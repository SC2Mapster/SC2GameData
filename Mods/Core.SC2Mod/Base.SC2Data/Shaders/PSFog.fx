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
half4 ApplyFog( in VertexTransport vertOut, half4 cColor, half fAlpha ) {
    // why is it that if we saturate the output from the VS we still get FP specials and I have to do this sat in the PS? evil.
    float4 saturatedFog = saturate(INTERPOLANT_FogColor);

    if (b_fogScaleByAlpha) {
        float fS = saturate(dot(cColor.rgb, cColor.rgb));
        cColor.rgb = lerp(cColor.xyz, saturatedFog.rgb+cColor.rgb, saturatedFog.a*fS);
    }
    else {
        half3 cFogCol;
        
        if ( fAlpha < 1.0f ) {
            // interesting: neither 'vertOut.cFogColor.xyz' nor 'fAlpha' causes FP excpetions
            // but 'VertOut.cFogColor.xyz*fAlpha' does. had to use a 'saturate' here.
            cFogCol = saturate(saturatedFog.xyz*fAlpha);
        }
        else {
            cFogCol = saturatedFog.rgb;
        }
        
        cColor.rgb = lerp(cColor.rgb, cFogCol, saturatedFog.a);
    }
    
    return cColor;
}

#endif  // PIXELS_SHADER

#endif  // PS_FOG_H__
