//==================================================================================================
//
// Copyright Blizzard Entertainment 2003-2005
//
// Shared post-processing related functions.
//==================================================================================================

#ifndef PS_POST_PROCESS
#define PS_POST_PROCESS

#ifdef PIXEL_SHADER

#include "ShaderSystem.fx"
#include "PSCommon.fx"
#include "PSHalo.fx"

// :TODO: Move this.
texDecl2D(p_sSrcMap);                   // Source texture map.
texDecl2D(p_sWeightMap);                // Weight map for blurring.
texDecl2D(p_sSeparateBlurMap);
texDecl2D(p_sOperandMap);
HALF2       p_vSrcSize;                // Source texture map size.
HALF4       p_vRecipSrcSizeOffset;

// screen space particles
texDecl2D(p_sParticleTexture);
float4      p_vParticleAmbientLight;
float       p_fParticleThreshold;
float2x4    p_mParticleTextureTransform;
float3      p_vParticleFogColor;
HALF        p_fFOWSmoothing;
float4      p_vBlurDepthCameraConstants;
float4      p_vBlurDepthRadiusConstants;

HALF        p_fHaloRadiusRcp;

float4      p_vPostProcessViewport;      // xy is top left, zw is bottom right. Used for blur and DoF

#include "PSDOF.fx"
#include "PSSSAO.fx"
#include "PSAntiAliasing.fx"

#define MODE_Copy                   0
#define MODE_SetValue               1
#define MODE_GaussianBlur           2
#define MODE_Downscale              3
#define MODE_COC                    4
#define MODE_DOF                    5
#define MODE_SSAO                   6
#define MODE_ConvertToGradient      7
#define MODE_DepthEncode            8
#define MODE_ScreenSpaceParticle    9
#define MODE_AntiAliasing           10
#define MODE_FOWSmoothing           11
#define MODE_HaloCopy               12
#define MODE_HaloPrepare            13
#define MODE_HaloBlur               14


#define CHANNEL_ALL                 0
#define CHANNEL_RED                 1
#define CHANNEL_GREEN               2
#define CHANNEL_BLUE                3
#define CHANNEL_ALPHA               4

#define PostProcessMode( x )    if ( b_iMode == MODE_##x ) cResult = PostProcess##x( vertOut );

HALF4       p_vScale;                    // Value scale.
HALF        p_fAdd;                        // Value add.

HALF4        p_vPostMaskColor;            // Color modulate after masking

//==================================================================================================
// Copy mode.
HALF4 PostProcessCopy( VertexTransport vertOut ) {
    HALF4 cResult = sample2D( p_sSrcMap, READ_INTERPOLANT_UV(0).xy );
    return cResult;
}

//==================================================================================================
// Set value mode.
float4      p_vValue;                    // Value to set.

//--------------------------------------------------------------------------------------------------
HALF4 PostProcessSetValue( VertexTransport vertOut ) {
    return p_vValue;
}

//==================================================================================================
// Downscale mode.
//--------------------------------------------------------------------------------------------------
HALF4 PostProcessDownscale( VertexTransport vertOut ) {
    // 4x4 Bilinear downscale.
    HALF4 cResult = ( sample2D( p_sSrcMap, INTERPOLANT_DownscaleUV0.xy ) + sample2D( p_sSrcMap, INTERPOLANT_DownscaleUV0.zw ) +
                      sample2D( p_sSrcMap, INTERPOLANT_DownscaleUV1.xy ) + sample2D( p_sSrcMap, INTERPOLANT_DownscaleUV1.zw ) ) * 
                      HALF4(0.25f, 0.25f, 0.25f, 0.25f);
    return cResult;
}

//==================================================================================================
// Convert to gradient mode.
HALF        p_fGradientScale;
HALF3        p_cGradientStartColor;
HALF3        p_cGradientEndColor;

//--------------------------------------------------------------------------------------------------
HALF4 PostProcessConvertToGradient( VertexTransport vertOut ) {
    return  HALF4(  lerp( p_cGradientStartColor, p_cGradientEndColor, 
                    saturate( sample2D( p_sSrcMap, READ_INTERPOLANT_UV(0).xy ).a / p_fGradientScale ) ), 1.0f );
}

//==================================================================================================
// Depth encode mode.

texDecl2D(p_sDepthEncodeRG);
texDecl2D(p_sDepthEncodeB);

//--------------------------------------------------------------------------------------------------
HALF4 PostProcessDepthEncode( VertexTransport vertOut ) {
    HALF4 vResult;
    float fDepth = saturate( sample2D( p_sSrcMap, READ_INTERPOLANT_UV(0).xy ).a / 10.0f );   // Map to [0..1]
    vResult.rg = sample2D( p_sDepthEncodeRG, float2( fDepth, fDepth * 32.0f ) ).rg;
    vResult.ba = sample2D( p_sDepthEncodeB, float2( fDepth * 2048.0f, fDepth * 2048.0f ) ).bb;
    return vResult;
}

//==================================================================================================
// Gaussian blur mode.
ArrayDecl(HALF) p_fBlurWeights[b_iSampleCount + 1];
ArrayDecl(HALF2) p_vBlurOffsets[b_iSampleCount + 1];

//--------------------------------------------------------------------------------------------------
float GaussSample( float2 vTapUV, float fWeight, inout HALF4 vResult, float4 vNormalDepth) {
    if ( b_iConstrainToViewport ) {
        vTapUV = max( vTapUV, p_vPostProcessViewport.xy );
        vTapUV = min( vTapUV, p_vPostProcessViewport.zw );
    }

    HALF4 cValue;
    if ( b_iUseSeparateBlurMap )
        cValue = sample2D( p_sSeparateBlurMap, vTapUV );
    else cValue = sample2D( p_sSrcMap, vTapUV );
    
    if ( b_iInteriorBlur ) {
        float4 vSampleNormalDepth = SampleNormalDepth(  texSampler(p_sNormalDepthMap), texTexture(p_sNormalDepthMap), vTapUV );
        if ( dot( vSampleNormalDepth.rgb, PIXEL_NORMAL ) < 0.9f || abs( vSampleNormalDepth.a - PIXEL_DEPTH ) > ((b_iInEncoding == DEPTH_NORMAL_ENCODING_FLOAT) ? 0.01f : 0.1f) )
            fWeight = 0.0f;
    }
    if ( b_iWeightedBlur )
        fWeight *= sample2D( p_sWeightMap, vTapUV ).a;
    if ( b_iLayeredBlur ) {
        float vDepth = SampleNormalDepth( texSampler(p_sNormalDepthMap), texTexture(p_sNormalDepthMap), vTapUV ).a;
        if ( PIXEL_DEPTH < vDepth )
            fWeight = 0.0f;
    }
    
    vResult += cValue * fWeight;
    return fWeight;
}

//--------------------------------------------------------------------------------------------------
HALF4 PostProcessGaussianBlur( VertexTransport vertOut ) {
#if ( b_iMode == MODE_GaussianBlur || CPP_SHADER )    // Need an ifdef because INTERPOLANT_GaussianBlurSample may not be present
    HALF2 vCenterTap    = READ_INTERPOLANT_UV(0).xy;
    HALF4 cValue        = sample2D( p_sSrcMap, vCenterTap.xy );
    HALF4 cResult       = cValue * floatRef(p_fBlurWeights[0]);
    float fTotalWeight  = floatRef(p_fBlurWeights[0]);
    
    float4 vNormalDepth = 0;
    if ( b_iInteriorBlur )
        vNormalDepth = SampleNormalDepth( texSampler(p_sNormalDepthMap), texTexture(p_sNormalDepthMap), vCenterTap.xy );
    else {
        vNormalDepth.a = SampleNormalDepth( texSampler(p_sNormalDepthMap), texTexture(p_sNormalDepthMap), vCenterTap.xy ).a;
        // :TODO: SSAO might need this.
        if ( b_iLayeredBlur && b_iInEncoding != DEPTH_NORMAL_ENCODING_FLOAT )
            vNormalDepth.a +=  0.01f;   // Add some slack for layered blur.
    }

    float depthScale = 1.f;
    if( b_iDepthScaledBlur ) {
        float depth = sample2D( p_sWeightMap, vCenterTap.xy ).r;
        float2 s = vCenterTap.xy * 2.f - 1.f;

        // Do some back transformation to find the original depth from the plane.
        float x0 = s.x * p_vBlurDepthCameraConstants.x;
        float z0 = s.y * p_vBlurDepthCameraConstants.y;
        float w = x0 + z0 + p_vBlurDepthCameraConstants.z - depth;

        if( w <= 0.f ) {
            // Depth is infinite.
            depthScale = 1.f;
        } else {
            // Use depth to scale the size of the blur circle.
            float invW = 1.f / w;
            float z0 = depth * w;
            float blurRadius = z0 * p_vBlurDepthRadiusConstants.z; // in view space units

            // convert blur radius to post projection space units
            depthScale = saturate( abs( blurRadius * ( p_vBlurOffsets[1].x == 0 ? p_vBlurDepthRadiusConstants.y : p_vBlurDepthRadiusConstants.x ) * invW ) );
        }
    }

    if ( b_iSampleCountPS ) {
        // Sample offsets stored in uniforms
#if __bsl__
        // Inspector Bug ID: 186629
        [unroll]
#endif
        for ( int i = 1; i <= b_iSampleCount; i++ ) {
            if( b_iShowSingleTap >= b_iSampleCount*2 || (b_iShowSingleTap%b_iSampleCount) == i-1 ) {
                if( b_iDepthScaledBlur )
                    fTotalWeight += GaussSample(vCenterTap + depthScale * float2Ref(p_vBlurOffsets[i]),floatRef(p_fBlurWeights[i]),cResult,vNormalDepth);
                else 
                    fTotalWeight += GaussSample(vCenterTap + float2Ref(p_vBlurOffsets[i]),floatRef(p_fBlurWeights[i]),cResult,vNormalDepth);
            }
        }
    } else {
        // Sample positions stored in interpolants
#if __bsl__
        // Inspector Bug ID: 186629
        [unroll]
#endif
        for ( int i = 0; i < b_iSampleInterpolantCount; i++ ) {
            if( b_iShowSingleTap >= b_iSampleCount*2 || (b_iShowSingleTap%b_iSampleCount) == i*2 )
                fTotalWeight += GaussSample(READ_INTERPOLANT_GaussianBlurSample(i).xy,floatRef(p_fBlurWeights[i * 2 + 1]),cResult,vNormalDepth);

            if( b_iShowSingleTap >= b_iSampleCount*2 || (b_iShowSingleTap%b_iSampleCount) == i*2+1 ) 
                fTotalWeight += GaussSample(READ_INTERPOLANT_GaussianBlurSample(i).zw,floatRef(p_fBlurWeights[i * 2 + 2]),cResult,vNormalDepth);
        }
    }
    
    if ( b_iInteriorBlur || b_iWeightedBlur || b_iLayeredBlur )
        cResult *= 1.0f / fTotalWeight;

    if( !b_iBlurAllChannels ) {
        if ( b_iBlurAlphaOnly )
            cResult.rgb = 0;         // Discard color.
        else
            cResult.a = cValue.a;    // Use original alpha.
    }

    if( b_iDepthScaledBlur ) {
        cResult.rgb = lerp( cValue.rgb, cResult.rgb, cValue.a );
        cResult.a = cValue.a;
    }

    return cResult;
#else
    return 0;
#endif
}

//--------------------------------------------------------------------------------------------------
float4 PostProcessScreenSpaceParticle (VertexTransport vertOut) {
    float4 vResult;

    vResult = sample2D(p_sSrcMap, READ_INTERPOLANT_UV(0).xy);

    // only for standard screen space particles
    float fogDensity = 0;
    //float fogDensity = vResult.r;

    // use a screen space texture instead
    float4 vParticleTexture = 0;
    if (b_iParticleScreenTexture) {
        float2 vUv = mul(p_mParticleTextureTransform, float4( READ_INTERPOLANT_UV(0).x, READ_INTERPOLANT_UV(0).y, 0.0f, 1.0f ) );
        vParticleTexture = sample2D(p_sParticleTexture, vUv.xy);
    }

    vResult.xyz = vResult.xyz*p_vParticleAmbientLight.xyz + vResult.xyz;

    // screen space textured particles need to get fog density from the frame buffer red channel
    if (b_iParticleScreenTexture) {
        vResult.xyz = lerp(vParticleTexture.xyz, p_vParticleFogColor.xyz, fogDensity);
    }

    vResult.a = step(p_fParticleThreshold, vResult.a);
    return vResult;
}

//--------------------------------------------------------------------------------------------------
HALF4 PostProcessFOWSmoothing( VertexTransport vertOut ) {
    HALF4 vResult;
    vResult  = 2 * sample2D(p_sSrcMap, READ_INTERPOLANT_UV(0).xy);
    vResult += sample2D(p_sSrcMap, READ_INTERPOLANT_UV(0).xy + HALF2(0, -p_fFOWSmoothing / p_vSrcSize.y));
    vResult += sample2D(p_sSrcMap, READ_INTERPOLANT_UV(0).xy + HALF2(0,  p_fFOWSmoothing / p_vSrcSize.y));
    vResult += sample2D(p_sSrcMap, READ_INTERPOLANT_UV(0).xy + HALF2(-p_fFOWSmoothing / p_vSrcSize.x, 0));
    vResult += sample2D(p_sSrcMap, READ_INTERPOLANT_UV(0).xy + HALF2( p_fFOWSmoothing / p_vSrcSize.x, 0));
    vResult /= 6.0f;
    if ( b_PostProcessFastFOW )
        vResult.a = dot(saturate(2.0f * vResult.rgb), HALF3(0.375f, 0.3125f, 0.3125f));
    return vResult;
}

//==================================================================================================
// Halo copy mode
HALF3   p_vStrobeParams;
HALF4   p_cHaloColor;

//--------------------------------------------------------------------------------------------------
HALF4 PostProcessHaloCopy( VertexTransport vertOut ) {
    float2 vUV = READ_INTERPOLANT_UV(0).xy;
    HALF4 cResult = sample2D( p_sSrcMap, vUV );
#ifdef COMPILING_SHADER_FOR_OPENGL
    return GetHaloColor(vUV, p_cHaloColor, p_vStrobeParams.x, p_vStrobeParams.y, p_vStrobeParams.z) * ((cResult.a > 0.01) ? 1.0 : 0.0);
#else
    return GetHaloColor(vUV, p_cHaloColor, p_vStrobeParams.x, p_vStrobeParams.y, p_vStrobeParams.z) * ((cResult.a > 0) ? 1.0 : 0.0);
#endif
}

//==================================================================================================
// Halo Prepare

#define HALO_RADIUS_MULTIPLIER  32.0

HALF4 HaloSample (HALF2 vUV) {
    if ( b_iConstrainToViewport ) {
        vUV = max( vUV, p_vPostProcessViewport.xy );
        vUV = min( vUV, p_vPostProcessViewport.zw );
    }
    return sample2D(p_sSrcMap, vUV);
}

void HaloPrepareSingle (in HALF4 cInput, in HALF fOffset, inout HALF4 cResult) {

    if (b_iBlurAllChannels) {
        HALF testValue = (1.0 - cInput.a) + fOffset;
        if (testValue < cResult.a) {
            cResult.a = testValue;
            cResult.rgb = cInput.rgb;
        }
    }
    else {
        HALF testValue = (1.0 - cInput.r) + fOffset;
        cResult.r = min(cResult.r, testValue);
    }
}

HALF4 PostProcessHaloPrepare( VertexTransport vertOut ) {
    HALF2 vUV = READ_INTERPOLANT_UV(0).xy;
    HALF4 cResult = sample2D( p_sSrcMap, vUV );

    if (b_iBlurAllChannels)
        cResult.a = (1.0 - cResult.a);
    else
        cResult.r = (1.0 - cResult.r);

    HALF texOffset = p_vRecipSrcSizeOffset.y;
    HALF radius = 1.0 / HALO_RADIUS_MULTIPLIER;
    for (int i = 1; i < b_iTapCount; i++) {
        HALF4 input = HaloSample(vUV + HALF2(0, texOffset));
        HaloPrepareSingle(input, radius, cResult);

        input = HaloSample(vUV - HALF2(0, texOffset));
        HaloPrepareSingle(input, radius, cResult);

        texOffset += p_vRecipSrcSizeOffset.y;
        radius += 1.0 / HALO_RADIUS_MULTIPLIER;
    }

    return cResult;
}

//==================================================================================================
// Halo Blur

#define HALOBLUR_GAUSSIAN   0
#define HALOBLUR_LINEAR     1
#define HALOBLUR_QUADRATIC  2
#define HALOBLUR_SHARP      3

#define HALO_ADD            0
#define HALO_MUL            1
#define HALO_ALPHA          2

void HaloBlurSingle (in HALF4 cInput, in HALF fDimSq, inout HALF fMinSq, inout HALF4 cResult) {
    HALF testSq, test; 
    
    test = (b_iBlurAllChannels) ? cInput.a : cInput.r;
    test *= HALO_RADIUS_MULTIPLIER;
    testSq = test * test + fDimSq;

    if (testSq < fMinSq) {
        fMinSq = testSq;
        if (b_iBlurAllChannels)
            cResult.rgb = cInput.rgb;
        else
            cResult.r = cInput.r;
    }
}

HALF4 PostProcessHaloBlur( VertexTransport vertOut ) {
    HALF2 vUV = READ_INTERPOLANT_UV(0).xy;
    HALF4 cResult = sample2D( p_sSrcMap, vUV );
    HALF minSq = (b_iBlurAllChannels) ? cResult.a : cResult.r;
    minSq = minSq * minSq * HALO_RADIUS_MULTIPLIER * HALO_RADIUS_MULTIPLIER;

    // If we're inside the blurred object, don't write anything
    clip(minSq - 0.001);
    
    HALF offset = p_vRecipSrcSizeOffset.x;
    for (int i = 1; i < b_iTapCount; i++) {
        HALF valSq = i * i;

        HALF4 testValue = HaloSample(vUV + HALF2(offset, 0));
        HaloBlurSingle(testValue, valSq, minSq, cResult);

        testValue = HaloSample(vUV - HALF2(offset, 0));
        HaloBlurSingle(testValue, valSq, minSq, cResult);

        offset += p_vRecipSrcSizeOffset.x;
    }

    // If we're outside of max radius, don't write
    clip(b_iTapCount * b_iTapCount - minSq);

    // Use halo mode to determine strength
    HALF strength;
    if (b_iHaloBlurMode == HALOBLUR_GAUSSIAN) {
        float weight = exp(-minSq * p_fHaloRadiusRcp);
        strength = max(weight, 0.0);
    }
    else if (b_iHaloBlurMode == HALOBLUR_LINEAR) {
        strength = max(1.0 - (sqrt(minSq) * p_fHaloRadiusRcp), 0.0);
    }
    else if (b_iHaloBlurMode == HALOBLUR_QUADRATIC) {
        strength = max(1.0 - (minSq * p_fHaloRadiusRcp), 0.0);
    }
    else if (b_iHaloBlurMode == HALOBLUR_SHARP) {
        strength = max(1.0 - (minSq * minSq * minSq * minSq * p_fHaloRadiusRcp), 0.0);
    }

    if (b_iBlurAllChannels) {
        cResult.a = strength;
    }
    else {
        cResult = HALF4(strength, strength, strength, strength);
    }
    return cResult;
}

//==================================================================================================
// Main post-processing entry point.
HALF4 PostProcess( VertexTransport vertOut ) {
    HALF4 cResult;
    PostProcessMode( Copy );
    PostProcessMode( SetValue );
    PostProcessMode( GaussianBlur );
    PostProcessMode( Downscale );
    PostProcessMode( COC );
    PostProcessMode( DOF );
    PostProcessMode( SSAO );
    PostProcessMode( ConvertToGradient );
    PostProcessMode( DepthEncode );
    PostProcessMode( ScreenSpaceParticle );
    PostProcessMode( AntiAliasing );
    PostProcessMode( FOWSmoothing );
    PostProcessMode( HaloCopy );
    PostProcessMode( HaloPrepare );
    PostProcessMode( HaloBlur );

    if ( b_iTakeMin ) {
        HALF4 cOperand = sample2D( p_sOperandMap, READ_INTERPOLANT_UV(0).xy );
        cResult = min( cOperand, cResult );
    }

    if ( b_iInputChannelFilter == CHANNEL_RED )
        cResult = cResult.r;
    else if ( b_iInputChannelFilter == CHANNEL_GREEN )
        cResult = cResult.g;
    else if ( b_iInputChannelFilter == CHANNEL_BLUE )
        cResult = cResult.b;
    else if ( b_iInputChannelFilter == CHANNEL_ALPHA )
        cResult = cResult.a;

    if (b_iHaloRastermode == HALO_ALPHA && b_iInputChannelFilter != CHANNEL_ALL) {
        cResult.rgb = HALF3(1.0, 1.0, 1.0);
    }

    if ( b_iScaleOutput )
        cResult *= p_vScale;
    if ( b_iAddToOutput )
        cResult += p_fAdd;
    if ( b_iOutputChannelFilter == CHANNEL_RED )
        cResult = cResult.r;
    else if ( b_iOutputChannelFilter == CHANNEL_GREEN )
        cResult = cResult.g;
    else if ( b_iOutputChannelFilter == CHANNEL_BLUE )
        cResult = cResult.b;
    else if ( b_iOutputChannelFilter == CHANNEL_ALPHA )
        cResult = cResult.a;
    if ( b_iClampNegativeOutput )
        cResult = max( HALF4(0.0f, 0.0f, 0.0f, 0.0f), cResult );
        
    if ( b_iPostMaskModulate )
        cResult *= p_vPostMaskColor;

    if (b_iHaloRastermode == HALO_MUL) {
        cResult = lerp(HALF4(1.0, 1.0, 1.0, 1.0), cResult, cResult.a);
    }

    if (b_iAlphaTest)
    {
        clip(cResult.a - p_fAlphaThreshold);
    }

    return cResult;
}

#endif  // PIXEL_SHADER

#endif  // PS_POST_PROCESS
