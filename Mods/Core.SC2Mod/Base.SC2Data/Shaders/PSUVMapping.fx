#ifndef PS_UVMAPPING
#define PS_UVMAPPING

#ifdef PIXEL_SHADER

#include "ShaderSystem.fx"
#include "PSCommon.fx"
#include "MaterialDefines.fx"

struct SEnvMappings {
    half2   vReflectSphericalEnvioUV;
    half3   vReflectCubicEnvioUV;
    half2   vSphericalEnvioUV;
    half3   vCubicEnvioUV;
};

//--------------------------------------------------------------------------------------------------
half2 GenSphericalEnvio( float3 vPosition, half3 vNormal, bool reflect ) {
    half3 vLookup;
	if ( reflect && PIXEL_SHADER_VERSION >= SHADER_VERSION_PS_30 ) {
		vLookup = normalize( vPosition - 2.0f * dot( vPosition, vNormal ) * vNormal );
    } 
    else {
        vLookup = vNormal;	// vNormal should be normalized
    }
    return vLookup.xz * half2( 0.5f, -0.5f ) + 0.5f;
}

//--------------------------------------------------------------------------------------------------
half3 GenCubicEnvio( float3 vPosition, half3 vNormal, bool reflect ) {
    half3 vLookup;
    if ( reflect ) {
		vLookup	= normalize(vPosition - 2.0f * dot( vPosition, vNormal ) * vNormal);
    }
    else {
        vLookup = vNormal;
    }
    return vLookup;
}

//--------------------------------------------------------------------------------------------------
SEnvMappings ComputeEnvMappings( VertexTransport vertOut, half3 vNormal ) {
    SEnvMappings envMappings;
    envMappings.vReflectSphericalEnvioUV	= GenSphericalEnvio(    INTERPOLANT_EyeToVertex, vNormal, true );
    envMappings.vReflectCubicEnvioUV		= GenCubicEnvio(        INTERPOLANT_EyeToVertex, vNormal, true );
    envMappings.vSphericalEnvioUV			= GenSphericalEnvio(    INTERPOLANT_EyeToVertex, vNormal, false );
    envMappings.vCubicEnvioUV				= GenCubicEnvio(        INTERPOLANT_EyeToVertex, vNormal, false );
    return envMappings;
}

//--------------------------------------------------------------------------------------------------
half4 GenEnvioUV( SEnvMappings envMappings, int iMapping ) {
    // Environment mappings only.
    half3 vResult;
    if ( iMapping == UVMAP_REFLECT_CUBICENVIO )
        vResult = envMappings.vReflectCubicEnvioUV;
    else if ( iMapping == UVMAP_REFLECT_SPHERICALENVIO ) {
        vResult.xy = envMappings.vReflectSphericalEnvioUV;
        vResult.z = 0;
    } else if ( iMapping == UVMAP_CUBICENVIO )
        vResult = envMappings.vCubicEnvioUV;
    else if ( iMapping == UVMAP_SPHERICALENVIO ) {
        vResult.xy = envMappings.vSphericalEnvioUV;
        vResult.z = 0;
    } else vResult = 0;
    return half4(vResult,1);
}

#endif  // PIXEL_SHADER

#endif  // PS_UVMAPPING