//==================================================================================================
//
// Copyright Blizzard Entertainment 2014
//
// This is the shader code for the reflection effect.
//==================================================================================================

#ifndef PS_REFLECTION
#define PS_REFLECTION
#ifdef PIXEL_SHADER

#if ( b_iShadingMode == SHADINGMODE_REFLECTION || CPP_SHADER )

#include "ShaderSystem.fx"
#include "PSLighting.fx"
#include "PSCommon.fx"

DECLARE_LAYER_2D( ReflectionNormal );
DECLARE_LAYER_2D( ReflectionStrength );
DECLARE_LAYER_2D( ReflectionBlurMask );
texDecl2D(p_sReflectionSrc);
float2      p_fDistortionStrength;
float3      p_fReflectionNormal;
float       p_fReflectionStrengthMultiplier;

HALF4 Reflection( in VertexTransport vertOut, inout HALF3 vDeferredNormal, inout HALF3 cDeferredDiffuse, inout HALF3 cDeferredSpecular, inout HALF cDeferredAO, inout HALF cDeferredSpecularPower, inout HALF cDeferredGlossiness ) {
    float3x2 mTriPlanarUVs[c_maxNumLayers];
    if( b_blurPass ) {
        HALF4 rvalue = 0.f;
        if( b_iReflectionBlurMaskLayerEnable ) {
            SEnvMappings envMappings = ComputeEnvMappings( vertOut, INTERPOLANT_Normal.xyz, INTERPOLANT_EyeToVertex );
            SETUP_LAYER( ReflectionBlurMask );
            rvalue.a = GetLayerColor( ReflectionBlurMask, 1.0f, false, vDeferredNormal, mTriPlanarUVs ).a;
        }

        return rvalue;
    } else {
        // Sample normal.
        HALF fStub = 0;
        HALF3 vNormal = 0;
        HALF3 vTextureNormal = 0;

        float2 reflectionUV = GetBackBufferUV( vertOut, true, true );
        if( b_iReflectionNormalLayerEnable ) {
            SETUP_LAYER( ReflectionNormal );
            if (b_iReflectionNormalUseConstantColor)
                vTextureNormal = ReflectionNormalLayerConfig.p_cConstantColor;
            else
                vTextureNormal = DecodeTextureNormal( texSampler(p_sReflectionNormalSampler), texTexture(p_sReflectionNormalSampler),
                                                      GetUVEmitter(vertOut, ReflectionNormalLayerConfig.b_iUVEmitter, ReflectionNormalLayerConfig.p_vMultiplyAddAlphaTrans.w, ReflectionNormalLayerConfig.p_mUVTransform), fStub );

            vNormal   = TangentToWorld( vTextureNormal, INTERPOLANT_Normal.xyz, INTERPOLANT_Tangent.xyz, INTERPOLANT_Binormal.xyz, false );

            // Remove the plane normal before projecting to viewspace so we get just the difference from the plane normal which we can translate to UV
            vNormal -= dot( vNormal, p_fReflectionNormal ) * p_fReflectionNormal.xyz;
            vNormal = mul( (half3x3)p_mViewTransform, vNormal );

            float2 reflectionDelta = ( vNormal.xy * p_fDistortionStrength.xy);
            reflectionUV.xy += reflectionDelta;
        }

        float fStrength = p_fReflectionStrengthMultiplier;
        if( b_iReflectionStrengthLayerEnable ) {
            SEnvMappings envMappings = ComputeEnvMappings( vertOut, vNormal, INTERPOLANT_EyeToVertex );
            SETUP_LAYER( ReflectionStrength );
            fStrength *= GetLayerColor( ReflectionStrength, 1.0f, false, vDeferredNormal, mTriPlanarUVs ).a;
        }

        return fStrength * sample2D( p_sReflectionSrc, reflectionUV );
    }
}

#else // ( b_iShadingMode == SHADINGMODE_REFLECTION || CPP_SHADER )

HALF4 Reflection( in VertexTransport vertOut, inout HALF3 vDeferredNormal, inout HALF3 cDeferredDiffuse, inout HALF3 cDeferredSpecular, inout HALF cDeferredAO, inout HALF cDeferredSpecularPower, inout HALF cDeferredGlossiness ) { return 0;    }
#endif // ( b_iShadingMode == SHADINGMODE_REFLECTION || CPP_SHADER )
#endif // PIXEL_SHADER
#endif // PS_REFLECTION
