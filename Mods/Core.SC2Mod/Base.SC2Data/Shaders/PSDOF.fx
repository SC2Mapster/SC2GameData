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
float		p_fDOFAmount;			// Depth of field amount.
float		p_fFocusDistance;       // Distance in focus.
float		p_fFullFocusRange;		// Range inside which everything is in focus.
float		p_fNoFocusRange;		// Range at which everything is fully blurred.
sampler2D   p_sMediumBlurMap;       // Medium blur map for depth of field.
sampler2D   p_sLargeBlurMap;        // Large blur map for depth of field.
sampler2D   p_sCoCMap;              // C0C map.
sampler2D   p_sDownscaledDepth;

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
half ComputeCOC( float depth ) {
    return /* saturate */(    p_fDOFAmount * max( 0.0f, abs( depth - p_fFocusDistance ) - p_fFullFocusRange ) / 
                        ( p_fNoFocusRange - p_fFullFocusRange ) );
}

//--------------------------------------------------------------------------------------------------
half4 Tex2DOffset( sampler2D s, half2 vUV, half2 vOffset, half2 vImageSize ) {
    // :TODO: Optimize.
    return tex2D( s, vUV + vOffset * half2( 1.0f / vImageSize.x, 1.0f / vImageSize.y ) );
}

//--------------------------------------------------------------------------------------------------
half4 GetSmallBlurSample( sampler2D s, half2 vUV, half2 vImageSize ) {
    // This is a 17 tap blur.
    // 16 taps are done here by using 4 taps with bilinear filtering = 16 taps.
    // The last tap is done by directly blending with the target buffer. 
    // Whenever small blur is present, this is done by biasing the final alpha by 16/17 
    // so that the last tap is automatically picked up during final blending.

    // Updated comment - now simply a 16-tap blur.
    half4 cSum;
    const half weight = 4.0 / 16.0f;
    cSum = 0;
    cSum += weight * Tex2DOffset( s, vUV, half2( 0.5f, -1.5f ), vImageSize );
    cSum += weight * Tex2DOffset( s, vUV, half2( -1.5f, -0.5f ), vImageSize );
    cSum += weight * Tex2DOffset( s, vUV, half2( -0.5f, 1.5f ), vImageSize );
    cSum += weight * Tex2DOffset( s, vUV, half2( 1.5f, 0.5f ), vImageSize );
    return cSum;
}

//==================================================================================================
// Circle of confusion mode.
half4 PostProcessCOC( VertexTransport vertOut ) {
    float4 vNormalDepth = SampleNormalDepth( p_sNormalDepthMap, INTERPOLANT_UV[0].xy );
    return ComputeCOC( PIXEL_DEPTH );
}

//==================================================================================================
// Depth of field mode.
half4 PostProcessDOF( VertexTransport vertOut ) {
    half2 vUV = INTERPOLANT_UV[0].xy;

    float4 vNormalDepth     = SampleNormalDepth( p_sNormalDepthMap, vUV );
    //return half4( tex2D( p_sNormalDepthMap, vUV ).a * 0.01f, tex2D( p_sNormalDepthMap, vUV ).a* 0.01f, tex2D( p_sNormalDepthMap, vUV ).a* 0.01f, 1.0f );
    half fUnblurredCOC      = ComputeCOC( PIXEL_DEPTH );
    float vDownscaledDepth  = 0;
    half fCoC;
    if ( b_iCorrectDOFForDepth ) {
        vDownscaledDepth = tex2D( p_sDownscaledDepth, vUV ).a;
        if ( vDownscaledDepth > ( vNormalDepth.a ) )
            fCoC = fUnblurredCOC;       // If object is sharp but downscaled depth is behind, then stay sharp.
        else
            //fCoC = max( tex2D( p_sLargeBlurMap, vUV ).a, fUnblurredCOC );  //saturate( 2.0f * max( tex2D( p_sLargeBlurMap, INTERPOLANT_UV[0].xy ).a, fUnblurredCOC ) - fUnblurredCOC );
            fCoC = 2.0f * max( tex2D( p_sLargeBlurMap, INTERPOLANT_UV[0].xy ).a, fUnblurredCOC ) - fUnblurredCOC;
    } else {
        fCoC = fUnblurredCOC;
    }

    const half d0 = 0.50f;
    const half d1 = 0.25f;
    const half d2 = 0.25f;
    fCoC = saturate( fCoC );

    if ( b_iDOFDebug == DOFDEBUG_SMALL )
        fCoC = d0;
    else if ( b_iDOFDebug == DOFDEBUG_MEDIUM )
        fCoC = d0 + d1;
    else if ( b_iDOFDebug == DOFDEBUG_LARGE )
        fCoC = d0 + d1 + d2;

    half3 cSharp    = tex2D( p_sSrcMap, vUV ).rgb;                                  // Unblurred source.
    half3 cSmall    = GetSmallBlurSample( p_sSrcMap, vUV, p_vSrcSize).rgb;          // Unblurred source.
    half3 cMed      = tex2D( p_sMediumBlurMap, vUV ).rgb;                           // Medium blur image - full size, blurred from unblurred source.
    half3 cLarge    = tex2D( p_sLargeBlurMap, vUV ).rgb;                            // Large blur image - 1/4 size, blurred from unblurred 1/4 size source.

    half3 cColor;
    half fAlpha = 1;
    half4 weights;
    if ( b_iDOFDotBlend ) {
        // Efficiently calculate the cross-blend weights for each sample.
        // 0 -> d0 = 0 -> small blur
        // d0 -> d0+d1 = small blur -> medium blur
        // d0+d1 -> d0+d1+d2 = medium blur -> large blur
        const half4 vLerpScale  = half4( -1 / d0, -1 / d1, -1 / d2, 1 / d2 );
        const half4 vLerpOffset = half4( 1, ( 1 - d2 ) / d1, 1 / d2, ( d2 - 1 ) / d2 );
        weights   = saturate( fCoC * vLerpScale +  vLerpOffset );
        weights.yz      = min( weights.yz, 1 - weights.xy );

        cColor      = weights.x * cSharp + weights.y * cSmall + weights.z * cMed + weights.w * cLarge;
        fAlpha      = 1;
        // fAlpha     = dot( weights.yzw, half3( 16.0f / 17.0f, 1.0f, 1.0f ) );
    } else {
        half3 cColorA;
        half3 cColorB;
        half t;
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
            cColorB = cLarge;
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
        cColor = saturate( tex2D( p_sLargeBlurMap, vUV ).a );
    else if ( b_iDOFDebug == DOFDEBUG_DOWNSCALEDDEPTH )
        cColor = vDownscaledDepth;
    else if ( b_iDOFDebug == DOFDEBUG_WEIGHTS )
        cColor = weights.yzw;
    else if ( b_iDOFDebug == DOFDEBUG_ALPHA ) {
        cColor = fAlpha;
        fAlpha = 1;
    } 
    return half4( cColor, fAlpha );
};

#endif  // PIXEL_SHADER

#endif  // PS_DOF