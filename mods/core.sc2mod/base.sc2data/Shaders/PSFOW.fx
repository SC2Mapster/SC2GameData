

//==================================================================================================
//
// Copyright Blizzard Entertainment 2003-2005
//
//==================================================================================================

#ifndef PS_FOW
#define PS_FOW

#ifdef PIXEL_SHADER

#include "ShaderSystem.fx"
#include "Common.fx"

texDecl2D(p_sFOWSampler);

#define FOWMODE_STORM_SMOOTH    0
#define FOWMODE_STORM           1
#define FOWMODE_STAR2           2
#define FOWMODE_RAW             3

float4      p_vFOWLevels;
float3      p_cFOWBlackMaskColor;
HALF        p_fFOWWidth;
HALF        p_fFOWSmoothing;
HALF4       p_cMaterialFOWTint;

//--------------------------------------------------------------------------------------------------
HALF4 ApplyFogOfWar( float2 FOWUV, HALF4 cResult, inout HALF3 cDeferredDiffuse ) {
    HALF4 cFOWFactor;
    if ( b_FOWEnabled ) {
        if ( b_SampleFOW ) {
            if (b_FOWMode == FOWMODE_STORM || b_FOWMode == FOWMODE_STORM_SMOOTH ) {
                if ( !b_FastFOW )
                {
                    cFOWFactor.rgb = saturate(2.0f * sample2D(p_sFOWSampler, FOWUV).rgb);
                    cFOWFactor.a = dot(cFOWFactor.rgb, p_vFOWLevels.rgb);
                }
                else cFOWFactor.a = sample2D(p_sFOWSampler, FOWUV).a;
                cFOWFactor.rgb = p_cFOWBlackMaskColor;
            }  
            else if ( b_FOWMode == FOWMODE_RAW )
            {
                cFOWFactor = sample2D(p_sFOWSampler, FOWUV);
                return HALF4( cFOWFactor.rgb, cResult.a );
            }
        } else
            cFOWFactor = p_cMaterialFOWTint;

        HALF4 cDiffuseFOWFactor = cFOWFactor;

        if (b_useBlendAdd) {
            HALF blendFactor = cResult.a;
            cDeferredDiffuse = lerp(cDeferredDiffuse.rgb, lerp(cDeferredDiffuse.rgb, 1.0f, blendFactor) * cFOWFactor.rgb, cFOWFactor.a);
            return HALF4( lerp(cResult.rgb, lerp(cResult.rgb, 1.0f, blendFactor) * cFOWFactor.rgb, cFOWFactor.a), cResult.a);
        }
        else if (b_FOWAdditiveScale) {
            cDeferredDiffuse = lerp(cDeferredDiffuse.rgb, cDeferredDiffuse.rgb * cDiffuseFOWFactor.rgb, cDiffuseFOWFactor.a);
            return HALF4( lerp(cResult.rgb, cResult.rgb * cFOWFactor.rgb, cFOWFactor.a), cResult.a);
        }
        else {
            cDeferredDiffuse = lerp(cDeferredDiffuse.rgb, cDiffuseFOWFactor.rgb, cDiffuseFOWFactor.a);
            return HALF4( lerp(cResult.rgb, cFOWFactor.rgb, cFOWFactor.a), cResult.a);
        }
    } else return cResult;
}

//--------------------------------------------------------------------------------------------------
HALF4 ApplyFogOfWar( VertexTransport vertOut, HALF4 cResult, inout HALF3 cDeferredDiffuse ) {
    float2 FOWUV;
    FOWUV = Ndc2Tex(INTERPOLANT_FOWUV.xy, true );
    return ApplyFogOfWar( FOWUV, cResult,cDeferredDiffuse );
}

#endif  // PIXEL_SHADER

#endif  // PS_FOW