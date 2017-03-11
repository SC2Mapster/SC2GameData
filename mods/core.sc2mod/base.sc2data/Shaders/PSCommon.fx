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
float       p_fMaxDepthRange;
texDecl2D(p_sNormalDepthMap);

HALF4 p_vMissingPixelDepth;

#define PIXEL_DEPTH         vNormalDepth.a
#define PIXEL_NORMAL        vNormalDepth.rgb

#define DEPTH_NORMAL_ENCODING_FLOAT     0
#define DEPTH_NORMAL_ENCODING_RGBA      1
#define DEPTH_NORMAL_ENCODING_RGBA16    2

//--------------------------------------------------------------------------------------------------
float DecodeDepth( float4 vNormalDepth ) {
    if ( b_iInEncoding == DEPTH_NORMAL_ENCODING_FLOAT )
        return vNormalDepth.a;
    else if ( b_iInEncoding == DEPTH_NORMAL_ENCODING_RGBA ) {
        float fDepth = dot( vNormalDepth.ba, float2( 1.0f, 1.0f / 255.0f ) );
        //fDepth *= p_fMaxDepth;
        fDepth = p_fMaxDepthFactor * ( ( 1.0f / ( 1.0f - fDepth ) ) - 1.0f );
        return fDepth;
    } else if ( b_iInEncoding == DEPTH_NORMAL_ENCODING_RGBA16 )
        return p_fMaxDepthFactor * ( ( 1.0f / ( 1.0f - vNormalDepth.a ) ) - 1.0f );
    else return 0;
}

//--------------------------------------------------------------------------------------------------
float3 DecodeNormal( float4 vNormalDepth, bool flipZ ) {
    if ( b_iInEncoding == DEPTH_NORMAL_ENCODING_FLOAT ) {
        return vNormalDepth.rgb;
    } else if ( b_iInEncoding == DEPTH_NORMAL_ENCODING_RGBA ) {
        float3 vNormal;
        vNormal.xz = 2.0f * vNormalDepth.rg - 1.0f;
        vNormal.y = -sqrt(max(0, 1 - dot(vNormal.xz, vNormal.xz)));
        vNormal = mul( (float3x3)p_mInvViewTransform, vNormal );
        vNormal = normalize( vNormal );
        return vNormal.rgb;
    } else if ( b_iInEncoding == DEPTH_NORMAL_ENCODING_RGBA16 )
        return 2.0f * vNormalDepth.rgb - 1.0f;
    else return 0;
}

//--------------------------------------------------------------------------------------------------
float4 SampleNormalDepth( typeSampler2D sNormalDepthMap, typeTexture2D tNormalTexture, HALF2 vUV ) {
    float4 cSample = sampleTex2D( tNormalTexture, sNormalDepthMap, vUV );
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
        if ( b_emitMRTNormal == 1 )
            vNormalDepth.rgb = vNormal;
        else vNormalDepth.rgb = 0;
        if ( b_emitMRTDepth == 1 )
            vNormalDepth.a = fDepth;
        else vNormalDepth.a = 1.0f;
    } else if ( b_iOutEncoding == DEPTH_NORMAL_ENCODING_RGBA ) {
        if ( b_emitMRTNormal == 1 ) {
            vNormal = mul( (float3x3)p_mViewTransform, vNormal );
            vNormalDepth.rg = ( vNormal.xz * 0.5f ) + 0.5f;
        } else vNormalDepth.rg = 0;
        if ( b_emitMRTDepth == 1 ) {
            fDepth = saturate( 1.0f - 1.0f / ( 1.0f + fDepth / p_fMaxDepthFactor ) );
            vNormalDepth.ba = frac( float2( 1.0f, 255.0f ) * fDepth );
            vNormalDepth.b -= vNormalDepth.a / 255.0f;
        } else vNormalDepth.ba = 0;
    } else if ( b_iOutEncoding == DEPTH_NORMAL_ENCODING_RGBA16 ) {
        if ( b_emitMRTNormal == 1 )
            vNormalDepth.rgb = vNormal * 0.5f + 0.5f;
        else vNormalDepth.rgb = 0;
        if ( b_emitMRTDepth == 1 )
            vNormalDepth.a = saturate( 1.0f - 1.0f / ( 1.0f + fDepth / p_fMaxDepthFactor ) );
        else vNormalDepth.a = 1.0f;
    }
    return vNormalDepth;
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
    #if ( b_emitMRTDiffuse == 1 || b_emitMRTAO == 1 )
        float4   cDiffuse : COLOR2;              // Diffuse color for deferred rendering.
        #if ( b_emitMRTSpecular == 1 )
            float4	 cSpecular : COLOR3;
        #endif
    #endif
#else
    #if ( b_emitMRTDiffuse == 1 || b_emitMRTAO == 1 )
        float4   cDiffuse : COLOR1;              // Diffuse color for deferred rendering.
        #if ( b_emitMRTSpecular == 1 )
            float4	 cSpecular : COLOR2;
        #endif
    #endif
#endif
};

#endif

HALF4 GetUVEmitter(in VertexTransport vertOut, int index, HALF iUVTransform, float2x4 iUVMatrix )
{
    HALF4 rvalue;
#if ( b_usePackedUVEmitter == 1 )
    if(index % 2 == 0)
        rvalue = HALF4(READ_INTERPOLANT_UV(index / 2).xy, 0, 1);
    else
        rvalue = HALF4(READ_INTERPOLANT_UV(index / 2).zw, 0, 1);
#else
    rvalue = READ_INTERPOLANT_UV(index);
#endif

    HALF4 transform = HALF4( mul( iUVMatrix, float4( rvalue.x, rvalue.y, 0.0f, 1.0f ) ).xy, 0, 1);
    return iUVTransform ? transform : rvalue;
}

#endif  // PIXEL_SHADER

#endif  // PS_COMMON