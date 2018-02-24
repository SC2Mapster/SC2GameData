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
#include "PSDebugUtils.fx"
#include "PSVolume.fx"
#include "PSTerrainDoodad.fx"
#include "PSHalo.fx"
#include "PSReflection.fx"
#include "PSCloaking.fx"

HALF4 MainShading( VertexTransport vertOut, inout HALF3 vDeferredNormal, inout HALF3 cDeferredDiffuse, inout HALF3 cDeferredSpecular, inout HALF  cDeferredAO, 
    inout HALF  cDeferredSpecularPower, inout HALF  cDeferredGlossiness );

float OutputDepth( in VertexTransport vertOut );
HALF4 ApplyDebugRenderMode( VertexTransport vertOut, HALF4 cResult );

float p_fStrobeOffset;
float p_fStrobeSizeRcp;
float p_fStrobeFalloff;
HALF4 p_cHaloColor;

//--------------------------------------------------------------------------------------------------
// Main pixel shader body.
//--------------------------------------------------------------------------------------------------
SPixelOut DefaultPixelMain( in VertexTransportRaw vertRaw ) {
    VertexTransport vertOut;
    InitShader( vertRaw, vertOut );

    SPixelOut result;

    HALF3 vDeferredNormal = 0;
    HALF3 cDeferredDiffuse = 0;
    HALF3 cDeferredSpecular = 0;
    HALF  cDeferredAO = 0;
    HALF  cDeferredSpecularPower = 0;
    HALF  cDeferredGlossiness = 0;

    // Core function.
    result.cColor = MainShading( vertOut, vDeferredNormal, cDeferredDiffuse, cDeferredSpecular, cDeferredAO, cDeferredSpecularPower, cDeferredGlossiness );

    // Currently final color and alpha is always written out, but we can cull out the shader computations.
#if CPP_SHADER
    int temp = b_emitFinalColor;    // Ensure it's not culled away. We always need this one.
    temp = b_iUse8BitHDR;           // Ensure it's not culled away. We always need this one.
    (void)((void*)&(temp));
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
        result.vNormalDepth = EncodeDepthNormal( vDeferredNormal, OutputDepth( vertOut ) );
    #endif
    #if ( b_emitMRTDiffuse == 1 || b_emitMRTAO == 1 )
        result.cDiffuse = 0;
        #if ( b_emitMRTDiffuse == 1 )
            result.cDiffuse         = HALF4( cDeferredDiffuse, result.cColor.a );
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
        #endif
        #if ( b_emitMRTAO == 1 )
            result.cDiffuse.a	= cDeferredAO;
        #endif 
    #endif
    #if( b_emitMRTSpecular == 1 )
        result.cSpecular = HALF4( cDeferredSpecular, result.cColor.a );
        #if( b_emitMRTSpecularPower == 1 )
            result.cSpecular.a = cDeferredSpecularPower;
            if ( b_iUse8BitHDR )
                result.cSpecular.a *= p_vHDRScaling.y;
        #endif
    #endif
    return result;
}

//--------------------------------------------------------------------------------------------------
// This is the default shading function shared by models, particles, ribbons and any other geometries that support
// the full palette of pixel shader effects: material, lighting, special FX materials.
HALF4 MainShading( VertexTransport vertOut, inout HALF3 vDeferredNormal, inout HALF3 cDeferredDiffuse, inout HALF3 cDeferredSpecular, inout HALF  cDeferredAO, 
    inout HALF  cDeferredSpecularPower, inout HALF  cDeferredGlossiness ) {

    vDeferredNormal	= 0;
    cDeferredAO		= 1;
    cDeferredDiffuse  = 1;

#if !defined(COMPILING_SHADER_FOR_OPENGL) && !defined(COMPILING_SHADER_FOR_OPENGL3) && !defined(COMPILING_SHADER_FOR_METAL)
    if (p_iClipPlaneCount > 0) {
        ClipPlanes(INTERPOLANT_HPosAsUV);
    }
#endif

    HALF4 cResult = HALF4(1,1,1,1);
    
    //----------------------------------------------------------------------------------------------
    // standard
    if ( b_iShadingMode == SHADINGMODE_STANDARD && !b_haloPass ) {

        // Can potentially be reused for several layers
        float3x2 mTriPlanarUVs[c_maxNumLayers];
        InitializeTriPlanarUVs(vertOut, mTriPlanarUVs);

        // Apply parallax.
        SETUP_LAYER(Heightmap);
        ApplyParallax( vertOut, texSampler(p_sHeightmapSampler), texTexture(p_sHeightmapSampler), GetUVEmitter(vertOut, b_iNormalUVEmitter, HeightmapLayerConfig.p_vMultiplyAddAlphaTrans.w, HeightmapLayerConfig.p_mUVTransform ) );

        // Decode normal.
        vDeferredNormal = DecodeNormal( vertOut );
        if( b_iNormalBlending ) {
            vDeferredNormal = NormalBlending( vertOut, vDeferredNormal, mTriPlanarUVs );
        }
                
        // Decode ambient occlusion layer.
        HALF fAmbientOcclusion;
        if ( 1 )
            fAmbientOcclusion = DecodeAOValue( vertOut, vDeferredNormal, cDeferredAO, mTriPlanarUVs );
        else fAmbientOcclusion = 0;

        // Decode soft shadow noise UV.
        HALF2 softShadowUV = DecodeSoftShadowUV( vertOut );
        
        // Determine specular gloss
        HALF fSpecularity = MaterialSpecularity( vertOut, vDeferredNormal, cDeferredGlossiness, mTriPlanarUVs );
        cDeferredSpecularPower = fSpecularity;
        
        // Lighting.
        HALF3 cLightDiffuse;
        HALF3 cLightSpecular;
        HALF3 cLightSpecular2;
        HALF4 cShadowColor;
        HALF4 cLightingRegionMap;
        MainLighting(   vertOut, vDeferredNormal, 
                        INTERPOLANT_ShadowMapUV, softShadowUV, 
                        GetUVEmitter(vertOut, b_iHeightmapUVEmitter, HeightmapLayerConfig.p_vMultiplyAddAlphaTrans.w, HeightmapLayerConfig.p_mUVTransform ).xy,
                        texSampler(p_sHeightmapSampler), texTexture(p_sHeightmapSampler), fAmbientOcclusion, fSpecularity,
                        cLightDiffuse, cLightSpecular, cShadowColor, cLightSpecular2, cLightingRegionMap );  // <-- output - fed in to material and fog
                
        // Material.
        cResult = MaterialColor( vertOut, vDeferredNormal, 
                                        cLightDiffuse, cLightSpecular, cShadowColor, fSpecularity, cLightingRegionMap,
                                        vDeferredNormal, cDeferredDiffuse, cDeferredSpecular, fAmbientOcclusion, cDeferredSpecularPower, 
                                        cDeferredGlossiness, mTriPlanarUVs );  // <-- output

        if ( b_useLighting == 0 ) {
            cDeferredDiffuse = 0;
            cDeferredSpecular = 0;
            cDeferredSpecularPower = 1;
        }

        // Special debug render modes.
        cResult = ApplyDebugRenderMode( vertOut, cResult );

        // Fog.
        if ( b_iDebugMode == NO_DEBUG && b_iDebugRenderMode == NO_DEBUG_RENDER_MODE )
            cResult.rgb = ApplyFog( vertOut, cResult, 1.0f, cLightingRegionMap );
        
        // Fog of war.
        if ( b_iDebugMode == NO_DEBUG && b_iDebugRenderMode == NO_DEBUG_RENDER_MODE && b_emitFinalColor )
            cResult.rgb = ApplyFogOfWar( vertOut, cResult, cDeferredDiffuse );
            
        if ( b_iUse8BitHDR )
            cResult.rgb *= p_vHDRScaling.x;

        if ( b_iDebugMode == NO_DEBUG && b_iDebugRenderMode == NO_DEBUG_RENDER_MODE )
            if (b_iWriteFogDensityIntoRed!=0)
                cResult.r = saturate(INTERPOLANT_FogColor.w);
        
    } else if (b_haloPass) {
        cResult = GetHaloColor( GetBackBufferUV(vertOut, true, true), p_cHaloColor, p_fStrobeOffset, p_fStrobeSizeRcp, p_fStrobeFalloff );
            
    //----------------------------------------------------------------------------------------------
    // terrain
    } else if (b_iShadingMode == SHADINGMODE_TERRAIN) {
        cResult = ShadeTerrain(vertOut, vDeferredNormal, cDeferredDiffuse, cDeferredSpecular, cDeferredAO, cDeferredSpecularPower, cDeferredGlossiness);
        if ( b_iUse8BitHDR && !b_computeHeight && !b_no8BitHDR)
            cResult.rgb *= p_vHDRScaling.x;

    //----------------------------------------------------------------------------------------------
    // displacement
    } else if ( b_iShadingMode == SHADINGMODE_DISPLACEMENT) {
        vDeferredNormal = DecodeNormal( vertOut);
        cResult = Displace( vertOut, vDeferredNormal, cDeferredDiffuse, cDeferredSpecular, cDeferredAO, cDeferredSpecularPower, cDeferredGlossiness );
        
    //----------------------------------------------------------------------------------------------
    // vector ui
    } else if (b_iShadingMode == SHADINGMODE_VECTORUI) {
        cResult =  VectorUI(vertOut);
        if ( b_iUse8BitHDR )
            cResult.rgb *= p_vHDRScaling.x;

    //----------------------------------------------------------------------------------------------
    } else if ( b_iShadingMode == SHADINGMODE_VOLUME) {
        cResult = Volume(vertOut, vDeferredNormal, cDeferredDiffuse, cDeferredSpecular, cDeferredAO, cDeferredSpecularPower, cDeferredGlossiness);
    } else if ( b_iShadingMode == SHADINGMODE_MODEL_TRIANGLE_ID) {
        cResult = INTERPOLANT_VertexColor;
    //----------------------------------------------------------------------------------------------
    } else if( b_iShadingMode == SHADINGMODE_REFLECTION ) {
        cResult = Reflection( vertOut, vDeferredNormal, cDeferredDiffuse, cDeferredSpecular, cDeferredAO, cDeferredSpecularPower, cDeferredGlossiness );
    } else if( b_iShadingMode == SHADINGMODE_CLOAKING ) {
        cResult = Cloaking( vertOut, vDeferredNormal, cDeferredDiffuse, cDeferredSpecular, cDeferredAO, cDeferredSpecularPower, cDeferredGlossiness );
    }

    AlphaTest(cResult.a);

    return cResult;
}

//--------------------------------------------------------------------------------------------------
HALF4 ApplyDebugRenderMode( VertexTransport vertOut, HALF4 cResult ) {
    // Special debug modes.
    if (b_iDebugRenderMode == RENDER_NO_HITTESTTIGHT_MODE) {
        float fCheck = 0;
        if (b_iDiffuseLayerEnable && !b_iDiffuseUseConstantColor) {
            // Red/blue stripes
            fCheck = (frac(GetUVEmitter(vertOut, b_iDiffuseUVEmitter, 0, float2x4(0,0,0,0,0,0,0,0)).x * 8.0f) > 0.5f);
        }
        return cResult + 0.5f * lerp(HALF4(1.0f, 0.0f, 0.0f, 0.0f), HALF4(0.0f, 0.0f, 1.0f, 0.0f), fCheck);
    }

    if (b_iDebugRenderMode == RENDER_NO_HITTESTFUZZY_MODE) {
        float fCheck = 0;
        if (b_iDiffuseLayerEnable && !b_iDiffuseUseConstantColor) {
            // Red/green stripes
            fCheck = (frac(GetUVEmitter(vertOut, b_iDiffuseUVEmitter, 0, float2x4(0,0,0,0,0,0,0,0)).x * 8.0f) > 0.5f);
        }
        return cResult + 0.5f * lerp(HALF4(1.0f, 0.0f, 0.0f, 0.0f), HALF4(0.0f, 1.0f, 0.0f, 0.0f), fCheck);
    }
    if ( b_iDebugRenderMode == RENDER_TANGENTS_MODE ) {
        cResult = INTERPOLANT_VertexColor;
    }
    return cResult;
}

//--------------------------------------------------------------------------------------------------
HALF4 EmitPSFogColor( VertexTransportRaw vertOut ) {
    // If we get here must have no triplanars
    return HALF4(float3(0,0,0), FogDensity( INTERPOLANT_WorldPos ) );
}

//--------------------------------------------------------------------------------------------------
float3  EmitPSViewPos (VertexTransportRaw vertOut) {
    return mul(INTERPOLANT_WorldPos, p_mViewTransform);
}

//--------------------------------------------------------------------------------------------------
float3  EmitPSEyeToVertex (VertexTransportRaw vertOut) {
    return normalize(INTERPOLANT_WorldPos - p_vEyePos);
}

//--------------------------------------------------------------------------------------------------
HALF3  EmitPSHalfVec (VertexTransportRaw vertOut) {
    return ComputeHalfVector(INTERPOLANT_WorldPos, p_directionalLights[0].vDirection);
}

#endif  // PIXEL_SHADER

#endif  // PS_MAINSHADING
