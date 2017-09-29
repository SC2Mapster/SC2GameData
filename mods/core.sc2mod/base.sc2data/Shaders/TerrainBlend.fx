//==================================================================================================
//
// Copyright Blizzard Entertainment 2003-2007
//
// terrain texture blending
//==================================================================================================

#include "ShaderSystem.fx"
#define BLEND_TERRAIN_DIFFUSE       0
#define BLEND_TERRAIN_NORMAL        1
#define BLEND_PROJECTOR_DIFFUSE     2
#define BLEND_PROJECTOR_NORMAL      3
#define BLEND_COPY_TERRAIN_SPEC     4
#define BLEND_PROJECTOR_SPEC        5
#define BLEND_COPY_FINAL_SPEC       6
#define BLEND_TERRAIN_DIFFUSEHEIGHT 7
#define BLEND_TERRAIN_NORMALHEIGHT  8

#if defined(COMPILING_SHADER_FOR_OPENGL) || (PIXEL_SHADER_VERSION >= SHADER_VERSION_PS_40)
#define USE_CLIP_PLANES
#endif

//--------------------------------------------------------------------------------------------------
// vertex shader to pixel shader parameters
//--------------------------------------------------------------------------------------------------
struct VertexTransport {
    float4 vPos  : POSITION;
    float4 vUV0  : TEXCOORD0;
    float4 vUV1  : TEXCOORD1;  
#ifdef USE_CLIP_PLANES
    float4 vClip : TEXCOORD2;
#endif
};


//--------------------------------------------------------------------------------------------------
struct STerrainBlendPixelOut {
    float4  cColor : COLOR0;
#if ( b_iTerrainBlendMode == BLEND_TERRAIN_NORMALHEIGHT )
    float4  vHeight0 : COLOR1;
    float4  vHeight1 : COLOR2;
#endif
};

//--------------------------------------------------------------------------------------------------
// VERTEX_SHADER
//--------------------------------------------------------------------------------------------------
#ifdef VERTEX_SHADER

#include "Common.fx"

//--------------------------------------------------------------------------------------------------
// input vertex format
//--------------------------------------------------------------------------------------------------
struct Input {
    float4  vPosition   : POSITION_;
};

float4 p_vTiling;
float4 p_vMaskTiling;
float3 p_vCenter;
float3 p_vSize;
float4x4 p_mWorldViewProj;
float4x4 p_mprojectorMatrix;

//--------------------------------------------------------------------------------------------------
void TerrainBlendVertexMain( in Input vertIn, out VertexTransport vertOut ) {
    VertexTransport output;
    float3 vPos = vertIn.vPosition*p_vSize + p_vCenter;

    vertOut.vPos  = mul(float4(vPos, 1), p_mWorldViewProj);
    vertOut.vUV0  = 0;
    vertOut.vUV1  = 0;

    if (b_iTerrainBlendMode==BLEND_TERRAIN_DIFFUSE
        || b_iTerrainBlendMode==BLEND_TERRAIN_NORMAL
        || b_iTerrainBlendMode==BLEND_TERRAIN_DIFFUSEHEIGHT
        || b_iTerrainBlendMode==BLEND_TERRAIN_NORMALHEIGHT
    ) {
        vertOut.vUV0.xy = vPos.xy*p_vTiling.xy + p_vTiling.zw;
        vertOut.vUV0.y = 1 - vertOut.vUV0.y;
        vertOut.vUV1.xy = vPos.xy*p_vMaskTiling.xy + p_vMaskTiling.zw;
        vertOut.vUV1.y = 1 - vertOut.vUV1.y;
    }
    else {
        // projector uv
        float4 uv = mul(float4(vPos, 1), p_mprojectorMatrix);
        uv.xy /= uv.w;
        vertOut.vUV0.xy = uv.xy*float2(0.5f, -0.5f) + 0.5f ;

        // back buffer uv
        // This is only used for BLEND_COPY_TERRAIN_SPEC and BLEND_COPY_FINAL_SPEC which are always rendered to the entire viewport,
        // So we convert the input vertex to normalized UV space and apply the mask
        vertOut.vUV1.xy = vertIn.vPosition * p_vMaskTiling.xy + p_vMaskTiling.zw;
    }

#ifdef USE_CLIP_PLANES
    // setup clip planes
    vertOut.vClip = float4(0.0f, 0.0f, 0.0f, 0.0f);
    if (b_iTerrainBlendMode == BLEND_PROJECTOR_DIFFUSE
        || b_iTerrainBlendMode == BLEND_PROJECTOR_NORMAL
        || b_iTerrainBlendMode == BLEND_PROJECTOR_SPEC) {
        vertOut.vClip.x = dot(vertOut.vPos, p_vClipPlanes[0]);
        vertOut.vClip.y = dot(vertOut.vPos, p_vClipPlanes[1]);
        vertOut.vClip.z = dot(vertOut.vPos, p_vClipPlanes[2]);
        vertOut.vClip.w = dot(vertOut.vPos, p_vClipPlanes[3]);
    }
#if defined(COMPILING_SHADER_FOR_OPENGL)
    vertOut.vPos.y *= -1.0;
#endif
#endif    
}

#endif  // VERTEX_SHADER








//--------------------------------------------------------------------------------------------------
// PIXEL_SHADER
//--------------------------------------------------------------------------------------------------
#ifdef PIXEL_SHADER

#include "Common.fx"

texDecl2D(p_sTexture0);
texDecl2D(p_sTexture1);
texDecl2D(p_sTexture2);
texDecl2D(p_sTexture3);
texDecl2D(p_sTexture4);
texDecl2D(p_sTexture5);
texDecl2D(p_sTexture6);
texDecl2D(p_sTexture7);
texDecl2D(p_sMask0);
texDecl2D(p_sMask1);
float4      p_vMaskInvSize;

float4 p_vHeightOffset0;
float4 p_vHeightOffset1;
float4 p_vHeightScale0;
float4 p_vHeightScale1;

float3 p_vTangent;

//--------------------------------------------------------------------------------------------------
float4 TerrainBlend_CopyTerrainSpec ( VertexTransport vertOut ) {
    // spec from terrain
    float terrainSpec = sample2D(p_sTexture0, vertOut.vUV1.xy).w;
    return float4(terrainSpec, terrainSpec, terrainSpec, 1);
}

//--------------------------------------------------------------------------------------------------
float4 TerrainBlend_BlendProjectorSpec ( VertexTransport vertOut ) {
    // spec from projector
    float projectorSpec = dot(sample2D(p_sTexture0, vertOut.vUV0.xy).xyz, float3(0.3f, 0.59f, 0.11f));
    float4 masks = sample2D(p_sMask0, vertOut.vUV0.xy);

    return float4(projectorSpec, projectorSpec, projectorSpec, masks.w);
}

//--------------------------------------------------------------------------------------------------
float4 TerrainBlend_CopyFinalSpec ( VertexTransport vertOut ) {
    float s = sample2D(p_sTexture0, vertOut.vUV1.xy).x;
    return float4(0, 0, 0, s);
}

//--------------------------------------------------------------------------------------------------
float4 TerrainBlend_BlendTerrainDiffuse (VertexTransport vertOut) {
    float4 masks = 0;
    float4 result = 0;
    
    masks = sample2D(p_sMask0, vertOut.vUV1.xy);

    float4 col0  = sample2D(p_sTexture0, vertOut.vUV0.xy);
    float4 col1  = sample2D(p_sTexture1, vertOut.vUV0.xy);
    float4 col2  = sample2D(p_sTexture2, vertOut.vUV0.xy);
    float4 col3  = sample2D(p_sTexture3, vertOut.vUV0.xy);
    result = col0*masks.w + col1*masks.x + col2*masks.y + col3*masks.z;

    return result;
}

//--------------------------------------------------------------------------------------------------
float4 TerrainBlend_BlendTerrainDiffuseHeight (VertexTransport vertOut) {
    float4 masks0,masks1;
    float4 result = 0;
    
    masks0 = sample2D(p_sMask0, vertOut.vUV1.xy);
    masks1 = sample2D(p_sMask1, vertOut.vUV1.xy);

    float4 col0  = sample2D(p_sTexture0, vertOut.vUV0.xy);
    float4 col1  = sample2D(p_sTexture1, vertOut.vUV0.xy);
    float4 col2  = sample2D(p_sTexture2, vertOut.vUV0.xy);
    float4 col3  = sample2D(p_sTexture3, vertOut.vUV0.xy);
    float4 col4  = sample2D(p_sTexture4, vertOut.vUV0.xy);
    float4 col5  = sample2D(p_sTexture5, vertOut.vUV0.xy);
    float4 col6  = sample2D(p_sTexture6, vertOut.vUV0.xy);
    float4 col7  = sample2D(p_sTexture7, vertOut.vUV0.xy);

    result = col0*masks0.w + col1*masks0.x + col2*masks0.y + col3*masks0.z + 
            col4*masks1.w + col5*masks1.x + col6*masks1.y + col7*masks1.z;

    return result;
}

//--------------------------------------------------------------------------------------------------
float3 UnSwizzleNormals (float4 result) {
    float3 finalNormal;
    finalNormal.xy = 2.0f * result.wy - 1.0f;
    finalNormal.z = sqrt(max(0, 1 - dot(finalNormal.xy, finalNormal.xy)));

    return finalNormal;
}

//--------------------------------------------------------------------------------------------------
float4 TerrainBlend_BlendTerrainNormal (VertexTransport vertOut) {
    float4 masks = 0;
    float4 result = 0;

    float4 col0  = sample2D(p_sTexture0, vertOut.vUV0.xy);
    float4 col1  = sample2D(p_sTexture1, vertOut.vUV0.xy);
    float4 col2  = sample2D(p_sTexture2, vertOut.vUV0.xy);
    float4 col3  = sample2D(p_sTexture3, vertOut.vUV0.xy);
    masks = sample2D(p_sMask0, vertOut.vUV1.xy);
    result = col0*masks.w + col1*masks.x + col2*masks.y + col3*masks.z;
    
    // if necessary we need to convert it to a non-dxn normal map format
    if (b_iUnSwizzleDXNNormalMaps) {
        result.xyz = UnSwizzleNormals(result);

        result.xyz = result.xyz* 0.5f + 0.5f;
    }

    return result;
}

//--------------------------------------------------------------------------------------------------
void TerrainBlend_BlendTerrainNormalHeight (VertexTransport vertOut, out STerrainBlendPixelOut pixelOut) {
    float4 masks0,masks1;
    float4 result = 0;

    float4 col0  = sample2D(p_sTexture0, vertOut.vUV0.xy);
    float4 col1  = sample2D(p_sTexture1, vertOut.vUV0.xy);
    float4 col2  = sample2D(p_sTexture2, vertOut.vUV0.xy);
    float4 col3  = sample2D(p_sTexture3, vertOut.vUV0.xy);
    float4 col4  = sample2D(p_sTexture4, vertOut.vUV0.xy);
    float4 col5  = sample2D(p_sTexture5, vertOut.vUV0.xy);
    float4 col6  = sample2D(p_sTexture6, vertOut.vUV0.xy);
    float4 col7  = sample2D(p_sTexture7, vertOut.vUV0.xy);
    masks0 = sample2D(p_sMask0, vertOut.vUV1.xy);
    masks1 = sample2D(p_sMask1, vertOut.vUV1.xy);

    float4 heights0 = float4(col1.r, col2.r, col3.r, col0.r);
    float4 heights1 = float4(col5.r, col6.r, col7.r, col4.r);
    masks0 *= heights0 * p_vHeightScale0 + p_vHeightOffset0;
    masks1 *= heights1 * p_vHeightScale1 + p_vHeightOffset1;

    float4 weightMax = max(max(max(masks0.x, masks0.y), max(masks0.z, masks0.w)), max(max(masks1.x, masks1.y), max(masks1.z, masks1.w))).xxxx;
    masks0 *= float4(1,1,1,1) - saturate(weightMax - masks0);
    masks1 *= float4(1,1,1,1) - saturate(weightMax - masks1);
    float rcpTotal = 1.0 / (dot(float4(1,1,1,1), masks0) + dot(float4(1,1,1,1), masks1));
    masks0 *= rcpTotal;
    masks1 *= rcpTotal;

    result = col0*masks0.w + col1*masks0.x + col2*masks0.y + col3*masks0.z + 
            col4*masks1.w + col5*masks1.x + col6*masks1.y + col7*masks1.z;
            
#if ( b_iTerrainBlendMode == BLEND_TERRAIN_NORMALHEIGHT )
    pixelOut.vHeight0 = masks0;
    pixelOut.vHeight1 = masks1;
#endif
    
    // if necessary we need to convert it to a non-dxn normal map format
    if (b_iUnSwizzleDXNNormalMaps) {
        result.xyz = UnSwizzleNormals(result);

        result.xyz = result.xyz* 0.5f + 0.5f;
    }

    pixelOut.cColor = result;
}

//--------------------------------------------------------------------------------------------------
float4 TerrainBlend_BlendProjectorDiffuse (VertexTransport vertOut) {
    float4 masks = 0;
    float4 result = 0;

    masks = sample2D(p_sMask0, vertOut.vUV0.xy);
    result = sample2D(p_sTexture0, vertOut.vUV0.xy);
    
    // set output alpha when blending projectors
    result.w = masks.w;

    return result;
}

//--------------------------------------------------------------------------------------------------
float4 TerrainBlend_BlendProjectorNormal (VertexTransport vertOut) {
    float4 masks = 0;
    float4 result = 0;

    masks = sample2D(p_sMask0, vertOut.vUV0.xy);
    result = sample2D(p_sTexture0, vertOut.vUV0.xy);
    
    // if necessary we need to convert it to a non-dxn normal map format
    if (b_iUnSwizzleDXNNormalMaps) {
        result.xyz = UnSwizzleNormals(result);
        result.xyz = result.xyz* 0.5f + 0.5f;
    }

    // transform normal
    result.xyz = result.xyz*2 - 1;
    float3 vBinormal = cross(float3(0,0,1), p_vTangent);
    result.xyz = mul(result.xyz, float3x3(p_vTangent, vBinormal, float3(0,0,1)));
    result.xyz = result.xyz* 0.5f + 0.5f;

    // set output alpha when blending projectors
    result.w = masks.w;

    return result;
}

//--------------------------------------------------------------------------------------------------
// main
//--------------------------------------------------------------------------------------------------
STerrainBlendPixelOut TerrainBlendPixelMain( VertexTransport vertOut ) {
    STerrainBlendPixelOut pixelOut;

#ifdef USE_CLIP_PLANES
    if (b_iTerrainBlendMode == BLEND_PROJECTOR_DIFFUSE
        || b_iTerrainBlendMode == BLEND_PROJECTOR_NORMAL
        || b_iTerrainBlendMode == BLEND_PROJECTOR_SPEC) {
        // handle clip planes
        if (vertOut.vClip.x < 0.0f
            || vertOut.vClip.y < 0.0f
            || vertOut.vClip.z < 0.0f
            || vertOut.vClip.w < 0.0f) {
            pixelOut.cColor = float4(0.0f, 0.0f, 0.0f, 0.0f);

            #if (b_iTerrainBlendMode == BLEND_TERRAIN_NORMALHEIGHT)
                pixelOut.vHeight0 = float4(0.0f, 0.0f, 0.0f, 0.0f);
                pixelOut.vHeight1 = float4(0.0f, 0.0f, 0.0f, 0.0f);
            #endif
                    
            #if (!CPP_SHADER) // If we return during the CPP shader simulation then we don't mark any of the static branches below as valid. This is bad!
                return pixelOut;
            #endif
        }
    }
#endif

    if (b_iTerrainDebugMode!=0) {
        pixelOut.cColor = sample2D(p_sMask1, vertOut.vUV1.xy);
        return pixelOut;
    }

    if (b_iTerrainBlendMode == BLEND_TERRAIN_DIFFUSE) {
        pixelOut.cColor = TerrainBlend_BlendTerrainDiffuse(vertOut);
    }
    else if (b_iTerrainBlendMode == BLEND_TERRAIN_NORMAL) {
        pixelOut.cColor = TerrainBlend_BlendTerrainNormal(vertOut);
    }
    else if (b_iTerrainBlendMode == BLEND_TERRAIN_DIFFUSEHEIGHT) {
        pixelOut.cColor = TerrainBlend_BlendTerrainDiffuseHeight(vertOut);
    }
    else if (b_iTerrainBlendMode == BLEND_TERRAIN_NORMALHEIGHT) {
        TerrainBlend_BlendTerrainNormalHeight(vertOut, pixelOut);
    }
    else if (b_iTerrainBlendMode == BLEND_PROJECTOR_DIFFUSE) {
        pixelOut.cColor = TerrainBlend_BlendProjectorDiffuse(vertOut);
    }
    else if (b_iTerrainBlendMode == BLEND_PROJECTOR_NORMAL) {
        pixelOut.cColor = TerrainBlend_BlendProjectorNormal(vertOut);
    }
    else if (b_iTerrainBlendMode == BLEND_COPY_TERRAIN_SPEC) {
        pixelOut.cColor = TerrainBlend_CopyTerrainSpec(vertOut);
    }
    else if (b_iTerrainBlendMode == BLEND_PROJECTOR_SPEC) {
        pixelOut.cColor = TerrainBlend_BlendProjectorSpec(vertOut);
    }
    else if (b_iTerrainBlendMode == BLEND_COPY_FINAL_SPEC) {
        pixelOut.cColor = TerrainBlend_CopyFinalSpec(vertOut);
    }
    else {
        pixelOut.cColor = float4(0,0,0,0);
    }

    return pixelOut;
}

#endif      // PIXEL_SHADER