#ifndef _SHADERSYSTEM
#define _SHADERSYSTEM

// This file must be included by all shaders.
#include "Permutations.fx"

#pragma pack_matrix(row_major)

#define FALSE                       0
#define TRUE                        1
    
#define SHADER_VERSION_NULL         0
#define SHADER_VERSION_VS_11        1
#define SHADER_VERSION_VS_20        2
#define SHADER_VERSION_VS_30        3
#define SHADER_VERSION_VS_40        4
#define SHADER_VERSION_PS_13        5
#define SHADER_VERSION_PS_14        6
#define SHADER_VERSION_PS_20        7
#define SHADER_VERSION_PS_2A        8
#define SHADER_VERSION_PS_2B        9
#define SHADER_VERSION_PS_30        10
#define SHADER_VERSION_PS_40        11

#define DETAILLEVEL_LOW             0
#define DETAILLEVEL_MEDIUM          1
#define DETAILLEVEL_HIGH            2

#if ( PIXEL_SHADER_VERSION >= SHADER_VERSION_PS_30 )
#define HALF    float
#define HALF2   float2
#define HALF3   float3
#define HALF4   float4
#else
#define HALF    half
#define HALF2   half2
#define HALF3   half3
#define HALF4   half4
#endif


// these must match c_ParticleMaxBatchCount in CParticleShaderInterface.h 
// and c_ribbonMaxBatchCount in CRibbonShaderInterface.h on the c++ side
#ifdef COMPILING_SHADER_FOR_OPENGL
    #define MAX_BATCHED_PARTICLES 8
#else
    #define MAX_BATCHED_PARTICLES 8
#endif

// these must match c_maxSplatTextureProjectionMatrices in SplatTypes.h on the c++ side
#ifdef COMPILING_SHADER_FOR_OPENGL
    #define MAX_SPLATS 8
#else
    #define MAX_SPLATS 8
#endif

#define MAX_BATCHED_RIBBONS	MAX_BATCHED_PARTICLES

// must match c_ribbonMaxBatchIndexRemappingTableSize in CRibbonShaderInterface.h
// as well as c_particleMaxBatchIndexRemappingTableSize in CParticleShaderInterface.h
#define MAX_BATCH_INDEX_REMAPPING_TABLE_SIZE 32

#ifdef COMPILING_SHADER_FOR_OPENGL
    #define tex2Dgrad tex2D

    #define POSITION_       ATTR0
    #define BLENDWEIGHT_    ATTR1
    #define NORMAL_         ATTR2
    #define COLOR0_         ATTR3
    #define COLOR1_         ATTR4
    #define TANGENT_        ATTR5
    #define BINORMAL_       ATTR6
    #define BLENDINDICES_   ATTR7
    #define TEXCOORD_       ATTR8
    #define TEXCOORD0_      ATTR8
    #define TEXCOORD1_      ATTR9
    #define TEXCOORD2_      ATTR10
    #define TEXCOORD3_      ATTR11
    #define TEXCOORD4_      ATTR12
    #define TEXCOORD5_      ATTR13
    #define TEXCOORD6_      ATTR14
    #define TEXCOORD7_      ATTR15
    
    #define TEXCOORD8_      TANGENT_
    #define ALTPOSITION0_   TEXCOORD7_
    #define ALTPOSITION1_   TEXCOORD6_

	#define VPOS_SEMANTIC   1
#else
    #define POSITION_       POSITION
    #define ALTPOSITION0_   POSITION1
    #define ALTPOSITION1_   POSITION2
    #define BLENDWEIGHT_    BLENDWEIGHT
    #define NORMAL_         NORMAL
    #define COLOR0_         COLOR0
    #define COLOR1_         COLOR1
    #define TANGENT_        TANGENT
    #define BINORMAL_       BINORMAL
    #define BLENDINDICES_   BLENDINDICES
    #define TEXCOORD_       TEXCOORD
    #define TEXCOORD0_      TEXCOORD0
    #define TEXCOORD1_      TEXCOORD1
    #define TEXCOORD2_      TEXCOORD2
    #define TEXCOORD3_      TEXCOORD3
    #define TEXCOORD4_      TEXCOORD4
    #define TEXCOORD5_      TEXCOORD5
    #define TEXCOORD6_      TEXCOORD6
    #define TEXCOORD7_      TEXCOORD7
    #define TEXCOORD8_      TEXCOORD8

	#define VPOS_SEMANTIC   (PIXEL_SHADER_VERSION >= SHADER_VERSION_PS_30)
#endif

#if !CPP_SHADER
    #define GenInterpolantUV( x, y )    INTERPOLANT_##x = y;
    #ifdef COMPILING_SHADER_FOR_OPENGL
        #define GenInterpolant( x, y )     if( INTERPOLANT_##x##ENABLED ) INTERPOLANT_##x = y;
    #else
        #define GenInterpolant( x, y )     INTERPOLANT_##x = y;
    #endif
#else
#define GenInterpolant( x, y )     if ( INTERPOLANT_##x.IsEnabled() ) INTERPOLANT_##x.Set( y );
#define GenInterpolantUV( x, y )   if ( INTERPOLANT_##x.IsEnabled() ) INTERPOLANT_##x.Set( y );
#endif

#endif