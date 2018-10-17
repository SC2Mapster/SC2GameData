//==================================================================================================
//
// Copyright Blizzard Entertainment 2003-2005
//
// Shader code for various debugging purposes.
//==================================================================================================

#include "ShaderSystem.fx"

struct VertexOutput {
    float4  vPosition		: POSITION;
    float2  vUV              : TEXCOORD0;
};

#ifdef VERTEX_SHADER

struct Input {
    float3  vPosition		: POSITION_;
    float2   vUV             : TEXCOORD0_;
};

//--------------------------------------------------------------------------------------------------
VertexOutput DebugVertexMain( Input input ) {
    VertexOutput output;
    InitShader();
#ifdef COMPILING_SHADER_FOR_OPENGL
    output.vPosition    = float4( input.vPosition.x, -input.vPosition.y, (input.vPosition.z * 2.0) - 1.0, 1.0f );
#else
    output.vPosition    = float4( input.vPosition, 1.0f );
#endif
    output.vUV          = input.vUV;
    return output;
}

#endif  // VERTEX_SHADER

#ifdef PIXEL_SHADER

#include "PSTonemap.fx"

#define VIEW_HDR_CURVE    0

float p_fBloomThreshold;

//--------------------------------------------------------------------------------------------------
float4 ViewHDRCurve( float2 vUV ) {
    float fSrcL = -log( 1.0f - vUV.x );
    float fDestL = Tonemap( fSrcL );
    float4 vResult;
    if ( ( 1.0f - vUV.y ) < fDestL ) 
        vResult = float4( fSrcL, fSrcL, fSrcL, 1.0f );
    else  {
        vResult = float4( 0.0f, 0.0f, 0.6f, 1.0f );
        if ( fSrcL > p_fBloomThreshold )    
            vResult.g += 0.5f;
    }

    float fRatio = fSrcL / ( 1.0f - vUV.y );
    if ( fRatio > 0.99f && fRatio < 1.01f )
        vResult = float4( 1.0f, 0.0f, 0.0f, 1.0f );
    return vResult;
}

//--------------------------------------------------------------------------------------------------
float4 DebugPixelMain( VertexOutput input ) : COLOR {
    InitShader();
    if ( b_iDebugFunction == VIEW_HDR_CURVE ) {
        return ViewHDRCurve( input.vUV );
    } else return 1;
}

#endif  // PIXEL_SHADER