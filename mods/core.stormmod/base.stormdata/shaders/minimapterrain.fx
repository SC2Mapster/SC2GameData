//==================================================================================================
// Copyright Blizzard Entertainment
//
// Shader interface for Minimap terrain.
//==================================================================================================

#include "ShaderSystem.fx"

//------------------------------------------------------------------------------------------------
// Vertex format
//------------------------------------------------------------------------------------------------
struct SMinimapTerrainVtxFmt {
    float4 vPos         : POSITION;
    float4 vTC0         : TEXCOORD0;
    float4 vTC1         : TEXCOORD1;
    float4 vTC2         : TEXCOORD2;
    float4 vTC3         : TEXCOORD3;
};

#ifdef VERTEX_SHADER

//------------------------------------------------------------------------------------------------
// Vertex format
//------------------------------------------------------------------------------------------------
struct SMinimapTerrainVtxFmtGeneric {
    float4 vPos         : POSITION_;
    float4 vTC0         : TEXCOORD0_;
    float4 vTC1         : TEXCOORD1_;
    float4 vTC2         : TEXCOORD2_;
    float4 vTC3         : TEXCOORD3_;
};

//------------------------------------------------------------------------------------------------
// Uniform parameters
//------------------------------------------------------------------------------------------------
float4x4 p_mTransform;

//------------------------------------------------------------------------------------------------
// Vertex shader
//------------------------------------------------------------------------------------------------
void MinimapTerrainVertexMain (in SMinimapTerrainVtxFmtGeneric IN, out SMinimapTerrainVtxFmt OUT) {
    OUT.vPos = mul(IN.vPos, p_mTransform);
    OUT.vTC0 = IN.vTC0;
    OUT.vTC1 = IN.vTC1;
    OUT.vTC2 = IN.vTC2;
    OUT.vTC3 = IN.vTC3;

#ifdef COMPILING_SHADER_FOR_OPENGL
    OUT.vPos.y *= -1.0;
#endif
}

#endif  // VERTEX_SHADER

#ifdef PIXEL_SHADER

//------------------------------------------------------------------------------------------------
// Samplers
//------------------------------------------------------------------------------------------------
texDecl2D(p_sTerrainTexture);
texDecl2D(p_sWaterTexture);
texDecl2D(p_sFowTexture);
texDecl2D(p_sCreepTexture);

//------------------------------------------------------------------------------------------------
// Uniform parameters
//------------------------------------------------------------------------------------------------
float4 p_vColor;
float4 p_vFOWLevels;

//--------------------------------------------------------------------------------------------------
// Pixel shader
//--------------------------------------------------------------------------------------------------
float4 MinimapTerrainPixelMain (in SMinimapTerrainVtxFmt IN) : COLOR {
    float4 terrainColor = sample2D(p_sTerrainTexture, IN.vTC0.xy);
    float4 waterColor = sample2D(p_sWaterTexture, IN.vTC3.xy);
    float4 color = lerp(terrainColor, waterColor, waterColor.w);

    if (!b_showMap) {
        float4 creepTex = sample2D(p_sCreepTexture, IN.vTC1.xy);
        color.rgb = lerp(color.rgb, float3(0.375f, 0.114f, 0.550f), creepTex.w * 0.5f);

        float4 cFOWFactor;
        cFOWFactor.rgb = saturate(2.f * sample2D(p_sFowTexture, IN.vTC2.xy).rgb);
        cFOWFactor.a = dot(cFOWFactor.rgb, p_vFOWLevels.rgb);
        cFOWFactor.rgb = 0.f;

        // Only fully opaque pixels should have fog of war applied to them
        color.rgb = lerp(color.rgb, cFOWFactor.rgb, terrainColor.a < 1.0f ? 0 : cFOWFactor.a);
    }

    if (b_iScaleAlphaToTerrain) {
        color.a *= terrainColor.a;
    }

    return color * p_vColor;
}

#endif  // PIXEL_SHADER
