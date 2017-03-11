//==================================================================================================
//
// Copyright Blizzard Entertainment 2003..
//
// Shader code for super-simple shaders
//==================================================================================================

#include "ShaderSystem.fx"

struct SVertexFormatIn {
    float4  vPosition       : POSITION_;
    float4  cColor          : COLOR0_;
    float2  vUV             : TEXCOORD0_;
};

struct SVertexFormatOut {
    float4  vPosition		: POSITION;
    float4  cColor          : COLOR0;
    float2  vUV             : TEXCOORD0;
    float4 vHPos            : TEXCOORD1;
};

#ifdef VERTEX_SHADER

float4x4    p_mProjection;
float4      p_cColor;

//--------------------------------------------------------------------------------------------------
void SimpleVertexMain( in SVertexFormatIn input, out SVertexFormatOut vertOut ) {
    SVertexFormatOut output;
#ifdef COMPILING_SHADER_FOR_OPENGL
    output.vPosition    = mul( input.vPosition, p_mProjection );
    output.vPosition.y *= -1;
    output.vPosition.z = 2.0 * (output.vPosition.z - (0.5 * output.vPosition.w));
#else
    output.vPosition    = mul( input.vPosition, p_mProjection );
#endif
    output.vUV          = input.vUV;
    output.cColor       = input.cColor * p_cColor;

    output.vHPos        = output.vPosition;

    vertOut = output;
}

#endif  // VERTEX_SHADER

#ifdef PIXEL_SHADER

#include "Common.fx"

texDecl2D(p_sTexture);

//--------------------------------------------------------------------------------------------------
float4 SimplePixelMain( in SVertexFormatOut input ) : COLOR {
    float4 cResult = sample2D(p_sTexture, input.vUV.xy) * input.cColor;
    AlphaTest(cResult.a);
    return cResult;
}

#endif  // PIXEL_SHADER