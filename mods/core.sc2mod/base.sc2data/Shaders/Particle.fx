//==================================================================================================
//
// Copyright Blizzard Entertainment 2003-2005
//
// This is the shader code for the particles.
//==================================================================================================

#include "ShaderSystem.fx"
#include "VSElementUtils.fx"

#ifdef VERTEX_SHADER

#if !CPP_SHADER

//==================================================================================================
// Input structure
struct Input
{
#ifdef COMPILING_SHADER_FOR_OPENGL
    float4  vPosition            : NORMAL_;
#else
    float4  vPosition            : POSITION_;
#endif
    int4    vSize                : TEXCOORD0_;
    HALF4   cColor0              : COLOR0_;
    HALF4   cColor1              : COLOR1_;
    HALF4   cColor2              : TEXCOORD1_;
    int4    vRotation            : TEXCOORD2_;
    float4  vBirthDeathAndDrag   : TEXCOORD3_;
#ifdef COMPILING_SHADER_FOR_OPENGL
    float4  iBatchIndex          : TEXCOORD4_;
#else
    uint4    iBatchIndex          : TEXCOORD4_;
#endif
    HALF4   vInterpolator1       : TEXCOORD5_;
    HALF4   vInterpolator2       : TEXCOORD6_;  
    HALF4   vNoiseVector         : TEXCOORD7_;  
#ifdef COMPILING_SHADER_FOR_OPENGL
    int2   vOffset              : POSITION_;
#else
    int2   vOffset              : NORMAL_;
#endif
};

#endif

#include "VSEmitters.fx"
#include "VSParallax.fx"
#include "VSVertexWarp.fx"
#include "VSUtils.fx"
#include "VSCommon.fx"
#include "MaterialDefines.fx"
#include "VSUVMapping.fx"
#include "VSLighting.fx"
#include "VSFog.fx"
#include "RibbonParticleCommon.fx"

#define PARTICLE_BILLBOARD					0
#define PARTICLE_TAIL						1
#define PARTICLE_FACE_TRAVEL_DIR			2
#define PARTICLE_FACE_WORLD_DIR				3
#define PARTICLE_SINGLE_AXIS				4
#define PARTICLE_TERRAIN_ORIENTED			5
#define PARTICLE_TERRAIN_DIR_ORIENTED		6
#define PARTICLE_EMITTER_ORIENTED			7
#define PARTICLE_PHYSICS_ORIENTED           8
#define PARTICLE_PINNED				        9
#define PARTICLE_TRAIL				        10

#define MAX_RAND_NUMBERS                    64

//==================================================================================================
// Uniform parameters

float4x4    p_mParticleInstanceTransform[MAX_BATCHED_PARTICLES];

HALF3       p_vBillboardRight;
HALF3       p_vBillboardUp;

float4      p_vSystemTime_ElementScale_FlipbookMidKeyTime_FlipbookColumnCount[MAX_BATCHED_PARTICLES];
HALF3       p_fFlipbookFrames[MAX_BATCHED_PARTICLES];
ArrayDecl(HALF2) p_vFlipbookCellSize[MAX_BATCHED_PARTICLES];
ArrayDecl(float) p_fParticleBatchIndexRemappingTable[MAX_BATCH_INDEX_REMAPPING_TABLE_SIZE];

//==================================================================================================
// VERTEX SHADER EMITTERS

//--------------------------------------------------------------------------------------------------
float4 EmitParticleHPos( Input vertIn ) {
    return mul( float4(vertIn.vPosition.xyz, 1.0), p_mVPTransform );
}

//--------------------------------------------------------------------------------------------------
// Homogeneous position as UV.
float4 EmitParticleHPosAsUV( Input vertIn ) {
    return mul( float4(vertIn.vPosition.xyz, 1.0), p_mVPTransform );
}

//--------------------------------------------------------------------------------------------------
// Camera space position.
float3 EmitParticleViewPos( Input vertIn ) {
    return mul( p_mViewTransform, float4(vertIn.vPosition.xyz, 1.0) );          // As 3x4
}

//--------------------------------------------------------------------------------------------------
// Normal.
HALF4 EmitParticleNormal( Input vertIn, float3 vParticleNormal ) {
    // always righthanded
    return HALF4(vParticleNormal, 1);
}

//--------------------------------------------------------------------------------------------------
// Tangent.
HALF4 EmitParticleTangent( Input vertIn, float3 vParticleTangent ) {
    return HALF4(vParticleTangent, 1);
}

//--------------------------------------------------------------------------------------------------
// Binormal.
HALF3 EmitParticleBinormal( Input vertIn, float3 vParticleBinormal ) {
    return vParticleBinormal;
}

//--------------------------------------------------------------------------------------------------
#ifdef COMPILING_SHADER_FOR_OPENGL
    float INTMOD( float x, float y) {
     return float(int(x) % int(y));
    }
#else
    #define INTMOD(x,y) (x % y)
#endif

//--------------------------------------------------------------------------------------------------
HALF4 EmitParticleUV( Input vertIn, int index, float4 vSizeAndAge, int iBatchIndex, int b_iUVMapping[8], int b_UVRandomOffsetEnable[8] ) {
    HALF2 vUV = vertIn.vOffset * HALF2( 0.5f, -0.5f ) + HALF2( 0.5f, 0.5f );

    if ( b_iUVMapping[index] == UVMAP_PARTICLE_FLIPBOOK ) {
        int iCell;
        if ( vSizeAndAge.w <= p_vSystemTime_ElementScale_FlipbookMidKeyTime_FlipbookColumnCount[iBatchIndex].z ) {
            float fRange = p_fFlipbookFrames[iBatchIndex].y - p_fFlipbookFrames[iBatchIndex].x;
            float fOffset = fRange * (vSizeAndAge.w / p_vSystemTime_ElementScale_FlipbookMidKeyTime_FlipbookColumnCount[iBatchIndex].z);
            iCell = p_fFlipbookFrames[iBatchIndex].x + floor(fOffset + 0.5f);
        } else {
            float fRange = p_fFlipbookFrames[iBatchIndex].z - p_fFlipbookFrames[iBatchIndex].y;
            float fOffset = fRange * ((vSizeAndAge.w - p_vSystemTime_ElementScale_FlipbookMidKeyTime_FlipbookColumnCount[iBatchIndex].z) / 
                            (1.0 - p_vSystemTime_ElementScale_FlipbookMidKeyTime_FlipbookColumnCount[iBatchIndex].z));
            iCell = p_fFlipbookFrames[iBatchIndex].y + floor(fOffset + 0.5f);
        }
        if (b_randomFlipBookStart)
            iCell += floor (vertIn.vNoiseVector.w);

#if CPP_SHADER
        p_vSystemTime_ElementScale_FlipbookMidKeyTime_FlipbookColumnCount[iBatchIndex].w = 1;      // Fixes integer overflow on c++ side.
#endif
        int iCellX = INTMOD( iCell, (int)p_vSystemTime_ElementScale_FlipbookMidKeyTime_FlipbookColumnCount[iBatchIndex].w );
        int iCellY = iCell / p_vSystemTime_ElementScale_FlipbookMidKeyTime_FlipbookColumnCount[iBatchIndex].w;
        HALF2 vOffset = HALF2( iCellX * p_vFlipbookCellSize[iBatchIndex].x, iCellY * p_vFlipbookCellSize[iBatchIndex].y );
        vUV = vUV * float2Ref(p_vFlipbookCellSize[iBatchIndex]) + vOffset;
    }
    else { 
        // offset with a random uv
        if (b_UVRandomOffsetEnable[index]) {
            float r = vertIn.vRotation.w;
            float x = floor(r/256); // hi byte
            float y = r - x*256; // lo byte
            vUV += float2(x, y) / 255;
        }

        vUV = GenUV(
            vertIn.vPosition.xyz, 
            vertIn.vPosition.xyz, 
            0,                      // No normal.
            0, 
            vUV, 
            vUV,                     // No vUV slot 1.
            vUV, 
            vUV, 
            index, 
            0,
            float3(0,0,0),
            b_iUVMapping
        );
    }
    
    return HALF4(vUV,0,1);
}

//--------------------------------------------------------------------------------------------------
HALF4 EmitParticleVertexColor( Input vertIn, float4 vSizeAndAge, int iBatchIndex ) {
    HALF4 cColor;

    cColor.rgb = InterpolateValue(
        vSizeAndAge.w, 
        vertIn.cColor0.rgb, 
        vertIn.cColor1.rgb, 
        vertIn.cColor2.rgb, 
        p_vMidKeyTimes[iBatchIndex].y, 
        p_vInversedMidKeyTimes[iBatchIndex].y, 
        p_vMidKeyHoldTimes[iBatchIndex].y, 
        b_iParticleColorInterpolation
    );
    
    cColor.a = InterpolateValue(
        vSizeAndAge.w, 
        vertIn.cColor0.a, 
        vertIn.cColor1.a, 
        vertIn.cColor2.a, 
        p_vMidKeyTimes[iBatchIndex].z, 
        p_vInversedMidKeyTimes[iBatchIndex].z, 
        p_vMidKeyHoldTimes[iBatchIndex].z, 
        b_iParticleColorInterpolation
    );

    return cColor;
}

//--------------------------------------------------------------------------------------------------
// eye to vertex
float3 EmitParticleEyeToVertex(Input vertIn) {
    return normalize(vertIn.vPosition.xyz - p_vEyePos);
}

//--------------------------------------------------------------------------------------------------
// FOW uvs
HALF4 EmitParticleFOWUV (Input vertIn) {
    return mul(float4(vertIn.vPosition.xyz, 1.0), p_mFOWMatrix);
}

//==================================================================================================
float GenerateRotation(in float fAge, float3 vRotation, int iBatchIndex) {
    return InterpolateValue(
        fAge, 
        vRotation.x, 
        vRotation.y, 
        vRotation.z, 
        p_vMidKeyTimes[iBatchIndex].w, 
        p_vInversedMidKeyTimes[iBatchIndex].w, 
        p_vMidKeyHoldTimes[iBatchIndex].w, 
        b_iParticleRotationInterpolation
    );
}

//==================================================================================================
void CalculatePositionAndVelocity(inout Input vertIn, float4 vSizeAndAge, int iBatchIndex) {
    float3 vOffsetFromOrigin;
    float3 vInstantaneousVelocity;

    float fTime = p_vSystemTime_ElementScale_FlipbookMidKeyTime_FlipbookColumnCount[iBatchIndex].x - vertIn.vBirthDeathAndDrag.x;
    float3 vInitialVelocity = vertIn.vInterpolator1.xyz;
    float fInvMass = vertIn.vInterpolator1.w;
    float fMass = 1.0f / fInvMass;
    float fDrag = vertIn.vBirthDeathAndDrag.z;
    float fInvDrag = vertIn.vBirthDeathAndDrag.w;
    float fGravity = -vertIn.vInterpolator2.w;
    CalculateDisplacmentAndVelocity(fTime, vInitialVelocity, fMass, fInvMass, fDrag, fInvDrag, fGravity,
        vOffsetFromOrigin, vInstantaneousVelocity);

    // offset the position
    vertIn.vPosition.xyz += vOffsetFromOrigin;

    // write back the instantenous velocity for later rendering
    if (b_iInstanceType == PARTICLE_FACE_TRAVEL_DIR)
        vertIn.vInterpolator2.xyz = vInstantaneousVelocity;
    else if (b_iInstanceType == PARTICLE_TAIL || b_iInstanceType == PARTICLE_PINNED || b_iInstanceType == PARTICLE_TRAIL) {
        vertIn.vInterpolator1.xyz = vInstantaneousVelocity;

        if (b_clampedTailLength) {
            float fSpeed = length(vInstantaneousVelocity);
            float fTailLength;
            if (b_fixedTailLength)
                fTailLength = vertIn.vInterpolator2.x * fSpeed * vSizeAndAge.xyz.x;
            else
                fTailLength = max(vertIn.vInterpolator2.x, vertIn.vInterpolator2.x * fSpeed) * vSizeAndAge.xyz.x;

            float fOffsetDistance = length(vOffsetFromOrigin);
            if (fOffsetDistance < fTailLength)
                vertIn.vInterpolator2.x = min(fOffsetDistance / (fSpeed * vSizeAndAge.xyz.x), vertIn.vInterpolator2.x);
        }
    }
}

//==================================================================================================
void UnpackNormals(Input vertIn, out HALF3 vRight, out HALF3 vUp, out HALF3 vForward, int iBatchIndex) {
    // sets up the correct normals for the following instance types:
    //      PARTICLE_FACE_TRAVEL_DIR 
    //      PARTICLE_FACE_WORLD_DIR 
    //      PARTICLE_EMITTER_ORIENTED 
    //      PARTICLE_PHYSICS_ORIENTED 

    if (b_iInstanceType == PARTICLE_EMITTER_ORIENTED) {
        
        // Note: this path is very close to the max temp register limit in SM 2.0, use
        // caution when adding logic for EmitterOriented particles.

        if (b_localSpace) {
            // all particles take the current rotation of the emitter
            vRight = normalize(p_mPRWorldTransform[iBatchIndex][0].xyz);
            vUp = normalize(p_mPRWorldTransform[iBatchIndex][1].xyz);
            vForward = normalize(cross(vRight, vUp));
        }
        else {
            // vInterpolator2 contains both the right and up vectors, packed as follows:
            // x => right.y | right.x
            // y => right.z | up.x
            // z =>    up.y | up.z
           
            vRight.y = (trunc(vertIn.vInterpolator2.x / 65536.0f));
            vRight.x = vertIn.vInterpolator2.x - (vRight.y * 65536.0f);
            vRight.z = (trunc(vertIn.vInterpolator2.y / 65536.0f));

            vUp.x = vertIn.vInterpolator2.y - (vRight.z * 65536.0f);
            vUp.y = (trunc(vertIn.vInterpolator2.z / 65536.0f));
            vUp.z = vertIn.vInterpolator2.z - (vUp.y * 65536.0f);

            vRight = ((vRight / 255.0f) * 2) - 1;
            vUp = ((vUp / 255.0f) * 2) - 1;

            vRight = normalize(vRight);
            vUp = normalize(vUp);
            vForward = normalize(cross(vRight, vUp));
        }
    }
    else {
        vForward = vertIn.vInterpolator2.xyz;
        vForward = normalize( vForward + HALF3( 0.0f, 0.0001f, 0.0f ) );
        vRight = normalize( cross( HALF3( 0.0f, 0.0f, 1.0f ), vForward ) );
        vUp = normalize( cross( vForward, vRight ) );
    }
}

//==================================================================================================
void ParticleVertexMain( in Input vertIn, out VertexTransport vertOut ) {
    float4  vSizeAndAge;
    float3  vParticleNormal;
    float3  vParticleTangent;
    float3  vParticleBinormal;
    int iBatchIndex = 0;


    int b_iUVMapping[8];
    int b_UVRandomOffsetEnable[8];
    InitShader( vertOut, b_iUVMapping, b_UVRandomOffsetEnable );

    // decompress vertex
    float4 vInputSize = vertIn.vSize * (1.f/256.f);
    float3 vInputRotation = vertIn.vRotation * (1.f/32.f);

#if defined(COMPILING_SHADER_FOR_OPENGL) || defined(COMPILING_SHADER_FOR_METAL)
    vertIn.cColor0 = vertIn.cColor0.zyxw;
    vertIn.cColor1 = vertIn.cColor1.zyxw;
    vertIn.cColor2 = vertIn.cColor2.zyxw;
    iBatchIndex = (int)(vertIn.iBatchIndex.x + 0.1);
    iBatchIndex = (int)(floatRef(p_fParticleBatchIndexRemappingTable[iBatchIndex]) + 0.1);
#else
#if !CPP_SHADER
    iBatchIndex = (int)(vertIn.iBatchIndex.x + 0.1);
    iBatchIndex = (int)(floatRef(p_fParticleBatchIndexRemappingTable[iBatchIndex]) + 0.1);
#endif
#endif

    
#if !CPP_SHADER
    vSizeAndAge.w = ( p_vSystemTime_ElementScale_FlipbookMidKeyTime_FlipbookColumnCount[iBatchIndex].x - vertIn.vBirthDeathAndDrag.x ) / ( vertIn.vBirthDeathAndDrag.y - vertIn.vBirthDeathAndDrag.x );
    vSizeAndAge.w = saturate(vSizeAndAge.w);  // to fix the fact that dead particles can still render!
#endif

    // compute size
    vSizeAndAge.xyz = InterpolateValue(
        vSizeAndAge.w, 
        vInputSize.x, 
        vInputSize.y, 
        vInputSize.z, 
        p_vMidKeyTimes[iBatchIndex].x, 
        p_vInversedMidKeyTimes[iBatchIndex].x, 
        p_vMidKeyHoldTimes[iBatchIndex].x, 
        b_iParticleSizeInterpolation
    );

    if (b_useProceduralPosition)
        CalculatePositionAndVelocity(vertIn,vSizeAndAge, iBatchIndex);

    if (b_localSpace) {
        vertIn.vPosition.xyz = mul(float4(vertIn.vPosition.xyz, 1), p_mPRWorldTransform[iBatchIndex]).xyz;
    }
    
    vertIn.vPosition.xyz += vertIn.vNoiseVector.xyz;

    // :TODO: :NOTE: How about some code reuse here huh?

    if( b_iInstanceType == PARTICLE_SINGLE_AXIS ) {
        
        // fixed vUp dir           
        HALF3 vRight = normalize(cross( vertIn.vInterpolator2.xyz, p_vCameraDirection));
        
        HALF fAngle = GenerateRotation(vSizeAndAge.w, vInputRotation, iBatchIndex);

        HALF3 vForward = normalize( cross( vRight, vertIn.vInterpolator2.xyz ) );
        half3x3 mRotation = MakeRotation( fAngle, vForward );
        HALF3 vOffset = vertIn.vOffset.x * vRight + vertIn.vOffset.y * vertIn.vInterpolator2.xyz;
        vOffset *= p_vSystemTime_ElementScale_FlipbookMidKeyTime_FlipbookColumnCount[iBatchIndex].y;
        vertIn.vPosition.xyz = vertIn.vPosition.xyz + mul( vSizeAndAge.xyz * vOffset, mRotation );

        vParticleNormal = normalize(cross(vRight, vForward));
        vParticleTangent = vRight;
        vParticleBinormal = vForward;
    }
    else if( b_iInstanceType == PARTICLE_FACE_TRAVEL_DIR 
          || b_iInstanceType == PARTICLE_FACE_WORLD_DIR 
          || b_iInstanceType == PARTICLE_EMITTER_ORIENTED 
          || b_iInstanceType == PARTICLE_PHYSICS_ORIENTED 
    ) {
        HALF3 vRight;
        HALF3 vUp;
        HALF3 vDirectionVector;

        UnpackNormals(vertIn, vRight, vUp, vDirectionVector, iBatchIndex);
             
        HALF4 vOffsetAngle;
        vOffsetAngle.xyz	= vertIn.vOffset.x * vRight + vertIn.vOffset.y * vUp;
        vOffsetAngle.xyz	*= p_vSystemTime_ElementScale_FlipbookMidKeyTime_FlipbookColumnCount[iBatchIndex].y;
        vOffsetAngle.w		= GenerateRotation(vSizeAndAge.w, vInputRotation, iBatchIndex);

        half3x3 mRotation = MakeRotation( vOffsetAngle.w, vDirectionVector );		
        vertIn.vPosition.xyz = vertIn.vPosition.xyz + mul( vSizeAndAge.xyz * vOffsetAngle.xyz, mRotation );
    }
    else if( b_iInstanceType == PARTICLE_TERRAIN_ORIENTED ) {
        // vInterpolator1 = particle DIRECTION
        // vInterpolator2 = terrain Normal
        
        HALF3 vDirectionVector =  vertIn.vInterpolator1.xyz;
        HALF3 vProjectedDir = vDirectionVector - dot( vDirectionVector, vertIn.vInterpolator2.xyz ) * vertIn.vInterpolator2.xyz;

        HALF fAngle = GenerateRotation(vSizeAndAge.w, vInputRotation, iBatchIndex);
        half3x3 mRotation = MakeRotation(fAngle, vertIn.vInterpolator2.xyz );		

        // :TODO: Find a better way.
        if ( dot( vProjectedDir, vProjectedDir ) < 0.01f )
            vProjectedDir = HALF3( 1.0f, 0.0f, 0.0f );
        vProjectedDir = normalize( vProjectedDir );
        HALF3 vRight = ( cross( vProjectedDir, vertIn.vInterpolator2.xyz ) );
        vProjectedDir = mul(vProjectedDir, mRotation);
        vRight = mul(vRight, mRotation);
        HALF3 vOffset = vertIn.vOffset.x * vRight + vertIn.vOffset.y * vProjectedDir;
        vOffset *= p_vSystemTime_ElementScale_FlipbookMidKeyTime_FlipbookColumnCount[iBatchIndex].y;
        vertIn.vPosition.xyz = vertIn.vPosition.xyz + ( vSizeAndAge.xyz * vOffset );

        vParticleNormal = normalize(cross(vRight, vProjectedDir));
        vParticleTangent = vRight;
        vParticleBinormal = vProjectedDir;

        // check to see if we need to flip the nbt's cause the particle is oriented "away" from the camera
        float d = -dot(vertIn.vPosition.xyz, vParticleNormal);
        float cameraDistFromParticlePlane = dot(float4(p_vEyePos.xyz, 1), float4(vParticleNormal, d));
        vParticleNormal = (cameraDistFromParticlePlane > 0) ? vParticleNormal : -vParticleNormal;
        vParticleTangent = (cameraDistFromParticlePlane > 0) ? vParticleTangent : -vParticleTangent;
        vParticleBinormal = (cameraDistFromParticlePlane > 0) ? vParticleBinormal : -vParticleBinormal;
    }
    else if( b_iInstanceType == PARTICLE_TERRAIN_DIR_ORIENTED ) {
        // vInterpolator1 = particle velocity
        // vInterpolator2 = terrain Normal
        
        float fMag = length( vertIn.vInterpolator1.xyz );

        HALF3 vDirectionVector = normalize( vertIn.vInterpolator1.xyz );
        HALF3 vProjectedDir = normalize( vDirectionVector - dot( vDirectionVector, vertIn.vInterpolator2.xyz ) * vertIn.vInterpolator2.xyz );
        HALF3 vRight = ( cross( vProjectedDir, vertIn.vInterpolator2.xyz ) );

        // scale projected dir by the tail length ( to make it bigger as we go faster )
        vProjectedDir = vProjectedDir * max( vInputRotation.x, ( fMag * vInputRotation.x ) );
        HALF3 vOffset = vertIn.vOffset.x * vRight + vertIn.vOffset.y * vProjectedDir;

        vOffset *= p_vSystemTime_ElementScale_FlipbookMidKeyTime_FlipbookColumnCount[iBatchIndex].y;
        vertIn.vPosition.xyz = vertIn.vPosition.xyz + ( vSizeAndAge.xyz * vOffset );

        vParticleNormal = normalize(cross(vRight, vProjectedDir));
        vParticleTangent = vRight;
        vParticleBinormal = vProjectedDir;

        // check to see if we need to flip the nbt's cause the particle is oriented "away" from the camera
        float d = -dot(vertIn.vPosition.xyz, vParticleNormal);
        float cameraDistFromParticlePlane = dot(float4(p_vEyePos.xyz, 1), float4(vParticleNormal, d));
        vParticleNormal = (cameraDistFromParticlePlane > 0) ? vParticleNormal : -vParticleNormal;
        vParticleTangent = (cameraDistFromParticlePlane > 0) ? vParticleTangent : -vParticleTangent;
        vParticleBinormal = (cameraDistFromParticlePlane > 0) ? vParticleBinormal : -vParticleBinormal;
    }
    else if( b_iInstanceType == PARTICLE_TAIL || b_iInstanceType == PARTICLE_TRAIL) {
         vertIn.vInterpolator1.xyz += vertIn.vNoiseVector.xyz;
    
        float fMag = length( vertIn.vInterpolator1.xyz );
         if (b_localSpace)
             vertIn.vInterpolator1.xyz = mul(vertIn.vInterpolator1.xyz, (float3x3)p_mPRWorldTransform[iBatchIndex]);
 
        HALF3 vDirectionVector = normalize( vertIn.vInterpolator1.xyz );
        HALF3 vRight = normalize((cross( p_vCameraDirection, vDirectionVector)));
        // scale dir by the tail length ( to make it bigger as we go faster )
        
         float fTailLength;
         if (b_fixedTailLength)
             fTailLength = vertIn.vInterpolator2.x;
        else
             fTailLength = max(vertIn.vInterpolator2.x, (fMag * vertIn.vInterpolator2.x));
        vDirectionVector = vDirectionVector * fTailLength;
 
        HALF3 vOffset = vertIn.vOffset.x * vRight + vertIn.vOffset.y * vDirectionVector;
        HALF3 vSize = p_vSystemTime_ElementScale_FlipbookMidKeyTime_FlipbookColumnCount[iBatchIndex].y * vSizeAndAge.xyz;
        vertIn.vPosition.xyz = vertIn.vPosition.xyz + vOffset*vSize;

        if (b_iInstanceType == PARTICLE_TRAIL) {
            vertIn.vPosition.xyz -= vSize*vDirectionVector;
        }
 
        vParticleNormal = normalize( cross(vRight, vDirectionVector) ); 
        vParticleTangent = vRight;
        vParticleBinormal = -vDirectionVector;  
    }
    else if(b_iInstanceType == PARTICLE_PINNED) {
         if (b_localSpace)
            vertIn.vInterpolator2.xyz = mul(float4(vertIn.vInterpolator2.xyz, 1), p_mPRWorldTransform[iBatchIndex]).xyz;

        // Delta vector from particle spawn position to current position
        float3 vDelta = vertIn.vPosition.xyz - vertIn.vInterpolator2.xyz;
        float norm = length(vDelta);
        
        // Build base
        float3 vForward = vDelta / norm;
        float3 vRight = normalize( cross(p_vCameraDirection, vForward) );
        float endScale = vertIn.vOffset.y *.5f + .5f;
        endScale = lerp(1.f, vInputSize.w, endScale);
        
        // Build quad offset
        float3 vCenter = 0.5f * (vertIn.vPosition.xyz + vertIn.vInterpolator2.xyz);
        float3 vOffset = vertIn.vOffset.x * vSizeAndAge.xyz * vRight * endScale + 0.5f * vertIn.vOffset.y * norm * vForward;
    
        // The actual quad corner is offset from the center
        vertIn.vPosition.xyz = vCenter + vOffset;
        
        vParticleNormal = cross(vRight, vForward); 
        vParticleTangent = vRight;
        vParticleBinormal = -vForward;  
    }
    else {
        // regular billboard		
        HALF fAngle = GenerateRotation(vSizeAndAge.w, vInputRotation, iBatchIndex);
       
        float3 forward = p_vCameraDirection.xyz;
        float3 right = p_vBillboardRight.xyz;
        float3 up = p_vBillboardUp.xyz;
        if ( b_useModelInstancing ) {
            #ifdef COMPILING_SHADER_FOR_OPENGL
                float4x4 mInstanceTransfrom = p_mParticleInstanceTransform[iBatchIndex];
            #else
                float4x4 mInstanceTransfrom = p_mParticleInstanceTransform[(int)floatRef(p_fParticleBatchIndexRemappingTable[vertIn.iBatchIndex.x])];
            #endif
            
            vertIn.vPosition.xyz = mul(float4(vertIn.vPosition.xyz, 1), mInstanceTransfrom).xyz;
        }

        half3x3 mRotation = MakeRotation( fAngle, forward );		
        HALF3 vOffset = vertIn.vOffset.x * right + vertIn.vOffset.y * up;
        vOffset *= p_vSystemTime_ElementScale_FlipbookMidKeyTime_FlipbookColumnCount[iBatchIndex].y;
        vertIn.vPosition.xyz = vertIn.vPosition.xyz + mul( vSizeAndAge.xyz * vOffset, mRotation );

        right = mul(right, mRotation);
        up = mul(up, mRotation);

        vParticleNormal = normalize(cross(right, up));
        vParticleTangent = right;
        vParticleBinormal = -up;
    }

    // transform instanced particles, bill board particles are handled already
    if (b_useModelInstancing && b_iInstanceType!=PARTICLE_BILLBOARD) {
        #ifdef COMPILING_SHADER_FOR_OPENGL
            vertIn.vPosition.xyz = mul(float4(vertIn.vPosition.xyz, 1), p_mParticleInstanceTransform[iBatchIndex]).xyz;
        #else
            vertIn.vPosition.xyz = mul(float4(vertIn.vPosition.xyz, 1), p_mParticleInstanceTransform[(int)floatRef( p_fParticleBatchIndexRemappingTable[vertIn.iBatchIndex.x])]).xyz;
        #endif
    }

    if ( b_enableVertexWarps == 1 )
        vertIn.vPosition.xyz = ApplyWarps( float4(vertIn.vPosition.xyz, 1.0) ).xyz;
    
    vertOut.HPos = EmitParticleHPos( vertIn );
#ifdef COMPILING_SHADER_FOR_METAL
    GenInterpolant( WorldPos, 0 );
#endif
    GenInterpolant( HPosAsUV, EmitParticleHPosAsUV( vertIn ) );
    GenInterpolant( ViewPos, EmitParticleViewPos( vertIn ) );
    GenInterpolant( VertexColor, EmitParticleVertexColor( vertIn, vSizeAndAge, iBatchIndex ) );
    GenInterpolant( ShadowMapUV, EmitShadowMapUV( vertIn.vPosition.xyz ) );
    GenInterpolant( FogColor, EmitFogColor( vertIn.vPosition.xyz ) );
    GenInterpolant( HalfVec, EmitHalfVec( vertIn.vPosition.xyz, 0 ) );
    GenInterpolant( EyeToVertex, EmitParticleEyeToVertex(vertIn) );
    GenInterpolant( EyeToVertexFresnel, EmitParticleEyeToVertex(vertIn) );
    GenInterpolant( FOWUV, EmitParticleFOWUV(vertIn) );
    
    if(b_usePackedUVEmitter)
    {
#if COMPILING_SHADER_WITH_BSL
        [unroll]
#endif
        for ( int i = 0; i < b_iUVEmitterCount / 2; i++ ) {
            GenInterpolantUV( i, HALF4( EmitParticleUV( vertIn, i * 2, vSizeAndAge, iBatchIndex, b_iUVMapping, b_UVRandomOffsetEnable ).xy, EmitParticleUV( vertIn, (i * 2) + 1, vSizeAndAge, iBatchIndex, b_iUVMapping, b_UVRandomOffsetEnable ).xy ) );
        }
        if(b_iUVEmitterCount % 2)
            GenInterpolantUV( b_iUVEmitterCount / 2, EmitParticleUV( vertIn, b_iUVEmitterCount-1, vSizeAndAge, iBatchIndex, b_iUVMapping, b_UVRandomOffsetEnable ) );
    }
    else
    {
#if COMPILING_SHADER_WITH_BSL
        [unroll]
#endif
        for ( int i = 0; i < b_iUVEmitterCount; i++ ) {
            GenInterpolantUV( i, EmitParticleUV( vertIn, i, vSizeAndAge, iBatchIndex, b_iUVMapping, b_UVRandomOffsetEnable ) );
        }
    }
    
    GenInterpolant( ParallaxVector, 0 );

    // Do the NBT in a second pass to minimize temp registers for 2.0
    if( b_iInstanceType == PARTICLE_FACE_TRAVEL_DIR || b_iInstanceType == PARTICLE_FACE_WORLD_DIR || 
        b_iInstanceType == PARTICLE_EMITTER_ORIENTED || b_iInstanceType == PARTICLE_PHYSICS_ORIENTED ) {

        HALF3 vRight;
        HALF3 vUp;
        HALF3 vDirectionVector;

        UnpackNormals(vertIn, vRight, vUp, vDirectionVector, iBatchIndex);
        
        vParticleNormal = vDirectionVector;
        vParticleTangent = vRight;
        vParticleBinormal = vUp;

        // check to see if we need to flip the nbt's cause the particle is oriented "away" from the camera
        float d = -dot(vertIn.vPosition.xyz, vParticleNormal);
        float cameraDistFromParticlePlane = dot(float4(p_vEyePos.xyz, 1), float4(vParticleNormal, d));
        vParticleNormal	= vParticleNormal * sign(cameraDistFromParticlePlane); //(cameraDistFromParticlePlane > 0) ? vParticleNormal : -vParticleNormal;
        vParticleTangent	= vParticleTangent * sign(cameraDistFromParticlePlane); //(cameraDistFromParticlePlane > 0) ? vParticleTangent : -vParticleTangent;
        vParticleBinormal = vParticleBinormal * sign(cameraDistFromParticlePlane);; //(cameraDistFromParticlePlane > 0) ? vParticleBinormal : -vParticleBinormal;
    }

    HALF3 cVertexSpecularLighting;
    HALF3 cVertexShadowSpecularLighting;
    HALF3 cVertexShadowSpecularLighting2;

    GenInterpolant( Normal, EmitParticleNormal( vertIn, vParticleNormal ) );
    GenInterpolant( Tangent, EmitParticleTangent( vertIn, vParticleTangent ) );
    GenInterpolant( Binormal, EmitParticleBinormal( vertIn, vParticleBinormal ) );
    GenInterpolant( Diffuse, EmitDiffuse( vertIn.vPosition.xyz, vParticleNormal, HALF4(0,0,0,0), cVertexSpecularLighting, cVertexShadowSpecularLighting, cVertexShadowSpecularLighting2 ) );
    GenInterpolant( ShadowDiffuse, EmitShadowDiffuse( vParticleNormal, HALF4(0,0,0,0), cVertexShadowSpecularLighting, cVertexShadowSpecularLighting2 ) );
    GenInterpolant( Specular, EmitSpecular(cVertexSpecularLighting) );
    GenInterpolant( ShadowSpecular, EmitShadowSpecular(cVertexShadowSpecularLighting) );

#ifdef COMPILING_SHADER_FOR_OPENGL
    vertOut.HPos.y *= -1.0;
    vertOut.HPos.z = 2.0 * (vertOut.HPos.z - (0.5 * vertOut.HPos.w));
#endif    
}

#endif  // VERTEXSHADER

#ifdef PIXEL_SHADER
#include "PSMainShading.fx"
#endif