//==================================================================================================
//
// Copyright Blizzard Entertainment 2003..
//
// Shader code for bokeh dof, see jjimenez siggraph 2014
//==================================================================================================

#ifndef PS_BOKEH_CIRCULARFILTER
#define PS_BOKEH_CIRCULARFILTER

#include "PSBokehCircularFilterOffsets.fx"

//--------------------------------------------------------------------------------------------------
float NoiseSpatialInterleavedGradient1D( float2 position, float scale )
{
    float3 magic = float3( 0.06711056, 0.00583715, 52.9829189 );
    return -scale + 2.0 * scale * frac( magic.z * frac( dot( position, magic.xy ) ) );
}


//--------------------------------------------------------------------------------------------------
void DofInternalTile( int j, float2 texCoords, float2 scale, float noise, float spreadScale, in out float4 background, in out float4 foreground, in out float3 accumulation )
{
#if !COMPILING_SHADER_WITH_BSL
    [unroll]
#endif
    for ( int i = ringSampleCount[j]; i < ringSampleCount[j + 1]; i++ )
    {
        float offsetCoc = c_vCircleOffsets[i].z;

        float2 sampleNoise = noise * p_vRenderTargetSize.zw * ( 1.0 - offsetCoc * ( 1.0 / DOF_RING_COUNT ) );
        float2 sampleTexCoords = texCoords + scale * c_vCircleOffsets[i].xy + sampleNoise;

        float3 sampleColor = sample2Dlod( p_sInputImage, float4( sampleTexCoords, 0.0, 1.0 ) ).rgb;
        PrepassParams samplePrepassParams = UnpackPrepassParams( sample2Dlod( p_sPrepassImage, float4( sampleTexCoords, 0.0, 1.0 ) ) );

        float spreadCmp = SpreadCmp( offsetCoc, samplePrepassParams.coc, spreadScale );
        samplePrepassParams.backgroundWeight *= spreadCmp;
        samplePrepassParams.foregroundWeight *= spreadCmp;

        background += samplePrepassParams.backgroundWeight * float4( sampleColor.rgb, 1.0 );
        foreground += samplePrepassParams.foregroundWeight * float4( sampleColor.rgb, 1.0 );

#if DOF_TILE_OPTIMIZATION
        accumulation += sampleColor.rgb;
#endif // #if DOF_TILE_OPTIMIZATION
    }
}


//--------------------------------------------------------------------------------------------------
void DofInternalFast( int j, float2 texCoords, float2 scale, float noise, in out float3 color )
{
#if !COMPILING_SHADER_WITH_BSL
    [unroll]
#endif
    for ( int i = ringSampleCount[j]; i < ringSampleCount[j + 1]; i++ )
    {
        float offsetCoc = c_vCircleOffsets[i].z;
        float2 sampleNoise = noise * p_vRenderTargetSize.zw * ( 1.0 - offsetCoc * ( 1.0 / DOF_RING_COUNT ) );
        float2 sampleTexCoords = texCoords + scale * c_vCircleOffsets[i].xy + sampleNoise;
        color += sample2Dlod( p_sInputImageLinear, float4( sampleTexCoords, 0.0, 1.0 ) ).rgb;
    }
}


//--------------------------------------------------------------------------------------------------
float4 Bokeh_CircularFilter(float2 vUV, out float4 vOutAlpha) {
    float4 vOutColor;

    TileParams tileParams = UnpackTileParams( sample2D( p_sTileImage, vUV ) );

    float3 centerColor = sample2D( p_sInputImage, vUV ).rgb;

#if DOF_TILE_OPTIMIZATION
    [branch]
    if ( HalfResFactor( tileParams.maxCoc, p_fMaxCoCRadius ) == 0.0 )
    {
        vOutAlpha = DOF_ALPHA_INVALID;
        vOutColor = float4( centerColor, 1.0 );

        vOutColor = DOF_TILE_DEBUG_COLOR( vOutColor, 0 );
        return vOutColor;
    }
#endif // #if DOF_TILE_OPTIMIZATION

    PrepassParams centerPrepassParams = UnpackPrepassParams( sample2Dlod( p_sPrepassImage, float4( vUV, 0.0, 1.0 ) ) );

    float noise = NoiseSpatialInterleavedGradient1D( vUV * p_vRenderTargetSize.xy, 0.25 );

    int maxRing;
    float ringScale;
    CalculateRingParams( DOF_MAX_RING_COUNT, DOF_RING_COUNT, tileParams.maxCoc, noise, maxRing, ringScale );

    float2 texCoords = vUV;

    float2 scale = ( ringScale * tileParams.maxCoc ) * p_vCoCTransform.xy;

#if DOF_TILE_OPTIMIZATION
    [branch]
    if ( tileParams.cocDelta > 0.0 )
#endif // #if DOF_TILE_OPTIMIZATION
    {
        float spreadScale = maxRing / tileParams.maxCoc;

        float3 accumulation = centerColor;

        float4 background = centerPrepassParams.backgroundWeight * float4( centerColor, 1.0 );
        float4 foreground = centerPrepassParams.foregroundWeight * float4( centerColor, 1.0 );

#if DOF_RING_MANUAL_UNROLL
        [unroll]
        for ( int j = 0; j < DOF_RING_COUNT; j++ )
        {
            [branch]
            if ( j < maxRing )
                DofInternalTile( j, texCoords, scale, noise, spreadScale, background, foreground, accumulation );
        }
#else // #if !DOF_RING_MANUAL_UNROLL
        DofInternalTile( 0, texCoords, scale, noise, spreadScale, background, foreground, accumulation );
#if DOF_RING_COUNT > 1
        [branch]
        if ( maxRing > 1 )
            DofInternalTile( 1, texCoords, scale, noise, spreadScale, background, foreground, accumulation );
#endif // #if DOF_RING_COUNT > 1
#if DOF_RING_COUNT > 2
        [branch]
        if ( maxRing > 2 )
            DofInternalTile( 2, texCoords, scale, noise, spreadScale, background, foreground, accumulation );
#endif // #if DOF_RING_COUNT > 2
#if DOF_RING_COUNT > 3
        [branch]
        if ( maxRing > 3 )
            DofInternalTile( 3, texCoords, scale, noise, spreadScale, background, foreground, accumulation );
#endif // #if DOF_RING_COUNT > 3
#endif // #else // #if !DOF_RING_MANUAL_UNROLL

        background.rgb *= rcp( max( background.w, DOF_EPS ) );
        foreground.rgb *= rcp( max( foreground.w, DOF_EPS ) );

        float alphaNorm = 1.0 / SampleAlpha( p_fMaxCoCRadius * tileParams.maxCoc );
        float alpha = saturate( foreground.w * alphaNorm * ringNormFactor[maxRing] );

        alpha = lerp( sqrt( alpha ), alpha, HalfResFactor( centerPrepassParams.coc, p_fMaxCoCRadius ) );

        float3 color = lerp( background.rgb, foreground.rgb, alpha );

#if DOF_TILE_OPTIMIZATION
        color = lerp( ringNormFactor[maxRing] * accumulation, color, tileParams.cocDelta );
#endif // #if DOF_TILE_OPTIMIZATION

        vOutAlpha = EncodeAlpha( alpha );
        vOutColor = DOF_TILE_DEBUG_COLOR( DOF_RING_DEBUG_COLOR( float4( color, 1.0 ), maxRing ), 4 );
    }
#if DOF_TILE_OPTIMIZATION
    else
    {
        float3 color = centerColor;

#if !DOF_RING_MANUAL_UNROLL
        [unroll]
        for ( int j = 0; j < DOF_RING_COUNT; j++ )
        {
            [branch]
            if ( j < maxRing )
                DofInternalFast( j, texCoords, scale, noise, color );
        }
#else // #if !DOF_RING_MANUAL_UNROLL
        DofInternalFast( 0, texCoords, scale, noise, color );
#if DOF_RING_COUNT > 1
        [branch]
        if ( maxRing > 1 )
            DofInternalFast( 1, texCoords, scale, noise, color );
#endif // #if DOF_RING_COUNT > 1
#if DOF_RING_COUNT > 2
        [branch]
        if ( maxRing > 2 )
            DofInternalFast( 2, texCoords, scale, noise, color );
#endif // #if DOF_RING_COUNT > 2
#if DOF_RING_COUNT > 3
        [branch]
        if ( maxRing > 3 )
            DofInternalFast( 3, texCoords, scale, noise, color );
#endif // #if DOF_RING_COUNT > 3
#endif // #else // #if !DOF_RING_MANUAL_UNROLL

        color *= ringNormFactor[maxRing];

        vOutAlpha = DOF_ALPHA_INVALID;
        vOutColor = DOF_TILE_DEBUG_COLOR( DOF_RING_DEBUG_COLOR( float4( color, 1.0 ), maxRing ), 2 );
    }
#endif // #if DOF_TILE_OPTIMIZATION

    return vOutColor;
}

#endif // Inclusion guard