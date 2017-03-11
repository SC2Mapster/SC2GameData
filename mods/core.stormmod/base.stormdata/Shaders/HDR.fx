//==================================================================================================
//
// Copyright Blizzard Entertainment 2003-2005
//
// This is the shader code for HDR post-processing.
//==================================================================================================

#include "ShaderSystem.fx"

struct VertexOutput {
    float4  vPosition		: POSITION;
    float2  vUV0            : TEXCOORD0;
};

#define LUMA_OFF            0
#define LUMA_OPTIMAL        1
#define LUMA_EQUAL          2
#define LUMA_IGNOREBLUE     3

#ifdef VERTEX_SHADER

struct Input {
    float3  vPosition		: POSITION_;
    float4  cColor   		: COLOR0_;
    float2  vUV             : TEXCOORD0_;
};

//--------------------------------------------------------------------------------------------------
VertexOutput HDRVertexMain( Input input ) {
    InitShader();
    VertexOutput output;
#ifdef COMPILING_SHADER_FOR_OPENGL
    output.vPosition = HALF4( input.vPosition.x, -input.vPosition.y, (input.vPosition.z * 2.0) - 1.0, 1.0f );
#else
    output.vPosition = HALF4( input.vPosition, 1.0f );
#endif    
    output.vUV0 = input.vUV;
    return output;
}

#endif  // VERTEX_SHADER

#ifdef PIXEL_SHADER

#include "PSTonemap.fx"

#define MODE_DOWNSAMPLE_LUM_LOG     0
#define MODE_DOWNSCALE_LUM          1
#define MODE_DOWNSAMPLE_LUM_EXP     2
#define MODE_TONEMAP                3

texDecl2D(p_sSrcMap);
texDecl2D(p_sBloomMap);
texDecl2D(p_sLuminanceMap);
texDecl2D(p_sAccumulationBuffer);
texDecl3D(p_sColorMap);

HALF    p_fSaturation;
HALF    p_fBloomThreshold;
HALF    p_fHDRScaling;

static const HALF3 c_vLuminanceWeights = HALF3(0.35f, 0.5f, 0.125f);
static const float c_fEpsilon = 0.0001f;

//--------------------------------------------------------------------------------------------------
float3 ConvertRGBToYUV( float3 cRGB ) {
    float3 vYUV;
    vYUV.r = dot( HALF3( 0.299f, 0.587f, 0.114f ), cRGB );
    vYUV.g = ( cRGB.b - vYUV.r ) * 0.565f;
    vYUV.b = ( cRGB.r - vYUV.r ) * 0.713f;
    return vYUV;
}

//--------------------------------------------------------------------------------------------------
float3 ConvertYUVToRGB( float3 vYUV ) {
    float3 cRGB;
    cRGB.r = vYUV.r + 1.403f * vYUV.b;
    cRGB.g = vYUV.r - 0.344f * vYUV.g - 0.714f * vYUV.b;
    cRGB.b = vYUV.r + 1.770f * vYUV.g;
    return cRGB;
}

//--------------------------------------------------------------------------------------------------
HALF4 HDRPixelMain( VertexOutput input ) : COLOR {
    InitShader();
    /*
      else if ( b_iHDRPass == MODE_DOWNSAMPLE_LUM_LOG ) {
        // Convert to luminance, take log (for geometric average) and 4x4 bilinear downscale.
        float fLuminance = ( log( dot( tex2D( p_sSrcMap, input.vUV0.xy ).rgb, c_vLuminanceWeights ) + c_fEpsilon ) +
                            log( dot( tex2D( p_sSrcMap, input.vUV0.zw ).rgb, c_vLuminanceWeights ) + c_fEpsilon ) +
                            log( dot( tex2D( p_sSrcMap, input.vUV1.xy ).rgb, c_vLuminanceWeights ) + c_fEpsilon ) +
                            log( dot( tex2D( p_sSrcMap, input.vUV1.zw ).rgb, c_vLuminanceWeights ) + c_fEpsilon ) ) * 0.25f;
        return float4( fLuminance, 0.0f, 0.0f, 0.0f );
        
    } else if ( b_iHDRPass == MODE_DOWNSCALE_LUM ) {
        // 4x4 bilinear downscale of fLuminance.
        return( tex2D( p_sSrcMap, input.vUV0.xy ).r + tex2D( p_sSrcMap, input.vUV0.zw ).r +
                tex2D( p_sSrcMap, input.vUV1.xy ).r + tex2D( p_sSrcMap, input.vUV1.zw ).r ) * 0.25f;
                
    } else if ( b_iHDRPass == MODE_DOWNSAMPLE_LUM_EXP ) {
        // 4x4 bilinear downscale and conversion back to non-logarithmic space.
        float fLuminance = ( tex2D( p_sSrcMap, input.vUV0.xy ).r + tex2D( p_sSrcMap, input.vUV0.zw ).r +
                            tex2D( p_sSrcMap, input.vUV1.xy ).r + tex2D( p_sSrcMap, input.vUV1.zw ).r ) * 0.25f;
        return exp( fLuminance );
    
    } */
    if ( b_iHDRPass == MODE_TONEMAP ) {
        // Tonemapping step.
        HALF3 cColor  = sample2D(p_sSrcMap, input.vUV0.xy ).rgb;
        if ( b_iUse8BitHDRPostProcess )
            cColor.rgb *= p_fHDRScaling;
        if ( b_useBloom ) {
            float3 bloom = sample2D( p_sBloomMap, input.vUV0.xy ).rgb;
            if ( b_iScaleBloom )
                bloom *= 2.0f;  // Exaggerate bloom to compensate for capped HDR.
           cColor += bloom;
        }

        /*
        if ( b_addMotionBlur ) {
            // Add accumulation and blur it a bit.
            cColor +=   (   tex2D( p_sAccumulationBuffer, input.vUV1.xy ) + tex2D( p_sAccumulationBuffer, input.vUV1.zw ) +
                            tex2D( p_sAccumulationBuffer, input.vUV2.xy ) + tex2D( p_sAccumulationBuffer, input.vUV2.zw ) ) * 0.25f;
        }
        */
        
        float fSrcL = dot( c_vLuminanceWeights, cColor );

        // White shift.
        if ( b_useWhiteShift && b_iOperator != REINHARD_OPERATOR ) {
            HALF fRatio = saturate( ( fSrcL - 1.5f ) / fSrcL );
            cColor = lerp( cColor, HALF3( fSrcL, fSrcL, fSrcL ), fRatio );
        }

        float fToneMappedL = Tonemap( fSrcL );

        // Saturation removed for now.
        // cColor = fToneMappedL * pow( cColor / fSrcL, p_fSaturation );
        cColor = fToneMappedL * cColor / fSrcL;

        if ( b_useColorMapping ) {
            cColor.rgb += 0.5f / b_iColorMapSize;
            cColor.rgb = sample3D( p_sColorMap, saturate( cColor.rgb ) );
        }
        
        float fAlpha = 1.0;
        if (b_iAALumaMode != LUMA_OFF) {
            // Store luma in Alpha channel - see FXAA description in PSAntiAliasing.fx
            if (b_iAALumaMode == LUMA_EQUAL)
                fAlpha = (cColor.r + cColor.g + cColor.b) / 3.0;
            if (b_iAALumaMode == LUMA_IGNOREBLUE)
                fAlpha = cColor.r * 0.337 + cColor.g * 0.663;
            else
                fAlpha = dot(cColor, HALF3(0.299, 0.587, 0.114));
        }

        return float4( cColor, fAlpha );
    }
}

#endif  // PIXEL_SHADER