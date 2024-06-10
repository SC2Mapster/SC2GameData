#ifndef _UVMAPPING
#define _UVMAPPING

#ifdef VERTEX_SHADER

#include "ShaderSystem.fx"
#include "MaterialDefines.fx"

#define MAX_UV_EMITTERS             8


float2x4    p_mUVTransform[MAX_UV_EMITTERS];        // UV transforms - transposed for efficiency.
float4x4    p_mProjTextureMat;                      // Projective texture mapping matrix
float4x4    p_mSplatTextureProjMatrix[MAX_SPLATS];  // project uvs into splat space
float4      p_vTerrainTiling;                       // terrain texture tiling freq and offset

//--------------------------------------------------------------------------------------------------
float4 GenProjectiveTexture (float3 vWorldPos) {
    return mul(float4(vWorldPos, 1.0f), p_mProjTextureMat);
}

//--------------------------------------------------------------------------------------------------
float4 GenSplatProjectiveTexture (float3 vWorldPos, int iIndex) {
    return mul(float4(vWorldPos, 1.0f), p_mSplatTextureProjMatrix[iIndex]);
}

//--------------------------------------------------------------------------------------------------
half4 GenUV(
    float3 vLocalPos,
    float3 vWorldPos,
    half3 vNormal, 
    half2 vUV0, 
    half2 vUV1, 
    half2 vUV2,
    half2 vUV3,
    int iMapping, 
    bool uvTransformEnable,
    float2x4 mUVTransform,
    int iSplatIndex ) {
    
    half4 vResult=1;
    if ( iMapping == UVMAP_EXPLICITUV0 )
        vResult = half4(vUV0, 0, 1);
    else if ( iMapping == UVMAP_EXPLICITUV1 )
        vResult = half4(vUV1, 0, 1);
    else if ( iMapping == UVMAP_EXPLICITUV2 )
        vResult = half4(vUV2, 0, 1);
    else if ( iMapping == UVMAP_EXPLICITUV3 )
        vResult = half4(vUV3, 0, 1);
    else if ( iMapping == UVMAP_CUBICENVIO )
        vResult = 0;
    else if ( iMapping == UVMAP_SPHERICALENVIO )
        vResult = 0;
    else if ( iMapping == UVMAP_REFLECT_CUBICENVIO )
        vResult = 0;
    else if ( iMapping == UVMAP_REFLECT_SPHERICALENVIO )
        vResult = 0;
    else if ( iMapping == UVMAP_PLANARLOCALX ) {
        vResult.xy = vLocalPos.yz*p_vTerrainTiling.xy + p_vTerrainTiling.zw;
        vResult.y = 1 - vResult.y;
    }
    else if ( iMapping == UVMAP_PLANARLOCALY ) {
        vResult.xy = vLocalPos.xz*p_vTerrainTiling.xy + p_vTerrainTiling.zw;
        vResult.y = 1 - vResult.y;
    }
    else if ( iMapping == UVMAP_PLANARLOCALZ ) {
        vResult.xy = vLocalPos.xy*p_vTerrainTiling.xy + p_vTerrainTiling.zw;
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
        
    // Replace uv0 and uv1 with auto generated uv's
    // :TODO: Why separate branches for these projectors?
    bool isProjectorChannel = (iMapping == UVMAP_EXPLICITUV0) || (iMapping == UVMAP_EXPLICITUV1);
    if (b_textureProjectorEnabled && isProjectorChannel) {
        vResult = GenProjectiveTexture(vWorldPos);
    }
    if (b_splatTextureProjectorEnabled && isProjectorChannel) {
        vResult = GenSplatProjectiveTexture(vWorldPos, iSplatIndex);
    }

    if ( uvTransformEnable ) {
        half2 vTemp = mul( mUVTransform, float4( vResult.x, vResult.y, 0.0f, 1.0f ) ).xy;
        vResult = half4(vTemp, 0, 1);
    }

   if (b_textureProjectorEnabled || b_splatTextureProjectorEnabled) {
        if(isProjectorChannel) {
            vResult.xy = Ndc2Tex(vResult.xy/vResult.w);
        }
    }

    return vResult;
}

#endif  // VERTEX_SHADER

#endif  // _UVMAPPING