//==================================================================================================
//
// Copyright Blizzard Entertainment 2003-2005
//
// This is the shader code for shadows.
//==================================================================================================

#ifndef PS_SHADOW
#define PS_SHADOW

#ifdef PIXEL_SHADER

#include "ShaderSystem.fx"
#include "PSUtils.fx"
#include "PSParallax.fx"

#define SHADOWMAP_METHOD_NVIDIA	0
#define SHADOWMAP_METHOD_ATI	1

//==================================================================================================
// Uniform parameters.
float4x4	p_mViewToShadowTransform;					// Transform to generate shadow map uv from within PS (when out of interpolant slots).
float		p_fShadowOffset;							// Shadow z-bias.
texDeclShadow(p_sShadowMap);                            // Shadow map.
texDecl2D(p_sRotationTexture);							// Soft shadow rotation texture.
texDeclShadow(p_sTransparentShadowDepthMap);            // Transparent shadow depth map.
texDecl2D(p_sTransparentShadowColorMap);                // Transparent shadow color map.

HALF2		p_vRotationTextureUVScale;
HALF4		p_vSoftShadowTapOffsets[6];

HALF2        p_fUseNativeShadowMapping;

//--------------------------------------------------------------------------------------------------
// Shadow map UV coordinates.
float4 EmitPSShadowMapUV( VertexTransportRaw vertOut ) {
    return mul( float4( INTERPOLANT_ViewPos, 1.0f ), p_mViewToShadowTransform );
}
    
//--------------------------------------------------------------------------------------------------
float SampleShadowMap( typeSamplerShadow shadowMapSampler, typeTexture2D shadowMapTex, float4 shadowMapUV ) {
    float value;
    if ( b_iUseExplicitShadowTest )
        value = sampleTexShadow( shadowMapTex, shadowMapSampler, shadowMapUV ).x > shadowMapUV.z;
    else value = sampleTexShadow( shadowMapTex, shadowMapSampler, shadowMapUV ).x;
    return value;
    //return value * p_fUseNativeShadowMapping.x + ( value > shadowMapUV.z ) * p_fUseNativeShadowMapping.y;
}

//--------------------------------------------------------------------------------------------------
HALF4 ShadowIntensity(	VertexTransport vertOut, float4 shadowMapUV, float2 softShadowUV, HALF2 vHeightMapUV, typeSampler2D sHeightMap, typeTexture2D tHeightMap ) {
    // Soft shadow samples.
    
    // Compute shadow intensity.
    HALF4 cShadowColor;
    if ( b_useShadows ) {
        if ( b_iUseSoftShadows ) {
            shadowMapUV = shadowMapUV / shadowMapUV.w;
            cShadowColor = 0;
            
            float4 duvdist_dx;
            float4 duvdist_dy;
            float invDet;
            float2 ddist_duv;;
            if ( b_iBiasAdjustment ) {
                duvdist_dx = ddx( shadowMapUV );
                duvdist_dy = ddy( shadowMapUV );
                float temp = ( duvdist_dx.x * duvdist_dy.y ) - ( duvdist_dx.y * duvdist_dy.x );
                if ( temp != 0.0f ) {
                    invDet = 1.0f / ( ( duvdist_dx.x * duvdist_dy.y ) - ( duvdist_dx.y * duvdist_dy.x ) );
                    ddist_duv.x = duvdist_dy.y * duvdist_dx.z - duvdist_dx.y * duvdist_dy.z;
                    ddist_duv.y = duvdist_dx.x * duvdist_dy.z - duvdist_dy.x * duvdist_dx.z;
                    ddist_duv *= invDet; 
                } else ddist_duv = 0.0f;

                //return HALF4( saturate( ddist_duv.x ), saturate( ddist_duv.y ), 0.0f, 1.0f );
            }

			// Grab random rotation vector.
			float3 rotation;
			rotation.xy     = normalize( sample2D( p_sRotationTexture, softShadowUV  ).ra );
            rotation.z      = -rotation.y;

            // Do 2 taps at a time.
#if COMPILING_SHADER_WITH_BSL
            [unroll]
#endif
            for ( int i = 0; i < b_iSoftShadowTaps / 2; i++ ) {
                // Rotate 2 kernel samples.
                float4 rotOffset = rotation.xzxz * p_vSoftShadowTapOffsets[i].xxzz + rotation.yxyx * p_vSoftShadowTapOffsets[i].yyww;
                
                float4 sampleUV = shadowMapUV;
                if ( b_iBiasAdjustment )
    				sampleUV.z += ddist_duv.x * rotOffset.x + ddist_duv.y * rotOffset.y;
				
				// Sample shadow map at 2 offset positions.
				// Use a mad to trick the compiler.
				cShadowColor += SampleShadowMap( texSampler(p_sShadowMap), texTexture(p_sShadowMap), sampleUV + rotOffset.xyxx * float4( 1.0f, 1.0f, 0.0f, 0.0f ) );

                sampleUV = shadowMapUV;
                if ( b_iBiasAdjustment )
                    sampleUV.z += ddist_duv.x * rotOffset.z + ddist_duv.y * rotOffset.w;

				cShadowColor += SampleShadowMap( texSampler(p_sShadowMap), texTexture(p_sShadowMap), sampleUV + rotOffset.zwxx * float4( 1.0f, 1.0f, 0.0f, 0.0f ) );
			}			
						
			// Average out.
			if ( b_iSoftShadowTaps > 0 )
				cShadowColor = cShadowColor / b_iSoftShadowTaps;
		} else {
			shadowMapUV = shadowMapUV / shadowMapUV.w;
			cShadowColor = SampleShadowMap( texSampler(p_sShadowMap), texTexture(p_sShadowMap), shadowMapUV );
		}

        if ( b_useTransparentShadows ) {
            HALF fTransparentOcclusion = SampleShadowMap( texSampler(p_sTransparentShadowDepthMap), texTexture(p_sTransparentShadowDepthMap), shadowMapUV );
            if ( fTransparentOcclusion < 1.0f )
				cShadowColor.rgb = cShadowColor.rgb * sample2D( p_sTransparentShadowColorMap, shadowMapUV.xy ).rgb;
        }

        /*
        if ( b_useParallaxMapping )
        {
            // :TODO: FIXME
            //cShadowColor = min( cShadowColor, ComputeParallaxOcclusion( vHeightMapUV, shadowLightDirectionTS, sHeightMap ) );

            //float3x3 mWorld2Tangent;
            //mWorld2Tangent[0] = INTERPOLANT_Tangent.xyz;
            //mWorld2Tangent[1] = INTERPOLANT_Binormal.xyz;
            //mWorld2Tangent[2] = INTERPOLANT_Normal.xyz;

            //float3 vLightDirTS = normalize(mul(mWorld2Tangent, p_directionalLights[0].vDirection.xyz));
            //vLightDirTS.y = -vLightDirTS.y;

            //cShadowColor *= ComputeParallaxShadow(
            //                    vHeightMapUV, 
            //                    vLightDirTS, 
            //                    sHeightMap, 
            //                    b_DXNStyleNormalMaps
            //                );
        }
        */

    } else cShadowColor = 1;
    return cShadowColor;
}

#endif  // PIXEL_SHADER

#endif  // PS_SHADOW
