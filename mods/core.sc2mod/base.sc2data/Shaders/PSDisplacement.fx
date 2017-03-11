//==================================================================================================
//
// Copyright Blizzard Entertainment 2003-2006
//
// This is the shader code forthe displacement effect.
//==================================================================================================

#ifndef PS_DISPLACEMENT
#define PS_DISPLACEMENT

#ifdef PIXEL_SHADER

#if ( b_iShadingMode == SHADINGMODE_DISPLACEMENT || CPP_SHADER )

#include "ShaderSystem.fx"
#include "PSLighting.fx"
#include "PSCommon.fx"

#define PASS_SINGLEPASS_DISPLACE    0
#define PASS_COPYBACK               1

DECLARE_LAYER_2D( Displacement );
DECLARE_LAYER_2D( DisplacementStrength );

texDecl2D(p_sResult);
texDecl2D(p_sDisplacementSrc);
HALF2       p_vStrength2D;

//--------------------------------------------------------------------------------------------------
HALF4 Displace( in VertexTransport vertOut, inout HALF3 vDeferredNormal, inout HALF3 cDeferredDiffuse, inout HALF3 cDeferredSpecular, inout HALF cDeferredAO, inout HALF cDeferredSpecularPower, inout HALF cDeferredGlossiness ) {
    float3x2    mTriPlanarUVs[c_maxNumLayers];

    if ( b_iDisplacementPass == PASS_SINGLEPASS_DISPLACE ) {
        float3x2 mTriPlanarUVs[c_maxNumLayers];

        SETUP_LAYER( Displacement );
        // Sample normal.
        HALF fStub = 0;
        HALF3 vNormal;
        HALF3 vTextureNormal;
        if ( b_useNormalMapping ) {
            if (b_iDisplacementUseConstantColor)
                vTextureNormal = p_cDisplacementConstantColor;
            else
                vTextureNormal = DecodeTextureNormal( texSampler(p_sDisplacementSampler), texTexture(p_sDisplacementSampler), GetUVEmitter(vertOut, b_iDisplacementUVEmitter, DisplacementLayerConfig.p_vMultiplyAddAlphaTrans.w, DisplacementLayerConfig.p_mUVTransform), fStub );
            vNormal   = TangentToWorld( vTextureNormal, INTERPOLANT_Normal.xyz, INTERPOLANT_Tangent.xyz, INTERPOLANT_Binormal.xyz, false );
        } else {
            vTextureNormal = INTERPOLANT_Normal.xyz;
            vNormal = INTERPOLANT_Normal.xyz;
        }
        vDeferredNormal = INTERPOLANT_Normal.xyz;		// We don't store this deferred normal in the backbuffer, but fresnel migth need it.
                                                        // :TRICKY: Don't use the normal map, but the geometry shape.

        if ( b_iDebugMode == NORMALS_ONLY )
            return HALF4( ( vNormal * 0.5f + 0.5f ), 1.0f );
        if ( b_iDebugMode == NORMALMAP_ONLY )
            return HALF4( ( vTextureNormal * 0.5f + 0.5f ), 1.0f );

        // Sample strength layer.
        SEnvMappings envMappings = ComputeEnvMappings( vertOut, vNormal, INTERPOLANT_EyeToVertex );
        SETUP_LAYER( DisplacementStrength );
        float fStrengthSample = GetLayerColor( DisplacementStrength, 1.0f, false, vDeferredNormal, mTriPlanarUVs ).a;

        if ( b_iDebugMode == FULLBRIGHT_DIFFUSE_ONLY )
            return HALF4( fStrengthSample, fStrengthSample, fStrengthSample, 1.0f );
        // if using vertex colors, then use the vertex alpha as a strength component
        if (b_useVertexAlphaStrength)
             fStrengthSample *= saturate(INTERPOLANT_VertexColor.w);

        // Adjust by depth.
        vNormal = mul( (half3x3)p_mViewTransform, vNormal );            // :TODO: We don't want to do this operation in the pixel shader.
        vNormal = vNormal / INTERPOLANT_ViewPos.y;

        // Calculate displacement UV.
        float2 vUV = GetBackBufferUV( vertOut, true, true );
        float2 vDisplacedUV = vUV + vNormal.xz * p_vStrength2D * fStrengthSample * p_vViewportScale; // * 0.1f;

        // Depth-aware part.
        if ( PIXEL_SHADER_VERSION >= SHADER_VERSION_PS_30 && b_distortionDepthFix ) {
            float4 vNormalDepth = SampleNormalDepth( texSampler(p_sNormalDepthMap), texTexture(p_sNormalDepthMap), vDisplacedUV );
            if ( PIXEL_DEPTH < INTERPOLANT_ViewPos.y )
                vDisplacedUV = vUV;         // We're about to sample from an object in front of the displacement area. In this case, cancel the displacement.
        }

        // Displace.
        return sample2D( p_sDisplacementSrc, vDisplacedUV );
        
    } else if ( b_iDisplacementPass == PASS_COPYBACK ) {
        // Copy back to main buffer.
        float2 vUV = GetBackBufferUV( vertOut, true, true );
        return sample2D( p_sResult, vUV );
    } else return 0;
}

#else
HALF4 Displace( in VertexTransport vertOut, inout HALF3 vDeferredNormal, inout HALF3 cDeferredDiffuse, inout HALF3 cDeferredSpecular, inout HALF cDeferredAO, inout HALF cDeferredSpecularPower, inout HALF cDeferredGlossiness ) { return 0;    }
#endif  // b_iShadingMode == SHADINGMODE_DISPLACEMENT

#endif  // PIXEL_SHADER

#endif  // PS_DISPLACEMENT
