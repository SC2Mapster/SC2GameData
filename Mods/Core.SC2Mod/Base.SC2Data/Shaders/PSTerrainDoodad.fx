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

#include "PSCreep.fx"
#include "PSMaterialDefines.fx"

half4 ApplyDebugRenderMode(VertexTransport vertOut, half4 cResult);

sampler2D   p_sTerrainDiffuse;      // diffuse texture sampler
sampler2D   p_sTerrainNormal;       // normal map sampler


#define c_terrainMinHeight       (-100.f)
#define c_terrainMaxHeight       (100.f)
// assuming 16-bit precision;
#define c_terrainHeightScale     (65535.f/(c_terrainMaxHeight-c_terrainMinHeight))     

DECLARE_LAYER( TerrainAlphaMask );


//--------------------------------------------------------------------------------------------------
void TerrainTextures ( VertexTransport vertOut, out float2 vUV,  out float4 cDiffuse, out float3 vNormal) {
    vUV = Ndc2Tex(INTERPOLANT_TerrainUV.xy);

    // offset uv if pom enabled
    if (b_useParallaxMapping) 
    {
        float3x3 mTangent2World;
        mTangent2World[0] = INTERPOLANT_Tangent.xyz;
        mTangent2World[1] = INTERPOLANT_Binormal.xyz;
        mTangent2World[2] = INTERPOLANT_Normal.xyz;
        if ( b_iUsePOMNew ) {
            float2 vParallaxOffset;
            if (ComputeParallaxOffsetNew(INTERPOLANT_ParallaxVector, vUV, p_sTerrainNormal, CHANNELSELECT_A, false, mTangent2World, vParallaxOffset) ) {
                vUV.xy += vParallaxOffset;
            }
        }
        else {
            float2 vParallaxOffset = ComputeParallaxOffset(INTERPOLANT_ParallaxVector.xy, vUV, p_sTerrainNormal, CHANNELSELECT_A ); //, false, mTangent2World, vParallaxOffset) ) {
            vUV.xy -= vParallaxOffset;
        }
    }

    // get diffuse texture color
    cDiffuse = tex2D(p_sTerrainDiffuse, vUV);

    // get normal from normal texture
    if (b_useNormalMapping) {
        float4 vNormalSample  = tex2D(p_sTerrainNormal, vUV);
        vNormal.xyz = (vNormalSample * 2.0f) - 1.0f;
    } 
    else {
        vNormal.xyz = INTERPOLANT_Normal.xyz;
    }
}

float4 ShadeTerrain (VertexTransport vertOut) {
    if ( b_creepEnabled ) {
        //--------------------------------------------------------------------------------------------------
        // creep
        //--------------------------------------------------------------------------------------------------
        g_vDeferredNormal = 1;
        g_cDeferredDiffuse = 1;
        g_cDeferredSpecular = 1;
	    g_cDeferredSpecularPower = 1;
        
        if (b_iCreepPass == CREEP_OPAQUE)
            return PixelCreepOpaque(vertOut);
        else if (b_iCreepPass == CREEP_TRANSLUCENT)
            return PixelCreepTranslucent(vertOut);
        else
            return PixelCreepAdditiveColor(vertOut);
    } 
    else {
        //--------------------------------------------------------------------------------------------------
        // terrain base
        //--------------------------------------------------------------------------------------------------
        g_vDeferredNormal = 1;
        g_cDeferredDiffuse = 1;
        g_cDeferredSpecular = 1;
	    g_cDeferredSpecularPower = 1;

        if ( b_iSolidColor )
            return float4(1,0,0,1);

        if ( b_computeHeight ) {
            float h = (INTERPOLANT_TerrainUV.x -  c_terrainMinHeight )*(c_terrainHeightScale);

            // assume output format is A8R8G8B8,
            // change clear color CTerrain3MaterialHeightSample::Render() if format is changed
            float g = floor(h/256.f);
            float b = floor(h - g*256.f);
            return float4(0, g/255, b/255, 1.f);
        }
        float2 vUV;
        float4 cDiffuse; 
        float3 vNormal;

        TerrainTextures(vertOut, vUV, cDiffuse, vNormal);
        float3 vWorldNormal;
        if ( b_useNormalMapping )
            vWorldNormal = TangentToWorld( vNormal.xyz, INTERPOLANT_Normal.xyz, INTERPOLANT_Tangent.xyz, INTERPOLANT_Binormal.xyz, true );
        else vWorldNormal = vNormal;

        // lighting
        half3 cLightDiff, cLightSpec, cLightSpec2;
        half4 cShadowColor;
        MainLighting(   vertOut, vWorldNormal, INTERPOLANT_ShadowMapUV, INTERPOLANT_TerrainUV.xy * 512.0f, vUV, p_sTerrainNormal, 
			            1.0f, cLightDiff, cLightSpec, cShadowColor, cLightSpec2 );

        g_vDeferredNormal = vWorldNormal;
        g_cDeferredDiffuse = cDiffuse.xyz;
        g_cDeferredSpecular = cDiffuse.w * p_vSpecularMultiplier_DepthBlendThreshold_HeightMapScale_AlphaFactor.x;

        float4 cResult;
        cResult.xyz = cLightDiff * cDiffuse.rgb + cLightSpec * cDiffuse.a;
        cResult.w = 1;
        
        if(b_iTerrainAlphaMaskLayerEnable) {
            SETUP_LAYER(TerrainAlphaMask);
            SEnvMappings envMappings;
            float4 cColor = GetLayerColor( TerrainAlphaMask, 1.0f, false );
            cResult.xyz *= cColor.xyz;
        }

        // Special debug render modes.
        cResult = ApplyDebugRenderMode( vertOut, cResult );
        

        // Fog.
        if ( b_iDebugMode == NO_DEBUG )
            cResult = ApplyFog( vertOut, cResult, 1.0f );
        
        // Fog of war.
        cResult = ApplyFogOfWar( vertOut, cResult, g_cDeferredDiffuse );


        // DEBUG MODES
        if ( b_iDebugMode != NO_DEBUG ) {
            return DebugColor(  cDiffuse.rgb, cDiffuse.w, 0, vNormal.xyz, vWorldNormal, 
                                cLightDiff, cLightSpec, cShadowColor, INTERPOLANT_VertexColor.r, 1.f, 0.f, 1.f, vertOut, 
                                cResult );
        }

        cResult *= p_vTerrainTint;

        return cResult;
    }
}

#endif  // PIXEL_SHADER

#else 
float4 ShadeTerrain (VertexTransport vertOut) { return 0;   };
#endif  // SHADINGMODE_TERRAIN

#endif  // PS_TERRAIN_MATERIAL_FX
