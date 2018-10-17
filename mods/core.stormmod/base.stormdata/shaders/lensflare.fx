//==================================================================================================
//
// Copyright Blizzard Entertainment 2014
//
// Shader code for lens flares
//==================================================================================================

#include "ShaderSystem.fx"
#include "VSElementUtils.fx"

struct VertexTransport {
    float4 vUVScreenPos : TEXCOORD0;
    float4 vColor       : COLOR0;
    float2 vFOWUV       : TEXCOORD1;
#ifdef VERTEX_SHADER
    float4 vPosition : POSITION;
#endif
};

#define INTERPOLANT_FOWUV vertOut.vFOWUV
#include "PSFOW.fx"

#ifdef VERTEX_SHADER

#if !CPP_SHADER
//==================================================================================================
// Input structure
struct Input
{
    float4  vColor                  : COLOR0_;
    float   hdrScale                : COLOR1_;
    float2  vFOWUV                  : TEXCOORD1_;
    float4  vPositionUV             : POSITION_;
};

#endif

//==================================================================================================
VertexTransport LensFlareVertexMain( in Input vertIn ) {
    VertexTransport vertOut;

#ifdef COMPILING_SHADER_FOR_OPENGL
    vertOut.vPosition = float4( vertIn.vPositionUV.x, -vertIn.vPositionUV.y, 0.f, 1.f );
#else
    vertOut.vPosition = float4( vertIn.vPositionUV.xy, .5f, 1.f );
#endif
    vertOut.vColor = vertIn.vColor.rgba * vertIn.hdrScale;
    vertOut.vFOWUV = vertIn.vFOWUV;
    vertOut.vUVScreenPos.xy = vertIn.vPositionUV.zw;
    vertOut.vUVScreenPos.zw = vertOut.vPosition.xy / vertOut.vPosition.w;

    return vertOut;
}


#endif  // VERTEXSHADER

#ifdef PIXEL_SHADER

texDecl2D( p_sAtlas );
texDecl2D( p_sDirtyLens );

float4 LensFlarePixelMain ( in VertexTransport vertIn ) : COLOR {
    float4 rvalue = float4( 0.f, 0.f, 0.f, 0.f );
    if( b_shaderMode == 0 ) {
        rvalue = vertIn.vColor * sample2D( p_sAtlas, vertIn.vUVScreenPos.xy );
    } else if( b_shaderMode == 1 ) {
        rvalue = vertIn.vColor * sample2D( p_sAtlas, vertIn.vUVScreenPos.xy ) * sample2D( p_sDirtyLens, .5f * vertIn.vUVScreenPos.zw + .5f );
    }

    HALF3 stubDiffuse = 0;
    rvalue.xyz = ApplyFogOfWar( Ndc2Tex(vertIn.vFOWUV.xy, true ), rvalue, stubDiffuse ).xyz;
    return rvalue;
}

#endif
