//==================================================================================================
//
// Copyright Blizzard Entertainment 2003-2005
//
// This is the shader code for lighting.
//==================================================================================================

#ifndef VS_LIGHTING
#define VS_LIGHTING

#include "Lighting.fx"
#include "VSShadow.fx"
#include "VSCommon.fx"

//--------------------------------------------------------------------------------------------------
// Calculate lighting specular HALF vectors for key light.
HALF3 ComputeHalfVector( HALF3 vPosWS ) {
    return ComputeHalfVector( vPosWS, p_directionalLights[0].vDirection );
}

//--------------------------------------------------------------------------------------------------
// Vertex stage diffuse lighting.
HALF3 EmitDiffuse( float3 vPosition, HALF3 vNormalWS, HALF4 vLightingRegions, inout HALF3 cVertexSpecularLighting, inout HALF3 cVertexShadowSpecularLighting, inout HALF3 cVertexShadowSpecularLighting2 ) {
    // Will also generate it for specular lighting color.
    cVertexShadowSpecularLighting = 0;
    HALF3       cVertexDiffuseLighting;
    if ( b_useLighting == 0 ) {
        cVertexDiffuseLighting = 1;
        cVertexSpecularLighting = 0;
        cVertexShadowSpecularLighting2 = 0;
    } else {
        HALF3 vHalfVecWS = ComputeHalfVector( vPosition );
        
        // :FIXME: :HACK: I'm passing in an empty vertex transport, knowing only the Kajiya-kay shading model needs it, 
        // and Kajiya-Kay is only supported pixel shader side.
        VertexTransport vertOut;
        if ( b_useShadows )
            Lighting(   vertOut, false, vPosition, vNormalWS, 1.0f, 1.0f, p_vSpecColorSpecularity.w, vLightingRegions, EXCLUDE_SHADOWLIGHT,
                        cVertexDiffuseLighting, cVertexSpecularLighting, cVertexShadowSpecularLighting2, vHalfVecWS );
        else {
            HALF fAmbientOcclusion;
            if ( b_UseVertexBasedAmbientOcclusion )
                fAmbientOcclusion = INTERPOLANT_VectorUI1.a;
            else 
                fAmbientOcclusion = 1.0f;
            Lighting(   vertOut, false, vPosition, vNormalWS, 1.0f, fAmbientOcclusion, p_vSpecColorSpecularity.w, vLightingRegions, ALL_LIGHTS,
                        cVertexDiffuseLighting, cVertexSpecularLighting, cVertexShadowSpecularLighting2, vHalfVecWS );
        }
    }
     
    return cVertexDiffuseLighting;
}

//--------------------------------------------------------------------------------------------------
// Vertex stage specular lighting.
HALF3 EmitSpecular(HALF3 cVertexSpecularLighting) {
    return cVertexSpecularLighting;
}

//--------------------------------------------------------------------------------------------------
// Vertex stage shadow diffuse lighting.
HALF3 EmitShadowDiffuse(HALF3 vNormalWS, HALF4 vLightingRegions, inout HALF3 cVertexShadowSpecularLighting, inout HALF3 cVertexShadowSpecularLighting2 ) {    
    HALF3       cVertexDiffuseLighting;
    if ( b_useLighting == 0 ) {
        cVertexDiffuseLighting = 1;
    } else {
        // :FIXME: :HACK: I'm passing in an empty vertex transport, knowing only the Kajiya-kay shading model needs it, 
        // and Kajiya-Kay is only supported pixel shader side.
        VertexTransport vertOut;
        Lighting(   vertOut, false, 0, vNormalWS, 1.0f, 1.0f, p_vSpecColorSpecularity.w, vLightingRegions, SHADOWLIGHT_ONLY, cVertexDiffuseLighting,
                    cVertexShadowSpecularLighting, cVertexShadowSpecularLighting2, HALF3(0,0,0) );
    }
    return cVertexDiffuseLighting;
}

//--------------------------------------------------------------------------------------------------
// Vertex stage specular lighting.
HALF3 EmitShadowSpecular( HALF3 cVertexShadowSpecularLighting ) {
    return cVertexShadowSpecularLighting;
}

//--------------------------------------------------------------------------------------------------
// Light HALF vector.
HALF3 EmitHalfVec( float3 vPosition, int iIndex ) {
    return ComputeHalfVector( vPosition );
}

#endif