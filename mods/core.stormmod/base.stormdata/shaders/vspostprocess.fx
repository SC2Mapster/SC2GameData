//==================================================================================================
//
// Copyright Blizzard Entertainment 2003-2005
//
// Shared post-processing related functions.
//==================================================================================================

#ifndef VS_POST_PROCESS
#define VS_POST_PROCESS

#include "ShaderSystem.fx"

#ifdef VERTEX_SHADER

ArrayDecl(HALF2) p_vBlurOffsets[b_iSampleCount + 1];
HALF2 p_vSrcSize;

//--------------------------------------------------------------------------------------------------
HALF4 EmitGaussianBlurSample( Input vertIn, int iIndex ) {
    HALF4 vSample    = vertIn.vUV0.xyxy;
    vSample.xy       += float2Ref(p_vBlurOffsets[iIndex * 2 + 1]);
    vSample.zw       += float2Ref(p_vBlurOffsets[iIndex * 2 + 2]);
    return vSample;
}

//--------------------------------------------------------------------------------------------------
HALF4 EmitDownscaleUV0( Input vertIn ) {
    HALF2 vRecipSrcSize               = 1.0f / p_vSrcSize;
    // Sample from the 16 surrounding points. Since bilinear filtering is being used, specify the coordinate
    // exactly halfway between the current texel center (k-1.5) and the neighboring texel center (k-0.5).
    return vertIn.vUV0.xyxy + ( -0.5 + HALF4( -1, -1, 1, -1 ) ) * vRecipSrcSize.xyxy;
}	

//--------------------------------------------------------------------------------------------------
HALF4 EmitDownscaleUV1( Input vertIn ) {
    // :TODO: Fix duplicate.
    HALF2 vRecipSrcSize               = 1.0f / p_vSrcSize;
    return vertIn.vUV0.xyxy + ( -0.5 + HALF4( -1, 1, 1, 1 ) ) * vRecipSrcSize.xyxy;
}

#endif  // VERTEX_SHADER

#endif  // VS_POST_PROCESS