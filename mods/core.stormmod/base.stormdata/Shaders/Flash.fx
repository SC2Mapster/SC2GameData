//==================================================================================================
// Copyright Blizzard Entertainment
//
// Shader interface for Flash files.
//==================================================================================================

#include "ShaderSystem.fx"

//------------------------------------------------------------------------------------------------
// Vertex format
//------------------------------------------------------------------------------------------------
struct SFlashVtxFmt {
    float4 vPos         : POSITION;
    float4 cColor0      : COLOR0;
    float4 cFactor0     : COLOR1;
    float2 vTC0         : TEXCOORD0;
    float2 vTC1         : TEXCOORD1;
};

#ifdef VERTEX_SHADER

//------------------------------------------------------------------------------------------------
// Vertex shader types - must match interface code
//------------------------------------------------------------------------------------------------
#define e_flashVertexShaderStrip            0
#define e_flashVertexShaderGlyph            1
#define e_flashVertexShaderXY16iC32         2
#define e_flashVertexShaderXY16iCF32        3
#define e_flashVertexShaderXY16iCF32_T2     4

//------------------------------------------------------------------------------------------------
// Vertex format
//------------------------------------------------------------------------------------------------
struct SFlashVtxFmtGeneric {
    float4 vPos         : POSITION_;
    float4 cColor0      : COLOR0_;
    float4 cFactor0     : COLOR1_;
    float2 vTC0         : TEXCOORD0_;
    float2 vTC1         : TEXCOORD1_;
};

//------------------------------------------------------------------------------------------------
// Uniform parameters
//------------------------------------------------------------------------------------------------
float4x4 p_mTransform;
float4 p_mTexgen0;
float4 p_mTexgen1;
float4 p_mTexgen2;
float4 p_mTexgen3;

//------------------------------------------------------------------------------------------------
// Vertex shader
//------------------------------------------------------------------------------------------------
void FlashVertexMain (in SFlashVtxFmtGeneric IN, out SFlashVtxFmt OUT) {

#if defined(COMPILING_SHADER_FOR_OPENGL) || defined(COMPILING_SHADER_FOR_METAL)
    IN.cColor0 = IN.cColor0.zyxw;
#endif

    if (b_iVertexShader == e_flashVertexShaderStrip) {
        OUT.vPos = mul(p_mTransform, IN.vPos);
        OUT.vTC0.x = dot(IN.vPos, p_mTexgen0);
        OUT.vTC0.y = dot(IN.vPos, p_mTexgen1);
        OUT.cColor0 = IN.cColor0;
        OUT.cFactor0 = IN.cFactor0;
    }
    else if (b_iVertexShader == e_flashVertexShaderGlyph) {
        OUT.vPos = mul(p_mTransform, IN.vPos);
        OUT.vTC0 = IN.vTC0;
        OUT.vTC1 = IN.vTC1;
        OUT.cColor0 = IN.cColor0;
        OUT.cFactor0 = IN.cFactor0;
    }
    else if (b_iVertexShader == e_flashVertexShaderXY16iC32) {
        OUT.vPos = mul(p_mTransform, IN.vPos);
        OUT.vTC0.x = dot(IN.vPos, p_mTexgen0);
        OUT.vTC0.y = dot(IN.vPos, p_mTexgen1);
        OUT.vTC1 = IN.vTC1;
        OUT.cColor0 = IN.cColor0;
        OUT.cFactor0 = IN.cFactor0;
    }
    else if (b_iVertexShader == e_flashVertexShaderXY16iCF32) {
        OUT.vPos = mul(p_mTransform, IN.vPos);
        OUT.vTC0.x = dot(IN.vPos, p_mTexgen0);
        OUT.vTC0.y = dot(IN.vPos, p_mTexgen1);
        OUT.vTC1 = IN.vTC1;
        OUT.cColor0 = IN.cColor0;
        OUT.cFactor0 = IN.cFactor0;
    }
    else if (b_iVertexShader == e_flashVertexShaderXY16iCF32_T2) {
        OUT.vPos = mul(p_mTransform, IN.vPos);
        OUT.vTC0.x = dot(IN.vPos, p_mTexgen0);
        OUT.vTC0.y = dot(IN.vPos, p_mTexgen1);
        OUT.vTC1.x = dot(IN.vPos, p_mTexgen2);
        OUT.vTC1.y = dot(IN.vPos, p_mTexgen3);
        OUT.cColor0 = IN.cColor0;
        OUT.cFactor0 = IN.cFactor0;
    }

#ifdef COMPILING_SHADER_FOR_OPENGL
    OUT.vPos.y *= -1.0;
#endif
}

#endif  // VERTEX_SHADER

#ifdef PIXEL_SHADER

//------------------------------------------------------------------------------------------------
// Pixel shader types - must match interface code
//------------------------------------------------------------------------------------------------
#define e_flashPixelShaderSolidColor                        0
#define e_flashPixelShaderCxformTexture                     1
#define e_flashPixelShaderCxformTextureMultiply             2
#define e_flashPixelShaderTextTextureAlpha                  3
#define e_flashPixelShaderTextTextureColor                  4
#define e_flashPixelShaderTextTextureColorMultiply          5
#define e_flashPixelShaderCxformGauraud                     6
#define e_flashPixelShaderCxformGauraudNoAddAlpha           7
#define e_flashPixelShaderCxformGauraudTexture              8
#define e_flashPixelShaderCxform2Texture                    9
#define e_flashPixelShaderCxformGauraudMultiply             10
#define e_flashPixelShaderCxformGauraudMultiplyNoAddAlpha   11
#define e_flashPixelShaderCxformGauraudMultiplyTexture      12
#define e_flashPixelShaderCxformMultiply2Texture            13

//------------------------------------------------------------------------------------------------
// Samplers
//------------------------------------------------------------------------------------------------
texDecl2D(p_sTexture0);
texDecl2D(p_sTexture1);

//------------------------------------------------------------------------------------------------
// Uniform parameters
//------------------------------------------------------------------------------------------------
float4 p_vColor;
float4 p_vColorTransformMul;
float4 p_vColorTransformAdd;
float p_fFrameAlpha;

//--------------------------------------------------------------------------------------------------
// Pixel shader
//--------------------------------------------------------------------------------------------------
float4 FlashPixelMain (in SFlashVtxFmt IN) : COLOR {

    float4 outColor;
    
    if (b_iPixelShader == e_flashPixelShaderSolidColor) {
        outColor = p_vColor;
    }
    else if (b_iPixelShader == e_flashPixelShaderCxformTexture) {
        outColor = sample2D(p_sTexture0, IN.vTC0.xy) * p_vColorTransformMul + p_vColorTransformAdd;
    }
    else if (b_iPixelShader == e_flashPixelShaderCxformTextureMultiply) {
        float4 color = sample2D(p_sTexture0, IN.vTC0.xy);
        color = color * p_vColorTransformMul + p_vColorTransformAdd;
#ifdef COMPILING_SHADER_FOR_OPENGL
        outColor = lerp(float4(1), color, color.a);
#else
        outColor = lerp(1, color, color.a);
#endif
    }
    else if (b_iPixelShader == e_flashPixelShaderTextTextureAlpha) {
        float4 color = IN.cColor0 * p_vColorTransformMul + p_vColorTransformAdd;
        color.a = color.a * sample2D(p_sTexture0, IN.vTC0.xy).a;
        outColor = color;
    }
    else if (b_iPixelShader == e_flashPixelShaderTextTextureColor) {
        float4 color = sample2D(p_sTexture0, IN.vTC0.xy);
        color = color * p_vColorTransformMul + p_vColorTransformAdd;
        outColor = color;
    }
    else if (b_iPixelShader == e_flashPixelShaderTextTextureColorMultiply) {
        float4 color = sample2D(p_sTexture0, IN.vTC0.xy);
        color = color * p_vColorTransformMul + p_vColorTransformAdd;
#ifdef COMPILING_SHADER_FOR_OPENGL
        outColor = lerp(float4(1), color, color.a);
#else
        outColor = lerp(1, color, color.a);
#endif
    }
    else if (b_iPixelShader == e_flashPixelShaderCxformGauraud) {
        float4 color = IN.cColor0;
        color = color * p_vColorTransformMul + p_vColorTransformAdd;
        color.a = color.a * IN.cFactor0.a;
        outColor = color;
    }
    else if (b_iPixelShader == e_flashPixelShaderCxformGauraudNoAddAlpha) {
        outColor = IN.cColor0 * p_vColorTransformMul + p_vColorTransformAdd;
    }
    else if (b_iPixelShader == e_flashPixelShaderCxformGauraudTexture) {
        float4 color = lerp(IN.cColor0, sample2D(p_sTexture0, IN.vTC0.xy), IN.cFactor0.b);
        color = color * p_vColorTransformMul + p_vColorTransformAdd;
        color.a = color.a * IN.cFactor0.a;
        outColor = color;
    }
    else if (b_iPixelShader == e_flashPixelShaderCxform2Texture) {
        float4 color = lerp(sample2D(p_sTexture1, IN.vTC1.xy), sample2D(p_sTexture0, IN.vTC0.xy), IN.cFactor0.b);
        outColor = color * p_vColorTransformMul + p_vColorTransformAdd;
    }
    else if (b_iPixelShader == e_flashPixelShaderCxformGauraudMultiply) {
        float4 color = IN.cColor0 * p_vColorTransformMul + p_vColorTransformAdd;
        color.a = color.a * IN.cFactor0.a;
#ifdef COMPILING_SHADER_FOR_OPENGL
        outColor = lerp(float4(1), color, color.a);
#else
        outColor = lerp(1, color, color.a);
#endif
    }
    else if (b_iPixelShader == e_flashPixelShaderCxformGauraudMultiplyNoAddAlpha) {
        float4 color = IN.cColor0 * p_vColorTransformMul + p_vColorTransformAdd;
#ifdef COMPILING_SHADER_FOR_OPENGL
        outColor = lerp(float4(1), color, color.a);
#else
        outColor = lerp(1, color, color.a);
#endif
    }
    else if (b_iPixelShader == e_flashPixelShaderCxformGauraudMultiplyTexture) {
        float4 color = lerp(IN.cColor0, sample2D(p_sTexture0, IN.vTC0.xy), IN.cFactor0.b);
        color = color * p_vColorTransformMul + p_vColorTransformAdd;
        color.a = color.a * IN.cFactor0.a;
#ifdef COMPILING_SHADER_FOR_OPENGL
        outColor = lerp(float4(1), color, color.a);
#else
        outColor = lerp(1, color, color.a);
#endif
    }
    else if (b_iPixelShader == e_flashPixelShaderCxformMultiply2Texture) {
        float4 color = lerp(sample2D(p_sTexture1, IN.vTC1.xy), sample2D(p_sTexture0, IN.vTC0.xy), IN.cFactor0.b);
        color = color * p_vColorTransformMul + p_vColorTransformAdd;
#ifdef COMPILING_SHADER_FOR_OPENGL
        outColor = lerp(float4(1), color, color.a);
#else
        outColor = lerp(1, color, color.a);
#endif
    }

    outColor.a = outColor.a * p_fFrameAlpha;

    return outColor;
}

#endif  // PIXEL_SHADER