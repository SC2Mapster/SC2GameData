//==================================================================================================
//
// Copyright Blizzard Entertainment 2003-2005
//
// This is the shader code for point lighting.
//==================================================================================================

#ifndef _LIGHTTYPES
#define _LIGHTTYPES

#include "ShaderSystem.fx"
#include "Common.fx"
#include "LightingModels.fx"

#define LIGHTTYPE_DIRECTIONAL	0
#define LIGHTTYPE_POINT			1
#define LIGHTTYPE_SPOT			2

#define NO_ATTENUATION			0
#define USE_ATTENUATION			1

#define NO_SPECULAR				0
#define USE_SPECULAR			1

//--------------------------------------------------------------------------------------------------
half ComputeLightAttenuation( half fAttenMultiplier, half fRecipRange, half fRecipDist ) {
    half fAttenuation = 1.0f - saturate( fRecipRange / fRecipDist );
	fAttenuation = saturate( fAttenuation * fAttenMultiplier );
    fAttenuation = fAttenuation * fAttenuation;
    return fAttenuation;
}

//--------------------------------------------------------------------------------------------------
void ComputeDirectionalLight(   VertexTransport vertOut, half3 vNormalWS, half3 vLightDirWS, half3 vLightHalfVecWS, 
                                bool bUseSpecular, out half3 vLightDiffuseSpecular ) {
    vLightDiffuseSpecular = LightShading( vertOut, vNormalWS, -vLightDirWS, bUseSpecular, true, vLightHalfVecWS, 0, 0, p_vSpecColorSpecularity.w );
}

//--------------------------------------------------------------------------------------------------
void ComputePointLight(		VertexTransport vertOut, half3 vNormalWS, float3 vVertexPosWS, float3 vLightPosWS, half fRecipRange, 
                            half fAttenMultiplier, bool bUseSpecular, half fSpecularPower, out half3 vLightDiffuseSpecular ) {
    float3 vLightDir = vLightPosWS - vVertexPosWS;
    float fRecipDist = rsqrt( dot( vLightDir, vLightDir ) );  // Reuse squared distance to normalize.
    vLightDir *= fRecipDist;                    
        
    vLightDiffuseSpecular = LightShading( vertOut, vNormalWS, vLightDir, bUseSpecular,false, 0, vVertexPosWS, vLightPosWS, fSpecularPower );
    vLightDiffuseSpecular = vLightDiffuseSpecular * ComputeLightAttenuation( fAttenMultiplier, fRecipRange, fRecipDist );
}

//--------------------------------------------------------------------------------------------------
void ComputeSpotLight(		VertexTransport vertOut, half3 vNormalWS, float3 vVertexPosWS, float3 vLightPosWS, half3 vSpotDir,
							half fRecipRange, half fAttenMultiplier, half fFalloffBias, half fFalloffScale, 
                            half fHotspotMultiplier, bool bUseSpecular, half fSpecularPower,
							out half3 vLightDiffuseSpecular ) {
    float3 vLightDir = vLightPosWS - vVertexPosWS;
    float fRecipDist = rsqrt( dot( vLightDir, vLightDir ) );  // Reuse squared distance to normalize.
    vLightDir *= fRecipDist;                    
        
    vLightDiffuseSpecular = LightShading( vertOut, vNormalWS, vLightDir, bUseSpecular, false, 0, vVertexPosWS, vLightPosWS, fSpecularPower );
    
	// half fFalloff = saturate( 1.0f - ( acos( dot( -vLightDir, vSpotDir ) ) / ( 0.5f * 3.1416f ) ) );		// Angle
	half fFalloff = saturate( dot( -vLightDir, vSpotDir ) );				// Dot product
	fFalloff = saturate( ( fFalloff + fFalloffBias ) * fFalloffScale );		// mad_sat to adjust fFalloff
	fFalloff = saturate( fFalloff * fHotspotMultiplier ); 					// mul_sat for hotspot
	fFalloff = fFalloff * fFalloff;
	
    vLightDiffuseSpecular = vLightDiffuseSpecular * 
                            ComputeLightAttenuation( fAttenMultiplier, fRecipRange, fRecipDist ) *
                            fFalloff;
}

#endif  // _LIGHTTYPES