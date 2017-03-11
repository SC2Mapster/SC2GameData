//==================================================================================================
//
// Copyright Blizzard Entertainment 2014
//
// This is the shader code for the blit offscreen effect.
//==================================================================================================

#ifndef PS_CLOAKING
#define PS_CLOAKING
#ifdef PIXEL_SHADER

#if ( b_iShadingMode == SHADINGMODE_CLOAKING || CPP_SHADER )

#include "ShaderSystem.fx"
#include "PSLighting.fx"
#include "PSCommon.fx"

DECLARE_LAYER_2D( CloakingAlphaMask );
DECLARE_LAYER_2D( CloakingEnvio );
DECLARE_LAYER_2D( CloakingEnvioMask );
DECLARE_LAYER_2D( CloakingAlphaTest );
DECLARE_LAYER_2D( CloakingAlphaMaskOriginal );
DECLARE_LAYER_2D( CloakingNormal );
texDecl2D( p_sCloakingSrc );

float p_fCloakingAlpha;
float p_fOGThreshold;

#define CLOAKINGMODE_BLITOFFSCREEN      0
#define CLOAKINGMODE_CLOAKTRANSPARENT   1
#define CLOAKINGMODE_CLOAKOPAQUE        2

HALF4 Cloaking( in VertexTransport vertOut, inout HALF3 vDeferredNormal, inout HALF3 cDeferredDiffuse, inout HALF3 cDeferredSpecular, inout HALF cDeferredAO,
    inout HALF cDeferredSpecularPower, inout HALF cDeferredGlossiness ) {
    float3x2 mTriPlanarUVs[c_maxNumLayers];
    if( b_iCloakingPass == CLOAKINGMODE_BLITOFFSCREEN ) {
        float2 vUV = GetBackBufferUV( vertOut, true, true );
        float4 rvalue = sample2D( p_sCloakingSrc, vUV );
        cDeferredDiffuse = rvalue;

        return rvalue;
    } else if( b_iCloakingPass == CLOAKINGMODE_CLOAKTRANSPARENT ) {
        SEnvMappings envMappings = ComputeEnvMappings( vertOut, INTERPOLANT_Normal, INTERPOLANT_EyeToVertex );
        float2 vUV = GetBackBufferUV( vertOut, true, true );
        float4 objectColor = sample2D( p_sCloakingSrc, vUV );

        vDeferredNormal = normalize( INTERPOLANT_Normal.xyz );

        HALF4 rvalue;
        rvalue = HALF4( p_fCloakingAlpha*objectColor.rgb, 1.f-p_fCloakingAlpha );

        if ( b_iCloakingAlphaTestLayerEnable ) {
            SETUP_LAYER( CloakingAlphaTest );
            float alphaTestValue = GetLayerColor( CloakingAlphaTest, 1.0f, true, vDeferredNormal, mTriPlanarUVs ).a;
            if( alphaTestValue >= p_fAlphaThreshold )
            {
                rvalue.rgb = objectColor.rgb;
                rvalue.a = 0.f;
            }
        }

        return rvalue;
    } else if( b_iCloakingPass == CLOAKINGMODE_CLOAKOPAQUE ) {
        HALF4 rvalue;
        SETUP_LAYER( CloakingNormal );
        if( b_iCloakingNormalLayerEnable ) {
            vDeferredNormal = DecodeNormalInternal( vertOut, CloakingNormalLayerConfig, texSampler(p_sCloakingNormalSampler),
                texTexture(p_sCloakingNormalSampler) );
        } else {
            vDeferredNormal = normalize( INTERPOLANT_Normal.xyz );
        }

        SEnvMappings envMappings = ComputeEnvMappings( vertOut, vDeferredNormal, INTERPOLANT_EyeToVertex );
        SETUP_LAYER( CloakingAlphaMask );
        rvalue.a =  p_fCloakingAlpha * saturate( GetLayerColor( CloakingAlphaMask, 1.0f, false, vDeferredNormal, mTriPlanarUVs ).a );
        if ( b_iCloakingAlphaMaskOriginalLayerEnable ) {
            SETUP_LAYER( CloakingAlphaMaskOriginal );
            float alphaTestValue = GetLayerColor( CloakingAlphaMaskOriginal, 1.0f, true, vDeferredNormal, mTriPlanarUVs ).a;
            if( alphaTestValue < p_fOGThreshold )
            {
                rvalue.rgb = 0.f;
                rvalue.a   = 1.f;
#if !CPP_SHADER  // If we return during the CPP shader simulation then we don't mark any of the static branches below as valid. This is bad!
                return rvalue;
#endif
            }
            rvalue.a *= alphaTestValue;
        }

        float2 vUV = GetBackBufferUV( vertOut, true, true );
        HALF4 backgroundColor = sample2D( p_sCloakingSrc, vUV );
        rvalue.rgb = backgroundColor.rgb;

        if ( b_iCloakingEnvioLayerEnable ) {
            SETUP_LAYER( CloakingEnvio );
            HALF4 envio = GetLayerColor( CloakingEnvio, 1.0f, true, vDeferredNormal, mTriPlanarUVs );
            if ( b_iCloakingEnvioMaskLayerEnable ) {
                SETUP_LAYER( CloakingEnvioMask );
                envio.a = GetLayerColor( CloakingEnvioMask, 1.0f, true, vDeferredNormal, mTriPlanarUVs ).a * envio.a;
            }

            // This simulates what would happen in a regular shader since our src and dst colors are reversed in the blend unit.
            if ( CloakingEnvioLayerConfig.b_iOp == LAYEROP_ADD ) {
                rvalue.rgb = (1.0 - rvalue.a) * rvalue.rgb + rvalue.a * envio.rgb * envio.a;
            } else if ( CloakingEnvioLayerConfig.b_iOp == LAYEROP_LERP ) {
                rvalue.rgb = (1.0 - rvalue.a) * rvalue.rgb + rvalue.a * envio.rgb * envio.a;
                rvalue.a = rvalue.a - rvalue.a * envio.a;
            }
            else
            {
                rvalue.rgb *= 1.0 - rvalue.a;
            }
        } else {
            rvalue.rgb *= 1.0 - rvalue.a;
        }

        if ( b_iCloakingAlphaTestLayerEnable ) {
            SETUP_LAYER( CloakingAlphaTest );
            float alphaTestValue = GetLayerColor( CloakingAlphaTest, 1.0f, true, vDeferredNormal, mTriPlanarUVs ).a;
            if( alphaTestValue >= p_fAlphaThreshold )
            {
                rvalue.rgb = 0.f;
                rvalue.a   = 1.f;
            }
        }

        return rvalue;
    }

    return HALF4( 0.0, 1.0, 0.0, 0.0 );
}

#else // ( b_iShadingMode == SHADINGMODE_CLOAKING || CPP_SHADER )

HALF4 Cloaking( in VertexTransport vertOut, inout HALF3 vDeferredNormal, inout HALF3 cDeferredDiffuse, inout HALF3 cDeferredSpecular, inout HALF cDeferredAO,
    inout HALF cDeferredSpecularPower, inout HALF cDeferredGlossiness ) { return 0;    }
#endif // ( b_iShadingMode == SHADINGMODE_CLOAKING || CPP_SHADER )
#endif // PIXEL_SHADER
#endif // PS_CLOAKING
