//==================================================================================================
//
// Copyright Blizzard Entertainment 2003-2007
//
//==================================================================================================

#ifndef _COMMON
#define _COMMON

#define c_terrainMinHeight       (-100.f)
#define c_terrainMaxHeight       (100.f)

float3      p_vEyePos;                                  // Eye position.
HALF4		p_vSpecColorSpecularity;                    // Specular color and specularity in w.
HALF2       p_vViewportOrigin;
HALF2       p_vViewportScale;
float4x4    p_mShadowTransform;                         // Transform for shadow map.
float3x4    p_mViewTransform;                           // View transform - transposed for efficiency.
HALF3       p_vCameraDirection;
HALF4       p_vSpecularMultiplier_DepthBlendThreshold_HeightMapScale_AlphaFactor;
float4x4    p_mFOWMatrix;
HALF2       p_vHDRScaling;
float       p_fAlphaThreshold;
float4      p_vClipPlanes[6];
float       p_iClipPlaneCount;

//--------------------------------------------------------------------------------------------------
// Compute fog density.
//--------------------------------------------------------------------------------------------------
float3      p_vFogDensity_Falloff_MinHeight;
HALF4       p_cFogColor;
float4      p_vFogDistance;     // x is near plane, y is far plane, z is distance falloff
//--------------------------------------------------------------------------------------------------
float FogDensityDistribution (float fZ) {
    return p_vFogDensity_Falloff_MinHeight.x * exp((p_vFogDensity_Falloff_MinHeight.z-fZ) * p_vFogDensity_Falloff_MinHeight.y);
}
//--------------------------------------------------------------------------------------------------
float FogDensity ( float3 vPosWorld ) {
    float3 vViewVect = vPosWorld - p_vEyePos;
    float fDist = length(vViewVect);
    float fFogIntegration = p_vFogDensity_Falloff_MinHeight.x * fDist * exp((p_vFogDensity_Falloff_MinHeight.z - p_vEyePos.z) * p_vFogDensity_Falloff_MinHeight.y);

    const float c_fSlopeEps = 0.01f;
    if (abs(vViewVect.z) > c_fSlopeEps) {
        float fT = p_vFogDensity_Falloff_MinHeight.y * vViewVect.z;

        if (fT == 0.0f) {
            fFogIntegration = 0.0f;
        } 
        else {
            //Ensure that exp(-fT) stays within the bounds of FLOAT_MAX
			//Without this compiler optimization can cause an otherwise unfogged object to be fogged
			fT = clamp(fT, -88.0f, 88.0f);
            fFogIntegration *= (1.0f - exp(-fT)) / fT;
        }
    }

    float fOutDensity = fFogIntegration;
    
    if (p_vFogDistance.z > 0.f) {
        if (p_vFogDistance.y != p_vFogDistance.x) {
            //fOutDensity = fFogIntegration * saturate(p_vFogDistance.z * (fDist - p_vFogDistance.x) / (p_vFogDistance.y - p_vFogDistance.x));
            fOutDensity = fFogIntegration * saturate(p_vFogDistance.z * (fDist - p_vFogDistance.x) * p_vFogDistance.w);
        }
    }

    return saturate(fOutDensity);
}

//--------------------------------------------------------------------------------------------------
float SplatAttenuationVectorUI (float3 worldPos, float4 vPlane, float scalar, float minHeight) {
#if b_splatAttenuationEnabled
    float fDist = dot(float4(worldPos, 1.0f), vPlane) * scalar;
    return 1.0f - saturate(abs(fDist));
#else
    return 1;
#endif
}

//--------------------------------------------------------------------------------------------------
float SplatAttenuationProjector (float3 worldPos, float4 vPlane, float halfHeight, float minHeight) {
#if b_splatAttenuationEnabled
    float d = abs(dot(float4(worldPos, 1.0f), vPlane));
    return saturate((halfHeight - d) / (halfHeight - minHeight));
#else
    return 1;
#endif
}

// :TODO: Move this.
//--------------------------------------------------------------------------------------------------
// Computes the half vector for specular lighting.
float3 ComputeHalfVector( float3 vWorldPos, float3 vWorldLightDirection ) {
    float3 vEyeVec;
	if ( false ) //b_useVertexLighting )
		vEyeVec       = normalize( float4( p_vEyePos, 1.0f ) - float4( vWorldPos, 1.0f ) ).xyz;	// Think this is weird? I think so too! This weird construct is there to walk
																								// around some glitch specifically for Nvidia hardware, geForce 7s and below.
	else vEyeVec       = normalize( p_vEyePos - vWorldPos );
    float3 vLightHalfVec = normalize( vEyeVec - vWorldLightDirection ); 
    return vLightHalfVec;
}

//--------------------------------------------------------------------------------------------------
HALF3 DecodeNormal( HALF3 vNormal ) {
    return vNormal * 2.0f - 1.0f;
}

//--------------------------------------------------------------------------------------------------
// normalized device coordinates to texture space coordinates
HALF2 Ndc2Tex (HALF2 vNDC, bool flipV=true) {
    //HALF2 vRet = (vNDC+HALF2(1.0f,1.0f))/(HALF2(2.0f,2.0f));
    //vRet.y = 1.0f-vRet.y;
    return vNDC * HALF2(0.5f, -0.5f) + 0.5f;
}

//--------------------------------------------------------------------------------------------------
float3 ComputeTriPlanarBlendingWeights (float3 vNormal ) {
    float3 w = abs(vNormal);
    w -= float3(0.2f, 0.2f, 0.2f);
    w *= float3(7.f, 7.f, 7.f);
    w = saturate(w);
    w = pow(w, 3);
    w /= dot(w, float3(1,1,1));
    return w;
}

//--------------------------------------------------------------------------------------------------
HALF SmoothStep( HALF fX ) {
    return fX * fX * ( 3.0f - 2.0f * fX );
}

//--------------------------------------------------------------------------------------------------
// quadratic bezier
float BezierInterpolation (float fV0, float fV1, float fV2, float fT) {
    float ret;
    float invT = (1.0f - fT);
    ret = (invT * invT) * fV0;
    ret += (2.0f * fT * invT) * fV1;
    ret += (fT * fT) * fV2;
    return ret;
}

//--------------------------------------------------------------------------------------------------
// quadratic bezier
float3 BezierInterpolation (float3 fV0, float3 fV1, float3 fV2, float fT) {
    float3 ret;
    float invT = (1.0f - fT);
    ret = (invT * invT) * fV0;
    ret += (2.0f * fT * invT) * fV1;
    ret += (fT * fT) * fV2;
    return ret;
}

//--------------------------------------------------------------------------------------------------
void AlphaTest (float fAlpha) {
    if (b_iAlphaTest){
		clip(fAlpha - p_fAlphaThreshold);
    }
}

//--------------------------------------------------------------------------------------------------
void ClipPlanes (float4 vClipPos) {

#ifndef COMPILING_SHADER_FOR_OPENGL
    if (PIXEL_SHADER_VERSION >= SHADER_VERSION_PS_40) {
        for (int i = 0; i < p_iClipPlaneCount; i++) {
            clip(dot(vClipPos, p_vClipPlanes[i]));
        }
    }
#endif

}

//--------------------------------------------------------------------------------------------------
#if ( b_useParallaxMapping == 1 || CPP_SHADER )

float3 EmitParallaxVector( float3 vVertWS, float3 vEyeWS, HALF3 vNormal, HALF3 vTangent, HALF3 vBinormal ) {
    // Compute initial parallax displacement direction

    // Move eye to tangent space and normalize.
    
    float3 vPos = vEyeWS - vVertWS;
    float3 vEyeTS;
    if ( b_useIdentityBasis )
		vEyeTS = vPos * HALF3( 1.0, -1.0f, 1.0f ); 
    else {
		float3x3 mWorldToTangent;
		mWorldToTangent[0] = normalize( vTangent );
		mWorldToTangent[1] = normalize( vBinormal );
		mWorldToTangent[2] = vNormal;
	    vEyeTS = normalize( mul( mWorldToTangent, vPos  ) );
	} 

    if (b_iUsePOMNew)
        return vEyeTS.xyz;
	
    float2 vParallaxDirection = normalize( vEyeTS.xy );

    // Compute the length of parallax displacement vector.
    
    //      Eye
    //       *
    //        *
    // --------\----------------        Height 1.0 (With no parallax, UVs would be sampled here)
    //          \
    //           \      <-- parallax displacement vector (in 2D tangent space).
    //            \
    // ------------\------------        Height 0.0
    float fLength = length( vEyeTS );
    // Parallax length increases along with divergent viewing angle.
    float fParallaxLength = sqrt( fLength * fLength -  vEyeTS.z * vEyeTS.z ) / vEyeTS.z;

    // Compute the actual reverse parallax displacement vector.
    return float3(vParallaxDirection * fParallaxLength * p_vSpecularMultiplier_DepthBlendThreshold_HeightMapScale_AlphaFactor.z, 0);
}


#else

float3 EmitParallaxVector( float3 vVertWS, float3 vEyeWS, HALF3 vNormal, HALF3 vTangent, HALF3 vBinormal ) {
    return 0;
}

#endif  // b_useParallaxMapping == 1


#endif  // _COMMON
