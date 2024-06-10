//==================================================================================================
//
// Copyright Blizzard Entertainment 2003-2007
//
// water shader code
//==================================================================================================

#include "ShaderSystem.fx"
#include "Common.fx"

/*
idea to do dynamic waves: 
dynamic wave accurators will just create circular sin waves
h(x, y, t) = a * sin(Dir dot {x, y} * wi + t*Phi)
Dir(x, y) = ({x, y} - Center) / |{x, y} - Center|
need to derive the analitical normal exquations from Gerstern waves + circular waves
*/


#define b_useCompressedBasis    0
#define c_maxNumWaves           64


//--------------------------------------------------------------------------------------------------
// VERTEX_SHADER
//--------------------------------------------------------------------------------------------------
#ifdef VERTEX_SHADER

#include "VSModelVertexFormat.fx"


#include "VSLighting.fx"
#include "VSUtils.fx"
#include "VSFog.fx"

#if ( b_iCheapWater && !CPP_SHADER )
    #define NUMWAVES 0
#else
    #define NUMWAVES 5
#endif

//--------------------------------------------------------------------------------------------------
float4x4 p_mWorldViewProj;                  // World * View * Projection transformation
float3x4 p_mView;                           // view matrix
float4x4 p_mUvMatrix;
float4   p_vWaveVectors[c_maxNumWaves];     // xy: 2D position, z: amplitude, w: not used
float4   p_fNumWaveVectors;
float4   p_vScrollVectors;
float3   p_vWaterScale;
float    p_fTime;
float3   p_vWaterTranslation;
float2   p_vTiling;

//--------------------------------------------------------------------------------------------------
float4 EmitWaterHPos( Input vertIn ) {
    return mul(vertIn.vPosition, p_mWorldViewProj);
}

//--------------------------------------------------------------------------------------------------
float4 EmitWaterHPosAsUV (Input vertIn) {
    return mul(vertIn.vPosition, p_mWorldViewProj);
}

//--------------------------------------------------------------------------------------------------
// View position.
float3 EmitWaterViewPos( Input vertIn ) {
    return mul( p_mView, vertIn.vPosition );            // View matrix is a 3x4 so it's transposed.
}

//--------------------------------------------------------------------------------------------------
float4 EmitWaterWorldPos ( Input vertIn ) {
    return float4(vertIn.vPosition.xyz, 1.0f);
}

//--------------------------------------------------------------------------------------------------
// FOW uvs
half4 EmitWaterFOWUV (Input vertIn) {
    return mul(vertIn.vPosition, p_mFOWMatrix);
}

//--------------------------------------------------------------------------------------------------
float3 GerstnerWave (in float3 x0) {
    float2 x=0;
    float z=0;
    float4 k;
#if PIXEL_SHADER_VERSION >= SHADER_VERSION_PS_30
#if COMPILING_SHADER_FOR_OPENGL
    for (int i=0; i<NUMWAVES; i++) {
#else
    for (int i=0; i<p_fNumWaveVectors.x; i++) {
#endif
         k = p_vWaveVectors[i];

        // frequency w^2 = g * |k|
        float omeg = sqrt(4.8f*length(k.xy));

        float s, c;
        sincos(omeg*p_fTime - dot(k.xy, x0.xy), s, c);

        x += k.w * k.z * normalize(k.xy) * s;
        z += k.w * k.z * c;
    }
#endif
    return float3(x0.xy+x, x0.z+z);
}

//--------------------------------------------------------------------------------------------------
float3 GerstnerWaveNormal (in float3 x0) {
    float2 adcx=0, adcy=0, ask=0;
    float z=0;
    float4 k;

#if PIXEL_SHADER_VERSION >= SHADER_VERSION_PS_30
#if COMPILING_SHADER_FOR_OPENGL
    for (int i=0; i<NUMWAVES; i++) {
#else
    for (int i=0; i<p_fNumWaveVectors.x; i++) {
#endif
         k = p_vWaveVectors[i];

        // frequency w^2 = g * |k|
        float omeg = sqrt(4.8f*length(k.xy));

        float s, c;
        sincos(omeg*p_fTime - dot(k.xy, x0.xy), s, c);

        // wave direction
        float2 d = normalize(k.xy);

        float a = k.z * k.w;
        float2 adc = a * d * c;
        adcx += adc * k.x;
        adcy += adc * k.y;
        ask += a * s * k.xy;
    }
#endif

    // tangent at x direction (dH/dx)
    float3 tx = float3(1-adcx.x, -adcx.y, ask.x);
    // tangent at y direction (dH/dy)
    float3 ty = float3(-adcy.x, 1-adcy.y, ask.y);

    float3 normal = cross(tx, ty);
    return normalize(normal);
}


//--------------------------------------------------------------------------------------------------
void WaterVertexMain( in VertDecl streamIn, out VertexTransport vertOut ) {
    InitShader( vertOut );

    Input vertIn;
    TranslateVert(streamIn, vertIn);
    
    VertexTransport output;
    
    // world position
    vertIn.vPosition.xyz *= p_vWaterScale;
    vertIn.vPosition.xyz += p_vWaterTranslation;

    // add wave
    if ( !b_iCheapWater )
        vertIn.vPosition.xyz = GerstnerWave(vertIn.vPosition.xyz);


    // compute UV from world position
    float4 vUv;
    vUv.xy = vertIn.vPosition.xy * p_vTiling;
    float4 scroll = p_fTime*p_vScrollVectors;
    vUv.y = 1.f - vUv.y;
    vUv.zw = vUv.xy + scroll.zw;
    vUv.xy = vUv.xy + scroll.xy;
    vUv.xy = mul(float4(vUv.xy, 0, 1), p_mUvMatrix);
    vUv.zw = mul(float4(vUv.zw, 0, 1), p_mUvMatrix);
    

    vertOut.HPos            = EmitWaterHPos(vertIn);
    INTERPOLANT_HPosAsUV    = EmitWaterHPosAsUV(vertIn);
    INTERPOLANT_WorldPos    = EmitWaterWorldPos(vertIn);
    INTERPOLANT_HalfVec     = EmitHalfVec(vertIn, 0);
    INTERPOLANT_Vector4     = vUv.xyzw;
    INTERPOLANT_ViewPos     = EmitWaterViewPos(vertIn);
    INTERPOLANT_FogColor    = EmitFogColor(vertIn);
    INTERPOLANT_FOWUV       = EmitWaterFOWUV(vertIn);
    INTERPOLANT_Diffuse     = EmitDiffuse( vertIn, float3(0,0,1) );
    INTERPOLANT_Specular    = EmitSpecular( vertIn );
    if ( b_useShadows ) {
        INTERPOLANT_ShadowMapUV     = EmitShadowMapUV(vertIn);
        INTERPOLANT_ShadowDiffuse	= EmitShadowDiffuse( vertIn, float3(0,0,1) );
        INTERPOLANT_ShadowSpecular	= EmitShadowSpecular(vertIn);
    }

    if ( !b_iCheapWater )
        INTERPOLANT_Normal   = float4(GerstnerWaveNormal(vertIn.vPosition.xyz),1);
    INTERPOLANT_Tangent  = float4(ComputeGridTangent(INTERPOLANT_Normal.xyz),1);


    #ifdef COMPILING_SHADER_FOR_OPENGL
        vertOut.HPos.y *= -1.0;
        vertOut.HPos.z = 2.0 * (vertOut.HPos.z - (0.5 * vertOut.HPos.w));
    #endif    
}

#endif  // VERTEX_SHADER

//--------------------------------------------------------------------------------------------------
// PIXEL_SHADER
//--------------------------------------------------------------------------------------------------
#ifdef PIXEL_SHADER

#include "PSCommon.fx"
#include "PSLighting.fx"
#include "PSFog.fx"
#include "PSShadow.fx"
#include "PSDebugUtils.fx"
#include "PSUtils.fx"
#include "PSUVMapping.fx"

float2      p_vVPOffset;                // view port offset
float2      p_vVPScale;                 // view port scale
float2	    p_vRTSize;                  // render target size
float2	    p_vRTOffset;                // render target offset
float4      p_vHeightMapInvertedSize;   // xy is the inverted size, z is scale

float4x4    p_mWorldView;
float4x4    p_mUvMatrixPS;

float3      p_vNormBias;
float4      p_vTint;
float       p_fTintFallOff;
float       p_fCausticsFallOff;
float       p_fSpecularScaler;
float2      p_vFrenelParams;
float       p_fFowScaler;
float       p_fReflectionDistortion;
float       p_fRefractionDistortion;
float       p_fShadowDistortion;
float2      p_vCausticsUvTiling;

sampler2D   p_sTexture0;
sampler2D   p_sTexture1;
sampler2D   p_sRelectionMap;
sampler2D   p_sRefractionMap;
sampler2D   p_sDepthMap;
sampler2D   p_sFow;
samplerCUBE p_sEnvMap;

//--------------------------------------------------------------------------------------------------
// a home made fresnel equation, not the real one but looks good and its fast
float ComputeFresnel(float3 vEyeVect, float3 vNormal) {
    //return saturate(p_vFrenelParams.y);
    /**/
    float eyeDotNormal = dot(vEyeVect, vNormal);
    //eyeDotNormal = saturate(eyeDotNormal);
    float f = pow(1-eyeDotNormal, p_vFrenelParams.x)+p_vFrenelParams.y;
    return saturate(f);
    /**/
}

//--------------------------------------------------------------------------------------------------
float2 HPos2ScreenUv (in VertexTransport vertOut, float2 vRTSize) {
	float2 vResult;
    #if ( VPOS_SEMANTIC )
		vResult = INTERPOLANT_HPosAsUV / vRTSize;
    #else
	    float2 vPos = INTERPOLANT_HPosAsUV.xy / INTERPOLANT_HPosAsUV.w;
	    vResult = vPos.xy * float2( 0.5f, -0.5f ) + 0.5f;
        vResult = (vResult + p_vVPOffset) / p_vVPScale;
    #endif
	return vResult;
}

//--------------------------------------------------------------------------------------------------
float2 ReflectionUv (in VertexTransport vertOut) {
	float2 vResult = HPos2ScreenUv(vertOut, p_vRTSize);
    vResult = (vResult + p_vVPOffset) * p_vVPScale;
    //vResult -= p_vRTOffset;
        
	return vResult;
}

//--------------------------------------------------------------------------------------------------
float2 RefractionUv (in VertexTransport vertOut) {
	float2 vResult = HPos2ScreenUv(vertOut, p_vRTSize);
    //vResult -= p_vRTOffset;
	return vResult;
}

//--------------------------------------------------------------------------------------------------
float3 WaterNormal (in VertexTransport vertOut) {
    float3 norm0;
    norm0.xy = tex2D(p_sTexture0,  INTERPOLANT_Vector4.xy).xy;
    norm0.xy = 2*norm0.xy - 1;
    norm0.z  = sqrt(1 - dot(norm0.xy, norm0.xy));

    float3 norm1;
    norm1.xy = tex2D(p_sTexture0,  INTERPOLANT_Vector4.zw).zw;
    norm1.xy = 2*norm1.xy - 1;
    norm1.z  = sqrt(1 - dot(norm1.xy, norm1.xy));

    float3 vNormal = norm0 + norm1;
    vNormal = vNormal + p_vNormBias;  // p_vNormBias is for smoothing normals
    vNormal = normalize(vNormal);
    vNormal = TangentToWorld(
                vNormal, 
                INTERPOLANT_Normal.xyz, 
                INTERPOLANT_Tangent.xyz, 
                cross(INTERPOLANT_Tangent.xyz, INTERPOLANT_Normal.xyz),
                true 
              );

    return vNormal;
}

//--------------------------------------------------------------------------------------------------
float4 WaterPixelMain( VertexTransport vertOut ) : COLOR {
    if ( b_envMapPass ) {
        //------------------------------------------------------------------------------------------
        // water env map pass
        //------------------------------------------------------------------------------------------
        InitShader( vertOut );
        float3 vNormal = WaterNormal(vertOut);
        float3 eyeDir = normalize(INTERPOLANT_WorldPos.xyz - p_vEyePos);
        float3 uv = GenCubicEnvio(eyeDir, vNormal, true);
#if COMPILING_SHADER_FOR_OPENGL
        return texCUBEbias(p_sEnvMap, float4(uv.xyz,-16));
#else
        return texCUBElod(p_sEnvMap, float4(uv.xyz,0));
#endif
    } 
    else if ( b_iCheapWater || PIXEL_SHADER_VERSION < SHADER_VERSION_PS_30 ) {
        //------------------------------------------------------------------------------------------
        // cheap water
        //------------------------------------------------------------------------------------------
        InitShader( vertOut );
        
        float4 vFinal=1;
        
        vFinal.xyz = tex2D(p_sTexture0, INTERPOLANT_Vector4.xy).xyz;
        
        // compute lighting
        float3 cDiffuse, cSpecular, cSpecular2;
        float3 vNormal = float3(0, 0, 1);
        half4 cShadowColor = 1;
        // :TODO: Need shadow UV here, even if it's "cheap" water!!!
        MainLighting(   vertOut, vNormal, 1, INTERPOLANT_Vector4.xy*512.f, 0, 
                        p_sTexture0, 1.0f, 
                        cDiffuse.xyz, cSpecular.xyz, cShadowColor, cSpecular2 );

        // modulate lighting
        vFinal.xyz = (vFinal.xyz*cDiffuse.xyz + vFinal.xyz) + cSpecular.xyz*vFinal.xyz;
        
        // modulate tint
        vFinal.xyz *= (float3(0.1f, 0.1f, 0.1f) + p_vTint.xyz);

        // add fog
        vFinal.xyz = ApplyFog(vertOut, vFinal, 1);
        
        if ( b_iUse8BitHDR )
            vFinal.xyz *= 0.5f;
        
        // add fog of war
        {
            float2 fowUv = Ndc2Tex(INTERPOLANT_FOWUV.xy, true );
            float4 c = tex2D(p_sFow, fowUv);
            vFinal.xyz = lerp(vFinal.xyz, c.xyz, c.w);
        }

        return float4(vFinal.xyz, max(p_vTint.w, 0.5f));
    } 
    else {
        //------------------------------------------------------------------------------------------
        // pretty water
        //------------------------------------------------------------------------------------------
        InitShader( vertOut );

        // normal
        float3 vNormal = WaterNormal(vertOut);
        float3 rnd = vNormal;
        
        // compute Frensel
        float3 worldPos = INTERPOLANT_WorldPos.xyz;
        float3 eyeDir = normalize(p_vEyePos - worldPos);
        float frensel = ComputeFresnel(eyeDir, vNormal);
        
        // reflection
        float2 reflectionUv = ReflectionUv(vertOut);

        // refraction
        float2 refractionUv = RefractionUv(vertOut);

        // tint, a function of depth
        float tintBlend = p_vTint.w;
        float depth = 0.5f;
        float saturatedDepth = 0.5f;
        float2 refractionUvDistortion = 0;
        if ( b_useWaterDepthEffects ) {
            float4 vNormalDepth = SampleNormalDepth( p_sDepthMap, refractionUv);

            float waterPlaneDepth = INTERPOLANT_ViewPos.y;
            depth = PIXEL_DEPTH - waterPlaneDepth;
            depth = max(0, depth);
            saturatedDepth = saturate(depth);

            tintBlend = p_fTintFallOff * depth;
            tintBlend = clamp(tintBlend, p_vTint.w, 1.0f ); 

            // compute refraction distortion
            {
                refractionUvDistortion = vNormal.xy*p_fRefractionDistortion*depth;
                float4 vNormalDepth = SampleNormalDepth( p_sDepthMap, refractionUv+refractionUvDistortion);
                float depth2 = PIXEL_DEPTH - waterPlaneDepth;
                depth2 = max(0, depth2);
                float saturatedDepth2 = saturate(depth2);
                refractionUvDistortion *= saturatedDepth2;
            }
        }

        // make normal variation at shore smaller
        vNormal = lerp(float3(0,0,1), vNormal, saturatedDepth);
        
        // sample reflection texture
        float4 cReflection;
        {
            float distortion = p_fReflectionDistortion*saturatedDepth;
            reflectionUv += vNormal.xy*distortion;
            cReflection = tex2D(p_sRelectionMap, reflectionUv);
        }

        // Lighting
        half4 cDiffuse, cSpecular, cSpecular2;
        float4 vShadowUv=1;
        half4 cShadowColor = 1;
        {
            // distort shadow in world space
            float3 vNewPos = INTERPOLANT_WorldPos.xyz + p_fShadowDistortion*rnd;
            vShadowUv = mul(float4(vNewPos, 1.f), p_mShadowTransform);

            MainLighting(   vertOut, vNormal, 
                            vShadowUv, INTERPOLANT_Vector4.xy*512.f, 
                            0, p_sTexture0,           // :TODO: Some height map support could make the water look better?
						    1.0f, cDiffuse.xyz, cSpecular.xyz, cShadowColor, cSpecular2.rgb );
        }


        // sample refraction texture    
        // if the area water texture covers changes (tiling frequency), these constants need to be changed
        float4 cRefraction;
        {
            cRefraction = tex2D(p_sRefractionMap, refractionUv+refractionUvDistortion);

            // add caustics onto refraction
            if ( b_useCaustics ) {
                float3 bottomPos = worldPos - eyeDir*depth;
                float2 vCausticsUv = p_vCausticsUvTiling * bottomPos.xy;
                vCausticsUv.y = 1 - vCausticsUv.y;
                vCausticsUv = mul(float4(vCausticsUv.xy, 0, 1), p_mUvMatrixPS).xy;
                //float2 perturb = INTERPOLANT_Normal.xy*0.1f;
                float4 vCaustics =  tex2D(p_sTexture1,  vCausticsUv);
                vCaustics.xyz *= cShadowColor.rgb;
                cRefraction += vCaustics*saturate(p_fCausticsFallOff*depth);
            }
        }

        // blend in refraction
        {
            cRefraction = lerp(cRefraction, p_vTint, tintBlend);
            cRefraction.xyz = cDiffuse*cRefraction.xyz;
        }

        // combine reflection and refraction
        float4 final;
        final.xyz = lerp(cRefraction.xyz, cReflection.xyz, frensel) + cSpecular.xyz*p_fSpecularScaler;
        
        // add fog
        final.xyz = ApplyFog(vertOut, final, 1);
        
        // add fog of war
        {
            float2 fowUv = Ndc2Tex(INTERPOLANT_FOWUV.xy, true );
            float4 c = tex2D(p_sFow, fowUv);
            final.xyz = lerp(final.xyz, c.xyz, c.w);
        }
        
        if (b_iDebugMode != NO_DEBUG && b_iDebugMode != SHOW_PROBLEMS) {
            return DebugColor(  cReflection.xyz, cRefraction.xyz, 0, vNormal.xyz, vNormal.xyz,         
                                cDiffuse.xyz, cSpecular.xyz, cShadowColor, 1.0f, 1.0f, 0.0f, 1.f, vertOut, final);
        }
        
        
        return float4(final.xyz, 1);
    }
}

#endif// PIXEL_SHADER