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

float3      p_vFogDensity_Falloff_MinHeight;
float4      p_cFogColor;
float3      p_vFogDistance;     // x is near plane, y is far plane, z is distance falloff


//==================================================================================================
// Compute fog density.
float FogDensity ( float3 vPosWorld ) {
    float3 vViewVect = vPosWorld - p_vEyePos;
    float fDist = length(vViewVect);
    float fFogIntegration = p_vFogDensity_Falloff_MinHeight.x * fDist * exp((p_vFogDensity_Falloff_MinHeight.z-p_vEyePos.z) * p_vFogDensity_Falloff_MinHeight.y);

    const float c_fSlopeEps = 0.01f;
    if (abs(vViewVect.z)>c_fSlopeEps) {
        float fT = p_vFogDensity_Falloff_MinHeight.y * vViewVect.z;
#if COMPILING_SHADER_FOR_OPENGL
        fT += 0.000001f;
        //Cap it so exp(-fT) is just below float max
        fT = min(fT, 88.0f);
        fT = max(fT, -88.0f);
#endif
        fFogIntegration *= (1.0f - exp(-fT)) / fT;
    }

    float fOutDensity = fFogIntegration ;
    
    if (p_vFogDistance.z > 0.f) {
        if (p_vFogDistance.y != p_vFogDistance.x) {
            fOutDensity = fFogIntegration * saturate(p_vFogDistance.z * (fDist - p_vFogDistance.x) / (p_vFogDistance.y - p_vFogDistance.x));
        }
        else {
            fOutDensity = fFogIntegration;
        }
    }
    return saturate(fOutDensity);
}

//--------------------------------------------------------------------------------------------------
// Compute fog color.
half4 EmitFogColor( Input vertIn ) {
    // vertIn.vPosition is assumed to be in world space at this point.
    return half4( p_cFogColor.rgb, FogDensity( vertIn.vPosition.xyz ) );
}

#endif  // VERTEX_SHADER

#endif  // VS_FOG_H__