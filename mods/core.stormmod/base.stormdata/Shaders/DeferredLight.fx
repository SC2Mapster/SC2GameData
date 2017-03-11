//==================================================================================================
//
// Copyright Blizzard Entertainment 2003-2006
//
// Deferred (point) light shader.
//==================================================================================================

#include "ShaderSystem.fx"

#ifdef VERTEX_SHADER

struct Input {
    float4  vPosition       : POSITION_;
};

#include "MaterialDefines.fx"
#include "VSCommon.fx"
#include "VSUtils.fx"
#include "VSShadow.fx"

float3x4    p_mWVTransform;                 // World-View transform.
float3x4    p_mWorldTransform;              // World transform.
float4x4    p_mWVPTransform;                // World-View-Projection transform.

//--------------------------------------------------------------------------------------------------
// Main vertex shader body.
//--------------------------------------------------------------------------------------------------
VertexTransport DeferredLightVertexMain( Input vertIn ) {
    VertexTransport vertOut;
    InitShader( vertOut );
    vertOut.HPos                = mul( vertIn.vPosition, p_mWVPTransform );
    WRITE_INTERPOLANT_BackBufferUV( GetBackBufferUV( vertOut.HPos, b_useViewport ) );
    WRITE_INTERPOLANT_HPosAsUV( vertOut.HPos );
#ifdef COMPILING_SHADER_FOR_OPENGL
    vertOut.HPos.y *= -1.0;
    vertOut.HPos.z = 2.0 * (vertOut.HPos.z - (0.5 * vertOut.HPos.w));
#endif
    return vertOut;
}

#endif  // VERTEX_SHADER

#ifdef PIXEL_SHADER

#include "LightTypes.fx"
#include "PSUtils.fx"
#include "PSCommon.fx"
#include "PSDebugModes.fx"
#include "PSShadow.fx"

texDecl2D(p_sDiffuseMap);
texDecl2D(p_sSpecularMap);
texDecl2D(p_sSSAO);
float4      p_vPositionRecipRadius;
HALF4       p_cColorAttenMultiplier;
HALF3       p_vDirection;
HALF3       p_vFalloffBiasScaleAndHotSpotMultiplier;
float4      p_vUVToViewPos;
float       p_fShadowMapSize;
float4x4    p_mPTransform;                // Projection transform.

/*
sampler2D   p_sStereoscopicTexture;
float       p_fInvProj00;
float       p_fStereoSeparation;
float       p_fStereoConvergence;
*/

#define LIGHT_DEBUG_NONE            0
#define LIGHT_DEBUG_COLORS          1
#define LIGHT_DEBUG_SINGLE_LIGHT    2

//--------------------------------------------------------------------------------------------------
// Main pixel shader body.
//--------------------------------------------------------------------------------------------------
HALF4 DeferredLightPixelMain( in VertexTransportRaw vertRaw ) : COLOR {
    VertexTransport vertOut;
    InitShader( vertRaw, vertOut );

    float2 vOffsetUV;
    float2 vUV;
    float4 vViewPos;

    if ( b_useVSBackBufferUV ) {
        vUV = INTERPOLANT_BackBufferUV;
        vOffsetUV = vUV + p_vRecipRenderTargetSizeOffset.zw;                            // Offset it so it samples exact pixels.
        vViewPos.xz = vUV.xy * p_vUVToViewPos.xy + p_vUVToViewPos.zw;                   // View vector
    } else  {
        if ( VPOS_SEMANTIC ) {
            // Optimized version.
            // Offset it so it samples exact pixels. Map to [0..1] with 1/2 pixel offset
            vOffsetUV = INTERPOLANT_ScreenPos.xy * p_vRecipRenderTargetSizeOffset.xy + p_vRecipRenderTargetSizeOffset.zw;

            // Equation is INTERPOLANT_ScreenPos * HALF2( 2.0f, -2.0f ) * 0.5 * p_vCameraNearSize * p_vRecipRenderTargetSize     Map to [0..CamWidth]
            // + HALF2( -1.0f, 1.0f ) ) * 0.5 * p_vCameraNearSize                                                               Map to [-CamWidth/2..CamWidth/2]
            vViewPos.xz = INTERPOLANT_ScreenPos.xy * p_vUVToViewPos.xy + p_vUVToViewPos.zw;
        } else {
            vUV = GetBackBufferUV( vertOut, b_useViewport, false );
            vOffsetUV = vUV + p_vRecipRenderTargetSizeOffset.zw;                        // Offset it so it samples exact pixels.
            // Equation is vUV * HALF2( 2.0f, -2.0f ) + HALF2( -1.0f, 1.0f ) ) * 0.5 * p_vCameraNearSize
            vViewPos.xz = vUV.xy * p_vUVToViewPos.xy + p_vUVToViewPos.zw;
        }
    }
    
    float4 vNormalDepth = SampleNormalDepth( texSampler(p_sNormalDepthMap), texTexture(p_sNormalDepthMap), vOffsetUV );
    HALF4 cDiffuse      = sample2D( p_sDiffuseMap, vOffsetUV );
    HALF4 cSpecular;
    if ( b_useDeffSpecularPower ) {
        cSpecular = sample2D( p_sSpecularMap, vOffsetUV );
    } else {
        cSpecular.rgb = sample2D( p_sSpecularMap, vOffsetUV ).rgb;
        cSpecular.a = p_vSpecColorSpecularity.a;
    }
    if ( b_iUse8BitHDR )
        cSpecular.a /= p_vHDRScaling.y;

    PIXEL_NORMAL = normalize( PIXEL_NORMAL );   // :TODO: Toggle this out. Ony needed for terrain.
    
    vViewPos.yw = HALF2( PIXEL_DEPTH, 1.0f );
    vViewPos.xz = vViewPos.xz * ( PIXEL_DEPTH * p_mPTransform[1][3] + p_mPTransform[3][3] );

    /*
    if ( b_iStereoscopicCorrection ) {
        float4 stereoSide = tex2D( p_sStereoscopicTexture, float2( 1.0f / 16.0f, 0.5 ) );
        //return stereoSide;
        vViewPos.x += stereoSide * p_fInvProj00 * ( -p_fStereoSeparation * vViewPos.y + p_fStereoSeparation * p_fStereoConvergence ); 
    }
    */

    // :TODO: Work in view space, not world space.
    // Back to world space
    float3 vPos = mul( p_mInvViewTransform, vViewPos ).xyz;

    HALF3 lightDiffSpecIntensity;
    if ( b_iLightType == LIGHTTYPE_POINT ) {
        ComputePointLight(  vertOut, PIXEL_NORMAL, vPos, p_vPositionRecipRadius.xyz, p_vPositionRecipRadius.w, p_cColorAttenMultiplier.w, 
                            USE_SPECULAR, cSpecular.w, lightDiffSpecIntensity );
    } else if ( b_iLightType == LIGHTTYPE_SPOT ) {
        ComputeSpotLight(   vertOut, PIXEL_NORMAL, vPos, p_vPositionRecipRadius.xyz, p_vDirection, p_vPositionRecipRadius.w, p_cColorAttenMultiplier.w, 
                            p_vFalloffBiasScaleAndHotSpotMultiplier.x, p_vFalloffBiasScaleAndHotSpotMultiplier.y, 
                            p_vFalloffBiasScaleAndHotSpotMultiplier.z, 
                            USE_SPECULAR, cSpecular.w, lightDiffSpecIntensity );
    }

    // :TODO: Deferred parallax mapping
    float4 vShadowMapUV = mul( float4( vPos, 1 ), p_mShadowTransform );  

    // Since spot light shadows have a fixed viewpoint, just use the shadow map UV for the shadow map noise.
    HALF4 cShadowColor = ShadowIntensity( vertOut, vShadowMapUV, vShadowMapUV.xy * p_fShadowMapSize / 32.0f, HALF2( 0.0f, 0.0f ), texSampler(p_sDiffuseMap), texTexture(p_sDiffuseMap) );

    if ( b_iAffectedByAO )
        cShadowColor *= sample2D( p_sSSAO, vOffsetUV ).a;
        
    if ( b_iDebugMode == LIGHTING_ONLY ) {
        cDiffuse = 1.0f;
        cSpecular = 1.0f;
    } else if ( b_iDebugMode == DIFFUSE_LIGHTING_ONLY ) {
        cDiffuse = 1.0f;
        cSpecular = 0.0f;
    } else if ( b_iDebugMode == SPECULAR_LIGHTING_ONLY ) {
        cDiffuse = 0.0f;
        cSpecular = 1.0f;
    } else if ( b_iDebugMode == DIFFUSE_ONLY )
        cSpecular = 0.0f;
    else if ( b_iDebugMode == SPECULAR_ONLY )
        cDiffuse = 0.0f;
    else if ( b_iDebugMode == SHADOWS_ONLY )
        return HALF4( cShadowColor.rgb, 1.0f );
    else if ( b_iDebugMode == LIGHTING_OVERLAP )
        return 1.0f / 8.0f;
    else if ( b_iDebugMode == OVERDRAW )
        return 0;
    else if ( b_iDebugMode != NO_DEBUG )
        return 0.0f;

#ifdef COMPILING_SHADER_FOR_OPENGL
    if ( b_iLightDebugMode == LIGHT_DEBUG_COLORS ) {
        HALF3 zero3 = HALF3(0.0f, 0.0f, 0.0f);
        bool3 spec3 = (cSpecular.rgb * p_vSpecColorSpecularity.rgb * lightDiffSpecIntensity.y) != zero3;
        bool spectest = spec3.x && spec3.y && spec3.z;
        bool3 diff3 = (cDiffuse.rgb * p_cColorAttenMultiplier.xyz * lightDiffSpecIntensity.x) == zero3;
        bool difftest = diff3.x && diff3.y && diff3.z;
        if (    b_iUseSpecular &&
                lightDiffSpecIntensity.y >= 0.02f &&
                spectest ) {
            if ( cShadowColor.a > 0.0f )
                return HALF4( 0.0f, 0.0f, 1.0f, 1.0f );     // Blue = specular highlight
            else return HALF4( 1.0f, 0.0f, 0.0f, 1.0f );    // Dark blue = shadowed specular
        } else if ( lightDiffSpecIntensity.x <= 0.02f ||
                    difftest )
            return HALF4( 1.0f, 0.0f, 0.0f, 1.0f ); // Red = <= 1% contribution sample
        else if ( cShadowColor.a == 0.0f )
            return HALF4( 1.0f, 0.0f, 0.0f, 1.0f ); // Dark green = shadowed light pixel
        else
            return HALF4( 0.0f, 1.0f, 0.0f, 1.0f );     // Green = lit pixel 
    }
#else
    if ( b_iLightDebugMode == LIGHT_DEBUG_COLORS ) {
        if (    b_iUseSpecular &&
                lightDiffSpecIntensity.y >= 0.02f 
                //&& ( cSpecular.rgb * p_vSpecColorSpecularity.rgb * lightDiffSpecIntensity.y ) != HALF3( 0.0f, 0.0f, 0.0f ) 
                ) {
            if ( cShadowColor.a > 0.0f )
                return HALF4( 0.0f, 0.0f, 1.0f, 1.0f );     // Blue = specular highlight
            else return HALF4( 0.5f, 0.0f, 0.0f, 1.0f );    // Dark red = shadowed specular
        } else if ( lightDiffSpecIntensity.x <= 0.02f ) 
            //|| ( cDiffuse.rgb * p_cColorAttenMultiplier.xyz * lightDiffSpecIntensity.x ) == HALF3( 0.0f, 0.0f, 0.0f ) )
            return HALF4( 1.0f, 0.0f, 0.0f, 1.0f );         // Red = <= 1% contribution sample
        else if ( cShadowColor.a == 0.0f )
            return HALF4( 0.5f, 0.0f, 0.0f, 1.0f );         // Dark red = shadowed light pixel
        else if ( cShadowColor.a < 1.0f ) 
            return HALF4( 0.0f, 0.5f, 0.0f, 1.0f );         // Dark Green = partially lit pixel
        else return HALF4( 0.0f, 1.0f, 0.0f, 1.0f );        // Green = lit pixel
    }
#endif

    HALF4 result;
    result.rgb = cDiffuse * p_cColorAttenMultiplier.xyz * lightDiffSpecIntensity.x * cShadowColor.rgb;
    if ( b_iUseSpecular )
        result.rgb += cSpecular.rgb * p_vSpecColorSpecularity.rgb * lightDiffSpecIntensity.y * cShadowColor.rgb;
    result.a = 1.0f;
    if ( b_iUse8BitHDR )
        result.rgb *= p_vHDRScaling.x;

    return result;
}

#endif  // PIXEL_SHADER