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

HALF4 p_cDebugColor;

#if ( b_iDebugMode != NO_DEBUG || CPP_SHADER )

HALF2 p_vDiffuseTextureSize;
HALF4 p_cLightingRegionsUsed;


//--------------------------------------------------------------------------------------------------
HALF4 DebugColor(   HALF3 cDiffuse, HALF3 cSpecular, HALF3 cEmissive, HALF3 vNormalMap, HALF3 vNormal, 
                    HALF3 cLightDiffuse, HALF3 cLightSpecular, HALF4 cShadowColor, HALF fAOValue, HALF fAlpha,
                    HALF3 vDiffuseUV,
                    HALF fModulate, in VertexTransport vertOut, in HALF4 cFinal, in HALF4 cDebugColor, 
                    in HALF fSpecularity, in HALF4 cLightingRegionMap ) {
    if ( b_iDebugMode == FULLBRIGHT_DIFFUSE_ONLY ) {
        return HALF4( cDiffuse, fAlpha );
    }
    if ( b_iDebugMode == LIGHTING_ONLY ) {
        return HALF4( ( cLightDiffuse + cLightSpecular ) * fModulate, fAlpha );
    }
    if ( b_iDebugMode == DIFFUSE_ONLY ) {
        return HALF4( cDiffuse * cLightDiffuse, fAlpha );
    }
    if ( b_iDebugMode == SPECULAR_ONLY ) {
        return HALF4( cSpecular * cLightSpecular, fAlpha );
    }
    if ( b_iDebugMode == EMISSIVE_ONLY ) {
        return HALF4( cEmissive * fModulate, fAlpha );
    }
    if ( b_iDebugMode == DIFFUSE_LIGHTING_ONLY ) {
        return HALF4( cLightDiffuse * fModulate, fAlpha );
    }
    if ( b_iDebugMode == SPECULAR_LIGHTING_ONLY ) {
        return HALF4( cLightSpecular * fModulate, fAlpha );
    }
	if ( b_iDebugMode == SPECULAR_GLOSS ) {
	    return fSpecularity / 256.0;
	}
	if ( b_iDebugMode == LIGHTING_REGION_MAP ) {
	    HALF4 cSample;
	    if ( b_UseLightingRegions )
	        cSample = cLightingRegionMap;
	    else
	        cSample = p_cLightingRegionsUsed;
	    return cSample;
	}
    if ( b_iDebugMode == ALPHAMASK_ONLY ) {
	    return HALF4( 1.0f, 1.0f, 1.0f, fAlpha );
    }
    if ( b_iDebugMode == NORMALS_ONLY ) {
        return HALF4( ( vNormal * 0.5f + 0.5f ) * fModulate, fAlpha );
    }
    if ( b_iDebugMode == NORMALMAP_ONLY ) {
        return HALF4( ( vNormalMap * 0.5f + 0.5f ) * fModulate, fAlpha );
    }
    if ( b_iDebugMode == SHADOWS_ONLY ) {
        return HALF4( cShadowColor.rgb * fModulate, fAlpha );
    }
    if ( b_iDebugMode == SHOW_PROBLEMS ) {
		//return HALF4(INTERPOLANT_Tangent.xyz*0.5+0.5,1);
        float returnValue = 0.0f;
        if ( b_useNormalMapping && b_useLighting ) 
        {
            return float4(INTERPOLANT_Binormal.xyz*0.5 + 0.5, 1);
        }
        return lerp(cFinal, HALF4(1.0f, 0.0f, 1.0f, 1.0f), returnValue);
    }
    if ( b_iDebugMode == AMBIENT_OCCLUSION_ONLY ) {
        if (b_UseVertexBasedAmbientOcclusion) {
            fAOValue = INTERPOLANT_VectorUI1.a;
        }
        return HALF4( fAOValue * fModulate, fAOValue * fModulate, fAOValue * fModulate, fAlpha );
    }
    if ( b_iDebugMode == LIGHTING_OVERLAP ) {
		return 0;
    }
    if ( b_iDebugMode == OVERDRAW ) {
		return 1.0f / 16.0f;
    }
#ifndef COMPILING_SHADER_FOR_OPENGL
    if ( b_iDebugMode == TEXEL_DENSITY ) {
		HALF gradientX = length( ddx( vDiffuseUV.xy * p_vDiffuseTextureSize ) );
		HALF gradientY = length( ddy( vDiffuseUV.xy * p_vDiffuseTextureSize ) );
        HALF scalarGradient = gradientX * gradientY;
        if ( scalarGradient == 0.0f )
            return 0;
        if ( scalarGradient < 1.0f )    // Insufficient density.
            return HALF4( lerp( HALF4( 1.0f, 0.0f, 0.0f, 1.0f ), HALF4( 0.0f, 1.0f, 0.0f, 1.0f ), 
                                saturate( scalarGradient - 0.5f ) * 2.0f ) );
        else if ( scalarGradient >= 4.0f )                         // Too much density.
            return HALF4( lerp( HALF4( 0.0f, 1.0f, 0.0f, 1.0f ), HALF4( 0.0f, 0.0f, 1.0f, 1.0f ), saturate( ( scalarGradient - 4.0f ) / 4.0f ) ) );
        else return HALF4( 0.0f, 1.0f, 0.0f, 1.0f );
    }
#endif
    if ( b_iDebugMode == UV_MAPPING )
        return HALF4( frac( vDiffuseUV.x ), frac( vDiffuseUV.y ), frac( vDiffuseUV.z ), 1.0f );
    if ( b_iDebugMode == LIGHT_COUNT || b_iDebugMode == STATIC_SHADOW_STATUS )
		return cDebugColor;

    return 0;
}

#else

//--------------------------------------------------------------------------------------------------
HALF4 DebugColor(   HALF3 cDiffuse, HALF3 cSpecular, HALF3 cEmissive, HALF3 vNormalMap, HALF3 vNormal, 
                    HALF3 cLightDiffuse, HALF3 cLightSpecular, HALF4 cShadowColor, HALF fAOValue, HALF fAlpha,
                    HALF3 vDiffuseUV, 
                    HALF fModulate, in VertexTransport vertOut, in HALF4 cFinal, in HALF4 cDebugColor, 
                    in HALF fSpecularity, in HALF4 cLightingRegionMap ) {
    return 0;
}

#endif  // b_iDebugMode != NO_DEBUG
    
#endif  // PIXEL_SHADER

#endif  // PS_DEBUG