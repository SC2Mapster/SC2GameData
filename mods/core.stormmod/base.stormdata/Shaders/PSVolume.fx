//==================================================================================================
//
// Copyright Blizzard Entertainment 2003-2006
//
// This is the shader code for volume effects.
//==================================================================================================

#ifndef PS_VOLUME
#define PS_VOLUME

#ifdef PIXEL_SHADER

#if ( b_iShadingMode == SHADINGMODE_VOLUME || CPP_SHADER )

#include "ShaderSystem.fx"
#include "PSCommon.fx"

#define VOLUME_TYPE_UNIFORM 0
#define VOLUME_TYPE_NOISY   1

#define PASS_CLEAR                              0
#define PASS_ADD_VOLUME_DEPTH                   1
#define PASS_SUBTRACT_VOLUME_DEPTH              2
#define PASS_ADD_SCENE_DEPTH                    3
#define PASS_SUBTRACT_SCENE_DEPTH               4
#define PASS_VOLUME_FOG                         5

#define LINEAR_FOG      0
#define EXPONENTIAL_FOG 1

#define NOISY_PASS0 0
#define NOISY_PASS1 1

#define NOISY_CAM_OUTSIDE 0
#define NOISY_CAM_INSIDE  1

HALF p_fDensity;

#if b_iVolumeColorTextureType == TEXTURE_TYPE_2D
DECLARE_LAYER_2D( VolumeColor );
#elif b_iVolumeColorTextureType == TEXTURE_TYPE_VOLUME
DECLARE_LAYER_3D( VolumeColor );
#else
DECLARE_LAYER_CUBE( VolumeColor );
#endif

#if b_iVolumeNoise1TextureType == TEXTURE_TYPE_2D
DECLARE_LAYER_2D( VolumeNoise1 );
#elif b_iVolumeNoise1TextureType == TEXTURE_TYPE_VOLUME
DECLARE_LAYER_3D( VolumeNoise1 );
#else
DECLARE_LAYER_CUBE( VolumeNoise1 );
#endif

#if b_iVolumeNoise2TextureType == TEXTURE_TYPE_2D
DECLARE_LAYER_2D( VolumeNoise2 );
#elif b_iVolumeNoise2TextureType == TEXTURE_TYPE_VOLUME
DECLARE_LAYER_3D( VolumeNoise2 );
#else
DECLARE_LAYER_CUBE( VolumeNoise2 );
#endif

texDecl2D(p_sThickness);
HALF p_fNearPlane;

/*
    if ( b_iVolumeNoise1LayerEnable ) {
        SETUP_LAYER( VolumeNoise1 );
        fDepth -= ( GetLayerColor( VolumeNoise1, 1.0f ).a ) * 2.0f;
    }
    if ( b_iVolumeNoise2LayerEnable ) {
        SETUP_LAYER( VolumeNoise2 );
        fDepth -= ( GetLayerColor( VolumeNoise2, 1.0f ).a ) * 10.0f;;
    }
*/

//--------------------------------------------------------------------------------------------------
float4 VolumeUniform ( in VertexTransport vertOut, inout HALF3 vDeferredNormal, inout HALF3 cDeferredDiffuse, inout HALF3 cDeferredSpecular, inout HALF cDeferredAO, inout HALF cDeferredSpecularPower, inout HALF cDeferredGlossiness ) {
    SEnvMappings envMappings = ComputeEnvMappings( vertOut, 1.0f, INTERPOLANT_EyeToVertex );

    float3x2 mTriPlanarUVs[c_maxNumLayers];

    if ( b_iVolumePass == PASS_CLEAR ) {
        return 0.0f;    
    } else if ( b_iVolumePass == PASS_ADD_VOLUME_DEPTH ) {
        float fDepth = INTERPOLANT_ViewPos.y;
        return fDepth;
    } else if ( b_iVolumePass == PASS_SUBTRACT_VOLUME_DEPTH ) {
        float fDepth = -INTERPOLANT_ViewPos.y;
        return fDepth;
    } else if ( b_iVolumePass == PASS_ADD_SCENE_DEPTH ) {
        float2 vUV = GetBackBufferUV( vertOut, true, true );
        float4 vNormalDepth = SampleNormalDepth( texSampler(p_sNormalDepthMap), texTexture(p_sNormalDepthMap), vUV );
        float fDepth = PIXEL_DEPTH;
        return fDepth;
    } else if ( b_iVolumePass == PASS_SUBTRACT_SCENE_DEPTH ) {
        float2 vUV = GetBackBufferUV( vertOut, true, true );
        float4 vNormalDepth = SampleNormalDepth( texSampler(p_sNormalDepthMap), texTexture(p_sNormalDepthMap), vUV );
        float fDepth = -PIXEL_DEPTH;
        return fDepth;
    } 
    else if ( b_iVolumePass == PASS_VOLUME_FOG ) {
        float2 vUV = GetBackBufferUV( vertOut, true, true );
        float fThickness = sample2D( p_sThickness, vUV ).x * p_fDensity;

        fThickness = max( 0.0f, fThickness );
        
        float fogDensity;
        if ( b_iVolumeFalloffType == EXPONENTIAL_FOG )
            fogDensity = 1.0f - saturate( exp( -fThickness ) );
        else fogDensity = saturate( fThickness );

        HALF3 cColor = 1.0f;
        if ( b_iVolumeColorLayerEnable ) {
            SETUP_LAYER( VolumeColor );
            cColor = GetLayerColor( VolumeColor, 1.0f, false, vDeferredNormal, mTriPlanarUVs ).rgb;
        }
        if ( b_iVolumeMod )
            cColor.rgb *= fogDensity;

        return HALF4( cColor, fogDensity );
    } else return 0;
}

//--------------------------------------------------------------------------------------------------
float4x4 p_mView2UV;            // view space to uv space
float3x3 p_mView2UV2;           // view space to uv space, for directional vectors
float4x4 p_vVolumeUvAnim;
float3   p_vVolumeUvScroll;
float    p_fFallOffValue;
texDecl2D(p_sSceneDepthMap);
//--------------------------------------------------------------------------------------------------
float4 WalkVolume (VertexTransport vertOut, float3 vViewEntry, float3 vViewExit, HALF3 vDeferredNormal) {
    float3x2 mTriPlanarUVs[c_maxNumLayers];

    SEnvMappings envMappings = ComputeEnvMappings( vertOut, 1.0f, INTERPOLANT_EyeToVertex );
    float fViewDist = length(vViewExit - vViewEntry);

    // entry and exit points in uv space
    float3 uvEntry = mul(float4(vViewEntry.xyz, 1), p_mView2UV).xyz;
    float3 uvExit = mul(float4(vViewExit.xyz, 1), p_mView2UV).xyz;
    float uvDist = length(uvEntry.xyz - uvExit.xyz);

    // view vector in uv space
    float3 vUvViewDir = mul(INTERPOLANT_ViewPos.xyz, (float3x3)p_mView2UV);
    vUvViewDir = normalize(vUvViewDir);

    // accumulate along view vector in uv space
    const int c_numMaxSteps = 40;
    float fViewDistDelta = fViewDist/c_numMaxSteps;
    float4 vSum = 0;
    float3 vUvDelta = vUvViewDir * (fViewDistDelta*uvDist/fViewDist);
    float3 vUv = uvEntry;
    float3 vUv2 = vUv;
    vUv = vUv + p_vVolumeUvScroll;     // scroll texture 1
    vUv2 = vUv2 - p_vVolumeUvScroll;   // scroll texture 2
    float fCurrentViewDist = 0;
    for (int i=0; i<c_numMaxSteps; i++) {
#if b_iVolumeNoise1TextureType == TEXTURE_TYPE_2D
        float4 vSample0 = sample2D(p_sVolumeNoise1Sampler, vUv.xy);
#else
        float4 vSample0 = sample3D(p_sVolumeNoise1Sampler, vUv);
#endif
#if b_iVolumeNoise2TextureType == TEXTURE_TYPE_2D
        float4 vSample1 = sample2D(p_sVolumeNoise2Sampler, vUv2.xy);
#else
        float4 vSample1 = sample3D(p_sVolumeNoise2Sampler, vUv2);
#endif
        
        float4 vSample = (vSample0 + vSample1) / 2.f;

        //float sampleBlend = vSample.w*(1 - vSum.w);
        //vSum.xyz += vSample.xyz*sampleBlend;
        //vSum.w += sampleBlend;

        float viewDistFallOff = saturate((fCurrentViewDist - p_fNearPlane)*p_fFallOffValue);
        float sampleBlend = vSample.w * p_fDensity * viewDistFallOff ;
        vSum.xyz += vSample.xyz*sampleBlend;

        vUv += vUvDelta;
        vUv2 += vUvDelta;
        fCurrentViewDist += fViewDistDelta;

        if (fCurrentViewDist >= fViewDist)
            break;
    }

    // color
    float4 cColor = 1.0f;
    if ( b_iVolumeColorLayerEnable ) {
        SETUP_LAYER( VolumeColor );
        cColor = GetLayerColor( VolumeColor, 1.0f, false, vDeferredNormal, mTriPlanarUVs );
    }

    float4 vResult = saturate(float4(cColor.xyz, vSum.x));

    // map fog
    float globalFogDensity = FogDensity(INTERPOLANT_WorldPos.xyz);
    vResult.rgb = lerp(vResult.rgb, p_cFogColor.xyz, globalFogDensity);

    return vResult;
}
//--------------------------------------------------------------------------------------------------
float4 VolumeNoisy ( in VertexTransport vertOut, inout HALF3 vDeferredNormal, inout HALF3 cDeferredDiffuse, inout HALF3 cDeferredSpecular, inout HALF cDeferredAO, inout HALF cDeferredSpecularPower, inout HALF cDeferredGlossiness ) {
    if (b_iVolumePass==NOISY_PASS0) {
        // inside
        if (b_iVolumeCamPos==NOISY_CAM_INSIDE) {
            float2 vBackBufferUv = GetBackBufferUV(vertOut, true, true);
            float fSceneDepth = SampleNormalDepth( texSampler(p_sSceneDepthMap), texTexture(p_sSceneDepthMap), vBackBufferUv ).w;
            float fExitDepth = min(INTERPOLANT_ViewPos.y, fSceneDepth);
            // entry and exit points in view space
            float3 vViewEntry = 0;
            float3 vViewExit = INTERPOLANT_ViewPos.xyz;
            vViewExit.y = fExitDepth;
            return WalkVolume(vertOut, vViewEntry, vViewExit, vDeferredNormal);
        }
        // outside
        else {
             return INTERPOLANT_ViewPos.y;
        }
    }
    else if (b_iVolumePass==NOISY_PASS1) {
        float2 vBackBufferUv = GetBackBufferUV(vertOut, true, true);
        float fSceneDepth = SampleNormalDepth( texSampler(p_sSceneDepthMap), texTexture(p_sSceneDepthMap), vBackBufferUv ).w;
        float fBackFaceDepth = sample2D(p_sThickness, vBackBufferUv).x;
        float fExitDepth = min(fBackFaceDepth, fSceneDepth);
        // entry and exit points in view space
        float3 vViewEntry = INTERPOLANT_ViewPos.xyz;
        float3 vViewExit = INTERPOLANT_ViewPos.xyz;
        vViewExit.y = fExitDepth;
        return WalkVolume(vertOut, vViewEntry, vViewExit, vDeferredNormal);
    }

    return 1;
}

//--------------------------------------------------------------------------------------------------
float4 Volume( in VertexTransport vertOut, inout HALF3 vDeferredNormal, inout HALF3 cDeferredDiffuse, inout HALF3 cDeferredSpecular, inout HALF cDeferredAO,
    inout HALF cDeferredSpecularPower, inout HALF cDeferredGlossiness ) {
    if (b_iVolumeType == VOLUME_TYPE_UNIFORM)
        return VolumeUniform(vertOut, vDeferredNormal, cDeferredDiffuse, cDeferredSpecular, cDeferredAO, cDeferredSpecularPower, cDeferredGlossiness);
    else
        return VolumeNoisy(vertOut, vDeferredNormal, cDeferredDiffuse, cDeferredSpecular, cDeferredAO, cDeferredSpecularPower, cDeferredGlossiness);
}

#else
float4 Volume( in VertexTransport vertOut, inout HALF3 vDeferredNormal, inout HALF3 cDeferredDiffuse, inout HALF3 cDeferredSpecular, inout HALF cDeferredAO,
    inout HALF cDeferredSpecularPower, inout HALF cDeferredGlossiness ) { return 0;     }
#endif  // b_iShadingMode == SHADINGMODE_VOLUME

#endif  // PIXEL_SHADER

#endif  // PS_VOLUME
