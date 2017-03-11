//==================================================================================================
//
// Copyright Blizzard Entertainment 2003..
//
// Shader code for bokeh dof, see jjimenez siggraph 2014
//==================================================================================================

#ifndef PS_BOKEH_TILENEIGHBOR
#define PS_BOKEH_TILENEIGHBOR

//--------------------------------------------------------------------------------------------------
float4 Bokeh_TileNeighbor(float2 vUV) {
    float2 texelSize = p_vTileRTSize.zw;

    float maxCoc, minCoc, closestDepth;
    maxCoc = DOF_MIN_COC;
    minCoc = DOF_MAX_COC;
    closestDepth = HALF_MAX;

    [unroll]
    for ( float i = -2.0; i <= 2.0; i += 1.0 )
    {
        [unroll]
        for ( float j = -2.0; j <= 2.0; j += 1.0 )
        {
            float3 cocDepth = sample2D( p_sInputImage, vUV + texelSize * float2( i, j ) ).rgb;

            if ( i > -2.0 && i < 2.0 && j > -2.0 && j < 2.0 )
            {
                maxCoc = max( maxCoc, cocDepth.r );
                minCoc = min( minCoc, cocDepth.g );
            }
            
            closestDepth = min( closestDepth, cocDepth.b );
        }
    }

    TileParams tileParams;
    tileParams.maxCoc = max( ClampCoc( maxCoc ), ClampCoc( minCoc ) );
    tileParams.nearestViewDepth = closestDepth;
    tileParams.cocDelta = TileCocDeltaFactor( abs( clamp( maxCoc, DOF_MIN_COC, DOF_MAX_COC ) - clamp( minCoc, DOF_MIN_COC, DOF_MAX_COC ) ), p_fMaxCoCRadius );
    tileParams.foregroundCoc = CalculateCoc( closestDepth, p_vDoFEquation );

    return PackTileParams( tileParams );
}

#endif