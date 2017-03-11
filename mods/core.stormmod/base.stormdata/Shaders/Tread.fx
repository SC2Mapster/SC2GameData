//==================================================================================================
//
// Copyright Blizzard Entertainment 2003-2005
//
// This is the shader code for the units.
//==================================================================================================

#include "ShaderSystem.fx"

#ifdef VERTEX_SHADER


//==================================================================================================
// Input structure

// :TODO: We need a better way to deal with different input structures than just defines.
struct Input
{
    float4  vPosition		: POSITION_;
#ifdef COMPILING_SHADER_FOR_OPENGL
    HALF4   vNormal         : NORMAL_;
#else
    HALF3   vNormal         : NORMAL_;
#endif
#ifdef COMPILING_SHADER_FOR_OPENGL
    HALF4   vTangent        : TANGENT_;
#else
    HALF3   vTangent        : TANGENT_;
#endif
    HALF2   vUV0            : TEXCOORD0_;
    HALF    fBirthTime      : TEXCOORD1_;
    HALF    fIntensity      : TEXCOORD2_;
};

#include "VSEmitters.fx"
#include "VSParallax.fx"
#include "VSLighting.fx"
#include "VSFog.fx"
#include "VSUtils.fx"
#include "VSCommon.fx"
#include "MaterialDefines.fx"
#include "VSUVMapping.fx"

float       p_fFallOffTime;
float       p_fSystemTime;
float       p_fMidTime;

//==================================================================================================
// VERTEX SHADER EMITTERS

//--------------------------------------------------------------------------------------------------
// Homogeneous position.
float4 EmitTreadHPos( Input vertIn ) {
    return mul( float4(vertIn.vPosition.xyz, 1), p_mVPTransform );
}

//--------------------------------------------------------------------------------------------------
// World position.
float4 EmitTreadWorldPos( Input vertIn ) {
    return float4(vertIn.vPosition.xyz, 1.0f);
}

//--------------------------------------------------------------------------------------------------
// Homogeneous position as UV.
float4 EmitTreadHPosAsUV( Input vertIn ) {
    return mul( vertIn.vPosition, p_mVPTransform );
}

//--------------------------------------------------------------------------------------------------
// Camera space position.
float3 EmitTreadViewPos( Input vertIn ) {
    return mul( p_mViewTransform, vertIn.vPosition );          // As 3x4
}

//--------------------------------------------------------------------------------------------------
// Normal.
HALF4 EmitTreadNormal( Input vertIn, float3 vBinormal ) {
    //$shan todo: we need to do this in the exporter and save everybody an interpolant
    float3 righthandedBinormal = cross(vertIn.vNormal.xyz, vertIn.vTangent.xyz);
    float righthanded = dot(vBinormal, righthandedBinormal);
    return HALF4(vertIn.vNormal, sign(righthanded));
}

//--------------------------------------------------------------------------------------------------
// Tangent.
HALF4 EmitTreadTangent( Input vertIn ) {
    return HALF4(vertIn.vTangent.xyz, 1);
}

//--------------------------------------------------------------------------------------------------
// Binormal.
HALF3 EmitTreadBinormal( Input vertIn, float3 vBinormal ) {
    return vBinormal;
}

//--------------------------------------------------------------------------------------------------
// UVs.
HALF4 EmitTreadUV( Input vertIn, int index, HALF3 vLocalPosition, HALF4 vLocalNormal, int b_iUVMapping[8] ) {
    return GenUV(
            vLocalPosition,
            vertIn.vPosition,
            vLocalNormal.xyz,
            vertIn.vNormal, 
            vertIn.vUV0.xy, 
            vertIn.vUV0.xy, 
            vertIn.vUV0.xy, 
            vertIn.vUV0.xy, 
            index,
            0,
            float3(0,0,0),
            b_iUVMapping );
}

//--------------------------------------------------------------------------------------------------
// Vertex color.
HALF4 EmitTreadVertexColor( Input vertIn ) {
    float timeFactor = saturate(1.0f - ((p_fSystemTime - vertIn.fBirthTime - p_fMidTime) / p_fFallOffTime));
    return HALF4(1, 1, 1, timeFactor * vertIn.fIntensity);
}

//--------------------------------------------------------------------------------------------------
// eye to vertex
float3 EmitTreadEyeToVertex(Input vertIn) {
    return normalize(vertIn.vPosition.xyz - p_vEyePos);
}

//--------------------------------------------------------------------------------------------------
// FOW uvs
HALF4 EmitTreadFOWUV (Input vertIn) {
    return mul(vertIn.vPosition, p_mFOWMatrix);
}

//--------------------------------------------------------------------------------------------------
// Main vertex shader body.
//--------------------------------------------------------------------------------------------------
void TreadVertexMain( in Input vertIn, out VertexTransport vertOut ) {
    InitShader( vertOut );
#if defined(COMPILING_SHADER_FOR_OPENGL) || defined(COMPILING_SHADER_FOR_METAL)
    vertIn.vNormal = vertIn.vNormal.zyxw;
    vertIn.vTangent = vertIn.vTangent.zyxw;
    //TODO: Blend indices
#endif    

    float3 vBinormal = float3( 1, 0, 0 );
    DecompressRightHandedBasis( vertIn.vNormal.xyz, vertIn.vTangent.xyz, vBinormal );
    //vertIn.vBinormal *= -1.0f;
    vertIn.vTangent *= -1.0f;
    HALF3 vLocalPosition = vertIn.vPosition;    // Preserve the local position (for possible uv mappings based on local vertex position).
    HALF4 vLocalNormal   = vertIn.vNormal;      // Skinning will transform the position to world space.

    vertOut.HPos = EmitTreadHPos( vertIn );
    INTERPOLANT_HPosAsUV                = EmitTreadHPosAsUV( vertIn );
    INTERPOLANT_WorldPos                = EmitTreadWorldPos( vertIn );
    INTERPOLANT_ViewPos                 = EmitTreadViewPos( vertIn );
    INTERPOLANT_Normal                  = EmitTreadNormal( vertIn );
    INTERPOLANT_Tangent                 = EmitTreadTangent( vertIn );
    INTERPOLANT_Binormal                = EmitTreadBinormal( vertIn );
    INTERPOLANT_VertexColor             = EmitTreadVertexColor( vertIn );
    INTERPOLANT_Diffuse                 = EmitDiffuse( vertIn.vPosition.xyz, vertIn.vNormal );
    INTERPOLANT_Specular                = EmitSpecular();
    INTERPOLANT_ShadowDiffuse           = EmitShadowDiffuse( vertIn.vNormal );
    INTERPOLANT_ShadowSpecular          = EmitShadowSpecular();
    INTERPOLANT_ShadowMapUV             = EmitShadowMapUV( vertIn.vPosition.xyz );
    INTERPOLANT_FogColor                = EmitFogColor( vertIn.vPosition.xyz );
    INTERPOLANT_HalfVec                 = EmitHalfVec( vertIn.vPosition.xyz, 0 );
    INTERPOLANT_EyeToVertex             = EmitTreadEyeToVertex(vertIn);
    INTERPOLANT_EyeToVertexFresnel      = EmitTreadEyeToVertex(vertIn);
    INTERPOLANT_FOWUV                   = EmitTreadFOWUV(vertIn);

    if(b_usePackedUVEmitter)
    {
#if COMPILING_SHADER_WITH_BSL
        [unroll]
#endif
        for ( int i = 0; i < b_iUVEmitterCount / 2; i++ ) {
            GenInterpolantUV( UV[i], HALF4( EmitTreadUV( vertIn, i * 2, b_iUVMapping).xy, EmitTreadUV( vertIn, (i * 2) + 1, b_iUVMapping ).xy ) );
        }
        if(b_iUVEmitterCount % 2)
            GenInterpolantUV( UV[(b_iUVEmitterCount / 2)], EmitTreadUV( vertIn, b_iUVEmitterCount-1, b_iUVMapping) );
    }
    else
    {
#if COMPILING_SHADER_WITH_BSL
        [unroll]
#endif
        for ( int i = 0; i < b_iUVEmitterCount; i++ ) {
            GenInterpolantUV( UV[i], EmitTreadUV( vertIn, i, b_iUVMapping ) );
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