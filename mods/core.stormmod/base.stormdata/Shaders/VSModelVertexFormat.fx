//==================================================================================================
//
// Copyright Blizzard Entertainment 2003-2006
//
// This is the shader code for the units.
//==================================================================================================

#ifndef VS_MODEL_VERTEX_FORMAT_H__
#define VS_MODEL_VERTEX_FORMAT_H__

#ifdef VERTEX_SHADER

float2 p_uvRangeOffset;

#ifdef SPLAT_VERTEX_FORMAT
#define BlendIndexType uint4
#else
#define BlendIndexType HALF4
#endif

#if CPP_SHADER

#define HasUVCoord0_(x) x
#define HasUVCoord1_(x) x
#define HasUVCoord2_(x) x
#define HasUVCoord3_(x) x
#define HasCustomUB4N1_(x) x
#define HasVertexBlendWeights_(x) x
#define HasVertexBlendIndices_(x) x
#define HasColor_(x) x

    //==================================================================================================
    // Input structure from d3d runtime
    struct VertDecl {
        float4  vPosition;
        HALF4   vBlendWeights;
        BlendIndexType vBlendIndices;
        HALF4   vNormal;
        HALF2   vUV0;
        HALF2   vUV1;
        HALF2   vUV2;
        HALF2   vUV3;
    #ifdef COMPILING_SHADER_FOR_OPENGL
        HALF4   vTangent;
    #else
        HALF3   vTangent;
    #endif
        //HALF3   vBinormal;
        HALF4   cColor;
        HALF4   cCustomUB4N1;
    };

    //==================================================================================================
    // internal input structure translated from VertDecl
    struct Input {
        // Model.
        float4  vPosition;
        HALF4   vBlendWeights;
        BlendIndexType vBlendIndices;
        HALF4   vNormal;
        HALF2   vUV0;
        HALF2   vUV1;
        HALF2   vUV2;
        HALF2   vUV3;
    #ifdef COMPILING_SHADER_FOR_OPENGL
        HALF4   vTangent;
    #else
        HALF3   vTangent;
    #endif
        HALF3   vBinormal;
        HALF4   cColor;
        HALF4   cCustomUB4N1;

        // Particle.
        HALF4   vSize;
        HALF4   cColor0;
        HALF4   cColor1;
        HALF4   cColor2;
        HALF4   vRotation;
        float4  vBirthDeathAndDrag;
    #ifdef COMPILING_SHADER_FOR_OPENGL
        float4  iBatchIndex;
    #else
        int4    iBatchIndex;
    #endif
        HALF4   vInterpolator1;
        HALF4   vInterpolator2;  
        HALF4   vNoiseVector;  
        HALF2   vOffset;

        // Ribbon.
        HALF2   vUV ;

        HALF4   vUp;
        float4  vInitialVelocity;

        // these two items are not filled in if using procedural position
        float4  vPositionPrev;
        float3  vPositionNext;

    };

#else

#if b_iUVCoordCount >= 1
#define HasUVCoord0_(x) x
#else
#define HasUVCoord0_(x)
#endif

#if b_iUVCoordCount >= 2
#define HasUVCoord1_(x) x
#else
#define HasUVCoord1_(x)
#endif

#if b_iUVCoordCount >= 3
#define HasUVCoord2_(x) x
#else
#define HasUVCoord2_(x)
#endif

#if b_iUVCoordCount >= 4
#define HasUVCoord3_(x) x
#else
#define HasUVCoord3_(x)
#endif

#if b_iLayoutHasCustomUB4N1
#define HasCustomUB4N1_(x) x
#else
#define HasCustomUB4N1_(x)
#endif

#if b_iLayoutHasNoVertexBlendWeights
#define HasVertexBlendWeights_(x)
#else
#define HasVertexBlendWeights_(x) x
#endif

#if b_iLayoutHasNoVertexBlendIndices
#define HasVertexBlendIndices_(x)
#else
#define HasVertexBlendIndices_(x) x
#endif

#if b_iUseSignedIntUVs
#define TexCoordType	int2
#else
#define TexCoordType	HALF2
#endif

#if b_iLayoutHasColor
#define HasColor_(x) x
#else
#define HasColor_(x)
#endif

    //==================================================================================================
    // Input structure from d3d runtime
    struct VertDecl {
        float4  vPosition		 : POSITION_;
        HasVertexBlendWeights_( HALF4   vBlendWeights   : BLENDWEIGHT_; )
        HasVertexBlendIndices_( BlendIndexType vBlendIndices   : BLENDINDICES_; )
        HALF4   vNormal          : NORMAL_;
        HasColor_( HALF4 cColor : COLOR0_; )
        HasUVCoord0_( TexCoordType vUV0 : TEXCOORD0_; )
        HasUVCoord1_( TexCoordType vUV1 : TEXCOORD1_; )
        HasUVCoord2_( TexCoordType vUV2 : TEXCOORD2_; )
        HasUVCoord3_( TexCoordType vUV3 : TEXCOORD3_; )
    #ifdef COMPILING_SHADER_FOR_OPENGL
        HALF4   vTangent         : TANGENT_;
    #else
        HALF3   vTangent         : TANGENT_;
    #endif
        //HasBinormal_( HALF3 vBinormal : BINORMAL_; )
        HasCustomUB4N1_( HALF4 cCustomUB4N1 : COLOR1_; )
    };

    //==================================================================================================
    // internal input structure translated from VertDecl
    struct Input {
        float4  vPosition		: POSITION_;
        HasVertexBlendWeights_( HALF4   vBlendWeights : BLENDWEIGHT_; )
        HasVertexBlendIndices_( BlendIndexType vBlendIndices : BLENDINDICES_; )
        HALF4   vNormal         : NORMAL_;
        HasColor_( HALF4   cColor : COLOR0_; )
        HasUVCoord0_( HALF2   vUV0 : TEXCOORD0_; )
        HasUVCoord1_( HALF2   vUV1 : TEXCOORD1_; )
        HasUVCoord2_( HALF2   vUV2 : TEXCOORD2_; )
        HasUVCoord3_( HALF2   vUV3 : TEXCOORD3_; )
    #ifdef COMPILING_SHADER_FOR_OPENGL
        HALF4   vTangent        : TANGENT_;
    #else
        HALF3   vTangent        : TANGENT_;
    #endif
        HALF3   vBinormal;
        HasCustomUB4N1_( HALF4 cCustomUB4N1 : COLOR1_; )
    };

#endif  // CPP_SHADER

    //--------------------------------------------------------------------------------------------------
    // translate from vertex stream format to our internal vertex shader format
    void TranslateVert (in VertDecl src, out Input dst) {
        dst.vPosition		=   src.vPosition;
        HasVertexBlendWeights_( dst.vBlendWeights = src.vBlendWeights );
        HasVertexBlendIndices_( dst.vBlendIndices = src.vBlendIndices );

        HasUVCoord0_( dst.vUV0 = src.vUV0 * p_uvRangeOffset.x + p_uvRangeOffset.y; )
        HasUVCoord1_( dst.vUV1 = src.vUV1 * p_uvRangeOffset.x + p_uvRangeOffset.y; )
        HasUVCoord2_( dst.vUV2 = src.vUV2 * p_uvRangeOffset.x + p_uvRangeOffset.y; )
        HasUVCoord3_( dst.vUV3 = src.vUV3 * p_uvRangeOffset.x + p_uvRangeOffset.y; )

        // tangent space is in compressed format
        // basis vectors are in ubyte4n format, and normal.w has the handiness of base vectors
        dst.vNormal         =   2.0f*src.vNormal - 1.0f;
        dst.vTangent        =   2.0f*src.vTangent - 1.0f;
        dst.vBinormal       = normalize(cross(dst.vTangent.xyz, dst.vNormal.xyz))*sign(dst.vNormal.w);
    #if defined(COMPILING_SHADER_FOR_OPENGL) || defined(COMPILING_SHADER_FOR_METAL)
        HasColor_( dst.cColor = src.cColor.zyxw; )
    #else
        HasColor_( dst.cColor = src.cColor; )
    #endif
        HasCustomUB4N1_( dst.cCustomUB4N1 = src.cCustomUB4N1; )
    }

#endif  // VERTEX_SHADER

#endif  // VS_MODEL_VERTEX_FORMAT_H__