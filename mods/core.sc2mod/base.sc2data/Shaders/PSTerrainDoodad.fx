//==================================================================================================
//
// Copyright Blizzard Entertainment 2003-2008
//
// This is shader for rendering terrain and models using terrain textures
//==================================================================================================

#ifndef PS_TERRAIN_MATERIAL_FX
#define PS_TERRAIN_MATERIAL_FX

#if (b_iShadingMode == SHADINGMODE_TERRAIN || CPP_SHADER)
#ifdef PIXEL_SHADER

// tint terrain and creep
float4      p_vTerrainTint;

DECLARE_LAYER_2D( TerrainAlphaMask );

#include "PSCreep.fx"
#include "PSMaterialDefines.fx"

HALF4 ApplyDebugRenderMode(VertexTransport vertOut, HALF4 cResult);

texDecl2D(p_sTerrainDiffuse);      // diffuse texture sampler
texDecl2D(p_sTerrainNormal);       // normal map sampler
texDecl2D(p_sVisualization);       // visualization texture sampler


// assuming 16-bit precision;
#define c_terrainHeightScale     (65535.f/(c_terrainMaxHeight-c_terrainMinHeight))     



//--------------------------------------------------------------------------------------------------
void TerrainTextures ( VertexTransport vertOut, out float2 vUV,  out float4 cDiffuse, out float3 vNormal) {
    vUV = Ndc2Tex(INTERPOLANT_TerrainUV.xy);

    // offset uv if pom enabled
    if (b_useParallaxMapping) {
        float3x3 mTangent2World;
        mTangent2World[0] = INTERPOLANT_Tangent.xyz;
        mTangent2World[1] = INTERPOLANT_Binormal.xyz;
        mTangent2World[2] = INTERPOLANT_Normal.xyz;
        if ( b_iUsePOMNew ) {
            float2 vParallaxOffset;
            if (ComputeParallaxOffsetNew(INTERPOLANT_ParallaxVector, vUV, texSampler(p_sTerrainNormal), texTexture(p_sTerrainNormal), CHANNELSELECT_A, false, mTangent2World, vParallaxOffset) ) {
                vUV.xy += vParallaxOffset;
            }
        }
        else {
            float2 vParallaxOffset = ComputeParallaxOffset(INTERPOLANT_ParallaxVector.xy, vUV, texSampler(p_sTerrainNormal), texTexture(p_sTerrainNormal), CHANNELSELECT_A ); //, false, mTangent2World, vParallaxOffset) ) {
            vUV.xy -= vParallaxOffset;
        }
    }

    // get diffuse texture color
    cDiffuse = sample2D(p_sTerrainDiffuse, vUV);

    // get normal from normal texture
    if (b_useNormalMapping) {
        float4 vNormalSample  = sample2D(p_sTerrainNormal, vUV);
        vNormal.xyz = (vNormalSample * 2.0f) - 1.0f;
    } 
    else {
        vNormal.xyz = INTERPOLANT_Normal.xyz;
    }
}

//--------------------------------------------------------------------------------------------------
// creep
//--------------------------------------------------------------------------------------------------
float4 ShadeTerrain_Creep (VertexTransport vertOut, inout HALF3 vDeferredNormal, inout HALF3 cDeferredDiffuse, inout HALF3 cDeferredSpecular, inout HALF cDeferredAO,
    inout HALF cDeferredSpecularPower, inout HALF cDeferredGlossiness) {
        if (b_iCreepPass == CREEP_OPAQUE)
            return PixelCreepOpaque(vertOut, vDeferredNormal, cDeferredDiffuse, cDeferredSpecular, cDeferredSpecularPower);
        else if (b_iCreepPass == CREEP_TRANSLUCENT)
            return PixelCreepTranslucent(vertOut, vDeferredNormal, cDeferredDiffuse, cDeferredSpecular, cDeferredSpecularPower);
        else
            return PixelCreepAdditiveColor(vertOut, vDeferredNormal, cDeferredDiffuse, cDeferredSpecular, cDeferredSpecularPower);
}

//--------------------------------------------------------------------------------------------------
// terrain base
//--------------------------------------------------------------------------------------------------
float4 ShadeTerrain_TerrainBase (VertexTransport vertOut, inout HALF3 vDeferredNormal, inout HALF3 cDeferredDiffuse, inout HALF3 cDeferredSpecular, inout HALF cDeferredAO,
    inout HALF cDeferredSpecularPower, inout HALF cDeferredGlossiness) {
        float3x2 mTriPlanarUVs[c_maxNumLayers];

        float2 vUV;
        float4 cDiffuse; 
        float3 vNormal;

        TerrainTextures(vertOut, vUV, cDiffuse, vNormal);

        float3 vWorldNormal;
        if ( b_useNormalMapping )
            vWorldNormal = TangentToWorld( vNormal.xyz, INTERPOLANT_Normal.xyz, INTERPOLANT_Tangent.xyz, INTERPOLANT_Binormal.xyz, true );
        else vWorldNormal = vNormal;

        // lighting
        HALF3 cLightDiff, cLightSpec, cLightSpec2;
        HALF4 cShadowColor;
        HALF4 cLightingRegionMap;

        HALF fAmbientOcclusion = 1.0f;
        if ( b_iUseDynamicAO ) {
            fAmbientOcclusion = saturate(sample2D( p_sSSAO, GetBackBufferUV( vertOut, true, true ) ).a);
        }
        MainLighting(   vertOut, vWorldNormal, INTERPOLANT_ShadowMapUV, INTERPOLANT_TerrainUV.xy * 512.0f, vUV, texSampler(p_sTerrainNormal), texTexture(p_sTerrainNormal), 
			            fAmbientOcclusion, p_vSpecColorSpecularity.w, cLightDiff, cLightSpec, cShadowColor, cLightSpec2, cLightingRegionMap );

        vDeferredNormal = vWorldNormal;
        cDeferredDiffuse = cDiffuse.xyz;
        cDeferredSpecular = cDiffuse.w * p_vSpecularMultiplier_DepthBlendThreshold_HeightMapScale_AlphaFactor.x;

        float4 cResult;
        cResult.xyz = cLightDiff * cDiffuse.rgb + cLightSpec * cDiffuse.a;
        cResult.w = 1;
        
        if ( b_useVertexColors )
            cResult.rgb *= saturate(INTERPOLANT_VertexColor.xyz);
        
        if(b_iTerrainAlphaMaskLayerEnable) {
            SETUP_LAYER(TerrainAlphaMask);
            SEnvMappings envMappings;
            float3x2 mTriPlanarUVs[c_maxNumLayers];
            float4 cColor = GetLayerColor( TerrainAlphaMask, 1.0f, false, vDeferredNormal, mTriPlanarUVs );
            cResult.w *= cColor.w;
        }

        // Special debug render modes.
        cResult = ApplyDebugRenderMode( vertOut, cResult );
        

        // Fog.
        if ( b_iDebugMode == NO_DEBUG )
            cResult = ApplyFog( vertOut, cResult, 1.0f, cLightingRegionMap );
        
        // Fog of war.
        if ( b_emitFinalColor )
            cResult = ApplyFogOfWar( vertOut, cResult, cDeferredDiffuse );


        // DEBUG MODES
        if ( b_iDebugMode != NO_DEBUG ) {
            float ao = 1;
            #if (b_useLighting && b_iVertexLightingMode)
                ao = INTERPOLANT_VectorUI1.a;
            #endif

            return DebugColor(  cDiffuse.rgb, cDiffuse.w, 0, vNormal.xyz, vWorldNormal, 
                                cLightDiff, cLightSpec, cShadowColor, ao, 1.f, 0.f, 1.f, vertOut, 
                                cResult, 0.0f, p_vSpecColorSpecularity.w, cLightingRegionMap );
        }

        if (b_iUseVisualization)
            cResult = sample2D(p_sVisualization, Ndc2Tex(INTERPOLANT_FOWUV.xy, true ));

        if (b_iBlockVisualization)
            cResult = sample2D(p_sVisualization, Ndc2Tex(INTERPOLANT_TerrainUV.xy));

        cResult *= p_vTerrainTint;

        return cResult;
}


//--------------------------------------------------------------------------------------------------
// terrain pixel shader main entry
//--------------------------------------------------------------------------------------------------
float4 ShadeTerrain (VertexTransport vertOut, inout HALF3 vDeferredNormal, inout HALF3 cDeferredDiffuse, inout HALF3 cDeferredSpecular, inout HALF cDeferredAO, inout HALF cDeferredSpecularPower, inout HALF cDeferredGlossiness) {
    vDeferredNormal = 1;
    cDeferredDiffuse = 1;
    cDeferredSpecular = 1;
    cDeferredSpecularPower = 1;

    if (b_iSolidColor) {
        vDeferredNormal = normalize(INTERPOLANT_Normal.xyz);
        return float4(1,0,0,1);
    }
    else if ( b_computeHeight ) {
        float h = (INTERPOLANT_TerrainUV.x -  c_terrainMinHeight )*(c_terrainHeightScale);

        // assume output format is A8R8G8B8,
        // change clear color CTerrain3MaterialHeightSample::Render() if format is changed
        float g = floor(h/256.f);
        float b = floor(h - g*256.f);
        return float4(0, g/255, b/255, 1.f);
    }
    else if ( b_creepEnabled ) {
        return ShadeTerrain_Creep(vertOut, vDeferredNormal, cDeferredDiffuse, cDeferredSpecular, cDeferredAO, cDeferredSpecularPower, cDeferredGlossiness);
    } 
    else {
        return ShadeTerrain_TerrainBase(vertOut, vDeferredNormal, cDeferredDiffuse, cDeferredSpecular, cDeferredAO, cDeferredSpecularPower, cDeferredGlossiness);
    }
}

#endif  // PIXEL_SHADER

#else 
float4 ShadeTerrain (VertexTransport vertOut, inout HALF3 vDeferredNormal, inout HALF3 cDeferredDiffuse, inout HALF3 cDeferredSpecular, inout HALF cDeferredAO, inout HALF cDeferredSpecularPower, inout HALF cDeferredGlossiness) { return 0;   };
#endif  // SHADINGMODE_TERRAIN

#endif  // PS_TERRAIN_MATERIAL_FX
