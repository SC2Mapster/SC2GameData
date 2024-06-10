//==================================================================================================
//
// Copyright Blizzard Entertainment 2003-2007
//
// Common shader code.
//==================================================================================================

#ifndef PS_COMMON
#define PS_COMMON

#ifdef PIXEL_SHADER

#include "ShaderSystem.fx"
#include "Common.fx"

#if !CPP_SHADER

#ifndef b_emitMRTDepth
    #define b_emitMRTDepth 0
#endif
#ifndef b_emitMRTNormal
    #define b_emitMRTNormal 0
#endif
#ifndef b_emitMRTDiffuse
    #define b_emitMRTDiffuse 0
#endif
#ifndef b_emitMRTSpecular
    #define b_emitMRTSpecular 0
#endif

#endif

float3x4	p_mInvViewTransform;						// Inverse view transform.
float       p_fMaxDepthFactor;

sampler2D   p_sNormalDepthMap;

// "out" parameters tend to break easily in the compiler, so we pass stuff around through global variables instead.
HALF3 g_vDeferredNormal;
HALF3 g_cDeferredDiffuse;
HALF3 g_cDeferredSpecular;
HALF  g_cDeferredAO;
HALF  g_cDeferredSpecularPower;

HALF4 p_vMissingPixelDepth;

#define PIXEL_DEPTH         vNormalDepth.a
#define PIXEL_NORMAL        vNormalDepth.rgb

#define DEPTH_NORMAL_ENCODING_FLOAT     0
#define DEPTH_NORMAL_ENCODING_RGBA      1

//--------------------------------------------------------------------------------------------------
float DecodeDepth( float4 vNormalDepth ) {
    if ( b_iInEncoding == DEPTH_NORMAL_ENCODING_FLOAT )
        return vNormalDepth.a;
    else if ( b_iInEncoding == DEPTH_NORMAL_ENCODING_RGBA ) {
        float fDepth = dot( vNormalDepth.ba, float2( 1.0f, 1.0f / 255.0f ) );
        //fDepth *= p_fMaxDepth;
        fDepth = p_fMaxDepthFactor * ( ( 1.0f / ( 1.0f - fDepth ) ) - 1.0f );
        return fDepth;
    } else return 0;
}

//--------------------------------------------------------------------------------------------------
float3 DecodeNormal( float4 vNormalDepth, bool flipZ ) {
    if ( b_iInEncoding == DEPTH_NORMAL_ENCODING_FLOAT ) {
        if ( b_iLowResNormal ) {
            float3 vNormal;
            vNormal.xz = 2.0f * vNormalDepth.rg - 1.0f;
            vNormal.y = -sqrt(max(0, 1 - dot(vNormal.xz, vNormal.xz)));
            vNormal = mul( (float3x3)p_mInvViewTransform, vNormal );
            vNormal = normalize( vNormal );
            return vNormal.rgb;
        } else return vNormalDepth.rgb;
    }
    else if ( b_iInEncoding == DEPTH_NORMAL_ENCODING_RGBA ) {
        float3 vNormal;
        vNormal.xz = 2.0f * vNormalDepth.rg - 1.0f;
        vNormal.y = -sqrt(max(0, 1 - dot(vNormal.xz, vNormal.xz)));
        vNormal = mul( (float3x3)p_mInvViewTransform, vNormal );
        vNormal = normalize( vNormal );
        return vNormal.rgb;
    }
    else return 0;
}

//--------------------------------------------------------------------------------------------------
float4 SampleNormalDepth( sampler2D sNormalDepthMap, half2 vUV ) {
    float4 cSample = tex2D( sNormalDepthMap, vUV );
    float4 vNormalDepth;
    vNormalDepth.a = DecodeDepth( cSample );
    vNormalDepth.rgb = DecodeNormal( cSample, false );
    return vNormalDepth;
}

//--------------------------------------------------------------------------------------------------
float4 EncodeDepthNormal( float3 vNormal, float fDepth ) {
    float4 vNormalDepth;
    if ( b_iNormalizeDeffNormal )
        vNormal = normalize( vNormal );
    if ( b_iOutEncoding == DEPTH_NORMAL_ENCODING_FLOAT ) {
        if ( b_emitMRTNormal == 1 ) {
            if ( b_iLowResNormal ) {
                vNormal = mul( (float3x3)p_mViewTransform, vNormal );
                vNormalDepth.rg = ( vNormal.xz + 1.0f ) * 0.5f;
            } else vNormalDepth.rgb = vNormal;
        } else vNormalDepth.rgb = 0;
        if ( b_emitMRTDepth == 1 )
            vNormalDepth.a = fDepth;
        else vNormalDepth.a = 1.0f;
    } else if ( b_iOutEncoding == DEPTH_NORMAL_ENCODING_RGBA ) {
        if ( b_emitMRTNormal == 1 ) {
            vNormal = mul( (float3x3)p_mViewTransform, vNormal );
            vNormalDepth.rg = ( vNormal.xz + 1.0f ) * 0.5f;
        } else vNormalDepth.rg = 0;
        if ( b_emitMRTDepth == 1 ) {
            //fDepth = saturate( fDepth / p_fMaxDepth );
            fDepth = saturate( 1.0f - 1.0f / ( 1.0f + fDepth / p_fMaxDepthFactor ) );
            vNormalDepth.ba = frac( float2( 1.0f, 255.0f ) * fDepth );
            vNormalDepth.b -= vNormalDepth.a / 255.0;
        } else vNormalDepth.ba = 0;
    }
    return vNormalDepth;
}

//--------------------------------------------------------------------------------------------------
float SplatAttenuation (float3 worldPos, float4 vPlane, float scalar, float minHeight) {
#if b_splatAttenuationEnabled
    float fDist;

    if ( PIXEL_SHADER_VERSION <= SHADER_VERSION_PS_14 ) {
        // :TODO: :FIXME:
        scalar = 1;
        fDist = 0;
    } 
    else {
        fDist = dot(float4(worldPos, 1.0f), vPlane) * scalar;
    }
    
    float a = 1.0f - saturate(abs(fDist));
    
    return a;
#else
    return 1;
#endif
}

#if !CPP_SHADER

//--------------------------------------------------------------------------------------------------
struct SPixelOut {
	// :TODO: I'm not sure why... but I can see significant banding if I use halfs here!!!
    float4   cColor : COLOR0;
    // :TODO: Improve this. The COLOR output need to be contiguous, so they'd need to be assigned by the
    // engine instead of using silly defines here.
#if ( b_emitMRTDepth == 1 || b_emitMRTNormal == 1 )    // Outputting depth map will output normals implicitly.
    float4  vNormalDepth : COLOR1;          // Normal and depth.
    #if ( b_emitMRTDiffuse == 1 )
        float4   cDiffuse : COLOR2;              // Diffuse color for deferred rendering.
        #if ( b_emitMRTSpecular == 1 )
	        float4	 cSpecular : COLOR3;
        #endif
    #endif
#else
    #if ( b_emitMRTDiffuse == 1 )
        float4   cDiffuse : COLOR1;              // Diffuse color for deferred rendering.
        #if ( b_emitMRTSpecular == 1 )
	        float4	 cSpecular : COLOR2;
        #endif
    #endif
#endif
};

#endif

half4 GetUVEmitter(in VertexTransport vertOut, int index)
{
#if ( b_usePackedUVEmitter == 1 )
    if(index % 2 == 0)
        return half4(INTERPOLANT_UV[index / 2].xy, 0, 1);
    else
        return half4(INTERPOLANT_UV[index / 2].zw, 0, 1);
#else
    return INTERPOLANT_UV[index];
#endif
}

#endif  // PIXEL_SHADER

#endif  // PS_COMMON