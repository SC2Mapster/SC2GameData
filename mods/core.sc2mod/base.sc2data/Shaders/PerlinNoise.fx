//==================================================================================================
//
// Copyright Blizzard Entertainment 2003-2007
//
// Perlin noise shader code
//==================================================================================================

#include "ShaderSystem.fx"

struct VertexTransport {
    float4 vPos	 : POSITION_;
    float4 vUV0  : TEXCOORD0_;
    float4 vUV1  : TEXCOORD1_;
    float4 vUV2  : TEXCOORD2_;
};




//--------------------------------------------------------------------------------------------------
// VERTEX_SHADER
//--------------------------------------------------------------------------------------------------
#ifdef VERTEX_SHADER

struct Input {
    float4  vPosition   : POSITION_;
};

//--------------------------------------------------------------------------------------------------

//--------------------------------------------------------------------------------------------------
void PerlinNoiseVertexMain( in Input vertIn, out VertexTransport vertOut ) {
    VertexTransport output;
    InitShader( vertOut );
        
    vertOut.vPos = vertIn.vPosition;
    vertOut.vUV0 = 0;
    vertOut.vUV1 = 0;
    vertOut.vUV2 = 0;

#ifdef COMPILING_SHADER_FOR_OPENGL
    vertOut.vPos.y *= -1.0;
#endif    
}

#endif  // VERTEX_SHADER







//--------------------------------------------------------------------------------------------------
// PIXEL_SHADER
//--------------------------------------------------------------------------------------------------
#ifdef PIXEL_SHADER

#include "PSCommon.fx"

texDecl2D(p_sRandMap);

//--------------------------------------------------------------------------------------------------
float4 PerlinNoisePixelMain( VertexTransportRaw vertRaw ) : COLOR {
    VertexTransport vertOut;
    InitShader( vertRaw, vertOut );
    
    return 1;
}

#endif      // PIXEL_SHADER