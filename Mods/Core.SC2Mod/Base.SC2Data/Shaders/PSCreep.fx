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
sampler2D creepGameCoverage;
sampler2D creepEdgeNormalMapAndAlphaMultiplier;
sampler2D creepDiffuseColor;
sampler2D creepInteriorNormalMap;
sampler2D creepSpecularMask;
sampler2D reflectionMap;
sampler2D creepShadowMap;

// creep params
float    g_CreepOpaqueAlphaThreshold;           //0.18
float4   g_CreepTransparentRampConstants;       //0.09, 1.0f/0.09f, second params for a madd to rescale coverage
float2   g_CreepBaseTextureTiling;              //10, 10
float2   g_CreepBaseNormalMapTiling;            //10, 10
float2   g_CreepEdgeNormalMapTiling;            //3, 3
float2   g_EdgeNormalMapRampConstants;          //0.74, 4
float3   g_TransparentTintColor;
float3   g_TransparentEmissiveColor;
float4   g_CreepAdditiveColor;

// should match ECreepOutputMode
#define CREEP_OUTPUT_DIFFUSE_ONLY   0
#define CREEP_OUTPUT_NORMALS_ONLY   1
#define CREEP_OUTPUT_COMPLETE       2
#define CREEP_OUTPUT_STENCIL_ONLY   3   // output just 1 or 0 for writing to the stencil buffer

// should match ECreepPass
#define CREEP_OPAQUE                0
#define CREEP_TRANSLUCENT           1
#define CREEP_ADDITIVE_COLOR        2

// single component specular power
float   g_SpecularPower;


// creep edge normal and aplha map layer
DECLARE_LAYER( CreepMask );


//--------------------------------------------------------------------------------------------------
float4 PixelCreepGeneric( VertexTransport vertOut, bool useSpecular, bool useReflection) {

    float4 output;

    float4 creepUV  = half4( INTERPOLANT_TerrainUV.xy, 0, 0 );
    float4 terrainMaskUV = half4( INTERPOLANT_CreepTerrainUV.xyz, 1.0f );
    float4 creepUV0 = float4(terrainMaskUV.xy * g_CreepBaseTextureTiling, terrainMaskUV.zw);
    float4 creepUV1 = float4(terrainMaskUV.xy * g_CreepBaseNormalMapTiling, terrainMaskUV.zw);
    float4 creepUV2 = float4(terrainMaskUV.xy * g_CreepEdgeNormalMapTiling, terrainMaskUV.zw);

    // use material system if enabled
    float4 creepGameCoverageSample = 0;
    if ( b_iCreepMaskLayerEnable ) {
        SETUP_LAYER(CreepMask);
        SEnvMappings envMappings;
        creepGameCoverageSample = GetLayerColor( CreepMask, 1.0f, false );
    } else {
        creepGameCoverageSample = tex2D(creepGameCoverage, creepUV.xy);
    }

    // rescale to contract edge
    creepGameCoverageSample = (creepGameCoverageSample * g_CreepTransparentRampConstants.z) + g_CreepTransparentRampConstants.w;

    float4 diffuseColorSample = tex2D(creepDiffuseColor, creepUV0.xy);
    float4 edgeNormalMapAndAlphaMultiplierSample = tex2D(creepEdgeNormalMapAndAlphaMultiplier, creepUV2.xy);
    edgeNormalMapAndAlphaMultiplierSample.xyz = DecodeNormal(edgeNormalMapAndAlphaMultiplierSample.xyz);

    float edgeFactor = saturate((creepGameCoverageSample.a - g_EdgeNormalMapRampConstants.x) * g_EdgeNormalMapRampConstants.y);
    half3 worldNormal;    
    float3 pixelNormalSample;
    if (b_useNormalMapping) {
        pixelNormalSample = tex2D(creepInteriorNormalMap, creepUV1.xy).xyz;
        pixelNormalSample.xyz = DecodeNormal(pixelNormalSample.xyz);
        pixelNormalSample.xyz = normalize(lerp(edgeNormalMapAndAlphaMultiplierSample.xyz, pixelNormalSample.xyz, edgeFactor));

        if (b_iCreepOutputMode == CREEP_OUTPUT_NORMALS_ONLY) {
            worldNormal = (pixelNormalSample * 0.5f) + 0.5f;
        }
        else {
            worldNormal = TangentToWorld( pixelNormalSample, INTERPOLANT_Normal.xyz, INTERPOLANT_Tangent.xyz, INTERPOLANT_Binormal, true );
        }
    } else {
        pixelNormalSample.xyz = INTERPOLANT_Normal.xyz;
        worldNormal = INTERPOLANT_Normal.xyz;
    }

    half4 creepShadowInfluence = half4(1, 1, 1, 1);
    if (b_selfShadowingCreep) {
        creepShadowInfluence = tex2D(creepShadowMap, creepUV2.xy);
        creepShadowInfluence = lerp(1.0f, creepShadowInfluence, edgeFactor);
    }

    half3 diff;
    half3 spec; 
    half3 spec2;
    half4 shadowColor;
    MainLighting(   vertOut, worldNormal.xyz, INTERPOLANT_ShadowMapUV, creepUV0.xy * 128.0f, creepUV1, creepInteriorNormalMap, 
					1.0f, diff, spec, shadowColor, spec2 );

    if (b_iCreepOutputMode == CREEP_OUTPUT_COMPLETE) {
        output.xyz = diff * diffuseColorSample.xyz;
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

    output.w = creepGameCoverageSample.a * edgeNormalMapAndAlphaMultiplierSample.a;

    float3 specularMaskSample = 0;
    if (b_iCreepOutputMode != CREEP_OUTPUT_NORMALS_ONLY) {
        float specularMask = saturate((edgeNormalMapAndAlphaMultiplierSample.a - 0.1f) * 5.0f);
        specularMaskSample = tex2D(creepSpecularMask, creepUV0.xy).xyz * specularMask;
        if (b_iCreepOutputMode == CREEP_OUTPUT_COMPLETE) {
            if (useSpecular) {
                //specularMaskSample = diffuseColorSample.a * specularMask;
                output.xyz += spec * specularMaskSample;
            }
        }
    }

    // cheezy luminance value
    g_SpecularPower = dot(specularMaskSample, float3(0.3f, 0.59f, 0.11f));

    g_cDeferredDiffuse = diffuseColorSample.xyz;
    g_vDeferredNormal = worldNormal;
    g_cDeferredSpecular = specularMaskSample.xyz;
	g_cDeferredSpecularPower = g_SpecularPower;

    if ( b_iDebugMode != NO_DEBUG ) {
        return DebugColor(  diffuseColorSample.xyz, specularMaskSample, 0, pixelNormalSample, worldNormal,
                            diff, spec, shadowColor, 1.0f, output.a, half3( creepUV0.x, creepUV.y, 0 ), 1.0f, vertOut, output );
    }

    if (useReflection) {
        half wetness = saturate((1.0f - edgeNormalMapAndAlphaMultiplierSample.a) - 0.65f) * 4.0f;

        float3 distortedReflection = INTERPOLANT_WorldPos.xyz;
        distortedReflection.xy += pixelNormalSample.xy * 0.8f;
        // :TODO: Don't do a full matrix multiply here in the pixel shader.
        float4 HPos = mul(float4(distortedReflection, 1.0f), p_mWorldViewProj);

        float2 reflectionMapUV = GetBackBufferUV(vertOut, false, true);
        half3 reflectionColor = tex2D(reflectionMap, reflectionMapUV);
        output.rgb += reflectionColor * wetness;
    }

    // fog
    if (b_iCreepOutputMode != CREEP_OUTPUT_NORMALS_ONLY) {
        float alpha = output.a;
        output = float4(ApplyFog( vertOut, output, 1.0f ).xyz, alpha);

        // Fog of war.
        output = ApplyFogOfWar( vertOut, output, g_cDeferredDiffuse );
    }

    return output;
}

//--------------------------------------------------------------------------------------------------
float4 PixelCreepOpaque ( VertexTransport vertOut ) {
    InitShader( vertOut );
    float4 output;

    output = PixelCreepGeneric(vertOut, true, b_useCreepReflection);

    // multiply by 1 or 0, we use alpha cutoff greater than 0 to make the fragment disappear completely
    // otherwise we want to maintain the alpha value for a specular mask
    if (b_iCreepOutputMode == CREEP_OUTPUT_DIFFUSE_ONLY) {
        output.a = step(g_CreepOpaqueAlphaThreshold, output.a) * (g_SpecularPower + (1.0 / 255.0));
    }
    else if (b_iCreepOutputMode == CREEP_OUTPUT_STENCIL_ONLY) {
        // output either (1, 1, 1, 1) or (0, 0, 0, 0) to simplify the shader
        output = step(g_CreepOpaqueAlphaThreshold, output.a);
    }
    else if (b_iCreepOutputMode == CREEP_OUTPUT_NORMALS_ONLY) {
        //output.xyz = 0;
        output.a = step(g_CreepOpaqueAlphaThreshold, output.a);
    }
    else {
        output.a = step(g_CreepOpaqueAlphaThreshold, output.a);
    }

    output *= p_vTerrainTint;
    return output;
}

//--------------------------------------------------------------------------------------------------
float4 PixelCreepTranslucent ( VertexTransport vertOut ) {
    InitShader( vertOut );
    float4 output;

    output = PixelCreepGeneric(vertOut, true, false);
    output.rgb = (output.rgb * g_TransparentTintColor) + g_TransparentEmissiveColor;
    output.a = saturate((output.a - g_CreepTransparentRampConstants.x) * g_CreepTransparentRampConstants.y);
    output *= p_vTerrainTint;

    g_cDeferredDiffuse = g_cDeferredDiffuse * g_TransparentTintColor;
    g_cDeferredSpecular = g_cDeferredSpecular * g_TransparentTintColor;
	g_cDeferredSpecularPower = g_SpecularPower;
    return output;
}

//--------------------------------------------------------------------------------------------------
float4 PixelCreepAdditiveColor ( VertexTransport vertOut ) {
    InitShader( vertOut );
    float4 output;

    output = PixelCreepGeneric(vertOut, false, false);
    output.rgb = g_CreepAdditiveColor.rgb;
    output.a = saturate((output.a - g_CreepTransparentRampConstants.x) * g_CreepTransparentRampConstants.y) * g_CreepAdditiveColor.a ;
    output *= p_vTerrainTint;

    g_cDeferredDiffuse = g_cDeferredDiffuse * g_TransparentTintColor;
    g_cDeferredSpecular = g_cDeferredSpecular * g_TransparentTintColor;
	g_cDeferredSpecularPower = g_SpecularPower;
    return output;
}

#endif  // PIXEL_SHADER

#endif  // PS_CREEP