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
    half4   vBlendWeights   : BLENDWEIGHT_;
    half4   vBlendIndices   : BLENDINDICES_;
#ifdef COMPILING_SHADER_FOR_OPENGL
    half4   vNormal         : NORMAL_;
#else
    half3   vNormal         : NORMAL_;
#endif
    half2   vUV0            : TEXCOORD0_;
    half2   vUV1            : TEXCOORD1_;
#ifdef COMPILING_SHADER_FOR_OPENGL
    half4   vTangent        : TANGENT_;
#else
    half3   vTangent        : TANGENT_;
#endif
    half3   vBinormal       : BINORMAL_;
    half4   cColor          : COLOR0_;
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

float g_fAO;

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
half4 EmitFoliageNormal( Input vertIn ) {
    float3 righthandedBinormal = cross(vertIn.vNormal.xyz, vertIn.vTangent.xyz);
    float righthanded = dot(vertIn.vBinormal, righthandedBinormal);
    return half4(vertIn.vNormal.xyz, sign(righthanded));
}


//--------------------------------------------------------------------------------------------------
// Tangent.
half4 EmitFoliageTangent( Input vertIn ) {
    return half4(vertIn.vTangent.xyz, 1);
}

//--------------------------------------------------------------------------------------------------
// Binormal.
half3 EmitFoliageBinormal( Input vertIn ) {
    return vertIn.vBinormal;
}

//--------------------------------------------------------------------------------------------------
// UVs.
half4 EmitFoliageUV( Input vertIn, int index ) {
    return GenUV(
            vertIn.vPosition,
            vertIn.vPosition,
            vertIn.vNormal.xyz, 
            vertIn.vUV0.xy, 
            vertIn.vUV1.xy, 
            vertIn.vUV0.xy,		// :TODO: These are missing? 
            vertIn.vUV0.xy, 
            b_iUVMapping[index], 
            b_UVTransformEnable[index],
            p_mUVTransform[index],
            vertIn.vBlendIndices[0] );
}

//--------------------------------------------------------------------------------------------------
// Vertex color.
half4 EmitFoliageVertexColor( Input vertIn ) {
    return half4(g_fAO, g_fAO, g_fAO, vertIn.cColor.a);
}

//--------------------------------------------------------------------------------------------------
// eye to vertex
float3 EmitFoliageEyeToVertex(Input vertIn) {
    return normalize(vertIn.vPosition.xyz - p_vEyePos);
}

//--------------------------------------------------------------------------------------------------
// FOW uvs
half4 EmitFoliageFOWUV (Input vertIn) {
    return mul(vertIn.vPosition, p_mFOWMatrix);
}

//--------------------------------------------------------------------------------------------------
// Main vertex shader body.
//--------------------------------------------------------------------------------------------------
void FoliageVertexMain( in Input vertIn, out VertexTransport vertOut ) {
    InitShader( vertOut );
    
#if COMPILING_SHADER_FOR_OPENGL 
    vertIn.vNormal = vertIn.vNormal.zyxw;
    vertIn.vTangent = vertIn.vTangent.zyxw;
    vertIn.vBlendWeights = vertIn.vBlendWeights.zyxw;
#endif

    if (b_useCompressedBasis)
        DecompressRightHandedBasis( vertIn.vNormal.xyz, vertIn.vTangent.xyz, vertIn.vBinormal );

    // decompress position
    vertIn.vPosition.xy = (vertIn.vPosition.xy * p_vCompressedPositionScale.xy) + p_vCompressedPositionOffset.xy;
    vertIn.vPosition.z = (vertIn.vCompressedPos.x * p_vCompressedPositionScale.z) + p_vCompressedPositionOffset.z;
    vertIn.vPosition.w = 1.0f;
    g_fAO = vertIn.vCompressedPos.y;

    // decompress uvs
    vertIn.vUV0 *= FOLIAGE_UV_RANGE;
    vertIn.vUV1 *= FOLIAGE_UV_RANGE;

    // offset vert by forces
    int4 iFoliageIndices = (int4) vertIn.vBlendIndices;
    vertIn.vPosition.xyz += p_vOffsetVectors[iFoliageIndices[0]].xyz * vertIn.vBlendWeights.x;
    vertIn.vPosition.xyz += p_vOffsetVectors[iFoliageIndices[1]].xyz * vertIn.vBlendWeights.y;
    vertIn.vPosition.xyz += p_vOffsetVectors[iFoliageIndices[2]].xyz * vertIn.vBlendWeights.z;
    vertIn.vPosition.xyz += p_vOffsetVectors[iFoliageIndices[3]].xyz * vertIn.vBlendWeights.w;

    vertOut.HPos = EmitFoliageHPos( vertIn );
    INTERPOLANT_HPosAsUV                = EmitFoliageHPosAsUV( vertIn );
    INTERPOLANT_WorldPos                = EmitFoliageWorldPos( vertIn );
    INTERPOLANT_ViewPos                 = EmitFoliageViewPos( vertIn );
    INTERPOLANT_Normal                  = EmitFoliageNormal( vertIn );
    INTERPOLANT_Tangent                 = EmitFoliageTangent( vertIn );
    INTERPOLANT_Binormal                = EmitFoliageBinormal( vertIn );
    INTERPOLANT_VertexColor             = EmitFoliageVertexColor( vertIn );
    INTERPOLANT_Diffuse                 = EmitDiffuse( vertIn, vertIn.vNormal.xyz );
    INTERPOLANT_Specular                = EmitSpecular( vertIn );
    INTERPOLANT_ShadowDiffuse           = EmitShadowDiffuse( vertIn, vertIn.vNormal.xyz );
    INTERPOLANT_ShadowSpecular          = EmitShadowSpecular( vertIn );
    INTERPOLANT_ShadowMapUV             = EmitShadowMapUV( vertIn );
    INTERPOLANT_FogColor                = EmitFogColor( vertIn );
    INTERPOLANT_HalfVec                 = EmitHalfVec( vertIn, 0 );
    INTERPOLANT_EyeToVertex             = EmitFoliageEyeToVertex(vertIn);
    INTERPOLANT_EyeToVertexFresnel      = EmitFoliageEyeToVertex(vertIn);
    INTERPOLANT_FOWUV                   = EmitFoliageFOWUV(vertIn);

    if(b_usePackedUVEmitter)
    {
        for ( int i = 0; i < b_iUVEmitterCount / 2; i++ ) {
            GenInterpolantUV( UV[i], half4( EmitFoliageUV( vertIn, i * 2).xy, EmitFoliageUV( vertIn, (i * 2) + 1 ).xy ) );
        }
        if(b_iUVEmitterCount % 2)
            GenInterpolantUV( UV[(b_iUVEmitterCount / 2)], EmitFoliageUV( vertIn, b_iUVEmitterCount-1) );
    }
    else
    {
        for ( int i = 0; i < b_iUVEmitterCount; i++ ) {
            GenInterpolantUV( UV[i], EmitFoliageUV( vertIn, i ) );
        }
    }

    INTERPOLANT_ParallaxVector  = EmitParallaxVector(   vertIn.vPosition.xyz, p_vEyePos, 
                                                        INTERPOLANT_Normal.xyz, INTERPOLANT_Tangent.xyz, INTERPOLANT_Binormal.xyz );
#ifdef COMPILING_SHADER_FOR_OPENGL
    vertOut.HPos.y *= -1.0;
    vertOut.HPos.z = 2.0 * (vertOut.HPos.z - (0.5 * vertOut.HPos.w));
#endif    
}
    
#endif  // VERTEXSHADER

#ifdef PIXEL_SHADER
#include "PSMainShading.fx"
#endif
