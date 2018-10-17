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
float3 DecodeDepth( HALF3 cDepth ) {
    return dot ( cDepth, float3( 1.0f, 1.0f / 32.0f, 1.0f / 2048.0f ) ) * 10.0f;
}

//--------------------------------------------------------------------------------------------------
float2 GetBackBufferUV( in VertexTransport vertOut, bool handleViewport, bool addOffset ) {
	float2 vResult;
    #if ( VPOS_SEMANTIC )
		vResult = INTERPOLANT_ScreenPos.xy * p_vRecipRenderTargetSizeOffset.xy;
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

//--------------------------------------------------------------------------------------------------
float4 SampleTriPlanarTexture (typeSampler2D sTex, typeTexture2D tTex, float2 uvZPlane, float2 uvYPlane, float2 uvXPlane, float3 weights) {
#ifdef COMPILING_SHADER_FOR_OPENGL
    // when compiling to arbfp1, we don't have support for tex2Dbias.  We plan on contacting the CG team about this,
    // since arbfp1 should techinically have the capability to support this.
    return  tex2D(sTex, uvZPlane) * weights.z + 
            tex2D(sTex, uvYPlane) * weights.y +
            tex2D(sTex, uvXPlane) * weights.x;
#else
    float4 result  = sampleTex2Dbias(tTex, sTex, float4(uvZPlane, 0, -20.f)) * weights.z;
           result += sampleTex2Dbias(tTex, sTex, float4(uvYPlane, 0, -20.f)) * weights.y;
           result += sampleTex2Dbias(tTex, sTex, float4(uvXPlane, 0, -20.f)) * weights.x;

    return result;
#endif
}

#endif  // PIXEL_SHADER

#endif  // PS_UTILS 
