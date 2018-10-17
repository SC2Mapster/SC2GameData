//==================================================================================================
//
// Copyright Blizzard Entertainment 2003-2007
//
// DoFi
// Parallax mapping code.
//==================================================================================================

#ifndef PS_PARALLAX
#define PS_PARALLAX

#ifdef PIXEL_SHADER

#include "ShaderSystem.fx"
#include "PSMaterialDefines.fx"
#include "PSCommon.fx"

#if ( b_useParallaxMapping == 1 || CPP_SHADER )

//--------------------------------------------------------------------------------------------------
void LinearSearch (typeSampler2D sTex, typeTexture2D tTex, int iChannels, int iNumSteps, inout float3 vVector, inout float3 vPoint) {
    vVector /= iNumSteps;
    for (int i=0; i<=iNumSteps; i++) {
        float h = ChooseChannel(iChannels, sampleTex2D(tTex, sTex, vPoint.xy)).a;
        if (vPoint.z > h) {
            vPoint += vVector;
        }
    }
}

//--------------------------------------------------------------------------------------------------
void BinarySearch (typeSampler2D sTex, typeTexture2D tTex, int iChannels, int iNumSteps, inout float3 vVector, inout float3 vPoint) {
    for( int i=0; i<iNumSteps; i++ ) {
        vVector *= 0.5f;
        float h = ChooseChannel(iChannels, sampleTex2D(tTex, sTex, vPoint.xy)).a;
        if (vPoint.z > h) {
            vPoint += 2.f * vVector;
        }
        vPoint -= vVector;
	}
}

//--------------------------------------------------------------------------------------------------
bool ComputeParallaxOffsetNew (
    float3 vViewVectorTS, 
    float2 vHeightMapUV, 
    typeSampler2D sHeightMap,
    typeTexture2D tHeightMap,
    int iChannelSelect,
    bool isDXN,
    float3x3 mTangent2World,
    out float2 vParallaxOffset
) {

    vViewVectorTS /= -vViewVectorTS.z;
    vViewVectorTS.xy *= p_vSpecularMultiplier_DepthBlendThreshold_HeightMapScale_AlphaFactor.z;

    float3 vUV = float3(vHeightMapUV.xy, 1);
    LinearSearch(sHeightMap, tHeightMap, iChannelSelect, 12, vViewVectorTS, vUV);
    BinarySearch(sHeightMap, tHeightMap, iChannelSelect, 4, vViewVectorTS, vUV);

    vParallaxOffset = vUV.xy - vHeightMapUV;

    return true;
}

float2 ComputeParallaxOffset( float2 vParallaxVector, float2 vHeightMapUV, typeSampler2D sHeightMap, typeTexture2D tHeightMap, int iChannelSelect );

void OffsetUVEmitter(inout VertexTransport vertOut, int index, float4 offset)
{
#if ( b_usePackedUVEmitter == 1 )
    if(index % 2 == 0)
        READ_INTERPOLANT_UV(index / 2).xy += offset.xy;
    else
        READ_INTERPOLANT_UV(index / 2).zw += offset.xy;
#else
#if !CPP_SHADER
    float4 newUV = READ_INTERPOLANT_UV(index) + offset;
    WRITE_INTERPOLANT_UV( index, newUV );
#endif
#endif
}

//--------------------------------------------------------------------------------------------------
void ApplyParallax( inout VertexTransport vertOut, typeSampler2D sHeightMap, typeTexture2D tHeightMap, HALF4 iUV ) {
    float4 parallax = 0; 
    if ( !b_useParallaxMapping )
        return;

#ifndef CPP_SHADER
    if( p_vSpecularMultiplier_DepthBlendThreshold_HeightMapScale_AlphaFactor.z <= 0.f )
        return;
#endif

    if (b_iUsePOMNew) {
        float3x3 mTangent2World;
        mTangent2World[0] = INTERPOLANT_Tangent.xyz;
        mTangent2World[1] = INTERPOLANT_Binormal.xyz;
        mTangent2World[2] = INTERPOLANT_Normal.xyz;

		// Height map and normal map must use the same mapping (they both share the same tangent basis). So height map uses the normal map mapping.
         if (ComputeParallaxOffsetNew( 
                INTERPOLANT_ParallaxVector, 
                iUV, 
                sHeightMap, tHeightMap,
                b_iHeightmapChannelSelect,
                b_DXNStyleNormalMaps,
                mTangent2World,
                parallax.xy 
            )
         ) {
                for ( int i = 0; i < b_iUVEmitterCount; i++ ) {
                    OffsetUVEmitter(vertOut, i, parallax);         // Parallax is applied to all UVs.
                }
         }
    }
    else {
	    // Height map and normal map must use the same mapping (they both share the same tangent basis). So height map uses the normal map mapping.
        parallax.xy = ComputeParallaxOffset( INTERPOLANT_ParallaxVector.xy, iUV, sHeightMap, tHeightMap, b_iHeightmapChannelSelect );
        for ( int i = 0; i < b_iUVEmitterCount; i++ ) {
            OffsetUVEmitter(vertOut, i, -parallax);         // Parallax is applied to all UVs.
        }
    }
}

//--------------------------------------------------------------------------------------------------
float2 ComputeParallaxOffset( float2 vParallaxVector, float2 vHeightMapUV, typeSampler2D sHeightMap, typeTexture2D tHeightMap, int iChannelSelect ) {
     // Determine the number of samples per ray. Depends on the viewing angle for the surface.
    int nNumSteps = 16; // (int) lerp( (int)nMaxSamples, (int)nMinSamples, dot( vViewWS, vNormalWS ) );

    // Compute current gradients. Gradients should be isolated outside of dynamic loops.
    float2 dx = ddx( vHeightMapUV );
    float2 dy = ddy( vHeightMapUV );

    float    fSampledHeight      = 0.0;
    float    fStepSize           = 1.0 / (float) nNumSteps;
    float    fPrevSampledHeight  = 1.0;
    int      nStepIndex          = 0;
    float2   vTexOffsetPerStep   = fStepSize * vParallaxVector;
    float2   vCurrentSampleUV    = vHeightMapUV;
    float    fRayHeight          = 1.0;
    float    fParallaxAmount     = 0.0;
    float    x                   = 0;
    float    y                   = 0;
    float    xh                  = 0;
    float    yh                  = 0;   

    // Ray trace.
    while ( nStepIndex < nNumSteps ) {
        vCurrentSampleUV -= vTexOffsetPerStep;

        fSampledHeight = ChooseChannel( iChannelSelect, tex2Dgrad( sHeightMap, vCurrentSampleUV, dx, dy ) ).a;

        fRayHeight -= fStepSize;

        if ( fSampledHeight > fRayHeight ) {    
            // Intersected.
            x  = fRayHeight;                    // Ray height = ray lateral displacement too
            y  = fRayHeight + fStepSize; 
            xh = fSampledHeight;
            yh = fPrevSampledHeight;
            nStepIndex = nNumSteps + 1;         // Done.
        }
        else {
            nStepIndex++;
            fPrevSampledHeight = fSampledHeight;
        }
    }

    // Compute the exact intersection point.
    fParallaxAmount = (x * (y - yh) - y * (x - xh))/((y - yh) - (x - xh));

    // Adjust the parallax vector.
    return vParallaxVector * (1.0f - fParallaxAmount );
}

//--------------------------------------------------------------------------------------------------
/*
float ComputeParallaxOcclusion( HALF2 vParallaxedUV, HALF3 vShadowLightDirectionTS, sampler2D sHeightMap ) {
    if ( b_useParallaxOcclusion ) {
        return 1;
        // Determine light ray in texture space
        float fShadowSoftening = 0.7f;
        float3 vLightTS         = normalize( vShadowLightDirectionTS );
        float2 vLightDirection  = vLightTS.xy * p_fHeightMapScale * 5.0f;

        // This is equivalent to a ray cast starting from the parallaxed UV found in the previous step and going towards the light.
        // 7 samples are taken along the light's direction to try to find a heigth that will block the light ray.
        // The importance of each sample is varied such that an intersection further towards the light contributes less shadow than
        // one very close to the intersection sample.
        float fBaseHeight =  tex2D( sHeightMap, vParallaxedUV).a;
        float fOcclusion1 = (tex2D( sHeightMap, vParallaxedUV + vLightDirection * 0.88 ).a - fBaseHeight - 0.88 ) *  1 * fShadowSoftening;
        float fOcclusion2 = (tex2D( sHeightMap, vParallaxedUV + vLightDirection * 0.77 ).a - fBaseHeight - 0.77 ) *  2 * fShadowSoftening;
        float fOcclusion3 = (tex2D( sHeightMap, vParallaxedUV + vLightDirection * 0.66 ).a - fBaseHeight - 0.66 ) *  4 * fShadowSoftening;
        float fOcclusion4 = (tex2D( sHeightMap, vParallaxedUV + vLightDirection * 0.55 ).a - fBaseHeight - 0.55 ) *  6 * fShadowSoftening;
        float fOcclusion5 = (tex2D( sHeightMap, vParallaxedUV + vLightDirection * 0.44 ).a - fBaseHeight - 0.44 ) *  8 * fShadowSoftening;
        float fOcclusion6 = (tex2D( sHeightMap, vParallaxedUV + vLightDirection * 0.33 ).a - fBaseHeight - 0.33 ) * 10 * fShadowSoftening;
        float fOcclusion7 = (tex2D( sHeightMap, vParallaxedUV + vLightDirection * 0.22 ).a - fBaseHeight - 0.22 ) * 12 * fShadowSoftening;

        // Compute the actual shadow strength:
        float fShadow = saturate( 1 - max( max( max( max( max( max( fOcclusion1, fOcclusion2 ), fOcclusion3 ), fOcclusion4 ), fOcclusion5 ), fOcclusion6 ), fOcclusion7 ) );
        //fShadow = fShadow * 0.6f + 0.4f;
        return fShadow;
    } else return 1;
}
*/

#else // b_useParallaxMapping

void ApplyParallax( in VertexTransport vertOut, typeSampler2D sHeightMap, typeTexture2D tHeightMap, HALF4 iUV ) {
}

bool ComputeParallaxOffsetNew (
    float3 vViewVectorTS, 
    float2 vHeightMapUV, 
    typeSampler2D sHeightMap,
    typeTexture2D tHeightMap,
    int iChannelSelect,
    bool isDXN,
    float3x3 mTangent2World,
    out float2 vParallaxOffset
) {
    vParallaxOffset = 0;
    return false;
}

float2 ComputeParallaxOffset( float2 vParallaxVector, float2 vHeightMapUV, typeSampler2D sHeightMap, typeTexture2D tHeightMap, int iChannelSelect ) {
    return 0;
}

#endif  // b_useParallaxMapping == 1

#endif  // PIXEL_SHADER

#endif  // PS_PARALLAX