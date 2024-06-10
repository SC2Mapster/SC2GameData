//==================================================================================================
//
// Copyright Blizzard Entertainment 2003-2005
//
// This is the shader code for different lighting models.
//==================================================================================================

#ifndef _LIGHTINGMODELS
#define _LIGHTINGMODELS

#include "ShaderSystem.fx"

#define BLINN_SHADING       0
#define KAJIYAKAY_SHADING   1       // Hair

//==================================================================================================
// BLINN
//==================================================================================================

half3 BlinnShading( VertexTransport vertOut, half3 vNormalWS, half3 vLightDirWS,
                    bool bUseSpecular, bool bSpecifyHalfVector, half3 vHalfVectorWS, float3 vVertexPosWS, half3 vLightPosWS,
					half fSpecularPower ) {
    // Standard Blinn shading, with an optional "double" lambertian term to add contrast.

    half3 vLightDiffuseSpecular;
    vLightDiffuseSpecular.x = dot( vNormalWS, vLightDirWS );
    if ( b_useDblLambert )
        vLightDiffuseSpecular.x = -1.0f + vLightDiffuseSpecular.x * 2.0f;

    if ( !bSpecifyHalfVector )
        vHalfVectorWS = ComputeHalfVector( vVertexPosWS, normalize( vVertexPosWS - vLightPosWS ) );
    vLightDiffuseSpecular.y = saturate( dot( vNormalWS, vHalfVectorWS ) );
#ifdef COMPILING_SHADER_FOR_OPENGL
    //Stupid NaN from NVidia
    vLightDiffuseSpecular.y = max( vLightDiffuseSpecular.y, 0.0001f );
#endif

    vLightDiffuseSpecular.y = pow( vLightDiffuseSpecular.y, fSpecularPower );
    vLightDiffuseSpecular.y = saturate( vLightDiffuseSpecular.y * sign( vLightDiffuseSpecular.x ) );

    vLightDiffuseSpecular.x = saturate( vLightDiffuseSpecular.x );

	if ( !bUseSpecular ) 
        vLightDiffuseSpecular.y = 0;
    vLightDiffuseSpecular.z = 0;
    return vLightDiffuseSpecular;
}

//==================================================================================================
// MODIFIED KAJIYA-KAY (HAIR)
//==================================================================================================

#ifdef PIXEL_SHADER

HALF p_fPrimaryShift;
HALF p_fSecondaryShift;
HALF p_fKajiyaKaySpecularity2;
sampler2D p_sSpecularShiftLayer;

//--------------------------------------------------------------------------------------------------
half3 ShiftTangent( half3 vTangentWS, half3 vNormalWS, half fShift ) {
    half3 fShiftedTangent = vTangentWS + fShift * vNormalWS;
    return normalize( fShiftedTangent );
}

//--------------------------------------------------------------------------------------------------
half StrandSpecular( half3 vTangentWS, half3 vView, half3 vLight, half fSpecExponent ) {
    half3 vHalf = normalize( vLight + vView );
    half fDotTH = dot( vTangentWS, vHalf );
    half fSinTH = sqrt( 1.0f - fDotTH * fDotTH );
    half fDirAtten = smoothstep( -1.0f, 0.0f, dot( fDotTH, vHalf ) );
    return fDirAtten * pow( fSinTH, fSpecExponent );
}

//--------------------------------------------------------------------------------------------------
half3 KajiyaKayShading( VertexTransport vertOut, half3 vNormalWS, half3 vLightDirWS,
                        bool bUseSpecular,
                        bool bSpecifyHalfVector, half3 vHalfVectorWS, half3 vVertexPosWS, half3 vLightPosWS,
						half fSpecularPower ) {
    // Modified Kajiya-Kay lighting based on ATI paper for hair rendering.
    // Tweaked N dot L.
    // Two shifted specular highlights.

    // Note that this lighting model can only be forward-rendered as the deferred renderer can't supply the tangent or
    // the proper per-material properties.
    
    half3 vLightDiffuseSpecular;
    vLightDiffuseSpecular.x = saturate( lerp( 0.25f, 1.0f, dot( vNormalWS, vLightDirWS ) ) );

    // Unfortunately sampling textures here blurs the line between the lighting part of the shading and
    // the material part. This is not good.
    // :TODO: Can this be improved?
    half fShiftTex  = tex2D( p_sSpecularShiftLayer, INTERPOLANT_UV[0] ).a - 0.5f;   // :TODO: Setup UV emitter.
    half3 vTangent1 = ShiftTangent( INTERPOLANT_Tangent.xyz, vNormalWS, p_fPrimaryShift + fShiftTex );
    half3 vTangent2 = ShiftTangent( INTERPOLANT_Tangent.xyz, vNormalWS, p_fSecondaryShift + fShiftTex );
    vLightDiffuseSpecular.y = StrandSpecular( vTangent1, INTERPOLANT_EyeToVertex, vLightDirWS, fSpecularPower );
    vLightDiffuseSpecular.z = StrandSpecular( vTangent2, INTERPOLANT_EyeToVertex, vLightDirWS, p_fKajiyaKaySpecularity2 );

    return vLightDiffuseSpecular;
}
#else
//--------------------------------------------------------------------------------------------------
half3 KajiyaKayShading( VertexTransport vertOut, half3 vNormalWS, half3 vLightDirWS,
                        bool bUseSpecular,
                        bool bSpecifyHalfVector, half3 vHalfVectorWS, half3 vVertexPosWS, half3 vLightPosWS, half fSpecularPower ) {
    // Kajiya-kay is pixel shader only, use Blinn as fallback otherwise.
    return BlinnShading(    vertOut, vNormalWS, vLightDirWS, bUseSpecular, 
                            bSpecifyHalfVector, vHalfVectorWS, vVertexPosWS, vLightPosWS, fSpecularPower );
}
#endif

//==================================================================================================
// HUB
//==================================================================================================

//--------------------------------------------------------------------------------------------------
// LightShading() returns the diffuse component in x, the specular component in y, and a second, optional 
// specular component in z.
half3 LightShading( VertexTransport vertOut, half3 vNormalWS, half3 vLightDirWS,
                    bool bUseSpecular,
                    bool bSpecifyHalfVector, half3 vHalfVectorWS, float3 vVertexPosWS, half3 vLightPosWS,
					half fSpecularPower ) {
    if ( b_iLightingModel == BLINN_SHADING )
        return BlinnShading(    vertOut, vNormalWS, vLightDirWS, bUseSpecular, bSpecifyHalfVector, vHalfVectorWS,
                                vVertexPosWS, vLightPosWS, fSpecularPower );
    else if ( b_iLightingModel == KAJIYAKAY_SHADING )
        return KajiyaKayShading(    vertOut, vNormalWS, vLightDirWS, bUseSpecular, bSpecifyHalfVector, vHalfVectorWS,
                                    vVertexPosWS, vLightPosWS, fSpecularPower );
    else return 0;
}

#endif  // _LIGHTINGMODELS