//==================================================================================================
//
// Copyright Blizzard Entertainment 2003-2005
//
// Legacy splat shader.
//==================================================================================================

#include "ShaderSystem.fx"

#ifdef VERTEX_SHADER

#define SPLAT_VERTEX_FORMAT

#include "VSModelVertexFormat.fx"
#include "VSCommon.fx"
#include "VSEmitters.fx"
#include "VSParallax.fx"
#include "VSLighting.fx"
#include "VSFog.fx"
#include "VSUtils.fx"
#include "MaterialDefines.fx"
#include "VSUVMapping.fx"

ArrayDecl(float) p_fSplatAlphaMultiplier[MAX_SPLATS];       // alpha multiplier for the splats
HALF4       p_cVectorUIColors[MAX_SPLATS];
float4      p_vVectorUIInterpolant0[MAX_SPLATS];
float4      p_vVectorUIInterpolant1[MAX_SPLATS];        // x == inner radius, y == outer radius, z == falloff, w == 1/falloff
float4      p_vVectorUIInterpolant2[MAX_SPLATS];        // x == segment count, y == percent solid, (z,w) == rotation axis
float4      p_vSplatAttenuationPlane[MAX_SPLATS];       // attenuation plane for splat
ArrayDecl(float2)      p_fSplatAttenuationScalar_MinHeight[MAX_SPLATS];      // attenuation scalar for splats
ArrayDecl(float)       p_fBatchIndexRemappingTable[MAX_BATCH_INDEX_REMAPPING_TABLE_SIZE];

float4      p_vSplatVolumeCorner[8 * MAX_SPLATS];

//==================================================================================================
// VERTEX SHADER EMITTERS

//--------------------------------------------------------------------------------------------------
// Homogeneous position.
float4 EmitSplatHPos( Input vertIn ) {
    return mul( vertIn.vPosition, p_mVPTransform );
}

//--------------------------------------------------------------------------------------------------
// World position.
float4 EmitSplatWorldPos( Input vertIn ) {
    return float4(vertIn.vPosition.xyz, 1.0f);
}

//--------------------------------------------------------------------------------------------------
// Homogeneous position as UV.
float4 EmitSplatHPosAsUV( Input vertIn ) {
    return mul( vertIn.vPosition, p_mVPTransform );
}

//--------------------------------------------------------------------------------------------------
// Camera space position.
float3 EmitSplatViewPos( Input vertIn ) {
    return mul( p_mViewTransform, vertIn.vPosition );          // As 3x4
}

//--------------------------------------------------------------------------------------------------
// Normal.
HALF4 EmitSplatNormal( Input vertIn ) {
    float3 righthandedBinormal = cross(vertIn.vNormal.xyz, vertIn.vTangent.xyz);
    float righthanded = dot(vertIn.vBinormal, righthandedBinormal);
    return HALF4(vertIn.vNormal.xyz, sign(righthanded));
}

//--------------------------------------------------------------------------------------------------
// Tangent.
HALF4 EmitSplatTangent( Input vertIn ) {
    return HALF4(vertIn.vTangent.xyz, 1);
}

//--------------------------------------------------------------------------------------------------
// Binormal.
HALF3 EmitSplatBinormal( Input vertIn ) {
    return vertIn.vBinormal;
}

//--------------------------------------------------------------------------------------------------
// UVs.
HALF4 EmitSplatUV( Input vertIn, int index, HALF3 vLocalPosition, HALF4 vLocalNormal, int iBatchIndex, int b_iUVMapping[8] ) {
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
            vertIn.vPosition,
            vLocalNormal.xyz, 
            vertIn.vNormal, 
            UV0, 
            UV1, 
            UV2, 
            UV3, 
            index,
            iBatchIndex,
            float3(0,0,0), 
            b_iUVMapping );
}

//--------------------------------------------------------------------------------------------------
// Vertex color.
HALF4 EmitSplatVertexColor( Input vertIn, int iBatchIndex ) {

    if (b_iShadingMode == SHADINGMODE_VECTORUI)
        return p_cVectorUIColors[iBatchIndex];
    else
        return HALF4(1, 1, 1, floatRef(p_fSplatAlphaMultiplier[iBatchIndex]));
}

//--------------------------------------------------------------------------------------------------
// eye to vertex
float3 EmitSplatEyeToVertex(Input vertIn) {
    return normalize(vertIn.vPosition.xyz - p_vEyePos);
}

//--------------------------------------------------------------------------------------------------
// FOW uvs
HALF4 EmitSplatFOWUV (Input vertIn) {
    return mul(vertIn.vPosition, p_mFOWMatrix);
}

//--------------------------------------------------------------------------------------------------
// Main vertex shader body.
//--------------------------------------------------------------------------------------------------
void SplatDirectVertexMain( in VertDecl streamIn, out VertexTransport vertOut ) {
    int b_iUVMapping[8];
    int b_UVRandomOffsetEnable[8];
    InitShader( vertOut, b_iUVMapping, b_UVRandomOffsetEnable );

    // translate vertex stream format into our vertex shader vertex format
    Input vertIn;
    TranslateVert(streamIn, vertIn);

    int iBatchIndex = vertIn.vBlendIndices[0];

    if (b_stencilFillPass == 1) {
        int iCornerIndex = iBatchIndex;
        vertIn.vPosition = float4(p_vSplatVolumeCorner[iCornerIndex].xyz, 1);
    }

    // remap the index
    iBatchIndex = (int)(floatRef(p_fBatchIndexRemappingTable[iBatchIndex]) + 0.1);

    HALF3 cVertexSpecularLighting;
    HALF3 cVertexShadowSpecularLighting;
    HALF3 cVertexShadowSpecularLighting2;

    HALF3 vLocalPosition = vertIn.vPosition;    // Preserve the local position (for possible uv mappings based on local vertex position).
    HALF4 vLocalNormal   = vertIn.vNormal;
                                            // Skinning will transform the position to world space.
    vertOut.HPos = EmitSplatHPos( vertIn );

    HALF4 interpNormal   = EmitSplatNormal( vertIn );
    HALF4 interpTangent  = EmitSplatTangent( vertIn );
    HALF3 interpBinormal = EmitSplatBinormal( vertIn );

    WRITE_INTERPOLANT_HPosAsUV                ( EmitSplatHPosAsUV( vertIn ) );
    WRITE_INTERPOLANT_WorldPos                ( EmitSplatWorldPos( vertIn ) );
    WRITE_INTERPOLANT_ViewPos                 ( EmitSplatViewPos( vertIn ) );
    WRITE_INTERPOLANT_Normal                  ( interpNormal );
    WRITE_INTERPOLANT_Tangent                 ( interpTangent );
    WRITE_INTERPOLANT_Binormal                ( interpBinormal );
    WRITE_INTERPOLANT_VertexColor             ( EmitSplatVertexColor( vertIn, iBatchIndex ) );
    WRITE_INTERPOLANT_Diffuse                 ( EmitDiffuse( vertIn.vPosition.xyz, vertIn.vNormal, HALF4(0,0,0,0), cVertexSpecularLighting, cVertexShadowSpecularLighting, cVertexShadowSpecularLighting2 ) );
    WRITE_INTERPOLANT_Specular                ( EmitSpecular(cVertexSpecularLighting) );
    WRITE_INTERPOLANT_ShadowDiffuse           ( EmitShadowDiffuse( vertIn.vNormal, HALF4(0,0,0,0), cVertexShadowSpecularLighting, cVertexShadowSpecularLighting2 ) );
    WRITE_INTERPOLANT_ShadowSpecular          ( EmitShadowSpecular(cVertexShadowSpecularLighting) );
    WRITE_INTERPOLANT_ShadowMapUV             ( EmitShadowMapUV( vertIn.vPosition.xyz ) );
    WRITE_INTERPOLANT_FogColor                ( EmitFogColor( vertIn.vPosition.xyz ) );
    WRITE_INTERPOLANT_HalfVec                 ( EmitHalfVec( vertIn.vPosition.xyz, 0 ) );
    WRITE_INTERPOLANT_EyeToVertex             ( EmitSplatEyeToVertex(vertIn) );
    WRITE_INTERPOLANT_EyeToVertexFresnel      ( EmitSplatEyeToVertex(vertIn) );
    WRITE_INTERPOLANT_FOWUV                   ( EmitSplatFOWUV(vertIn) );

    if(b_usePackedUVEmitter)
    {
#if COMPILING_SHADER_WITH_BSL
        [unroll]
#endif
        for ( int i = 0; i < b_iUVEmitterCount / 2; i++ ) {
            GenInterpolantUV( i, HALF4( EmitSplatUV( vertIn, i * 2, vLocalPosition, vLocalNormal, iBatchIndex, b_iUVMapping ).xy, EmitSplatUV( vertIn, (i * 2) + 1, vLocalPosition, vLocalNormal, iBatchIndex, b_iUVMapping ).xy ) );
        }
        if(b_iUVEmitterCount % 2)
            GenInterpolantUV( b_iUVEmitterCount / 2, EmitSplatUV( vertIn, b_iUVEmitterCount-1, vLocalPosition, vLocalNormal, iBatchIndex, b_iUVMapping) );
    }
    else
    {
#if COMPILING_SHADER_WITH_BSL
        [unroll]
#endif
        for ( int i = 0; i < b_iUVEmitterCount; i++ ) {
            GenInterpolantUV( i, EmitSplatUV( vertIn, i, vLocalPosition, vLocalNormal, iBatchIndex, b_iUVMapping ) );
        }
    }

    if (b_iShadingMode == SHADINGMODE_VECTORUI) {
        WRITE_INTERPOLANT_VectorUI0( p_vVectorUIInterpolant0[iBatchIndex] );
        WRITE_INTERPOLANT_VectorUI1( p_vVectorUIInterpolant1[iBatchIndex] );
        WRITE_INTERPOLANT_VectorUI2( p_vVectorUIInterpolant2[iBatchIndex] );
        
        // attenuation params
        WRITE_INTERPOLANT_Vector4( p_vSplatAttenuationPlane[iBatchIndex] );
        WRITE_INTERPOLANT_SWIZZLE_VectorUI0( w, p_fSplatAttenuationScalar_MinHeight[iBatchIndex].x );
    }
    else {
        // attenuation params
        WRITE_INTERPOLANT_VectorUI0( p_vSplatAttenuationPlane[iBatchIndex] );
        WRITE_INTERPOLANT_SWIZZLE_VectorUI1( xyz, EmitSplatWorldPos( vertIn ) );
        WRITE_INTERPOLANT_SWIZZLE_VectorUI1( w, p_fSplatAttenuationScalar_MinHeight[iBatchIndex].x );
        WRITE_INTERPOLANT_SWIZZLE_Tangent( w, p_fSplatAttenuationScalar_MinHeight[iBatchIndex].y );
    }
        
    // parallax vector
    WRITE_INTERPOLANT_ParallaxVector( EmitParallaxVector(   vertIn.vPosition.xyz, p_vEyePos, 
                                                        interpNormal.xyz, interpTangent.xyz, interpBinormal.xyz ) );
#ifdef COMPILING_SHADER_FOR_OPENGL
    vertOut.HPos.y *= -1.0;
    vertOut.HPos.z = 2.0 * (vertOut.HPos.z - (0.5 * vertOut.HPos.w));
#endif    
}

#endif  // VERTEXSHADER

#ifdef PIXEL_SHADER

#include "PSCommon.fx"
#include "PSMainShading.fx"

SPixelOut SplatDirectPixelMain (VertexTransportRaw vertIn) {
    if (b_stencilFillPass == 1) {
        SPixelOut outValue;
        outValue.cColor = 1;

        #if (b_emitMRTDepth == 1 || b_emitMRTNormal == 1)
            outValue.vNormalDepth = 0;
        #endif

        #if (b_emitMRTDepth == 1)
            outValue.vNormalDepth = 1;
        #endif

        #if (b_emitMRTNormal == 1)
            outValue.vNormalDepth = 1;
            #if (b_emitMRTDepth == 0)
                outValue.vNormalDepth.a = outValue.cColor.a;
            #endif
        #endif
        #if ( b_emitMRTDiffuse == 1 )
            outValue.cDiffuse = 1;
        #endif
        #if( b_emitMRTSpecular == 1 )
            outValue.cSpecular = 1;
        #endif
    
        return outValue;
    }
    else {
        return DefaultPixelMain( vertIn );
    }
}

#endif