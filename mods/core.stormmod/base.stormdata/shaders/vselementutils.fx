//==================================================================================================
//
// Copyright Blizzard Entertainment 2003-2007
//
// Common shader code.
//==================================================================================================

#ifndef VS_ELEMENT_UTILS
#define VS_ELEMENT_UTILS

#ifdef VERTEX_SHADER

//==================================================================================================
// calculate the displacment from a starting position and instantaneous velocity
void CalculateDisplacmentAndVelocity (in float fElapsedTime, in float3 vInitialVelocity, in float fMass, in float fInvMass,
                                      in float fDrag, in float fInvDrag, in float fGravity,
                                      out float3 vDisplacement, out float3 vVelocity) {
    float3 vGravity = float3(0, 0, fGravity);
    float3 vMG = fMass * vGravity;
    float3 vMassTimesGravityOverDrag = vMG * fInvDrag;
    float fExpTerm = exp(-fDrag * fInvMass * fElapsedTime);

    // calculate the displacement
    {
        float3 vTerm0a = -(vInitialVelocity + vMassTimesGravityOverDrag);
        float fTerm0b = fMass * fInvDrag;
        float3 vTerm0 = vTerm0a * fTerm0b * fExpTerm;
        float3 vTerm1 = fElapsedTime * vMassTimesGravityOverDrag;
        float3 vTerm2 = fTerm0b * (vInitialVelocity + vMassTimesGravityOverDrag);
		vDisplacement = vTerm0 - vTerm1 + vTerm2;
    }

    // calculate the instantaneous velocity
    {
        float3 vTerm0 = fInvDrag * fExpTerm * (fDrag * vInitialVelocity + vMG);
        vVelocity = vTerm0 - vMassTimesGravityOverDrag;
    }
}

#endif // VERTEX_SHADER

#endif // VS_ELEMENT_UTILS