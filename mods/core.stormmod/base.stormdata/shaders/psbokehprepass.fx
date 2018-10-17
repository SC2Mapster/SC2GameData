//==================================================================================================
//
// Copyright Blizzard Entertainment 2003..
//
// Shader code for bokeh dof, see jjimenez siggraph 2014
//==================================================================================================

#ifndef PS_BOKEH_PREPASS
#define PS_BOKEH_PREPASS

#include "PSBokehSurfaceFilter.fx"

//--------------------------------------------------------------------------------------------------
float4 CalculatePrepass( float maxDepth, float centerDepth, float unclampedCoc, float coc ) {
    float nearFieldFactor = 1.0 + smoothstep( 0.0, 1.0, saturate( -DOF_NEAR_FIELD_SCALE * p_fMaxCoCRadius * unclampedCoc - DOF_NEAR_FIELD_BIAS ) );
    float alpha = SampleAlpha( p_fMaxCoCRadius * coc );
    float viewDepth = centerDepth;
    float2 depthCmp = DepthCmp2( viewDepth, maxDepth );

    float2 weight = nearFieldFactor * depthCmp;

    PrepassParams prepassParams;
    prepassParams.coc = coc;
    prepassParams.backgroundWeight = weight.x;
    prepassParams.foregroundWeight = alpha * weight.y;

    return PackPrepassParams( prepassParams );
}


//--------------------------------------------------------------------------------------------------
void SelectLargestDepth( float2 texCoords, out float centerDepth, out float2 offset ) {
    // TODO - make sure this is the right size (should be full)
    float4 centerDepth4 = tex2DGatherDepth( texTexture(p_sDepthImage), texSampler(p_sDepthImage), texCoords, 0, p_vRenderTargetSize );

    centerDepth = max4(centerDepth4);

    offset = float2( -0.25, 0.25 );
    if ( centerDepth == centerDepth4.y )
        offset = float2( 0.25, 0.25 );
    if ( centerDepth == centerDepth4.z )
        offset = float2( 0.25, -0.25 );
    if ( centerDepth == centerDepth4.w )
        offset = float2( -0.25, -0.25 );
}


//--------------------------------------------------------------------------------------------------
float4 Bokeh_Prepass(float2 vUV, out float4 vOutColor) {
    TileParams tileParams = UnpackTileParams( sample2D( p_sTileImage, vUV ) );

    float centerDepth;
    float2 offset;
    SelectLargestDepth( vUV, centerDepth, offset );
    float2 texCoords = vUV + offset * p_vRenderTargetSize.zw;

    float unclampedCenterCoc = CalculateUnclampedCoc( centerDepth, p_vDoFEquation );
    float centerCoc = ClampCoc( unclampedCenterCoc );

    vOutColor = float4( SurfaceFilter( texTexture(p_sInputImage), texSampler(p_sInputImage), texTexture(p_sDepthImage), texSampler(p_sDepthImage), vUV, texCoords, centerCoc, centerDepth, tileParams.cocDelta, tileParams.nearestViewDepth, p_vCoCGapSpaceTransform, p_vDoFEquation, p_fKarisInvSharpness, p_vRenderTargetSize ), 1.0 );

    return CalculatePrepass( tileParams.nearestViewDepth, centerDepth, unclampedCenterCoc, centerCoc );
}

#endif // Inclusion guard