//==================================================================================================
//
// Copyright Blizzard Entertainment 2003-2006
//
// This is the shader code for fog
//==================================================================================================
#ifndef PS_FOG_H__
#define PS_FOG_H__

#ifdef PIXEL_SHADER


//--------------------------------------------------------------------------------------------------
// Applies fog based on static branch settings.
HALF4 ApplyFog( in VertexTransport vertOut, HALF4 cColor, HALF fAlpha, HALF4 mask ) {
    HALF3 cFogColor = HALF3(0, 0, 0);

    if (b_UseLightingRegions) {
        // blend fog colors according to mask
        cFogColor = p_lightSetups[0].cFogColor * mask.x
                    + p_lightSetups[1].cFogColor * mask.y
                    + p_lightSetups[2].cFogColor * mask.z
                    + p_lightSetups[3].cFogColor * mask.w;
    }
    else {
        // default map fog
        cFogColor = p_cFogColor.xyz;
    }

    if (b_fogScaleByAlpha) {
        // Additive effects.  Bend lighting towards fog color, then towards 0 to actually fade it out.
		HALF fogAtten = saturate( INTERPOLANT_FogColor.w ); // Saturate necessitated by Bug ID: 5032
        float fS = saturate(dot(cColor.rgb, cColor.rgb) * cColor.a);
        cColor.rgb = lerp(cColor.xyz, cFogColor.rgb + cColor.rgb, fogAtten * fS);
        cColor.rgb = lerp(cColor.rgb, (b_useBlendAdd) ? cFogColor.rgb * cColor.a : 0, fogAtten * fogAtten);

    }
    else {
        // Simple case, just color replace
        // 1-minus comes free because the saturate forced a 'mov_sat' anyway.  
        HALF fogAtten = saturate(1 - INTERPOLANT_FogColor.w); // Saturate necessitated by Bug ID: 5032

        // Lerp "to" instead of "from" color saves us from a useless 'mov' instruction on ps_2_0
		cColor.rgb = lerp(cFogColor.rgb, cColor.rgb, fogAtten);
    }

    return cColor;
}

#endif  // PIXELS_SHADER

#endif  // PS_FOG_H__
