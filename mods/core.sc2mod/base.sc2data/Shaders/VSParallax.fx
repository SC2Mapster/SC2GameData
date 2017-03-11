//==================================================================================================
//
// Copyright Blizzard Entertainment 2003-2007
//
// Parallax mapping code.
//==================================================================================================

#ifndef _VSPARALLAX
#define _VSPARALLAX

#ifdef VERTEX_SHADER

#include "ShaderSystem.fx"
#include "Common.fx"

#if ( b_useParallaxMapping == 1 || CPP_SHADER )

//--------------------------------------------------------------------------------------------------
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

#endif  // VERTEX_SHADER

#endif  // _PARALLAX