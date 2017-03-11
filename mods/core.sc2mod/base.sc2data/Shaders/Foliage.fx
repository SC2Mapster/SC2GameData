//==================================================================================================
//
// Copyright Blizzard Entertainment 2003-2005
//
// This is the shader code for the units.
//==================================================================================================

#include "ShaderSystem.fx"

#ifdef VERTEX_SHADER

struct Input
{
    float4  vPosition       : POSITION_;
    float2  vCompressedPos  : ALTPOSITION0_;
    HALF4   vBlendWeights   : BLENDWEIGHT_;
    HALF4   vBlendIndices   : BLENDINDICES_;
#ifdef COMPILING_SHADER_FOR_OPENGL
    HALF4   vNormal         : NORMAL_;
#else
    HALF3   vNormal         : NORMAL_;
#endif
    HALF2   vUV0            : TEXCOORD0_;
    HALF2   vUV1            : TEXCOORD1_;
#ifdef COMPILING_SHADER_FOR_OPENGL
    HALF4   vTangent        : TANGENT_;
#else
    HALF3   vTangent        : TANGENT_;
#endif
    HALF3   vBinormal       : BINORMAL_;
    HALF4   cColor          : COLOR0_;
};

#include "VSEmitters.fx"
#include "VSParallax.fx"
#include "VSLighting.fx"
#include "VSFog.fx"
#include "VSUtils.fx"
#include "VSCommon.fx"
#include "MaterialDefines.fx"
#include "VSUVMapping.fx"

#define FOLIAGE_GRID_SIZE   8       // this must match c_foliagePointsPerCell
#define FOLIAGE_UV_RANGE    32.0f   // this must match c_FoliageUVRange

float4      p_vOffsetVectors[FOLIAGE_GRID_SIZE * FOLIAGE_GRID_SIZE];

float3      p_vCompressedPositionScale;
float3      p_vCompressedPositionOffset;

//==================================================================================================
// VERTEX SHADER EMITTERS

//--------------------------------------------------------------------------------------------------
// Homogeneous position.
float4 EmitFoliageHPos( Input vertIn ) {
    return mul( vertIn.vPosition, p_mVPTransform );
}

//--------------------------------------------------------------------------------------------------
// World position.
float4 EmitFoliageWorldPos( Input vertIn ) {
    return float4(vertIn.vPosition.xyz, 1.0f);
}

//--------------------------------------------------------------------------------------------------
// Homogeneous position as UV.
float4 EmitFoliageHPosAsUV( Input vertIn ) {
    return mul( vertIn.vPosition, p_mVPTransform );
}

//--------------------------------------------------------------------------------------------------
// Camera space position.
float3 EmitFoliageViewPos( Input vertIn ) {
    return mul( p_mViewTransform, vertIn.vPosition );          // As 3x4
}

//--------------------------------------------------------------------------------------------------
// Normal.
HALF4 EmitFoliageNormal( Input vertIn ) {
    float3 righthandedBinormal = cross(vertIn.vNormal.xyz, vertIn.vTangent.xyz);
    float righthanded = dot(vertIn.vBinormal, righthandedBinormal);
    return HALF4(vertIn.vNormal.xyz, sign(righthanded));
}


//--------------------------------------------------------------------------------------------------
// Tangent.
HALF4 EmitFoliageTangent( Input vertIn ) {
    return HALF4(vertIn.vTangent.xyz, 1);
}

//--------------------------------------------------------------------------------------------------
// Binormal.
HALF3 EmitFoliageBinormal( Input vertIn ) {
    return vertIn.vBinormal;
}

//--------------------------------------------------------------------------------------------------
// UVs.
HALF4 EmitFoliageUV( Input vertIn, int index, int b_iUVMapping[8] ) {
    return GenUV(
            vertIn.vPosition,
            vertIn.vPosition,
            vertIn.vNormal.xyz, 
            vertIn.vNormal.xyz,
            vertIn.vUV0.xy, 
            vertIn.vUV1.xy, 
            vertIn.vUV0.xy,		// :TODO: These are missing? 
            vertIn.vUV0.xy, 
            index,
            vertIn.vBlendIndices[0],
            float3(0,0,0),
            b_iUVMapping
    );
}

//--------------------------------------------------------------------------------------------------
// Vertex color.
HALF4 EmitFoliageVertexColor( Input vertIn, float fAO ) {
    return HALF4(fAO, fAO, fAO, vertIn.cColor.a);
}

//--------------------------------------------------------------------------------------------------
// eye to vertex
float3 EmitFoliageEyeToVertex(Input vertIn) {
    return normalize(vertIn.vPosition.xyz - p_vEyePos);
}

//--------------------------------------------------------------------------------------------------
// FOW uvs
HALF4 EmitFoliageFOWUV (Input vertIn) {
    return mul(vertIn.vPosition, p_mFOWMatrix);
}

//--------------------------------------------------------------------------------------------------
// Main vertex shader body.
//--------------------------------------------------------------------------------------------------
void FoliageVertexMain( in Input vertIn, out VertexTransport vertOut ) {
    int b_iUVMapping[8];
    int b_UVRandomOffsetEnable[8];
    InitShader( vertOut, b_iUVMapping, b_UVRandomOffsetEnable );
    
#if defined(COMPILING_SHADER_FOR_OPENGL) || defined(COMPILING_SHADER_FOR_METAL)
    vertIn.vNormal.xyz = vertIn.vNormal.zyx;
    vertIn.vTangent.xyz = vertIn.vTangent.zyx;
    vertIn.vBlendWeights.xyz = vertIn.vBlendWeights.zyx;
#endif

    DecompressRightHandedBasis( vertIn.vNormal.xyz, vertIn.vTangent.xyz, vertIn.vBinormal );

    // decompress position
    vertIn.vPosition.xy = (vertIn.vPosition.xy * p_vCompressedPositionScale.xy) + p_vCompressedPositionOffset.xy;
    vertIn.vPosition.z = (vertIn.vCompressedPos.x * p_vCompressedPositionScale.z) + p_vCompressedPositionOffset.z;
    vertIn.vPosition.w = 1.0f;
    float fAO = vertIn.vCompressedPos.y;

    // decompress uvs
    vertIn.vUV0 *= FOLIAGE_UV_RANGE;
    vertIn.vUV1 *= FOLIAGE_UV_RANGE;

    // offset vert by forces
    int4 iFoliageIndices = (int4) vertIn.vBlendIndices;
    vertIn.vPosition.xyz += p_vOffsetVectors[iFoliageIndices[0]].xyz * vertIn.vBlendWeights.x;
    vertIn.vPosition.xyz += p_vOffsetVectors[iFoliageIndices[1]].xyz * vertIn.vBlendWeights.y;
    vertIn.vPosition.xyz += p_vOffsetVectors[iFoliageIndices[2]].xyz * vertIn.vBlendWeights.z;
    vertIn.vPosition.xyz += p_vOffsetVectors[iFoliageIndices[3]].xyz * vertIn.vBlendWeights.w;

    HALF3 cVertexSpecularLighting;
    HALF3 cVertexShadowSpecularLighting;
    HALF3 cVertexShadowSpecularLighting2;

    vertOut.HPos = EmitFoliageHPos( vertIn );

    HALF4 interpNormal   = EmitFoliageNormal( vertIn );
    HALF4 interpTangent  = EmitFoliageTangent( vertIn );
    HALF3 interpBinormal = EmitFoliageBinormal( vertIn );

    WRITE_INTERPOLANT_HPosAsUV                ( EmitFoliageHPosAsUV( vertIn ) );
    WRITE_INTERPOLANT_WorldPos                ( EmitFoliageWorldPos( vertIn ) );
    WRITE_INTERPOLANT_ViewPos                 ( EmitFoliageViewPos( vertIn ) );
    WRITE_INTERPOLANT_Normal                  ( interpNormal );
    WRITE_INTERPOLANT_Tangent                 ( interpTangent );
    WRITE_INTERPOLANT_Binormal                ( interpBinormal );
    WRITE_INTERPOLANT_VertexColor             ( EmitFoliageVertexColor( vertIn, fAO ) );
    WRITE_INTERPOLANT_Diffuse                 ( EmitDiffuse( vertIn.vPosition.xyz, vertIn.vNormal.xyz, HALF4(0,0,0,0), cVertexSpecularLighting, cVertexShadowSpecularLighting, cVertexShadowSpecularLighting2 ) );
    WRITE_INTERPOLANT_Specular                ( EmitSpecular(cVertexSpecularLighting) );
    WRITE_INTERPOLANT_ShadowDiffuse           ( EmitShadowDiffuse(vertIn.vNormal.xyz, HALF4(0,0,0,0), cVertexShadowSpecularLighting, cVertexShadowSpecularLighting2 ) );
    WRITE_INTERPOLANT_ShadowSpecular          ( EmitShadowSpecular(cVertexShadowSpecularLighting) );
    WRITE_INTERPOLANT_ShadowMapUV             ( EmitShadowMapUV( vertIn.vPosition.xyz ) );
    WRITE_INTERPOLANT_FogColor                ( EmitFogColor( vertIn.vPosition.xyz ) );
    WRITE_INTERPOLANT_HalfVec                 ( EmitHalfVec( vertIn.vPosition.xyz, 0 ) );
    WRITE_INTERPOLANT_EyeToVertex             ( EmitFoliageEyeToVertex(vertIn) );
    WRITE_INTERPOLANT_EyeToVertexFresnel      ( EmitFoliageEyeToVertex(vertIn) );
    WRITE_INTERPOLANT_FOWUV                   ( EmitFoliageFOWUV(vertIn) );

    if(b_usePackedUVEmitter)
    {
#if COMPILING_SHADER_WITH_BSL
        [unroll]
#endif
        for ( int i = 0; i < b_iUVEmitterCount / 2; i++ ) {
            GenInterpolantUV( i, HALF4( EmitFoliageUV( vertIn, i * 2, b_iUVMapping).xy, EmitFoliageUV( vertIn, (i * 2) + 1, b_iUVMapping ).xy ) );
        }
        if(b_iUVEmitterCount % 2)
            GenInterpolantUV( (b_iUVEmitterCount / 2), EmitFoliageUV( vertIn, b_iUVEmitterCount-1, b_iUVMapping) );
    }
    else
    {
#if COMPILING_SHADER_WITH_BSL
        [unroll]
#endif
        for ( int i = 0; i < b_iUVEmitterCount; i++ ) {
            GenInterpolantUV( i, EmitFoliageUV( vertIn, i, b_iUVMapping ) );
        }
    }

    WRITE_INTERPOLANT_ParallaxVector( EmitParallaxVector(   vertIn.vPosition.xyz, p_vEyePos, 
                                                        interpNormal.xyz, interpTangent.xyz, interpBinormal.xyz ) );
#ifdef COMPILING_SHADER_FOR_OPENGL
    vertOut.HPos.y *= -1.0;
    vertOut.HPos.z = 2.0 * (vertOut.HPos.z - (0.5 * vertOut.HPos.w));
#endif    
}
    
#endif  // VERTEXSHADER

#ifdef PIXEL_SHADER
#include "PSMainShading.fx"
#endif