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
    half3   vSize                : TEXCOORD0_;
    half4   cColor0              : COLOR0_;
    half4   cColor1              : COLOR1_;
    half4   cColor2              : TEXCOORD1_;
    half3   vRotation            : TEXCOORD2_;
    float4  vBirthDeathAndDrag   : TEXCOORD3_;
#ifdef COMPILING_SHADER_FOR_OPENGL
    float4  iBatchIndex          : TEXCOORD4_;
#else
    int4    iBatchIndex          : TEXCOORD4_;
#endif
	half4   vInterpolator1       : TEXCOORD5_;
	half4   vInterpolator2       : TEXCOORD6_;  
	half4   vNoiseVector         : TEXCOORD7_;  
#ifdef COMPILING_SHADER_FOR_OPENGL
    half2   vOffset              : POSITION_;
#else
    half2   vOffset              : NORMAL_;
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

//==================================================================================================
// Uniform parameters

float4x4    p_mParticleInstanceTransform[MAX_BATCHED_PARTICLES];

HALF3       p_vBillboardRight;
HALF3       p_vBillboardUp;

float4      p_vSystemTime_ElementScale_FlipbookMidKeyTime_FlipbookColumnCount[MAX_BATCHED_PARTICLES];
half3       p_fFlipbookFrames[MAX_BATCHED_PARTICLES];
HALF2       p_vFlipbookCellSize[MAX_BATCHED_PARTICLES];
float       p_fParticleBatchIndexRemappingTable[MAX_BATCH_INDEX_REMAPPING_TABLE_SIZE];

float4		g_vSizeAndAge;

float3      g_vParticleNormal;
float3      g_vParticleTangent;
float3      g_vParticleBinormal;

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
half4 EmitParticleNormal( Input vertIn ) {
    // allways righthanded
    return half4(g_vParticleNormal, 1);
}

//--------------------------------------------------------------------------------------------------
// Normal.
half4 EmitParticleTangent( Input vertIn ) {
    return half4(g_vParticleTangent, 1);
}

//--------------------------------------------------------------------------------------------------
// Normal.
half3 EmitParticleBinormal( Input vertIn ) {
    return g_vParticleBinormal;
}

//--------------------------------------------------------------------------------------------------
#ifdef COMPILING_SHADER_FOR_OPENGL
    float INTMOD( float x, float y) {
     return y - floor(floor(x/y)*y);
    }
#else
    #define INTMOD(x,y) (x % y)
#endif

half4 EmitParticleUV( Input vertIn, int index ) {
    half2 vUV = vertIn.vOffset * half2( 0.5f, -0.5f ) + half2( 0.5f, 0.5f );
    if ( b_iUVMapping[index] == UVMAP_PARTICLE_FLIPBOOK ) {
        int iCell;
        if ( g_vSizeAndAge.w <= p_vSystemTime_ElementScale_FlipbookMidKeyTime_FlipbookColumnCount[g_iBatchIndex].z ) {
            float fRange = p_fFlipbookFrames[g_iBatchIndex].y - p_fFlipbookFrames[g_iBatchIndex].x;
            float fOffset = fRange * (g_vSizeAndAge.w / p_vSystemTime_ElementScale_FlipbookMidKeyTime_FlipbookColumnCount[g_iBatchIndex].z);
            iCell = p_fFlipbookFrames[g_iBatchIndex].x + floor(fOffset + 0.5f);
        } else {
            float fRange = p_fFlipbookFrames[g_iBatchIndex].z - p_fFlipbookFrames[g_iBatchIndex].y;
            float fOffset = fRange * ((g_vSizeAndAge.w - p_vSystemTime_ElementScale_FlipbookMidKeyTime_FlipbookColumnCount[g_iBatchIndex].z) / 
                            (1.0 - p_vSystemTime_ElementScale_FlipbookMidKeyTime_FlipbookColumnCount[g_iBatchIndex].z));
            iCell = p_fFlipbookFrames[g_iBatchIndex].y + floor(fOffset + 0.5f);
        }
        if (b_randomFlipBookStart)
            iCell += floor (vertIn.vNoiseVector.w);

#if CPP_SHADER
        p_vSystemTime_ElementScale_FlipbookMidKeyTime_FlipbookColumnCount[g_iBatchIndex].w = 1;      // Fixes integer overflow on c++ side.
#endif
        int iCellX = INTMOD( iCell, (int)p_vSystemTime_ElementScale_FlipbookMidKeyTime_FlipbookColumnCount[g_iBatchIndex].w );
        int iCellY = iCell / p_vSystemTime_ElementScale_FlipbookMidKeyTime_FlipbookColumnCount[g_iBatchIndex].w;
        half2 vOffset = half2( iCellX * p_vFlipbookCellSize[g_iBatchIndex].x, iCellY * p_vFlipbookCellSize[g_iBatchIndex].y );
        vUV = vUV * p_vFlipbookCellSize[g_iBatchIndex] + vOffset;
    }
    else vUV = GenUV(    vertIn.vPosition.xyz, 
                        vertIn.vPosition.xyz, 
                        0,                      // No normal.
                        vUV, 
                        vUV,                     // No vUV slot 1.
						vUV, 
						vUV, 
						b_iUVMapping[index], 
                        b_UVTransformEnable[index], 
                        p_mUVTransform[index],
                        0 );
    
    return half4(vUV,0,1);
}

//--------------------------------------------------------------------------------------------------
half4 EmitParticleVertexColor( Input vertIn ) {
    half4 cColor;
    half fT;

    if (b_bezierSmoothColor) {
        float invAge = (1.0f - g_vSizeAndAge.w);
        cColor.rgb = (invAge * invAge) * vertIn.cColor0.rgb;
        cColor.rgb += (2.0f * g_vSizeAndAge.w * invAge) * vertIn.cColor1.rgb;
        cColor.rgb += (g_vSizeAndAge.w * g_vSizeAndAge.w) * vertIn.cColor2.rgb;
    }
    else {
        if ( g_vSizeAndAge.w < p_vMidKeyTimes[g_iBatchIndex].y )
        {
            fT = g_vSizeAndAge.w / p_vMidKeyTimes[g_iBatchIndex].y;
            if ( b_smoothColor ) 
                fT = SmoothStep( fT );
            cColor.rgb = vertIn.cColor0.rgb + ( vertIn.cColor1.rgb - vertIn.cColor0.rgb ) * fT;
        }
        else
        {
            fT = ( g_vSizeAndAge.w - p_vMidKeyTimes[g_iBatchIndex].y ) / ( 1.0f - p_vMidKeyTimes[g_iBatchIndex].y );
            if ( b_smoothColor ) 
                fT = SmoothStep( fT );
            cColor.rgb = vertIn.cColor1.rgb + ( vertIn.cColor2.rgb - vertIn.cColor1.rgb ) * fT;
        }
    }

    if (b_bezierSmoothColor) {
        float invAge = (1.0f - g_vSizeAndAge.w);
        cColor.a = (invAge * invAge) * vertIn.cColor0.a;
        cColor.a += (2.0f * g_vSizeAndAge.w * invAge) * vertIn.cColor1.a;
        cColor.a += (g_vSizeAndAge.w * g_vSizeAndAge.w) * vertIn.cColor2.a;
    }
    else {
        if ( g_vSizeAndAge.w < p_vMidKeyTimes[g_iBatchIndex].z )
        {
            fT = g_vSizeAndAge.w / p_vMidKeyTimes[g_iBatchIndex].z;
            if ( b_smoothColor ) 
                fT = SmoothStep( fT );
            cColor.a = vertIn.cColor0.a + ( vertIn.cColor1.a - vertIn.cColor0.a ) * fT;
        }
        else 
        {
            fT = ( g_vSizeAndAge.w - p_vMidKeyTimes[g_iBatchIndex].z ) / ( 1.0f - p_vMidKeyTimes[g_iBatchIndex].z );
            if ( b_smoothColor ) 
                fT = SmoothStep( fT );
            cColor.a = vertIn.cColor1.a + ( vertIn.cColor2.a - vertIn.cColor1.a ) * fT;
        }
    }

    return cColor;
}

//--------------------------------------------------------------------------------------------------
// eye to vertex
float3 EmitParticleEyeToVertex(Input vertIn) {
    return normalize(vertIn.vPosition.xyz - p_vEyePos);
}

//--------------------------------------------------------------------------------------------------
// FOW uvs
half4 EmitParticleFOWUV (Input vertIn) {
    return mul(float4(vertIn.vPosition.xyz, 1.0), p_mFOWMatrix);
}

//==================================================================================================
float GenerateRotation(in float fAge, in Input vertIn) {
    float fAngle;

    if (b_bezierSmoothRotation) {
        float invAge = (1.0f - fAge);
        fAngle = (invAge * invAge) * vertIn.vRotation.x;
        fAngle += (2.0f * fAge * invAge) * vertIn.vRotation.y;
        fAngle += (fAge * fAge) * vertIn.vRotation.z;
    }
    else {
        float fT;
	    if ( fAge < p_vMidKeyTimes[g_iBatchIndex].w ) {
            fT = fAge / p_vMidKeyTimes[g_iBatchIndex].w;
            if ( b_smoothRotation ) 
                fT = SmoothStep( fT );
		    fAngle = vertIn.vRotation.x + ( vertIn.vRotation.y - vertIn.vRotation.x ) * fT;
        }
	    else {
            fT = ( fAge - p_vMidKeyTimes[g_iBatchIndex].w ) / ( 1.0f - p_vMidKeyTimes[g_iBatchIndex].w );
            if ( b_smoothRotation ) 
                fT = SmoothStep( fT );
            fAngle = vertIn.vRotation.y + ( vertIn.vRotation.z - vertIn.vRotation.y ) * fT;
        }
    }

    return fAngle;
}

//==================================================================================================
void CalculatePositionAndVelocity(inout Input vertIn) {
	float3 vOffsetFromOrigin;
    float3 vInstantaneousVelocity;

    float fTime = p_vSystemTime_ElementScale_FlipbookMidKeyTime_FlipbookColumnCount[g_iBatchIndex].x - vertIn.vBirthDeathAndDrag.x;
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
    else if (b_iInstanceType == PARTICLE_TAIL) {
        vertIn.vInterpolator1.xyz = vInstantaneousVelocity;

        if (b_clampedTailLength) {
            float fSpeed = length(vInstantaneousVelocity);
            float fTailLength;
            if (b_fixedTailLength)
                fTailLength = vertIn.vInterpolator2.x * fSpeed * g_vSizeAndAge.xyz.x;
            else
                fTailLength = max(vertIn.vInterpolator2.x, vertIn.vInterpolator2.x * fSpeed) * g_vSizeAndAge.xyz.x;

            float fOffsetDistance = length(vOffsetFromOrigin);
            if (fOffsetDistance < fTailLength)
                vertIn.vInterpolator2.x = min(fOffsetDistance / (fSpeed * g_vSizeAndAge.xyz.x), vertIn.vInterpolator2.x);
        }
	}
}

//==================================================================================================
void ParticleVertexMain( in Input vertIn, out VertexTransport vertOut ) {
    InitShader( vertOut );
#ifdef COMPILING_SHADER_FOR_OPENGL
    vertIn.cColor0 = vertIn.cColor0.zyxw;
    vertIn.cColor1 = vertIn.cColor1.zyxw;
    vertIn.cColor2 = vertIn.cColor2.zyxw;
    g_iBatchIndex = (int)(vertIn.iBatchIndex.x + 0.1);
    g_iBatchIndex = (int)(p_fParticleBatchIndexRemappingTable[g_iBatchIndex] + 0.1);

#else
    g_iBatchIndex = (int)(vertIn.iBatchIndex.x + 0.1);
    g_iBatchIndex = (int) (p_fParticleBatchIndexRemappingTable[g_iBatchIndex] + 0.1);
#endif

    half fT;
    
    g_vSizeAndAge.w = ( p_vSystemTime_ElementScale_FlipbookMidKeyTime_FlipbookColumnCount[g_iBatchIndex].x - vertIn.vBirthDeathAndDrag.x ) / ( vertIn.vBirthDeathAndDrag.y - vertIn.vBirthDeathAndDrag.x );
    g_vSizeAndAge.w = saturate(g_vSizeAndAge.w);  // to fix the fact that dead particles can still render!

    if (b_bezierSmoothSize) {
        float invAge = (1.0f - g_vSizeAndAge.w);
        g_vSizeAndAge.xyz = (invAge * invAge) * vertIn.vSize.x;
        g_vSizeAndAge.xyz += (2.0f * g_vSizeAndAge.w * invAge) * vertIn.vSize.y;
        g_vSizeAndAge.xyz += (g_vSizeAndAge.w * g_vSizeAndAge.w) * vertIn.vSize.z;
    }
    else {
        if ( g_vSizeAndAge.w < p_vMidKeyTimes[g_iBatchIndex].x )
        {
            fT = g_vSizeAndAge.w / p_vMidKeyTimes[g_iBatchIndex].x;
            if ( b_smoothSize ) 
                fT = SmoothStep( fT );
            g_vSizeAndAge.xyz = vertIn.vSize.x + ( vertIn.vSize.y - vertIn.vSize.x ) * fT;
        }
        else 
        {
            fT = ( g_vSizeAndAge.w - p_vMidKeyTimes[g_iBatchIndex].x ) / ( 1.0f - p_vMidKeyTimes[g_iBatchIndex].x );
            if ( b_smoothSize ) 
                fT = SmoothStep( fT );
            g_vSizeAndAge.xyz = vertIn.vSize.y + ( vertIn.vSize.z - vertIn.vSize.y ) * fT;
        }
    }


    if (b_useProceduralPosition)
        CalculatePositionAndVelocity(vertIn);

    if (b_localSpace) {
        vertIn.vPosition.xyz = mul(float4(vertIn.vPosition.xyz, 1), p_mPRWorldTransform[g_iBatchIndex]).xyz;
    }
    
    

    vertIn.vPosition.xyz += vertIn.vNoiseVector.xyz;

    half3 vCameraForward = p_vCameraDirection;
    
    // :TODO: :NOTE: How about some code reuse here huh?

    if( b_iInstanceType == PARTICLE_SINGLE_AXIS ) {
		
		// fixed vUp dir           
		half3 vRight = normalize(cross( vertIn.vInterpolator2.xyz, vCameraForward));
		
		half fAngle = GenerateRotation(g_vSizeAndAge.w, vertIn);

		half3 vForward = normalize( cross( vRight, vertIn.vInterpolator2.xyz ) );
        half3x3 mRotation = MakeRotation( fAngle, vForward );
		half3 vOffset = vertIn.vOffset.x * vRight + vertIn.vOffset.y * vertIn.vInterpolator2.xyz;
		vOffset *= p_vSystemTime_ElementScale_FlipbookMidKeyTime_FlipbookColumnCount[g_iBatchIndex].y;
		vertIn.vPosition.xyz = vertIn.vPosition.xyz + mul( g_vSizeAndAge.xyz * vOffset, mRotation );

        g_vParticleNormal = normalize(cross(vRight, vForward));
        g_vParticleTangent = vRight;
        g_vParticleBinormal = vForward;
    }
    else if( b_iInstanceType == PARTICLE_FACE_TRAVEL_DIR || b_iInstanceType == PARTICLE_FACE_WORLD_DIR || b_iInstanceType == PARTICLE_EMITTER_ORIENTED || b_iInstanceType == PARTICLE_PHYSICS_ORIENTED ) {
            	                        
        half3 vDirectionVector = normalize( vertIn.vInterpolator2.xyz + half3( 0.0f, 0.0001f, 0.0f ) );
		half3 vRight = normalize( cross( half3( 0.0f, 0.0f, 1.0f ), vDirectionVector ) );
		half3 vUp = normalize( cross( vDirectionVector, vRight ) );
		
		half4 vOffsetAngle;
		//half3 vOffset = vertIn.vOffset.x * vRight + vertIn.vOffset.y * vUp;
		//vOffset *= p_vSystemTime_ElementScale_FlipbookMidKeyTime_FlipbookColumnCount[g_iBatchIndex].y;
		vOffsetAngle.xyz	= vertIn.vOffset.x * vRight + vertIn.vOffset.y * vUp;
		vOffsetAngle.xyz	*= p_vSystemTime_ElementScale_FlipbookMidKeyTime_FlipbookColumnCount[g_iBatchIndex].y;
		vOffsetAngle.w		= GenerateRotation(g_vSizeAndAge.w, vertIn);

        half3x3 mRotation = MakeRotation( vOffsetAngle.w, vDirectionVector );		
		vertIn.vPosition.xyz = vertIn.vPosition.xyz + mul( g_vSizeAndAge.xyz * vOffsetAngle.xyz, mRotation );
    }
    else if( b_iInstanceType == PARTICLE_TERRAIN_ORIENTED ) {
    	// vInterpolator1 = particle DIRECTION
    	// vInterpolator2 = terrain Normal
        
	    half3 vDirectionVector =  vertIn.vInterpolator1.xyz;
        half3 vProjectedDir = vDirectionVector - dot( vDirectionVector, vertIn.vInterpolator2.xyz ) * vertIn.vInterpolator2.xyz;

		half fAngle = GenerateRotation(g_vSizeAndAge.w, vertIn);
        half3x3 mRotation = MakeRotation(fAngle, vertIn.vInterpolator2.xyz );		

        // :TODO: Find a better way.
        if ( dot( vProjectedDir, vProjectedDir ) < 0.01f )
            vProjectedDir = half3( 1.0f, 0.0f, 0.0f );
        vProjectedDir = normalize( vProjectedDir );
	    half3 vRight = ( cross( vProjectedDir, vertIn.vInterpolator2.xyz ) );
        vProjectedDir = mul(vProjectedDir, mRotation);
        vRight = mul(vRight, mRotation);
		half3 vOffset = vertIn.vOffset.x * vRight + vertIn.vOffset.y * vProjectedDir;
		vOffset *= p_vSystemTime_ElementScale_FlipbookMidKeyTime_FlipbookColumnCount[g_iBatchIndex].y;
		vertIn.vPosition.xyz = vertIn.vPosition.xyz + ( g_vSizeAndAge.xyz * vOffset );

        g_vParticleNormal = normalize(cross(vRight, vProjectedDir));
        g_vParticleTangent = vRight;
        g_vParticleBinormal = vProjectedDir;

        // check to see if we need to flip the nbt's cause the particle is oriented "away" from the camera
        float d = -dot(vertIn.vPosition.xyz, g_vParticleNormal);
        float cameraDistFromParticlePlane = dot(float4(p_vEyePos.xyz, 1), float4(g_vParticleNormal, d));
        g_vParticleNormal = (cameraDistFromParticlePlane > 0) ? g_vParticleNormal : -g_vParticleNormal;
        g_vParticleTangent = (cameraDistFromParticlePlane > 0) ? g_vParticleTangent : -g_vParticleTangent;
        g_vParticleBinormal = (cameraDistFromParticlePlane > 0) ? g_vParticleBinormal : -g_vParticleBinormal;
    }
    else if( b_iInstanceType == PARTICLE_TERRAIN_DIR_ORIENTED ) {
    	// vInterpolator1 = particle velocity
    	// vInterpolator2 = terrain Normal
    	
		float fMag = length( vertIn.vInterpolator1.xyz );

		half3 vDirectionVector = normalize( vertIn.vInterpolator1.xyz );
		half3 vProjectedDir = normalize( vDirectionVector - dot( vDirectionVector, vertIn.vInterpolator2.xyz ) * vertIn.vInterpolator2.xyz );
		half3 vRight = ( cross( vProjectedDir, vertIn.vInterpolator2.xyz ) );

		// scale projected dir by the tail length ( to make it bigger as we go faster )
		vProjectedDir = vProjectedDir * max( vertIn.vRotation.x, ( fMag * vertIn.vRotation.x ) );
		half3 vOffset = vertIn.vOffset.x * vRight + vertIn.vOffset.y * vProjectedDir;

		vOffset *= p_vSystemTime_ElementScale_FlipbookMidKeyTime_FlipbookColumnCount[g_iBatchIndex].y;
		vertIn.vPosition.xyz = vertIn.vPosition.xyz + ( g_vSizeAndAge.xyz * vOffset );

        g_vParticleNormal = normalize(cross(vRight, vProjectedDir));
        g_vParticleTangent = vRight;
        g_vParticleBinormal = vProjectedDir;

        // check to see if we need to flip the nbt's cause the particle is oriented "away" from the camera
        float d = -dot(vertIn.vPosition.xyz, g_vParticleNormal);
        float cameraDistFromParticlePlane = dot(float4(p_vEyePos.xyz, 1), float4(g_vParticleNormal, d));
        g_vParticleNormal = (cameraDistFromParticlePlane > 0) ? g_vParticleNormal : -g_vParticleNormal;
        g_vParticleTangent = (cameraDistFromParticlePlane > 0) ? g_vParticleTangent : -g_vParticleTangent;
        g_vParticleBinormal = (cameraDistFromParticlePlane > 0) ? g_vParticleBinormal : -g_vParticleBinormal;
    }
    else if( b_iInstanceType == PARTICLE_TAIL ) {
        vertIn.vInterpolator1.xyz += vertIn.vNoiseVector.xyz;
		
		float fMag = length( vertIn.vInterpolator1.xyz );
        if (b_localSpace)
            vertIn.vInterpolator1.xyz = mul(vertIn.vInterpolator1.xyz, (float3x3)p_mPRWorldTransform[g_iBatchIndex]);

		half3 vDirectionVector = normalize( vertIn.vInterpolator1.xyz );
		half3 vRight = normalize((cross( vCameraForward, vDirectionVector)));
		// scale dir by the tail length ( to make it bigger as we go faster )

        float fTailLength;
        if (b_fixedTailLength)
            fTailLength = vertIn.vInterpolator2.x;
        else
            fTailLength = max(vertIn.vInterpolator2.x, (fMag * vertIn.vInterpolator2.x));
	    vDirectionVector = vDirectionVector * fTailLength;

		half3 vOffset = vertIn.vOffset.x * vRight + vertIn.vOffset.y * vDirectionVector;
		vOffset *= p_vSystemTime_ElementScale_FlipbookMidKeyTime_FlipbookColumnCount[g_iBatchIndex].y;
		vertIn.vPosition.xyz = vertIn.vPosition.xyz + ( g_vSizeAndAge.xyz * vOffset );

        g_vParticleNormal = normalize(cross(vRight, vDirectionVector));
        g_vParticleTangent = vRight;
        g_vParticleBinormal = vDirectionVector;
    }
    else {
		// regular billboard		
		half fAngle = GenerateRotation(g_vSizeAndAge.w, vertIn);
		
        float3 forward = vCameraForward.xyz;
        float3 right = p_vBillboardRight.xyz;
        float3 up = p_vBillboardUp.xyz;
        if ( b_useModelInstancing ) {
            #ifdef COMPILING_SHADER_FOR_OPENGL
                float4x4 mInstanceTransfrom = p_mParticleInstanceTransform[g_iBatchIndex];
            #else
                float4x4 mInstanceTransfrom = p_mParticleInstanceTransform[(int) p_fParticleBatchIndexRemappingTable[vertIn.iBatchIndex.x]];
            #endif
            
            vertIn.vPosition.xyz = mul(float4(vertIn.vPosition.xyz, 1), mInstanceTransfrom).xyz;
        }

        half3x3 mRotation = MakeRotation( fAngle, forward );		
		half3 vOffset = vertIn.vOffset.x * right + vertIn.vOffset.y * up;
		vOffset *= p_vSystemTime_ElementScale_FlipbookMidKeyTime_FlipbookColumnCount[g_iBatchIndex].y;
		vertIn.vPosition.xyz = vertIn.vPosition.xyz + mul( g_vSizeAndAge.xyz * vOffset, mRotation );

        g_vParticleNormal = normalize(cross(right, up));
        g_vParticleTangent = right;
        g_vParticleBinormal = up;
	}

    // transform instanced particles, bill board particles are handled already
    if (b_useModelInstancing && b_iInstanceType!=PARTICLE_BILLBOARD) {
        #ifdef COMPILING_SHADER_FOR_OPENGL
            vertIn.vPosition.xyz = mul(float4(vertIn.vPosition.xyz, 1), p_mParticleInstanceTransform[g_iBatchIndex]).xyz;
        #else
            vertIn.vPosition.xyz = mul(float4(vertIn.vPosition.xyz, 1), p_mParticleInstanceTransform[(int) p_fParticleBatchIndexRemappingTable[vertIn.iBatchIndex.x]]).xyz;
        #endif
    }

    if ( b_enableVertexWarps == 1 )
        vertIn.vPosition.xyz = ApplyWarps( float4(vertIn.vPosition.xyz, 1.0) ).xyz;
    
    vertOut.HPos = EmitParticleHPos( vertIn );
    GenInterpolant( HPosAsUV, EmitParticleHPosAsUV( vertIn ) );
    GenInterpolant( ViewPos, EmitParticleViewPos( vertIn ) );
    GenInterpolant( VertexColor, EmitParticleVertexColor( vertIn ) );
    GenInterpolant( ShadowMapUV, EmitShadowMapUV( vertIn ) );
    GenInterpolant( FogColor, EmitFogColor( vertIn ) );
    GenInterpolant( HalfVec, EmitHalfVec( vertIn, 0 ) );
    GenInterpolant( EyeToVertex, EmitParticleEyeToVertex(vertIn) );
    GenInterpolant( EyeToVertexFresnel, EmitParticleEyeToVertex(vertIn) );
    GenInterpolant( FOWUV, EmitParticleFOWUV(vertIn) );
    
    if(b_usePackedUVEmitter)
    {
        for ( int i = 0; i < b_iUVEmitterCount / 2; i++ ) {
            GenInterpolantUV( UV[i], half4( EmitParticleUV( vertIn, i * 2).xy, EmitParticleUV( vertIn, (i * 2) + 1 ).xy ) );
        }
        if(b_iUVEmitterCount % 2)
            GenInterpolantUV( UV[(b_iUVEmitterCount / 2)], EmitParticleUV( vertIn, b_iUVEmitterCount-1) );
    }
    else
    {
        for ( int i = 0; i < b_iUVEmitterCount; i++ ) {
            GenInterpolantUV( UV[i], EmitParticleUV( vertIn, i ) );
        }
    }
    
	GenInterpolant( ParallaxVector, 0 );

	// Do the NBT in a second pass to minimize temp registers for 2.0
    if( b_iInstanceType == PARTICLE_FACE_TRAVEL_DIR || b_iInstanceType == PARTICLE_FACE_WORLD_DIR || 
		b_iInstanceType == PARTICLE_EMITTER_ORIENTED || b_iInstanceType == PARTICLE_PHYSICS_ORIENTED ) {
		half3 vDirectionVector	= normalize( vertIn.vInterpolator2.xyz + half3( 0.0f, 0.0001f, 0.0f ) );
		half3 vRight			= normalize( cross( half3( 0.0f, 0.0f, 1.0f ), vDirectionVector ) );
		half3 vUp				= normalize( cross( vDirectionVector, vRight ) );

        g_vParticleNormal = normalize(cross(vRight, vUp));
        g_vParticleTangent = vRight;
        g_vParticleBinormal = vUp;

		// check to see if we need to flip the nbt's cause the particle is oriented "away" from the camera
        float d = -dot(vertIn.vPosition.xyz, g_vParticleNormal);
        float cameraDistFromParticlePlane = dot(float4(p_vEyePos.xyz, 1), float4(g_vParticleNormal, d));
        g_vParticleNormal	= g_vParticleNormal * sign(cameraDistFromParticlePlane); //(cameraDistFromParticlePlane > 0) ? g_vParticleNormal : -g_vParticleNormal;
        g_vParticleTangent	= g_vParticleTangent * sign(cameraDistFromParticlePlane); //(cameraDistFromParticlePlane > 0) ? g_vParticleTangent : -g_vParticleTangent;
        g_vParticleBinormal = g_vParticleBinormal * sign(cameraDistFromParticlePlane);; //(cameraDistFromParticlePlane > 0) ? g_vParticleBinormal : -g_vParticleBinormal;
	}

    GenInterpolant( Normal, EmitParticleNormal( vertIn ) );
    GenInterpolant( Tangent, EmitParticleTangent( vertIn ) );
    GenInterpolant( Binormal, EmitParticleBinormal( vertIn ) );
    GenInterpolant( Diffuse, EmitDiffuse( vertIn, g_vParticleNormal ) );
    GenInterpolant( ShadowDiffuse, EmitShadowDiffuse( vertIn, g_vParticleNormal ) );
    GenInterpolant( Specular, EmitSpecular( vertIn ) );
    GenInterpolant( ShadowSpecular, EmitShadowSpecular( vertIn ) );

#ifdef COMPILING_SHADER_FOR_OPENGL
    vertOut.HPos.y *= -1.0;
    vertOut.HPos.z = 2.0 * (vertOut.HPos.z - (0.5 * vertOut.HPos.w));
#endif    
}

#endif  // VERTEXSHADER

#ifdef PIXEL_SHADER
#include "PSMainShading.fx"
#endif