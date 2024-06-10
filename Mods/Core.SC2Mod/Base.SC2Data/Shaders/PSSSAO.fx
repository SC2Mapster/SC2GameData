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

sampler2D p_sBlockerFunc;
sampler2D p_sDetailBlockerFunc;
sampler2D p_sEncodedDepth;
sampler2D p_sSSAONoise;

HALF2 p_vSSAOTermA;

#define OPTIMIZE_SSAO

//--------------------------------------------------------------------------------------------------
half3x3 MakeRotation( half fAngle, half3 vAxis ) {
    half fS;
    half fC;
    sincos( fAngle, fS, fC );
    half fXX       = vAxis.x * vAxis.x;
    half fYY       = vAxis.y * vAxis.y;
    half fZZ       = vAxis.z * vAxis.z;
    half fXY       = vAxis.x * vAxis.y;
    half fYZ       = vAxis.y * vAxis.z;
    half fZX       = vAxis.z * vAxis.x;
    half fXS       = vAxis.x * fS;
    half fYS       = vAxis.y * fS;
    half fZS       = vAxis.z * fS;
	half fOneC      = 1.0f - fC;
    
    half3x3 result = half3x3(       fOneC * fXX +  fC, fOneC * fXY + fZS, fOneC * fZX - fYS,
                                    fOneC * fXY - fZS, fOneC * fYY +  fC, fOneC * fYZ + fXS,
                                    fOneC * fZX + fYS, fOneC * fYZ - fXS, fOneC * fZZ +  fC
    );
    return result;
}

float3 reflect( float3 vSample, float3 vNormal ) {
    return normalize( vSample - 2.0f * dot( vSample, vNormal ) * vNormal );
}

float2 SSAOCenterUV;
float SSAOLength;

bool TestOcclusion( float3 vViewPos, float3 vSamplePointDelta, float3 vNormal, out float fBlock,
                    float fOcclusionRadius, sampler2D sBlockerFunc, half2 fSampleRecip,
                    float fFullOcclusionThreshold, float fNoOcclusionThreshold ) {
    if ( dot( vSamplePointDelta, vNormal.xzy ) < 0 )
        vSamplePointDelta = -vSamplePointDelta;
    
    float3 vSamplePoint     = vViewPos + fOcclusionRadius * vSamplePointDelta;
    float2 vSamplePointUV;
    if ( b_iSSAOOptimizedSampleDelta )
        // This one sacrifices some contrast
        // SSAO term A = reciprocal of half camera size times ( 0.5f, -0.5f )
        // SSAO term B = ( 1.0f, -1.0f ) * ( 0.5f, -0.5f ) = ( 0.5f, 0.5f )
        vSamplePointUV = ( p_vSSAOTermA / vSamplePoint.z ) * vSamplePoint.xy + half2( 0.5f, 0.5f );
    else {
        vSamplePointUV = vSamplePoint.xy / vSamplePoint.z;
        vSamplePointUV = vSamplePointUV / p_vCameraSize / 0.5f;
        vSamplePointUV = vSamplePointUV + float2( 1.0f, -1.0f );
        vSamplePointUV = vSamplePointUV / float2( 2.0f, -2.0f );
    }
    
#if 1 //ndef OPTIMIZE_SSAO
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
        fSampleDepth = DecodeDepth( tex2D( p_sEncodedDepth, vSamplePointUV ) ); 
    else fSampleDepth = tex2D( p_sEncodedDepth, vSamplePointUV ).r; 

    float fDistance = vSamplePoint.z - fSampleDepth; 

    if ( b_iSSAOBlockerLookup )
        // Clip it so so there is no occlusion if sampled depth is behind the sample point's z.
        fBlock = tex2D( sBlockerFunc, fDistance ).r; 
    else {
        if ( fDistance > 0.01f ) {
            // Past this distance there is no occlusion.
            half fNoOcclusionRange = fNoOcclusionThreshold - fFullOcclusionThreshold;      
            if ( fDistance < fFullOcclusionThreshold )
                fBlock = 1.0f;
            else fBlock = max( 1.0f - ( ( fDistance - fFullOcclusionThreshold ) / fNoOcclusionRange ), 0.0f );
        } else fBlock = 0.0f;
    }

    return true;
}

half4 PostProcessSSAO( VertexTransport vertOut ) {
    float2 vViewSpaceUV = INTERPOLANT_HPosAsUV * p_vRecipSrcSizeOffset.xy ;
    float2 vScreenUV    = vViewSpaceUV + p_vRecipSrcSizeOffset.zw;
    float4 vNormalDepth = SampleNormalDepth( p_sNormalDepthMap, vScreenUV );

    SSAOLength = 0.0f;
    
    float3 vNormal = normalize( mul( (float3x3)p_mViewTransform, PIXEL_NORMAL ) );       // In camera space
    //float3 vNormal = mul( (float3x3)p_mViewTransform, PIXEL_NORMAL );       // In camera space

    vViewSpaceUV = vViewSpaceUV * float2( 2.0f, -2.0f );  // From 0..1 to to 0..2
    vViewSpaceUV = vViewSpaceUV + float2( -1.0f, 1.0f );  // From 0..2 to -1..1
    vViewSpaceUV = vViewSpaceUV * p_vCameraSize * 0.5f;

    SSAOCenterUV = vScreenUV;

    float3 vViewPos;
    if ( b_iSSAOEncodedDepth )
        vViewPos = float3( vViewSpaceUV.x, vViewSpaceUV.y, 1.0f ) * DecodeDepth( tex2D( p_sEncodedDepth, vScreenUV ) );
    else vViewPos = float3( vViewSpaceUV.x, vViewSpaceUV.y, 1.0f ) * tex2D( p_sEncodedDepth, vScreenUV ).r; //  PIXEL_DEPTH?

    half2 fSampleRecip = p_vSSAOTermA / vViewPos.z;   // Reuse this for all samples instead of a pespective divide - the error should be small.

    half fAdjustedOcclusionRadius = p_fOcclusionRadius * 0.15f;
    half fAdjustedDetailOcclusionRadius = p_fDetailOcclusionRadius * 0.15f;
    half fScreenOcclusionRadius = fAdjustedOcclusionRadius / vViewPos.z;
    //if ( fScreenOcclusionRadius > p_fSSAOLimiter ) {
        //fAdjustedOcclusionRadius = fAdjustedOcclusionRadius * p_fSSAOLimiter / fScreenOcclusionRadius;
    //}

    /*
    fScreenOcclusionRadius = fAdjustedDetailOcclusionRadius / vViewPos.z;
    if ( fScreenOcclusionRadius > p_fSSAOLimiter ) {
        fAdjustedDetailOcclusionRadius = fAdjustedDetailOcclusionRadius * p_fSSAOLimiter * 0.1f / fScreenOcclusionRadius;
    }
    */

    float3 vRandomNormal = ( normalize( tex2D( p_sSSAONoise, vScreenUV *  p_vSrcSize / 256.0f ).xyz * 2.0f - 1.0f ) );
    //float3 vRandomNormal = tex2D( p_sSSAONoise, vScreenUV * p_vSrcSize / 32.0f ).xyz * 2.0f - 1.0f;
    
    //float3x3 mBasis;
    //mBasis[0] = cross( half3( 0.0f, 0.0f, 1.0f ), vNormal.xzy );
    //mBasis[1] = cross( mBasis[0], vNormal.xzy );
    //mBasis[2] = vNormal.xzy;

    int iSampleCount;
    if ( b_iUseSeparateDetailSSAO ) 
        iSampleCount = b_iSSAOSampleCount * 3 / 4;
    else iSampleCount = b_iSSAOSampleCount;

    half fAccumBlock = 0.0f;
    int iSamples = 0;
    for ( int i = 0; i < iSampleCount; i++ ) {
        //float3 vSamplePointDelta = normalize( mul( p_vSSAOSamplePoints[i], mBasis ) ); //normalize( mul( mBasis,  ) );
        float3 vSamplePointDelta = reflect( p_vSSAOSamplePoints[i], vRandomNormal );
        float fBlock;
        if ( TestOcclusion( vViewPos, vSamplePointDelta, vNormal, fBlock, fAdjustedOcclusionRadius, p_sBlockerFunc, fSampleRecip,
                            p_fFullOcclusionThreshold, p_fNoOcclusionThreshold ) ) {
            fAccumBlock += fBlock;
            iSamples++;
        }
    }
    fAccumBlock /= iSamples;
    half fOcclusion = 1.0f - fAccumBlock;
    fOcclusion = pow( fOcclusion, p_fOcclusionPower );

    if ( b_iUseSeparateDetailSSAO ) {
        fAccumBlock = 0.0f;
        iSamples = 0;
        for ( int i = b_iSSAOSampleCount * 3 / 4; i < b_iSSAOSampleCount; i++ ) {
            //float3 vSamplePointDelta = normalize( mul( p_vSSAOSamplePoints[i], mBasis ) ); //normalize( mul( mBasis, p_vSSAOSamplePoints[i] ) );
            float3 vSamplePointDelta = reflect( p_vSSAOSamplePoints[i], vRandomNormal );
            float fBlock;
            if ( TestOcclusion(     vViewPos, vSamplePointDelta, vNormal, fBlock, fAdjustedDetailOcclusionRadius, p_sDetailBlockerFunc, fSampleRecip, 
                                    p_fDetailFullOcclusionThreshold, p_fDetailNoOcclusionThreshold ) ) {
                fAccumBlock += fBlock;
                iSamples++;
            }
        }
        fAccumBlock /= iSamples;
        half fOcclusion2 = 1.0f - fAccumBlock;
        fOcclusion2 = pow( fOcclusion2, p_fDetailOcclusionPower );


        SSAOLength /= b_iSSAOSampleCount;
        //return SSAOLength;

        return min( fOcclusion, fOcclusion2 );
    } else return fOcclusion;
}

#endif  // PIXEL_SHADER

#endif  // PS_SSAO