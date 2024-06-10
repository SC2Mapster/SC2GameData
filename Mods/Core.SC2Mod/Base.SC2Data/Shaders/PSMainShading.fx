//==================================================================================================
//
// Copyright Blizzard Entertainment 2003-2005
//
// This is the default shading function.
//==================================================================================================

#ifndef PS_MAINSHADING
#define PS_MAINSHADING

#ifdef PIXEL_SHADER

#include "ShaderSystem.fx"
#include "MaterialDefines.fx"
#include "PSLighting.fx"
#include "PSMaterial.fx"
#include "PSDisplacement.fx"
#include "PSFog.fx"
#include "PSVectorUI.fx"
#include "PSParallax.fx"
#include "PsDebugUtils.fx"
#include "PSVolume.fx"
#include "PSTerrainDoodad.fx"

half4 MainShading( in VertexTransport vertOut );
float OutputDepth( in VertexTransport vertOut );
half4 ApplyDebugRenderMode( VertexTransport vertOut, half4 cResult );

//--------------------------------------------------------------------------------------------------
// Main pixel shader body.
//--------------------------------------------------------------------------------------------------
SPixelOut DefaultPixelMain( in VertexTransport vertOut ) {
    InitShader( vertOut );
	                                                        
    SPixelOut result;
    
    // Core function.
    result.cColor = MainShading( vertOut );

    // Currently final color and alpha is always written out, but we can cull out the shader computations.
#if CPP_SHADER
    int temp = b_emitFinalColor;    // Ensure it's not culled away. We always need this one.
    temp = b_iUse8BitHDR;           // Ensure it's not culled away. We always need this one.
    ref( temp );
#endif

    #if ( b_emitFinalColor == 0 )
        result.cColor.rgb = 1;
    #endif
    #if ( b_emitAlpha == 0 )
        result.cColor.a = 1;
    #endif

    #if ( CPP_SHADER || b_emitMRTDepth == 1 || b_emitMRTNormal == 1 )
		// In case one is missing but the other is present, initialize both to 0 so the compiler doesn't complain.
		result.vNormalDepth = 0;
		result.vNormalDepth.a = result.cColor.a;
        result.vNormalDepth = EncodeDepthNormal( g_vDeferredNormal, OutputDepth( vertOut ) );
    #endif
    #if ( b_emitMRTDiffuse == 1 )
        result.cDiffuse         = half4( g_cDeferredDiffuse, result.cColor.a );
        #if ( b_blendMRTNormals == 1 )
            // This is for terrain.
            // Terrain renders a depth pass first with depth only, then blends in multiple layers with no depth write.
            // The terrain normals and colors are blended in the deferred buffers, so we replicate the alpha
            // component for the normal buffer - alpha color write is off so depth, which is stored in the normal
            // buffer's alpha, will be preserved.
            // Blending normals is not really correct - terrain version 4 may allow us to improve this.
			// :NOTE: Assuming we are in HDR mode here. In non-HDR we would not have 4 components available.
			result.vNormalDepth.a = result.cColor.a;
		#endif
		#if ( b_emitMRTAO == 1 )
			result.cDiffuse.a	= g_cDeferredAO;
		#endif 
    #endif
	#if( b_emitMRTSpecular == 1 )
		result.cSpecular = half4( g_cDeferredSpecular, result.cColor.a );
		#if( b_emitMRTSpecularPower == 1 )
			result.cSpecular.a = g_cDeferredSpecularPower;
            if ( b_iUse8BitHDR )
                result.cSpecular.a *= 0.01f;
		#endif
	#endif
    return result;
}

//--------------------------------------------------------------------------------------------------
// This is the default shading function shared by models, particles, ribbons and any other geometries that support
// the full palette of pixel shader effects: material, lighting, special FX materials.
half4 MainShading( VertexTransport vertOut ) {
    g_vDeferredNormal	= 0;
    g_cDeferredAO		= 1;
    g_cDeferredDiffuse  = 1;
    
    //----------------------------------------------------------------------------------------------
    // standard
    if ( b_iShadingMode == SHADINGMODE_STANDARD || b_iShadingMode == SHADINGMODE_HALOFILL ) {

        // Apply parallax.
        ApplyParallax( vertOut, p_sHeightmapSampler);
    
        // Decode normal.
        g_vDeferredNormal = DecodeNormal( vertOut );
		        
        // Decode ambient occlusion layer.
        half fAmbientOcclusion;
        if ( b_useLighting )
            fAmbientOcclusion = DecodeAOValue( vertOut );
        else fAmbientOcclusion = 0;

        // Decode soft shadow noise UV.
        half2 softShadowUV = DecodeSoftShadowUV( vertOut );
        
        // Lighting.
        half3 cLightDiffuse;
        half3 cLightSpecular;
        half3 cLightSpecular2;
        half4 cShadowColor;
        MainLighting(   vertOut, g_vDeferredNormal, 
                        INTERPOLANT_ShadowMapUV, softShadowUV, 
                        GetUVEmitter(vertOut, b_iHeightmapUVEmitter).xy, p_sHeightmapSampler, 
                        fAmbientOcclusion, 
                        cLightDiffuse, cLightSpecular, cShadowColor, cLightSpecular2 );  // <-- output - fed in to material.
		        
        // Material.
        half4 cResult = MaterialColor( vertOut, g_vDeferredNormal, 
                                        cLightDiffuse, cLightSpecular, cShadowColor, 
										g_cDeferredDiffuse, g_cDeferredSpecular, g_cDeferredSpecularPower );  // <-- output

        if ( b_useLighting == 0 ) {
            g_cDeferredDiffuse = 0;
            g_cDeferredSpecular = 0;
            g_cDeferredSpecularPower = 1;
        }

        // Special debug render modes.
        cResult = ApplyDebugRenderMode( vertOut, cResult );

        // Fog.
        if ( b_iDebugMode == NO_DEBUG && b_iDebugRenderMode == NO_DEBUG_RENDER_MODE )
            cResult = ApplyFog( vertOut, cResult, 1.0f );
        
        // Fog of war.
        if ( b_iDebugMode == NO_DEBUG && b_iDebugRenderMode == NO_DEBUG_RENDER_MODE )
            cResult = ApplyFogOfWar( vertOut, cResult, g_cDeferredDiffuse );

        if ( b_iShadingMode == SHADINGMODE_HALOFILL)
            cResult.rgb = half3( 1.0f, 1.0f, 1.0f );    // Just keep the alpha
        else if ( b_iUse8BitHDR )
            cResult.rgb *= 0.5f;
        return cResult;

    //----------------------------------------------------------------------------------------------
    // terrain
    } else if (b_iShadingMode == SHADINGMODE_TERRAIN) {
        float4 cResult = ShadeTerrain(vertOut);
        if ( b_iUse8BitHDR && !b_computeHeight && !b_no8BitHDR)
            cResult.rgb *= 0.5f;
        return cResult;

    //----------------------------------------------------------------------------------------------
    // displacement
    } else if ( b_iShadingMode == SHADINGMODE_DISPLACEMENT) {
        g_vDeferredNormal = DecodeNormal( vertOut );
        return Displace( vertOut );
        
    //----------------------------------------------------------------------------------------------
    // vector ui
    } else if (b_iShadingMode == SHADINGMODE_VECTORUI) {
        float4 cResult =  VectorUI(vertOut);
        if ( b_iUse8BitHDR )
            cResult.rgb *= 0.5f;
        return cResult;

    //----------------------------------------------------------------------------------------------
    } else if ( b_iShadingMode == SHADINGMODE_VOLUME) {
        return Volume(vertOut);
    } else if ( b_iShadingMode == SHADINGMODE_MODEL_TRIANGLE_ID) {
        return INTERPOLANT_VertexColor;
    //----------------------------------------------------------------------------------------------
    } else
        return 1;
}

//--------------------------------------------------------------------------------------------------
half4 ApplyDebugRenderMode( VertexTransport vertOut, half4 cResult ) {
    // Special debug modes.
    if (b_iDebugRenderMode == RENDER_NO_HITTESTTIGHT_MODE) {
        float fCheck = 0;
        if (b_iDiffuseLayerEnable && !b_iDiffuseUseConstantColor) {
            // Red/blue stripes
            fCheck = (frac(GetUVEmitter(vertOut, b_iDiffuseUVEmitter).x * 8.0f) > 0.5f);
        }
        return cResult + 0.5f * lerp(half4(1.0f, 0.0f, 0.0f, 0.0f), half4(0.0f, 0.0f, 1.0f, 0.0f), fCheck);
    }

    if (b_iDebugRenderMode == RENDER_NO_HITTESTFUZZY_MODE) {
        float fCheck = 0;
        if (b_iDiffuseLayerEnable && !b_iDiffuseUseConstantColor) {
            // Red/green stripes
            fCheck = (frac(GetUVEmitter(vertOut, b_iDiffuseUVEmitter).x * 8.0f) > 0.5f);
        }
        return cResult + 0.5f * lerp(half4(1.0f, 0.0f, 0.0f, 0.0f), half4(0.0f, 1.0f, 0.0f, 0.0f), fCheck);
    }
    if ( b_iDebugRenderMode == RENDER_TANGENTS_MODE ) {
        cResult = INTERPOLANT_VertexColor;
    }
    return cResult;
}

#endif  // PIXEL_SHADER

#endif  // PS_MAINSHADING