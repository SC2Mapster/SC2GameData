//==================================================================================================
//
// Copyright Blizzard Entertainment 2003-2007
//
//==================================================================================================

#ifndef _COMMON
#define _COMMON

float3      p_vEyePos;                                  // Eye position.
HALF4		p_vSpecColorSpecularity;                    // Specular color and specularity in w.
HALF2       p_vViewportOrigin;
HALF2       p_vViewportScale;
float4x4    p_mShadowTransform;                         // Transform for shadow map.
float3x4    p_mViewTransform;                           // View transform - transposed for efficiency.
HALF3       p_vCameraDirection;
HALF4       p_vSpecularMultiplier_DepthBlendThreshold_HeightMapScale_AlphaFactor;
float4x4    p_mFOWMatrix;

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
half3 DecodeNormal( half3 vNormal ) {
    return vNormal * 2.0f - 1.0f;
}

//--------------------------------------------------------------------------------------------------
// normalized device coordinates to texture space coordinates
half2 Ndc2Tex (half2 vNDC, bool flipV=true) {
    //half2 vRet = (vNDC+half2(1.0f,1.0f))/(half2(2.0f,2.0f));
    //vRet.y = 1.0f-vRet.y;
    return vNDC * half2(0.5f, -0.5f) + 0.5f;
}

#endif  // _COMMON