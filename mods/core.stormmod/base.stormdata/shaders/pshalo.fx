//==================================================================================================
//
// Copyright Blizzard Entertainment 2003-2012
//
// Utility functions for halo rendering
//==================================================================================================

HALF4 GetHaloColor( float2 vUV, HALF4 cColor, float fStrobeOffset, float fStrobeSizeRcp, float fStrobeFalloff ) {
    HALF4 cResult = cColor;    
    float Dist = (abs(vUV.y - fStrobeOffset) * fStrobeSizeRcp);
    cResult.rgb *= saturate(max(1.0 - pow(Dist, fStrobeFalloff),0.0) + cColor.a);
    cResult.a = 1.0;
    return cResult;
}
