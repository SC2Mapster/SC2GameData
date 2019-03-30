#ifndef PS_UVMAPPING
#define PS_UVMAPPING

#ifdef PIXEL_SHADER

#include "ShaderSystem.fx"
#include "PSCommon.fx"
#include "MaterialDefines.fx"

struct SEnvMappings {
    HALF2   vReflectSphericalEnvioUV;
    HALF3   vReflectCubicEnvioUV;
    HALF2   vSphericalEnvioUV;
    HALF3   vCubicEnvioUV;
};


//--------------------------------------------------------------------------------------------------
HALF2 GenSphericalEnvio( float3 vPosition, HALF3 vNormal, bool reflect ) {
    HALF3 vLookup;
    if ( reflect && PIXEL_SHADER_VERSION >= SHADER_VERSION_PS_30 ) {
        vLookup = normalize( vPosition - 2.0f * dot( vPosition, vNormal ) * vNormal );
    } 
    else {
        vLookup = vNormal;    // vNormal should be normalized
    }
    return vLookup.xz * HALF2( 0.5f, -0.5f ) + 0.5f;
}

//--------------------------------------------------------------------------------------------------
HALF3 GenCubicEnvio( float3 vPosition, HALF3 vNormal, bool reflect ) {
    HALF3 vLookup;
    if ( reflect ) {
        vLookup    = normalize(vPosition - 2.0f * dot( vPosition, vNormal ) * vNormal);
    }
    else {
        vLookup = vNormal;
    }
    return vLookup;
}

//--------------------------------------------------------------------------------------------------
SEnvMappings ComputeEnvMappings( VertexTransport vertOut, HALF3 vNormal, float3 vPosition ) {
    SEnvMappings envMappings;
    envMappings.vReflectSphericalEnvioUV    = GenSphericalEnvio(    vPosition, vNormal, true );
    envMappings.vReflectCubicEnvioUV        = GenCubicEnvio(        vPosition, vNormal, true );
    envMappings.vSphericalEnvioUV           = GenSphericalEnvio(    vPosition, vNormal, false );
    envMappings.vCubicEnvioUV               = GenCubicEnvio(        vPosition, vNormal, false );
    return envMappings;
}

//--------------------------------------------------------------------------------------------------
HALF4 GenEnvioUV( SEnvMappings envMappings, int iMapping ) {
    // Environment mappings only.
    HALF3 vResult;
    if ( iMapping == UVMAP_REFLECT_CUBICENVIO )
        vResult = envMappings.vReflectCubicEnvioUV;
    else if ( iMapping == UVMAP_REFLECT_SPHERICALENVIO ) {
        vResult.xy = envMappings.vReflectSphericalEnvioUV;
        vResult.z = 0;
    } else if ( iMapping == UVMAP_CUBICENVIO )
        vResult = envMappings.vCubicEnvioUV;
    else if ( iMapping == UVMAP_SPHERICALENVIO ) {
        vResult.xy = envMappings.vSphericalEnvioUV;
        vResult.z = 0;
    } else vResult = 0;
    return HALF4(vResult,1);
}

//--------------------------------------------------------------------------------------------------
float2 ToAtlasUV (float4 vAtlasParams, float2 numCells, float2 cellId, float2 uv) {
    /*
    float2 imgSize = float2(1024, 512);

    // convert to [0, 1)
    uv = frac(uv);
    float2 invNumCells = 1.f / numCells;
    float2 cellSize = imgSize * invNumCells;
    float2 halfInvNumCells = 0.5f * invNumCells;

    // move to cell space
    uv = uv * invNumCells;
    uv = (uv - halfInvNumCells) * (cellSize - 1) / cellSize + halfInvNumCells;
    uv += cellId * invNumCells;
    return uv;
    */

    uv = frac(uv);
    return uv * vAtlasParams.xy + vAtlasParams.wz + cellId / numCells;
}

//--------------------------------------------------------------------------------------------------
void TriplanarAtlas (float4 vAtlasParams, float3 normal, float3 uvSource, out float2 uvZ, out float2 uvY, out float2 uvX) {

    /*
    float3 s = sign(normal);

    uvZ = uvSource.xy*float2( s.z, -1.f);
    uvY = uvSource.xz*float2(-s.y, -1.f);
    uvX = uvSource.yz*float2( s.x, -1.f);

    uvZ = frac(uvZ)*vAtlasParams.xy + vAtlasParams.wz;
    uvY = frac(uvY)*vAtlasParams.xy + vAtlasParams.wz + float2(.5f,0);
    uvX = frac(uvX)*vAtlasParams.xy + vAtlasParams.wz + float2(.5f,0);
    */
    
    // Shared atlas calculations for normalizing and packing.
    float2 uvCalc    = frac(uvSource.xy);
    float4 uvReverse = frac(-uvSource.xyzy);
    
    float4 atlasScale = vAtlasParams.xyyx;
    float4 atlasOffset = vAtlasParams.wzzw;

    uvCalc = uvCalc * atlasScale.x + atlasOffset.x;
    uvReverse = uvReverse * atlasScale + atlasOffset;

    uvZ.x = (normal.z >= 0) ? uvCalc.x : uvReverse.x;
    uvZ.y = uvReverse.y;
    
    uvY.x = (normal.y >= 0) ? uvReverse.x : uvCalc.x;
    uvY.y = uvReverse.z;
    
    uvX.x = (normal.x >= 0) ? uvCalc.y : uvReverse.w;
    uvX.y = uvReverse.z;

    // Offset to right image
    uvY.x += .5f;
    uvX.x += .5f;
}


#endif  // PIXEL_SHADER

#endif  // PS_UVMAPPING
