//==================================================================================================
//
// Copyright Blizzard Entertainment 2003-2005
//
// This is the shared shader code for the ribbons and particles.
//==================================================================================================

#include "ShaderSystem.fx"

#ifndef _PARTICLERIBBONCOMMON
#define _PARTICLERIBBONCOMMON

float4x4    p_mPRWorldTransform[MAX_BATCHED_RIBBONS];

// ryantodo: optimize these into fewer constants
float4      p_vMidKeyTimes[MAX_BATCHED_RIBBONS];                // x == scale midkey
                                                                // y == color midkey
                                                                // z == alpha midkey
                                                                // w == rotation midkey
int         g_iBatchIndex;

#endif  // _PARTICLERIBBONCOMMON