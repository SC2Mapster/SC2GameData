//==================================================================================================
//
// Copyright Blizzard Entertainment 2003-2005
//
// A simple full-screen quad used for post-processing.
//==================================================================================================

#include "ShaderSystem.fx"

#ifdef VERTEX_SHADER

struct Input {
    float4  vPosition		    : POSITION_;
    float4  cColor  		    : COLOR0_;
    HALF2   vUV0                : TEXCOORD0_;
};

#define b_iUVEmitterCount  1           // :HACK:

#include "VSEmitters.fx"
#include "VSPostProcess.fx"

float4x4 p_mTransform;
HALF2 p_vCameraSize;

//--------------------------------------------------------------------------------------------------
float4 EmitPostProcessQuadHPos( Input vertIn ) {
    float4 HPos;
    if ( b_useTransform )
        HPos = mul( vertIn.vPosition, p_mTransform );
    else HPos = vertIn.vPosition;
    return HPos;
}

//--------------------------------------------------------------------------------------------------
HALF4 EmitPostProcessQuadUV( Input vertIn, int iIndex ) {
    return HALF4( vertIn.vUV0, 0, 1 );
}

//--------------------------------------------------------------------------------------------------
void PostProcessQuadVertexMain( in Input vertIn, out VertexTransport vertOut ) {
    InitShader( vertOut );
    vertOut.HPos = EmitPostProcessQuadHPos( vertIn );
#if COMPILING_SHADER_WITH_BSL
    // Workaround for a OpenGL3 driver bug when compiling with BSL
    [unroll]
#endif
    for ( int i = 0; i < b_iUVEmitterCount; i++ )
        READ_INTERPOLANT_UV( i ) = EmitPostProcessQuadUV( vertIn, i );
        
    if (b_iSampleCountPS == 0) {
#if __bsl__
        // Inspector Bug ID: 186629
        [unroll]
#endif
        for ( int i = 0; i < b_iSampleInterpolantCount; i++ )
            WRITE_INTERPOLANT_GaussianBlurSample(i, EmitGaussianBlurSample( vertIn, i ) );
    }

#ifdef COMPILING_SHADER_FOR_OPENGL
    vertOut.HPos.y *= -1.0;
    vertOut.HPos.z = 2.0 * (vertOut.HPos.z - (0.5 * vertOut.HPos.w));
#endif    
    
    WRITE_INTERPOLANT_DownscaleUV0( EmitDownscaleUV0( vertIn ) );
    WRITE_INTERPOLANT_DownscaleUV1( EmitDownscaleUV1( vertIn ) );
}

#endif

#ifdef PIXEL_SHADER

#include "PSPostProcess.fx"

//--------------------------------------------------------------------------------------------------
HALF4 PostProcessQuadPixelMain( VertexTransportRaw vertRaw ) : COLOR {
    VertexTransport vertOut;
    InitShader( vertRaw, vertOut );
    return PostProcess( vertOut );
}

#endif