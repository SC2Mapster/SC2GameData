//==================================================================================================
//
// Copyright Blizzard Entertainment 2003-2005
//
// This is the shader code for the ribbons.
//==================================================================================================

#include "ShaderSystem.fx"
#include "VSElementUtils.fx"

#ifdef VERTEX_SHADER

#include "VSVertexWarp.fx"

#define RIBBON_SIM_GPUONLY                      0
#define RIBBON_SIM_SPLINE_RIBBON                1
#define RIBBON_SIM_MIXED                        2
#define RIBBON_SIM_MIXED_PRECOMPUTED_TANGENT    3
#define RIBBON_SIM_LEGACY                       4

#if defined(COMPILING_SHADER_FOR_OPENGL)
#define BatchIndexType float4
#else
#define BatchIndexType uint4
#endif

#if !CPP_SHADER

#if b_iRibbonSimTech == RIBBON_SIM_SPLINE_RIBBON
struct VertDecl
{
    float4  vPosition                   : POSITION_;        
    HALF2   vUV                         : TEXCOORD0_;
    HALF2	vOffset					    : NORMAL_;
    BatchIndexType iBatchIndex          : TEXCOORD6_;
};
#else
struct VertDecl
{
    float4  vPosition                   : POSITION_;        
#if b_iRibbonSimTech == RIBBON_SIM_LEGACY
    HALF2   vUV                         : TEXCOORD0_;
#endif
    HALF4   vSize					    : TEXCOORD1_;
    HALF4   cColor0					    : COLOR0_;
    HALF4   cColor1                     : COLOR1_;
    HALF4   cColor2                     : TEXCOORD2_;
    HALF3   vRotation                   : TEXCOORD3_;
    HALF2	vOffset					    : NORMAL_;
    HALF3   vUp                         : TEXCOORD4_;
    float4  vInitialVelocity            : TEXCOORD5_;       
    BatchIndexType  iBatchIndex         : TEXCOORD6_;
#if b_iRibbonSimTech == RIBBON_SIM_MIXED_PRECOMPUTED_TANGENT || b_iRibbonSimTech == RIBBON_SIM_LEGACY
    float3  vPositionPrev               : TEXCOORD7_;  
#endif     
#if b_iRibbonSimTech == RIBBON_SIM_LEGACY
    float3  vPositionNext               : TEXCOORD8_;
#endif    
};
#endif

struct Input
{
    float4  vPosition;       
    HALF2   vUV;                 
    HALF4   vSize;		
    HALF4   cColor0;		
    HALF4   cColor1;
    HALF4   cColor2;
    HALF3   vRotation;
    HALF2   vOffset;
    HALF3   vUp;
    float4  vInitialVelocity;
    BatchIndexType iBatchIndex;
    float3  vPositionPrev;
    float3  vPositionNext;
};

Input TranslateVertexLayout (VertDecl layout)
{
	Input input;
	input.vPosition        = layout.vPosition;
	input.iBatchIndex      = layout.iBatchIndex;
	input.vOffset          = layout.vOffset;
	input.vUV              = 0;
	input.vSize            = 0;
	input.cColor0          = 0;
	input.cColor1          = 0;
	input.cColor2          = 0;
	input.vRotation        = 0;
	input.vUp              = 0;
	input.vInitialVelocity = 0;
    input.vPositionPrev    = 0;
    input.vPositionNext    = 0;
#if b_iRibbonSimTech == RIBBON_SIM_SPLINE_RIBBON || b_iRibbonSimTech == RIBBON_SIM_LEGACY
	input.vUV              = layout.vUV;
#endif
#if b_iRibbonSimTech != RIBBON_SIM_SPLINE_RIBBON
	input.vSize            = layout.vSize;
	input.cColor0          = layout.cColor0;
	input.cColor1          = layout.cColor1;
	input.cColor2          = layout.cColor2;
	input.vRotation        = layout.vRotation;
	input.vUp              = layout.vUp;
	input.vInitialVelocity = layout.vInitialVelocity;
#if b_iRibbonSimTech == RIBBON_SIM_MIXED_PRECOMPUTED_TANGENT || b_iRibbonSimTech == RIBBON_SIM_LEGACY
    input.vPositionPrev    = layout.vPositionPrev;
#endif     
#if b_iRibbonSimTech == RIBBON_SIM_LEGACY
    input.vPositionNext    = layout.vPositionNext;
#endif 
#endif
	return input;
}

#else
struct VertLayout
{
    float4  vPosition;
    HALF4   vUV;
    HALF4   vSize;
    HALF4   cColor0;
    HALF4   cColor1;
    HALF4   cColor2;
    HALF3   vRotation;
    HALF2	vOffset;
    HALF3   vUp;
    float4  vInitialVelocity;
    BatchIndexType  iBatchIndex;
    float3  vPositionPrev;
    float3  vPositionNext;
};

Input TranslateVertexLayout (VertDecl layout)
{
    Input input;

    // This is just to make sure b_iRibbonSimTech does not get culled by shader validation
    if (b_iRibbonSimTech == RIBBON_SIM_LEGACY)
        input.vPositionPrev = 0;
    return input;
}
#endif

#include "VSEmitters.fx"
#include "VSUtils.fx"
#include "VSCommon.fx"
#include "VSParallax.fx"
#include "VSVertexWarp.fx"
#include "VSLighting.fx"
#include "VSFog.fx"
#include "VSUVMapping.fx"
#include "RibbonParticleCommon.fx"


#define RIBBON_BILLBOARD    0
#define RIBBON_PLANAR       1
#define RIBBON_CYLINDER     2
#define RIBBON_STAR         3

#define TIME_INTERPOLANT    0
#define LENGTH_INTERPOLANT  1

//==================================================================================================
// Uniform parameters

// Matrices.
float4x4    p_mRibbonInstanceTransform[MAX_BATCHED_RIBBONS];
float4      p_vSystemPhysicsConstants[MAX_BATCHED_RIBBONS];     // x == mass
                                                                // y == 1/mass
                                                                // z == gravity
                                                                // w == drag
float4      p_vLockedStartPositionAndTime[MAX_BATCHED_RIBBONS]; // xyz == clamped start position
                                                                // w == time which needs to be clamped
float4      p_vLockedTailPositionAndTime[MAX_BATCHED_RIBBONS];  // xyz == clamped start position
                                                                // w == time which needs to be clamped
float4      p_vGPURibbonValues[MAX_BATCHED_RIBBONS];            // x == system time of this batch
                                                                // y == uv generation age multiplier
                                                                // z == uv generation add value
                                                                // w == tail clamping time
float3      p_mSplineRibbonControlPoints[4*MAX_BATCHED_RIBBONS];// w == empty right now
float3      p_vSplineRibbonSize[MAX_BATCHED_RIBBONS];           // matches vSize
float4      p_vSplineRibbonColor0[MAX_BATCHED_RIBBONS];         // matches cColor0
float4      p_vSplineRibbonColor1[MAX_BATCHED_RIBBONS];         // matches cColor0
float4      p_vSplineRibbonColor2[MAX_BATCHED_RIBBONS];         // matches cColor0
ArrayDecl(float)       p_fRibbonBatchIndexRemappingTable[MAX_BATCH_INDEX_REMAPPING_TABLE_SIZE];
float4x4    p_mInvPRWorldTransform[MAX_BATCHED_RIBBONS];

//--------------------------------------------------------------------------------------------------
float3 SafeNormalize (float3 v, float3 d) {
    if (length(v) < 0.00001f)
        return d;
        
    return normalize(v);
}


//==================================================================================================
// VERTEX SHADER EMITTERS

//--------------------------------------------------------------------------------------------------
// Homogeneous vPosition.
float4 EmitRibbonHPos( Input vertIn ) {
    // Same as particles.
    return mul( float4(vertIn.vPosition.xyz, 1), p_mVPTransform );
}

//--------------------------------------------------------------------------------------------------
// Homogeneous vPosition as vUV.
float4 EmitRibbonHPosAsUV( Input vertIn ) {
    return mul( float4(vertIn.vPosition.xyz, 1), p_mVPTransform );
}

//--------------------------------------------------------------------------------------------------
// Camera space vPosition.
float3 EmitRibbonViewPos( Input vertIn ) {
    return mul( p_mViewTransform, float4(vertIn.vPosition.xyz, 1) );          // As 3x4
}

//--------------------------------------------------------------------------------------------------
// UVs.
HALF4 EmitRibbonUV( Input vertIn, int index, HALF3 vVertexNormal, int b_iUVMapping[8] ) {
    // note: we're swizzling x and y here. this is because it allows for more effecient vb building inside CRibbon::RenderBatches()
    return GenUV(
            vertIn.vPosition.xyz,            // No local space available.
            vertIn.vPosition.xyz,
            vVertexNormal,
            vVertexNormal, 
            vertIn.vUV.yx, 
            vertIn.vUV.yx,               // No vUV 1.
            vertIn.vUV.xy, 
            vertIn.vUV.xy, 
            index,
            0,
            float3(0,0,0), 
            b_iUVMapping );
}

//--------------------------------------------------------------------------------------------------
HALF4 EmitRibbonNormal( Input vertIn, HALF3 vVertexNormal ) {
    // allways righthanded
    return HALF4(vVertexNormal, 1);
}

//--------------------------------------------------------------------------------------------------
HALF4 EmitRibbonTangent( Input vertIn, HALF3 vVertexTangent ) {
    return HALF4(vVertexTangent,1);
}

//--------------------------------------------------------------------------------------------------
HALF3 EmitRibbonBinormal( Input vertIn, HALF3 vVertexBinormal ) {
    return vVertexBinormal;
}

//--------------------------------------------------------------------------------------------------
HALF4 EmitRibbonVertexColor( Input vertIn, float fAge, int iBatchIndex ) {
    // Same as particles.
    HALF4 cColor;
    
    cColor.rgb = InterpolateValue(
        fAge, 
        vertIn.cColor0.rgb, 
        vertIn.cColor1.rgb, 
        vertIn.cColor2.rgb, 
        p_vMidKeyTimes[iBatchIndex].y, 
        p_vInversedMidKeyTimes[iBatchIndex].y, 
        p_vMidKeyHoldTimes[iBatchIndex].y, 
        b_iRibbonColorInterpolation
    );
    
    cColor.a = InterpolateValue(
        fAge, 
        vertIn.cColor0.a, 
        vertIn.cColor1.a, 
        vertIn.cColor2.a, 
        p_vMidKeyTimes[iBatchIndex].z, 
        p_vInversedMidKeyTimes[iBatchIndex].z, 
        p_vMidKeyHoldTimes[iBatchIndex].z, 
        b_iRibbonColorInterpolation
    );

    if (b_tintRibbonRed)
        cColor = float4(1.0f, 0.0f, 0.0f, 1.0f);

    return cColor;
}

//--------------------------------------------------------------------------------------------------
// eye to vertex
float3 EmitRibbonEyeToVertex(Input vertIn) {
    return normalize(vertIn.vPosition.xyz - p_vEyePos);
}

//--------------------------------------------------------------------------------------------------
// FOW uvs
HALF4 EmitRibbonFOWUV (Input vertIn) {
    return mul(float4(vertIn.vPosition.xyz, 1), p_mFOWMatrix);
}

//==================================================================================================
void RibbonVertexMain( in VertDecl vertLayout, out VertexTransport vertOut ) {
    float fAge;
    HALF3 vVertexNormal;
    HALF3 vVertexTangent;
    HALF3 vVertexBinormal;
    int iBatchIndex = 0;

    Input vertIn = TranslateVertexLayout(vertLayout);
    int b_iUVMapping[8];
    int b_UVRandomOffsetEnable[8];
    InitShader( vertOut, b_iUVMapping, b_UVRandomOffsetEnable );

#if defined(COMPILING_SHADER_FOR_OPENGL) || defined(COMPILING_SHADER_FOR_METAL)
    vertIn.cColor0 = vertIn.cColor0.zyxw;
    vertIn.cColor1 = vertIn.cColor1.zyxw;
    vertIn.cColor2 = vertIn.cColor2.zyxw;
#endif

#ifdef COMPILING_SHADER_FOR_OPENGL
    iBatchIndex = (unsigned int)(vertIn.iBatchIndex.x + 0.1);
    // remap to the proper index -- gpu spline ribbons don't need to do this step
    if (!b_gpuSplineRibbon) {
        iBatchIndex = (unsigned int)(floatRef(p_fRibbonBatchIndexRemappingTable[iBatchIndex]) + 0.1);
    }
#else
#if !CPP_SHADER
    iBatchIndex = vertIn.iBatchIndex.x;
    // remap to the proper index -- gpu spline ribbons don't need to do this step
    if (!b_gpuSplineRibbon) {
        iBatchIndex = floatRef(p_fRibbonBatchIndexRemappingTable[iBatchIndex]);
    }
#endif
#endif

    if (b_compressedVertex) {
        vertIn.vSize = (vertIn.vSize + 1.0f) * 0.5f;
        vertIn.vRotation = (vertIn.vRotation + 1.0f) * 0.5f;

        vertIn.vUV.y = vertIn.vSize.x;

        // ryantodo: pull these from constants
        float3 sizeScalar = float3(10.0f, 10.0f, 10.0f);
        vertIn.vSize.xyz = vertIn.vSize.yzw * sizeScalar;

        // ryantodo: pull these from constants
        float pi = 3.1415926535897932384626433832795f;
        float3 rotationScalar = float3(400 * pi, 400 * pi, 400 * pi);
        float3 rotationOffset = float3(-200 * pi, -200 * pi, -200 * pi);
        vertIn.vRotation.xyz = vertIn.vRotation.xyz * rotationScalar + rotationOffset;
    }

    HALF fSize;

    float3 vNormal = float3(0.0f, 0.0f, 1.0f);
    float3 vTangent;
    float3 vBinormal;
    HALF3  vOffset;

    // spline ribbon path
    if (b_gpuSplineRibbon) {
        fAge = vertIn.vPosition.x;

        float age = saturate(vertIn.vPosition.x);
        float ageSquared = age * age;
        float invAge = saturate(vertIn.vPosition.z);
        float invAgeSquared = invAge * invAge;

        float contractedAge = saturate(vertIn.vPosition.y);
        float contractedAgeSquared = contractedAge * contractedAge;
        float contractedInvAge = saturate(vertIn.vPosition.w);
        float contractedInvAgeSquared = contractedInvAge * contractedInvAge;

        // get the cotnrol points
        float3 cp0 = p_mSplineRibbonControlPoints[iBatchIndex * 4 + 0];
        float3 cp1 = p_mSplineRibbonControlPoints[iBatchIndex * 4 + 1];
        float3 cp2 = p_mSplineRibbonControlPoints[iBatchIndex * 4 + 2];
        float3 cp3 = p_mSplineRibbonControlPoints[iBatchIndex * 4 + 3];

        // calculate the position
        vertIn.vPosition.xyz = invAge * invAgeSquared * cp0;
        vertIn.vPosition.xyz += 3 * age * invAgeSquared * cp1;
        vertIn.vPosition.xyz += 3 * invAge * ageSquared * cp2;
        vertIn.vPosition.xyz += age * ageSquared * cp3;

        // calculate the hodograph
        vTangent = (cp1 - cp0) * contractedInvAgeSquared;
        vTangent += 2 * (cp2 - cp1) * contractedAge * contractedInvAge;
        vTangent += (cp3 - cp2) * contractedAgeSquared;
        vTangent = normalize(vTangent);

        // guess at a plane that can be used as the up vector for the whole spline
        float3 n0 = cross(cp1 - cp0, cp3 - cp0);
        float3 n1 = cross(cp2 - cp3, cp0 - cp3);
        n0 *= (dot (n0, n1) < 0 ? -1.0f : 1.0f);
        n0 += n1;
        n0.x += 1;  // add some bogus value just to force stabilization of near colinear endpoints
        vertIn.vUp.xyz = normalize(n0);

        vertIn.vSize.xyz = p_vSplineRibbonSize[iBatchIndex];
        vertIn.cColor0 = p_vSplineRibbonColor0[iBatchIndex];
        vertIn.cColor1 = p_vSplineRibbonColor1[iBatchIndex];
        vertIn.cColor2 = p_vSplineRibbonColor2[iBatchIndex];
    }

    // normal ribbon path
    else {
        // set to 0 if clamped
        float proceduralScalar = 1.0;

        if (b_precomputedAge) {
            fAge = vertIn.vPosition.w;
        }
        else {
            float ageScalar = 1.0;

            if (!b_ribbonLocalSpace) {
                // clamp the head
                {
                    float ageDelta = p_vLockedStartPositionAndTime[iBatchIndex].w - vertIn.vPosition.w;
                    float4 posChange;
                    posChange.w = p_vGPURibbonValues[iBatchIndex].x - vertIn.vPosition.w;
                    posChange.xyz = p_vLockedStartPositionAndTime[iBatchIndex].xyz - vertIn.vPosition.xyz;
                    // please turn into slt not if...then
                    proceduralScalar = (ageDelta > 0.001) ? 1.0 : 0.0;
                    posChange *= (1.0f - proceduralScalar);
                    vertIn.vPosition += posChange;
                }

                // clamp the tail
                if (b_clampTail) {
                    float ageDelta = p_vLockedTailPositionAndTime[iBatchIndex].w - vertIn.vPosition.w;
                    float3 posChange;
                    posChange.xyz = p_vLockedTailPositionAndTime[iBatchIndex].xyz - vertIn.vPosition.xyz;
                    // please turn into slt not if...then
                    float localProceduralScalar = (ageDelta < -0.001) ? 1.0 : 0.0;

                    posChange *= (1.0f - localProceduralScalar);
                    vertIn.vPosition.xyz += posChange;
                    proceduralScalar *= localProceduralScalar;
                }
            }

            if (b_clampTail) {
                ageScalar = p_vGPURibbonValues[iBatchIndex].w;
            }

            fAge = (p_vGPURibbonValues[iBatchIndex].x - vertIn.vPosition.w) / (vertIn.vInitialVelocity.w - vertIn.vPosition.w);
            fAge = saturate(fAge * ageScalar);
        }

        if (b_proceduralPosition) {
            float fMass = p_vSystemPhysicsConstants[iBatchIndex].x;
            float fInvMass = p_vSystemPhysicsConstants[iBatchIndex].y;
            float fGravity = -p_vSystemPhysicsConstants[iBatchIndex].z;
            float fDrag = p_vSystemPhysicsConstants[iBatchIndex].w;
            float fInvDrag = 1.0f / p_vSystemPhysicsConstants[iBatchIndex].w;
            float3 vOffsetFromOrigin;
            float3 vInstantaneousVelocity;

            float fTime;
            float3 vInitialVelocity;

            fTime = (p_vGPURibbonValues[iBatchIndex].x - vertIn.vPosition.w);
            vInitialVelocity = vertIn.vInitialVelocity.xyz;
            CalculateDisplacmentAndVelocity(fTime, vInitialVelocity, fMass, fInvMass, fDrag, fInvDrag, fGravity, vOffsetFromOrigin, vInstantaneousVelocity);
            vertIn.vPosition.xyz += (proceduralScalar * vOffsetFromOrigin);

            if (b_precomputedTangent) {
                vTangent = vertIn.vPositionPrev.xyz;
                //fAge = vertIn.vPositionPrev.w;
                // test
            }
            else {
                vTangent = -vInstantaneousVelocity;
            }
        }
    } // normal ribbon path

    // transform instanced particles
    if ( b_useModelInstancing )
        vertIn.vPosition.xyz = mul(float4(vertIn.vPosition.xyz, 1), p_mRibbonInstanceTransform[iBatchIndex]).xyz;

    if (b_computeUFromAge) {
        if (b_gpuSplineRibbon) {
            vertIn.vUV.x = 1.0f - fAge;
        }
        else {
            vertIn.vUV.x = 1.0f - (p_vGPURibbonValues[iBatchIndex].y * fAge + p_vGPURibbonValues[iBatchIndex].z);
        }
    }

    fSize = InterpolateValue(
        fAge, 
        vertIn.vSize.x, 
        vertIn.vSize.y, 
        vertIn.vSize.z, 
        p_vMidKeyTimes[iBatchIndex].x, 
        p_vInversedMidKeyTimes[iBatchIndex].x, 
        p_vMidKeyHoldTimes[iBatchIndex].x, 
        b_iRibbonSizeInterpolation
    );

    fSize = fSize * 0.5f;

    if (!b_proceduralPosition && !b_gpuSplineRibbon) {
        HALF3 vPrevSegmentDir = vertIn.vPosition.xyz - vertIn.vPositionPrev.xyz;
        HALF3 vNextSegmentDir = vertIn.vPositionNext.xyz - vertIn.vPosition.xyz;

        // Take average direction of both segments.
        // Note that this is an average vTangent, not the "real" vTangent but this produces smoother results.
        vTangent = vPrevSegmentDir + vNextSegmentDir;

        // make sure our tangent doesn't flip directions on us
        //vTangent = dot(vTangent, vPrevSegmentDir) < 0 ? -vTangent : vTangent;
    }

    vTangent = SafeNormalize(vTangent, float3(1,0,0));
    
    // compute binormal
    if ((!b_splineRibbon) && (!b_proceduralPosition || b_precomputedTangent || b_iRibbonSimTech==RIBBON_SIM_MIXED)) {
        if ( b_iRibbonType == RIBBON_BILLBOARD ) {
            // make sure to put the camera forward into the local space of the ribbon first
            HALF3 cameraDir = p_vCameraDirection.xyz;
            if ( b_ribbonLocalSpace)
                cameraDir.xyz = mul(p_vCameraDirection.xyz, (float3x3)(p_mInvPRWorldTransform[iBatchIndex]));

            vNormal = -cameraDir.xyz;
            vBinormal = SafeNormalize(cross(vNormal, vTangent), float3(0,1,0));
        } 
        else {
            vBinormal = vertIn.vUp.xyz;
            vNormal = SafeNormalize(cross( vTangent, vBinormal ), float3(0,0,1));
        }
    }
    else {
        if ( b_iRibbonType == RIBBON_BILLBOARD ) {
            // make sure to put the camera forward into the local space of the ribbon first
            HALF3 cameraDir = p_vCameraDirection.xyz;
            if ( b_ribbonLocalSpace)
                cameraDir.xyz = mul(p_vCameraDirection.xyz, (float3x3)(p_mInvPRWorldTransform[iBatchIndex]));

            // Flatten on camera plane.
            HALF3 vSegment = normalize(vTangent - cameraDir * dot( vTangent, p_vCameraDirection));

            // Billboard direction is perpendicular to flattened vSegment.
            vBinormal = cross(vSegment, cameraDir);
        }
        else {
            vBinormal = SafeNormalize(cross( vTangent.xyz, vertIn.vUp.xyz), float3(0,1,0));
        }

        vNormal = SafeNormalize(cross( vTangent, vBinormal ), float3(0,0,1));       
    }

    HALF fAngle;
    if ( fAge < p_vMidKeyTimes[iBatchIndex].w )
        fAngle = vertIn.vRotation.x + ( vertIn.vRotation.y - vertIn.vRotation.x ) * fAge / p_vMidKeyTimes[iBatchIndex].w;
    else fAngle = vertIn.vRotation.y + ( vertIn.vRotation.z - vertIn.vRotation.y ) * ( fAge - p_vMidKeyTimes[iBatchIndex].w ) / ( 1.0f - p_vMidKeyTimes[iBatchIndex].w );

    half3x3 mRotation = MakeRotation( fAngle, vTangent );
    vBinormal = mul( vBinormal, mRotation );
    vNormal = mul( vNormal, mRotation );

    if ( b_iRibbonType == RIBBON_BILLBOARD || b_iRibbonType == RIBBON_PLANAR ) {
        vOffset = vertIn.vOffset.y * vBinormal;
        vVertexNormal = vNormal;
        vVertexTangent = -vBinormal;
        vVertexBinormal = -vTangent;        
    } 
    else if ( b_iRibbonType == RIBBON_CYLINDER || b_iRibbonType == RIBBON_STAR ) {
        // Make a basis around the vSegment.
        half3x3 basis = half3x3(
                                    vNormal.x, vNormal.y, vNormal.z,
                                    vTangent.x, vTangent.y, vTangent.z,
                                    vBinormal.x, vBinormal.y, vBinormal.z
                                );
        vOffset = mul( HALF3( vertIn.vOffset.x, 0.0f, vertIn.vOffset.y ), basis ); 

        if (b_iRibbonType == RIBBON_CYLINDER) {
            vOffset = SafeNormalize(vOffset, float3(0,0,1));
        }
    
        // :TODO: Planar ribbons are dual-sided, and thus would require normals on both sides. For this we need to duplicate
        // vertices and double the triangle count.
        vVertexNormal = vOffset;
        vVertexTangent = vTangent;
        vVertexBinormal = cross( vVertexTangent, vVertexNormal );
    }

    vertIn.vPosition.xyz = vertIn.vPosition.xyz + vOffset * fSize;

    if (b_ribbonLocalSpace) {
        vertIn.vPosition.xyz = mul(float4(vertIn.vPosition.xyz, 1.0f), p_mPRWorldTransform[iBatchIndex]).xyz;
        vVertexNormal = mul(vVertexNormal, (float3x3)p_mPRWorldTransform[iBatchIndex]);
        vVertexTangent = mul(vVertexTangent, (float3x3)p_mPRWorldTransform[iBatchIndex]);
        vVertexBinormal = mul(vVertexBinormal, (float3x3)p_mPRWorldTransform[iBatchIndex]);
    }

    if ( b_enableVertexWarps == 1 )
        vertIn.vPosition.xyz = ApplyWarps( float4(vertIn.vPosition.xyz, 1.0) ).xyz;

    HALF3 cVertexSpecularLighting;
    HALF3 cVertexShadowSpecularLighting;
    HALF3 cVertexShadowSpecularLighting2;

    vertOut.HPos = EmitRibbonHPos( vertIn );
    GenInterpolant( WorldPos, float4(vertIn.vPosition.xyz, 1) );
    GenInterpolant( HPosAsUV, EmitRibbonHPosAsUV( vertIn ) );
    GenInterpolant( ViewPos, EmitRibbonViewPos( vertIn ) );
    GenInterpolant( Normal, EmitRibbonNormal( vertIn, vVertexNormal ) );
    GenInterpolant( Tangent, EmitRibbonTangent( vertIn, vVertexTangent ) );
    GenInterpolant( Binormal, EmitRibbonBinormal( vertIn, vVertexBinormal ) );
    GenInterpolant( VertexColor, EmitRibbonVertexColor( vertIn, fAge, iBatchIndex ) );
    GenInterpolant( Diffuse, EmitDiffuse( vertIn.vPosition.xyz, vVertexNormal, HALF4(0,0,0,0), cVertexSpecularLighting, cVertexShadowSpecularLighting, cVertexShadowSpecularLighting2 ) );
    GenInterpolant( Specular, EmitSpecular(cVertexSpecularLighting) );
    GenInterpolant( ShadowDiffuse, EmitShadowDiffuse( vVertexNormal, HALF4(0,0,0,0), cVertexShadowSpecularLighting, cVertexShadowSpecularLighting2 ) );
    GenInterpolant( ShadowSpecular, EmitShadowSpecular(cVertexShadowSpecularLighting) );
    GenInterpolant( ShadowMapUV, EmitShadowMapUV( vertIn.vPosition.xyz ) );
    GenInterpolant( FogColor, EmitFogColor( vertIn.vPosition.xyz ) );
    GenInterpolant( HalfVec, EmitHalfVec( vertIn.vPosition.xyz, 0 ) );
    GenInterpolant( EyeToVertex, EmitRibbonEyeToVertex(vertIn) );
    GenInterpolant( EyeToVertexFresnel, EmitRibbonEyeToVertex(vertIn) );
    GenInterpolant( FOWUV, EmitRibbonFOWUV(vertIn) );

    if(b_usePackedUVEmitter)
    {
#if COMPILING_SHADER_WITH_BSL
        [unroll]
#endif
        for ( int i = 0; i < b_iUVEmitterCount / 2; i++ ) {
            GenInterpolantUV( i, HALF4( EmitRibbonUV( vertIn, i * 2, vVertexNormal, b_iUVMapping).xy, EmitRibbonUV( vertIn, (i * 2) + 1, vVertexNormal, b_iUVMapping ).xy ) );
        }
        if(b_iUVEmitterCount % 2)
            GenInterpolantUV( b_iUVEmitterCount / 2, EmitRibbonUV( vertIn, b_iUVEmitterCount-1, vVertexNormal, b_iUVMapping) );
    }
    else
    {
#if COMPILING_SHADER_WITH_BSL
        [unroll]
#endif
        for ( int i = 0; i < b_iUVEmitterCount; i++ ) {
            GenInterpolantUV( i, EmitRibbonUV( vertIn, i, vVertexNormal, b_iUVMapping ) );
        }
    }

    GenInterpolant( ParallaxVector, EmitParallaxVector(   vertIn.vPosition.xyz, p_vEyePos, 
                                                        INTERPOLANT_Normal.xyz, INTERPOLANT_Tangent.xyz, INTERPOLANT_Binormal.xyz ) );
#ifdef COMPILING_SHADER_FOR_OPENGL
    vertOut.HPos.y *= -1.0;
    vertOut.HPos.z = 2.0 * (vertOut.HPos.z - (0.5 * vertOut.HPos.w));
#endif    
}

#endif  // VERTEX_SHADER

#ifdef PIXEL_SHADER
#include "PSMainShading.fx"
#endif