//==================================================================================================
//
// Copyright Blizzard Entertainment 2003-2005
//
// This is the shader code for lighting.
//==================================================================================================

#ifndef PS_LIGHTING
#define PS_LIGHTING

#ifdef PIXEL_SHADER

#include "ShaderSystem.fx"
#include "Lighting.fx"
#include "PSShadow.fx"
#include "PSDebugModes.fx"

//--------------------------------------------------------------------------------------------------
float3 EmitPSBinormal( VertexTransportRaw vertOut ) {
    // sign of INTERPOLANT_Normal.w is the handiness
    return cross( INTERPOLANT_Normal.xyz, INTERPOLANT_Tangent.xyz ) * INTERPOLANT_Normal.w;
}

//--------------------------------------------------------------------------------------------------
// Shadowing light direction in tangent space (for POM).
float3 ShadowLightTS(   float3 vTangentSpaceNormal,
                        float3 vTangentSpaceBinormal,
                        float3 vTangentSpaceTangent
) {
    float3x3 mWorldToTangent;
    mWorldToTangent[0] = vTangentSpaceTangent;
    mWorldToTangent[1] = vTangentSpaceBinormal;
    mWorldToTangent[2] = vTangentSpaceNormal;
    return mul( -p_directionalLights[0].vDirection.xyz, mWorldToTangent );
}

//--------------------------------------------------------------------------------------------------
// Returns per-pixel normal.
HALF3 TangentToWorld( HALF3 vTextureNormal, float3 vNormal, float3 vTangent, float3 vBinormal, bool normalizeBasis ) {
    if ( b_useIdentityBasis )
        return normalize( vTextureNormal * HALF3( 1.0, -1.0f, 1.0f ) );
   
    // Move normal to world space.
    float3x3 mTangentToWorld;
    mTangentToWorld[0] = vTangent;
    mTangentToWorld[1] = vBinormal;
    mTangentToWorld[2] = vNormal;
    
    /*
    if ( normalizeBasis ) {
        mTangentToWorld[0] = normalize( mTangentToWorld[0] );
        mTangentToWorld[1] = normalize( mTangentToWorld[1] );
        mTangentToWorld[2] = normalize( mTangentToWorld[2] );    
        return normalize( mul( vTextureNormal, mTangentToWorld ) );
    }
    */

    // $zzs: its not necessary to normalize this,
    // a vNormalWS vector trasformed by an orthornormal basis is still a vNormalWS vector
    // this also avoids the FP exception when normalizing a null vector
    // DoFi: The basis vectors are linearly interpolated by the shader interpolants and thus are not guaranteed to be perfectly
    // orthonormal. In some cases the error could be noticeable (aka when polygon density is low).
    
    // :NOTE: Don't forget to normalize the texture normal.
    return normalize( mul( vTextureNormal, mTangentToWorld ) );
}

//--------------------------------------------------------------------------------------------------
void MainLighting(      VertexTransport vertOut, 
                        HALF3 vNormalWS,                    // Normal
                        float4 shadowUV,                    // Shadow map uv
                        float2 softShadowUV,				// Soft shadow noise UV
                        HALF2 heightMapUV,                  // Height map (normal map) UV - used for POM
                        typeSampler2D sHeightMap,           // Height map sampler - used for POM
                        typeTexture2D tHeightMap,
                        HALF fAmbientOcclusion,				// Ambient occlusion value
                        HALF fSpecularity,                  // Specular exponent value
                        out HALF3 cLightDiffuse,            // Resulting lighting diffuse color
                        out HALF3 cLightSpecular,           // Resulting lighting specular color
                        out HALF4 cShadowColor,             // Resulting shadow occlusion value or color (1=no shadow)
                        out HALF3 cLightSpecular2,          // Optional second specular term
                        out HALF4 cLightingRegionMap        // Lighting region map, used for debugging
                        ) {
    cLightDiffuse = 0;
    cLightSpecular = 0;
    cLightSpecular2 = 0;
    cLightingRegionMap = float4(0,0,0,0);

    // Get shadow value.
    cShadowColor = ShadowIntensity( vertOut, shadowUV, softShadowUV, heightMapUV, sHeightMap, tHeightMap );

    if ( b_useLighting == 0 ) {
        cLightDiffuse   = 1;
        if ( b_iDebugMode == LIGHTING_ONLY )
            cLightDiffuse = 0;
    } else {

        if ( b_iVertexLightingMode == VERTEXLIGHTING_NONE) {
            // if doing per pixel lighting, get our lighting region weights from the texture
            HALF4 vLightingRegions = HALF4(0, 0, 0, 0);
            if (b_UseLightingRegions) {
                float2 vUV = (INTERPOLANT_WorldPos.xy * p_vWorldToLightingRegionTransform.zw) + p_vWorldToLightingRegionTransform.xy;
                vLightingRegions = sample2D(p_sLightingRegions, vUV);
            }
            cLightingRegionMap = vLightingRegions;

            // Transfer vertex transport component to locals for easier access (transfering arrays as function parameters breaks compiler).
            HALF3 vHalfVecWS = INTERPOLANT_HalfVec;
            if ( b_iNormalizeHalfVector )
                vHalfVecWS = normalize(vHalfVecWS);
			
            if ( b_UseVertexBasedAmbientOcclusion ) {
                fAmbientOcclusion = INTERPOLANT_VectorUI1.a;
            }
            
            // Compute per-pixel lighting.
            Lighting(   vertOut, true, INTERPOLANT_WorldPos.xyz, vNormalWS, cShadowColor, fAmbientOcclusion, fSpecularity, cLightingRegionMap,
                        ALL_LIGHTS, cLightDiffuse, cLightSpecular, cLightSpecular2, vHalfVecWS ); 
        } else {

            // if we did vertex lighting, get our lighting region weights from the vertex color instead
            cLightingRegionMap.xyz = INTERPOLANT_VertexColor.xyz;
            cLightingRegionMap.a = 1.0 - (cLightingRegionMap.x + cLightingRegionMap.y + cLightingRegionMap.z);

            if ( b_iVertexLightingMode == VERTEXLIGHTING_PARTIAL ) {
                HALF3 vHalfVecWS = ComputeHalfVector( INTERPOLANT_WorldPos.xyz, p_directionalLights[0].vDirection );
                Lighting(   vertOut, true, INTERPOLANT_WorldPos.xyz, vNormalWS, cShadowColor, fAmbientOcclusion, fSpecularity, cLightingRegionMap,
                            ALL_LIGHTS, cLightDiffuse, cLightSpecular, cLightSpecular2, vHalfVecWS ); 
                cLightDiffuse       += INTERPOLANT_Diffuse;       
                cLightSpecular      += INTERPOLANT_Specular;
            } else {
                // Use passed-in interpolant values.
                cLightDiffuse       = INTERPOLANT_Diffuse;       
                cLightSpecular      = INTERPOLANT_Specular;
                if ( b_useShadows ) {
                    cLightDiffuse += INTERPOLANT_ShadowDiffuse * cShadowColor.rgb;
                    cLightSpecular += INTERPOLANT_ShadowSpecular * cShadowColor.rgb;
                }
            }
        } 
    }
}

#endif  // PIXEL_SHADER

#endif  // PS_LIGHTING
