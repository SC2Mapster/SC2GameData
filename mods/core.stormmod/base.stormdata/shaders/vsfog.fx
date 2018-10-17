//==================================================================================================
//
// Copyright Blizzard Entertainment 2003-2006
//
// This is the shader code for fog
//==================================================================================================
#ifndef VS_FOG_H__
#define VS_FOG_H__

#ifdef VERTEX_SHADER

#include "VSCommon.fx"

//--------------------------------------------------------------------------------------------------
// Compute fog color.
HALF4 EmitFogColor( float3 vPosition, float3 triPlanarWeightsWorld=float3(0,0,0)) {
    // vertIn.vPosition is assumed to be in world space at this point.
    return HALF4(triPlanarWeightsWorld, FogDensity( vPosition ) );
}

#endif  // VERTEX_SHADER

#endif  // VS_FOG_H__