//==================================================================================================
//
// Copyright Blizzard Entertainment 2003-2005
//
//==================================================================================================

#ifndef PS_MATERIALLAYER
#define PS_MATERIALLAYER

#ifdef PIXEL_SHADER

#include "ShaderSystem.fx"
#include "PSMaterialDefines.fx"
#include "PSUVMapping.fx"
#include "PSUtils.fx"

#define c_maxNumLayers  18

#define TEAMCOLOR_NONE		0
#define TEAMCOLOR_DIFFUSE	1
#define TEAMCOLOR_EMISSIVE	2

#define TEXTURE_TYPE_2D         0
#define TEXTURE_TYPE_CUBE       1
#define TEXTURE_TYPE_VOLUME     2
#define TEXTURE_TYPE_UNDEFINED  3

#define FRESNELTRANSFORM_NONE       0
#define FRESNELTRANSFORM_SIMPLE     1
#define FRESNELTRANSFORM_NORMALIZED 2

struct SLayerConfig {
    
    bool    b_iLayerEnable;
    int     b_iLayerId;
    int     b_iTextureType;
    int     b_iUVMapping;
    int		b_iTeamColorMode;
    int     b_iUVEmitter;
    bool    b_iUseMask;    
    int     b_iChannelSelect;
    bool    b_iInvert;
    bool    b_iClamp;
    int     b_iFresnelMode;
    int     b_iFresnelTransformMode;
    bool    b_iFresnelSaturate;
    bool    b_iUseConstantColor;
    HALF4   p_vMultiplyAddAlphaTrans;
    float4  p_vAtlasParams;
    HALF3   p_vFresnelExponentBiasScale;
    HALF4   p_cConstantColor;
    int     b_iOp;
    int     b_iIsRTTTexture;
    int     b_iTriPlanarUvId;
    HALF4   p_vRTTTextureOffsetScale;
    half3x4 p_mFresnelTransform;
    float2x4 p_mUVTransform;
};


#if PIXEL_SHADER_VERSION >= SHADER_VERSION_PS_40
#define DECLARE_LAYER(name, textureType, samplerType) samplerType     p_s##name##Sampler_s;             \
                                                textureType     p_s##name##Sampler_t;                   \
                                                HALF4           p_v##name##MultiplyAddAlphaTrans;       \
                                                HALF3           p_v##name##FresnelExponentBiasScale;    \
                                                HALF4           p_c##name##ConstantColor;               \
                                                HALF4           p_v##name##RTTTextureOffsetScale;       \
                                                float4          p_v##name##AtlasParams;                 \
                                                float3x4        p_m##name##FresnelTransform;            \
                                                float2x4        p_m##name##UVTransform;
#else
#define DECLARE_LAYER(name, textureType, samplerType) samplerType         p_s##name##Sampler;           \
                                                HALF4           p_v##name##MultiplyAddAlphaTrans;       \
                                                HALF3           p_v##name##FresnelExponentBiasScale;    \
                                                HALF4           p_c##name##ConstantColor;               \
                                                HALF4           p_v##name##RTTTextureOffsetScale;       \
                                                float4          p_v##name##AtlasParams;                 \
                                                float3x4        p_m##name##FresnelTransform;            \
                                                float2x4        p_m##name##UVTransform;
#endif
#define DECLARE_LAYER_2D(name)                  DECLARE_LAYER(name, typeTexture2D, typeSampler2D)
#define DECLARE_LAYER_3D(name)                  DECLARE_LAYER(name, typeTexture3D, typeSampler3D)
#define DECLARE_LAYER_CUBE(name)                DECLARE_LAYER(name, typeTextureCube, typeSamplerCube)


#define SETUP_LAYER( x )                                                                        \
    SLayerConfig                                x##LayerConfig;                                 \
    x##LayerConfig.b_iLayerEnable               = b_i##x##LayerEnable;                          \
    x##LayerConfig.b_iLayerId                   = b_i##x##LayerId;                              \
    x##LayerConfig.b_iTextureType               = b_i##x##TextureType;                          \
    x##LayerConfig.b_iUVMapping                 = b_i##x##UVMapping;                            \
    x##LayerConfig.b_iTeamColorMode             = b_i##x##TeamColorMode;                        \
    x##LayerConfig.b_iUVEmitter                 = b_i##x##UVEmitter;                            \
    x##LayerConfig.b_iUseMask                   = b_i##x##UseMask;                              \
    x##LayerConfig.b_iChannelSelect             = b_i##x##ChannelSelect;                        \
    x##LayerConfig.b_iInvert                    = b_i##x##Invert;                               \
    x##LayerConfig.b_iClamp                     = b_i##x##Clamp;                                \
    x##LayerConfig.b_iFresnelMode               = b_i##x##FresnelMode;                          \
    x##LayerConfig.b_iFresnelTransformMode      = b_i##x##FresnelTransformMode;                 \
    x##LayerConfig.b_iFresnelSaturate           = b_i##x##FresnelSaturate;                      \
    x##LayerConfig.b_iUseConstantColor          = b_i##x##UseConstantColor;                     \
    x##LayerConfig.b_iOp                        = b_i##x##Op;                                   \
    x##LayerConfig.b_iIsRTTTexture              = b_i##x##IsRTTTexture;                         \
    x##LayerConfig.b_iTriPlanarUvId             = b_i##x##TriPlanarUvId;                        \
    x##LayerConfig.p_vMultiplyAddAlphaTrans     = p_v##x##MultiplyAddAlphaTrans;                \
    x##LayerConfig.p_vAtlasParams               = p_v##x##AtlasParams;                          \
    x##LayerConfig.p_vFresnelExponentBiasScale  = p_v##x##FresnelExponentBiasScale;             \
    x##LayerConfig.p_cConstantColor             = p_c##x##ConstantColor;                        \
    x##LayerConfig.p_vRTTTextureOffsetScale     = p_v##x##RTTTextureOffsetScale;                \
    x##LayerConfig.p_mFresnelTransform          = p_m##x##FresnelTransform;                     \
    x##LayerConfig.p_mUVTransform               = p_m##x##UVTransform;

#define GetLayerColor( layer, mask, allowEnvio, normal, mTriPlanarUVs )   ComputeLayerColor(   vertOut, layer##LayerConfig,\
                                                                        texSampler(p_s##layer##Sampler), \
                                                                        texTexture(p_s##layer##Sampler), \
                                                                        envMappings, mask, allowEnvio, normal, mTriPlanarUVs )

#define GetLayerColorGrad( layer, mask, allowEnvio, normal, ddx, ddy )   ComputeLayerColorGrad(   vertOut, layer##LayerConfig,\
                                                                        texSampler(p_s##layer##Sampler), \
                                                                        texTexture(p_s##layer##Sampler), \
                                                                        envMappings, mask, allowEnvio, normal, \
                                                                        ddx, ddy )

#define GetLayerColorBias( layer, mask, allowEnvio, normal, bias )   ComputeLayerColorBias(   vertOut, layer##LayerConfig,\
                                                                        texSampler(p_s##layer##Sampler), \
                                                                        texTexture(p_s##layer##Sampler), \
                                                                        envMappings, mask, allowEnvio, normal, \
                                                                        bias )

#define GetLayerColorLevel( layer, mask, allowEnvio, normal, level )   ComputeLayerColorLevel(   vertOut, layer##LayerConfig,\
                                                                        texSampler(p_s##layer##Sampler), \
                                                                        texTexture(p_s##layer##Sampler), \
                                                                        envMappings, mask, allowEnvio, normal, \
                                                                        level )

HALF4       p_cEmissiveTeamColor;
HALF4       p_cDiffuseTeamColor;
HALF2       p_fTeamColorIntensity;

//--------------------------------------------------------------------------------------------------
float3x2 InitializeTriPlanarUVsSingleImpl (SLayerConfig layerSettings, in VertexTransport vertOut) {
    float4 vUV = GetUVEmitter(vertOut, layerSettings.b_iUVEmitter, layerSettings.p_vMultiplyAddAlphaTrans.w, layerSettings.p_mUVTransform );

    float3 normal;
    if (TriPlanarIsWorldFX(layerSettings.b_iUVMapping)) {
        normal = INTERPOLANT_Normal.xyz;
    }
    else {
        normal = INTERPOLANT_VectorUI0.xyz;
    }

    float2 uvZ;
    float2 uvY;
    float2 uvX;
    TriplanarAtlas(layerSettings.p_vAtlasParams, normal, vUV.xyz, uvZ, uvY, uvX);
        
    float3x2 outMat;
    outMat[0] = uvZ;
    outMat[1] = uvY;
    outMat[2] = uvX;
    return outMat;
}

#define InitializeTriPlanarUVsSingle(x, vertOut, mTriPlanarUVs) \
    if (IsTriPlanarMappingFX(b_i##x##UVMapping) &&              \
        b_i##x##TriPlanarUvId >= c_maxNumLayers &&              \
        b_i##x##LayerId < c_maxNumLayers) {                     \
            SETUP_LAYER(x);                                     \
            mTriPlanarUVs[b_i##x##LayerId] = InitializeTriPlanarUVsSingleImpl (x##LayerConfig, vertOut); \
        }

//--------------------------------------------------------------------------------------------------
HALF CalcFresnelTerm( HALF3 vNormal, float3 vEyetoVertex, HALF exponent, half3x4 mFresnelTransform, int iFresnelTransformMode, bool bFresnelSaturate ) {
    if ( PIXEL_SHADER_VERSION <= SHADER_VERSION_PS_14 )
        return 1;
        
    HALF3 vFresnelDir = vEyetoVertex;
    float fResult;
    if (iFresnelTransformMode != FRESNELTRANSFORM_NONE) {
        vFresnelDir = mul(mFresnelTransform,HALF4(vFresnelDir,1.0)).xyz;
        if (iFresnelTransformMode == FRESNELTRANSFORM_NORMALIZED)
            vFresnelDir = normalize(vFresnelDir);
    }
    
    if (bFresnelSaturate)
        fResult = 1.0f - saturate( -dot( vNormal, vFresnelDir ) );
    else
        fResult = 1.0f - abs( dot( vNormal, vFresnelDir ) );
    
    fResult = pow( max( fResult, 0.0001), exponent );
    return fResult;
}

HALF4 ComputeLayerColorInternal( 
    in VertexTransport vertOut,
    SLayerConfig layerSettings, 
    HALF fMask,
    HALF4 cColor,
    HALF3 vNormal
) {
    HALF4 cResult = cColor;

    // Apply mask.
    if ( layerSettings.b_iUseMask )
        cResult = cResult * fMask;
    
    cResult = ChooseChannel( layerSettings.b_iChannelSelect, cResult );

    // Alpha factor.
    cResult.a *= layerSettings.p_vMultiplyAddAlphaTrans.z;

    // Apply team cColor.
    if (layerSettings.b_iChannelSelect != CHANNELSELECT_RGB) {
        if ( layerSettings.b_iTeamColorMode == TEAMCOLOR_DIFFUSE ) {
            cResult = HALF4( lerp( p_cDiffuseTeamColor.rgb, cResult.rgb, saturate(pow(cColor.a,p_fTeamColorIntensity.x)) ).rgb, 1.0f );	// When team colored, the alpha represents the team color ratio                                                                                        // Not the layerSettings operation's blend/add ratio
        } else if ( layerSettings.b_iTeamColorMode == TEAMCOLOR_EMISSIVE ) {        
            cResult = HALF4( lerp( p_cEmissiveTeamColor.rgb, cResult.rgb, cColor.a ).rgb, 1.0f );   // When team colored, the alpha represents the team color ratio                                                                                        // Not the layerSettings operation's blend/add ratio
        }
    }

    if ( layerSettings.b_iInvert )
        cResult = HALF4( 1.0f, 1.0f, 1.0f, 1.0f ) - cResult;
        
    // Apply RGB multiplication factor and add term.
    cResult.rgba = (cResult.rgba * layerSettings.p_vMultiplyAddAlphaTrans.x) + layerSettings.p_vMultiplyAddAlphaTrans.y;
    
    // Apply layerSettings clamping.
    if ( layerSettings.b_iClamp )
        cResult.rgba = saturate( cResult.rgba );
        
    // Fresnel term, applicable on any layer.
    HALF fFresnelTerm;
    if ( b_useSimplifiedFresnel )
        fFresnelTerm  =	CalcFresnelTerm( vNormal, p_vCameraDirection, layerSettings.p_vFresnelExponentBiasScale.x, layerSettings.p_mFresnelTransform, layerSettings.b_iFresnelTransformMode, layerSettings.b_iFresnelSaturate );
    else fFresnelTerm  =	CalcFresnelTerm( vNormal, INTERPOLANT_EyeToVertexFresnel, layerSettings.p_vFresnelExponentBiasScale.x, layerSettings.p_mFresnelTransform, layerSettings.b_iFresnelTransformMode, layerSettings.b_iFresnelSaturate );
    if ( layerSettings.b_iFresnelMode == FRESNELMODE_INVERTED )
        fFresnelTerm = 1.0f - fFresnelTerm;
    fFresnelTerm = saturate( fFresnelTerm * layerSettings.p_vFresnelExponentBiasScale.z + layerSettings.p_vFresnelExponentBiasScale.y ); 
    
    if ( layerSettings.b_iFresnelMode != FRESNELMODE_NONE )
        cResult = cResult * fFresnelTerm;
        
    return cResult;
}

#define typeTexture typeTexture2D
#define textureEnum TEXTURE_TYPE_2D
#define typeSampler typeSampler2D
#include "PSMaterialLayerColor.fx"
#undef typeTexture
#undef textureEnum
#undef typeSampler

#define typeTexture typeTexture3D
#define textureEnum TEXTURE_TYPE_VOLUME
#define typeSampler typeSampler3D
#include "PSMaterialLayerColor.fx"
#undef typeTexture
#undef textureEnum
#undef typeSampler

#define typeTexture typeTextureCube
#define textureEnum TEXTURE_TYPE_CUBE
#define typeSampler typeSamplerCube
#include "PSMaterialLayerColor.fx"
#undef typeTexture
#undef textureEnum
#undef typeSampler

//--------------------------------------------------------------------------------------------------
HALF3 CombineLayerColor( 
    HALF4   cLayerColor, 
    HALF3   cResult,
    SLayerConfig layerSettings
) {
    // Combine layer color.
    if ( layerSettings.b_iOp == LAYEROP_MOD )
        cResult = cResult * cLayerColor.rgb;
    else if ( layerSettings.b_iOp == LAYEROP_MOD2X )
        cResult = cResult * cLayerColor.rgb * 2.0f;    
    else if ( layerSettings.b_iOp == LAYEROP_ADD )
        cResult = cResult + cLayerColor.rgb * cLayerColor.a;
    else if ( layerSettings.b_iOp == LAYEROP_ADD_NO_ALPHA )
        cResult = cResult + cLayerColor.rgb;
    else if ( layerSettings.b_iOp == LAYEROP_LERP )
        cResult = lerp( cResult, cLayerColor.rgb, cLayerColor.a );
    else if ( layerSettings.b_iOp == LAYEROP_TEAMCOLOR_EMISSIVE_ADD )
        cResult = cResult + saturate(pow(cLayerColor.a, p_fTeamColorIntensity.y)) * p_cEmissiveTeamColor.rgb;
    else if ( layerSettings.b_iOp == LAYEROP_TEAMCOLOR_DIFFUSE_ADD )
        cResult = cResult + cLayerColor.a * p_cDiffuseTeamColor.rgb;
    return cResult;
}

//--------------------------------------------------------------------------------------------------
HALF3 DecodeNormalSample (HALF4 cTextureSample, out HALF fExtraValue ) {
    HALF3 vPixelNormal;
    if (b_DXNStyleNormalMaps) {
        vPixelNormal.xy = 2.0f * cTextureSample.wy - 1.0f;
        vPixelNormal.z = sqrt(max(0, 1 - dot(vPixelNormal.xy, vPixelNormal.xy)));
        // we can't count on this here since the w component was used for the vNormal map itself
        fExtraValue = 1;
    }
    else {
        vPixelNormal = 2.0f * cTextureSample.xyz - 1.0f;
        fExtraValue = cTextureSample.w;
    }
    return vPixelNormal;
}

//--------------------------------------------------------------------------------------------------
HALF3 DecodeTextureNormal( typeSampler2D sNormalMap, typeTexture2D tNormalMap, HALF4 vNormalMapUV, out HALF fExtraValue ) {
    HALF4 cSample = sampleTex2D( tNormalMap, sNormalMap, vNormalMapUV.xy );
    return DecodeNormalSample(cSample, fExtraValue);
}

//--------------------------------------------------------------------------------------------------
HALF3 DecodeTextureNormalGrad( typeSampler2D sNormalMap, typeTexture2D tNormalMap, HALF4 vNormalMapUV, out HALF fExtraValue, HALF4 ddx, HALF4 ddy ) {
    HALF4 cSample = sampleTex2Dgrad( tNormalMap, sNormalMap, vNormalMapUV.xy, ddx, ddy );
    return DecodeNormalSample(cSample, fExtraValue);
}


//--------------------------------------------------------------------------------------------------
HALF3 DecodeTriTextureNormal(
    typeSampler2D sNormalMap, 
    typeTexture2D tNormalMap,
    float4 vUV, 
    float4 vAtlasParams,
    float4 vWeights, 
    float3 vNormal,
    out HALF fExtraValue
) {
    float2 uvX;
    float2 uvY;
    float2 uvZ;
    TriplanarAtlas(vAtlasParams, vNormal, vUV.rgb, uvZ, uvY, uvX);
    HALF4 vBlended = SampleTriPlanarTexture(sNormalMap, tNormalMap, uvZ, uvY, uvX, vWeights);
    return DecodeNormalSample(vBlended, fExtraValue);
}

#endif  // PIXEL_SHADER

#endif  // PS_MATERIALLAYER
