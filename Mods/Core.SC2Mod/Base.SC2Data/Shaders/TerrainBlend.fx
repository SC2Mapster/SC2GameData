//==================================================================================================
//
// Copyright Blizzard Entertainment 2003-2007
//
// terrain texture blending
//==================================================================================================

#include "ShaderSystem.fx"

//--------------------------------------------------------------------------------------------------
// vertex shader to pixel shader parameters
//--------------------------------------------------------------------------------------------------
struct VertexTransport {
    float4 vPos  : POSITION;
    float4 vUV0  : TEXCOORD0;
    float4 vUV1  : TEXCOORD1;
};





//--------------------------------------------------------------------------------------------------
// VERTEX_SHADER
//--------------------------------------------------------------------------------------------------
#ifdef VERTEX_SHADER

//--------------------------------------------------------------------------------------------------
// input vertex format
//--------------------------------------------------------------------------------------------------
struct Input {
    float4  vPosition   : POSITION_;
};

float4 p_vTiling;
float2 p_vMaskTiling;
float3 p_vCenter;
float3 p_vSize;
float4x4 p_mWorldViewProj;

//--------------------------------------------------------------------------------------------------
void TerrainBlendVertexMain( in Input vertIn, out VertexTransport vertOut ) {
    VertexTransport output;
    float3 vPos = vertIn.vPosition*p_vSize + p_vCenter;
    vertOut.vPos = mul(float4(vPos, 1), p_mWorldViewProj);
    vertOut.vUV0.xy = vPos.xy*p_vTiling.xy + p_vTiling.zw;
    vertOut.vUV0.y = 1 - vertOut.vUV0.y;
    vertOut.vUV1.xy = vPos.xy*p_vMaskTiling.xy;
    vertOut.vUV1.y = 1 - vertOut.vUV1.y;

#ifdef COMPILING_SHADER_FOR_OPENGL
    vertOut.vPos.y *= -1.0;
#endif    
}

#endif  // VERTEX_SHADER








//--------------------------------------------------------------------------------------------------
// PIXEL_SHADER
//--------------------------------------------------------------------------------------------------
#ifdef PIXEL_SHADER

//#include "PSCommon.fx"

sampler2D   p_sTexture0;
sampler2D   p_sTexture1;
sampler2D   p_sTexture2;
sampler2D   p_sTexture3;
sampler2D   p_sMask;

//--------------------------------------------------------------------------------------------------
float4 TerrainBlendPixelMain( VertexTransport vertOut ) : COLOR {
    float4 col0  = tex2D(p_sTexture0, vertOut.vUV0.xy);
    float4 col1  = tex2D(p_sTexture1, vertOut.vUV0.xy);
    float4 col2  = tex2D(p_sTexture2, vertOut.vUV0.xy);
    float4 col3  = tex2D(p_sTexture3, vertOut.vUV0.xy);
    float4 masks = tex2D(p_sMask, vertOut.vUV1.xy);

    float4 result = col0*masks.w + col1*masks.x + col2*masks.y + col3*masks.z;

    // if necessary we need to convert it to a non-dxn normal map format
    if (b_iUnSwizzleDXNNormalMaps) {
        float4 finalNormal;
        finalNormal.xy = 2.0f * result.wy - 1.0f;
        finalNormal.z = sqrt(max(0, 1 - dot(finalNormal.xy, finalNormal.xy)));

        // w stores height map
        result.w = result.r;
        result.xyz = (finalNormal.xyz + 1) * 0.5f;
    }

    if (b_iTerrainDebugMode!=0)
        return masks;

    return result;
}

#endif      // PIXEL_SHADER