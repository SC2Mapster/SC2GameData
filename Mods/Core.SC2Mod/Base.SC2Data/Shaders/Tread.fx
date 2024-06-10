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
    half4   vNormal         : NORMAL_;
#else
    half3   vNormal         : NORMAL_;
#endif
#ifdef COMPILING_SHADER_FOR_OPENGL
    half4   vTangent        : TANGENT_;
#else
    half3   vTangent        : TANGENT_;
#endif
    half2   vUV0            : TEXCOORD0_;
    half    fBirthTime      : TEXCOORD1_;
    half    fIntensity      : TEXCOORD2_;
};

#include "VSEmitters.fx"
#include "VSParallax.fx"
#include "VSLighting.fx"
#include "VSFog.fx"
#include "VSUtils.fx"
#include "VSCommon.fx"
#include "MaterialDefines.fx"
#include "VSUVMapping.fx"

HALF3       g_vLocalPosition;                           // Local space vertex position.
HALF3       g_vBinormal;

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
half4 EmitTreadNormal( Input vertIn ) {
    //$shan todo: we need to do this in the exporter and save everybody an interpolant
    float3 righthandedBinormal = cross(vertIn.vNormal.xyz, vertIn.vTangent.xyz);
    float righthanded = dot(g_vBinormal, righthandedBinormal);
    return half4(vertIn.vNormal, sign(righthanded));
}

//--------------------------------------------------------------------------------------------------
// Tangent.
half4 EmitTreadTangent( Input vertIn ) {
    return half4(vertIn.vTangent.xyz, 1);
}

//--------------------------------------------------------------------------------------------------
// Binormal.
half3 EmitTreadBinormal( Input vertIn ) {
    return g_vBinormal;
}

//--------------------------------------------------------------------------------------------------
// UVs.
half4 EmitTreadUV( Input vertIn, int index ) {
    return GenUV(
            g_vLocalPosition,
            vertIn.vPosition,
            vertIn.vNormal, 
            vertIn.vUV0.xy, 
            vertIn.vUV0.xy, 
            vertIn.vUV0.xy, 
            vertIn.vUV0.xy, 
            b_iUVMapping[index], 
            b_UVTransformEnable[index],
            p_mUVTransform[index],
            0 );
}

//--------------------------------------------------------------------------------------------------
// Vertex color.
half4 EmitTreadVertexColor( Input vertIn ) {
    float timeFactor = saturate(1.0f - ((p_fSystemTime - vertIn.fBirthTime - p_fMidTime) / p_fFallOffTime));
    return half4(1, 1, 1, timeFactor * vertIn.fIntensity);
}

//--------------------------------------------------------------------------------------------------
// eye to vertex
float3 EmitTreadEyeToVertex(Input vertIn) {
    return normalize(vertIn.vPosition.xyz - p_vEyePos);
}

//--------------------------------------------------------------------------------------------------
// FOW uvs
half4 EmitTreadFOWUV (Input vertIn) {
    return mul(vertIn.vPosition, p_mFOWMatrix);
}

//--------------------------------------------------------------------------------------------------
// Main vertex shader body.
//--------------------------------------------------------------------------------------------------
void TreadVertexMain( in Input vertIn, out VertexTransport vertOut ) {
    InitShader( vertOut );
#ifdef COMPILING_SHADER_FOR_OPENGL
    vertIn.vNormal = vertIn.vNormal.zyxw;
    vertIn.vTangent = vertIn.vTangent.zyxw;
    //TODO: Blend indices
#endif    

    if ( b_useCompressedBasis ) {
        DecompressRightHandedBasis( vertIn.vNormal.xyz, vertIn.vTangent.xyz, g_vBinormal );
        //vertIn.vBinormal *= -1.0f;
        vertIn.vTangent *= -1.0f;
    }
    g_vLocalPosition = vertIn.vPosition;    // Preserve the local position (for possible uv mappings based on local vertex position).
                                            // Skinning will transform the position to world space.
    vertOut.HPos = EmitTreadHPos( vertIn );
    INTERPOLANT_HPosAsUV                = EmitTreadHPosAsUV( vertIn );
    INTERPOLANT_WorldPos                = EmitTreadWorldPos( vertIn );
    INTERPOLANT_ViewPos                 = EmitTreadViewPos( vertIn );
    INTERPOLANT_Normal                  = EmitTreadNormal( vertIn );
    INTERPOLANT_Tangent                 = EmitTreadTangent( vertIn );
    INTERPOLANT_Binormal                = EmitTreadBinormal( vertIn );
    INTERPOLANT_VertexColor             = EmitTreadVertexColor( vertIn );
    INTERPOLANT_Diffuse                 = EmitDiffuse( vertIn, vertIn.vNormal );
    INTERPOLANT_Specular                = EmitSpecular( vertIn );
    INTERPOLANT_ShadowDiffuse           = EmitShadowDiffuse( vertIn, vertIn.vNormal );
    INTERPOLANT_ShadowSpecular          = EmitShadowSpecular( vertIn );
    INTERPOLANT_ShadowMapUV             = EmitShadowMapUV( vertIn );
    INTERPOLANT_FogColor                = EmitFogColor( vertIn );
    INTERPOLANT_HalfVec                 = EmitHalfVec( vertIn, 0 );
    INTERPOLANT_EyeToVertex             = EmitTreadEyeToVertex(vertIn);
    INTERPOLANT_EyeToVertexFresnel      = EmitTreadEyeToVertex(vertIn);
    INTERPOLANT_FOWUV                   = EmitTreadFOWUV(vertIn);

    if(b_usePackedUVEmitter)
    {
        for ( int i = 0; i < b_iUVEmitterCount / 2; i++ ) {
            GenInterpolantUV( UV[i], half4( EmitTreadUV( vertIn, i * 2).xy, EmitTreadUV( vertIn, (i * 2) + 1 ).xy ) );
        }
        if(b_iUVEmitterCount % 2)
            GenInterpolantUV( UV[(b_iUVEmitterCount / 2)], EmitTreadUV( vertIn, b_iUVEmitterCount-1) );
    }
    else
    {
        for ( int i = 0; i < b_iUVEmitterCount; i++ ) {
            GenInterpolantUV( UV[i], EmitTreadUV( vertIn, i ) );
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
