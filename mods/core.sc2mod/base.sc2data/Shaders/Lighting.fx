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

// Must be in sync with constants in LightStructs.h
#define MAX_DIRECTIONAL_LIGHTS      3
#define MAX_POINT_LIGHTS            3
#define MAX_SPOTLIGHTS              7

#define MAX_LIGHT_SETUPS            4

#define DIRECTIONAL_LIGHT           0
#define OMNI_LIGHT                  1

// Light filters.
#define ALL_LIGHTS                  0        // All directional lights + all point and spot lights in a single pass.
#define EXCLUDE_SHADOWLIGHT         1        // All directional lights + all point and spot lights in a single pass, excluding the shadowcasting direction light.
#define SHADOWLIGHT_ONLY            2        // Shadow casting directional light. Separated out so vertex lighting can still use shadows on that one light.

// Light mode.
#define NO_LOCAL_LIGHTS_MODE                0    // Local lighting disabled.
#define DEFERRED_LIGHTING_MODE              1    // Deferred lighting - light quality high or above.
#define VERTEX_SINGLEPASS_LIGHTING_MODE     2    // All lighting in a single pass - used for low quality vertex lighting.
#define PIXEL_SINGLEPASS_LIGHTING_MODE      3    // All lighting in a single pass done in the pixel shader

#define VERTEXLIGHTING_NONE         0
#define VERTEXLIGHTING_FULL         1
#define VERTEXLIGHTING_PARTIAL      2

struct DirectionalLight {
    float4  vDirection;
    HALF4   cColor;
};

struct PointLight {
    float4   vPositionRecipRadius;           // xyz is position, w is reciprocal of light radius
    HALF4    cSpecular;
    HALF4    cColorAttenMultiplier;          // rgb is color, w is attenution multiplier
};

struct SpotLight {
    float4   vPositionRecipRadius;           // xyz is position, w is reciprocal of light radius
    HALF4    cSpecular;
    HALF4    cColorAttenMultiplier;          // rgb is color, w is attenution multiplier
    HALF4    vDirection;
    HALF4    vSpotFalloffBiasScaleAndHotSpotMultiplier;
};

struct LightSetup {
    HALF3   cAmbientIntensity;
    HALF3   cLight0Specular;
    HALF3   cLight0Diffuse;
    HALF3   cLight1Diffuse;
    HALF3   cLight2Diffuse;
    HALF3   cFogColor;
};

HALF3              p_cAmbientColor;                                // Ambient cColor.
DirectionalLight   p_directionalLights[MAX_DIRECTIONAL_LIGHTS];    // Directional lights.
PointLight         p_pointLights[MAX_POINT_LIGHTS];                // Point lights.
SpotLight          p_spotLights[MAX_SPOTLIGHTS];                    // Spot lights.

LightSetup          p_lightSetups[MAX_LIGHT_SETUPS];                // Light region setups
texDecl2D(p_sLightingRegions);
float4              p_vWorldToLightingRegionTransform;              // XY - offset, ZW - scale

texDeclCube(p_sAmbientEnvironmentTexture);

//--------------------------------------------------------------------------------------------------
void BlendLightSetup( int lightSetup, HALF fraction, inout HALF3 ambient, inout HALF3 specular, inout HALF3 light0, inout HALF3 light1, inout HALF3 light2 ) {
    ambient += p_lightSetups[lightSetup].cAmbientIntensity * fraction;
    specular += p_lightSetups[lightSetup].cLight0Specular * fraction;
    light0 += p_lightSetups[lightSetup].cLight0Diffuse * fraction;
    light1 += p_lightSetups[lightSetup].cLight1Diffuse * fraction;
    light2 += p_lightSetups[lightSetup].cLight2Diffuse * fraction;
}

//--------------------------------------------------------------------------------------------------
void AddLightContribution( bool useSpecular, HALF3 cLightColor, HALF3 cLightDiffuseSpecular, HALF4 cShadowColor, HALF3 cSpecular, inout HALF3 curTotalDiffuse, inout HALF3 curTotalSpecular, inout HALF3 curTotalSpecular2 ) {
    HALF3 cLightDiffuseColor     = 0;
    HALF3 cLightSpecularColor    = 0;
    HALF3 cLightSpecularColor2  = 0;
    
    // Color by light.
    cLightDiffuseColor = cLightColor * cLightDiffuseSpecular.x;
    //if ( b_useShadows )
        cLightDiffuseColor *= cShadowColor.rgb;

    // Add light diffuse contribution.            
    curTotalDiffuse += cLightDiffuseColor;
    
    if ( useSpecular ) {
        // Color by light specular color.
        cLightSpecularColor = cSpecular * cLightDiffuseSpecular.y;
        //if ( b_useShadows )
            cLightSpecularColor *= cShadowColor.rgb;

        // Add light specular contribution.
        curTotalSpecular += cLightSpecularColor;

        // Color by light specular color.
        cLightSpecularColor2 = cSpecular * cLightDiffuseSpecular.z;
        //if ( b_useShadows )
            cLightSpecularColor2 *= cShadowColor.rgb;

        // Add light specular contribution.
        curTotalSpecular2 += cLightSpecularColor2;
    }     
}

//--------------------------------------------------------------------------------------------------
// Lighting function, which could be executed either pixel or vertex shader side.
void Lighting(  VertexTransport vertOut, 
                bool isPerPixel,            // True if we are using per-pixel lighting
                float3 vPositionWS,         // World space position
                HALF3 vNormalWS,            // Normal in world space
                HALF4 cShadowColor,         // Shadow intensity (1=no shadow) computed from previous stage
                HALF fAmbientOcclusion,     // Ambient occlusion value
                HALF fSpecularity,          // Specular exponent value
                HALF4 vLightingRegions,
                int mode,                   // Compatibility mode.
                out HALF3 cTotalDiffuse,    // Resulting lighting diffuse color
                out HALF3 cTotalSpecular,   // Resulting lighting specular color 
                out HALF3 cTotalSpecular2,
                HALF3 vHalfVecWS
    ) {
    HALF3 curTotalDiffuse       = 0;
    HALF3 curTotalSpecular      = 0;
    HALF3 curTotalSpecular2     = 0;

    HALF3 cLightDiffuseSpecular = 0;

    HALF3 cAmbient;
    HALF3 cDirectional[MAX_DIRECTIONAL_LIGHTS];
    HALF3 cSpecular;
        
    bool bShadowLight = mode != EXCLUDE_SHADOWLIGHT  &&
                ( ( !isPerPixel && b_iVertexLightingMode == VERTEXLIGHTING_FULL ) ||
                ( isPerPixel && ( b_iVertexLightingMode == VERTEXLIGHTING_PARTIAL || b_iVertexLightingMode == VERTEXLIGHTING_NONE ) ) );
    bool bSecondaryLights = mode != SHADOWLIGHT_ONLY && b_iDirectionalLightCount > 1 && 
            ( ( !isPerPixel && b_iVertexLightingMode == VERTEXLIGHTING_FULL ) ||
            ( isPerPixel && ( b_iVertexLightingMode == VERTEXLIGHTING_PARTIAL || b_iVertexLightingMode == VERTEXLIGHTING_NONE ) ) );

    if ( b_UseLightingRegions && (bShadowLight || bSecondaryLights) ) {
        cAmbient = cSpecular = cDirectional[0] = cDirectional[1] = cDirectional[2] = HALF3(0,0,0);
            
        BlendLightSetup(0,vLightingRegions.x,cAmbient,cSpecular,cDirectional[0],cDirectional[1],cDirectional[2]);
        BlendLightSetup(1,vLightingRegions.y,cAmbient,cSpecular,cDirectional[0],cDirectional[1],cDirectional[2]);
        BlendLightSetup(2,vLightingRegions.z,cAmbient,cSpecular,cDirectional[0],cDirectional[1],cDirectional[2]);
        BlendLightSetup(3,vLightingRegions.a,cAmbient,cSpecular,cDirectional[0],cDirectional[1],cDirectional[2]);
    } else
    {
        cAmbient = p_cAmbientColor;
        cSpecular = p_vSpecColorSpecularity.rgb;
        cDirectional[0] = p_directionalLights[0].cColor;
        cDirectional[1] = p_directionalLights[1].cColor;
        cDirectional[2] = p_directionalLights[2].cColor;
    }
        
#if !defined(COMPILING_SHADER_FOR_OPENGL) || !defined(VERTEX_SHADER)
    // in arbvp1, we can't support texture sampling in a vertex shader
    if (isPerPixel && b_UseAmbientEnvironment) {
        cAmbient *= sampleCube( p_sAmbientEnvironmentTexture, vNormalWS ).xyz;
    }
#endif        
    
    if ( bShadowLight ) {
        // Key shadow light.
        ComputeDirectionalLight(    vertOut,
                                    vNormalWS, 
                                    p_directionalLights[0].vDirection, 
                                    vHalfVecWS, 
                                    b_iUseSpecular,
                                    fSpecularity, 
                                    cLightDiffuseSpecular );
        AddLightContribution( true, cDirectional[0], cLightDiffuseSpecular, cShadowColor, cSpecular, curTotalDiffuse, curTotalSpecular, curTotalSpecular2 );
    }

    if ( mode != SHADOWLIGHT_ONLY ) {
        // Ambient term.
        if ( b_iVertexLightingMode != VERTEXLIGHTING_PARTIAL || isPerPixel )
            curTotalDiffuse += cAmbient * fAmbientOcclusion;

        // Directional lights.
        // This extra if is needed for Cg to optimize away the loop when b_iDirectionalLightCount == 0 on Mac/OpenGL
        if ( bSecondaryLights ) {
#if COMPILING_SHADER_WITH_BSL
            [unroll]
#endif
            for ( int i = 1; i < b_iDirectionalLightCount; i++ ) {
                ComputeDirectionalLight(    vertOut,
                                            vNormalWS, 
                                            p_directionalLights[i].vDirection, 
                                            vHalfVecWS, 
                                            false, 
                                            fSpecularity,
                                            cLightDiffuseSpecular );
                AddLightContribution( false, cDirectional[i], cLightDiffuseSpecular, fAmbientOcclusion, cSpecular, curTotalDiffuse, curTotalSpecular, curTotalSpecular2 );
                    
            }
        }        
                
        if ( (b_iLightingMode == VERTEX_SINGLEPASS_LIGHTING_MODE && !isPerPixel) || 
             (b_iLightingMode == PIXEL_SINGLEPASS_LIGHTING_MODE && isPerPixel) ) {
            // Single passed point lights.
            for ( int i = 0; i < MAX_POINT_LIGHTS; i++ ) {
                ComputePointLight(    vertOut,
                                    vNormalWS, 
                                    vPositionWS, 
                                    p_pointLights[i].vPositionRecipRadius.xyz, 
                                    p_pointLights[i].vPositionRecipRadius.w, 
                                    p_pointLights[i].cColorAttenMultiplier.a, 
                                    isPerPixel, fSpecularity, cLightDiffuseSpecular );
                AddLightContribution( isPerPixel, p_pointLights[i].cColorAttenMultiplier.rgb, cLightDiffuseSpecular, 1.0f, p_pointLights[i].cSpecular, curTotalDiffuse, curTotalSpecular, curTotalSpecular2 );
            }

            // Single passed spot lights.
            //for ( int i = 0; i < p_iSpotLightCount; i++ ) {
            for ( int i = 0; i < MAX_SPOTLIGHTS; i++ ) {
                ComputeSpotLight(    vertOut,
                                    vNormalWS, 
                                    vPositionWS, p_spotLights[i].vPositionRecipRadius.xyz, 
                                    p_spotLights[i].vDirection, 
                                    p_spotLights[i].vPositionRecipRadius.w, 
                                    p_spotLights[i].cColorAttenMultiplier.a, 
                                    p_spotLights[i].vSpotFalloffBiasScaleAndHotSpotMultiplier.x, 
                                    p_spotLights[i].vSpotFalloffBiasScaleAndHotSpotMultiplier.y,
                                    p_spotLights[i].vSpotFalloffBiasScaleAndHotSpotMultiplier.z, 
                                    isPerPixel, fSpecularity, cLightDiffuseSpecular );
                AddLightContribution( isPerPixel, p_spotLights[i].cColorAttenMultiplier.rgb, cLightDiffuseSpecular, 1.0f, p_spotLights[i].cSpecular, curTotalDiffuse, curTotalSpecular, curTotalSpecular2 );
            }
        }
    }
    
    cTotalDiffuse = curTotalDiffuse;
    cTotalSpecular = curTotalSpecular;
    cTotalSpecular2 = curTotalSpecular2;
}

#endif
