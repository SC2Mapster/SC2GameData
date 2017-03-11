//==================================================================================================
//
// Copyright Blizzard Entertainment 2003..
//
// Shader code for bokeh dof, see jjimenez siggraph 2014
//==================================================================================================

#ifndef PS_BOKEH_TILE
#define PS_BOKEH_TILE

//--------------------------------------------------------------------------------------------------
float4 Bokeh_TileDownSample(float2 vUV) {

    float2 coord = vUV + p_vPixelTransform.xy;

    float maxCoc = DOF_MIN_COC;
    float minCoc = DOF_MAX_COC;
    float closestDepth = HALF_MAX;

    [unroll]
    for ( int i = 0; i < SAMPLE_COUNT; i++ )
    {
        float3 cocDepth;
        if (b_iBokehPass == BOKEH_TILEDOWNSAMPLE0) {
            cocDepth.b = SampleNormalDepth( texSampler(p_sDepthImage), texTexture(p_sDepthImage), coord + p_vPixelTransform.zw * float( i ) ).a;
            cocDepth.rg = CalculateUnclampedCoc( cocDepth.b, p_vDoFEquation );
        }
        else
            cocDepth = sample2D( p_sInputImage, coord + p_vPixelTransform.zw * float( i ) ).rgb;

        maxCoc = max( maxCoc, cocDepth.r );
        minCoc = min( minCoc, cocDepth.g );
        closestDepth = min( closestDepth, cocDepth.b );
    }

    return float4( maxCoc, minCoc, closestDepth, 0.0 );
}

#endif // Inclusion guard