//==================================================================================================
//
// Copyright Blizzard Entertainment 2003-2005
//
// Shared post-processing related functions.
//==================================================================================================

#ifndef PS_POST_PROCESS
#define PS_POST_PROCESS

#ifdef PIXEL_SHADER

#include "ShaderSystem.fx"
#include "PSCommon.fx"

// :TODO: Move this.
sampler2D   p_sSrcMap;			    // Source texture map.
sampler2D   p_sWeightMap;           // Weight map for blurring.
sampler2D   p_sSeparateBlurMap;
HALF2       p_vSrcSize;				// Source texture map size.
HALF4       p_vRecipSrcSizeOffset;

#include "PSDOF.fx"
#include "PSSSAO.fx"

#define MODE_Copy                   0
#define MODE_SetValue               1
#define MODE_GaussianBlur           2
#define MODE_Downscale		        3
#define MODE_COC		            4
#define MODE_DOF				    5
#define MODE_SSAO                   6
#define MODE_ConvertToGradient	    7
#define MODE_DepthEncode    	    8

#define CHANNEL_ALL                 0
#define CHANNEL_RED                 1
#define CHANNEL_GREEN               2
#define CHANNEL_BLUE                3
#define CHANNEL_ALPHA               4

#define PostProcessMode( x )    if ( b_iMode == MODE_##x ) cResult = PostProcess##x( vertOut );

HALF4       p_vScale;					// Value scale.
HALF        p_fAdd;					    // Value add.

//==================================================================================================
// Copy mode.
half4 PostProcessCopy( VertexTransport vertOut ) {
    half4 cResult = tex2D( p_sSrcMap, INTERPOLANT_UV[0].xy );
    return cResult;
}

//==================================================================================================
// Set value mode.
float4      p_vValue;				    // Value to set.

//--------------------------------------------------------------------------------------------------
half4 PostProcessSetValue( VertexTransport vertOut ) {
    return p_vValue;
}

//==================================================================================================
// Downscale mode.
//--------------------------------------------------------------------------------------------------
half4 PostProcessDownscale( VertexTransport vertOut ) {
    // 4x4 Bilinear downscale.
    half4 cResult = ( tex2D( p_sSrcMap, INTERPOLANT_DownscaleUV0.xy ) + tex2D( p_sSrcMap, INTERPOLANT_DownscaleUV0.zw ) +
                      tex2D( p_sSrcMap, INTERPOLANT_DownscaleUV1.xy ) + tex2D( p_sSrcMap, INTERPOLANT_DownscaleUV1.zw ) ) * 
                      half4(0.25f, 0.25f, 0.25f, 0.25f);
	return cResult;
}

//==================================================================================================
// Convert to gradient mode.
HALF		p_fGradientScale;
HALF3		p_cGradientStartColor;
HALF3		p_cGradientEndColor;

//--------------------------------------------------------------------------------------------------
half4 PostProcessConvertToGradient( VertexTransport vertOut ) {
    return  half4(  lerp( p_cGradientStartColor, p_cGradientEndColor, 
                    saturate( tex2D( p_sSrcMap, INTERPOLANT_UV[0].xy ).a / p_fGradientScale ) ), 1.0f );
}

//==================================================================================================
// Depth encode mode.

sampler2D   p_sDepthEncodeRG;
sampler2D   p_sDepthEncodeB;

//--------------------------------------------------------------------------------------------------
half4 PostProcessDepthEncode( VertexTransport vertOut ) {
    half4 vResult;
    float fDepth = saturate( tex2D( p_sSrcMap, INTERPOLANT_UV[0].xy ).a / 10.0f );   // Map to [0..1]
    vResult.rg = tex2D( p_sDepthEncodeRG, float2( fDepth, fDepth * 32.0f ) ).rg;
    vResult.ba = tex2D( p_sDepthEncodeB, float2( fDepth * 2048.0f, fDepth * 2048.0f ) ).bb;
    return vResult;
}

//==================================================================================================
// Gaussian blur mode.
HALF p_fBlurWeights[b_iSampleCount + 1];
HALF2 p_vBlurOffsets[b_iSampleCount + 1];

float4 p_vBlurViewport;      // xy is top left, zw is bottom right.

//--------------------------------------------------------------------------------------------------
half4 PostProcessGaussianBlur( VertexTransport vertOut ) {
#if ( b_iMode == MODE_GaussianBlur || CPP_SHADER )    // Need an ifdef because INTERPOLANT_GaussianBlurSample may not be present
    half2 vCenterTap    = INTERPOLANT_UV[0].xy;
    half4 cValue        = tex2D( p_sSrcMap, vCenterTap.xy );
    half4 cResult       = cValue * p_fBlurWeights[0];
    float fTotalWeight  = p_fBlurWeights[0];
    
    float4 vNormalDepth = 0;
    if ( b_iInteriorBlur )
        vNormalDepth = SampleNormalDepth( p_sNormalDepthMap, vCenterTap.xy );
    else {
        vNormalDepth.a = SampleNormalDepth( p_sNormalDepthMap, vCenterTap.xy ).a;
        // :TODO: SSAO might need this.
        //if ( b_iLayeredBlur )
        //    vNormalDepth.a += 0.01f;   // Add some slack for layered blur.
    }
    for ( int i = 0; i < b_iSampleInterpolantCount; i++ ) {
        float2 tapUV = INTERPOLANT_GaussianBlurSample[i].xy;
        if ( b_iConstrainToViewport ) {
            tapUV = max( tapUV, p_vBlurViewport.xy );
            tapUV = min( tapUV, p_vBlurViewport.zw );
        }

        half4 cValue;
        if ( b_iUseSeparateBlurMap )
            cValue = tex2D( p_sSeparateBlurMap, tapUV );
        else cValue = tex2D( p_sSrcMap, tapUV );
        half fWeight = p_fBlurWeights[i * 2 + 1];
        
        if ( b_iInteriorBlur ) {
            float4 vSampleNormalDepth = tex2D( p_sNormalDepthMap, tapUV );
            if ( dot( vSampleNormalDepth.rgb, PIXEL_NORMAL ) < 0.9f || abs( vSampleNormalDepth.a - PIXEL_DEPTH ) > 0.01f )
                fWeight = 0.0f;
        }
        if ( b_iWeightedBlur )
            fWeight *= tex2D( p_sWeightMap, tapUV ).a;
        if ( b_iLayeredBlur ) {
            float vDepth = SampleNormalDepth( p_sNormalDepthMap, tapUV );
            if ( PIXEL_DEPTH < vDepth )
                fWeight = 0.0f;
        }

        cResult += cValue * fWeight;
        fTotalWeight += fWeight;

        tapUV = INTERPOLANT_GaussianBlurSample[i].zw;
        if ( b_iConstrainToViewport ) {
            tapUV = max( tapUV, p_vBlurViewport.xy );
            tapUV = min( tapUV, p_vBlurViewport.zw);
        }

        if ( b_iUseSeparateBlurMap )
            cValue = tex2D( p_sSeparateBlurMap, tapUV );
        else cValue = tex2D( p_sSrcMap, tapUV );
        fWeight = p_fBlurWeights[i * 2 + 2];
        if ( b_iInteriorBlur ) {
            float4 vSampleNormalDepth = tex2D( p_sNormalDepthMap, tapUV );
            if ( dot( vSampleNormalDepth.rgb, PIXEL_NORMAL < 0.9f ) || abs( vSampleNormalDepth.a - PIXEL_DEPTH ) > 0.01f )
                fWeight = 0.0f;
        }
        if ( b_iWeightedBlur )
            fWeight *= tex2D( p_sWeightMap, tapUV ).a;
        if ( b_iLayeredBlur ) {
            float vDepth = tex2D( p_sNormalDepthMap, tapUV ).a;
            if ( PIXEL_DEPTH < vDepth )    
                fWeight = 0.0f;
        }
        cResult += cValue * fWeight;
        fTotalWeight += fWeight;
    }
    
    if ( b_iInteriorBlur || b_iWeightedBlur || b_iLayeredBlur )
		cResult *= 1.0f / fTotalWeight;

    if ( b_iBlurAlpha )
        cResult.rgb = 0;         // Discard color.
    else
        cResult.a = cValue.a;    // Use original alpha.

    return cResult;
#else
    return 0;
#endif
}

//==================================================================================================
// Main post-processing entry point.
half4 PostProcess( VertexTransport vertOut ) {
    half4 cResult;
    PostProcessMode( Copy );
    PostProcessMode( SetValue );
    PostProcessMode( GaussianBlur );
    PostProcessMode( Downscale );
    PostProcessMode( COC );
    PostProcessMode( DOF );
    PostProcessMode( SSAO );
    PostProcessMode( ConvertToGradient );
    PostProcessMode( DepthEncode );

    if ( b_iInputChannelFilter == CHANNEL_RED )
        cResult = cResult.r;
    else if ( b_iInputChannelFilter == CHANNEL_GREEN )
        cResult = cResult.g;
    else if ( b_iInputChannelFilter == CHANNEL_BLUE )
        cResult = cResult.b;
    else if ( b_iInputChannelFilter == CHANNEL_ALPHA )
        cResult = cResult.a;

    if ( b_iScaleOutput )
        cResult *= p_vScale;
    if ( b_iAddToOutput )
        cResult += p_fAdd;
    if ( b_iOutputChannelFilter == CHANNEL_RED )
        cResult = cResult.r;
    else if ( b_iOutputChannelFilter == CHANNEL_GREEN )
        cResult = cResult.g;
    else if ( b_iOutputChannelFilter == CHANNEL_BLUE )
        cResult = cResult.b;
    else if ( b_iOutputChannelFilter == CHANNEL_ALPHA )
        cResult = cResult.a;
    if ( b_iClampNegativeOutput )
        cResult = max( half4(0.0f, 0.0f, 0.0f, 0.0f), cResult );

    return cResult;
}

#endif  // PIXEL_SHADER

#endif  // PS_POST_PROCESS