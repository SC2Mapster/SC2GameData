
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

//==================================================================================================
// Uniform parameters

// Colors
HALF            p_fEmissiveMultiplier;
HALF3           p_fMaterialTint;
HALF4           p_cMaterialFOWTint;

DECLARE_LAYER(Diffuse);
DECLARE_LAYER(Decal);
DECLARE_LAYER(Specular);
DECLARE_LAYER(Emissive);
DECLARE_LAYER(Emissive2);
DECLARE_LAYER(Envio);
DECLARE_LAYER(EnvioMask);
DECLARE_LAYER(AlphaMask);
DECLARE_LAYER(AlphaMask2);
DECLARE_LAYER(Normal);
DECLARE_LAYER(Heightmap);
DECLARE_LAYER(Lightmap);
DECLARE_LAYER(AmbientOcclusion);

sampler2D   p_sFOWSampler;
sampler2D   p_sDefferedDiffuse;

half3       p_cLightmapShadowColor;

//--------------------------------------------------------------------------------------------------
// Main material hook.
//--------------------------------------------------------------------------------------------------
half4 MaterialColor(    in VertexTransport vertOut, 
                        half3 vNormal,              // Input normal
                        half3 cLightDiffuse,        // Input lighting diffuse color
                        half3 cLightSpecular,       // Input lighting specular color
                        half4 cShadowColor,         // Shadowed or not
                        out half3 cDiffuse,
                        out half3 cSpecular,
						out half fSpecularPower )
{
    // Compute all material layers.
    cDiffuse                = 0;
    cSpecular				= 0;
	fSpecularPower			= p_vSpecColorSpecularity.w;
    half3   cEmissive       = 0;

	//----------------------------------------------------------------------------------------------
    // :TODO: Verify this.
    //if ( !b_useLighting && b_useEmissiveMultiplier )
    //    cLightDiffuse   = p_fEmissiveMultiplier;
    if ( b_iDebugMode == FULLBRIGHT_DIFFUSE_ONLY )
        cLightDiffuse = 1;

    SEnvMappings envMappings = ComputeEnvMappings( vertOut, vNormal );
    
    //----------------------------------------------------------------------------------------------
    // Team colored diffuse layer.
    half fTeamColorAlpha = 0;		// Sampled team color alpha.
    half3 vDiffuseUV = 0;
    if ( b_iDiffuseLayerEnable ) {
        SETUP_LAYER( Diffuse );
        if ( !DiffuseLayerConfig.b_iUseConstantColor )
            vDiffuseUV = GetUVEmitter(vertOut, DiffuseLayerConfig.b_iUVEmitter).xyz;
        half4 cColor = GetLayerColor( Diffuse, 1.0f, false );
        cDiffuse = CombineLayerColor( cColor, cDiffuse, DiffuseLayerConfig );
        fTeamColorAlpha = cColor.a;
    }

    //----------------------------------------------------------------------------------------------
    // Decal layer.
    if ( b_iDecalLayerEnable ) {
        SETUP_LAYER( Decal );
        half4 cColor = GetLayerColor( Decal, 1.0f, false );
        cDiffuse = CombineLayerColor( cColor, cDiffuse, DecalLayerConfig );
    }

    //----------------------------------------------------------------------------------------------
    // Specular layer.
    if ( b_iSpecularLayerEnable ) {
        SETUP_LAYER( Specular );
        //if ( b_iSpecularType == SPECULAR_A_ONLY )
        //    SpecularLayerConfig.b_iChannelSelect = CHANNELSELECT_A;
        half4 cColor = GetLayerColor( Specular, 1.0f, false );

        if ( b_iSpecularType == SPECULAR_A_ONLY ) {
			if ( b_iDiffuseTeamColorMode == TEAMCOLOR_DIFFUSE && b_useTeamColorSpecular ) {
				cColor = lerp( p_cDiffuseTeamColor.a, cColor.a, fTeamColorAlpha );
			}
        } else {
			if ( b_iDiffuseTeamColorMode == TEAMCOLOR_DIFFUSE && b_useTeamColorSpecular ) {
				//half fLayerLuminance = dot ( half3(0.27f, 0.67f, 0.06f), cColor.rgb );
				cColor = half4( lerp( p_cDiffuseTeamColor.rgb , cColor.rgb, fTeamColorAlpha ).rgb, 1.0f );
			}
        }

        cSpecular = CombineLayerColor( cColor, cSpecular, SpecularLayerConfig );
    }
    
    //----------------------------------------------------------------------------------------------
    // First emissive layer.
    if ( b_iEmissiveLayerEnable ) {
        SETUP_LAYER( Emissive );
        half4 cColor = GetLayerColor( Emissive, 1.0f, false );
        cEmissive = CombineLayerColor( cColor, cEmissive, EmissiveLayerConfig );
    }
    
    //----------------------------------------------------------------------------------------------
    // Second emissive layer.
    if ( b_iEmissive2LayerEnable ) {
        SETUP_LAYER( Emissive2 );
        half4 cColor = GetLayerColor( Emissive2, 1.0f, false );
        cEmissive = CombineLayerColor( cColor, cEmissive, Emissive2LayerConfig );
    }
    
    //----------------------------------------------------------------------------------------------
	// if ( b_useEmissiveMultiplier )
    if ( b_iEmissiveLayerEnable || b_iEmissive2LayerEnable )
        cEmissive = cEmissive * p_fEmissiveMultiplier;

	//----------------------------------------------------------------------------------------------
    // Special mode showing lit components only.
	if ( b_litOnly ) {
		cEmissive = 0;
		if ( !b_useLighting ) {
			cLightDiffuse = 0;
			cLightSpecular = 0;
		}
	}
	
	//----------------------------------------------------------------------------------------------
    // Color by lightmap.
    if ( b_iLightmapLayerEnable ) {
        SETUP_LAYER( Lightmap );
        half4 cColor = GetLayerColor( Lightmap, 1.0f, false ) * 2.0f;
		cLightDiffuse = cColor.rgb;
		cLightSpecular = 0;
        if ( b_iLightmapShadow ) {
            cLightDiffuse *= lerp( p_cLightmapShadowColor, 1.0f, cShadowColor.a );
        }
	}
	
    //----------------------------------------------------------------------------------------------
    // Blend the lighting components.
    half4   cFinal;
    cFinal.rgb = cEmissive.rgb + cDiffuse * cLightDiffuse;
    if ( b_useLighting && b_useSpecular )
        cFinal.rgb += cSpecular * cLightSpecular;
    else
        cLightSpecular = 0;

    //----------------------------------------------------------------------------------------------
    // Environment map layer.
    if ( !b_litOnly ) {
        if ( b_iEnvioLayerEnable ) {    
            SETUP_LAYER( Envio );

            half4 cColor = GetLayerColor( Envio, 1.0f, true );
            half fMaskValue;
            if ( b_iEnvioMaskLayerEnable ) {
                SETUP_LAYER( EnvioMask );
                fMaskValue = GetLayerColor( EnvioMask, 1.0f, true ).a * cColor.a;
            } else fMaskValue = cColor.a;

            if ( EnvioLayerConfig.b_iOp == LAYEROP_MOD )
                cFinal.rgb = cFinal.rgb * cColor.rgb * fMaskValue;
            else if ( EnvioLayerConfig.b_iOp == LAYEROP_ADD )
                cFinal.rgb = cFinal.rgb + cColor.rgb * fMaskValue;
            else if ( EnvioLayerConfig.b_iOp == LAYEROP_LERP )
                cFinal.rgb = lerp( cFinal.rgb, cColor.rgb, fMaskValue );
        }

        //----------------------------------------------------------------------------------------------
        // Tinting.
        if ( b_useVertexColors )
            cFinal.rgb *= saturate(INTERPOLANT_VertexColor.xyz);
        // :TODO: Optimize this.
        cFinal.rgb		*= p_fMaterialTint;
        cDiffuse.rgb	*= p_fMaterialTint;
    }

    //----------------------------------------------------------------------------------------------
    // Alpha.
    cFinal.a = 1.0f;
    if ( b_useVertexAlpha )
        cFinal.a *= saturate(INTERPOLANT_VertexColor.a);
    //if ( b_alphaEnable )
    cFinal.a *= p_vSpecularMultiplier_DepthBlendThreshold_HeightMapScale_AlphaFactor.w;
    if ( b_splatAttenuationEnabled && PIXEL_SHADER_VERSION >= SHADER_VERSION_PS_30 ) {
        cFinal.a *= SplatAttenuation( INTERPOLANT_VectorUI1.xyz, INTERPOLANT_VectorUI0, INTERPOLANT_VectorUI1.w, INTERPOLANT_Tangent.w);
    }

    //----------------------------------------------------------------------------------------------
    // First alpha mask layer.
    if ( b_iAlphaMaskLayerEnable ) {
        SETUP_LAYER( AlphaMask );
        cFinal.a *= GetLayerColor( AlphaMask, 1.0f, false ).a;
    }
    
    //----------------------------------------------------------------------------------------------
    // Second alpha mask layer.
    if ( b_iAlphaMask2LayerEnable ) {
        SETUP_LAYER( AlphaMask2 );
        cFinal.a *= ( GetLayerColor( AlphaMask2, 1.0f, false ).a + 0.00000001f);  // Epsilon is to go around wacky shader compiler bug.
    }

    //----------------------------------------------------------------------------------------------
    // Soft blend.
    if ( PIXEL_SHADER_VERSION >= SHADER_VERSION_PS_30 && b_useDepthBlend ) {
        // a.k.a. soft particles.
        float4 vNormalDepth = SampleNormalDepth( p_sNormalDepthMap, GetBackBufferUV( vertOut, true, true ) );
        float fDistToSampledDepth = max( 0, PIXEL_DEPTH - INTERPOLANT_ViewPos.y );
        if ( fDistToSampledDepth < p_vSpecularMultiplier_DepthBlendThreshold_HeightMapScale_AlphaFactor.y ) {
            cFinal.a *= ( fDistToSampledDepth / p_vSpecularMultiplier_DepthBlendThreshold_HeightMapScale_AlphaFactor.y );
        }
    }

    if ( b_iModAlpha )
        cFinal.rgb *= cFinal.a;

	// Tricky: The specular multiplier for both material and HDR setting are actually pre-multiplied CPU side on
	// the light's specular multiplier so we don't use the multiplier for lighting since it's already baked in. 
	// For the deferred specular output however, we need to multiply the material specular multiplier manually here.    
	cSpecular *= p_vSpecularMultiplier_DepthBlendThreshold_HeightMapScale_AlphaFactor.x;
    
    //==============================================================================================
    // DEBUG MODES
    if ( b_iDebugMode != NO_DEBUG ) {
        half fExtraValue = 0;
        half3 vMapNormal;
        if ( b_useNormalMapping )
            vMapNormal = DecodeTextureNormal( p_sNormalSampler, GetUVEmitter(vertOut, b_iNormalUVEmitter), fExtraValue );
        else vMapNormal = 0;

        return DebugColor(  cDiffuse, cSpecular, cEmissive, vMapNormal, vNormal, 
                            cLightDiffuse, cLightSpecular, cShadowColor, g_cDeferredAO, 
                            cFinal.a, vDiffuseUV, 1.0f, vertOut, 
                            cFinal );
    }
    
    if ( b_iClampOutput ) {
        cFinal = saturate( cFinal ); 
    }

    return cFinal;
}

//--------------------------------------------------------------------------------------------------
half3 DecodeNormal( VertexTransport vertOut ) {
	// Decode normal.
    half3 vNormalWS;
    half fExtraValue = 0;
    if ( b_useNormalMapping && b_iNormalLayerEnable  ) {
		// Pixel-based.
        half3   vNormalTS = DecodeTextureNormal( p_sNormalSampler, GetUVEmitter(vertOut, b_iNormalUVEmitter), fExtraValue );
				vNormalWS = TangentToWorld( vNormalTS, INTERPOLANT_Normal.xyz, INTERPOLANT_Tangent.xyz, INTERPOLANT_Binormal, true );
    } else 
		// Vertex-based.
		vNormalWS = normalize( INTERPOLANT_Normal.xyz );		
    return vNormalWS;
}

//--------------------------------------------------------------------------------------------------
half DecodeAOValue( VertexTransport vertOut ) {
    half fAmbientOcclusion;
    if ( b_iAmbientOcclusionLayerEnable ) {
        SEnvMappings envMappings;
		SETUP_LAYER( AmbientOcclusion );
		fAmbientOcclusion = GetLayerColor( AmbientOcclusion, 1.0f, false ).a;
        g_cDeferredAO = fAmbientOcclusion;
    } else fAmbientOcclusion = 1.0f;

    if ( b_iUseDynamicAO ) {
        return tex2D( p_sDefferedDiffuse, GetBackBufferUV( vertOut, true, true ) ).a;
    }
    return fAmbientOcclusion;
}

//--------------------------------------------------------------------------------------------------
half2 DecodeSoftShadowUV( VertexTransport vertOut ) {
    // Use the first UV as the soft shadow noise interpolant so it doesn't swim around.
    half2 softShadowUV;
    if ( b_useShadows && b_iUseSoftShadows ) {
		if ( b_iUVEmitterCount > 0 ) {
			softShadowUV = INTERPOLANT_UV[0].xy * 256.0f;	
		} else {
			// If there are no UV emitters use the screen-based UV generation.
            #if ( VPOS_SEMANTIC )
				softShadowUV = INTERPOLANT_HPosAsUV.xy / p_vRotationTextureUVScale;
            #else
				softShadowUV = ( float4( INTERPOLANT_HPosAsUV / INTERPOLANT_HPosAsUV.w ).xy ) * p_vRotationTextureUVScale;
            #endif
		}
	} else softShadowUV = 0;
    return softShadowUV;
}

//--------------------------------------------------------------------------------------------------
half4 ApplyFogOfWar( VertexTransport vertOut, half4 cResult, inout half3 cDeferredDiffuse ) {
    half4 cFOWFactor;
    if ( b_FOWEnabled ) {
        if ( b_emitFinalColor ) {
            if ( b_SampleFOW ) {
                float2 FOWUV = Ndc2Tex(INTERPOLANT_FOWUV.xy, true );
                cFOWFactor = tex2D(p_sFOWSampler, FOWUV);
            }
            else {
                cFOWFactor = p_cMaterialFOWTint;
            }

            half4 cDiffuseFOWFactor = cFOWFactor;

            //float fowAlpha = 1.0f - cFOWFactor.a;
            //fowAlpha = saturate( pow( fowAlpha, 8.0f ) );
            if (b_FOWAdditiveScale) {
                cDeferredDiffuse = lerp(cDeferredDiffuse.rgb, cDeferredDiffuse.rgb * cDiffuseFOWFactor.rgb, cDiffuseFOWFactor.a);
                return half4( lerp(cResult.rgb, cResult.rgb * cFOWFactor.rgb, cFOWFactor.a), /* fowAlpha * */ cResult.a);
            }
            else {
                cDeferredDiffuse = lerp(cDeferredDiffuse.rgb, cDiffuseFOWFactor.rgb, cDiffuseFOWFactor.a);
                return half4( lerp(cResult.rgb, cFOWFactor.rgb, cFOWFactor.a), /* fowAlpha * */ cResult.a);
            }
        } else {
            return cResult;
        }
    } else return cResult;
}

#endif  // PIXEL_SHADER

#endif  // PS_MATERIAL