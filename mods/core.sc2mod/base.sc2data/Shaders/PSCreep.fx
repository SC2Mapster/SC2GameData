//==================================================================================================
//
// Copyright Blizzard Entertainment 2003-2007
//
// Terrain2 shader template.
//==================================================================================================

#ifndef PS_CREEP
#define PS_CREEP

#ifdef PIXEL_SHADER

#include "ShaderSystem.fx"
#include "PSCommon.fx"
#include "PSDebugUtils.fx"
#include "PSUtils.fx"
#include "PSFog.fx"

// :TODO: Duplicate?
float4x4 p_mWorldViewProj;  // World * View * Projection transformation

// creep samplers
texDecl2D(p_sCreepGameCoverage);
texDecl2D(p_sCreepEdgeNormalMapAndAlphaMultiplier);
texDecl2D(p_sCreepDiffuseColor);
texDecl2D(p_sCreepInteriorNormalMap);
texDecl2D(p_sCreepSpecularMask);
texDecl2D(p_sCreepGroundNormalMap);

// creep params
float4   p_vCreepTransparentRampConstants;       //0.09, 1.0f/0.09f
float2   p_vCreepBaseTextureTiling;              //10, 10
float2   p_vCreepBaseNormalMapTiling;            //10, 10
float2   p_vCreepEdgeNormalMapTiling;            //3, 3
float2   p_vEdgeNormalMapRampConstants;          //0.74, 4
float3   p_cTransparentTintColor;
float3   p_cCreepDiffuseTintColor;               // tints the diffuse color
float    p_fCreepOpaqueAlphaThreshold;           //0.18
float3   p_cTransparentEmissiveColor;
float4   p_cCreepAdditiveColor;
float2   p_vCreepHeightRamp;
float3   p_vCreepTriPlanarScale;
float    p_vfCreepGroundNormalBlend;
float4x4 p_mCreepGroundTextureMatrix;
#if !CPP_SHADER
float4   p_vCreepTextureRotation;
#endif

// should match ECreepOutputMode
#define CREEP_OUTPUT_DIFFUSE_ONLY   0
#define CREEP_OUTPUT_NORMALS_ONLY   1
#define CREEP_OUTPUT_COMPLETE       2
#define CREEP_OUTPUT_STENCIL_ONLY   3   // output just 1 or 0 for writing to the stencil buffer

// should match ECreepPass
#define CREEP_OPAQUE                0
#define CREEP_TRANSLUCENT           1
#define CREEP_ADDITIVE_COLOR        2

//--------------------------------------------------------------------------------------------------
void GetCreepTextureUV (VertexTransport vertOut, float2 tiling, out float2 uvs[3]) {
    // if use tri planar blending
    if (b_iTriPlanarCreep) {
        float3 vScaledPos = INTERPOLANT_WorldPos.xyz*p_vCreepTriPlanarScale;
        float3 vNormal = INTERPOLANT_Normal.xyz;
        float3 s = sign(vNormal);
        uvs[0] = vScaledPos.xy * float2(s.z, -1.f) * tiling;
        uvs[1] = vScaledPos.xz * float2(-s.y, -1.f) * tiling.x;    // FIXME, expose z tiling too
        uvs[2] = vScaledPos.yz * float2(s.x, -1.f) * tiling.yx;
#if COMPILING_SHADER_WITH_BSL
        uvs[0] = mul(float2x2(p_vCreepTextureRotation.x, p_vCreepTextureRotation.y, p_vCreepTextureRotation.z, p_vCreepTextureRotation.w), uvs[0]);
        uvs[1] = mul(float2x2(p_vCreepTextureRotation.x, p_vCreepTextureRotation.y, p_vCreepTextureRotation.z, p_vCreepTextureRotation.w), uvs[1]);
        uvs[2] = mul(float2x2(p_vCreepTextureRotation.x, p_vCreepTextureRotation.y, p_vCreepTextureRotation.z, p_vCreepTextureRotation.w), uvs[2]);
#else
        uvs[0] = mul(float2x2(p_vCreepTextureRotation), uvs[0]);
        uvs[1] = mul(float2x2(p_vCreepTextureRotation), uvs[1]);
        uvs[2] = mul(float2x2(p_vCreepTextureRotation), uvs[2]);
#endif
    }
    else {
        uvs[0] = INTERPOLANT_TerrainUV.zw * tiling;
        uvs[1] = 0;
        uvs[2] = 0;
    }
}

//--------------------------------------------------------------------------------------------------
float4 SampleCreepTexture (typeSampler2D sCreep, typeTexture2D tCreep, float2 uvs[3], VertexTransport vertOut) {
    if (b_iTriPlanarCreep) {
        return SampleTriPlanarTexture(sCreep, tCreep, uvs[0], uvs[1], uvs[2], INTERPOLANT_TriPlanarWeights.xyz);
    }
    else {
        return sampleTex2D(tCreep, sCreep, uvs[0].xy);
    }
}

//--------------------------------------------------------------------------------------------------
float4 SampleGroundTexture (typeSampler2D sGround, typeTexture2D tGround, VertexTransport vertOut) {
    float2 vUV = mul(float4(INTERPOLANT_WorldPos.xyz, 1), p_mCreepGroundTextureMatrix).xy;
    vUV = Ndc2Tex(vUV);
    return sampleTex2D(tGround, sGround, vUV);
}

//--------------------------------------------------------------------------------------------------
float4 PixelCreepGeneric( VertexTransport vertOut, bool useSpecular, inout HALF4 cLightingRegionMap, inout HALF3 vDeferredNormal, inout HALF3 cDeferredDiffuse, inout HALF3 cDeferredSpecular, inout HALF cDeferredSpecularPower ) {
    float3x2 mTriPlanarUVs[c_maxNumLayers];
    float4 output;

    // INTERPOLANT_TerrainUV.xy covers the entire map
    // INTERPOLANT_TerrainUV.zw is the rotated INTERPOLANT_TerrainUV.xy
    float4 coverageUV  = HALF4( INTERPOLANT_TerrainUV.xy, 0, 0 );
    float2 baseUV[3], normalUV[3], edgeUV[3];
    GetCreepTextureUV(vertOut, p_vCreepBaseTextureTiling, baseUV);
    GetCreepTextureUV(vertOut, p_vCreepBaseNormalMapTiling, normalUV);
    GetCreepTextureUV(vertOut, p_vCreepEdgeNormalMapTiling, edgeUV);

    // use material system if enabled
    float4 creepGameCoverageSample = 1;
    if ( b_iTerrainAlphaMaskLayerEnable ) {
        SETUP_LAYER(TerrainAlphaMask);
        SEnvMappings envMappings;
        float3x2 mTriPlanarUVs[c_maxNumLayers];
        creepGameCoverageSample = GetLayerColor( TerrainAlphaMask, 1.0f, false, vDeferredNormal, mTriPlanarUVs );
    } 
    
    creepGameCoverageSample *= sample2D(p_sCreepGameCoverage, coverageUV.xy);

    float4 diffuseColorSample = SampleCreepTexture(texSampler(p_sCreepDiffuseColor), texTexture(p_sCreepDiffuseColor), baseUV, vertOut);
    diffuseColorSample.xyz *= p_cCreepDiffuseTintColor.xyz;

    // preserve alpha from the diffuse texture
    creepGameCoverageSample.a *= diffuseColorSample.w;

    float4 edgeNormalMapAndAlphaMultiplierSample = SampleCreepTexture(texSampler(p_sCreepEdgeNormalMapAndAlphaMultiplier), texTexture(p_sCreepEdgeNormalMapAndAlphaMultiplier), edgeUV, vertOut);
    edgeNormalMapAndAlphaMultiplierSample.xyz = DecodeNormal(edgeNormalMapAndAlphaMultiplierSample.xyz);

    // height edge factor
    float heightFactor = 1;
    if (b_iTriPlanarCreep) {
        heightFactor = 1 - saturate((INTERPOLANT_WorldPos.z - p_vCreepHeightRamp.x) * p_vCreepHeightRamp.y);
    }

    // slope factor
    float slopeFactor = 1;
    if (!b_iTriPlanarCreep) {
        slopeFactor = INTERPOLANT_FOWUV.z;
    }

    // compute edge factor
    float edgeFactor = saturate((creepGameCoverageSample.a - p_vEdgeNormalMapRampConstants.x) * p_vEdgeNormalMapRampConstants.y);

    HALF3 worldNormal;    
    float3 pixelNormalSample;
    if (b_useNormalMapping) {
        // sample creep normal texture
        pixelNormalSample = SampleCreepTexture(texSampler(p_sCreepInteriorNormalMap), texTexture(p_sCreepInteriorNormalMap), normalUV, vertOut).xyz;
        pixelNormalSample.xyz = DecodeNormal(pixelNormalSample.xyz);
        
        // sample ground normal texture
        if (b_iCreepUseGroundNormalMap) {
            float2 groundNormalSample = DecodeNormal( SampleGroundTexture(texSampler(p_sCreepGroundNormalMap), texTexture(p_sCreepGroundNormalMap), vertOut).xyy).xy;
            pixelNormalSample.xy = pixelNormalSample.xy + groundNormalSample * p_vfCreepGroundNormalBlend;

            // Not important enough visually for the cost, at this time.
            //  Fallback on the normalize after the edge normal map lerp instead.
            //pixelNormalSample.xyz = normalize( pixelNormalSample.xyz );
        }

        
        pixelNormalSample.xyz = normalize(lerp(edgeNormalMapAndAlphaMultiplierSample.xyz, pixelNormalSample.xyz, edgeFactor*heightFactor));

        if (b_iCreepOutputMode == CREEP_OUTPUT_NORMALS_ONLY) {
            worldNormal = (pixelNormalSample * 0.5f) + 0.5f;
        }
        else {
            worldNormal = TangentToWorld( pixelNormalSample, INTERPOLANT_Normal.xyz, INTERPOLANT_Tangent.xyz, INTERPOLANT_Binormal, true );
        }
    } 
    else {
        pixelNormalSample.xyz = INTERPOLANT_Normal.xyz;
        worldNormal = INTERPOLANT_Normal.xyz;
    }

    HALF3 diff;
    HALF3 spec; 
    HALF3 spec2;
    HALF4 shadowColor;
    MainLighting(   vertOut, worldNormal.xyz, INTERPOLANT_ShadowMapUV, baseUV[0].xy * 128.0f, normalUV[0], texSampler(p_sCreepInteriorNormalMap), texTexture(p_sCreepInteriorNormalMap),
					1.0f, p_vSpecColorSpecularity.w, diff, spec, shadowColor, spec2, cLightingRegionMap );

    if (b_iCreepOutputMode == CREEP_OUTPUT_COMPLETE) {
        output.xyz = diff * diffuseColorSample.xyz;
        if ( b_useVertexColors ) {
            output.rgb *= saturate(INTERPOLANT_VertexColor.xyz);
        }
    }
    if (b_iCreepOutputMode == CREEP_OUTPUT_DIFFUSE_ONLY) {
        output.xyz = diffuseColorSample.xyz;
    }
    if (b_iCreepOutputMode == CREEP_OUTPUT_NORMALS_ONLY) {
        output.xyz = pixelNormalSample.xyz;
        output.xyz = (output.xyz * 0.5f) + 0.5f;
    }
    if (b_iCreepOutputMode == CREEP_OUTPUT_STENCIL_ONLY) {
        output.xyz = 1;
    }

    output.w = creepGameCoverageSample.a * edgeNormalMapAndAlphaMultiplierSample.a * heightFactor * slopeFactor;

    float3 specularMaskSample = 0;
    if (b_iCreepOutputMode != CREEP_OUTPUT_NORMALS_ONLY) {
        //float specularMask = saturate((edgeNormalMapAndAlphaMultiplierSample.a - 0.1f) * 5.0f);
        float specularMask = saturate(edgeNormalMapAndAlphaMultiplierSample.a*5 - 0.5f);
        specularMaskSample = SampleCreepTexture(texSampler(p_sCreepSpecularMask), texTexture(p_sCreepSpecularMask), baseUV, vertOut).xyz * specularMask;
        if (b_iCreepOutputMode == CREEP_OUTPUT_COMPLETE) {
            if (useSpecular) {
                //specularMaskSample = diffuseColorSample.a * specularMask;
                output.xyz += spec * specularMaskSample;
            }
        }
    }

    // cheezy luminance value
    cDeferredSpecularPower = dot(specularMaskSample, float3(0.3f, 0.59f, 0.11f));

    cDeferredDiffuse = diffuseColorSample.xyz;
    vDeferredNormal = worldNormal;
    cDeferredSpecular = specularMaskSample.xyz;

    if ( b_iDebugMode != NO_DEBUG ) {
        return DebugColor(  diffuseColorSample.xyz, specularMaskSample, 0, pixelNormalSample, worldNormal,
                            diff, spec, shadowColor, 1.0f, output.a, HALF3( baseUV[0].x, coverageUV.y, 0 ), 1.0f, vertOut, output, 0.0f, cDeferredSpecularPower, cLightingRegionMap );
    }

    return output;
}

//--------------------------------------------------------------------------------------------------
float4 PixelCreepOpaque ( VertexTransport vertOut, inout HALF3 vDeferredNormal, inout HALF3 cDeferredDiffuse, inout HALF3 cDeferredSpecular, inout HALF cDeferredSpecularPower ) {
    float4 output;

    HALF4 cLightingRegionMap;
    output = PixelCreepGeneric(vertOut, true, cLightingRegionMap, vDeferredNormal, cDeferredDiffuse, cDeferredSpecular, cDeferredSpecularPower);

    // multiply by 1 or 0, we use alpha cutoff greater than 0 to make the fragment disappear completely
    // otherwise we want to maintain the alpha value for a specular mask
    if (b_iCreepOutputMode == CREEP_OUTPUT_DIFFUSE_ONLY) {
        output.a = step(p_fCreepOpaqueAlphaThreshold, output.a) * (cDeferredSpecularPower + (1.0 / 255.0));
    }
    else if (b_iCreepOutputMode == CREEP_OUTPUT_STENCIL_ONLY) {
        // output either (1, 1, 1, 1) or (0, 0, 0, 0) to simplify the shader
        output = step(p_fCreepOpaqueAlphaThreshold, output.a);
    }
    else if (b_iCreepOutputMode == CREEP_OUTPUT_NORMALS_ONLY) {
        //output.xyz = 0;
        output.a = step(p_fCreepOpaqueAlphaThreshold, output.a);
    }
    else {
        output.a = step(p_fCreepOpaqueAlphaThreshold, output.a);
    }

    // fog
    if (b_iCreepOutputMode != CREEP_OUTPUT_STENCIL_ONLY
        && b_iCreepOutputMode != CREEP_OUTPUT_NORMALS_ONLY
    ) {
        output = float4(ApplyFog( vertOut, output, 1.0f, cLightingRegionMap ).xyz, output.a);

        // Fog of war.
        if ( b_emitFinalColor )
            output = ApplyFogOfWar( vertOut, output, cDeferredDiffuse );
    }

    output *= p_vTerrainTint;

    return output;
}

//--------------------------------------------------------------------------------------------------
float4 PixelCreepTranslucent ( VertexTransport vertOut, inout HALF3 vDeferredNormal, inout HALF3 cDeferredDiffuse, inout HALF3 cDeferredSpecular, inout HALF cDeferredSpecularPower ) {
    float4 output;

    HALF4 cLightingRegionMap;
    output = PixelCreepGeneric(vertOut, true, cLightingRegionMap, vDeferredNormal, cDeferredDiffuse, cDeferredSpecular, cDeferredSpecularPower);
    output.rgb = (output.rgb * p_cTransparentTintColor) + p_cTransparentEmissiveColor;
    output.a = saturate((output.a - p_vCreepTransparentRampConstants.x) * p_vCreepTransparentRampConstants.y);

    // fog
    if (b_iCreepOutputMode != CREEP_OUTPUT_NORMALS_ONLY) {
        output = float4(ApplyFog( vertOut, output, 1.0f, cLightingRegionMap ).xyz, output.a);

        // Fog of war.
        if ( b_emitFinalColor )
            output = ApplyFogOfWar( vertOut, output, cDeferredDiffuse );
    }

    output *= p_vTerrainTint;
    cDeferredDiffuse = cDeferredDiffuse * p_cTransparentTintColor;
    cDeferredSpecular = cDeferredSpecular * p_cTransparentTintColor;
    return output;
}

//--------------------------------------------------------------------------------------------------
float4 PixelCreepAdditiveColor ( VertexTransport vertOut, inout HALF3 vDeferredNormal, inout HALF3 cDeferredDiffuse, inout HALF3 cDeferredSpecular, inout HALF cDeferredSpecularPower ) {
    float4 output;

    HALF4 cLightingRegionMap;
    output = PixelCreepGeneric(vertOut, false, cLightingRegionMap, vDeferredNormal, cDeferredDiffuse, cDeferredSpecular, cDeferredSpecularPower);
    output.rgb = p_cCreepAdditiveColor.rgb;
    output.a = saturate((output.a - p_vCreepTransparentRampConstants.x) * p_vCreepTransparentRampConstants.y) * p_cCreepAdditiveColor.a ;
    output *= p_vTerrainTint;

    cDeferredDiffuse = cDeferredDiffuse * p_cTransparentTintColor;
    cDeferredSpecular = cDeferredSpecular * p_cTransparentTintColor;
    return output;
}

#endif  // PIXEL_SHADER

#endif  // PS_CREEP
