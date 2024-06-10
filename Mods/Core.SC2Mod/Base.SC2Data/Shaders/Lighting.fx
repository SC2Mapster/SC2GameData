//==================================================================================================
//
// Copyright Blizzard Entertainment 2003-2005
//
// This is the shader code for lighting.
//==================================================================================================

#ifndef _LIGHTING
#define _LIGHTING

#include "ShaderSystem.fx"
#include "Common.fx"
#include "LightTypes.fx"

#define MAX_DIRECTIONAL_LIGHTS      3
#define MAX_POINT_LIGHTS			5
#define MAX_SPOTLIGHTS				5

#define DIRECTIONAL_LIGHT           0
#define OMNI_LIGHT                  1

// Light filters.
#define ALL_LIGHTS					0		// All directional lights + all point and spot lights in a single pass.
#define EXCLUDE_SHADOWLIGHT			1		// All directional lights + all point and spot lights in a single pass, excluding the shadowcasting direction light.
#define SHADOWLIGHT_ONLY			2		// Shadow casting directional light. Separated out so vertex lighting can still use shadows on that one light.

// Light mode.
#define NO_LOCAL_LIGHTS_MODE		0		// Local lighting disabled.
#define DEFERRED_LIGHTING_MODE		1		// Deferred lighting - light quality high or above.
#define SINGLEPASS_LIGHTING_MODE	2		// All lighting in a single pass - used for low quality vertex lighting.
#define MULTIPASS_POINTLIGHT_MODE	3		// One light per object pass - used for medium quality lighting.
#define MULTIPASS_SPOTLIGHT_MODE	4		// One light per object pass - used for medium quality lighting.

#define VERTEXLIGHTING_NONE         0
#define VERTEXLIGHTING_FULL         1
#define VERTEXLIGHTING_PARTIAL      2

struct DirectionalLight {
    float3  vDirection;
    half3   cColor;
};

struct PointLight {
	float4	vPositionRecipRadius;           // xyz is position, w is reciprocal of light radius
	half4	cColorAttenMultiplier;          // rgb is color, w is attenution multiplier
};

struct SpotLight {
	float4	vPositionRecipRadius;           // xyz is position, w is reciprocal of light radius
	half4	cColorAttenMultiplier;          // rgb is color, w is attenution multiplier
	half3	vDirection;
	half3	vSpotFalloffBiasScaleAndHotSpotMultiplier;
};

HALF3				p_cAmbientColor;								// Ambient cColor.
DirectionalLight    p_directionalLights[MAX_DIRECTIONAL_LIGHTS];	// Directional lights.
PointLight			p_pointLights[MAX_POINT_LIGHTS];				// Point lights.
SpotLight			p_spotLights[MAX_SPOTLIGHTS];					// Spot lights.
HALF3				g_vHalfVecWS;									// Half vector.

// These retarded globals are here to go around the shoddy compiler.
HALF3   g_curTotalDiffuse;
HALF3   g_curTotalSpecular;
HALF3   g_curTotalSpecular2;

//--------------------------------------------------------------------------------------------------
void AddLightContribution( bool useSpecular, half3 cLightColor, half3 cLightDiffuseSpecular, half4 cShadowColor ) {
    half3 cLightDiffuseColor     = 0;
    half3 cLightSpecularColor    = 0;
    half3 cLightSpecularColor2  = 0;
    
    // Color by light.
    cLightDiffuseColor = cLightColor * cLightDiffuseSpecular.x;
    //if ( b_useShadows )
        cLightDiffuseColor *= cShadowColor.rgb;

    // Add light diffuse contribution.            
    g_curTotalDiffuse += cLightDiffuseColor;
    
    if ( useSpecular ) {
        // Color by light specular color.
        cLightSpecularColor = p_vSpecColorSpecularity.rgb * cLightDiffuseSpecular.y;
        //if ( b_useShadows )
            cLightSpecularColor *= cShadowColor.rgb;

        // Add light specular contribution.
        g_curTotalSpecular += cLightSpecularColor;

        // Color by light specular color.
        cLightSpecularColor2 = p_vSpecColorSpecularity.rgb * cLightDiffuseSpecular.z;
        //if ( b_useShadows )
            cLightSpecularColor *= cShadowColor.rgb;

        // Add light specular contribution.
        g_curTotalSpecular2 += cLightSpecularColor2;
    }     
}

//--------------------------------------------------------------------------------------------------
// Lighting function, which could be executed either pixel or vertex shader side.
void Lighting(  VertexTransport vertOut, 
                bool isPerPixel,            // True if we are using per-pixel lighting
				float3 vPositionWS,			// World space position
                half3 vNormalWS,            // Normal in world space
                half4 cShadowColor,         // Shadow intensity (1=no shadow) computed from previous stage
                half fAmbientOcclusion,		// Ambient occlusion value
                int mode,                   // Compatibility mode.
                out half3 cTotalDiffuse,    // Resulting lighting diffuse color
                out half3 cTotalSpecular,   // Resulting lighting specular color 
                out half3 cTotalSpecular2
    ) {
    g_curTotalDiffuse           = 0;
    g_curTotalSpecular          = 0;
    g_curTotalSpecular2         = 0;
    half3 cLightDiffuseSpecular = 0;

    // Various modes for lighting.
	if ( b_iLightingMode == MULTIPASS_POINTLIGHT_MODE ) {
		// Multipassed point lights.
		ComputePointLight(	vertOut,
                            vNormalWS, 
                            vPositionWS, 
                            p_pointLights[0].vPositionRecipRadius.xyz, 
                            p_pointLights[0].vPositionRecipRadius.w, 
							p_pointLights[0].cColorAttenMultiplier.a,
                            b_iUseSpecular, p_vSpecColorSpecularity.w, cLightDiffuseSpecular );
        if ( b_iAffectedByAO )
            cShadowColor *= fAmbientOcclusion;
		AddLightContribution( b_iUseSpecular, p_pointLights[0].cColorAttenMultiplier.rgb, cLightDiffuseSpecular, cShadowColor );
	} else if ( b_iLightingMode == MULTIPASS_SPOTLIGHT_MODE ) {
		// Multipassed spot lights.
		ComputeSpotLight(	vertOut,
                            vNormalWS, 
                            vPositionWS, 
                            p_spotLights[0].vPositionRecipRadius.xyz, 
                            p_spotLights[0].vDirection, 
							p_spotLights[0].vPositionRecipRadius.w, 
							p_spotLights[0].cColorAttenMultiplier.a, 
							p_spotLights[0].vSpotFalloffBiasScaleAndHotSpotMultiplier.x, 
							p_spotLights[0].vSpotFalloffBiasScaleAndHotSpotMultiplier.y,
							p_spotLights[0].vSpotFalloffBiasScaleAndHotSpotMultiplier.z, 
							b_iUseSpecular, p_vSpecColorSpecularity.w, cLightDiffuseSpecular );
        if ( b_iAffectedByAO )
            cShadowColor *= fAmbientOcclusion;
		AddLightContribution( b_iUseSpecular, p_spotLights[0].cColorAttenMultiplier.rgb, cLightDiffuseSpecular, cShadowColor );
	} else {	
		if ( mode != EXCLUDE_SHADOWLIGHT  &&
                    ( ( !isPerPixel && b_iVertexLightingMode == VERTEXLIGHTING_FULL ) ||
                    ( isPerPixel && ( b_iVertexLightingMode == VERTEXLIGHTING_PARTIAL || b_iVertexLightingMode == VERTEXLIGHTING_NONE ) ) ) ) {
			// Key shadow light.
			ComputeDirectionalLight(    vertOut,
                                        vNormalWS, 
                                        p_directionalLights[0].vDirection, 
                                        g_vHalfVecWS, 
                                        b_iUseSpecular, 
                                        cLightDiffuseSpecular );
			AddLightContribution( true, p_directionalLights[0].cColor, cLightDiffuseSpecular, cShadowColor );
		}

		if ( mode != SHADOWLIGHT_ONLY ) {
            // Ambient term.
		    if ( b_iVertexLightingMode != VERTEXLIGHTING_PARTIAL || isPerPixel )
                g_curTotalDiffuse += p_cAmbientColor * fAmbientOcclusion;

			// Directional lights.
			// This extra if is needed for Cg to optimize away the loop when b_iDirectionalLightCount == 0 on Mac/OpenGL
			if ( b_iDirectionalLightCount && 
                ( ( !isPerPixel && b_iVertexLightingMode == VERTEXLIGHTING_FULL ) ||
                ( isPerPixel && ( b_iVertexLightingMode == VERTEXLIGHTING_PARTIAL || b_iVertexLightingMode == VERTEXLIGHTING_NONE ) ) ) ) {
				for ( int i = 1; i < b_iDirectionalLightCount; i++ ) {
					ComputeDirectionalLight(    vertOut,
                                                vNormalWS, 
                                                p_directionalLights[i].vDirection, 
                                                g_vHalfVecWS, 
                                                false, 
                                                cLightDiffuseSpecular );
					AddLightContribution( false, p_directionalLights[i].cColor, cLightDiffuseSpecular, fAmbientOcclusion );
			        
				}
			}		
				
			if ( b_iLightingMode == SINGLEPASS_LIGHTING_MODE && !isPerPixel ) {
				// Single passed point lights.
				for ( int i = 0; i < MAX_POINT_LIGHTS; i++ ) {
					ComputePointLight(	vertOut,
                                        vNormalWS, 
                                        vPositionWS, 
                                        p_pointLights[i].vPositionRecipRadius.xyz, 
                                        p_pointLights[i].vPositionRecipRadius.w, 
										p_pointLights[i].cColorAttenMultiplier.a, 
                                        NO_SPECULAR, p_vSpecColorSpecularity.w, cLightDiffuseSpecular );
					AddLightContribution( false, p_pointLights[i].cColorAttenMultiplier.rgb, cLightDiffuseSpecular, 1.0f );
				}

				// Single passed spot lights.
				//for ( int i = 0; i < p_iSpotLightCount; i++ ) {
				for ( int i = 0; i < MAX_SPOTLIGHTS; i++ ) {
					ComputeSpotLight(	vertOut,
                                        vNormalWS, 
                                        vPositionWS, p_spotLights[i].vPositionRecipRadius.xyz, 
                                        p_spotLights[i].vDirection, 
										p_spotLights[i].vPositionRecipRadius.w, 
										p_spotLights[i].cColorAttenMultiplier.a, 
										p_spotLights[i].vSpotFalloffBiasScaleAndHotSpotMultiplier.x, 
										p_spotLights[i].vSpotFalloffBiasScaleAndHotSpotMultiplier.y,
										p_spotLights[i].vSpotFalloffBiasScaleAndHotSpotMultiplier.z, 
										NO_SPECULAR, p_vSpecColorSpecularity.w, cLightDiffuseSpecular );
					AddLightContribution( false, p_spotLights[i].cColorAttenMultiplier.rgb, cLightDiffuseSpecular, 1.0f );
				}
			}
		}
	}
    
    cTotalDiffuse = g_curTotalDiffuse;
    cTotalSpecular = g_curTotalSpecular;
    cTotalSpecular2 = g_curTotalSpecular2;
}

#endif
