//==================================================================================================
//
// Copyright Blizzard Entertainment 2003..
//
// Shader code for bokeh dof, see jjimenez siggraph 2014
//==================================================================================================

#ifndef PS_BOKEH_SMALLFILTER
#define PS_BOKEH_SMALLFILTER


#if DOF_SMALL_FILTER_DITHER == 1
#define DITHER_SAMPLE_COUNT_DIVIDER		2
#else // #if DOF_SMALL_FILTER_DITHER
#define DITHER_SAMPLE_COUNT_DIVIDER		1
#endif // #else // #if DOF_SMALL_FILTER_DITHER

//#if defined( XB3 )
//#define DOF_SMALL_FILTER_SAMPLE_COUNT	8
//#else // #if defined( XB3 )
#define DOF_SMALL_FILTER_SAMPLE_COUNT	16
//#endif // #else // #if defined( XB3 )

#if DOF_SMALL_FILTER_SAMPLE_COUNT == 16
#define DOF_SMALL_FILTER_RADIUS			3
static const float3 c_vSmallFilterOffsets[] =
{
	// First HALF:
	{  0.3535, -0.3535, 1.5 },
	{ -0.3535, -0.3535, 1.5 },
	{  0.2588, -0.9659, 3.0 },
	{ -0.2588, -0.9659, 3.0 },
	{  0.7071, -0.7071, 3.0 },
	{ -0.7071, -0.7071, 3.0 },
	{  0.9659, -0.2588, 3.0 },
	{ -0.9659, -0.2588, 3.0 },

	// Second HALF:
	{ -0.3535,  0.3535, 1.5 },
	{  0.3535,  0.3535, 1.5 },
	{ -0.2588,  0.9659, 3.0 },
	{  0.2588,  0.9659, 3.0 },
	{ -0.7071,  0.7071, 3.0 },
	{  0.7071,  0.7071, 3.0 },
	{ -0.9659,  0.2588, 3.0 },
	{  0.9659,  0.2588, 3.0 },
};
#elif DOF_SMALL_FILTER_SAMPLE_COUNT == 8
#define DOF_SMALL_FILTER_RADIUS			2
static const float3 c_vSmallFilterOffsets[] =
{
	// First HALF:
	{  0.5,  0.5, 1.0 },
	{  0.5, -0.5, 1.0 },
	{  1.0,  0.0, 2.0 },
	{  0.0,  1.0, 2.0 },

	// Second HALF:
	{ -0.5, -0.5, 1.0 },
	{ -0.5,  0.5, 1.0 },
	{ -1.0,  0.0, 2.0 },
	{ -0.0, -1.0, 2.0 },
};
#else
#error invalid DOF_SMALL_FILTER_SAMPLE_COUNT
#endif

#define DOF_SMALL_FILTER_MAX_RADIUS ( ( 1.0 + DOF_HALF_RES_BIAS ) / DOF_HALF_RES_SCALE )


float3 SmallFilter( typeTexture2D tColor, typeSampler2D sColor, typeTexture2D tDepth, typeSampler2D sDepth, float2 texCoords, float3 centerColor, float centerDepth, float centerCoc, float maxCoCRadius, float2 cocXform, TileParams tileParams, float karisInvSharpness )
{
#if DOF_SMALL_FILTER_DITHER
	float noise = NoiseSpatioTemporalDither1D_1( texCoords * renderTargetSize.xy, 1.0, false );
#else // #if DOF_SMALL_FILTER_DITHER
	float noise = 1.0;
#endif // #else // #if DOF_SMALL_FILTER_DITHER

	float2 scale = ( noise * min( centerCoc, DOF_SMALL_FILTER_MAX_RADIUS * rcp( maxCoCRadius ) ) ) * cocXform.xy;

	float spreadScale = DOF_SMALL_FILTER_RADIUS / centerCoc;

	float4 color = float4( centerColor, 1.0 );

#if DOF_SMALL_FILTER_KARIS_AVG
	color *= 1.0 / ( 1.0 + Luma( color.rgb ) );
#endif // #if DOF_SMALL_FILTER_KARIS_AVG

#if DOF_TILE_OPTIMIZATION
	[branch]
	if ( tileParams.cocDelta > 0.0 )
#endif // #if DOF_TILE_OPTIMIZATION
	{
		[unroll]
		for ( int i = 0; i < DOF_SMALL_FILTER_SAMPLE_COUNT / DITHER_SAMPLE_COUNT_DIVIDER; i++ )
		{
			float offsetCoc = c_vSmallFilterOffsets[i].z;

			float2 sampleTexCoords = texCoords + scale * c_vSmallFilterOffsets[i].xy;
			float4 sampleColor = float4( sampleTex2Dlod( tColor, sColor, float4( sampleTexCoords, 0.0, 1.0 ) ).rgb, 1.0 );
			float4 sampleDepth = tex2DGatherDepth( tDepth, sDepth, sampleTexCoords, 0, p_vRenderTargetSize );

			float weight;
            //if (BOKEH_USE_LEGACY_COC)
                weight = saturate( 1.0 - max4( abs( sampleDepth - centerDepth ) / DOF_DEPTH_SCALE_SURFACE_CLIP ) );
            //else
            //    weight = saturate( 1.0 - DOF_DEPTH_SCALE_SURFACE_CLIP * max4( abs( sampleDepth - centerDepth ) ) );

			sampleColor *= lerp( 1.0, weight, tileParams.cocDelta );

#if DOF_SMALL_FILTER_KARIS_AVG
			sampleColor *= KarisWeight( sampleColor.rgb, karisInvSharpness );
#endif // #if DOF_SMALL_FILTER_KARIS_AVG

			color += sampleColor;
		}
	}
#if DOF_TILE_OPTIMIZATION
	else
	{
		[unroll]
		for ( int i = 0; i < DOF_SMALL_FILTER_SAMPLE_COUNT / DITHER_SAMPLE_COUNT_DIVIDER; i++ )
		{
			float2 sampleTexCoords = texCoords + scale * c_vSmallFilterOffsets[i].xy;
			float4 sampleColor = float4( sampleTex2Dlod( tColor, sColor, float4( sampleTexCoords, 0.0, 1.0 ) ).rgb, 1.0 );

#if DOF_SMALL_FILTER_KARIS_AVG
			sampleColor *= KarisWeight( sampleColor.rgb, karisInvSharpness );
#endif // #if DOF_SMALL_FILTER_KARIS_AVG

			color += sampleColor;
		}
	}
#endif // #if DOF_TILE_OPTIMIZATION

	color.rgb /= max( color.w, DOF_EPS );

	return color.rgb;
}

#endif // Inclusion guard