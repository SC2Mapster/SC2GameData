
//==================================================================================================
//
// Copyright Blizzard Entertainment 2003-2005
//
//==================================================================================================

#ifndef PS_MATERIAL
#define PS_MATERIAL

#ifdef PIXEL_SHADER

#include "ShaderSystem.fx"
#include "PSMaterialDefines.fx"
#include "PSUVMapping.fx"
#include "PSDebugUtils.fx"
#include "PSCommon.fx"
#include "PSMaterialLayer.fx"
#include "PSFOW.fx"

//==================================================================================================
// Uniform parameters

// Colors
HALF            p_fEmissiveMultiplier;
HALF3           p_fMaterialTint;
float4          p_cMaterialFOWParams;
float4          p_vEnvioTextureSize;

DECLARE_LAYER_2D(Diffuse);
DECLARE_LAYER_2D(Decal);
DECLARE_LAYER_2D(Specular);
DECLARE_LAYER_2D(SpecularExponent);
DECLARE_LAYER_2D(Emissive);
DECLARE_LAYER_2D(Emissive2);

#if b_iEnvioTextureType == TEXTURE_TYPE_2D
DECLARE_LAYER_2D( Envio );
#else
DECLARE_LAYER_CUBE( Envio );
#endif
#if b_iEnvioMaskTextureType == TEXTURE_TYPE_2D
DECLARE_LAYER_2D( EnvioMask );
#else
DECLARE_LAYER_CUBE( EnvioMask );
#endif

DECLARE_LAYER_2D(AlphaMask);
DECLARE_LAYER_2D(AlphaMask2);
DECLARE_LAYER_2D(Normal);
DECLARE_LAYER_2D(Heightmap);
DECLARE_LAYER_2D(Lightmap);
DECLARE_LAYER_2D(AmbientOcclusion);
DECLARE_LAYER_2D(NormalBlendMask);
DECLARE_LAYER_2D(NormalBlendMask2);
DECLARE_LAYER_2D(NormalBlendNormal);
DECLARE_LAYER_2D(NormalBlendNormal2);

texDecl2D(p_sSSAO);

HALF3       p_cLightmapShadowColor;
float3x4    p_mEnvironmentMapTransform;

HALF4       p_vNormalBlendingFactors;
HALF4       p_vNormalBlendingFactors2;

HALF3       p_vEnvioConstantDiffSpec;

#if defined(COMPILING_SHADER_FOR_OPENGL) || defined(COMPILING_SHADER_FOR_OPENGL3)
    HALF       p_fFaceRender;
#endif

//--------------------------------------------------------------------------------------------------
float3  EmitPSFOWUV (VertexTransportRaw vertOut) {
    return mul(INTERPOLANT_WorldPos, p_mFOWMatrix);
}

//--------------------------------------------------------------------------------------------------
HALF3  ApplyEnv (in HALF3 cColor, in HALF3 cEnv, HALF4 cMaskValue, int b_iOp ) {
    if ( b_iOp == LAYEROP_MOD )
        return cColor * cEnv * cMaskValue.rgb;
    else if ( b_iOp == LAYEROP_ADD )
        return cColor + cEnv * cMaskValue.rgb;
    else if ( b_iOp == LAYEROP_LERP )
        return lerp( cColor, cEnv, cMaskValue.a );

    return cColor;
}

//--------------------------------------------------------------------------------------------------
void InitializeTriPlanarUVs (in VertexTransport vertOut, out float3x2 mTriPlanarUVs[c_maxNumLayers]) {

    // HLSL gets unhappy if we do not initialize all elements
    for (int i = 0; i < c_maxNumLayers; i++)
        mTriPlanarUVs[i] = float3x2(1.0, 0.0, 0.0, 1.0, 0.0, 0.0);

    InitializeTriPlanarUVsSingle(Diffuse, vertOut, mTriPlanarUVs);
    InitializeTriPlanarUVsSingle(Decal, vertOut, mTriPlanarUVs);
    InitializeTriPlanarUVsSingle(Specular, vertOut, mTriPlanarUVs);
    InitializeTriPlanarUVsSingle(SpecularExponent, vertOut, mTriPlanarUVs);
    InitializeTriPlanarUVsSingle(Emissive, vertOut, mTriPlanarUVs);
    InitializeTriPlanarUVsSingle(Emissive2, vertOut, mTriPlanarUVs);

#if b_iEnvioTextureType == TEXTURE_TYPE_2D
    InitializeTriPlanarUVsSingle(Envio, vertOut, mTriPlanarUVs);
#endif
#if b_iEnvioMaskTextureType == TEXTURE_TYPE_2D
    InitializeTriPlanarUVsSingle(EnvioMask, vertOut, mTriPlanarUVs);
#endif

    InitializeTriPlanarUVsSingle(AlphaMask, vertOut, mTriPlanarUVs);
    InitializeTriPlanarUVsSingle(AlphaMask2, vertOut, mTriPlanarUVs);
    InitializeTriPlanarUVsSingle(Normal, vertOut, mTriPlanarUVs);
    InitializeTriPlanarUVsSingle(Heightmap, vertOut, mTriPlanarUVs);
    InitializeTriPlanarUVsSingle(Lightmap, vertOut, mTriPlanarUVs);
    InitializeTriPlanarUVsSingle(AmbientOcclusion, vertOut, mTriPlanarUVs);
    InitializeTriPlanarUVsSingle(NormalBlendMask, vertOut, mTriPlanarUVs);
    InitializeTriPlanarUVsSingle(NormalBlendMask2, vertOut, mTriPlanarUVs);
    InitializeTriPlanarUVsSingle(NormalBlendNormal, vertOut, mTriPlanarUVs);
    InitializeTriPlanarUVsSingle(NormalBlendNormal2, vertOut, mTriPlanarUVs);
}

//--------------------------------------------------------------------------------------------------
// Main material hook.
//--------------------------------------------------------------------------------------------------
HALF4 MaterialColor(    in VertexTransport vertOut, 
                        HALF3 vNormal,              // Input normal
                        HALF3 cLightDiffuse,        // Input lighting diffuse color
                        HALF3 cLightSpecular,       // Input lighting specular color
                        HALF4 cShadowColor,         // Shadowed or not,
                        HALF fSpecularity,
                        HALF4 cLightingRegionMap,   // Only used for debugging
                        inout HALF3 vDeferredNormal,
                        inout HALF3 cDeferredDiffuse,
                        inout HALF3 cDeferredSpecular,
                        HALF fAmbientOcclusion,
                        inout HALF cDeferredSpecularPower,
                        inout HALF cDeferredGlossiness,
                        inout float3x2 mTriPlanarUVs[c_maxNumLayers] )
{
    // Compute all material layers.
    cDeferredDiffuse                = 0;
    cDeferredSpecular               = 0;
    HALF3   cEmissive       = 0;

    //----------------------------------------------------------------------------------------------
    // :TODO: Verify this.
    //if ( !b_useLighting && b_useEmissiveMultiplier )
    //    cLightDiffuse   = p_fEmissiveMultiplier;
    if ( b_iDebugMode == FULLBRIGHT_DIFFUSE_ONLY )
        cLightDiffuse = 1;

    
    SEnvMappings envMappings;
    envMappings = ComputeEnvMappings( vertOut, 
                                        mul( p_mEnvironmentMapTransform, float4(vNormal,1.0) ).xyz, 
                                        mul( p_mEnvironmentMapTransform, float4(INTERPOLANT_EyeToVertex,1.0)).xyz );
        
    //----------------------------------------------------------------------------------------------
    // Team colored diffuse layer.
    HALF fTeamColorAlpha = 0;        // Sampled team color alpha.
    HALF3 vDiffuseUV = 0;
    if ( b_iDiffuseLayerEnable ) {
        SETUP_LAYER( Diffuse );
        if ( !DiffuseLayerConfig.b_iUseConstantColor )
            vDiffuseUV = GetUVEmitter(vertOut, DiffuseLayerConfig.b_iUVEmitter, DiffuseLayerConfig.p_vMultiplyAddAlphaTrans.w, DiffuseLayerConfig.p_mUVTransform).xyz;

        HALF4 cColor = GetLayerColor( Diffuse, 1.0f, false, vDeferredNormal, mTriPlanarUVs );
        cDeferredDiffuse = CombineLayerColor( cColor, cDeferredDiffuse, DiffuseLayerConfig );
        fTeamColorAlpha = cColor.a;
    }

    //----------------------------------------------------------------------------------------------
    // Decal layer.
    if ( b_iDecalLayerEnable ) {
        SETUP_LAYER( Decal );
        HALF4 cColor = GetLayerColor( Decal, 1.0f, false, vDeferredNormal, mTriPlanarUVs );
        cDeferredDiffuse = CombineLayerColor( cColor, cDeferredDiffuse, DecalLayerConfig );
    }

    //----------------------------------------------------------------------------------------------
    // Specular layer.
    if ( b_iSpecularLayerEnable ) {
        SETUP_LAYER( Specular );
        //if ( b_iSpecularType == SPECULAR_A_ONLY )
        //    SpecularLayerConfig.b_iChannelSelect = CHANNELSELECT_A;
        HALF4 cColor = GetLayerColor( Specular, 1.0f, false, vDeferredNormal, mTriPlanarUVs );

        if ( b_iSpecularType == SPECULAR_A_ONLY ) {
            if ( b_iDiffuseTeamColorMode == TEAMCOLOR_DIFFUSE && b_useTeamColorSpecular ) {
                cColor = lerp( p_cDiffuseTeamColor.a, cColor.a, fTeamColorAlpha );
            }
        } else {
            if ( b_iDiffuseTeamColorMode == TEAMCOLOR_DIFFUSE && b_useTeamColorSpecular ) {
                //HALF fLayerLuminance = dot ( HALF3(0.27f, 0.67f, 0.06f), cColor.rgb );
                cColor = HALF4( lerp( p_cDiffuseTeamColor.rgb , cColor.rgb, fTeamColorAlpha ).rgb, 1.0f );
            }
        }

        cDeferredSpecular = CombineLayerColor( cColor, cDeferredSpecular, SpecularLayerConfig );
    }

    if( b_iFakeEnergyConservingSpec ) {
        // IWRM Note: This is a polynomial fit for the relative area of a specular highlight on a sphere. Then adjusted to make the lowest value darker.
        float powClamped = clamp( fSpecularity, 1.f, 512.f );
        float dim = saturate(-0.000004444f*powClamped*powClamped + 0.004333f*powClamped + 0.0020834f);
        cDeferredSpecular *= dim;
    }

    //----------------------------------------------------------------------------------------------
    // Special mode showing lit components only.
    if ( b_litOnly ) {
        if ( !b_useLighting ) {
            cLightDiffuse = 0;
            cLightSpecular = 0;
        }
    }
    
    //----------------------------------------------------------------------------------------------
    // Color by lightmap.
    if ( b_iLightmapLayerEnable ) {
        SETUP_LAYER( Lightmap );
        HALF4 cColor = GetLayerColor( Lightmap, 1.0f, false, vDeferredNormal, mTriPlanarUVs ) * 2.0f;
        cLightDiffuse = cColor.rgb;
        cLightSpecular = 0;
        if ( b_iLightmapShadow ) {
            cLightDiffuse *= lerp( p_cLightmapShadowColor, 1.0f, cShadowColor.a );
        }
    }
    
    //----------------------------------------------------------------------------------------------
    // Blend the lighting components.
    HALF4   cFinal;
    cFinal.rgb = cDeferredDiffuse * cLightDiffuse;
    if ( b_useLighting && b_useSpecular )
        cFinal.rgb += cDeferredSpecular * cLightSpecular;
    else
        cLightSpecular = 0;
    
    if ( !b_litOnly ) {
        //----------------------------------------------------------------------------------------------
        // First emissive layer.
        bool bAdd = false;
        if ( b_iEmissiveLayerEnable ) {
            SETUP_LAYER( Emissive );
            HALF4 cColor = GetLayerColor( Emissive, 1.0f, false, vDeferredNormal, mTriPlanarUVs );
            if( EmissiveLayerConfig.b_iOp == LAYEROP_MOD || EmissiveLayerConfig.b_iOp == LAYEROP_MOD2X || EmissiveLayerConfig.b_iOp == LAYEROP_LERP)
                cFinal.rgb = CombineLayerColor( cColor, cFinal.rgb, EmissiveLayerConfig );
            else {
                cEmissive = CombineLayerColor( cColor, cEmissive, EmissiveLayerConfig );
                bAdd = true;
            }
        }
        
        //----------------------------------------------------------------------------------------------
        // Second emissive layer.
        if ( b_iEmissive2LayerEnable ) {
            SETUP_LAYER( Emissive2 );
            HALF4 cColor = GetLayerColor( Emissive2, 1.0f, false, vDeferredNormal, mTriPlanarUVs );
            if( !bAdd && (Emissive2LayerConfig.b_iOp == LAYEROP_MOD || Emissive2LayerConfig.b_iOp == LAYEROP_MOD2X || Emissive2LayerConfig.b_iOp == LAYEROP_LERP) )
                cFinal.rgb = CombineLayerColor( cColor, cFinal.rgb, Emissive2LayerConfig );
            else {
                cEmissive = CombineLayerColor( cColor, cEmissive, Emissive2LayerConfig );
                bAdd = true;
            }
        }
        
        //----------------------------------------------------------------------------------------------
        // if ( b_useEmissiveMultiplier )
        if ( bAdd ) {
            if ( b_iEmissiveLayerEnable || b_iEmissive2LayerEnable )
                cEmissive = cEmissive * p_fEmissiveMultiplier;
                
            cFinal.rgb += cEmissive.rgb;
        }
    }

    //----------------------------------------------------------------------------------------------
    // Environment map layer.
    if ( !b_litOnly ) {
        if ( b_iEnvioLayerEnable ) {    
            SETUP_LAYER( Envio );
            SETUP_LAYER( Normal );
            HALF4 cColor;

#ifdef COMPILING_SHADER_FOR_OPENGL
            // Biased normal maps not supported on mac currently because they can't support our mipmapping scheme.
            cColor = GetLayerColor( Envio, 1.0f, true, vDeferredNormal, mTriPlanarUVs );
#else
            if( b_iBlurEnvironmentMap ) {
                // We need to calculate our own mip here because using the normal mapped normal as the source of our mip level
                // leads to weird artifacts because of the varying rate of change in the normal and because even changing mip levels because
                // the camera position changes for reflections. Normally this doesn't happen because normals are pretty smooth, but all the old sc2
                // models have errors in their baked normals and their vertex norm/binorm/tangent aren't orthogonal. So instead we use the normal map uv deltas
                // or the change in the eye to vert position.

                // This is the equation for mip calculation given by the opengl standard.
                // DirectX doesn't give this info so hopefully they're the same.
                float3 deltaX, deltaY;
                if ( b_useNormalMapping && NormalLayerConfig.b_iLayerEnable ) {
                    HALF4 vUV = GetUVEmitter(vertOut, NormalLayerConfig.b_iUVEmitter, NormalLayerConfig.p_vMultiplyAddAlphaTrans.w, NormalLayerConfig.p_mUVTransform );
                    deltaX = ddx( vUV.xyz*p_vEnvioTextureSize.x );
                    deltaY = ddy( vUV.xyz*p_vEnvioTextureSize.y );
                } else {
                    deltaX = ddx( INTERPOLANT_EyeToVertex.xyz * .25f * p_vEnvioTextureSize.x );
                    deltaY = ddy( INTERPOLANT_EyeToVertex.xyz * .25f * p_vEnvioTextureSize.y );
                }

                float mipLevel = max( dot( deltaX, deltaX ), dot( deltaY, deltaY ) );
                mipLevel = max( 0, .5f * log2( mipLevel ) );

                HALF bias = p_vEnvioTextureSize.z * (1.f - cDeferredGlossiness);
                cColor = GetLayerColorLevel( Envio, 1.0f, true, vDeferredNormal, mipLevel + bias );
            } else {
                cColor = GetLayerColor( Envio, 1.0f, true, vDeferredNormal, mTriPlanarUVs );
            }
#endif

            HALF4 cMaskValue;
            if ( b_iEnvioMaskLayerEnable ) {
                SETUP_LAYER( EnvioMask );
                cMaskValue = GetLayerColor( EnvioMask, 1.0f, true, vDeferredNormal, mTriPlanarUVs );
                if( EnvioMaskLayerConfig.b_iChannelSelect == CHANNELSELECT_RGBA )
                    cMaskValue.rgb *= cMaskValue.a;
                cMaskValue *= cColor.a;
            } else cMaskValue = cColor.a;

            if (b_iEnvioMultipliers) {
                HALF3 cConstant = cColor.rgb * p_vEnvioConstantDiffSpec.x;
                cConstant += cColor.rgb * cLightDiffuse * p_vEnvioConstantDiffSpec.y;
                cConstant += cColor.rgb * cLightSpecular * p_vEnvioConstantDiffSpec.z;
                cFinal.rgb = ApplyEnv (cFinal.rgb, cConstant, cMaskValue, EnvioLayerConfig.b_iOp);
                cDeferredDiffuse = ApplyEnv (cDeferredDiffuse, cColor.rgb * p_vEnvioConstantDiffSpec.y, cMaskValue, EnvioLayerConfig.b_iOp);
                cDeferredSpecular = ApplyEnv (cDeferredSpecular, cColor.rgb * p_vEnvioConstantDiffSpec.z, cMaskValue, EnvioLayerConfig.b_iOp);
            }
            else
                cFinal.rgb = ApplyEnv (cFinal.rgb, cColor.rgb, cMaskValue, EnvioLayerConfig.b_iOp);
        }

        //----------------------------------------------------------------------------------------------
        // Tinting.
        if ( b_useVertexColors ) {
            float3 cVertex = saturate(INTERPOLANT_VertexColor.xyz);
            cFinal.rgb *= cVertex;
            cDeferredDiffuse.rgb *= cVertex;
        }
        // :TODO: Optimize this.
        cFinal.rgb        *= p_fMaterialTint;
        cDeferredDiffuse.rgb    *= p_fMaterialTint;
    }

    //----------------------------------------------------------------------------------------------
    // Alpha.
    cFinal.a = 1.0f;
    if ( b_useVertexAlpha )
        cFinal.a *= saturate(INTERPOLANT_VertexColor.a);
    //if ( b_alphaEnable )
    cFinal.a *= p_vSpecularMultiplier_DepthBlendThreshold_HeightMapScale_AlphaFactor.w;
    if ( b_splatAttenuationEnabled && PIXEL_SHADER_VERSION >= SHADER_VERSION_PS_30 ) {
        cFinal.a *= SplatAttenuationProjector( INTERPOLANT_VectorUI1.xyz, INTERPOLANT_VectorUI0, INTERPOLANT_VectorUI1.w, INTERPOLANT_Tangent.w);
    }

    //----------------------------------------------------------------------------------------------
    // Soft blend.
    if ( PIXEL_SHADER_VERSION >= SHADER_VERSION_PS_30 && b_useDepthBlend ) {
        // a.k.a. soft particles.
        float4 vNormalDepth = SampleNormalDepth( texSampler(p_sNormalDepthMap), texTexture(p_sNormalDepthMap), GetBackBufferUV( vertOut, true, true ) );
        float fDistToSampledDepth = max( 0, PIXEL_DEPTH - INTERPOLANT_ViewPos.y );
        if ( fDistToSampledDepth < p_vSpecularMultiplier_DepthBlendThreshold_HeightMapScale_AlphaFactor.y ) {
            cFinal.a *= ( fDistToSampledDepth / p_vSpecularMultiplier_DepthBlendThreshold_HeightMapScale_AlphaFactor.y );
        }
    }

    // Save off how transparent the whole pixel should be.
    //   For BlendAdd (premultiplied alpha), this is independent of alpha textures.
    HALF fade = cFinal.a;
    
    //----------------------------------------------------------------------------------------------
    // First alpha mask layer.
    if ( b_iAlphaMaskLayerEnable ) {
        SETUP_LAYER( AlphaMask );
        cFinal.a *= GetLayerColor( AlphaMask, 1.0f, false, vDeferredNormal, mTriPlanarUVs ).a;
    }
    
    //----------------------------------------------------------------------------------------------
    // Second alpha mask layer.
    if ( b_iAlphaMask2LayerEnable ) {
        SETUP_LAYER( AlphaMask2 );
        cFinal.a *= ( GetLayerColor( AlphaMask2, 1.0f, false, vDeferredNormal, mTriPlanarUVs ).a + 0.00000001f);  // Epsilon is to go around wacky shader compiler bug.
    }

    if ( !b_useBlendAdd ) {
        fade = cFinal.a;
    }

    if ( b_iModAlpha )
        cFinal.rgb *= fade;

    // Tricky: The specular multiplier for both material and HDR setting are actually pre-multiplied CPU side on
    // the light's specular multiplier so we don't use the multiplier for lighting since it's already baked in. 
    // For the deferred specular output however, we need to multiply the material specular multiplier manually here.    
    cDeferredSpecular *= p_vSpecularMultiplier_DepthBlendThreshold_HeightMapScale_AlphaFactor.x;
    
    //==============================================================================================
    // DEBUG MODES
    if ( b_iDebugMode != NO_DEBUG ) {
        HALF fExtraValue = 0;
        HALF3 vMapNormal=0;
        if ( b_useNormalMapping && b_iNormalLayerEnable) {
            SETUP_LAYER( Normal )
            HALF4 vUV = GetUVEmitter(vertOut, b_iNormalUVEmitter, NormalLayerConfig.p_vMultiplyAddAlphaTrans.w, NormalLayerConfig.p_mUVTransform);
            if (!IsTriPlanarMappingFX(b_iNormalUVMapping))
                vMapNormal = DecodeTextureNormal( texSampler(p_sNormalSampler), texTexture(p_sNormalSampler), vUV, fExtraValue );
            else {
                if (TriPlanarIsLocalFX(b_iNormalUVMapping)) {
                    vMapNormal = DecodeTriTextureNormal( texSampler(p_sNormalSampler), texTexture(p_sNormalSampler), vUV, p_vNormalAtlasParams, INTERPOLANT_TriPlanarWeights, INTERPOLANT_VectorUI0.xyz, fExtraValue);
                }
                else {
                    float4 weights = float4(INTERPOLANT_FogColor.x, INTERPOLANT_FogColor.y, vUV.w,0);
                    vMapNormal = DecodeTriTextureNormal(texSampler(p_sNormalSampler), texTexture(p_sNormalSampler), vUV, p_vNormalAtlasParams, weights, INTERPOLANT_Normal.xyz, fExtraValue);
                }
            }

        }

        return DebugColor(  cDeferredDiffuse, cDeferredSpecular, cEmissive, vMapNormal, vNormal, 
                            cLightDiffuse, cLightSpecular, cShadowColor, fAmbientOcclusion, 
                            cFinal.a, vDiffuseUV, 1.0f, vertOut, 
                            cFinal, p_cDebugColor, fSpecularity, cLightingRegionMap );
    }
    
    if ( b_iClampOutput ) {
        cFinal = saturate( cFinal ); 
    }

    return cFinal;
}

//--------------------------------------------------------------------------------------------------
HALF3 DecodeNormalInternal( VertexTransport vertOut, SLayerConfig layerSettings, typeSampler2D sLayer, typeTexture2D tLayer ) {
    // Decode normal.
    HALF3 vNormalWS, vNormalTS;
    HALF fExtraValue = 0;

    // Pixel-based.
    if ( b_useNormalMapping && layerSettings.b_iLayerEnable ) {
        SETUP_LAYER( Normal );
        HALF4 vUV = GetUVEmitter(vertOut, layerSettings.b_iUVEmitter, layerSettings.p_vMultiplyAddAlphaTrans.w, layerSettings.p_mUVTransform );
        if (!IsTriPlanarMappingFX(layerSettings.b_iUVMapping))
            vNormalTS = DecodeTextureNormal( sLayer, tLayer, vUV, fExtraValue );
        else {
            if (TriPlanarIsLocalFX(layerSettings.b_iUVMapping)) {
                vNormalTS = DecodeTriTextureNormal(sLayer, tLayer, vUV, p_vNormalAtlasParams, INTERPOLANT_TriPlanarWeights, INTERPOLANT_VectorUI0.xyz, fExtraValue);
            }
            else {
                float4 weights = float4(INTERPOLANT_FogColor.x, INTERPOLANT_FogColor.y, vUV.w, 0);
                vNormalTS = DecodeTriTextureNormal(sLayer, tLayer, vUV, p_vNormalAtlasParams, weights, INTERPOLANT_Normal.xyz, fExtraValue);
            }
        }
        
        vNormalWS = TangentToWorld( vNormalTS, INTERPOLANT_Normal.xyz, INTERPOLANT_Tangent.xyz, INTERPOLANT_Binormal, true );
    } 
    // Vertex-based.
    else {
        vNormalWS = normalize( INTERPOLANT_Normal.xyz );        
    }

    if ( b_iTwoSided ) {
        // we need to flip the normal if we are looking at the backface. Note that VFACE/SV_IsFrontFace
        // is relative to the winding order, so we have to check for the frontface
        if (PIXEL_SHADER_VERSION == SHADER_VERSION_PS_30) {
#ifdef COMPILING_SHADER_FOR_OPENGL
            if (p_fFaceRender < 0.0f)
#else
            if (INTERPOLANT_FrontFace >= 0.0f)
#endif
                vNormalWS = -vNormalWS;
        }
        else if (PIXEL_SHADER_VERSION >= SHADER_VERSION_PS_40) {
#if defined(COMPILING_SHADER_FOR_OPENGL3)
			if (p_fFaceRender != 0.0f)
				vNormalWS = vNormalWS * p_fFaceRender;
			else
#endif
            if (INTERPOLANT_FrontFace)
                vNormalWS = -vNormalWS;
        }
    }  

    return vNormalWS;
}

//--------------------------------------------------------------------------------------------------
HALF3 DecodeNormalGradInternal( VertexTransport vertOut, SLayerConfig layerSettings, typeSampler2D sLayer, typeTexture2D tLayer, HALF4 ddx, HALF4 ddy ) {
    // Decode normal.
    HALF3 vNormalWS, vNormalTS;
    HALF fExtraValue = 0;

    // Pixel-based.
    if ( b_useNormalMapping && layerSettings.b_iLayerEnable ) {
        HALF4 vUV = GetUVEmitter(vertOut, layerSettings.b_iUVEmitter, layerSettings.p_vMultiplyAddAlphaTrans.w, layerSettings.p_mUVTransform );
        vNormalTS = DecodeTextureNormalGrad( sLayer, tLayer, vUV, fExtraValue, ddx, ddy );
        
        vNormalWS = TangentToWorld( vNormalTS, INTERPOLANT_Normal.xyz, INTERPOLANT_Tangent.xyz, INTERPOLANT_Binormal, true );
    } 
    // Vertex-based.
    else {
        vNormalWS = normalize( INTERPOLANT_Normal.xyz );        
    }

    if ( b_iTwoSided ) {
        // we need to flip the normal if we are looking at the backface. Note that VFACE/SV_IsFrontFace
        // is relative to the winding order, so we have to check for the frontface
        if (PIXEL_SHADER_VERSION == SHADER_VERSION_PS_30) {
#ifdef COMPILING_SHADER_FOR_OPENGL
            if (p_fFaceRender < 0.0f)
#else
            if (INTERPOLANT_FrontFace >= 0.0f)
#endif
                vNormalWS = -vNormalWS;
        }
        else if (PIXEL_SHADER_VERSION >= SHADER_VERSION_PS_40) {
#if defined(COMPILING_SHADER_FOR_OPENGL3)
			if (p_fFaceRender != 0.0f)
				vNormalWS = vNormalWS * p_fFaceRender;
			else
#endif
            if (INTERPOLANT_FrontFace)
                vNormalWS = -vNormalWS;
        }
    }  

    return vNormalWS;
}
//--------------------------------------------------------------------------------------------------
HALF3 DecodeNormal( VertexTransport vertOut) {
    SETUP_LAYER( Normal );
    return DecodeNormalInternal( vertOut, NormalLayerConfig, texSampler(p_sNormalSampler), texTexture(p_sNormalSampler) );
}

//--------------------------------------------------------------------------------------------------
HALF DecodeAOValue( VertexTransport vertOut, HALF3 vDeferredNormal, inout HALF cDeferredAO, float3x2 mTriPlanarUVs[c_maxNumLayers] ) {
    HALF fAmbientOcclusion;
    if ( b_iAmbientOcclusionLayerEnable ) {
        SEnvMappings envMappings;
        SETUP_LAYER( AmbientOcclusion );
        fAmbientOcclusion = GetLayerColor( AmbientOcclusion, 1.0f, false, vDeferredNormal, mTriPlanarUVs ).a;
        cDeferredAO = fAmbientOcclusion;
    } else fAmbientOcclusion = 1.0f;

    if ( b_iUseDynamicAO ) {
        fAmbientOcclusion = saturate(fAmbientOcclusion * sample2D( p_sSSAO, GetBackBufferUV( vertOut, true, true ) ).a);
    }
    return fAmbientOcclusion;
}

//--------------------------------------------------------------------------------------------------
HALF2 DecodeSoftShadowUV( VertexTransport vertOut ) {
    // Use the first UV as the soft shadow noise interpolant so it doesn't swim around.
    HALF2 softShadowUV;
    if ( b_useShadows && b_iUseSoftShadows ) {
        if ( b_iUVEmitterCount > 0 ) {
            softShadowUV = READ_INTERPOLANT_UV(0).xy * 256.0f;    
        } else {
            // If there are no UV emitters use the screen-based UV generation.
            #if ( VPOS_SEMANTIC )
                softShadowUV = INTERPOLANT_ScreenPos.xy / p_vRotationTextureUVScale;
            #else
                softShadowUV = ( float4( INTERPOLANT_HPosAsUV / INTERPOLANT_HPosAsUV.w ).xy ) * p_vRotationTextureUVScale;
            #endif
        }
    } else softShadowUV = 0;
    return softShadowUV;
}

//--------------------------------------------------------------------------------------------------
// Determine specularity of fragment
//--------------------------------------------------------------------------------------------------
HALF MaterialSpecularity(in VertexTransport vertOut, HALF3 vDeferredNormal, out HALF cDeferredGlossiness, float3x2 mTriPlanarUVs[c_maxNumLayers]) {
    if ( b_iSpecularExponentLayerEnable ) {
        SETUP_LAYER( SpecularExponent );
        SEnvMappings envMappings;
        HALF4 cClr = GetLayerColor( SpecularExponent, 1.0f, false, vDeferredNormal, mTriPlanarUVs );
        cDeferredGlossiness = cClr.a;
        return cClr.a * cClr.a * p_vSpecColorSpecularity.w;
    }
    else {
        cDeferredGlossiness = 1;
        return p_vSpecColorSpecularity.w;
    }
}

//--------------------------------------------------------------------------------------------------
HALF3 NormalBlending(in VertexTransport vertOut, in HALF3 iBaseNormal, float3x2 mTriPlanarUVs[c_maxNumLayers] ) { 

    SEnvMappings envMappings;
    HALF3 outNormal = 0;
    SETUP_LAYER( NormalBlendMask );
    SETUP_LAYER( NormalBlendMask2 );
    SETUP_LAYER( NormalBlendNormal );
    SETUP_LAYER( NormalBlendNormal2 );

    HALF4 mask = GetLayerColor( NormalBlendMask, 1.0f, false, iBaseNormal, mTriPlanarUVs );
    HALF blendFactor = dot( mask, p_vNormalBlendingFactors );

    if( b_iNormalBlendingEnableMask2 ) {
        HALF4 mask2 = GetLayerColor( NormalBlendMask2, 1.0f, false, iBaseNormal, mTriPlanarUVs );
        blendFactor += dot( mask2, p_vNormalBlendingFactors2 );
    }
    blendFactor = clamp( blendFactor, -1.f, 1.f );
    blendFactor *= abs(blendFactor);

    HALF4 norm1UV = GetUVEmitter(vertOut, NormalBlendMaskLayerConfig.b_iUVEmitter, NormalBlendMaskLayerConfig.p_vMultiplyAddAlphaTrans.w, NormalBlendMaskLayerConfig.p_mUVTransform);
    float4 norm2UV = GetUVEmitter(vertOut, NormalBlendMask2LayerConfig.b_iUVEmitter, NormalBlendMask2LayerConfig.p_vMultiplyAddAlphaTrans.w, NormalBlendMask2LayerConfig.p_mUVTransform);

    HALF3 blendNormal;
#ifdef COMPILING_SHADER_FOR_OPENGL
    HALF3 blendNormal1, blendNormal2;
    blendNormal1 = DecodeNormalInternal( vertOut, NormalBlendNormalLayerConfig, texSampler(p_sNormalBlendNormalSampler),
        texTexture(p_sNormalBlendNormalSampler) );
    blendNormal2 = DecodeNormalInternal( vertOut, NormalBlendNormalLayerConfig, texSampler(p_sNormalBlendNormal2Sampler),
        texTexture(p_sNormalBlendNormal2Sampler) );
    blendNormal = blendFactor < 0.f ? blendNormal1 : blendNormal2;
#else
    // Compute texture gradients. These must be done outside the if statement.
    HALF4 ddx1 = ddx( norm1UV );
    HALF4 ddy1 = ddy( norm1UV );
    HALF4 ddx2 = ddx( norm2UV );
    HALF4 ddy2 = ddy( norm2UV );

    if( blendFactor < 0.f ) {
        blendNormal = DecodeNormalGradInternal( vertOut, NormalBlendNormalLayerConfig, texSampler(p_sNormalBlendNormalSampler),
            texTexture(p_sNormalBlendNormalSampler), ddx1, ddy1 );
    } else {
        blendNormal = DecodeNormalGradInternal( vertOut, NormalBlendNormalLayerConfig, texSampler(p_sNormalBlendNormal2Sampler),
            texTexture(p_sNormalBlendNormal2Sampler), ddx2, ddy2 );
    }
#endif

    outNormal = normalize( lerp( iBaseNormal, blendNormal, abs(blendFactor) ) );

    return outNormal;
}

#endif  // PIXEL_SHADER

#endif  // PS_MATERIAL
