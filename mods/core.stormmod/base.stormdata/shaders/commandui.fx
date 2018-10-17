//==================================================================================================
// Copyright Blizzard Entertainment
//
// Shader interface for any two-dimensional screen-aligned quad.
//==================================================================================================

#include "ShaderSystem.fx"

struct SCommandUIVtxFmt {
    float4 vPos         : POSITION;
    float4 cColor0      : COLOR0;
    float4 vTC0         : TEXCOORD0;
};

#ifdef VERTEX_SHADER

//------------------------------------------------------------------------------------------------
// Vertex format
//------------------------------------------------------------------------------------------------
struct SCommandUIVtxFmtGeneric {
    float4 vPos         : POSITION_;
    float4 cColor0      : COLOR0_;
    float4 vTC0         : TEXCOORD0_;
};

//------------------------------------------------------------------------------------------------
// Uniform parameters
//------------------------------------------------------------------------------------------------
float4x4 p_mTransform;

//------------------------------------------------------------------------------------------------
// Vertex shader
//------------------------------------------------------------------------------------------------
void CommandUIVertexMain (in SCommandUIVtxFmtGeneric IN, out SCommandUIVtxFmt OUT) {
    OUT.vPos = mul(float4(IN.vPos.xyz, 1), p_mTransform);
#ifdef COMPILING_SHADER_FOR_OPENGL
    OUT.vPos.y *= -1.0;
    OUT.vPos.z = 2.0 * (OUT.vPos.z - (0.5 * OUT.vPos.w));
#endif

#if defined(COMPILING_SHADER_FOR_OPENGL) || defined(COMPILING_SHADER_FOR_METAL)
    OUT.cColor0 = IN.cColor0.zyxw;
#else
    OUT.cColor0 = IN.cColor0;
#endif
    OUT.vTC0 = IN.vTC0;
}

#endif  // VERTEX_SHADER

#ifdef PIXEL_SHADER

//------------------------------------------------------------------------------------------------
// Samplers
//------------------------------------------------------------------------------------------------
texDecl2D(p_sTexture);

//--------------------------------------------------------------------------------------------------
// Pixel shader
//--------------------------------------------------------------------------------------------------
float4 CommandUIPixelMain (in SCommandUIVtxFmt IN) : COLOR {
    return sample2D(p_sTexture, IN.vTC0.xy) * IN.cColor0;
}

#endif  // PIXEL_SHADER