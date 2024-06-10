//==================================================================================================
//
// Copyright Blizzard Entertainment 2003-2005
//
// This is the shader code for the units.
//==================================================================================================

#include "ShaderSystem.fx"

#ifdef VERTEX_SHADER

#include "VSModelVertexFormat.fx"
#include "VSCommon.fx"
#include "VSEmitters.fx"
#include "VSParallax.fx"
#include "VSLighting.fx"
#include "VSFog.fx"
#include "VSUtils.fx"
#include "MaterialDefines.fx"
#include "VSUVMapping.fx"

HALF3       g_vLocalPosition;                           // Local space vertex position.

float       p_fSplatAlphaMultiplier[MAX_SPLATS];       // alpha multiplier for the splats
HALF4       p_cVectorUIColors[MAX_SPLATS];
float4      p_vVectorUIInterpolant0[MAX_SPLATS];
float4      p_vVectorUIInterpolant1[MAX_SPLATS];        // x == inner radius, y == outer radius, z == falloff, w == 1/falloff
float4      p_vVectorUIInterpolant2[MAX_SPLATS];        // x == segment count, y == percent solid, (z,w) == rotation axis
float4      p_vSplatAttenuationPlane[MAX_SPLATS];       // attenuation plane for splat
float2      p_fSplatAttenuationScalar_MinHeight[MAX_SPLATS];      // attenuation scalar for splats

float       p_fBatchIndexRemappingTable[MAX_BATCH_INDEX_REMAPPING_TABLE_SIZE];

float4      p_vSplatVolumeCorner[8 * MAX_SPLATS];

int         g_iBatchIndex;

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
half4 EmitSplatNormal( Input vertIn ) {
    return half4(vertIn.vNormal.xyz, 1);
}

//--------------------------------------------------------------------------------------------------
// Tangent.
half4 EmitSplatTangent( Input vertIn ) {
    return half4(vertIn.vTangent.xyz, 1);
}

//--------------------------------------------------------------------------------------------------
// Binormal.
half3 EmitSplatBinormal( Input vertIn ) {
    return vertIn.vBinormal;
}

//--------------------------------------------------------------------------------------------------
// UVs.
half4 EmitSplatUV( Input vertIn, int index ) {
    return GenUV(
            g_vLocalPosition,
            vertIn.vPosition,
            vertIn.vNormal, 
            vertIn.vUV0.xy, 
            vertIn.vUV1.xy, 
            vertIn.vUV2.xy, 
            vertIn.vUV3.xy, 
            b_iUVMapping[index], 
            b_UVTransformEnable[index],
            p_mUVTransform[index],
            g_iBatchIndex );
}

//--------------------------------------------------------------------------------------------------
// Vertex color.
half4 EmitSplatVertexColor( Input vertIn ) {

    if (b_iShadingMode == SHADINGMODE_VECTORUI)
        return p_cVectorUIColors[g_iBatchIndex];
    else
        return half4(1, 1, 1, p_fSplatAlphaMultiplier[g_iBatchIndex]);
}

//--------------------------------------------------------------------------------------------------
// eye to vertex
float3 EmitSplatEyeToVertex(Input vertIn) {
    return normalize(vertIn.vPosition.xyz - p_vEyePos);
}

//--------------------------------------------------------------------------------------------------
// FOW uvs
half4 EmitSplatFOWUV (Input vertIn) {
    return mul(vertIn.vPosition, p_mFOWMatrix);
}

//--------------------------------------------------------------------------------------------------
// Main vertex shader body.
//--------------------------------------------------------------------------------------------------
void SplatVertexMain( in VertDecl streamIn, out VertexTransport vertOut ) {
    InitShader( vertOut );

    // translate vertex stream format into our vertex shader vertex format
    Input vertIn;
    TranslateVert(streamIn, vertIn);
    if ( b_useCompressedBasis ) {
        //vertIn.vBinormal *= -1.0f;
        //vertIn.vTangent *= -1.0f;
    }

    g_iBatchIndex = vertIn.vBlendIndices[0];

    if (b_stencilFillPass == 1) {
        int iCornerIndex = g_iBatchIndex;
        vertIn.vPosition = float4(p_vSplatVolumeCorner[iCornerIndex].xyz, 1);
    }

    // remap the index
    g_iBatchIndex = (int)(p_fBatchIndexRemappingTable[g_iBatchIndex] + 0.1);

    g_vLocalPosition = vertIn.vPosition;    // Preserve the local position (for possible uv mappings based on local vertex position).
                                            // Skinning will transform the position to world space.
    vertOut.HPos = EmitSplatHPos( vertIn );
    INTERPOLANT_HPosAsUV                = EmitSplatHPosAsUV( vertIn );
    INTERPOLANT_WorldPos                = EmitSplatWorldPos( vertIn );
    INTERPOLANT_ViewPos                 = EmitSplatViewPos( vertIn );
    INTERPOLANT_Normal                  = EmitSplatNormal( vertIn );
    INTERPOLANT_Tangent                 = EmitSplatTangent( vertIn );
    INTERPOLANT_Binormal                = EmitSplatBinormal( vertIn );
    INTERPOLANT_VertexColor             = EmitSplatVertexColor( vertIn );
    INTERPOLANT_Diffuse                 = EmitDiffuse( vertIn, vertIn.vNormal );
    INTERPOLANT_Specular                = EmitSpecular( vertIn );
    INTERPOLANT_ShadowDiffuse           = EmitShadowDiffuse( vertIn, vertIn.vNormal );
    INTERPOLANT_ShadowSpecular          = EmitShadowSpecular( vertIn );
    INTERPOLANT_ShadowMapUV             = EmitShadowMapUV( vertIn );
    INTERPOLANT_FogColor                = EmitFogColor( vertIn );
    INTERPOLANT_HalfVec                 = EmitHalfVec( vertIn, 0 );
    INTERPOLANT_EyeToVertex             = EmitSplatEyeToVertex(vertIn);
    INTERPOLANT_EyeToVertexFresnel      = EmitSplatEyeToVertex(vertIn);
    INTERPOLANT_FOWUV                   = EmitSplatFOWUV(vertIn);

    if(b_usePackedUVEmitter)
    {
        for ( int i = 0; i < b_iUVEmitterCount / 2; i++ ) {
            GenInterpolantUV( UV[i], half4( EmitSplatUV( vertIn, i * 2).xy, EmitSplatUV( vertIn, (i * 2) + 1 ).xy ) );
        }
        if(b_iUVEmitterCount % 2)
            GenInterpolantUV( UV[(b_iUVEmitterCount / 2)], EmitSplatUV( vertIn, b_iUVEmitterCount-1) );
    }
    else
    {
        for ( int i = 0; i < b_iUVEmitterCount; i++ ) {
            GenInterpolantUV( UV[i], EmitSplatUV( vertIn, i ) );
        }
    }

    if (b_iShadingMode == SHADINGMODE_VECTORUI) {
        INTERPOLANT_VectorUI0 = p_vVectorUIInterpolant0[g_iBatchIndex];
        INTERPOLANT_VectorUI1 = p_vVectorUIInterpolant1[g_iBatchIndex];
        INTERPOLANT_VectorUI2 = p_vVectorUIInterpolant2[g_iBatchIndex];
        
        // attenuation params
        INTERPOLANT_Vector4     = p_vSplatAttenuationPlane[g_iBatchIndex];
        INTERPOLANT_VectorUI0.w = p_fSplatAttenuationScalar_MinHeight[g_iBatchIndex].x;
    }
    else {
        // attenuation params
        INTERPOLANT_VectorUI0     = p_vSplatAttenuationPlane[g_iBatchIndex];
        INTERPOLANT_VectorUI1.xyz = INTERPOLANT_WorldPos.xyz;
        INTERPOLANT_VectorUI1.w   = p_fSplatAttenuationScalar_MinHeight[g_iBatchIndex].x;
    }
    
    
    // parallax vector
    INTERPOLANT_ParallaxVector  = EmitParallaxVector(   vertIn.vPosition.xyz, p_vEyePos, 
                                                        INTERPOLANT_Normal.xyz, INTERPOLANT_Tangent.xyz, INTERPOLANT_Binormal.xyz );
#ifdef COMPILING_SHADER_FOR_OPENGL
    vertOut.HPos.y *= -1.0;
    vertOut.HPos.z = 2.0 * (vertOut.HPos.z - (0.5 * vertOut.HPos.w));
#endif    
}

#endif  // VERTEXSHADER

#ifdef PIXEL_SHADER

#include "PSCommon.fx"
#include "PSMainShading.fx"

SPixelOut SplatPixelMain (VertexTransport vertIn) {
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
