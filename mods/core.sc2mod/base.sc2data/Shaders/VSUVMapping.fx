#ifndef _UVMAPPING
#define _UVMAPPING

#ifdef VERTEX_SHADER

#include "ShaderSystem.fx"
#include "MaterialDefines.fx"

#define MAX_UV_EMITTERS             8

// UV mapping constant for the Planar Local types
// Note: roughly equivalent to the terrain tiling value, but decoupled to prevent unexpected changes
static const float c_planarLocalUVMapping = 0.09375f;

float3      p_vTriPlanarOffset[MAX_UV_EMITTERS];
float3      p_vTriPlanarScale[MAX_UV_EMITTERS];
float4x4    p_mSplatTextureProjMatrix[MAX_SPLATS];  // project uvs into splat space
float4      p_vTerrainTiling;                       // terrain texture tiling freq and offset


//--------------------------------------------------------------------------------------------------
float4 GenSplatProjectiveTexture (float3 vWorldPos, int iIndex) {
    return mul(float4(vWorldPos, 1.0f), p_mSplatTextureProjMatrix[iIndex]);
}

//--------------------------------------------------------------------------------------------------
float4 ComputeTriPlanarUVs (float3 vPos, float3 vOffset, float3 vScale) {
    float3 t = (vPos.xyz + vOffset.xyz) * vScale.xyz;
    return float4(t, 1);
}

//--------------------------------------------------------------------------------------------------
float3 GetTriPlanarPos(int iMapping, float3 vLocalPos, float3 vWorldPos) {
    if (iMapping==UVMAP_TRIPLANAR_LOCAL) {
        return vLocalPos;
    }
    else if (iMapping==UVMAP_TRIPLANAR_WORLD) {
        return vWorldPos;
    }
    else if (iMapping==UVMAP_TRIPLANAR_WORLD_LOCAL_Z ) {
        return float3(vWorldPos.x, vWorldPos.y, vLocalPos.z);
    }

    return vLocalPos;
}

//--------------------------------------------------------------------------------------------------
float4 GenUV(
    float3 vLocalPos,
    float3 vWorldPos,
    float3 vLocalNormal,
    float3 vWorldNormal, 
    HALF2 vUV0, 
    HALF2 vUV1, 
    HALF2 vUV2,
    HALF2 vUV3,
    int iIndex,
    int iSplatIndex,
    float3 vTriPlanarWeightsWorld,
    int b_iUVMapping[8]
) {

    int iMapping = b_iUVMapping[iIndex]; 

    float4 vResult=1;
    if ( iMapping == UVMAP_EXPLICITUV0 )
        vResult = HALF4(vUV0, 0, 1);
    else if ( iMapping == UVMAP_EXPLICITUV1 )
        vResult = HALF4(vUV1, 0, 1);
    else if ( iMapping == UVMAP_EXPLICITUV2 )
        vResult = HALF4(vUV2, 0, 1);
    else if ( iMapping == UVMAP_EXPLICITUV3 )
        vResult = HALF4(vUV3, 0, 1);
    else if ( iMapping == UVMAP_CUBICENVIO )
        vResult = 0;
    else if ( iMapping == UVMAP_SPHERICALENVIO )
        vResult = 0;
    else if ( iMapping == UVMAP_REFLECT_CUBICENVIO )
        vResult = 0;
    else if ( iMapping == UVMAP_REFLECT_SPHERICALENVIO )
        vResult = 0;
    else if ( iMapping == UVMAP_PLANARLOCALX ) {
        vResult.xy = vLocalPos.yz * c_planarLocalUVMapping;
        vResult.y = 1 - vResult.y;
    }
    else if ( iMapping == UVMAP_PLANARLOCALY ) {
        vResult.xy = vLocalPos.xz * c_planarLocalUVMapping;
        vResult.y = 1 - vResult.y;
    }
    else if ( iMapping == UVMAP_PLANARLOCALZ ) {
        vResult.xy = vLocalPos.xy * c_planarLocalUVMapping;
        vResult.y = 1 - vResult.y;
    }
    else if ( iMapping == UVMAP_PLANARWORLDX ) {
        vResult.xy = vWorldPos.yz*p_vTerrainTiling.xy + p_vTerrainTiling.zw;
        vResult.y = 1 - vResult.y;
    }
    else if ( iMapping == UVMAP_PLANARWORLDY ) {
        vResult.xy = vWorldPos.xz*p_vTerrainTiling.xy + p_vTerrainTiling.zw;
        vResult.y = 1 - vResult.y;
    }
    else if ( iMapping == UVMAP_PLANARWORLDZ ) {
        vResult.xy = vWorldPos.xy*p_vTerrainTiling.xy + p_vTerrainTiling.zw;
        vResult.y = 1 - vResult.y;
    }
    else if ( iMapping == UVMAP_SCREENSPACE ) {
        vResult = mul( float4( vWorldPos.x, vWorldPos.y, vWorldPos.z, 1.0f ), p_mVPTransform );
        vResult = vResult / vResult.w;
        vResult.xy = vResult.xy * float2( 0.5f, -0.5f ) + 0.5f;     // To [0..1]
    }
    else if (IsTriPlanarMappingFX(iMapping)) {
        float3 vNormal;

        if (TriPlanarIsWorldFX(iMapping))
            vNormal = vWorldNormal.xyz;
        else
            vNormal = vLocalNormal.xyz;

        float3 vPos = GetTriPlanarPos(iMapping, vLocalPos, vWorldPos);

        vResult = ComputeTriPlanarUVs(vPos, p_vTriPlanarOffset[iIndex], p_vTriPlanarScale[iIndex]);
        vResult.w = vTriPlanarWeightsWorld.z;
    }

    // Replace uv0 and uv1 with auto generated uv's
    // :TODO: Why separate branches for these projectors?
    bool isProjectorChannel = (iMapping == UVMAP_EXPLICITUV0) || (iMapping == UVMAP_EXPLICITUV1);
    if (b_splatTextureProjectorEnabled && isProjectorChannel) {
        vResult = GenSplatProjectiveTexture(vWorldPos, iSplatIndex);
        vResult.xy = Ndc2Tex(vResult.xy/vResult.w);
    }

    return vResult;
}



#endif  // VERTEX_SHADER

#endif  // _UVMAPPING