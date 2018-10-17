//==================================================================================================
//
// Copyright Blizzard Entertainment 2003-2005
//
// Depth of field post-processing.
//==================================================================================================

#ifndef PS_DOF
#define PS_DOF

#include "ShaderSystem.fx"

#ifdef PIXEL_SHADER

// Depth of field.
float		p_fFocusDistance;       // Distance in focus.
float4      p_vCoCWindow;
float       p_fCorrectDepthDOFBias; // Bias to prevent self-testing when doing depth DOF correction.
float3      p_vBlurRamp;
texDecl2D(p_sMediumBlurMap);        // Medium blur map for depth of field.
texDecl2D(p_sLargeBlurMap);         // Large blur map for depth of field.
texDecl2D(p_sCoCMap);               // C0C map.
texDecl2D(p_sDownscaledDepth);

#define DOFDEBUG_NODOF              1
#define DOFDEBUG_SMALL              2
#define DOFDEBUG_MEDIUM             3
#define DOFDEBUG_LARGE              4
#define DOFDEBUG_COC                5
#define DOFDEBUG_UNBLURREDCOC       6
#define DOFDEBUG_BLURREDCOC         7
#define DOFDEBUG_DOWNSCALEDDEPTH    8
#define DOFDEBUG_WEIGHTS            9
#define DOFDEBUG_ALPHA              10

//--------------------------------------------------------------------------------------------------
HALF ComputeCOC( float depth ) {
    return max(0.0f, max((depth - p_fFocusDistance) * p_vCoCWindow.x + p_vCoCWindow.y, (p_fFocusDistance - depth) * p_vCoCWindow.z + p_vCoCWindow.w));
}

//--------------------------------------------------------------------------------------------------
HALF4 Tex2DOffset( typeSampler2D s, typeTexture2D t, HALF2 vUV, HALF2 vOffset, HALF2 vImageSize ) {
    // :TODO: Optimize.
    HALF2 vUVFinal = vUV + vOffset * HALF2( 1.0f / vImageSize.x, 1.0f / vImageSize.y );
    if (b_iConstrainToViewport)
        vUVFinal = clamp( vUVFinal, p_vPostProcessViewport.xy, p_vPostProcessViewport.zw );
    return sampleTex2D( t, s, vUVFinal );
}

//--------------------------------------------------------------------------------------------------
HALF4 GetSmallBlurSample( typeSampler2D s, typeTexture2D t, HALF2 vUV, HALF2 vImageSize ) {
    // This is a 17 tap blur.
    // 16 taps are done here by using 4 taps with bilinear filtering = 16 taps.
    // The last tap is done by directly blending with the target buffer. 
    // Whenever small blur is present, this is done by biasing the final alpha by 16/17 
    // so that the last tap is automatically picked up during final blending.

    // Updated comment - now simply a 16-tap blur.
    HALF4 cSum;
    const HALF weight = 4.0 / 16.0f;
    cSum = 0;
    cSum += weight * Tex2DOffset( s, t, vUV, HALF2( 0.5f, -1.5f ), vImageSize );
    cSum += weight * Tex2DOffset( s, t, vUV, HALF2( -1.5f, -0.5f ), vImageSize );
    cSum += weight * Tex2DOffset( s, t, vUV, HALF2( -0.5f, 1.5f ), vImageSize );
    cSum += weight * Tex2DOffset( s, t, vUV, HALF2( 1.5f, 0.5f ), vImageSize );
    return cSum;
}

//==================================================================================================
// Circle of confusion mode.
HALF4 PostProcessCOC( VertexTransport vertOut ) {
    float4 vNormalDepth = SampleNormalDepth( texSampler(p_sNormalDepthMap), texTexture(p_sNormalDepthMap), READ_INTERPOLANT_UV(0).xy );
    return ComputeCOC( PIXEL_DEPTH );
}

//==================================================================================================
// Depth of field mode.
HALF4 PostProcessDOF( VertexTransport vertOut ) {
    HALF2 vUV = READ_INTERPOLANT_UV(0).xy;

    float4 vNormalDepth     = SampleNormalDepth( texSampler(p_sNormalDepthMap), texTexture(p_sNormalDepthMap), vUV );
    HALF4 cLarge            = sample2D( p_sLargeBlurMap, vUV );                            // Large blur image - 1/4 size, blurred from unblurred 1/4 size source.
    HALF fUnblurredCOC      = ComputeCOC( PIXEL_DEPTH );
    float vDownscaledDepth  = 0;
    HALF fCoC;
    if ( b_iCorrectDOFForDepth ) {
        vDownscaledDepth = SampleNormalDepth( texSampler(p_sDownscaledDepth), texTexture(p_sDownscaledDepth), vUV ).a + p_fCorrectDepthDOFBias;
        if ( vDownscaledDepth > vNormalDepth.a )
            fCoC = fUnblurredCOC;       // If object is sharp but downscaled depth is behind, then stay sharp.
        else
            //fCoC = max( tex2D( p_sLargeBlurMap, vUV ).a, fUnblurredCOC );  //saturate( 2.0f * max( tex2D( p_sLargeBlurMap, READ_INTERPOLANT_UV(0).xy ).a, fUnblurredCOC ) - fUnblurredCOC );
            fCoC = 2.0f * max( cLarge.a, fUnblurredCOC ) - fUnblurredCOC;
    } else {
        fCoC = fUnblurredCOC;
    }

    const HALF d0 = p_vBlurRamp.x;
    const HALF d1 = p_vBlurRamp.y;
    const HALF d2 = p_vBlurRamp.z;
    fCoC = saturate( fCoC );

    if ( b_iDOFDebug == DOFDEBUG_SMALL )
        fCoC = d0;
    else if ( b_iDOFDebug == DOFDEBUG_MEDIUM )
        fCoC = d0 + d1;
    else if ( b_iDOFDebug == DOFDEBUG_LARGE )
        fCoC = d0 + d1 + d2;

    HALF3 cSharp    = sample2D( p_sSrcMap, vUV ).rgb;                                  // Unblurred source.
    HALF3 cSmall    = GetSmallBlurSample( texSampler(p_sSrcMap), texTexture(p_sSrcMap), vUV, p_vSrcSize).rgb;          // Unblurred source.
    HALF3 cMed      = sample2D( p_sMediumBlurMap, vUV ).rgb;                           // Medium blur image - full size, blurred from unblurred source.

    HALF3 cColor;
    HALF fAlpha = 1;
    HALF4 weights;
    if ( b_iDOFDotBlend ) {
        // Efficiently calculate the cross-blend weights for each sample.
        // 0 -> d0 = 0 -> small blur
        // d0 -> d0+d1 = small blur -> medium blur
        // d0+d1 -> d0+d1+d2 = medium blur -> large blur
        const HALF4 vLerpScale  = HALF4( -1 / d0, -1 / d1, -1 / d2, 1 / d2 );
        const HALF4 vLerpOffset = HALF4( 1, ( 1 - d2 ) / d1, 1 / d2, ( d2 - 1 ) / d2 );
        weights   = saturate( fCoC * vLerpScale +  vLerpOffset );
        weights.yz      = min( weights.yz, 1 - weights.xy );

        cColor      = weights.x * cSharp + weights.y * cSmall + weights.z * cMed + weights.w * cLarge.rgb;
        fAlpha      = 1;
        // fAlpha     = dot( weights.yzw, HALF3( 16.0f / 17.0f, 1.0f, 1.0f ) );
    } else {
        HALF3 cColorA;
        HALF3 cColorB;
        HALF t;
        weights = 0;
        if ( fCoC <= d0) {
            t = fCoC / d0;
            cColorA = cSharp;
            cColorB = cSmall;
            weights = lerp( float4( 0.0f, 0.0f, 0.0f, 0.0f ), float4( 0.0f, 1.0f, 0.0f, 0.0f ), t );
        }
        else if ( fCoC <= ( d1 + d0 ) ) {
            t = (fCoC - d0) / d1;
            cColorA = cSmall;
            cColorB = cMed;
            weights = lerp( float4( 0.0f, 1.0f, 0.0f, 0.0f ), float4( 0.0f, 0.0f, 1.0f, 0.0f ), t );
        }
        else {
            t = ( fCoC - d0 - d1) / d2;
            cColorA = cMed;
            cColorB = cLarge.rgb;
            weights = lerp( float4( 0.0f, 0.0f, 1.0f, 0.0f ), float4( 0.0f, 0.0f, 0.0f, 1.0f ), t );
        }

        cColor = lerp( cColorA, cColorB, t).rgb;
        fAlpha = 1;
    }
    
    if ( b_iDOFDebug > DOFDEBUG_LARGE && b_iDOFDebug != DOFDEBUG_ALPHA )
        fAlpha = 1;
    if ( b_iDOFDebug == DOFDEBUG_NODOF )
        fAlpha = 0;
    else if ( b_iDOFDebug == DOFDEBUG_COC )
        cColor = saturate( fCoC );
    else if ( b_iDOFDebug == DOFDEBUG_UNBLURREDCOC )
        cColor = saturate( fUnblurredCOC );
    else if ( b_iDOFDebug == DOFDEBUG_BLURREDCOC )
        cColor = saturate( sample2D( p_sLargeBlurMap, vUV ).a );
    else if ( b_iDOFDebug == DOFDEBUG_DOWNSCALEDDEPTH )
        cColor = vDownscaledDepth;
    else if ( b_iDOFDebug == DOFDEBUG_WEIGHTS )
        cColor = weights.yzw;
    else if ( b_iDOFDebug == DOFDEBUG_ALPHA ) {
        cColor = fAlpha;
        fAlpha = 1;
    } 
    return HALF4( cColor, fAlpha );
};

#endif  // PIXEL_SHADER

#endif  // PS_DOF