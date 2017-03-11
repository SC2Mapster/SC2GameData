//==================================================================================================
//
// Copyright Blizzard Entertainment 2003..
//
// Shader code for bokeh dof, see jjimenez siggraph 2014
//==================================================================================================

#ifndef PS_BOKEH_MEDIAN
#define PS_BOKEH_MEDIAN

static const float2 squareOffsets[] =
{
	{  -1.0, -1.0 },
	{   0.0, -1.0 },
	{   1.0, -1.0 },
	{  -1.0,  0.0 },
	{   0.0,  0.0 },
	{   1.0,  0.0 },
	{  -1.0,  1.0 },
	{   0.0,  1.0 },
	{   1.0,  1.0 },
};


static const float2 circleOffsets[] =
{
	{  0.7071, -0.7071 },
	{ -0.7071,  0.7071 },
	{ -1.0000,  0.0000 },
	{  1.0000,  0.0000 },
	{  0.0000,  0.0000 },
	{ -0.7071, -0.7071 },
	{  0.7071,  0.7071 },
	{ -0.0000, -1.0000 },
	{  0.0000,  1.0000 },
};


void sort3( in out float p1, in out float p2, in out float p3 )
{
	float minValue = min3( p1, p2, p3 );
	float medValue = med3( p1, p2, p3 );
	float maxValue = max3( p1, p2, p3 );

	p1 = minValue;
	p2 = medValue;
	p3 = maxValue;
}


void sort3( in out float3 p1, in out float3 p2, in out float3 p3 )
{
	float3 minValue = min3( p1, p2, p3 );
	float3 medValue = med3( p1, p2, p3 );
	float3 maxValue = max3( p1, p2, p3 );

	p1 = minValue;
	p2 = medValue;
	p3 = maxValue;
}


float Median1( typeTexture2D tColor, typeSampler2D sColor, float2 texCoords, out float p_center, out float p[9] )
{
	// See [Smith1996] Implementing median filters in XC4000E FPGAs

	float2 texelSize = p_vRenderTargetSize.zw;

	p[0] = sampleTex2Dlod( tColor, sColor, float4( texCoords + texelSize * squareOffsets[0], 0.0, 1.0 ) ).a;
	p[1] = sampleTex2Dlod( tColor, sColor, float4( texCoords + texelSize * squareOffsets[1], 0.0, 1.0 ) ).a;
	p[2] = sampleTex2Dlod( tColor, sColor, float4( texCoords + texelSize * squareOffsets[2], 0.0, 1.0 ) ).a;
	sort3( p[0], p[1], p[2] );

	p[3] = sampleTex2Dlod( tColor, sColor, float4( texCoords + texelSize * squareOffsets[3], 0.0, 1.0 ) ).a;
	p[4] = sampleTex2Dlod( tColor, sColor, float4( texCoords + texelSize * squareOffsets[4], 0.0, 1.0 ) ).a;
	p[5] = sampleTex2Dlod( tColor, sColor, float4( texCoords + texelSize * squareOffsets[5], 0.0, 1.0 ) ).a;
	p_center = p[4];
	sort3( p[3], p[4], p[5] );

	p[6] = sampleTex2Dlod( tColor, sColor, float4( texCoords + texelSize * squareOffsets[6], 0.0, 1.0 ) ).a;
	p[7] = sampleTex2Dlod( tColor, sColor, float4( texCoords + texelSize * squareOffsets[7], 0.0, 1.0 ) ).a;
	p[8] = sampleTex2Dlod( tColor, sColor, float4( texCoords + texelSize * squareOffsets[8], 0.0, 1.0 ) ).a;
	sort3( p[6], p[7], p[8] );

	p[6] = max3( p[0], p[3], p[6] );
	p[2] = min3( p[2], p[5], p[8] );

	sort3( p[1], p[4], p[7] );
	sort3( p[2], p[4], p[6] );

	return p[4];
}


float3 Median3( typeTexture2D tColor, typeSampler2D sColor, float2 texCoords )
{
	// See [Smith1996] Implementing median filters in XC4000E FPGAs

	float3 p[9];
	float2 texelSize = p_vRenderTargetSize.zw;

	p[0] = sampleTex2Dlod( tColor, sColor, float4( texCoords + texelSize * circleOffsets[0], 0.0, 1.0 ) ).rgb;
	p[1] = sampleTex2Dlod( tColor, sColor, float4( texCoords + texelSize * circleOffsets[1], 0.0, 1.0 ) ).rgb;
	p[2] = sampleTex2Dlod( tColor, sColor, float4( texCoords + texelSize * circleOffsets[2], 0.0, 1.0 ) ).rgb;
	sort3( p[0], p[1], p[2] );

	p[3] = sampleTex2Dlod( tColor, sColor, float4( texCoords + texelSize * circleOffsets[3], 0.0, 1.0 ) ).rgb;
	p[4] = sampleTex2Dlod( tColor, sColor, float4( texCoords + texelSize * circleOffsets[4], 0.0, 1.0 ) ).rgb;
	p[5] = sampleTex2Dlod( tColor, sColor, float4( texCoords + texelSize * circleOffsets[5], 0.0, 1.0 ) ).rgb;
	sort3( p[3], p[4], p[5] );

	p[6] = sampleTex2Dlod( tColor, sColor, float4( texCoords + texelSize * circleOffsets[6], 0.0, 1.0 ) ).rgb;
	p[7] = sampleTex2Dlod( tColor, sColor, float4( texCoords + texelSize * circleOffsets[7], 0.0, 1.0 ) ).rgb;
	p[8] = sampleTex2Dlod( tColor, sColor, float4( texCoords + texelSize * circleOffsets[8], 0.0, 1.0 ) ).rgb;
	sort3( p[6], p[7], p[8] );

	p[6] = max3( p[0], p[3], p[6] );
	p[2] = min3( p[2], p[5], p[8] );

	sort3( p[1], p[4], p[7] );
	sort3( p[2], p[4], p[6] );

	return p[4];
}

//--------------------------------------------------------------------------------------------------
float4 Bokeh_Median (float2 vUV, out float4 vOutAlpha) {
	float alpha[9];
	float centerAlpha;
	float4 vAlpha = Median1( texTexture(p_sAlphaImage), texSampler(p_sAlphaImage), vUV, centerAlpha, alpha );

	float minValue = min( min3( alpha[0], alpha[1], alpha[2] ), alpha[3] );
	float maxValue = max( max3( alpha[5], alpha[6], alpha[7] ), alpha[8] );

	if ( minValue == DOF_ALPHA_INVALID )
		vAlpha = centerAlpha == DOF_ALPHA_INVALID ? maxValue : centerAlpha;

	vOutAlpha = DecodeAlpha( vAlpha );
	return float4( Median3( texTexture(p_sInputImage), texSampler(p_sInputImage), vUV ), 1.0 );
}

#endif // Inclusion guard