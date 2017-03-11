//==================================================================================================
//
// Copyright Blizzard Entertainment 2003-2005
//
// This is the shared shader code for the ribbons and particles.
//==================================================================================================

#include "ShaderSystem.fx"

#ifndef _PARTICLERIBBONCOMMON
#define _PARTICLERIBBONCOMMON

#define ITERPOLATION_LINEAR                         0       // e_imLinear
#define ITERPOLATION_LINEAR_SMOOTH                  1       // e_imLinearSmooth
#define ITERPOLATION_BEZIER                         2       // e_imBezier
#define ITERPOLATION_LINEAR_WITH_HOLD               3       // e_imLinearWithHold
#define ITERPOLATION_BEZIER_WITH_HOLD               4       // e_imBezierWithHold


float4x4    p_mPRWorldTransform[MAX_BATCHED_RIBBONS];

// ryantodo: optimize these into fewer constants
float4      p_vMidKeyTimes[MAX_BATCHED_RIBBONS];                // x == scale midkey
                                                                // y == color midkey
                                                                // z == alpha midkey
                                                                // w == rotation midkey
float4      p_vInversedMidKeyTimes[MAX_BATCHED_RIBBONS];
float4      p_vMidKeyHoldTimes[MAX_BATCHED_RIBBONS];

//--------------------------------------------------------------------------------------------------


//--------------------------------------------------------------------------------------------------
float InterpolateValue (
    float age, 
    float value0, 
    float value1, 
    float value2, 
    float midTime,
    float inversedMidTime,
    float midTimeHold, 
    int   interpolation
) {
    float ret=value0;

    // quadratic bezier
    if (interpolation==ITERPOLATION_BEZIER) {
        ret = BezierInterpolation(value0, value1, value2, age);
    }
    // linear interpolation
    else if (interpolation==ITERPOLATION_LINEAR) {
        if ( age < midTime ) {
            float fT = age * inversedMidTime;
            ret = lerp(value0, value1, fT);
        }
        else {
            float fT = ( age - midTime ) / ( 1.0f - midTime );
            ret = lerp(value1, value2, fT);
        }
    }
    // linear with smoothed time
    else if (interpolation==ITERPOLATION_LINEAR_SMOOTH) {
        if ( age < midTime ) {
            float fT = age * inversedMidTime;
            fT = SmoothStep( fT );
            ret = lerp(value0, value1, fT);
        }
        else {
            float fT = ( age - midTime ) / ( 1.0f - midTime );
            fT = SmoothStep( fT );
            ret = lerp(value1, value2, fT);
        }
    }
    // linear with hold
    else if (interpolation==ITERPOLATION_LINEAR_WITH_HOLD) {
        float t0 = (midTime-midTimeHold);
        float t1 = (midTime+midTimeHold);
        if (age < t0) {
            ret = lerp(value0, value1, age / t0 );
        }
        else if (age < t1) {
            ret = value1;
        }
        else {
            ret = lerp(value1, value2, ( age - t1 ) / ( 1.0f - t1 ));
        }
    }
    // bezier with hold (2 piecewise quadratic bezier)
    else if (interpolation==ITERPOLATION_BEZIER_WITH_HOLD) {
        float t0 = (midTime-midTimeHold);
        float t1 = (midTime+midTimeHold);
        
        if (age < t0) {
            age = age / t0;
            value2 = value1;
        }
        else {
            age = (age - t1) / (1.0f - t1);
            value0 = value1;
        }
		age = saturate(age);
        
        ret = BezierInterpolation(value0, value1, value2, age);
    }

    return ret;
}

//--------------------------------------------------------------------------------------------------
float3 InterpolateValue (
    float age, 
    float3 value0, 
    float3 value1, 
    float3 value2, 
    float midTime, 
    float inversedMidTime,
    float midTimeHold, 
    int interpolation
) {
    float3 ret=value0;

    // quadratic bezier
    if (interpolation==ITERPOLATION_BEZIER) {
        ret = BezierInterpolation(value0, value1, value2, age);
    }
    // linear interpolation
    else if (interpolation==ITERPOLATION_LINEAR) {
        if ( age < midTime ) {
            float fT = age * inversedMidTime;
            ret = lerp(value0, value1, fT);
        }
        else {
            float fT = ( age - midTime ) / ( 1.0f - midTime );
            ret = lerp(value1, value2, fT);
        }
    }
    // linear with smoothed time
    else if (interpolation==ITERPOLATION_LINEAR_SMOOTH) {
        if ( age < midTime ) {
            float fT = age * inversedMidTime;
            fT = SmoothStep( fT );
            ret = lerp(value0, value1, fT);
        }
        else {
            float fT = ( age - midTime ) / ( 1.0f - midTime );
            fT = SmoothStep( fT );
            ret = lerp(value1, value2, fT);
        }
    }
    // linear with hold
    else if (interpolation==ITERPOLATION_LINEAR_WITH_HOLD) {
        float t0 = (midTime-midTimeHold);
        float t1 = (midTime+midTimeHold);
        if (age < t0) {
            ret = lerp(value0, value1, age / t0 );
        }
        else if (age < t1) {
            ret = value1;
        }
        else {
            ret = lerp(value1, value2, ( age - t1 ) / ( 1.0f - t1 ));
        }
    }
    // bezier with hold (2 piecewise quadratic bezier)
    else if (interpolation==ITERPOLATION_BEZIER_WITH_HOLD) {
        float t0 = (midTime-midTimeHold);
        float t1 = (midTime+midTimeHold);
        if (age < t0) {
            ret = BezierInterpolation(value0, lerp(value0, value1, midTimeHold), value1, age/t0);
        }
        else if (age < t1) {
            ret = value1;
        }
        else {
            ret = BezierInterpolation(value1, lerp(value1, value2, midTimeHold), value2, ( age - t1 ) / ( 1.0f - t1 ));
        }
    }

    return ret;
}


#endif  // _PARTICLERIBBONCOMMON