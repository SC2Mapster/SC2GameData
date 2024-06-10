//==================================================================================================
//
// Copyright Blizzard Entertainment 2003-2007
//
// Common shader code.
//==================================================================================================

#ifndef PS_UTILS
#define PS_UTILS

#ifdef PIXEL_SHADER

#include "ShaderSystem.fx"

float4		p_vRecipRenderTargetSizeOffset;


//--------------------------------------------------------------------------------------------------
float3 Yuv2Rgb (float y, float u, float v) {
    return float3(y+1.402f*(v-0.5f), y-0.34414f*(u-0.5f) - 0.71414f*(v-0.5f), y+1.772f*(u-0.5f));
}

//--------------------------------------------------------------------------------------------------
float3 DecodeDXT5Normal( float4 vNormalSample ) {
    float3 norm;
    norm.xy = 2.0f * vNormalSample.wy - 1.0f;
    norm.z = sqrt(max(0, 1 - dot(norm.xy, norm.xy)));
    return norm;
}

//--------------------------------------------------------------------------------------------------
float3 DecodeDepth( half3 cDepth ) {
    return dot ( cDepth, float3( 1.0f, 1.0f / 32.0f, 1.0f / 2048.0f ) ) * 10.0f;
}

//--------------------------------------------------------------------------------------------------
float2 GetBackBufferUV( in VertexTransport vertOut, bool handleViewport, bool addOffset ) {
	float2 vResult;
    #if ( VPOS_SEMANTIC )
		vResult = INTERPOLANT_HPosAsUV.xy * p_vRecipRenderTargetSizeOffset.xy;
    #else
	    float2 vPos = INTERPOLANT_HPosAsUV.xy / INTERPOLANT_HPosAsUV.w;
	    vResult = vPos.xy * float2( 0.5f, -0.5f ) + 0.5f;     // To [0..1]
	    if ( handleViewport )
		    vResult = p_vViewportOrigin + vResult * p_vViewportScale;
    #endif
    if ( addOffset )
		vResult += p_vRecipRenderTargetSizeOffset.zw;
	return vResult;
}

//--------------------------------------------------------------------------------------------------
float OutputDepth( in VertexTransport vertOut ) {
    return INTERPOLANT_ViewPos.y;
}

#endif  // PIXEL_SHADER

#endif  // PS_UTILS 
