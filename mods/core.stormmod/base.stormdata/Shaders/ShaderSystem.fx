#ifndef _SHADERSYSTEM
#define _SHADERSYSTEM

#pragma pack_matrix(row_major)

#define FALSE                       0
#define TRUE                        1

// this must be in sync with EShaderVersion
#define SHADER_VERSION_NULL         0
#define SHADER_VERSION_VS_11        1
#define SHADER_VERSION_VS_20        2
#define SHADER_VERSION_VS_30        3
#define SHADER_VERSION_VS_40        4
#define SHADER_VERSION_VS_50        5
#define SHADER_VERSION_PS_13        6
#define SHADER_VERSION_PS_14        7
#define SHADER_VERSION_PS_20        8
#define SHADER_VERSION_PS_2A        9
#define SHADER_VERSION_PS_2B        10
#define SHADER_VERSION_PS_30        11
#define SHADER_VERSION_PS_40        12

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

#ifdef COMPILING_SHADER_FOR_METAL
    #define ArrayDecl(t) float4
    #define floatRef(v) v.x
    #define float2Ref(v) v.xy
#else
    #define ArrayDecl(t) t
    #define floatRef(v) v
    #define float2Ref(v) v
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
    #define GenInterpolantUV( x, y )    WRITE_INTERPOLANT_UV( x, y );
    #ifdef COMPILING_SHADER_FOR_OPENGL
        #define GenInterpolant( x, y )     if( INTERPOLANT_##x##ENABLED ) WRITE_INTERPOLANT_##x( y );
    #else
        #define GenInterpolant( x, y )     WRITE_INTERPOLANT_##x( y );
    #endif
#else
#define GenInterpolant( x, y )     if ( INTERPOLANT_##x.IsEnabled() ) INTERPOLANT_##x.Set( y );
#define GenInterpolantUV( x, y )   if ( INTERPOLANT_UV_BASE[x].IsEnabled() ) INTERPOLANT_UV_BASE[x].Set( y );
#endif

#if PIXEL_SHADER_VERSION >= SHADER_VERSION_PS_40
    #define texDecl2D(name)         \
        Texture2D       name##_t;    \
        SamplerState    name##_s
    #define texDecl3D(name)         \
        Texture3D       name##_t;    \
        SamplerState    name##_s
    #define texDeclCube(name)         \
        TextureCube       name##_t;    \
        SamplerState    name##_s
    #define texDeclShadow(name)     \
        Texture2D               name##_t; \
        SamplerComparisonState  name##_s;

    #define texSampler(texture)             texture##_s
    #define texTexture(texture)             texture##_t

    #define typeSampler2D                   SamplerState
    #define typeSampler3D                   SamplerState
    #define typeSamplerCube                 SamplerState
    #define typeSamplerShadow               SamplerComparisonState
    #define typeTexture2D                   Texture2D
    #define typeTexture3D                   Texture3D
    #define typeTextureCube                 TextureCube

    #define sampleTex2D(texture, sampler, coord)                texture.Sample(sampler, coord)
    #define sampleTex2Dlod(texture, sampler, coord)             texture.SampleLevel(sampler, coord.xy, coord.w)
    #define sampleTex2Dbias(texture, sampler, coord)            texture.SampleBias(sampler, coord.xy, coord.w)
    #define sampleTex2Dgrad(texture, sampler, coord, ddx, ddy)  texture.SampleGrad(sampler, coord, ddx, ddy)
    #define sampleTex3D(texture, sampler, coord)                texture.Sample(sampler, coord)
    #define sampleTex3Dgrad(texture, sampler, coord, ddx, ddy)  texture.SampleGrad(sampler, coord, ddx, ddy)
    #define sampleTex3Dbias(texture, sampler, coord)            texture.SampleBias(sampler, coord, coord.w)
    #define sampleTex3Dlod(texture, sampler, coord)             texture.SampleLevel(sampler, coord, coord.w)
    #define sampleTexCube(texture, sampler, coord)              texture.Sample(sampler, coord)
    #define sampleTexCubegrad(texture, sampler, coord, ddx, ddy) texture.SampleGrad(sampler, coord, ddx, ddy)
    #define sampleTexCubebias(texture, sampler, coord)          texture.SampleBias(sampler, coord, coord.w)
    #define sampleTexCubelod(texture, sampler, coord)           texture.SampleLevel(sampler, coord.xyz, coord.w)
    #define sampleTexShadow(texture, sampler, coord)            texture.SampleCmpLevelZero(sampler, coord.xy / coord.w, coord.z)
#else
    #define texDecl2D(name)     sampler2D   name
    #define texDecl3D(name)     sampler3D   name
    #define texDeclCube(name)   samplerCUBE name
    #define texDeclShadow(name) sampler2D   name

    #define texSampler(texture)             texture
    #define texTexture(texture)             float4(0,0,0,0)

    #define typeSampler2D                   sampler2D
    #define typeSampler3D                   sampler3D
    #define typeSamplerCube                 samplerCUBE
    #define typeSamplerShadow               sampler2D
    #define typeTexture2D                   float4
    #define typeTexture3D                   float4
    #define typeTextureCube                 float4

    #define sampleTex2D(texture, sampler, coord)                tex2D(sampler, coord)
    #define sampleTex2Dlod(texture, sampler, coord)             tex2Dlod(sampler, coord)
    #define sampleTex2Dbias(texture, sampler, coord)            tex2Dbias(sampler, coord)
    #define sampleTex2Dgrad(texture, sampler, coord, ddx, ddy)  tex2Dgrad(sampler, coord, ddx, ddy)
    #define sampleTex3D(texture, sampler, coord)                tex3D(sampler, coord)
    #define sampleTex3Dgrad(texture, sampler, coord, ddx, ddy)  tex3Dgrad(sampler, coord, ddx, ddy)
    #define sampleTex3Dlod(texture, sampler, coord)             tex3Dlod(sampler, coord)
    #define sampleTex3Dbias(texture, sampler, coord)            tex3Dbias(sampler, coord)
    #define sampleTexCube(texture, sampler, coord)              texCUBE(sampler, coord)
    #define sampleTexCubegrad(texture, sampler, coord, ddx, ddy) texCUBEgrad(sampler, coord, ddx, ddy)
    #define sampleTexCubebias(texture, sampler, coord)          texCUBEbias(sampler, coord)
    #define sampleTexCubelod(texture, sampler, coord)           texCUBElod(sampler, coord)
    #define sampleTexShadow(texture, sampler, coord)            tex2Dproj(sampler, coord)
#endif

#define sample2D(name, coord)               sampleTex2D(texTexture(name), texSampler(name), coord)
#define sample2Dlod(name, coord)            sampleTex2Dlod(texTexture(name), texSampler(name), coord)
#define sample2Dbias(name, coord)           sampleTex2Dbias(texTexture(name), texSampler(name), coord)
#define sample2Dgrad(name, coord, ddx, ddy) sampleTex2Dgrad(texTexture(name), texSampler(name), coord, ddx, ddy)
#define sample3D(name, coord)               sampleTex3D(texTexture(name), texSampler(name), coord)
#define sample3Dgrad(name, coord, ddx, ddy) sampleTex3Dgrad(texTexture(name), texSampler(name), coord, ddx, ddy)
#define sample3Dlod(name, coord, ddx, ddy) sampleTex3Dgrad(texTexture(name), texSampler(name), coord, ddx, ddy)
#define sample3Dbias(name, coord)           sampleTex3Dbias(texTexture(name), texSampler(name), coord)
#define sampleCube(name, coord)             sampleTexCube(texTexture(name), texSampler(name), coord)
#define sampleCubegrad(name, coord)         sampleTexCubegrad(texTexture(name), texSampler(name), coord, ddx, ddy)
#define sampleCubebias(name, coord)         sampleTexCubebias(texTexture(name), texSampler(name), coord)
#define sampleCubelod(name, coord)          sampleTexCubelod(texTexture(name), texSampler(name), coord)
#define sampleShadow(name, coord)           sampleTexShadow(texTexture(name), texSampler(name), coord)

#endif