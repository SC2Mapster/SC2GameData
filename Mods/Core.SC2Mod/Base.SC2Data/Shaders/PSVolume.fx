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

#define PASS_CLEAR                              0
#define PASS_ADD_VOLUME_DEPTH                   1
#define PASS_SUBTRACT_VOLUME_DEPTH              2
#define PASS_ADD_SCENE_DEPTH                    3
#define PASS_SUBTRACT_SCENE_DEPTH               4
#define PASS_VOLUME_FOG                         5

#define LINEAR_FOG      0
#define EXPONENTIAL_FOG 1

HALF p_fDensity;

DECLARE_LAYER( VolumeColor );
DECLARE_LAYER( VolumeNoise1 );
DECLARE_LAYER( VolumeNoise2 );

sampler2D p_sThickness;
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
float4 Volume( in VertexTransport vertOut ) {
    SEnvMappings envMappings = ComputeEnvMappings( vertOut, 1.0f );

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
        float4 vNormalDepth = SampleNormalDepth( p_sNormalDepthMap, vUV );
        float fDepth = PIXEL_DEPTH;
        return fDepth;
    } else if ( b_iVolumePass == PASS_SUBTRACT_SCENE_DEPTH ) {
        float2 vUV = GetBackBufferUV( vertOut, true, true );
        float4 vNormalDepth = SampleNormalDepth( p_sNormalDepthMap, vUV );
        float fDepth = -PIXEL_DEPTH;
        return fDepth;
    } 
    else if ( b_iVolumePass == PASS_VOLUME_FOG ) {
        float2 vUV = GetBackBufferUV( vertOut, true, true );
        float fThickness = tex2D( p_sThickness, vUV ).x * p_fDensity;

        fThickness = max( 0.0f, fThickness );
        
        float fogDensity;
        if ( b_iVolumeFalloffType == EXPONENTIAL_FOG )
            fogDensity = 1.0f - saturate( exp( -fThickness ) );
        else fogDensity = saturate( fThickness );

        half3 cColor = 1.0f;
        if ( b_iVolumeColorLayerEnable ) {
            SETUP_LAYER( VolumeColor );
            cColor = GetLayerColor( VolumeColor, 1.0f, false ).rgb;
        }
        if ( b_iVolumeMod )
            cColor.rgb *= fogDensity;

        return half4( cColor, fogDensity );
    } else return 0;
}

#else
float4 Volume( in VertexTransport vertOut ) { return 0;     }
#endif  // b_iShadingMode == SHADINGMODE_VOLUME

#endif  // PIXEL_SHADER

#endif  // PS_VOLUME