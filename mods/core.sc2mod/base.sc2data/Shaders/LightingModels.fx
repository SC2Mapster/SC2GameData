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

HALF3 BlinnShading( VertexTransport vertOut, HALF3 vNormalWS, HALF3 vLightDirWS,
                    bool bUseSpecular, bool bSpecifyHalfVector, HALF3 vHalfVectorWS, float3 vVertexPosWS, HALF3 vLightPosWS,
					HALF fSpecularPower ) {
    // Standard Blinn shading, with an optional "double" lambertian term to add contrast.

    HALF3 vLightDiffuseSpecular;
    vLightDiffuseSpecular.x = dot( vNormalWS, vLightDirWS );
    if ( b_useDblLambert )
        vLightDiffuseSpecular.x = -1.0f + vLightDiffuseSpecular.x * 2.0f;

    if (bUseSpecular) {
        if ( !bSpecifyHalfVector )
            vHalfVectorWS = ComputeHalfVector( vVertexPosWS, normalize( vVertexPosWS - vLightPosWS ) );
        vLightDiffuseSpecular.y = saturate( dot( vNormalWS, vHalfVectorWS ) );

        #ifdef COMPILING_SHADER_FOR_OPENGL
            //Stupid NaN from NVidia
            vLightDiffuseSpecular.y = max( vLightDiffuseSpecular.y, 0.0001f );
        #endif

        vLightDiffuseSpecular.y = pow( vLightDiffuseSpecular.y, fSpecularPower );
        vLightDiffuseSpecular.y = saturate( vLightDiffuseSpecular.y * sign( vLightDiffuseSpecular.x ) );
    }
    else
        vLightDiffuseSpecular.y = 0;

    vLightDiffuseSpecular.x = saturate( vLightDiffuseSpecular.x );

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
texDecl2D(p_sSpecularShiftLayer);

//--------------------------------------------------------------------------------------------------
HALF3 ShiftTangent( HALF3 vTangentWS, HALF3 vNormalWS, HALF fShift ) {
    HALF3 fShiftedTangent = vTangentWS + fShift * vNormalWS;
    return normalize( fShiftedTangent );
}

//--------------------------------------------------------------------------------------------------
HALF StrandSpecular( HALF3 vTangentWS, HALF3 vView, HALF3 vLight, HALF fSpecExponent ) {
    HALF3 vHalf = normalize( vLight + vView );
    HALF fDotTH = dot( vTangentWS, vHalf );
    HALF fSinTH = sqrt( 1.0f - fDotTH * fDotTH );
    HALF fDirAtten = smoothstep( -1.0f, 0.0f, dot( fDotTH, vHalf ) );
    return fDirAtten * pow( fSinTH, fSpecExponent );
}

//--------------------------------------------------------------------------------------------------
HALF3 KajiyaKayShading( VertexTransport vertOut, HALF3 vNormalWS, HALF3 vLightDirWS,
                        bool bUseSpecular,
                        bool bSpecifyHalfVector, HALF3 vHalfVectorWS, HALF3 vVertexPosWS, HALF3 vLightPosWS,
						HALF fSpecularPower ) {
    // Modified Kajiya-Kay lighting based on ATI paper for hair rendering.
    // Tweaked N dot L.
    // Two shifted specular highlights.

    // Note that this lighting model can only be forward-rendered as the deferred renderer can't supply the tangent or
    // the proper per-material properties.
    
    HALF3 vLightDiffuseSpecular;
    vLightDiffuseSpecular.x = saturate( lerp( 0.25f, 1.0f, dot( vNormalWS, vLightDirWS ) ) );

    // Unfortunately sampling textures here blurs the line between the lighting part of the shading and
    // the material part. This is not good.
    // :TODO: Can this be improved?
    HALF fShiftTex  = sample2D( p_sSpecularShiftLayer, READ_INTERPOLANT_UV( 0 ) ).a - 0.5f;   // :TODO: Setup UV emitter.
    HALF3 vTangent1 = ShiftTangent( INTERPOLANT_Tangent.xyz, vNormalWS, p_fPrimaryShift + fShiftTex );
    HALF3 vTangent2 = ShiftTangent( INTERPOLANT_Tangent.xyz, vNormalWS, p_fSecondaryShift + fShiftTex );
    vLightDiffuseSpecular.y = StrandSpecular( vTangent1, INTERPOLANT_EyeToVertex, vLightDirWS, fSpecularPower );
    vLightDiffuseSpecular.z = StrandSpecular( vTangent2, INTERPOLANT_EyeToVertex, vLightDirWS, p_fKajiyaKaySpecularity2 );

    return vLightDiffuseSpecular;
}
#else
//--------------------------------------------------------------------------------------------------
HALF3 KajiyaKayShading( VertexTransport vertOut, HALF3 vNormalWS, HALF3 vLightDirWS,
                        bool bUseSpecular,
                        bool bSpecifyHalfVector, HALF3 vHalfVectorWS, HALF3 vVertexPosWS, HALF3 vLightPosWS, HALF fSpecularPower ) {
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
HALF3 LightShading( VertexTransport vertOut, HALF3 vNormalWS, HALF3 vLightDirWS,
                    bool bUseSpecular,
                    bool bSpecifyHalfVector, HALF3 vHalfVectorWS, float3 vVertexPosWS, HALF3 vLightPosWS,
					HALF fSpecularPower ) {
    if ( b_iLightingModel == BLINN_SHADING )
        return BlinnShading(    vertOut, vNormalWS, vLightDirWS, bUseSpecular, bSpecifyHalfVector, vHalfVectorWS,
                                vVertexPosWS, vLightPosWS, fSpecularPower );
    else if ( b_iLightingModel == KAJIYAKAY_SHADING )
        return KajiyaKayShading(    vertOut, vNormalWS, vLightDirWS, bUseSpecular, bSpecifyHalfVector, vHalfVectorWS,
                                    vVertexPosWS, vLightPosWS, fSpecularPower );
    else return 0;
}

#endif  // _LIGHTINGMODELS