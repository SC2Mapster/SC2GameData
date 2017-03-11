//==================================================================================================
//
// Copyright Blizzard Entertainment 2003-2007
//
// movie player shader code
//==================================================================================================

#include "ShaderSystem.fx"

struct VSOutput {
    float4 vHPos        : POSITION;
    float2 vUV0         : TEXCOORD0;
};

//--------------------------------------------------------------------------------------------------
// VERTEX_SHADER
//--------------------------------------------------------------------------------------------------
#ifdef VERTEX_SHADER

struct Input {
    float4  vPosition   : POSITION_;
    float2  vUV         : TEXCOORD0_;
};



//--------------------------------------------------------------------------------------------------
float3   p_vSize;
float4x4 p_mWorldViewProj;      // World * View * Projection transformation

//--------------------------------------------------------------------------------------------------
void MovieVertexMain( in Input vertIn, out VSOutput vertOut ) {   
    vertIn.vPosition.xyz *= p_vSize; 
    vertOut.vHPos = mul(vertIn.vPosition, p_mWorldViewProj);
    vertOut.vUV0  = vertIn.vUV;

#ifdef COMPILING_SHADER_FOR_OPENGL
    vertOut.vHPos.y *= -1.0;
    vertOut.vHPos.z = 2.0 * (vertOut.vHPos.z - (0.5 * vertOut.vHPos.w));
#endif    
}

#endif  // VERTEX_SHADER







//--------------------------------------------------------------------------------------------------
// PIXEL_SHADER
//--------------------------------------------------------------------------------------------------
#ifdef PIXEL_SHADER

float4      p_cColor;

// YUV textures
texDecl2D(p_sY);
texDecl2D(p_sUV);

//--------------------------------------------------------------------------------------------------
float3 Yuv2Rgb (float y, float u, float v) {
    return saturate(float3(y+1.402f*(v-0.5f), y-0.34414f*(u-0.5f) - 0.71414f*(v-0.5f), y+1.772f*(u-0.5f)));
}

//--------------------------------------------------------------------------------------------------
float4 MoviePixelMain( VSOutput vertOut ) : COLOR {    
    float4 vFinal=1;
    
    float y = sample2D(p_sY, vertOut.vUV0).x;
    float2 vUV = sample2D(p_sUV, vertOut.vUV0).zw;
    vFinal.xyz = Yuv2Rgb(y, vUV.x, vUV.y);
    
    vFinal *= p_cColor;

    return vFinal;
}


#endif      // PIXEL_SHADER