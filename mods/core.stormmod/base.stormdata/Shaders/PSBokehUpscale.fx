//==================================================================================================
//
// Copyright Blizzard Entertainment 2003..
//
// Shader code for bokeh dof, see jjimenez siggraph 2014
//==================================================================================================

#ifndef PS_BOKEH_UPSCALE
#define PS_BOKEH_UPSCALE

#include "PSBokehSmallFilter.fx"

//--------------------------------------------------------------------------------------------------
float ViewDepthForPixel( const float2 vUV )
{
    return SampleNormalDepth( texSampler(p_sDepthImage), texTexture(p_sDepthImage), vUV ).a;
}

//--------------------------------------------------------------------------------------------------
float4 Bokeh_Upsample (float2 vUV) {
    float4 vOutColor;
	TileParams tileParams = UnpackTileParams( sample2D( p_sTileImage, vUV ) );

	float centerDepth = ViewDepthForPixel( vUV );
	float centerCoc = CalculateCoc( centerDepth, p_vDoFEquation );

	float backgroundFactor = HalfResFactor( centerCoc, p_fMaxCoCRadius );

	float3 colorHalfRes = sample2D( p_sInputImageLinear, vUV ).rgb;

#if DOF_TILE_OPTIMIZATION
	float cocDelta = max4( tex2DGatherBlue( texTexture(p_sTileImage), texSampler(p_sTileImage), vUV, 0, p_vTileRTSize ) );

	[branch]
	if ( cocDelta > 0.0 || backgroundFactor < 1.0 )
#endif // #if DOF_TILE_OPTIMIZATION
	{
#if DOF_UPSCALE_VIEWMODEL_HACK
		float depthDelta = DepthCmp1( centerDepth, tileParams.nearestViewDepth );
		float foregroundCoc = lerp( tileParams.maxCoc, centerCoc, pow( depthDelta, DOF_UPSCALE_VIEWMODEL_HACK_GAMMA ) );
#else // #if DOF_UPSCALE_VIEWMODEL_HACK
		float foregroundCoc = tileParams.foregroundCoc;
#endif // #else // #if DOF_UPSCALE_VIEWMODEL_HACK

		float foregroundFactor = HalfResFactor( foregroundCoc, p_fMaxCoCRadius );

		float alpha = sample2D( p_sAlphaImage, vUV ).a;

#if !DOF_TILE_DEBUG
		float halfResFactor = lerp( backgroundFactor, foregroundFactor, alpha );
#else // #if !DOF_TILE_DEBUG
		float halfResFactor = 1.0;
#endif // #else // #if !DOF_TILE_DEBUG

		float3 colorFullRes = sample2Dlod( p_sInputImage, float4( vUV, 0.0, 1.0 ) ).rgb;
		[branch]
		if ( halfResFactor < 1.0 )
			colorFullRes = SmallFilter( texTexture(p_sFullImageLinear), texSampler(p_sFullImageLinear), texTexture(p_sDepthImage), texSampler(p_sDepthImage), vUV, colorFullRes, centerDepth, centerCoc, p_fMaxCoCRadius, p_vCoCTransform, tileParams, p_fKarisInvSharpness );

		vOutColor = float4( lerp( colorFullRes, colorHalfRes, halfResFactor ), 1.0 );
	}
#if DOF_TILE_OPTIMIZATION
	else
	{
		vOutColor = float4( colorHalfRes, 1.0 );
	}
#endif // #if DOF_TILE_OPTIMIZATION

	return vOutColor;
}

#endif // Inclusion guard