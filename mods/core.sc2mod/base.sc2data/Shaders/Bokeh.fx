//==================================================================================================
//
// Copyright Blizzard Entertainment 2003..
//
// Shader code for bokeh dof, see jjimenez siggraph 2014
//==================================================================================================

#include "ShaderSystem.fx"

#define BOKEH_TILEDOWNSAMPLE0       0
#define BOKEH_TILEDOWNSAMPLE1       1
#define BOKEH_TILENEIGHBOR          2
#define BOKEH_PREPASS               3
#define BOKEH_CIRCULARFILTER        4
#define BOKEH_MEDIAN                5
#define BOKEH_UPSAMPLE              6

// TEMP
#define HALFRES 1

#define READ_INTERPOLANT_UV(a) float4(0,0,0,0)

struct SVertexFormatIn {
    float4  vPosition       : POSITION_;
    float2  vUV             : TEXCOORD0_;
};

struct VertexTransport {
    float4  vPosition        : POSITION;
    float2  vUV             : TEXCOORD0;
};

struct SFragmentOut {
    float4  vColor0         : COLOR0;
    #if b_iBokehPass >= BOKEH_PREPASS && b_iBokehPass <= BOKEH_MEDIAN
        float4 vColor1      : COLOR1;
    #endif
};


#ifdef VERTEX_SHADER

// float4x4 p_mTransform;

//--------------------------------------------------------------------------------------------------
void BokehVertexMain( in SVertexFormatIn vertIn, out VertexTransport vertOut ) {
#ifdef COMPILING_SHADER_FOR_OPENGL
    vertOut.vPosition    = mul( vertIn.vPosition, p_mTransform );
    vertOut.vPosition.y *= -1;
    vertOut.vPosition.z = 2.0 * (vertOut.vPosition.z - (0.5 * vertOut.vPosition.w));
#else
    vertOut.vPosition    = vertIn.vPosition; //mul( vertIn.vPosition, p_mTransform );
#endif
    vertOut.vUV = vertIn.vUV;
}

#endif  // VERTEX_SHADER

#ifdef PIXEL_SHADER

#include "PSCommon.fx"
#include "PSBokehUtil.fx"

#if HALFRES
#define SAMPLE_COUNT    ( DOF_MAX_COC_RADIUS_LENGTH / 2 )
#else // #if HALFRES
#define SAMPLE_COUNT    DOF_MAX_COC_RADIUS_LENGTH 
#endif // #else // #if HALFRES


texDecl2D(p_sInputImage);
texDecl2D(p_sInputImageLinear);
texDecl2D(p_sFullImageLinear);
texDecl2D(p_sAlphaImage);
texDecl2D(p_sDepthImage);
texDecl2D(p_sTileImage);
texDecl2D(p_sPrepassImage);

HALF4   p_vDoFEquation;
HALF4   p_vPixelTransform;
HALF4   p_vRenderTargetSize;
HALF4   p_vTileRTSize;
HALF    p_fMaxCoCRadius;
HALF2   p_vCoCGapSpaceTransform;
HALF    p_fKarisInvSharpness;
HALF2   p_vCoCTransform;

// These in separate files to keep it somewhat clean
#include "PSBokehTile.fx"
#include "PSBokehTileNeighbor.fx"
#include "PSBokehPrepass.fx"
#include "PSBokehCircularFilter.fx"
#include "PSBokehMedian.fx"
#include "PSBokehUpscale.fx"


//--------------------------------------------------------------------------------------------------
void BokehPixelMain ( in VertexTransport input, out SFragmentOut output ) {

    if (b_iBokehPass == BOKEH_TILEDOWNSAMPLE0 || b_iBokehPass == BOKEH_TILEDOWNSAMPLE1)
        output.vColor0 = Bokeh_TileDownSample(input.vUV.xy);
    if (b_iBokehPass == BOKEH_TILENEIGHBOR)
        output.vColor0 = Bokeh_TileNeighbor(input.vUV.xy);
    #if b_iBokehPass == BOKEH_PREPASS
        output.vColor0 = Bokeh_Prepass(input.vUV.xy, output.vColor1);
    #endif
    #if b_iBokehPass == BOKEH_CIRCULARFILTER
        output.vColor0 = Bokeh_CircularFilter(input.vUV.xy, output.vColor1);
    #endif
    #if b_iBokehPass == BOKEH_MEDIAN
        output.vColor0 = Bokeh_Median(input.vUV.xy, output.vColor1);
    #endif
    if (b_iBokehPass == BOKEH_UPSAMPLE)
        output.vColor0 = Bokeh_Upsample(input.vUV.xy);
}

#endif  // PIXEL_SHADER