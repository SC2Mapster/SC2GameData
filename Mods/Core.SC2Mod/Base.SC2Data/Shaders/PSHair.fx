//==================================================================================================
//
// Copyright Blizzard Entertainment 2003-2006
//
// This is the shader code forthe displacement effect.
//==================================================================================================

#ifndef PS_HAIR
#define PS_HAIR

#ifdef PIXEL_SHADER

#if ( b_iShadingMode == SHADINGMODE_HAIR || CPP_SHADER )

#include "ShaderSystem.fx"
#include "PSCommon.fx"

#define PASS_HAIR_SHADING    0

DECLARE_LAYER( HairBase );
DECLARE_LAYER( SpecularMask );
//DECLARE_LAYER( HairNormal );
//DECLARE_LAYER( HairAmbientOcclusion );

//--------------------------------------------------------------------------------------------------
half4 HairShading( in VertexTransport vertOut ) {
    if ( b_iHairPass == PASS_HAIR_SHADING ) {
        haf3 vTextureNormal;
        half3 vNormalWS;

        // :TODO: Do we use normal mapping?
        /*
        if ( b_useNormalMapping ) {
            vTextureNormal  = DecodeTextureNormal( p_sHairNormalSampler, GetUVEmitter(vertOut, b_iHairNormalUVEmitter), fStub );
            vNormalWS       = TangentToWorld( vTextureNormal, INTERPOLANT_Normal.xyz, INTERPOLANT_Tangent.xyz, INTERPOLANT_Binormal.xyz, false );
        } else */
        {
            vTextureNormal = INTERPOLANT_Normal;
            vNormalWS = INTERPOLANT_Normal;
        }

        half3 vTangent1 = ShiftTangent( INTERPOLANT_Tangent.xyz, vNormalWS, p_fPrimaryShift + fShiftTex );
        half3 vTangent2 = ShiftTangent( INTERPOLANT_Tangent.xyz, vNormalWS, p_fSecondaryShift + fShiftTex );

        half3 cDiffuse = saturate( lerp( 0.25f, 1.0f, dot( vNormalWS, vLightVec ) ) * p_cDiffuseColor;

        // :TODO: How do I integrate the lights?
        half3 vLightVec = 0;
        half3 cSpecular = p_cSpecularColor1 * StrandSpecular( vTangent1, INTERPOLANT_View, vLightVec, p_fSpecularExponent1 );
        half fSpecMask = GetLayerColor( SpecularMask, 1.0f ).a ;
        fSpecular += p_cSpecularColor2 * fSpecMask * StrandSpecular( vTangent2, INTERPOLANT_View, vLightVec, p_fSpecularExponent2 );

        half4 cBaseColor = GetLayerColor( HairBase, 1.0f ).rgb;
        half4 cOutput;
        cOutput.rgb = ( cDiffuse + cSpecular ) * cBaseColor.rgb;
        // :TODO: AO term?
        //output.rgb *= GetLayerColor( HairAmbientOcclusion, 1.0f ).a;
        cOutput.a = cBaseColor.a;
        return cOutput;
    } 
}

#endif  // b_iShadingMode == PASS_HAIR_SHADING

#endif  // PIXEL_SHADER

#endif  // PS_HAIR