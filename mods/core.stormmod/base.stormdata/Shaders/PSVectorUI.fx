//==================================================================================================
//
// Copyright Blizzard Entertainment 2003-2006
//
// This is the shader code forthe displacement effect.
//==================================================================================================

#ifndef PS_VECTORUI
#define PS_VECTORUI

#ifdef PIXEL_SHADER

#include "ShaderSystem.fx"

#include "PSLighting.fx"
#include "PSCommon.fx"

#if (b_iShadingMode == SHADINGMODE_VECTORUI || CPP_SHADER )

// this MUST match SSplatVectorUIInit::SSplatVectorUIInitType
#define VECTORUI_INVALID 0
#define VECTORUI_CIRCLE 1
#define VECTORUI_CRESCENT 2

#define c_fPI 3.141592653589793f
#define c_f2PI 6.2831853071795864f

//--------------------------------------------------------------------------------------------------
void ApplyCircleInfluence (in float2 vPosition, in float2 vCircleCenter, in float4 vCircleRadiiParams, in float4 vCircleDashParams,
                           in HALF4 cLitColor, inout HALF4 cAccumulatedColor) {
        
    float2 vDist;

    vDist = vPosition - vCircleCenter;
    float fDist = length(vDist);

    float finalFactor;
    // calculate the circle factor
    {
        float innerFactor = fDist - (vCircleRadiiParams.x - vCircleRadiiParams.z);
        innerFactor = saturate(innerFactor * vCircleRadiiParams.w);

        float outerFactor = fDist - vCircleRadiiParams.y;
        outerFactor = 1.0f - saturate(outerFactor * vCircleRadiiParams.w);

        finalFactor = innerFactor * outerFactor;
    }

    // calcualte the dashed factor
    if (b_dashedCircleSplats) {
        float2 vDir = normalize(vDist);
        float2 xAxis = vCircleDashParams.zw;
        float2 yAxis = float2(xAxis.y, -xAxis.x);
        float2 vRotatedDir;
        vRotatedDir = (xAxis * vDir.x) + (yAxis * vDir.y);

        float fDashAngle = vCircleDashParams.x;
        float fPercentSolid = vCircleDashParams.y;
        float fAvgRadius = (vCircleRadiiParams.x + vCircleRadiiParams.y) * 0.5f;
        float fInvAvgRadius = 1.0f / fAvgRadius;

        float fSegmentLength = fDashAngle * fAvgRadius;
        float fRange = vCircleRadiiParams.z * fInvAvgRadius;
        float fOuterAngle = (fSegmentLength * fPercentSolid * fInvAvgRadius) - fRange;

        // ryantodo: don't do this in randian space to save on the acos() call
        float fAngle = acos(vRotatedDir.x);
        fAngle = (vRotatedDir.y > 0) ? fAngle : (c_f2PI) - fAngle;
        
        float fPartial = fmod(fAngle, fDashAngle);
        fPartial = max(fPartial, fDashAngle - fPartial);
        float fDashedFactor = saturate((fPartial - fOuterAngle) / fRange);

        finalFactor = min(fDashedFactor, finalFactor);
    }

    HALF4 color = cLitColor * finalFactor;

    if (b_additiveSplat)
        cAccumulatedColor += color;
    else {
        cAccumulatedColor.xyz = lerp(cAccumulatedColor.xyz, color.xyz, color.w);
        cAccumulatedColor.w *= (1.0 - color.w);
    }
}

//--------------------------------------------------------------------------------------------------
void ApplyCrescentInfulence (in float2 vPosition, in float2 vCircleCenter, in float4 vCircleRadiiParams, in float3 vCameraToVert,
                             in float3 vInsideCircleRatios, in HALF4 cLitColor, inout HALF4 cAccumulatedColor) {
    float2 vDist;

    vDist = vPosition - vCircleCenter;
    float fDist = length(vDist);

    float innerFactor = fDist - (vCircleRadiiParams.x - vCircleRadiiParams.z);
    innerFactor = saturate(innerFactor * vCircleRadiiParams.w);

    float outerFactor = fDist - vCircleRadiiParams.y;
    //outerFactor = step(0.01f, 1.0f - saturate(outerFactor * vCircleRadiiParams.w));
    outerFactor = saturate(outerFactor * vCircleRadiiParams.w);
    outerFactor *= outerFactor;
    outerFactor = 1.0 - outerFactor;

    float finalFactor = innerFactor * outerFactor;

    if (b_lowEndShaders) {
        cAccumulatedColor = cLitColor * float4(1.0f, 1.0f, 1.0f, finalFactor * 0.5f);
        cAccumulatedColor.w = 1.0f - cAccumulatedColor.w;
        return;
    }

    HALF4 innerColor = HALF4(cLitColor.x, cLitColor.y, cLitColor.z, cLitColor.w * 0.5f);
    HALF4 edgeColor = HALF4(cLitColor.x, cLitColor.y, cLitColor.z, 1.0f - cLitColor.w);

    //cAccumulatedColor = innerColor * HALF4(outerFactor, outerFactor, outerFactor, outerFactor);
    cAccumulatedColor = innerColor * HALF4(1.0, 1.0, 1.0, outerFactor);
    cAccumulatedColor.w = 1.0f - cAccumulatedColor.w;
    cAccumulatedColor = lerp(cAccumulatedColor, edgeColor, finalFactor);

    float2 vOffset = normalize(vCameraToVert.xy) * vInsideCircleRatios.x * vCircleRadiiParams.y;
    float2 vInnerCircleCenter = vCircleCenter.xy + vOffset;
    vDist = vPosition - vInnerCircleCenter;
    fDist = length(vDist);

    float innerCircleInsideBound = vCircleRadiiParams.y * vInsideCircleRatios.y;
    float innerCircleFalloffDistance = 1.0f / (vCircleRadiiParams.y * vInsideCircleRatios.z);
    float innerCircleFactor = 1.0f - saturate((fDist - innerCircleInsideBound) * innerCircleFalloffDistance);
    cAccumulatedColor.w = lerp(cAccumulatedColor.w, 1.0f, innerCircleFactor);
}

//--------------------------------------------------------------------------------------------------
HALF4 VectorUI(in VertexTransport vertOut) {
    if (b_renderBlack)
        return HALF4(0.0f, 0.0f, 0.0f, 1.0f);

    HALF4 accumulatedColor;
    if (b_additiveSplat)
        accumulatedColor = HALF4(1.0f, 0.0f, 0.0f, 0.0f);
    else
        accumulatedColor = HALF4(0.0f, 0.0f, 0.0f, 1.0f);

    // in theory we could do multiple influences per pixel, but early tests show that isn't optimal
    if ( PIXEL_SHADER_VERSION >= SHADER_VERSION_PS_20 ) {
        if (b_iDrawType == VECTORUI_CIRCLE) {

            // INTERPOLANT_VectorUI0 == camera position
            // INTERPOLANT_VectorUI1 == x == inner radius, y == outer radius, z == falloff, w == 1/falloff
            // INTERPOLANT_VectorUI2 == x == segment count, y == percent solid, (z,w) == rotation axis
            ApplyCircleInfluence(INTERPOLANT_WorldPos.xy, INTERPOLANT_VectorUI0.xy, INTERPOLANT_VectorUI1, INTERPOLANT_VectorUI2,
                INTERPOLANT_VertexColor, accumulatedColor);
        }
        else if (b_iDrawType == VECTORUI_CRESCENT) {

            // INTERPOLANT_VectorUI0 == camera position
            // INTERPOLANT_VectorUI1 == x == inner radius, y == outer radius, z == falloff, w == 1/falloff
            // INTERPOLANT_VectorUI2 == x == inner offset ratio, y == inner boundry ratio, z == inner buondry falloff ratio
            ApplyCrescentInfulence(INTERPOLANT_WorldPos.xy, INTERPOLANT_VectorUI0.xy, INTERPOLANT_VectorUI1, INTERPOLANT_EyeToVertex,
                INTERPOLANT_VectorUI2.xyz, INTERPOLANT_VertexColor, accumulatedColor);
        }

        else {
            // haven't implemented any other primitives yet
            return HALF4(1.0f, 0.0f, 0.0f, 1.0f);
        }
    }

    if (b_additiveSplat)
        accumulatedColor = saturate(accumulatedColor);
    else
        accumulatedColor = saturate(HALF4(accumulatedColor.xyz, 1.0f - accumulatedColor.w));

    // attenuation factor
    accumulatedColor.w *= SplatAttenuationVectorUI(INTERPOLANT_WorldPos.xyz, INTERPOLANT_Vector4, INTERPOLANT_VectorUI0.w, INTERPOLANT_WorldPos.w);
        
    return accumulatedColor;
}

#else
HALF4 VectorUI(in VertexTransport vertOut) { return 0;      }
#endif  // b_iShadingMode == SHADINGMODE_VECTORUI

#endif // PIXEL_SHADER

#endif  // PS_VECTORUI