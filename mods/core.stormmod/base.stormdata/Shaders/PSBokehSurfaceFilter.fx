//==================================================================================================
//
// Copyright Blizzard Entertainment 2003..
//
// Shader code for bokeh dof, see jjimenez siggraph 2014
//==================================================================================================

#ifndef PS_BOKEH_SURFACEFILTER
#define PS_BOKEH_SURFACEFILTER

//#ifdef XB3
//#define DOF_SURFACE_FILTER_SAMPLE_COUNT    4
//#else // #if defined( XB3 )
// TODO - static branch?
#define DOF_SURFACE_FILTER_SAMPLE_COUNT    8
//#endif // #else // #if defined( XB3 )

#if DOF_SURFACE_FILTER_SAMPLE_COUNT == 8
static const float2 c_vSurfaceFilterOffsets[] =
{
    {  0.9239, -0.3827 },
    { -0.9239,  0.3827 },
    { -0.9239, -0.3827 },
    {  0.9239,  0.3827 },
    { -0.3827, -0.9239 },
    {  0.3827,  0.9239 },
    {  0.3827, -0.9239 },
    { -0.3827,  0.9239 },
};
#elif DOF_SURFACE_FILTER_SAMPLE_COUNT == 4
static const float2 c_vSurfaceFilterOffsets[] =
{
    {  1.0,  1.0 },
    {  1.0, -1.0 },
    { -1.0,  1.0 },
    { -1.0, -1.0 },
};
#else
#error invalid DOF_SURFACE_FILTER_SAMPLE_COUNT
#endif

float3 SurfaceFilter( typeTexture2D tColor, typeSampler2D sColor, 
                      typeTexture2D tFloatZ, typeSampler2D sFloatZ, 
                      float2 texCoords, 
                      float2 texCoordsReference, 
                      float centerCoc, 
                      float centerDepth, 
                      float cocDelta, 
                      float tileNearestViewDepth, 
                      float2 cocGapSpaceXform, 
                      float4 dofEquation, 
                      float karisSharpnessInv, 
                      float4 vRTSize )
{
    float4 centerColor = float4( sampleTex2Dlod( tColor, sColor, float4( texCoordsReference, 0.0, 1.0 ) ).rgb, 1.0 );

    if (DOF_SURFACE_FILTER_KARIS_AVG)
        centerColor *= KarisWeight( centerColor.rgb, karisSharpnessInv );

    float4 color = centerColor;

    float2 scale = max( centerCoc * cocGapSpaceXform.xy, vRTSize.zw );

#if DOF_TILE_OPTIMIZATION
    [branch]
    if ( cocDelta > 0.0 )
#endif // #if DOF_TILE_OPTIMIZATION
    {
        // TODO
        // Debug variable for foreground
        float centerBackgroundFactor = DepthCmp2(centerDepth, tileNearestViewDepth);

        [unroll]
        for ( int i = 0; i < DOF_SURFACE_FILTER_SAMPLE_COUNT; i++ )
        {
            float2 sampleTexCoords = texCoords + scale * c_vSurfaceFilterOffsets[i];
            float4 sampleColor = float4( sampleTex2Dlod( tColor, sColor, float4( sampleTexCoords, 0.0, 1.0 ) ).rgb, 1.0 );

            // TODO - check to make sure this is right - texture should be full-size
            float4 sampleDepth = tex2DGatherDepth( tFloatZ, sFloatZ, sampleTexCoords, 0, vRTSize );

            float4 sampleBackgroundFactor4;
            sampleBackgroundFactor4 = BackgroundFactor4(sampleDepth, tileNearestViewDepth);
            
            float backgroundToBackground = min4( sampleBackgroundFactor4 ) * centerBackgroundFactor;
            float foregroundToForeground = ( 1.0 - max4( sampleBackgroundFactor4 ) ) * ( 1.0 - centerBackgroundFactor );

#if DOF_SURFACE_FILTER_VIEWMODEL_HACK
            foregroundToForeground *= pow( CalculateCoc( max4( sampleClipDepth ), dofEquation ), DOF_SURFACE_FILTER_VIEWMODEL_HACK_GAMMA );
#endif // #if DOF_SURFACE_FILTER_VIEWMODEL_HACK

            float weight = saturate( backgroundToBackground + foregroundToForeground );

            sampleColor *= lerp( 1.0, weight, cocDelta );

#if DOF_SURFACE_FILTER_KARIS_AVG
            sampleColor *= KarisWeight( sampleColor.rgb, karisSharpnessInv );
#endif // #if DOF_SURFACE_FILTER_KARIS_AVG

            color += sampleColor;
        }
    }
#if DOF_TILE_OPTIMIZATION
    else
    {
        [unroll]
        for ( int i = 0; i < DOF_SURFACE_FILTER_SAMPLE_COUNT; i++ )
        {
            float2 sampleTexCoords = texCoords + scale * c_vSurfaceFilterOffsets[i];
            float4 sampleColor = float4( sampleTex2Dlod( tColor, sColor, float4( sampleTexCoords, 0.0, 1.0 ) ).rgb, 1.0 );

#if DOF_SURFACE_FILTER_KARIS_AVG
            sampleColor *= KarisWeight( sampleColor.rgb, karisSharpnessInv );
#endif // #if DOF_SURFACE_FILTER_KARIS_AVG

            color += sampleColor;
        }
    }
#endif // #if DOF_TILE_OPTIMIZATION

    color.rgb /= color.w;

    return color.rgb;
}

#endif // Inclusion guard
