//==================================================================================================
//
// Copyright Blizzard Entertainment 2003-2005
//
//==================================================================================================

#ifndef PS_DEBUG
#define PS_DEBUG

#ifdef PIXEL_SHADER

#include "ShaderSystem.fx"
#include "PSDebugModes.fx"

#if ( b_iDebugMode != NO_DEBUG || CPP_SHADER )

HALF2 p_vDiffuseTextureSize;
HALF4 p_cDebugColor;

//--------------------------------------------------------------------------------------------------
half4 DebugColor(   half3 cDiffuse, half3 cSpecular, half3 cEmissive, half3 vNormalMap, half3 vNormal, 
                    half3 cLightDiffuse, half3 cLightSpecular, half4 cShadowColor, half fAOValue, half fAlpha,
                    half3 vDiffuseUV,
                    half fModulate, in VertexTransport vertOut, in half4 cFinal ) {
    if ( b_iDebugMode == FULLBRIGHT_DIFFUSE_ONLY ) {
        return half4( cDiffuse, fAlpha );
    }
    if ( b_iDebugMode == LIGHTING_ONLY ) {
        return half4( ( cLightDiffuse + cLightSpecular ) * fModulate, fAlpha );
    }
    if ( b_iDebugMode == DIFFUSE_ONLY ) {
        return half4( cDiffuse * cLightDiffuse, fAlpha );
    }
    if ( b_iDebugMode == SPECULAR_ONLY ) {
        return half4( cSpecular * cLightSpecular, fAlpha );
    }
    if ( b_iDebugMode == EMISSIVE_ONLY ) {
        return half4( cEmissive * fModulate, fAlpha );
    }
    if ( b_iDebugMode == DIFFUSE_LIGHTING_ONLY ) {
        return half4( cLightDiffuse * fModulate, fAlpha );
    }
    if ( b_iDebugMode == SPECULAR_LIGHTING_ONLY ) {
        return half4( cLightSpecular * fModulate, fAlpha );
    }
    if ( b_iDebugMode == ALPHAMASK_ONLY ) {
	    return half4( 1.0f, 1.0f, 1.0f, fAlpha );
    }
    if ( b_iDebugMode == NORMALS_ONLY ) {
        return half4( ( vNormal * 0.5f + 0.5f ) * fModulate, fAlpha );
    }
    if ( b_iDebugMode == NORMALMAP_ONLY ) {
        return half4( ( vNormalMap * 0.5f + 0.5f ) * fModulate, fAlpha );
    }
    if ( b_iDebugMode == SHADOWS_ONLY ) {
        return half4( cShadowColor.rgb * fModulate, fAlpha );
    }
    if ( b_iDebugMode == SHOW_PROBLEMS ) {
		//return half4(INTERPOLANT_Tangent.xyz*0.5+0.5,1);
        float returnValue = 0.0f;
        if ( b_useNormalMapping && b_useLighting ) 
        {
            return float4(INTERPOLANT_Binormal.xyz*0.5 + 0.5, 1);
            if (length(INTERPOLANT_Tangent.xyz) < 0.00001f)
                returnValue = 1.0f;
            if ( b_useCompressedBasis == 0 ) {
                if (length(INTERPOLANT_Binormal.xyz) < 0.00001f)
                    returnValue = 1.0f;
            }
        }
        return lerp(cFinal, half4(1.0f, 0.0f, 1.0f, 1.0f), returnValue);
    }
    if ( b_iDebugMode == AMBIENT_OCCLUSION_ONLY ) {
        if (b_UseVertexBasedAmbientOcclusion)
            fAOValue = INTERPOLANT_VertexColor.a;
        return half4( fAOValue * fModulate, fAOValue * fModulate, fAOValue * fModulate, fAlpha );
    }
    if ( b_iDebugMode == LIGHTING_OVERLAP ) {
		return 0;
    }
    if ( b_iDebugMode == OVERDRAW ) {
		return 1.0f / 16.0f;
    }
    if ( b_iDebugMode == TEXEL_DENSITY ) {
		half gradientX = length( ddx( vDiffuseUV.xy * p_vDiffuseTextureSize ) );
		half gradientY = length( ddy( vDiffuseUV.xy * p_vDiffuseTextureSize ) );
        half scalarGradient = gradientX * gradientY;
        if ( scalarGradient == 0.0f )
            return 0;
        if ( scalarGradient < 1.0f )    // Insufficient density.
            return half4( lerp( half4( 1.0f, 0.0f, 0.0f, 1.0f ), half4( 0.0f, 1.0f, 0.0f, 1.0f ), 
                                saturate( scalarGradient - 0.5f ) * 2.0f ) );
        else if ( scalarGradient >= 4.0f )                         // Too much density.
            return half4( lerp( half4( 0.0f, 1.0f, 0.0f, 1.0f ), half4( 0.0f, 0.0f, 1.0f, 1.0f ), saturate( ( scalarGradient - 4.0f ) / 4.0f ) ) );
        else return half4( 0.0f, 1.0f, 0.0f, 1.0f );
    }
    if ( b_iDebugMode == UV_MAPPING )
        return half4( frac( vDiffuseUV.x ), frac( vDiffuseUV.y ), frac( vDiffuseUV.z ), 1.0f );
    if ( b_iDebugMode == LIGHT_COUNT || b_iDebugMode == STATIC_SHADOW_STATUS )
		return p_cDebugColor;

    return 0;
}

#else

//--------------------------------------------------------------------------------------------------
half4 DebugColor(   half3 cDiffuse, half3 cSpecular, half3 cEmissive, half3 vNormalMap, half3 vNormal, 
                    half3 cLightDiffuse, half3 cLightSpecular, half4 cShadowColor, half fAOValue, half fAlpha,
                    half3 vDiffuseUV, 
                    half fModulate, in VertexTransport vertOut, in half4 cFinal ) {
    return 0;
}

#endif  // b_iDebugMode != NO_DEBUG
    
#endif  // PIXEL_SHADER

#endif  // PS_DEBUG