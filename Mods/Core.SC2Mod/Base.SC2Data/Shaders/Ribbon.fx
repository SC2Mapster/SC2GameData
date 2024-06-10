//==================================================================================================
//
// Copyright Blizzard Entertainment 2003-2005
//
// This is the shader code for the ribbons.
//==================================================================================================

#include "ShaderSystem.fx"
#include "VSElementUtils.fx"

#ifdef VERTEX_SHADER

#include "RibbonParticleCommon.fx"
#include "VSVertexWarp.fx"

#if !CPP_SHADER

//==================================================================================================
// Input structure
struct Input
{
    float4  vPosition                   : POSITION_;        // w == birth time
    half2   vUV                         : TEXCOORD0_;

    // this block maps to SRibbonVertexStaticBase
    half4   vSize                       : TEXCOORD1_;
    half4   cColor0                     : COLOR0_;
    half4   cColor1                     : COLOR1_;
    half4   cColor2                     : TEXCOORD2_;
    half4   vRotation                   : TEXCOORD3_;
    half2   vOffset                     : NORMAL_;
    half4   vUp                         : TEXCOORD4_;
    float4  vInitialVelocity            : TEXCOORD5_;       // w == death time

#ifdef COMPILING_SHADER_FOR_OPENGL
    float4  iBatchIndex                 : TEXCOORD6_;
#else
    int4    iBatchIndex                 : TEXCOORD6_;
#endif

    // these two items are not filled in if using procedural position
    float4  vPositionPrev               : TEXCOORD7_;       // for pre-calculated tangent, then w is the age
    float3  vPositionNext               : TEXCOORD8_;       // store something in w?
};

#endif

#include "VSEmitters.fx"
#include "VSUtils.fx"
#include "VSCommon.fx"
#include "VSParallax.fx"
#include "VSVertexWarp.fx"
#include "VSLighting.fx"
#include "VSFog.fx"
#include "VSUVMapping.fx"

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
float       p_fRibbonBatchIndexRemappingTable[MAX_BATCH_INDEX_REMAPPING_TABLE_SIZE];
float4x4    p_mInvPRWorldTransform[MAX_BATCHED_RIBBONS];

float       g_fAge;
float       g_fAgeNext;
float       g_fAgePrev;

// Reminder: vTangent is along U, vBinormal is along V.
HALF3 g_vVertexNormal;
HALF3 g_vVertexTangent;
HALF3 g_vVertexBinormal;

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
half4 EmitRibbonUV( Input vertIn, int index ) {
    // note: we're swizzling x and y here. this is because it allows for more effecient vb building inside CRibbon::RenderBatches()
    return GenUV(
            vertIn.vPosition.xyz,            // No local space available.
            vertIn.vPosition.xyz,
            g_vVertexNormal, 
            vertIn.vUV.yx, 
            vertIn.vUV.yx,               // No vUV 1.
            vertIn.vUV.xy, 
            vertIn.vUV.xy, 
            b_iUVMapping[index], 
            b_UVTransformEnable[index],
            p_mUVTransform[index],
            0 );
}

//--------------------------------------------------------------------------------------------------
half4 EmitRibbonNormal( Input vertIn ) {
    // allways righthanded
    return half4(g_vVertexNormal, 1);
}

//--------------------------------------------------------------------------------------------------
half4 EmitRibbonTangent( Input vertIn ) {
    return half4(g_vVertexTangent,1);
}

//--------------------------------------------------------------------------------------------------
half3 EmitRibbonBinormal( Input vertIn ) {
    return g_vVertexBinormal;
}

//--------------------------------------------------------------------------------------------------
half4 EmitRibbonVertexColor( Input vertIn ) {
    // Same as particles.
    half4 cColor;
    if ( g_fAge < p_vMidKeyTimes[g_iBatchIndex].y )
        cColor.rgb = vertIn.cColor0.rgb + ( vertIn.cColor1.rgb - vertIn.cColor0.rgb ) * g_fAge / p_vMidKeyTimes[g_iBatchIndex].y;
    else cColor.rgb = vertIn.cColor1.rgb + ( vertIn.cColor2.rgb - vertIn.cColor1.rgb ) * ( g_fAge - p_vMidKeyTimes[g_iBatchIndex].y ) / ( 1.0f - p_vMidKeyTimes[g_iBatchIndex].y );
    if ( g_fAge < p_vMidKeyTimes[g_iBatchIndex].z )
        cColor.a = vertIn.cColor0.a + ( vertIn.cColor1.a - vertIn.cColor0.a ) * g_fAge / p_vMidKeyTimes[g_iBatchIndex].z;
    else cColor.a = vertIn.cColor1.a + ( vertIn.cColor2.a - vertIn.cColor1.a ) * ( g_fAge - p_vMidKeyTimes[g_iBatchIndex].z ) / ( 1.0f - p_vMidKeyTimes[g_iBatchIndex].z );

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
half4 EmitRibbonFOWUV (Input vertIn) {
    return mul(float4(vertIn.vPosition.xyz, 1), p_mFOWMatrix);
}

//==================================================================================================
void RibbonVertexMain( in Input vertIn, out VertexTransport vertOut ) {
    InitShader( vertOut );
#ifdef COMPILING_SHADER_FOR_OPENGL
    vertIn.cColor0 = vertIn.cColor0.zyxw;
    vertIn.cColor1 = vertIn.cColor1.zyxw;
    vertIn.cColor2 = vertIn.cColor2.zyxw;
    g_iBatchIndex = (int)(vertIn.iBatchIndex.x + 0.1);
    // remap to the proper index -- gpu spline ribbons don't need to do this step
    if (!b_gpuSplineRibbon) {
        g_iBatchIndex = (int)(p_fRibbonBatchIndexRemappingTable[g_iBatchIndex] + 0.1);
    }
#else
    g_iBatchIndex = vertIn.iBatchIndex.x;
    // remap to the proper index -- gpu spline ribbons don't need to do this step
    if (!b_gpuSplineRibbon) {
        g_iBatchIndex = p_fRibbonBatchIndexRemappingTable[g_iBatchIndex];
    }
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

    half fSize;
    half fT;

    float3 vNormal;
    float3 vTangent;
    float3 vBinormal;
    half3  vOffset;

    // spline ribbon path
    if (b_gpuSplineRibbon) {
        g_fAge = vertIn.vPosition.x;

        float age = saturate(vertIn.vPosition.x);
        float ageSquared = age * age;
        float invAge = saturate(vertIn.vPosition.z);
        float invAgeSquared = invAge * invAge;

        float contractedAge = saturate(vertIn.vPosition.y);
        float contractedAgeSquared = contractedAge * contractedAge;
        float contractedInvAge = saturate(vertIn.vPosition.w);
        float contractedInvAgeSquared = contractedInvAge * contractedInvAge;

        // get the cotnrol points
        float3 cp0 = p_mSplineRibbonControlPoints[g_iBatchIndex * 4 + 0];
        float3 cp1 = p_mSplineRibbonControlPoints[g_iBatchIndex * 4 + 1];
        float3 cp2 = p_mSplineRibbonControlPoints[g_iBatchIndex * 4 + 2];
        float3 cp3 = p_mSplineRibbonControlPoints[g_iBatchIndex * 4 + 3];

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

        vertIn.vSize.xyz = p_vSplineRibbonSize[g_iBatchIndex];
        vertIn.cColor0 = p_vSplineRibbonColor0[g_iBatchIndex];
        vertIn.cColor1 = p_vSplineRibbonColor1[g_iBatchIndex];
        vertIn.cColor2 = p_vSplineRibbonColor2[g_iBatchIndex];
    }

    // normal ribbon path
    else {
        // set to 0 if clamped
        float proceduralScalar = 1.0;

        if (b_precomputedAge) {
            g_fAge = vertIn.vPosition.w;
        }
        else {
            float ageScalar = 1.0;

            if (!b_ribbonLocalSpace) {
                // clamp the head
                {
                    float ageDelta = p_vLockedStartPositionAndTime[g_iBatchIndex].w - vertIn.vPosition.w;
                    float4 posChange;
                    posChange.w = p_vGPURibbonValues[g_iBatchIndex].x - vertIn.vPosition.w;
                    posChange.xyz = p_vLockedStartPositionAndTime[g_iBatchIndex].xyz - vertIn.vPosition.xyz;
                    // please turn into slt not if...then
                    proceduralScalar = (ageDelta > 0.001) ? 1.0 : 0.0;
                    posChange *= (1.0f - proceduralScalar);
                    vertIn.vPosition += posChange;
                }

                // clamp the tail
                if (b_clampTail) {
                    float ageDelta = p_vLockedTailPositionAndTime[g_iBatchIndex].w - vertIn.vPosition.w;
                    float3 posChange;
                    posChange.xyz = p_vLockedTailPositionAndTime[g_iBatchIndex].xyz - vertIn.vPosition.xyz;
                    // please turn into slt not if...then
                    float localProceduralScalar = (ageDelta < -0.001) ? 1.0 : 0.0;

                    posChange *= (1.0f - localProceduralScalar);
                    vertIn.vPosition.xyz += posChange;
                    proceduralScalar *= localProceduralScalar;
                }
            }

            if (b_clampTail) {
                ageScalar = p_vGPURibbonValues[g_iBatchIndex].w;
            }

            g_fAge = (p_vGPURibbonValues[g_iBatchIndex].x - vertIn.vPosition.w) / (vertIn.vInitialVelocity.w - vertIn.vPosition.w);
            g_fAge = saturate(g_fAge * ageScalar);
        }

        if (b_proceduralPosition) {
            float fMass = p_vSystemPhysicsConstants[g_iBatchIndex].x;
            float fInvMass = p_vSystemPhysicsConstants[g_iBatchIndex].y;
            float fGravity = -p_vSystemPhysicsConstants[g_iBatchIndex].z;
            float fDrag = p_vSystemPhysicsConstants[g_iBatchIndex].w;
            float fInvDrag = 1.0f / p_vSystemPhysicsConstants[g_iBatchIndex].w;
            float3 vOffsetFromOrigin;
            float3 vInstantaneousVelocity;

            float fTime;
            float3 vInitialVelocity;

            fTime = (p_vGPURibbonValues[g_iBatchIndex].x - vertIn.vPosition.w);
            vInitialVelocity = vertIn.vInitialVelocity.xyz;
            CalculateDisplacmentAndVelocity(fTime, vInitialVelocity, fMass, fInvMass, fDrag, fInvDrag, fGravity, vOffsetFromOrigin, vInstantaneousVelocity);
            vertIn.vPosition.xyz += (proceduralScalar * vOffsetFromOrigin);

            if (b_precomputedTangent) {
                vTangent = vertIn.vPositionPrev.xyz;
                //g_fAge = vertIn.vPositionPrev.w;
                // test
            }
            else {
				vTangent = -vInstantaneousVelocity;
			}
        }
    }

    // transform instanced particles
    if ( b_useModelInstancing )
        vertIn.vPosition.xyz = mul(float4(vertIn.vPosition.xyz, 1), p_mRibbonInstanceTransform[g_iBatchIndex]).xyz;

    if (b_computeUFromAge) {
        if (b_gpuSplineRibbon) {
            vertIn.vUV.x = 1.0f - g_fAge;
        }
        else {
            vertIn.vUV.x = 1.0f - (p_vGPURibbonValues[g_iBatchIndex].y * g_fAge + p_vGPURibbonValues[g_iBatchIndex].z);
        }
    }

    if (b_ribbonBezierSmoothSize) {
        float invAge = (1.0f - g_fAge);
        fSize = (invAge * invAge) * vertIn.vSize.x;
        fSize += (2.0f * g_fAge * invAge) * vertIn.vSize.y;
        fSize += (g_fAge * g_fAge) * vertIn.vSize.z;
    }

    else {
        if ( g_fAge < p_vMidKeyTimes[g_iBatchIndex].x ) {
            fT = g_fAge / p_vMidKeyTimes[g_iBatchIndex].x;
            if ( b_ribbonSmoothSize ) 
                fT = SmoothStep( fT );
            fSize = vertIn.vSize.x + ( vertIn.vSize.y - vertIn.vSize.x ) * fT;
        } else {
            fT = ( g_fAge - p_vMidKeyTimes[g_iBatchIndex].x ) / ( 1.0f - p_vMidKeyTimes[g_iBatchIndex].x );
            if ( b_ribbonSmoothSize ) 
                fT = SmoothStep( fT );
            fSize = vertIn.vSize.y + ( vertIn.vSize.z - vertIn.vSize.y ) * fT ;
        }
    }
    fSize = fSize * 0.5f;

    if (!b_proceduralPosition && !b_gpuSplineRibbon) {
        half3 vPrevSegmentDir = (vertIn.vPosition.xyz - vertIn.vPositionPrev.xyz);
        half3 vNextSegmentDir = (vertIn.vPositionNext.xyz - vertIn.vPosition.xyz);

        // Take average direction of both segments.
        // Note that this is an average vTangent, not the "real" vTangent but this produces smoother results.
        vTangent = vPrevSegmentDir + vNextSegmentDir;

        // make sure our tangent doesn't flip directions on us
        vTangent = dot(vTangent, vPrevSegmentDir) < 0 ? -vTangent : vTangent;
    }

    vTangent = normalize(vTangent);

    // avoid a mid-ribbon reversal
    if (!b_splineRibbon) {
        vertIn.vUp.xyz = dot(vTangent, vertIn.vInitialVelocity.xyz) >= 0 ? vertIn.vUp.xyz : -vertIn.vUp.xyz;
    }

    if ( b_iRibbonType == RIBBON_BILLBOARD ) {

        // make sure to put the camera forward into the local space of the ribbon first
        if ( b_ribbonLocalSpace)
            p_vCameraDirection.xyz = mul(p_vCameraDirection.xyz, (float3x3)(p_mInvPRWorldTransform[g_iBatchIndex]));

        // Flatten on camera plane.
        half3 vSegment = normalize(vTangent - p_vCameraDirection * dot( vTangent, p_vCameraDirection));

        // Billboard direction is perpendicular to flattened vSegment.
        vBinormal = cross( vSegment, p_vCameraDirection );
    } else {
        vBinormal = normalize( cross( vTangent, vertIn.vUp.xyz ) );
    }
    vNormal = normalize(cross( vTangent, vBinormal ));

    if ( b_useRotation ) {
        half fAngle;
        if ( g_fAge < p_vMidKeyTimes[g_iBatchIndex].w )
            fAngle = vertIn.vRotation.x + ( vertIn.vRotation.y - vertIn.vRotation.x ) * g_fAge / p_vMidKeyTimes[g_iBatchIndex].w;
        else fAngle = vertIn.vRotation.y + ( vertIn.vRotation.z - vertIn.vRotation.y ) * ( g_fAge - p_vMidKeyTimes[g_iBatchIndex].w ) / ( 1.0f - p_vMidKeyTimes[g_iBatchIndex].w );

        half3x3 mRotation = MakeRotation( fAngle, vTangent );
        vBinormal = mul( vBinormal, mRotation );
        vNormal = mul( vNormal, mRotation );
    }

    if ( b_iRibbonType == RIBBON_BILLBOARD || b_iRibbonType == RIBBON_PLANAR ) {
        vOffset = vertIn.vOffset.y * vBinormal;
        g_vVertexNormal = vNormal;
        g_vVertexTangent = vTangent;
        g_vVertexBinormal = vBinormal;        
    } else if ( b_iRibbonType == RIBBON_CYLINDER || b_iRibbonType == RIBBON_STAR ) {
        // Make a basis around the vSegment.
        half3x3 basis = half3x3(
                                    vNormal.x, vNormal.y, vNormal.z,
                                    vTangent.x, vTangent.y, vTangent.z,
                                    vBinormal.x, vBinormal.y, vBinormal.z
                                );
        vOffset = mul( half3( vertIn.vOffset.x, 0.0f, vertIn.vOffset.y ), basis ); 

        if (b_iRibbonType == RIBBON_CYLINDER)
            vOffset = normalize(vOffset);
    
        // :TODO: Planar ribbons are dual-sided, and thus would require normals on both sides. For this we need to duplicate
        // vertices and double the triangle count.

        g_vVertexNormal = vOffset;
        g_vVertexTangent = vTangent;
        g_vVertexBinormal = cross( vTangent, g_vVertexNormal );
    }

    vertIn.vPosition.xyz = vertIn.vPosition.xyz + vOffset * fSize;

    if (b_ribbonLocalSpace) {
        vertIn.vPosition.xyz = mul(float4(vertIn.vPosition.xyz, 1.0f), p_mPRWorldTransform[g_iBatchIndex]).xyz;
        g_vVertexNormal = mul(g_vVertexNormal, (float3x3)p_mPRWorldTransform[g_iBatchIndex]);
        g_vVertexTangent = mul(g_vVertexTangent, (float3x3)p_mPRWorldTransform[g_iBatchIndex]);
        g_vVertexBinormal = mul(g_vVertexBinormal, (float3x3)p_mPRWorldTransform[g_iBatchIndex]);
    }

    if ( b_enableVertexWarps == 1 )
        vertIn.vPosition.xyz = ApplyWarps( float4(vertIn.vPosition.xyz, 1.0) ).xyz;

    vertOut.HPos = EmitRibbonHPos( vertIn );
    GenInterpolant( WorldPos, float4(vertIn.vPosition.xyz, 1) );
    GenInterpolant( HPosAsUV, EmitRibbonHPosAsUV( vertIn ) );
    GenInterpolant( ViewPos, EmitRibbonViewPos( vertIn ) );
    GenInterpolant( Normal, EmitRibbonNormal( vertIn ) );
    GenInterpolant( Tangent, EmitRibbonTangent( vertIn ) );
    GenInterpolant( Binormal, EmitRibbonBinormal( vertIn ) );
    GenInterpolant( VertexColor, EmitRibbonVertexColor( vertIn ) );
    GenInterpolant( Diffuse, EmitDiffuse( vertIn, g_vVertexNormal ) );
    GenInterpolant( Specular, EmitSpecular( vertIn ) );
    GenInterpolant( ShadowDiffuse, EmitShadowDiffuse( vertIn, g_vVertexNormal ) );
    GenInterpolant( ShadowSpecular, EmitShadowSpecular( vertIn ) );
    GenInterpolant( ShadowMapUV, EmitShadowMapUV( vertIn ) );
    GenInterpolant( FogColor, EmitFogColor( vertIn ) );
    GenInterpolant( HalfVec, EmitHalfVec( vertIn, 0 ) );
    GenInterpolant( EyeToVertex, EmitRibbonEyeToVertex(vertIn) );
    GenInterpolant( EyeToVertexFresnel, EmitRibbonEyeToVertex(vertIn) );
    GenInterpolant( FOWUV, EmitRibbonFOWUV(vertIn) );

    if(b_usePackedUVEmitter)
    {
        for ( int i = 0; i < b_iUVEmitterCount / 2; i++ ) {
            GenInterpolantUV( UV[i], half4( EmitRibbonUV( vertIn, i * 2).xy, EmitRibbonUV( vertIn, (i * 2) + 1 ).xy ) );
        }
        if(b_iUVEmitterCount % 2)
            GenInterpolantUV( UV[(b_iUVEmitterCount / 2)], EmitRibbonUV( vertIn, b_iUVEmitterCount-1) );
    }
    else
    {
        for ( int i = 0; i < b_iUVEmitterCount; i++ ) {
            GenInterpolantUV( UV[i], EmitRibbonUV( vertIn, i ) );
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