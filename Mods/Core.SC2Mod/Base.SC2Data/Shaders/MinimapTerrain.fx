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

#ifdef COMPILING_SHADER_FOR_OPENGL
    OUT.vPos.y *= -1.0;
#endif
}

#endif  // VERTEX_SHADER

#ifdef PIXEL_SHADER

//------------------------------------------------------------------------------------------------
// Samplers
//------------------------------------------------------------------------------------------------
sampler2D p_sTerrainTexture;
sampler2D p_sFowTexture;
sampler2D p_sCreepTexture;

//------------------------------------------------------------------------------------------------
// Uniform parameters
//------------------------------------------------------------------------------------------------
float4 p_vColor;

//--------------------------------------------------------------------------------------------------
// Pixel shader
//--------------------------------------------------------------------------------------------------
float4 MinimapTerrainPixelMain (in SMinimapTerrainVtxFmt IN) : COLOR {    
    float4 color = tex2D(p_sTerrainTexture, IN.vTC0.xy);
    
    if (!b_showMap) {
        float4 creepTex = tex2D(p_sCreepTexture, IN.vTC1.xy);
        color = lerp(color, float4(0.5f, 0.0f, 0.847f, 0.5f), creepTex.w);
        float4 fowTex = tex2D(p_sFowTexture, IN.vTC2.xy);
        color = lerp(color, fowTex, fowTex.w);
    }

    return float4(color.xyz, 1) * p_vColor;
}

#endif  // PIXEL_SHADER