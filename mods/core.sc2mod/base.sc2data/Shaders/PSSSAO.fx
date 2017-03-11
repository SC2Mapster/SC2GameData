//==================================================================================================
//
// Copyright Blizzard Entertainment 2003-2005
//
// Screen space ambient occlusion.
//==================================================================================================

#ifndef PS_SSAO
#define PS_SSAO

#include "ShaderSystem.fx"

#ifdef PIXEL_SHADER

#include "PSCommon.fx"
#include "PSUtils.fx"

float p_fSampleRadius;
float3 p_vSSAOSamplePoints[64];
float2 p_vCameraSize;            // :TODO: This is redundant
HALF p_fOcclusionRadius;
HALF p_fOcclusionPower;                      // 3.0f
HALF p_fDetailOcclusionRadius;               // 0.02f
HALF p_fDetailOcclusionPower;                // 16.0f

HALF p_fFullOcclusionThreshold;
HALF p_fNoOcclusionThreshold;
HALF p_fDetailFullOcclusionThreshold;        // 0.0
HALF p_fDetailNoOcclusionThreshold;          // 0.15 * 0.2
HALF p_fSSAOLimiter;

texDecl2D(p_sBlockerFunc);
texDecl2D(p_sDetailBlockerFunc);
texDecl2D(p_sEncodedDepth);
texDecl2D(p_sSSAONoise);
texDecl2D(p_sStaticAO);

HALF2 p_vSSAOTermA;

#define OPTIMIZE_SSAO

#define SSAO_OUTPUT_MIN     0
#define SSAO_OUTPUT_STATIC  1
#define SSAO_OUTPUT_DYNAMIC 2

//--------------------------------------------------------------------------------------------------
half3x3 MakeRotation( HALF fAngle, HALF3 vAxis ) {
    HALF fS;
    HALF fC;
    sincos( fAngle, fS, fC );
    HALF fXX       = vAxis.x * vAxis.x;
    HALF fYY       = vAxis.y * vAxis.y;
    HALF fZZ       = vAxis.z * vAxis.z;
    HALF fXY       = vAxis.x * vAxis.y;
    HALF fYZ       = vAxis.y * vAxis.z;
    HALF fZX       = vAxis.z * vAxis.x;
    HALF fXS       = vAxis.x * fS;
    HALF fYS       = vAxis.y * fS;
    HALF fZS       = vAxis.z * fS;
	HALF fOneC      = 1.0f - fC;
    
    half3x3 result = half3x3(       fOneC * fXX +  fC, fOneC * fXY + fZS, fOneC * fZX - fYS,
                                    fOneC * fXY - fZS, fOneC * fYY +  fC, fOneC * fYZ + fXS,
                                    fOneC * fZX + fYS, fOneC * fYZ - fXS, fOneC * fZZ +  fC
    );
    return result;
}

float3 reflect( float3 vSample, float3 vNormal ) {
    return normalize( vSample - 2.0f * dot( vSample, vNormal ) * vNormal );
}

bool TestOcclusion( float3 vViewPos, float3 vSamplePointDelta, float3 vNormal, out float fBlock,
                    float fOcclusionRadius, typeSampler2D sBlockerFunc, typeTexture2D tBlockerFunc, HALF2 fSampleRecip,
                    float fFullOcclusionThreshold, float fNoOcclusionThreshold, float2 SSAOCenterUV, float SSAOLength ) {
    if ( dot( vSamplePointDelta, vNormal.xzy ) < 0 )
        vSamplePointDelta = -vSamplePointDelta;
    
    float3 vSamplePoint     = vViewPos + fOcclusionRadius * vSamplePointDelta;
    float2 vSamplePointUV;
    if ( b_iSSAOOptimizedSampleDelta )
        // This one sacrifices some contrast
        // SSAO term A = reciprocal of HALF camera size times ( 0.5f, -0.5f )
        // SSAO term B = ( 1.0f, -1.0f ) * ( 0.5f, -0.5f ) = ( 0.5f, 0.5f )
        vSamplePointUV = ( p_vSSAOTermA / vSamplePoint.z ) * vSamplePoint.xy + HALF2( 0.5f, 0.5f );
    else {
        vSamplePointUV = vSamplePoint.xy / vSamplePoint.z;
        vSamplePointUV = vSamplePointUV / p_vCameraSize / 0.5f;
        vSamplePointUV = vSamplePointUV + float2( 1.0f, -1.0f );
        vSamplePointUV = vSamplePointUV / float2( 2.0f, -2.0f );
    }
    
#if !CPP_SHADER  // If we return during the CPP shader simulation then we don't mark any of the static branches below as valid. This is bad!
//#ifndef OPTIMIZE_SSAO
    // :TODO: Need to use a border color with very large depth.
    // Removed this and using clamp now.
    if (    vSamplePointUV.x < 0.0f || vSamplePointUV.y < 0.0f ||
            vSamplePointUV.x > 1.0f || vSamplePointUV.y > 1.0f ) 
    {   
        fBlock = 0.0f;
        return true;
    }
#endif

    SSAOLength += length( vSamplePointUV - SSAOCenterUV );

    // PIXEL_DEPTH?
    float fSampleDepth;
    if ( b_iSSAOEncodedDepth )
        fSampleDepth = DecodeDepth( sample2D( p_sEncodedDepth, vSamplePointUV ) ); 
    else fSampleDepth = sample2D( p_sEncodedDepth, vSamplePointUV ).r; 

    float fDistance = vSamplePoint.z - fSampleDepth; 

    if ( b_iSSAOBlockerLookup )
        // Clip it so so there is no occlusion if sampled depth is behind the sample point's z.
        fBlock = sampleTex2D( tBlockerFunc, sBlockerFunc, fDistance ).r; 
    else {
        if ( fDistance > 0.01f ) {
            // Past this distance there is no occlusion.
            HALF fNoOcclusionRange = fNoOcclusionThreshold - fFullOcclusionThreshold;  
            if ( fDistance < fFullOcclusionThreshold )
                fBlock = 1.0f;
            else fBlock = max( 1.0f - ( ( fDistance - fFullOcclusionThreshold ) / fNoOcclusionRange ), 0.0f );
        } else fBlock = 0.0f;
    }

    return true;
}

HALF4 PostProcessSSAO( VertexTransport vertOut ) {
    float2 SSAOCenterUV;
    float SSAOLength;

#if ( VPOS_SEMANTIC )
    float2 vViewSpaceUV = INTERPOLANT_ScreenPos.xy * p_vRecipSrcSizeOffset.xy ;
#else
    float2 vViewSpaceUV = (INTERPOLANT_HPosAsUV.xy / INTERPOLANT_HPosAsUV.w) * float2( 0.5f, -0.5f ) + 0.5f;
#endif
    float2 vScreenUV    = vViewSpaceUV + p_vRecipSrcSizeOffset.zw;
    float4 vNormalDepth = SampleNormalDepth( texSampler(p_sNormalDepthMap), texTexture(p_sNormalDepthMap), vScreenUV );

    SSAOLength = 0.0f;
    
    float3 vNormal = normalize( mul( (float3x3)p_mViewTransform, PIXEL_NORMAL ) );       // In camera space
    //float3 vNormal = mul( (float3x3)p_mViewTransform, PIXEL_NORMAL );       // In camera space

    vViewSpaceUV = vViewSpaceUV * float2( 2.0f, -2.0f );  // From 0..1 to to 0..2
    vViewSpaceUV = vViewSpaceUV + float2( -1.0f, 1.0f );  // From 0..2 to -1..1
    vViewSpaceUV = vViewSpaceUV * p_vCameraSize * 0.5f;

    SSAOCenterUV = vScreenUV;

    float3 vViewPos;
    if ( b_iSSAOEncodedDepth )
        vViewPos = float3( vViewSpaceUV.x, vViewSpaceUV.y, 1.0f ) * DecodeDepth( sample2D( p_sEncodedDepth, vScreenUV ) );
    else vViewPos = float3( vViewSpaceUV.x, vViewSpaceUV.y, 1.0f ) * sample2D( p_sEncodedDepth, vScreenUV ).r; //  PIXEL_DEPTH?

    HALF2 fSampleRecip = p_vSSAOTermA / vViewPos.z;   // Reuse this for all samples instead of a pespective divide - the error should be small.

    HALF fAdjustedOcclusionRadius = p_fOcclusionRadius * 0.15f;
    HALF fAdjustedDetailOcclusionRadius = p_fDetailOcclusionRadius * 0.15f;
    HALF fScreenOcclusionRadius = fAdjustedOcclusionRadius / vViewPos.z;
    if ( fScreenOcclusionRadius > p_fSSAOLimiter ) {
        fAdjustedOcclusionRadius = fAdjustedOcclusionRadius * p_fSSAOLimiter / fScreenOcclusionRadius;
    }

    /*
    fScreenOcclusionRadius = fAdjustedDetailOcclusionRadius / vViewPos.z;
    if ( fScreenOcclusionRadius > p_fSSAOLimiter ) {
        fAdjustedDetailOcclusionRadius = fAdjustedDetailOcclusionRadius * p_fSSAOLimiter * 0.1f / fScreenOcclusionRadius;
    }
    */

    float3 vRandomNormal = ( normalize( sample2D( p_sSSAONoise, vScreenUV *  p_vSrcSize / 256.0f ).xyz * 2.0f - 1.0f ) );
    //float3 vRandomNormal = tex2D( p_sSSAONoise, vScreenUV * p_vSrcSize / 32.0f ).xyz * 2.0f - 1.0f;
    
    //float3x3 mBasis;
    //mBasis[0] = cross( HALF3( 0.0f, 0.0f, 1.0f ), vNormal.xzy );
    //mBasis[1] = cross( mBasis[0], vNormal.xzy );
    //mBasis[2] = vNormal.xzy;

    int iSampleCount;
    if ( b_iUseSeparateDetailSSAO ) 
        iSampleCount = b_iSSAOSampleCount * 3 / 4;
    else iSampleCount = b_iSSAOSampleCount;

    HALF fAccumBlock = 0.0f;
    int iSamples = 0;
    for ( int i = 0; i < iSampleCount; i++ ) {
        //float3 vSamplePointDelta = normalize( mul( p_vSSAOSamplePoints[i], mBasis ) ); //normalize( mul( mBasis,  ) );
        float3 vSamplePointDelta = reflect( p_vSSAOSamplePoints[i], vRandomNormal );
        float fBlock;
        if ( TestOcclusion( vViewPos, vSamplePointDelta, vNormal, fBlock, fAdjustedOcclusionRadius, texSampler(p_sBlockerFunc), texTexture(p_sBlockerFunc), fSampleRecip,
                            p_fFullOcclusionThreshold, p_fNoOcclusionThreshold, SSAOCenterUV, SSAOLength ) ) {
            fAccumBlock += fBlock;
            iSamples++;
        }
    }
    fAccumBlock /= iSamples;
    HALF fOcclusion = 1.0f - fAccumBlock;
    fOcclusion = pow( fOcclusion, p_fOcclusionPower );

    HALF fResult;
    if ( b_iUseSeparateDetailSSAO ) {
        fAccumBlock = 0.0f;
        iSamples = 0;
        for ( int i = b_iSSAOSampleCount * 3 / 4; i < b_iSSAOSampleCount; i++ ) {
            //float3 vSamplePointDelta = normalize( mul( p_vSSAOSamplePoints[i], mBasis ) ); //normalize( mul( mBasis, p_vSSAOSamplePoints[i] ) );
            float3 vSamplePointDelta = reflect( p_vSSAOSamplePoints[i], vRandomNormal );
            float fBlock;
            if ( TestOcclusion(     vViewPos, vSamplePointDelta, vNormal, fBlock, fAdjustedDetailOcclusionRadius, texSampler(p_sDetailBlockerFunc), texTexture(p_sDetailBlockerFunc), fSampleRecip, 
                                    p_fDetailFullOcclusionThreshold, p_fDetailNoOcclusionThreshold, SSAOCenterUV, SSAOLength ) ) {
                fAccumBlock += fBlock;
                iSamples++;
            }
        }
        fAccumBlock /= iSamples;
        HALF fOcclusion2 = 1.0f - fAccumBlock;
        fOcclusion2 = pow( fOcclusion2, p_fDetailOcclusionPower );


        SSAOLength /= b_iSSAOSampleCount;
        //return SSAOLength;

        fResult = min( fOcclusion, fOcclusion2 );
    } else fResult = fOcclusion;

    HALF fStaticAO = sample2D( p_sStaticAO, vScreenUV );
    if ( b_iSSAOOutput == SSAO_OUTPUT_STATIC ) {
        fResult = 1.0f;
    }

    return fResult;
}

#endif  // PIXEL_SHADER

#endif  // PS_SSAO