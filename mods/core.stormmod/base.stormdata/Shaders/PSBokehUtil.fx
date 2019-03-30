//==================================================================================================
//
// Copyright Blizzard Entertainment 2003..
//
// Shader code for bokeh dof, see jjimenez siggraph 2014
//==================================================================================================

#include "ShaderSystem.fx"

#ifndef PS_BOKEH_UTIL
#define PS_BOKEH_UTIL

// Use viewspace positions instead of camera settings
#define BOKEH_USE_LEGACY_COC            0

#define DOF_MAX_COC_RADIUS_LENGTH       16

// This was originally something like 100 inches, which is close enough to our units that we can simply use 1 =P
#define DOF_DEPTH_SCALE_SURFACE_CLIP    1.f 
#define DOF_DEPTH_SCALE_FOREGROUND      (1.f / DOF_DEPTH_SCALE_SURFACE_CLIP)

#define DOF_SPREAD_TOE_POWER            3.0

#define DOF_SURFACE_FILTER_KARIS_AVG    1
#define DOF_SMALL_FILTER_KARIS_AVG        1

#define DOF_SMALL_FILTER_DITHER            0

#define DOF_SURFACE_FILTER_VIEWMODEL_HACK        0
#define DOF_SURFACE_FILTER_VIEWMODEL_HACK_GAMMA    2.0
#define DOF_UPSCALE_VIEWMODEL_HACK                0
#define DOF_UPSCALE_VIEWMODEL_HACK_GAMMA        0.5

#define DOF_HALF_RES_SCALE              0.5
#define DOF_HALF_RES_BIAS               ( 1.5 * DOF_HALF_RES_SCALE )

#define DOF_NEAR_FIELD_SCALE            0.5
#define DOF_NEAR_FIELD_BIAS             ( 0.0 * DOF_NEAR_FIELD_SCALE )

#define DOF_TILE_OPTIMIZATION           1
#define DOF_TILE_COC_DELTA_SCALE        0.5
#define DOF_TILE_COC_DELTA_BIAS         ( 1.0 * DOF_TILE_COC_DELTA_SCALE )
#define DOF_TILE_DEBUG                  0

#define DOF_RING_OPTIMIZATION           1
#define DOF_RING_GAMMA                  0.5
#define DOF_RING_DEBUG                  0

#define DOF_RING_MANUAL_UNROLL            1    // PS4 shader compiler needs help unrolling the ring optimization.
#define DOF_RING_COUNT                          3

#define DOF_SINGLE_PIXEL_RADIUS            0.7071 // length( float2( 0.5, 0.5 ) )
#define DOF_MIN_COC                        -1.0
#define DOF_MAX_COC                        1.0
#define DOF_EPS                            1e-5

#define DOF_ALPHA_INVALID                0.0
#define DOF_ALPHA_ENCODE_BIAS            ( 1.0 / 255.0 )
#define DOF_ALPHA_ENCODE_SCALE            ( 254.0 / 255.0 )
#define DOF_ALPHA_DECODE_BIAS            ( -DOF_ALPHA_ENCODE_BIAS / DOF_ALPHA_ENCODE_SCALE )
#define DOF_ALPHA_DECODE_SCALE            ( 1.0 / DOF_ALPHA_ENCODE_SCALE )

#if DOF_TILE_DEBUG || DOF_RING_DEBUG
static const float4 debugColors[] =
{
    { 0.0, 0.0, 1.0, 1.0 },
    { 0.0, 1.0, 1.0, 1.0 },
    { 0.0, 1.0, 0.0, 1.0 },
    { 1.0, 1.0, 0.0, 1.0 },
    { 1.0, 0.0, 0.0, 1.0 }
};
#endif // #if DOF_TILE_DEBUG || DOF_RING_DEBUG

#if DOF_TILE_DEBUG
#define DOF_TILE_DEBUG_COLOR( color, index ) ( color * debugColors[index] )
#else // #if DOF_TILE_DEBUG
#define DOF_TILE_DEBUG_COLOR( color, index ) ( color )
#endif // #else // #if DOF_TILE_DEBUG

#if DOF_RING_DEBUG
#define DOF_RING_DEBUG_COLOR( color, maxRing ) ( color * debugColors[maxRing] )
#else // #if DOF_RING_DEBUG
#define DOF_RING_DEBUG_COLOR( color, maxRing ) ( color )
#endif // #else // #if DOF_RING_DEBUG

// dofParams
#define DOF_SCALE_X                        0
#define DOF_SCALE_Y                        1
#define DOF_MAX_COC_RADIUS                2
#define DOF_SHARPNESS_INV                3 // (circular)

#define DOF_ALPHA                        3 // (hexagonal and octogonal)

#define PI                  3.1415926
#define FLOATZ_MIN_VALUE    1.0e-8
#define HALF_MAX            65504

HALF4   p_fFocusDepth;

float4 tex2DGatherChannel_Emulation( typeTexture2D tTexture, typeSampler2D sSampler, float2 vUV, float2 offset, float4 vRTSize, float index )
{
    float2 pos = vUV * vRTSize.xy;
    float2 topLeftOffset = floor( pos - 0.5 );

    float topLeft     = sampleTex2Dlod(tTexture, sSampler, float4(( topLeftOffset + float2( 0.5, 0.5 ) ) * vRTSize.zw, 0, 1.0f) )[index];
    float topRight    = sampleTex2Dlod(tTexture, sSampler, float4(( topLeftOffset + float2( 1.5, 0.5 ) ) * vRTSize.zw, 0, 1.0f) )[index];
    float bottomLeft  = sampleTex2Dlod(tTexture, sSampler, float4(( topLeftOffset + float2( 0.5, 1.5 ) ) * vRTSize.zw, 0, 1.0f) )[index];
    float bottomRight = sampleTex2Dlod(tTexture, sSampler, float4(( topLeftOffset + float2( 1.5, 1.5 ) ) * vRTSize.zw, 0, 1.0f) )[index];
    
    return float4( bottomLeft, bottomRight, topRight, topLeft );
}

float4 tex2DGatherRed( typeTexture2D tTexture, typeSampler2D sSampler, float2 texcoords, float2 offset, float4 vRTSize )
{
#if PIXEL_SHADER_VERSION >= SHADER_VERSION_PS_40
    return tTexture.GatherRed( sSampler, texcoords, offset );
#else
    return tex2DGatherChannel_Emulation( tTexture, sSampler, texcoords, offset, vRTSize, 0 );
#endif
}

float4 tex2DGatherGreen( typeTexture2D tTexture, typeSampler2D sSampler, float2 texcoords, float2 offset, float4 vRTSize )
{
    return tex2DGatherChannel_Emulation( tTexture, sSampler, texcoords, offset, vRTSize, 1 );
}

float4 tex2DGatherBlue( typeTexture2D tTexture, typeSampler2D sSampler, float2 texcoords, float2 offset, float4 vRTSize )
{
    return tex2DGatherChannel_Emulation( tTexture, sSampler, texcoords, offset, vRTSize, 2 );
}

float4 tex2DGatherAlpha( typeTexture2D tTexture,  typeSampler2D sSampler, float2 texcoords, float2 offset, float4 vRTSize )
{
    return tex2DGatherChannel_Emulation( tTexture, sSampler, texcoords, offset, vRTSize, 3 );
}

#ifdef PIXEL_SHADER
float4 tex2DGatherDepth( typeTexture2D tTexture, typeSampler2D sSampler, float2 vUV, float2 vOffset, float4 vRTSize ) {
    //if (BOKEH_USE_LEGACY_COC) {
        float4 depthVal = tex2DGatherAlpha(tTexture, sSampler, vUV, vOffset, vRTSize);
        depthVal.r = DecodeDepth(depthVal.rrrr);
        depthVal.g = DecodeDepth(depthVal.gggg);
        depthVal.b = DecodeDepth(depthVal.bbbb);
        depthVal.a = DecodeDepth(depthVal.aaaa);
        return depthVal;
    //}
    //else
    //    return tex2DGatherRed(tTexture, sSampler, vUV, vOffset, vRTSize);
}
#endif

struct TileParams
{
    float maxCoc;
    float foregroundCoc;
    float nearestViewDepth;
    float cocDelta;
};


struct PrepassParams
{
    float coc;
    float backgroundWeight;
    float foregroundWeight;
};

float min3( float a, float b, float c )
{
    return min( min( a, b ), c );
}

float max3( float a, float b, float c )
{
    return max( max( a, b ), c );
}

float med3( float a, float b, float c )
{
    return max( min( a, b ), min( max( a, b ), c ) );
}

float2 min3( float2 a, float2 b, float2 c )
{
    return float2( min3( a.x, b.x, c.x ), min3( a.y, b.y, c.y ) );
}

float3 min3( float3 a, float3 b, float3 c )
{
    return float3( min3( a.x, b.x, c.x ), min3( a.y, b.y, c.y ), min3( a.z, b.z, c.z ) );
}

float4 min3( float4 a, float4 b, float4 c )
{
    return float4( min3( a.x, b.x, c.x ), min3( a.y, b.y, c.y ), min3( a.z, b.z, c.z ), min3( a.w, b.w, c.w ) );
}

float2 max3( float2 a, float2 b, float2 c )
{
    return float2( max3( a.x, b.x, c.x ), max3( a.y, b.y, c.y ) );
}

float3 max3( float3 a, float3 b, float3 c )
{
    return float3( max3( a.x, b.x, c.x ), max3( a.y, b.y, c.y ), max3( a.z, b.z, c.z ) );
}

float4 max3( float4 a, float4 b, float4 c )
{
    return float4( max3( a.x, b.x, c.x ), max3( a.y, b.y, c.y ), max3( a.z, b.z, c.z ), max3( a.w, b.w, c.w ) );
}

float2 med3( float2 a, float2 b, float2 c )
{
    return float2( med3( a.x, b.x, c.x ), med3( a.y, b.y, c.y ) );
}

float3 med3( float3 a, float3 b, float3 c )
{
    return float3( med3( a.x, b.x, c.x ), med3( a.y, b.y, c.y ), med3( a.z, b.z, c.z ) );
}

float4 med3( float4 a, float4 b, float4 c )
{
    return float4( med3( a.x, b.x, c.x ), med3( a.y, b.y, c.y ), med3( a.z, b.z, c.z ), med3( a.w, b.w, c.w ) );
}

float min4( float4 values )
{
    return min( min3( values.x, values.y, values.z ), values.w );
}

float max4( float4 values )
{
    return max( max3( values.x, values.y, values.z ), values.w );
}

float4 PackTileParams( TileParams tileParams )
{
    return float4( tileParams.maxCoc, tileParams.nearestViewDepth, tileParams.cocDelta, tileParams.foregroundCoc );
}

TileParams UnpackTileParams( float4 packedTileParams )
{
    TileParams tileParams;
    tileParams.maxCoc = packedTileParams.r;
    tileParams.nearestViewDepth = packedTileParams.g;
    tileParams.cocDelta = packedTileParams.b;
    tileParams.foregroundCoc = packedTileParams.a;
    return tileParams;
}


float4 PackPrepassParams( PrepassParams prepassParams )
{
    return float4( prepassParams.coc, prepassParams.backgroundWeight, prepassParams.foregroundWeight, 1.0 );
}


PrepassParams UnpackPrepassParams( float4 packedPrepassParams )
{
    PrepassParams prepassParams;
    prepassParams.coc = packedPrepassParams.r;
    prepassParams.backgroundWeight = packedPrepassParams.g;
    prepassParams.foregroundWeight = packedPrepassParams.b;
    return prepassParams;
}


float ClampCoc( float coc )
{
    return saturate( abs( coc ) );
}

bool IsViewModelClipDepth( float clipDepth )
{
    return false;
}


/*
// Unused - we store viewspace depth in buffers all the way
float LinearizeDepth(float fZOverW)
{
	float fLinearDepth = (p_fFarPlane * p_fNearPlane) / max( (p_fFarPlane - (1.f - fZOverW) * (p_fFarPlane - p_fNearPlane)), FLOATZ_MIN_VALUE );
	return fLinearDepth;
}

float SceneClipDepthToZNumerator()
{
	return p_fFarPlane * p_fNearPlane;
}


float SceneClipDepthToZDenominator( float clipDepth )
{
	return 1.0 /  max( (p_fFarPlane - (1.f - clipDepth) * (p_fFarPlane - p_fNearPlane)), FLOATZ_MIN_VALUE );
}

float ClipDepthToZ( float clipDepth )
{
    return LinearizeDepth( clipDepth );
}
*/

float FunkyCocScale( float fCoC ) {
    // Scales the CoC to match the weird curve that would result from using the previous DoF method.
    if( fCoC <= .5f ) {
        return 0.124977903f * fCoC * 2.f;
    }
    if( fCoC <= .75f ) {
        return lerp( 0.124977903f, 0.250132579f, (fCoC - .5f) * 4.f );
    }
    if( fCoC < 1.f ) {
        return lerp( 0.250132579f, 1.f, (fCoC - .75f) * 4.f );
    }

    return fCoC;
}

float CalculateUnclampedCoc( float fDepth, float4 vDoFEquation )
{
    // Legacy method
    if (BOKEH_USE_LEGACY_COC) {
        float depthDelta = fDepth - p_fFocusDepth;

        if( depthDelta <= 0.f ) {
            float val = min( 0.f, -((p_fFocusDepth - fDepth) * vDoFEquation.z + vDoFEquation.w) );
            return -val;
        } else {
            float val = max( 0.f, (fDepth - p_fFocusDepth) * vDoFEquation.x + vDoFEquation.y );
            return val;
        }
    }
    
    // "camera" method
	fDepth = 1.f / fDepth;

    float2 coc = vDoFEquation.xz * fDepth + vDoFEquation.yw;
    return IsViewModelClipDepth( fDepth ) ? coc.y : coc.x;
}

float CalculateCoc( float viewDepth, float4 dofEquation )
{
    return ClampCoc( CalculateUnclampedCoc( viewDepth, dofEquation ) );
}

float DepthCmp1( float depth, float tileNearestViewDepth )
{
    return saturate( 1.0 - DOF_DEPTH_SCALE_FOREGROUND * ( depth - tileNearestViewDepth ) );
}


float2 DepthCmp2( float depth, float tileNearestViewDepth )
{
    float d = DOF_DEPTH_SCALE_FOREGROUND * ( depth - tileNearestViewDepth );

    float2 depthCmp;
    depthCmp.x = smoothstep( 0.0, 1.0, d );
    depthCmp.y = 1.0 - depthCmp.x;
    return depthCmp;
}


// Like above, but just gets the background factor for all channels
float4 BackgroundFactor4( float4 depth, float tileNearestViewDepth ) {
    return smoothstep(0.0, 1.0, DOF_DEPTH_SCALE_FOREGROUND * (depth - float4(tileNearestViewDepth, tileNearestViewDepth, tileNearestViewDepth, tileNearestViewDepth)));
}


float SpreadToe( float offsetCoc, float spreadCmp )
{
    return offsetCoc <= 1.0 ? pow( spreadCmp, DOF_SPREAD_TOE_POWER ) : spreadCmp;
}


float SpreadCmp( float offsetCoc, float sampleCoc, float spreadScale )
{
    return SpreadToe( offsetCoc, saturate( spreadScale * sampleCoc - ( offsetCoc - 1.0 ) ) );
}


float SampleAlpha( float sampleCoc )
{
    return min( rcp( PI * sampleCoc * sampleCoc ), rcp( PI * DOF_SINGLE_PIXEL_RADIUS * DOF_SINGLE_PIXEL_RADIUS ) );
}


void CalculateRingParams( int maxRingCount, int ringCount, float tileMaxCoc, float noise, out int maxRing, out float ringScale )
{
#if DOF_RING_OPTIMIZATION
    maxRing = clamp( round( pow( tileMaxCoc, DOF_RING_GAMMA ) * ringCount + noise ), 1, ringCount );
#else // #if DOF_RING_OPTIMIZATION
    maxRing = ringCount;
#endif // #else // #if DOF_RING_OPTIMIZATION

    ringScale = float( maxRingCount ) / float( maxRing );
}


float TileCocDeltaFactor( float cocDelta, float maxCocRadius )
{
    return saturate( maxCocRadius * DOF_TILE_COC_DELTA_SCALE * cocDelta - DOF_TILE_COC_DELTA_BIAS );
}


float HalfResFactor( float coc, float maxCocRadius )
{
    return saturate( maxCocRadius * DOF_HALF_RES_SCALE * coc - DOF_HALF_RES_BIAS );
}


float EncodeAlpha( float alpha )
{
    return saturate( DOF_ALPHA_ENCODE_BIAS + DOF_ALPHA_ENCODE_SCALE * alpha );
}


float DecodeAlpha( float alpha )
{
    return saturate( DOF_ALPHA_DECODE_BIAS + DOF_ALPHA_DECODE_SCALE * alpha );
}


float Luma( float3 color )
{
    return dot( color, float3( 0.2126, 0.7152, 0.0722 ) );
}

float KarisWeight( float3 color, float sharpnessInv )
{
    return rcp( 1.0 + sharpnessInv * Luma( color ) );
}

#endif // Inclusion guard