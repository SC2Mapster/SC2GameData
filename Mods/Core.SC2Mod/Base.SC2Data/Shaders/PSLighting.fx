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
half3 EmitPSBinormal( VertexTransport vertOut ) {
	// sign of INTERPOLANT_Normal.w is the handiness
	return cross( INTERPOLANT_Tangent.xyz, INTERPOLANT_Normal.xyz ) * INTERPOLANT_Normal.w;
}

//--------------------------------------------------------------------------------------------------
half3 DecodeTextureNormal( half4 cSample, out half fExtraValue );

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
half3 TangentToWorld( half3 vTextureNormal, float3 vNormal, float3 vTangent, float3 vBinormal, bool normalizeBasis ) {
	if ( b_useIdentityBasis )
		return normalize( vTextureNormal * half3( 1.0, -1.0f, 1.0f ) );
   
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
                        half3 vNormalWS,                    // Normal
                        float4 shadowUV,                    // Shadow map uv
                        float2 softShadowUV,				// Soft shadow noise UV
                        half2 heightMapUV,                  // Height map (normal map) UV - used for POM
                        sampler2D sHeightMap,               // Height map sampler - used for POM
                        half fAmbientOcclusion,				// Ambient occlusion value
                        out half3 cLightDiffuse,            // Resulting lighting diffuse color
                        out half3 cLightSpecular,           // Resulting lighting specular color
                        out half4 cShadowColor,             // Resulting shadow occlusion value or color (1=no shadow)
                        out half3 cLightSpecular2           // Optional second specular term
                        ) {
    cLightDiffuse = 0;
    cLightSpecular = 0;
    cLightSpecular2 = 0;

    // Get shadow value.
    cShadowColor = ShadowIntensity( vertOut, shadowUV, softShadowUV, heightMapUV, sHeightMap );

    if ( b_useLighting == 0 ) {
        cLightDiffuse   = 1;
        if ( b_iDebugMode == LIGHTING_ONLY )
            cLightDiffuse = 0;
    } else {
        if ( b_iVertexLightingMode == VERTEXLIGHTING_NONE) {
            // Transfer vertex transport component to locals for easier access (transfering arrays as function parameters breaks compiler).
            g_vHalfVecWS = INTERPOLANT_HalfVec;
			
			if ( b_UseVertexBasedAmbientOcclusion )
                fAmbientOcclusion = INTERPOLANT_VertexColor.a;
			
            // Compute per-pixel lighting.
            Lighting(   vertOut, true, INTERPOLANT_WorldPos.xyz, vNormalWS, cShadowColor, fAmbientOcclusion, 
                        ALL_LIGHTS, cLightDiffuse, cLightSpecular, cLightSpecular2 ); 
        } else {

            if ( b_iVertexLightingMode == VERTEXLIGHTING_PARTIAL ) {
                g_vHalfVecWS = ComputeHalfVector( INTERPOLANT_WorldPos.xyz, p_directionalLights[0].vDirection );
                Lighting(   vertOut, true, INTERPOLANT_WorldPos.xyz, vNormalWS, cShadowColor, fAmbientOcclusion, 
                            ALL_LIGHTS, cLightDiffuse, cLightSpecular, cLightSpecular2 ); 
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