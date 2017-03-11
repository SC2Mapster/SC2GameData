//==================================================================================================
//
// Copyright Blizzard Entertainment 2003-2005
//
// This is the shader code for the units.
//==================================================================================================

#include "ShaderSystem.fx"

#ifdef VERTEX_SHADER

#include "VSSkinning.fx"         // Must include skinning before model vertex format to ensure that it's constants come first for DX11 stuff. See CShaderCore::UpdateRegisters()
#include "VSModelVertexFormat.fx"
#include "VSEmitters.fx"
#include "VSVertexWarp.fx"
#include "VSUtils.fx"
#include "VSCommon.fx"
#include "VSUVMapping.fx"
#include "VSLighting.fx"
#include "VSFog.fx"
#include "VSParallax.fx"

float4x4            p_mTerrainTextureMatrix;
float4              p_InvCreepTextureRotation;
float4              p_vCreepTextureRotation;
float4x4            p_mInstanceTransform;

HALF4               p_vVectorUIColor;
float4              p_vVectorUIInterpolant0;
float4              p_vVectorUIInterpolant1;        // x == inner radius, y == outer radius, z == falloff, w == 1/falloff
float4              p_vVectorUIInterpolant2;        // x == segment count, y == percent solid, (z,w) == rotation axis
float4              p_vSplatAttenuationPlane;
float2              p_fSplatAttenuationScalar_MinHeight;
float3              p_vSplatTextureUVector;

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
// Local position.
float4 EmitModelLocalPos( Input vertIn, HALF3 vLocalPosition ) {
    return float4(vLocalPosition.xyz, 1.0f);
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
HALF4 EmitModelNormal( Input vertIn ) {
    // tangent space is compressed already
    // terrain always uses right handed basis
    if ( b_iShadingMode == SHADINGMODE_TERRAIN )
        return float4(vertIn.vNormal.xyz, -1);
    else
    return vertIn.vNormal;
}

//--------------------------------------------------------------------------------------------------
HALF4 EmitModelNormalLocal (Input vertIn, HALF4 vLocalNormal ) {
    // tangent space is compressed already
    return vLocalNormal;
}

//--------------------------------------------------------------------------------------------------
HALF4 EmitModelAOData (Input vertIn) {
    HALF4 value = 0;
    // for legacy data
    if (b_iVertexAOFromVertexColor) {
        HasColor_( value = vertIn.cColor.a; )
    // for new data
    } else {
        HasCustomUB4N1_( value = vertIn.cCustomUB4N1; )
    }
    return value;
}

//--------------------------------------------------------------------------------------------------
HALF4 EmitTriPlanarWeights (Input vertIn, float3 vTriPlanarWeightsLocal, float3 vTriPlanarWeightsWorld) {
    if (b_iShadingMode != SHADINGMODE_TERRAIN)
        return float4(vTriPlanarWeightsLocal.xyz, vTriPlanarWeightsWorld.x);
    else
        return float4(vTriPlanarWeightsWorld.xyz, 0);     // terrain is always in world space
}

//--------------------------------------------------------------------------------------------------
// Tangent.
HALF4 EmitModelTangent( Input vertIn, float3 vTriPlanarWeightsWorld ) {
    if ( b_iShadingMode == SHADINGMODE_TERRAIN )
        return HALF4(ComputeGridTangent(vertIn.vNormal.xyz), 1);
    else if (b_splatTextureProjectorEnabled) {
        float3 b = cross(vertIn.vNormal.xyz, p_vSplatTextureUVector.xyz);
        float3 t = cross(b, vertIn.vNormal.xyz);
        return HALF4(normalize(t), 1);
    }
    else {
        // :TODO: This will break parallax mapping - shouldn't normalize.
        return HALF4(normalize( vertIn.vTangent.xyz ), vTriPlanarWeightsWorld.y);
    }
}

//--------------------------------------------------------------------------------------------------
// Binormal.
HALF3 EmitModelBinormal( Input vertIn, float3 vTangent ) {
    if ( b_iShadingMode == SHADINGMODE_TERRAIN )
        return normalize(cross(vTangent.xyz, vertIn.vNormal.xyz));
    else if (b_splatTextureProjectorEnabled) {
        return normalize(cross(vTangent.xyz, vertIn.vNormal.xyz));
    }
    else {
        // sign of INTERPOLANT_Normal.w is the handiness
        return cross(vertIn.vNormal.xyz, vTangent.xyz) * vertIn.vNormal.w;
    }
}

//--------------------------------------------------------------------------------------------------
// UVs.
HALF4 EmitModelUV( Input vertIn, int index, HALF3 vLocalPosition, HALF3 vLocalNormal, float3 vTriPlanarWeightsWorld, int b_iUVMapping[8] ) {
    HALF2 UV0 = 0;
    HALF2 UV1 = 0;
    HALF2 UV2 = 0;
    HALF2 UV3 = 0;
    HasUVCoord0_(UV0 = vertIn.vUV0.xy; )
    HasUVCoord1_(UV1 = vertIn.vUV1.xy; )
    HasUVCoord2_(UV2 = vertIn.vUV2.xy; )
    HasUVCoord3_(UV3 = vertIn.vUV3.xy; )
    return GenUV(
            vLocalPosition,
            vertIn.vPosition.xyz,
            vLocalNormal.xyz,
            vertIn.vNormal.xyz, 
            UV0, 
            UV1, 
            UV2,
            UV3,
            index,
            0,                  // we're forcing index 0 here, splats that render on models don't batch, so this enforces the proper index in the texture projection matrix array
            vTriPlanarWeightsWorld,
            b_iUVMapping
    );                         
}

//--------------------------------------------------------------------------------------------------
// Vertex color.
HALF4 EmitModelVertexColor( Input vertIn ) {
    // vector ui splat
    if (b_iShadingMode == SHADINGMODE_VECTORUI) {
        return p_vVectorUIColor;
    }
    // triangle id
    else if (b_iShadingMode == SHADINGMODE_MODEL_TRIANGLE_ID) {
        float4 id = 0;
	HasColor_( id = vertIn.cColor; )
        return id;
    }
    // material splat on model
    else if (b_splatTextureProjectorEnabled) {
        float a = SplatAttenuationProjector(vertIn.vPosition.xyz, p_vSplatAttenuationPlane, p_fSplatAttenuationScalar_MinHeight.x, p_fSplatAttenuationScalar_MinHeight.y);
        // do not use model vertex color
        return HALF4(1, 1, 1, a);
    }
    // normal rendering
    else {
        float4 value = 0;
        HasColor_(value = vertIn.cColor; )
        return value;
    }
}

//--------------------------------------------------------------------------------------------------
// eye to vertex
float3 EmitModelEyeToVertex(Input vertIn) {
    return normalize(vertIn.vPosition.xyz - p_vEyePos);
}

//--------------------------------------------------------------------------------------------------
// FOW uvs
HALF4 EmitModelFOWUV (Input vertIn) {
    HALF4 vRet = mul(vertIn.vPosition, p_mFOWMatrix);
    // to fade out creep on vertical triangles
    if ( b_iShadingMode == SHADINGMODE_TERRAIN ) {
        vRet.z = saturate(abs(vertIn.vNormal.z)*5);
    }
    return vRet;
}

//--------------------------------------------------------------------------------------------------
// terrain blended textue uvs and creep texture uvs
float4 EmitTerrainCreepTextureUV (Input vertIn) {
    if ( !b_computeHeight ) {
        float2 t = mul(vertIn.vPosition, p_mTerrainTextureMatrix);
#if COMPILING_SHADER_WITH_BSL
        return float4(t, mul(float2x2(p_vCreepTextureRotation.x, p_vCreepTextureRotation.y, p_vCreepTextureRotation.z, p_vCreepTextureRotation.w), float2(t.x, -t.y)));
#else
        return float4(t, mul(float2x2(p_vCreepTextureRotation), float2(t.x, -t.y)));
#endif
    }
    else
        return vertIn.vPosition.z;
}

//--------------------------------------------------------------------------------------------------
void ComputeTriPlanarTangentSpace (float3 weights, inout float4 vNorm, out float3 vTangent, out float3 vBinormal) {
    const float3 x=float3(1,0,0), y=float3(0,1,0), z=float3(0,0,1);

    vTangent = 0;
    vBinormal = 0;

    // xy 
    float3 t = cross(y, vNorm.xyz);
    float3 b = cross(t, vNorm.xyz);
    vTangent += t*weights.z;
    vBinormal += b*weights.z;

    // xz
    t = cross(z, vNorm.xyz);
    b = cross(t, vNorm.xyz);
    vTangent += t*weights.y;
    vBinormal += b*weights.y;

    // yz
    t = cross(z, vNorm.xyz);
    b = cross(t, vNorm.xyz);
    vTangent += t*weights.x;
    vBinormal += b*weights.x;

    vTangent = normalize(vTangent);
    vBinormal = normalize(vBinormal);

    float3 righthandedBinormal = cross(vNorm.xyz, vTangent.xyz);
    float righthanded = dot(vBinormal, righthandedBinormal);
    vNorm.w = sign(righthanded);
}

//--------------------------------------------------------------------------------------------------
float DecodeZOffset (float x, float y) {
    //float z = (x*255.f*256.f + y*255.f) / 65535.f;
    float z = (x*255.f*256.f/65535.f + y*255.f/65535.f);
    //z = saturate(z);
    return z*(c_terrainMaxHeight - c_terrainMinHeight) + c_terrainMinHeight;
}

//--------------------------------------------------------------------------------------------------
// Main vertex shader body.
//--------------------------------------------------------------------------------------------------
void ModelVertexMain( in VertDecl streamIn, out VertexTransport vertOut ) {
    int b_iUVMapping[8];
    int b_UVRandomOffsetEnable[8];
    InitShader( vertOut, b_iUVMapping, b_UVRandomOffsetEnable );

    // translate vertex stream format into our vertex shader vertex format
    Input vertIn;
    TranslateVert(streamIn, vertIn);

    // preprocess vertex' local space data
    // Preserve the local position (for possible uv mappings based on local vertex position).
    HALF3 vLocalPosition = vertIn.vPosition.xyz; 
    if (b_iZOffsetFromUB4N_XY) {
        HasCustomUB4N1_( vLocalPosition.z -= DecodeZOffset(vertIn.cCustomUB4N1.x, vertIn.cCustomUB4N1.y); )
    }
    float3 vTriPlanarWeightsLocal = 0;
    if (b_iUseLocalTriPlanarWeights)
        vTriPlanarWeightsLocal = ComputeTriPlanarBlendingWeights(vertIn.vNormal);
    // generate procedural triplanar UV's in local space
    if (b_iUseLocalTriPlanarTangentSpace) {
        ComputeTriPlanarTangentSpace(vTriPlanarWeightsLocal, vertIn.vNormal, vertIn.vTangent.xyz, vertIn.vBinormal.xyz);
    }
    HALF4 vLocalNormal = vertIn.vNormal;
    HALF3 vLocalBinormal = vertIn.vBinormal;
    HALF3 vLocalTangent = vertIn.vTangent;

    // transform the vertex into world space
    #if b_iLayoutHasNoVertexBlendWeights
        Skin( vertIn.vPosition, vertIn.vNormal.xyz, vertIn.vTangent.xyz, vertIn.vBinormal.xyz, 0, 0 );
    #else
        Skin( vertIn.vPosition, vertIn.vNormal.xyz, vertIn.vTangent.xyz, vertIn.vBinormal.xyz, vertIn.vBlendWeights, vertIn.vBlendIndices );
    #endif

    // now vertex is in world space, generate procedural triplanar UV's in world space
    float3 vTriPlanarWeightsWorld = 0;
    if (b_iUseWorldTriPlanarWeights)
        vTriPlanarWeightsWorld = ComputeTriPlanarBlendingWeights(vertIn.vNormal);
    if (b_iUseWorldTriPlanarTangentSpace)
        ComputeTriPlanarTangentSpace(vTriPlanarWeightsWorld, vertIn.vNormal, vertIn.vTangent.xyz, vertIn.vBinormal.xyz);

    // transform instance
    if ( b_useModelInstancing )
        vertIn.vPosition.xyz = mul(float4(vertIn.vPosition.xyz,1), p_mInstanceTransform).xyz;

    if ( b_enableVertexWarps == 1 )
        vertIn.vPosition = ApplyWarps( vertIn.vPosition );
    
    vertOut.HPos = EmitModelHPos( vertIn );
    
    HALF4 interpTangent = EmitModelTangent( vertIn, vTriPlanarWeightsWorld );
    HALF3 interpBinormal = EmitModelBinormal( vertIn, interpTangent.xyz );
    GenInterpolant( HPosAsUV,   EmitModelHPosAsUV( vertIn ) );
    GenInterpolant( WorldPos,   EmitModelWorldPos( vertIn ) );
    GenInterpolant( ViewPos,    EmitModelViewPos( vertIn ) );
    GenInterpolant( Normal,     EmitModelNormal( vertIn ) );
    GenInterpolant( Tangent,    interpTangent );
    GenInterpolant( Binormal,   interpBinormal );
    GenInterpolant( VectorUI1,  EmitModelAOData( vertIn ) );

    // if we're doing creep, we need to adjust the tangent and binormal if the creep texture is rotated
    if (b_creepEnabled) {
#if COMPILING_SHADER_WITH_BSL
        WRITE_INTERPOLANT_SWIZZLE_Tangent( xy, mul(float2x2(p_InvCreepTextureRotation.x, p_InvCreepTextureRotation.y, p_InvCreepTextureRotation.z, p_InvCreepTextureRotation.w), interpTangent.xy) );
        WRITE_INTERPOLANT_SWIZZLE_Binormal( xy, mul(float2x2(p_InvCreepTextureRotation.x, p_InvCreepTextureRotation.y, p_InvCreepTextureRotation.z, p_InvCreepTextureRotation.w), interpBinormal.xy) );
#else
        WRITE_INTERPOLANT_SWIZZLE_Tangent( xy, mul(float2x2(p_InvCreepTextureRotation), interpTangent.xy) );
        WRITE_INTERPOLANT_SWIZZLE_Binormal( xy, mul(float2x2(p_InvCreepTextureRotation), interpBinormal.xy) );
#endif
    }

    HALF3 cVertexSpecularLighting;
    HALF3 cVertexShadowSpecularLighting;
    HALF3 cVertexShadowSpecularLighting2;

    // We may be using vertex alpha for something else, so just recalculate the 4th region
    HALF4 vLightingRegions = HALF4(0,0,0,0);
    HasColor_(vLightingRegions = vertIn.cColor; vLightingRegions.a = 1.0 - (vLightingRegions.r + vLightingRegions.g + vLightingRegions.b));

    GenInterpolant( VertexColor,        EmitModelVertexColor( vertIn ) );
    GenInterpolant( Diffuse,            EmitDiffuse( vertIn.vPosition.xyz, vertIn.vNormal.xyz, vLightingRegions, cVertexSpecularLighting, cVertexShadowSpecularLighting, cVertexShadowSpecularLighting2 ) );
    GenInterpolant( Specular,           EmitSpecular(cVertexSpecularLighting) );
    GenInterpolant( ShadowDiffuse,      EmitShadowDiffuse( vertIn.vNormal.xyz, vLightingRegions, cVertexShadowSpecularLighting, cVertexShadowSpecularLighting2 ) );
    GenInterpolant( ShadowSpecular,     EmitShadowSpecular(cVertexShadowSpecularLighting) );
    GenInterpolant( ShadowMapUV,        EmitShadowMapUV( vertIn.vPosition.xyz ) );
    GenInterpolant( FogColor,           EmitFogColor( vertIn.vPosition.xyz, vTriPlanarWeightsWorld ) );
    GenInterpolant( HalfVec,            EmitHalfVec( vertIn.vPosition.xyz, 0 ) );
    GenInterpolant( EyeToVertex,        EmitModelEyeToVertex( vertIn ) );
    GenInterpolant( EyeToVertexFresnel, EmitModelEyeToVertex( vertIn ) );
    GenInterpolant( FOWUV,              EmitModelFOWUV( vertIn ) );
    GenInterpolant( TerrainUV,          EmitTerrainCreepTextureUV( vertIn ) );
    GenInterpolant( VectorUI0,          EmitModelNormalLocal(vertIn,vLocalNormal));

    if(b_usePackedUVEmitter)
    {
#if COMPILING_SHADER_WITH_BSL
        [unroll]
#endif
        for ( int i = 0; i < b_iUVEmitterCount / 2; i++ ) {
            GenInterpolantUV( i, float4( EmitModelUV( vertIn, i * 2, vLocalPosition, vLocalNormal, vTriPlanarWeightsWorld, b_iUVMapping ).xy, EmitModelUV( vertIn, (i * 2) + 1, vLocalPosition, vLocalNormal, vTriPlanarWeightsWorld, b_iUVMapping ).xy ) );
        }
        if(b_iUVEmitterCount % 2)
            GenInterpolantUV( b_iUVEmitterCount / 2, EmitModelUV( vertIn, b_iUVEmitterCount-1, vLocalPosition, vLocalNormal, vTriPlanarWeightsWorld, b_iUVMapping ) );
    }
    else
    {
#if COMPILING_SHADER_WITH_BSL
        [unroll]
#endif
        for ( int i = 0; i < b_iUVEmitterCount; i++ ) {
            GenInterpolantUV( i, EmitModelUV( vertIn, i, vLocalPosition, vLocalNormal, vTriPlanarWeightsWorld, b_iUVMapping ));
        }
    }

    GenInterpolant( ParallaxVector, EmitParallaxVector(vertIn.vPosition.xyz, p_vEyePos, INTERPOLANT_Normal.xyz, INTERPOLANT_Tangent.xyz, INTERPOLANT_Binormal.xyz ) );
    GenInterpolant( TriPlanarWeights, EmitTriPlanarWeights(vertIn, vTriPlanarWeightsLocal, vTriPlanarWeightsWorld));

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
