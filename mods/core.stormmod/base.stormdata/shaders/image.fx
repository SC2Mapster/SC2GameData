//==================================================================================================
// Copyright Blizzard Entertainment
//
// Shader interface for any two-dimensional screen-aligned quad.
//==================================================================================================

#include "ShaderSystem.fx"


struct SImageVtxFmt {
    float4 vPos         : POSITION;
    float4 cColor0      : COLOR0;
#if b_iLayerCount > 1
    float4 cColor1      : COLOR1;
#endif
#if b_iLayerCount > 2
    float4 cColor2      : TEXCOORD4;
#endif
#if b_iLayerCount > 3
    float4 cColor3      : TEXCOORD5;
#endif
    float4 vTC0         : TEXCOORD0;
#if b_iLayerCount > 1
    float4 vTC1         : TEXCOORD1;
#endif
#if b_iLayerCount > 2
    float4 vTC2         : TEXCOORD2;
#endif
#if b_iLayerCount > 3
    float4 vTC3         : TEXCOORD3;
#endif
};

#ifdef VERTEX_SHADER

//------------------------------------------------------------------------------------------------
// Vertex format
//------------------------------------------------------------------------------------------------
struct SImageVtxFmtGeneric {
    float4 vPos         : POSITION_;
    float4 cColor0      : COLOR0_;
#if b_iVertexLayoutLayerCount > 1
    float4 cColor1      : COLOR1_;
#endif
#if b_iVertexLayoutLayerCount > 2
    float4 cColor2      : TEXCOORD4_;
#endif
#if b_iVertexLayoutLayerCount > 3
    float4 cColor3      : TEXCOORD5_;
#endif
    float4 vTC0         : TEXCOORD0_;
#if b_iVertexLayoutLayerCount > 1
    float4 vTC1         : TEXCOORD1_;
#endif
#if b_iVertexLayoutLayerCount > 2
    float4 vTC2         : TEXCOORD2_;
#endif
#if b_iVertexLayoutLayerCount > 3
    float4 vTC3         : TEXCOORD3_;
#endif
};

//------------------------------------------------------------------------------------------------
// Uniform parameters
//------------------------------------------------------------------------------------------------
float4x4 p_mTransform;

//------------------------------------------------------------------------------------------------
// Vertex shader
//------------------------------------------------------------------------------------------------
void ImageVertexMain (in SImageVtxFmtGeneric IN, out SImageVtxFmt OUT) {
    OUT.vPos = mul(float4(IN.vPos), p_mTransform);
#ifdef COMPILING_SHADER_FOR_OPENGL
    OUT.vPos.y *= -1.0;
    OUT.vPos.z = 2.0 * (OUT.vPos.z - (0.5 * OUT.vPos.w));
#endif

#if defined(COMPILING_SHADER_FOR_OPENGL) || defined(COMPILING_SHADER_FOR_METAL)
    OUT.cColor0 = IN.cColor0.zyxw;
    #if b_iLayerCount > 1
        OUT.cColor1 = IN.cColor1.zyxw;
    #endif
    #if b_iLayerCount > 2
        OUT.cColor2 = IN.cColor2.zyxw;
    #endif
    #if b_iLayerCount > 3
        OUT.cColor3 = IN.cColor3.zyxw;
    #endif
#else
    OUT.cColor0 = IN.cColor0;
    #if b_iLayerCount > 1
        OUT.cColor1 = IN.cColor1;
    #endif
    #if b_iLayerCount > 2
        OUT.cColor2 = IN.cColor2;
    #endif
    #if b_iLayerCount > 3
        OUT.cColor3 = IN.cColor3;
    #endif
#endif
    OUT.vTC0 = IN.vTC0;
    #if b_iLayerCount > 1
        OUT.vTC1 = IN.vTC1;
    #endif
    #if b_iLayerCount > 2
        OUT.vTC2 = IN.vTC2;
    #endif
    #if b_iLayerCount > 3
        OUT.vTC3 = IN.vTC3;
    #endif
}

#endif  // VERTEX_SHADER

#ifdef PIXEL_SHADER

#include "Common.fx"

//------------------------------------------------------------------------------------------------
#define e_imageColorAdjustModeNone          0   // Normal/No Adjust: Vertex multiply which is always done despite the color mode
#define e_imageColorAdjustModeDesaturate    1   // Old desaturate method for backwards compatibility (MaxChannel x AdjustmentColor)
#define e_imageColorAdjustModeColorize      2   // Fast approximation of Hue shifting
#define e_imageColorAdjustModeFill          3   // Color overwriting
#define e_imageColorAdjustModeAddSelf       4   // Adds the image to itself mutiplied by both the color channel and alpha of the AdjustmentColor

//------------------------------------------------------------------------------------------------
// Samplers
//------------------------------------------------------------------------------------------------
texDecl2D(p_sLayer0);
texDecl2D(p_sLayer1);
texDecl2D(p_sLayer2);
texDecl2D(p_sLayer3);
texDecl2D(p_sAlphaMask);

//------------------------------------------------------------------------------------------------
// Parameters
//------------------------------------------------------------------------------------------------
float4 p_vLightAdjustColor;
float4 p_vDarkAdjustColor;
float4 p_vLayerAlphaChannelIndex;
float4 p_vLayerAlphaChannelInverse;
float4 p_vLayerAlphaChannelMultiply;

//--------------------------------------------------------------------------------------------------
// Pixel shader
//--------------------------------------------------------------------------------------------------
float4 ImagePixelMain (in SImageVtxFmt IN) : COLOR {
    float alphaMult = 1;
    float4 cColor = sample2D(p_sLayer0, IN.vTC0.xy);

    if (b_renderingInnerText) {
        // If we are rendering InnerText, we assume we are rendering text which lets us assume
        // the image is grayscale and we only want the opaque white parts.  So here we pretend
        // that 'g' means gray, and we multiply it by the alpha to get the new alpha which will
        // result in cutting out the inner white text from its black outline.
        cColor.a *= cColor.g;
        cColor.rgb = 1;
    }

    int index   = (int)p_vLayerAlphaChannelIndex[0];
    float newA  = cColor[index];
    newA        = lerp(newA, 1-newA, p_vLayerAlphaChannelInverse[0]);
    cColor.a    = lerp(newA, newA*cColor.a, p_vLayerAlphaChannelMultiply[0]);

    cColor *= IN.cColor0;

    // Alpha-only layers multiply their alpha into the next layer up and contribute no color
    // information to the final composited color.  The final layer cannot be alpha-only.
    if (b_layer0AlphaOnly) {
        alphaMult = cColor.a;
        cColor.rgb = 0;
        cColor.a = 1;
    }
    else {
        cColor.rgb *= cColor.a;
        cColor.a = 1 - cColor.a;
    }

    #if b_iLayerCount > 1
    {
        float4 cLayer = sample2D(p_sLayer1, IN.vTC1.xy);

        index   = (int)p_vLayerAlphaChannelIndex[1];
        newA    = cLayer[index];
        newA    = lerp(newA, 1-newA, p_vLayerAlphaChannelInverse[1]);
        cLayer.a= lerp(newA, newA*cLayer.a, p_vLayerAlphaChannelMultiply[1]);

        if (b_layer1AlphaOnly) {
            alphaMult *= cLayer.a * IN.cColor1.a;
        }
        else {
            cLayer *= IN.cColor1;

            float alpha = 1 - (cLayer.a * alphaMult);
            cColor.rgb = lerp(cLayer.rgb, cColor.rgb, alpha);
            cColor.a *= alpha;
            alphaMult = 1;
        }
    }
    #endif
    #if b_iLayerCount > 2
    {
        float4 cLayer = sample2D(p_sLayer2, IN.vTC2.xy);

        index   = (int)p_vLayerAlphaChannelIndex[2];
        newA    = cLayer[index];
        newA    = lerp(newA, 1-newA, p_vLayerAlphaChannelInverse[2]);
        cLayer.a= lerp(newA, newA*cLayer.a, p_vLayerAlphaChannelMultiply[2]);

        if (b_layer2AlphaOnly) {
            alphaMult *= cLayer.a * IN.cColor2.a;
        }
        else {
            cLayer *= IN.cColor2;

            float alpha = 1 - (cLayer.a * alphaMult);
            cColor.rgb = lerp(cLayer.rgb, cColor.rgb, alpha);
            cColor.a *= alpha;
            alphaMult = 1;
        }
    }
    #endif
    #if b_iLayerCount > 3
    {
        float4 cLayer = sample2D(p_sLayer3, IN.vTC3.xy);

        index   = (int)p_vLayerAlphaChannelIndex[3];
        newA    = cLayer[index];
        newA    = lerp(newA, 1-newA, p_vLayerAlphaChannelInverse[3]);
        cLayer.a= lerp(newA, newA*cLayer.a, p_vLayerAlphaChannelMultiply[3]);

        cLayer *= IN.cColor3;

        // To save on shaders, the final layer cannot be alpha only
        float alpha = 1 - (cLayer.a * alphaMult);
        cColor.rgb = lerp(cLayer.rgb, cColor.rgb, alpha);
        cColor.a *= alpha;
    }
    #endif


    if (b_colorAdjustMode == e_imageColorAdjustModeDesaturate) {
        float fMax = max(max(cColor.r, cColor.g), cColor.b);

        // un-premultiply the alpha (add 1/256 / 1/512 to prevent divide by 0);
        fMax *= (cColor.a >= 1.0f) ? 512.0f : (1.0f / (1.0f - cColor.a));   // Un-pre-mult the alphas
        fMax = saturate(fMax);

        float4 desaturateColor;
        desaturateColor = lerp(p_vDarkAdjustColor, p_vLightAdjustColor, fMax);

        // re-multiply the alpha
        desaturateColor.rgb *= 1 - cColor.a;

        cColor.rgb = lerp(cColor.rgb, desaturateColor.rgb, desaturateColor.a);
    }
    else if (b_colorAdjustMode == e_imageColorAdjustModeColorize) {
        // 2x Grayscale value
        float gray = cColor.r * .62f + cColor.g * 1.1737f + cColor.b * .2067f;
        gray *= (cColor.a >= 1.0f) ? 512.0f : (1.0f / (1.0f - cColor.a));   // Un-pre-mult the alphas

        float4 colorizeColor = float4(0, 0, 0, 1);

        // Linear interpolation: black(@0.0) -> color(@1.0) -> white(@2.0)
        if (gray > 1.0f)
        {
            gray -= 1.0f;
            // Free clamping to [0,1]
            gray = saturate(gray);

            colorizeColor = lerp(p_vDarkAdjustColor, p_vLightAdjustColor, gray);
        }
        else
        {
            colorizeColor = float4(
                (gray * p_vDarkAdjustColor.r),
                (gray * p_vDarkAdjustColor.g),
                (gray * p_vDarkAdjustColor.b),
                p_vDarkAdjustColor.a);
        }

        // re-multiply the alpha
        colorizeColor.rgb *= (1 - cColor.a);

        cColor.rgb = lerp(cColor.rgb, colorizeColor.rgb, colorizeColor.a);
    }
    else if (b_colorAdjustMode == e_imageColorAdjustModeFill) {
        float4 fillColor = p_vLightAdjustColor;
        fillColor.rgb *= (1 - cColor.a);

        // Interpolate between composite color and fill color
        cColor.rgb = lerp(cColor.rgb, fillColor.rgb, fillColor.a);
    }
    else if (b_colorAdjustMode == e_imageColorAdjustModeAddSelf) {
        // Un-pre-multiply the alpha.
        cColor.rgb *= cColor.a >= 1.0f ? 512.0f : (1.0f / (1.0f - cColor.a));

        // ColorOut.rgb = ColorIn.rgb + 2*(ColorIn.rgb * AdjustmentColor.rgb);
        float4 addColor = p_vLightAdjustColor;
        addColor.rgb *= 2;                      // Give AdjustmentColor's color channels a 0 - 2 meaning
        addColor.rgb *= p_vLightAdjustColor.a;   // Muliply the alpha value to accomplish interpolation.
        addColor.rgb *= cColor.rgb;             // Choose which color channels to add (and by how much)
        addColor.rgb += cColor.rgb;             // Do the color adding
        addColor.rgb = saturate(addColor.rgb);  // clamp rgb values to 0, and 1
        addColor.rgb *= (1 - cColor.a);         // Premultiply the alphas

        // lerp() not required
        // Interpolation using the alpha channel has effectively already been done.
        cColor.rgb = addColor.rgb;
    }

    if (b_iUseAlphaMask) {
        float4 cLayer = sample2D(p_sAlphaMask, IN.vTC0.xy);
        cColor.rgb *= cLayer.a;
        cColor.a = 1 - ( (1 - cColor.a) * cLayer.a );
    }

    if (b_imageUse8BitHDR) {
        cColor.rgb *= 0.5f;
    }

    AlphaTest(1-cColor.a);

    return cColor;
}

#endif  // PIXEL_SHADER