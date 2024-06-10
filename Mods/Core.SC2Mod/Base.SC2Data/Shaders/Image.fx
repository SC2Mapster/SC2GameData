//==================================================================================================
// Copyright Blizzard Entertainment
//
// Shader interface for any two-dimensional screen-aligned quad.
//==================================================================================================

#include "ShaderSystem.fx"

struct SImageVtxFmt {
    float4 vPos         : POSITION;
    float4 vTC0         : TEXCOORD0;
    float4 vTC1         : TEXCOORD1;
    float4 vTC2         : TEXCOORD2;
    float4 vTC3         : TEXCOORD3;
    float4 cColor0      : COLOR0;
    float4 cColor1      : COLOR1;
    float4 cColor2      : TEXCOORD4;
    float4 cColor3      : TEXCOORD5;
};

#ifdef VERTEX_SHADER

//------------------------------------------------------------------------------------------------
// Vertex format
//------------------------------------------------------------------------------------------------
struct SImageVtxFmtGeneric {
    float4 vPos         : POSITION_;
    float4 vTC0         : TEXCOORD0_;
    float4 vTC1         : TEXCOORD1_;
    float4 vTC2         : TEXCOORD2_;
    float4 vTC3         : TEXCOORD3_;
    float4 cColor0      : COLOR0_;
    float4 cColor1      : COLOR1_;
    float4 cColor2      : TEXCOORD4_;
    float4 cColor3      : TEXCOORD5_;
};

//------------------------------------------------------------------------------------------------
// Uniform parameters
//------------------------------------------------------------------------------------------------
float4x4 p_mTransform;

//------------------------------------------------------------------------------------------------
// Vertex shader
//------------------------------------------------------------------------------------------------
void ImageVertexMain (in SImageVtxFmtGeneric IN, out SImageVtxFmt OUT) {
    OUT.vPos = mul(float4(IN.vPos.xy, 0, 1), p_mTransform);
#ifdef COMPILING_SHADER_FOR_OPENGL
    OUT.vPos.y *= -1.0;
    OUT.vPos.z = 2.0 * (OUT.vPos.z - (0.5 * OUT.vPos.w));
    OUT.cColor0 = IN.cColor0.zyxw;
    if (b_iLayerCount > 1) {
        OUT.cColor1 = IN.cColor1.zyxw;
    }
    if (b_iLayerCount > 2) {
        OUT.cColor2 = IN.cColor2.zyxw;
    }
    if (b_iLayerCount > 3) {
        OUT.cColor3 = IN.cColor3.zyxw;
    }
#else
    OUT.cColor0 = IN.cColor0;
    if (b_iLayerCount > 1) {
        OUT.cColor1 = IN.cColor1;
    }
    if (b_iLayerCount > 2) {
        OUT.cColor2 = IN.cColor2;
    }
    if (b_iLayerCount > 3) {
        OUT.cColor3 = IN.cColor3;
    }
#endif
    OUT.vTC0 = IN.vTC0;
    if (b_iLayerCount > 1) {
        OUT.vTC1 = IN.vTC1;
    }
    if (b_iLayerCount > 2) {
        OUT.vTC2 = IN.vTC2;
    }
    if (b_iLayerCount > 3) {
        OUT.vTC3 = IN.vTC3;
    }
}

#endif  // VERTEX_SHADER

#ifdef PIXEL_SHADER

float4 p_vDesaturationColor;

//------------------------------------------------------------------------------------------------
// Samplers
//------------------------------------------------------------------------------------------------
sampler2D p_sLayer0;
sampler2D p_sLayer1;
sampler2D p_sLayer2;
sampler2D p_sLayer3;

//--------------------------------------------------------------------------------------------------
// Pixel shader
//--------------------------------------------------------------------------------------------------
float4 ImagePixelMain (in SImageVtxFmt IN) : COLOR {
    float4 cColor = tex2D(p_sLayer0, IN.vTC0.xy) * IN.cColor0;
    cColor.a = 1 - cColor.a;

    if (b_iLayerCount > 1) {
        float4 cLayer = tex2D(p_sLayer1, IN.vTC1.xy) * IN.cColor1;
        cColor.rgb = lerp(cColor.rgb, cLayer.rgb, cLayer.a);
        cColor.a *= 1 - cLayer.a;
    }

    if (b_iLayerCount > 2) {
        float4 cLayer = tex2D(p_sLayer2, IN.vTC2.xy) * IN.cColor2;
        cColor.rgb = lerp(cColor.rgb, cLayer.rgb, cLayer.a);
        cColor.a *= 1 - cLayer.a;
    }

    if (b_iLayerCount > 3) {
        float4 cLayer = tex2D(p_sLayer3, IN.vTC3.xy) * IN.cColor3;
        cColor.rgb = lerp(cColor.rgb, cLayer.rgb, cLayer.a);
        cColor.a *= 1 - cLayer.a;
    }

    if (b_desaturate) {
        float fMax = max(max(cColor.r, cColor.g), cColor.b);
        cColor = float4(fMax, fMax, fMax, cColor.a);
        cColor.rgb *= p_vDesaturationColor.rgb;
    }

    cColor.a = 1 - cColor.a;

    if ( b_imageUse8BitHDR )
        cColor.rgb *= 0.5f;
    return cColor;
}

#endif  // PIXEL_SHADER