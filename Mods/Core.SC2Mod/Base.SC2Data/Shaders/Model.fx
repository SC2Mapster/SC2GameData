//==================================================================================================
//
// Copyright Blizzard Entertainment 2003-2005
//
// This is the shader code for the units.
//==================================================================================================

#include "ShaderSystem.fx"

#ifdef VERTEX_SHADER

#include "VSModelVertexFormat.fx"
#include "VSEmitters.fx"
#include "VSSkinning.fx"
#include "VSVertexWarp.fx"
#include "VSUtils.fx"
#include "VSCommon.fx"
#include "VSUVMapping.fx"
#include "VSLighting.fx"
#include "VSFog.fx"
#include "VSParallax.fx"

static  half3       g_vLocalPosition;                           // Local space vertex position.

float4x4            p_mTerrainTextureMatrix;
float4              g_InvCreepTextureRotation;
float4              g_CreepTextureRotation;
float4x4            p_mInstanceTransform;

HALF4               p_vVectorUIColor;
float4              p_vVectorUIInterpolant0;
float4              p_vVectorUIInterpolant1;        // x == inner radius, y == outer radius, z == falloff, w == 1/falloff
float4              p_vVectorUIInterpolant2;        // x == segment count, y == percent solid, (z,w) == rotation axis
float4              p_vSplatAttenuationPlane;

//==================================================================================================
// VERTEX SHADER EMITTERS

//--------------------------------------------------------------------------------------------------
// Homogeneous position.
float4 EmitModelHPos( Input vertIn ) {
    return mul( vertIn.vPosition, p_mVPTransform );
}

//--------------------------------------------------------------------------------------------------
// World position.
float4 EmitModelWorldPos( Input vertIn ) {
    return float4(vertIn.vPosition.xyz, 1.0f);
}

//--------------------------------------------------------------------------------------------------
// Homogeneous position as UV.
float4 EmitModelHPosAsUV( Input vertIn ) {
    return mul( vertIn.vPosition, p_mVPTransform );
}

//--------------------------------------------------------------------------------------------------
// Camera space position.
float3 EmitModelViewPos( Input vertIn ) {
    return mul( p_mViewTransform, vertIn.vPosition );          // As 3x4
}

//--------------------------------------------------------------------------------------------------
// Normal. w is the handiness
half4 EmitModelNormal( Input vertIn ) {
    if ( b_useCompressedBasis )
        return vertIn.vNormal;
    else {
        float3 righthandedBinormal = cross(vertIn.vNormal.xyz, vertIn.vTangent.xyz);
        float righthanded = dot(vertIn.vBinormal, righthandedBinormal);
        return half4(vertIn.vNormal.xyz, sign(righthanded));
    }
}

//--------------------------------------------------------------------------------------------------
// Tangent.
half4 EmitModelTangent( Input vertIn ) {
    if ( b_iShadingMode == SHADINGMODE_TERRAIN )
        return half4(ComputeGridTangent(vertIn.vNormal.xyz), 1);
    else
        // :TODO: This will break parallax mapping - shouldn't normalize.
        return half4(normalize( vertIn.vTangent.xyz ),1);
}

//--------------------------------------------------------------------------------------------------
// Binormal.
half3 EmitModelBinormal( Input vertIn, float3 vTangent ) {
    if ( b_iShadingMode == SHADINGMODE_TERRAIN )
        return normalize(cross(vTangent.xyz, vertIn.vNormal.xyz));
    else {

        if ( b_useCompressedBasis )
	        // sign of INTERPOLANT_Normal.w is the handiness
	        return cross(vertIn.vNormal.xyz, vTangent.xyz) * vertIn.vNormal.w;

        // :TODO: This will break parallax mapping - shouldn't normalize.
        return normalize(vertIn.vBinormal);
    }
}

//--------------------------------------------------------------------------------------------------
// UVs.
half4 EmitModelUV( Input vertIn, int index ) {
    return GenUV(
            g_vLocalPosition,
            vertIn.vPosition.xyz,
            vertIn.vNormal.xyz, 
            vertIn.vUV0.xy, 
            vertIn.vUV1.xy, 
            vertIn.vUV2.xy, 
            vertIn.vUV3.xy, 
            b_iUVMapping[index], 
            b_UVTransformEnable[index],
            p_mUVTransform[index],
            0);                         // we're forcing index 0 here, splats that render on models don't
                                        // batch, so this enforces the proper index in the texture projection
                                        // matrix array
}

//--------------------------------------------------------------------------------------------------
// Vertex color.
half4 EmitModelVertexColor( Input vertIn ) {
    // vector ui splat
    if (b_iShadingMode == SHADINGMODE_VECTORUI) {
        return p_vVectorUIColor;
    }
    // triangle id
    else if (b_iShadingMode == SHADINGMODE_MODEL_TRIANGLE_ID) {
        float4 id = vertIn.cColor;
        return id;
    }
    // material splat on model
    else if (b_splatTextureProjectorEnabled) {
        float attenuation = 1.0f - (dot(vertIn.vPosition.xyz, p_vSplatAttenuationPlane.xyz) + p_vSplatAttenuationPlane.w);
        return half4(vertIn.cColor.x, vertIn.cColor.y, vertIn.cColor.z, vertIn.cColor.w * attenuation);
    }
    // normal rendering
    else {
        return vertIn.cColor;
    }
}

//--------------------------------------------------------------------------------------------------
// eye to vertex
float3 EmitModelEyeToVertex(Input vertIn) {
    return normalize(vertIn.vPosition.xyz - p_vEyePos);
}

//--------------------------------------------------------------------------------------------------
// FOW uvs
half4 EmitModelFOWUV (Input vertIn) {
    return mul(vertIn.vPosition, p_mFOWMatrix);
}

//--------------------------------------------------------------------------------------------------
// terrain blended textue uvs
half4 EmitTerrainBlendedTextureUV (Input vertIn) {
    if ( !b_computeHeight )
        return mul(vertIn.vPosition, p_mTerrainTextureMatrix);
    else
        return vertIn.vPosition.z;
}

//--------------------------------------------------------------------------------------------------
// terrain blended textue uvs
half4 EmitTerrainCreepUV (Input vertIn) {
    half4 baseUVs = EmitTerrainBlendedTextureUV(vertIn);
    return half4(mul(float2x2(g_CreepTextureRotation), float2(baseUVs.x, -baseUVs.y)), 0, 1);
}

//--------------------------------------------------------------------------------------------------
// Main vertex shader body.
//--------------------------------------------------------------------------------------------------
void ModelVertexMain( in VertDecl streamIn, out VertexTransport vertOut ) {
    InitShader( vertOut );

    // translate vertex stream format into our vertex shader vertex format
    Input vertIn;
    TranslateVert(streamIn, vertIn);

    g_vLocalPosition = vertIn.vPosition.xyz;    // Preserve the local position (for possible uv mappings based on local vertex position).
                                                // Skinning will transform the position to world space.

    Skin( vertIn.vPosition, vertIn.vNormal.xyz, vertIn.vTangent.xyz, vertIn.vBinormal.xyz, vertIn.vBlendWeights, vertIn.vBlendIndices );

    // transform instance
    if ( b_useModelInstancing )
        vertIn.vPosition.xyz = mul(float4(vertIn.vPosition.xyz,1), p_mInstanceTransform).xyz;

    if ( b_enableVertexWarps == 1 )
        vertIn.vPosition = ApplyWarps( vertIn.vPosition );
    
    vertOut.HPos = EmitModelHPos( vertIn );
    
    GenInterpolant( HPosAsUV,   EmitModelHPosAsUV( vertIn ) );
    GenInterpolant( WorldPos,   EmitModelWorldPos( vertIn ) );
    GenInterpolant( ViewPos,    EmitModelViewPos( vertIn ) );
    GenInterpolant( Normal,     EmitModelNormal( vertIn ) );
    GenInterpolant( Tangent,    EmitModelTangent( vertIn ) );
    GenInterpolant( Binormal,   EmitModelBinormal( vertIn, INTERPOLANT_Tangent.xyz ) );

        // if we're doing creep, we need to adjust the tangent and binormal if the creep texture is rotated
    if (b_creepEnabled) {
        INTERPOLANT_Tangent.xy = mul(float2x2(g_InvCreepTextureRotation), INTERPOLANT_Tangent.xy);
        INTERPOLANT_Binormal.xy = mul(float2x2(g_InvCreepTextureRotation), INTERPOLANT_Binormal.xy);
    }

    GenInterpolant( VertexColor,        EmitModelVertexColor( vertIn ) );
    GenInterpolant( Diffuse,            EmitDiffuse( vertIn, vertIn.vNormal.xyz ) );
    GenInterpolant( Specular,           EmitSpecular( vertIn ) );
    GenInterpolant( ShadowDiffuse,      EmitShadowDiffuse( vertIn, vertIn.vNormal.xyz ) );
    GenInterpolant( ShadowSpecular,     EmitShadowSpecular( vertIn ) );
    GenInterpolant( ShadowMapUV,        EmitShadowMapUV( vertIn ) );
    GenInterpolant( FogColor,           EmitFogColor( vertIn ) );
    GenInterpolant( HalfVec,            EmitHalfVec( vertIn, 0 ) );
    GenInterpolant( EyeToVertex,        EmitModelEyeToVertex( vertIn ) );
    GenInterpolant( EyeToVertexFresnel, EmitModelEyeToVertex( vertIn ) );
    GenInterpolant( FOWUV,              EmitModelFOWUV( vertIn ) );
    GenInterpolant( TerrainUV,          EmitTerrainBlendedTextureUV( vertIn ) );
    GenInterpolant( CreepTerrainUV,     EmitTerrainCreepUV( vertIn ) );

    if(b_usePackedUVEmitter)
    {
        for ( int i = 0; i < b_iUVEmitterCount / 2; i++ ) {
            GenInterpolantUV( UV[i], half4( EmitModelUV( vertIn, i * 2).xy, EmitModelUV( vertIn, (i * 2) + 1 ).xy ) );
        }
        if(b_iUVEmitterCount % 2)
            GenInterpolantUV( UV[(b_iUVEmitterCount / 2)], EmitModelUV( vertIn, b_iUVEmitterCount-1) );
    }
    else
    {
        for ( int i = 0; i < b_iUVEmitterCount; i++ ) {
            GenInterpolantUV( UV[i], EmitModelUV( vertIn, i ) );
        }
    }

    GenInterpolant( ParallaxVector, EmitParallaxVector(     vertIn.vPosition.xyz, p_vEyePos, 
                                                            INTERPOLANT_Normal.xyz, INTERPOLANT_Tangent.xyz, INTERPOLANT_Binormal.xyz ) );

    if (b_iShadingMode == SHADINGMODE_VECTORUI) {
        GenInterpolant( VectorUI0, p_vVectorUIInterpolant0 );
        GenInterpolant( VectorUI1, p_vVectorUIInterpolant1 );
        GenInterpolant( VectorUI2, p_vVectorUIInterpolant2 );
        GenInterpolant( Vector4,   p_vSplatAttenuationPlane);
    }

#ifdef COMPILING_SHADER_FOR_OPENGL
    vertOut.HPos.y *= -1.0;
    vertOut.HPos.z = 2.0 * (vertOut.HPos.z - (0.5 * vertOut.HPos.w));
#endif    
}
    
#endif

#ifdef PIXEL_SHADER

#include "PSMainShading.fx"
#include "PSParallax.fx"

#endif