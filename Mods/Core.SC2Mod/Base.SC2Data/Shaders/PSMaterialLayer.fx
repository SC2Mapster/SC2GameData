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

#define TEAMCOLOR_NONE		0
#define TEAMCOLOR_DIFFUSE	1
#define TEAMCOLOR_EMISSIVE	2

#define TEXTURE_TYPE_2D     0
#define TEXTURE_TYPE_CUBE   1
#define TEXTURE_TYPE_VOLUME 2

struct SLayerConfig {
    
    bool    b_iLayerEnable;
    int     b_iTextureType;
    int     b_iUVMapping;
    int		b_iTeamColorMode;
    int     b_iUVEmitter;
    bool    b_iUseAlphaFactor;
    bool    b_iUseMask;    
    int     b_iChannelSelect;
    bool    b_iInvert;
    bool    b_iMultiplyEnable;
    bool    b_iAddEnable;
    bool    b_iClamp;
    int     b_iFresnelMode;
    bool    b_iUseConstantColor;
    half3   p_vMultiplyAddAlpha;
    half3   p_vFresnelExponentBiasScale;
    half4   p_cConstantColor;
    int     b_iOp;
    int     b_iIsRTTTexture;
    half4   p_vRTTTextureOffsetScale;

};

#define DECLARE_LAYER( x )      SLayerConfig    x##LayerConfig;                                     \
                                                sampler         p_s##x##Sampler;                    \
                                                half3           p_v##x##MultiplyAddAlpha;           \
                                                half3           p_v##x##FresnelExponentBiasScale;   \
                                                half4           p_c##x##ConstantColor;              \
                                                half4           p_v##x##RTTTextureOffsetScale;

#define SETUP_LAYER( x )                                                                        \
    x##LayerConfig.b_iLayerEnable               = b_i##x##LayerEnable;                          \
    x##LayerConfig.b_iTextureType               = b_i##x##TextureType;                          \
    x##LayerConfig.b_iUVMapping                 = b_i##x##UVMapping;                            \
    x##LayerConfig.b_iTeamColorMode             = b_i##x##TeamColorMode;                        \
    x##LayerConfig.b_iUVEmitter                 = b_i##x##UVEmitter;                            \
    x##LayerConfig.b_iUseAlphaFactor            = b_i##x##UseAlphaFactor;                       \
    x##LayerConfig.b_iUseMask                   = b_i##x##UseMask;                              \
    x##LayerConfig.b_iChannelSelect             = b_i##x##ChannelSelect;                        \
    x##LayerConfig.b_iInvert                    = b_i##x##Invert;                               \
    x##LayerConfig.b_iMultiplyEnable            = b_i##x##MultiplyEnable;                       \
    x##LayerConfig.b_iAddEnable                 = b_i##x##AddEnable;                            \
    x##LayerConfig.b_iClamp                     = b_i##x##Clamp;                                \
    x##LayerConfig.b_iFresnelMode               = b_i##x##FresnelMode;                          \
    x##LayerConfig.b_iUseConstantColor          = b_i##x##UseConstantColor;                     \
    x##LayerConfig.b_iOp                        = b_i##x##Op;                                   \
    x##LayerConfig.b_iIsRTTTexture              = b_i##x##IsRTTTexture;                         \
    x##LayerConfig.p_vMultiplyAddAlpha          = p_v##x##MultiplyAddAlpha;                     \
    x##LayerConfig.p_vFresnelExponentBiasScale  = p_v##x##FresnelExponentBiasScale;             \
    x##LayerConfig.p_cConstantColor             = p_c##x##ConstantColor;                        \
    x##LayerConfig.p_vRTTTextureOffsetScale     = p_v##x##RTTTextureOffsetScale;

#define GetLayerColor( layer, mask, allowEnvio )   ComputeLayerColor(   vertOut, layer##LayerConfig,            \
                                                                        p_s##layer##Sampler, envMappings, mask, allowEnvio )
half4       p_cEmissiveTeamColor;
half4       p_cDiffuseTeamColor;

//--------------------------------------------------------------------------------------------------
half4 SampleLayer(  in VertexTransport vertOut, SLayerConfig layerSettings, 
                    sampler Sampler, SEnvMappings envMappings, bool allowEnvio ) {
    if ( layerSettings.b_iUseConstantColor )
        return layerSettings.p_cConstantColor;

    half4 vUV = GetUVEmitter(vertOut, layerSettings.b_iUVEmitter);

#if 0
    if (b_textureProjectorEnabled || b_splatTextureProjectorEnabled) {
        /* :TODO: :FIXME: layer.vUV.xy = Ndc2Tex( layer.vUV.xy / layer.vUV.w, b_splatTextureProjectorEnabled == 0);           \*/
        vUV.xy = Ndc2Tex( vUV.xy, b_splatTextureProjectorEnabled == 0);
    }
#endif

    if ( allowEnvio ) {
        if ( layerSettings.b_iUVMapping == UVMAP_REFLECT_CUBICENVIO || layerSettings.b_iUVMapping == UVMAP_CUBICENVIO )
            vUV = GenEnvioUV( envMappings, layerSettings.b_iUVMapping );
        else if ( layerSettings.b_iUVMapping == UVMAP_REFLECT_SPHERICALENVIO || layerSettings.b_iUVMapping == UVMAP_SPHERICALENVIO ) 
            vUV = GenEnvioUV( envMappings, layerSettings.b_iUVMapping );
    }

    if ( layerSettings.b_iIsRTTTexture )
        vUV.xy = vUV.xy * layerSettings.p_vRTTTextureOffsetScale.zw + layerSettings.p_vRTTTextureOffsetScale.xy;

    if ( layerSettings.b_iTextureType == TEXTURE_TYPE_2D )
       return tex2D( Sampler, vUV.xy );
    else if ( layerSettings.b_iTextureType == TEXTURE_TYPE_CUBE )
       return texCUBE( Sampler, vUV.xyz );
    else if ( layerSettings.b_iTextureType == TEXTURE_TYPE_VOLUME )
       return tex3D( Sampler, vUV.xyz );
    else return 0;
}

//--------------------------------------------------------------------------------------------------
half CalcFresnelTerm( half3 vNormal, float3 vEyetoVertex, half exponent ) {
    if ( PIXEL_SHADER_VERSION <= SHADER_VERSION_PS_14 )
        return 1;

    float fResult = 1.0f - abs( dot( vNormal, vEyetoVertex ) );
#ifdef COMPILING_SHADER_FOR_OPENGL
    fResult = max( fResult, 0.0000001);
#endif
    fResult = pow( fResult, exponent );
    return fResult;
}

//--------------------------------------------------------------------------------------------------
half4 ComputeLayerColor(    in VertexTransport vertOut, SLayerConfig layerSettings, 
                            sampler Sampler, SEnvMappings envMappings, half fMask, bool allowEnvio ) {
    half4 cColor = SampleLayer( vertOut, layerSettings, Sampler, envMappings, allowEnvio );
    half4 cResult = cColor;

    // Apply mask.
	if ( layerSettings.b_iUseMask )
        cResult = cResult * fMask;
	
	cResult = ChooseChannel( layerSettings.b_iChannelSelect, cResult );
	    
    // Alpha factor.
    if ( layerSettings.b_iUseAlphaFactor )
        cResult.a *= layerSettings.p_vMultiplyAddAlpha.z;
        
    // Apply team cColor.
    if ( layerSettings.b_iTeamColorMode == TEAMCOLOR_DIFFUSE ) {
        cResult = half4( lerp( p_cDiffuseTeamColor, cResult, cColor.a ).rgb, 1.0f );	// When team colored, the alpha represents the team color ratio                                                                                        // Not the layerSettings operation's blend/add ratio
    } else if ( layerSettings.b_iTeamColorMode == TEAMCOLOR_EMISSIVE ) {        
		cResult = half4( lerp( p_cEmissiveTeamColor, cResult, cColor.a ).rgb, 1.0f );   // When team colored, the alpha represents the team color ratio                                                                                        // Not the layerSettings operation's blend/add ratio
	}

	// Invert layer color if needed.
	if ( layerSettings.b_iInvert )
	    cResult = half4( 1.0f, 1.0f, 1.0f, 1.0f ) - cResult;
    	
	// Apply RGB multiplication factor and add term.
	if ( layerSettings.b_iMultiplyEnable )
	    cResult.rgba *= layerSettings.p_vMultiplyAddAlpha.x;
	if ( layerSettings.b_iAddEnable )
	    cResult.rgba += layerSettings.p_vMultiplyAddAlpha.y;
    
	// Apply layerSettings clamping.
	if ( layerSettings.b_iClamp )
	    cResult.rgba = saturate( cResult.rgba );
	    
	// Fresnel term, applicable on any layer.
	half fFresnelTerm;
	if ( b_useSimplifiedFresnel )
		fFresnelTerm  =	CalcFresnelTerm( g_vDeferredNormal, p_vCameraDirection, layerSettings.p_vFresnelExponentBiasScale.x );
    else fFresnelTerm  =	CalcFresnelTerm( g_vDeferredNormal, INTERPOLANT_EyeToVertexFresnel, layerSettings.p_vFresnelExponentBiasScale.x );
	if ( layerSettings.b_iFresnelMode == FRESNELMODE_INVERTED )
	    fFresnelTerm = 1.0f - fFresnelTerm;
    fFresnelTerm = saturate( fFresnelTerm * layerSettings.p_vFresnelExponentBiasScale.z + layerSettings.p_vFresnelExponentBiasScale.y ); 
	
	if ( layerSettings.b_iFresnelMode != FRESNELMODE_NONE )
	    cResult = cResult * fFresnelTerm;
	    
	return cResult;
}

//--------------------------------------------------------------------------------------------------
half3 CombineLayerColor( 
    half4   cLayerColor, 
    half3   cResult,
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
        cResult = cResult + cLayerColor.a * p_cEmissiveTeamColor.rgb;
    else if ( layerSettings.b_iOp == LAYEROP_TEAMCOLOR_DIFFUSE_ADD )
        cResult = cResult + cLayerColor.a * p_cDiffuseTeamColor.rgb;
	return cResult;
}

//--------------------------------------------------------------------------------------------------
half3 DecodeTextureNormal( sampler2D sNormapMap, half4 vNormalMapUV, out half fExtraValue ) {
    //if ( b_textureProjectorEnabled || b_splatTextureProjectorEnabled)
    //    vNormalMapUV.xy = Ndc2Tex(vNormalMapUV.xy / vNormalMapUV.w, b_splatTextureProjectorEnabled == 0);

    half3 vPixelNormal;
    half4 cSample = tex2D( sNormapMap, vNormalMapUV.xy );
    if (b_DXNStyleNormalMaps) {
        vPixelNormal.xy = 2.0f * cSample.wy - 1.0f;
        vPixelNormal.z = sqrt(max(0, 1 - dot(vPixelNormal.xy, vPixelNormal.xy)));
        // we can't count on this here since the w component was used for the vNormal map itself
        fExtraValue = 1;
    }
    else {
        vPixelNormal = 2.0f * cSample.xyz - 1.0f;
        fExtraValue = cSample.w;
    }
    return vPixelNormal;
}

#endif  // PIXEL_SHADER

#endif  // PS_MATERIALLAYER