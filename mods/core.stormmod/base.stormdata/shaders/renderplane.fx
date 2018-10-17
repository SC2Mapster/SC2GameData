//==================================================================================================
//
// Copyright Blizzard Entertainment 2003-2009
//
// render plane shader code
//==================================================================================================

#include "ShaderSystem.fx"

struct VertexTransport {
    float4 vHPos        : POSITION;
    float4 vFowUV       : TEXCOORD0;
};

#define INTERPOLANT_FOWUV   vertOut.vFowUV

#include "PSFOW.fx"

//--------------------------------------------------------------------------------------------------
// VERTEX_SHADER
//--------------------------------------------------------------------------------------------------
#ifdef VERTEX_SHADER

struct Input {
    float4  vPosition   : POSITION_;
};



//--------------------------------------------------------------------------------------------------
float3   p_vSize;
float3   p_vOffset;
float4x4 p_mWorldViewProj;      // World * View * Projection transformation
float4x4 p_mFOWMatrix;

//--------------------------------------------------------------------------------------------------
void RenderPlaneVertexMain( in Input vertIn, out VertexTransport vertOut ) {   
    vertIn.vPosition.xyz *= p_vSize; 
    vertIn.vPosition.xyz += p_vOffset;
    vertOut.vFowUV        = mul(vertIn.vPosition, p_mFOWMatrix);
    vertOut.vHPos         = mul(vertIn.vPosition, p_mWorldViewProj);

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

//--------------------------------------------------------------------------------------------------
float4 RenderPlanePixelMain( VertexTransport vertOut ) : COLOR {    
    float2 fowUv = vertOut.vFowUV.xy * HALF2(0.5f, -0.5f) + 0.5f;
    float4 cResult = 1;
    HALF3 cStub;
    cResult = ApplyFogOfWar( fowUv, cResult, cStub);
    return float4( p_cFOWBlackMaskColor, 1.0f - cResult.r );
}


#endif      // PIXEL_SHADER