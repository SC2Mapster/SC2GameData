//==================================================================================================
//
// Copyright Blizzard Entertainment 2003-2006
//
// This is the shader code for the units.
//==================================================================================================

#ifndef VS_MODEL_VERTEX_FORMAT_H__
#define VS_MODEL_VERTEX_FORMAT_H__

#ifdef VERTEX_SHADER

#if CPP_SHADER

//==================================================================================================
// Input structure from d3d runtime
struct VertDecl {
    float4  vPosition;
    half4   vBlendWeights;
    half4   vBlendIndices;
    half4   vNormal;
    half2   vUV0;
    half2   vUV1;
    half2   vUV2;
    half2   vUV3;
#ifdef COMPILING_SHADER_FOR_OPENGL
    half4   vTangent;
#else
    half3   vTangent;
#endif
    half3   vBinormal;
    half4   cColor;
};

//==================================================================================================
// internal input structure translated from Input
struct Input {
    // Model.
    float4  vPosition;
    half4   vBlendWeights;
    half4   vBlendIndices;
    half4   vNormal;
    half2   vUV0;
    half2   vUV1;
    half2   vUV2;
    half2   vUV3;
#ifdef COMPILING_SHADER_FOR_OPENGL
    half4   vTangent;
#else
    half3   vTangent;
#endif
    half3   vBinormal;
    half4   cColor;

    // Particle.
    half4   vSize;
    half4   cColor0;
    half4   cColor1;
    half4   cColor2;
    half3   vRotation;
    float4  vBirthDeathAndDrag;
#ifdef COMPILING_SHADER_FOR_OPENGL
    float4  iBatchIndex;
#else
    int4    iBatchIndex;
#endif
	half4   vInterpolator1;
	half4   vInterpolator2;  
	half4   vNoiseVector;  
    half2   vOffset;

    // Ribbon.
    half2   vUV ;

    half4   vUp;
    float4  vInitialVelocity;

    // these two items are not filled in if using procedural position
    float4  vPositionPrev;
    float3  vPositionNext;

};

#else

//==================================================================================================
// Input structure from d3d runtime
struct VertDecl {
    float4  vPosition		: POSITION_;
    half4   vBlendWeights   : BLENDWEIGHT_;
    half4   vBlendIndices   : BLENDINDICES_;
    half4   vNormal         : NORMAL_;
    half2   vUV0            : TEXCOORD0_;
    half2   vUV1            : TEXCOORD1_;
    half2   vUV2            : TEXCOORD2_;
    half2   vUV3            : TEXCOORD3_;
#ifdef COMPILING_SHADER_FOR_OPENGL
    half4   vTangent        : TANGENT_;
#else
    half3   vTangent        : TANGENT_;
#endif
    half3   vBinormal       : BINORMAL_;
    half4   cColor          : COLOR0_;
};

//==================================================================================================
// internal input structure translated from Input
struct Input {
    float4  vPosition		: POSITION_;
    half4   vBlendWeights   : BLENDWEIGHT_;
    half4   vBlendIndices   : BLENDINDICES_;
    half4   vNormal         : NORMAL_;
    half2   vUV0            : TEXCOORD0_;
    half2   vUV1            : TEXCOORD1_;
    half2   vUV2            : TEXCOORD2_;
    half2   vUV3            : TEXCOORD3_;
#ifdef COMPILING_SHADER_FOR_OPENGL
    half4   vTangent        : TANGENT_;
#else
    half3   vTangent        : TANGENT_;
#endif
    half3   vBinormal       : BINORMAL_;
    half4   cColor          : COLOR0_;
};

#endif

//--------------------------------------------------------------------------------------------------
// translate from vertex stream format to our internal vertex shader format
void TranslateVert (in VertDecl src, out Input dst) {
    dst.vPosition		=   src.vPosition;
    dst.vBlendWeights   =   src.vBlendWeights;
    dst.vBlendIndices   =   src.vBlendIndices;

    if ( b_useCompressedUVs ) {
        dst.vUV0            =   16.0f*src.vUV0;
        dst.vUV1            =   16.0f*src.vUV1;
        dst.vUV2            =   16.0f*src.vUV2;
        dst.vUV3            =   16.0f*src.vUV3;
    } else {
        dst.vUV0            =   src.vUV0;
        dst.vUV1            =   src.vUV1;
        dst.vUV2            =   src.vUV2;
        dst.vUV3            =   src.vUV3;
    }

    // tangent space is in compressed format
    // basis vectors are in ubyte4n format, and normal.w has the handiness of base vectors
    if ( b_useCompressedBasis ) {
        dst.vNormal         =   2.0f*src.vNormal - 1.0f;
        dst.vTangent        =   2.0f*src.vTangent - 1.0f;
        dst.vBinormal       =   normalize(cross(dst.vTangent.xyz, dst.vNormal.xyz))*sign(dst.vNormal.w);
    } else {
        dst.vNormal         =   src.vNormal;
        dst.vTangent        =   src.vTangent;
        dst.vBinormal       =   src.vBinormal;
    }

#if COMPILING_SHADER_FOR_OPENGL 
    dst.cColor          =   src.cColor.zyxw;
#else
    dst.cColor          =   src.cColor;
#endif
}

#endif  // VERTEX_SHADER

#endif// VS_MODEL_VERTEX_FORMAT_H__