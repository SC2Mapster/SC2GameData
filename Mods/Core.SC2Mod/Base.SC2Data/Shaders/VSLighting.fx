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

half3       g_cVertexSpecularLighting;                 // Vertex stage specular lighting result.
half3		g_cVertexShadowSpecularLighting;
half3		g_cVertexShadowSpecularLighting2;

//--------------------------------------------------------------------------------------------------
// Calculate lighting specular half vectors for key light.
half3 ComputeHalfVector( half3 vPosWS ) {
	return ComputeHalfVector( vPosWS, p_directionalLights[0].vDirection );
}

//--------------------------------------------------------------------------------------------------
// Vertex stage diffuse lighting.
half3 EmitDiffuse( Input vertIn, half3 vNormalWS ) {
    // Will also generate it for specular lighting color.
    half3       cVertexDiffuseLighting;
    g_vHalfVecWS = ComputeHalfVector( vertIn.vPosition.xyz );
    
    // :FIXME: :HACK: Skanky, but I'm passing in an empty vertex transport, knowing only the Kajiya-kay shading model needs it, 
    // and Kajiya-Kay is only supported pixel shader side.
    VertexTransport vertOut;
    if ( b_useShadows )
	    Lighting(   vertOut, false, vertIn.vPosition.xyz, vNormalWS, 1.0f, 1.0f, EXCLUDE_SHADOWLIGHT, 
                    cVertexDiffuseLighting, g_cVertexSpecularLighting, g_cVertexShadowSpecularLighting2 );
    else {
		half fAmbientOcclusion;
		if ( b_UseVertexBasedAmbientOcclusion )
			fAmbientOcclusion = INTERPOLANT_VertexColor.a;
		else 
			fAmbientOcclusion = 1.0f;
		Lighting(   vertOut, false, vertIn.vPosition.xyz, vNormalWS, 1.0f, fAmbientOcclusion, ALL_LIGHTS, 
                    cVertexDiffuseLighting, g_cVertexSpecularLighting, g_cVertexShadowSpecularLighting2 );
    }
     
    return cVertexDiffuseLighting;
}

//--------------------------------------------------------------------------------------------------
// Vertex stage specular lighting.
half3 EmitSpecular( Input vertIn ) {
    return g_cVertexSpecularLighting;
}

//--------------------------------------------------------------------------------------------------
// Vertex stage shadow diffuse lighting.
half3 EmitShadowDiffuse( Input vertIn, half3 vNormalWS ) {    
    half3       cVertexDiffuseLighting;
    // :FIXME: :HACK: Skanky, but I'm passing in an empty vertex transport, knowing only the Kajiya-kay shading model needs it, 
    // and Kajiya-Kay is only supported pixel shader side.
    VertexTransport vertOut;
    Lighting(   vertOut, false, 0, vNormalWS, 1.0f, 1.0f, SHADOWLIGHT_ONLY, cVertexDiffuseLighting, 
                g_cVertexShadowSpecularLighting, g_cVertexShadowSpecularLighting2 );
    return cVertexDiffuseLighting;
}

//--------------------------------------------------------------------------------------------------
// Vertex stage specular lighting.
half3 EmitShadowSpecular( Input vertIn ) {
    return g_cVertexShadowSpecularLighting;
}

//--------------------------------------------------------------------------------------------------
// Light half vector.
half3 EmitHalfVec( Input vertIn, int iIndex ) {
    return ComputeHalfVector( vertIn.vPosition.xyz );
}

#endif