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
sampler2D   p_sShadowMap;                               // Shadow map.
sampler2D	p_sRotationTexture;							// Soft shadow rotation texture.
sampler2D   p_sTransparentShadowDepthMap;               // Transparent shadow depth map.
sampler2D   p_sTransparentShadowColorMap;               // Transparent shadow color map.

float3      g_vShadowUV;                                // Shadow map UV.
half2		p_vRotationTextureUVScale;
half4		p_vSoftShadowTapOffsets[6];

half        p_fUseExplicitShadowCompare;

//--------------------------------------------------------------------------------------------------
// Shadow map UV coordinates.
float4 EmitPSShadowMapUV( VertexTransport vertOut ) {
    return mul( float4( INTERPOLANT_ViewPos, 1.0f ), p_mViewToShadowTransform );
}
    
//--------------------------------------------------------------------------------------------------
float SampleShadowMap( sampler2D shadowMap, float4 shadowMapUV ) {
    if ( b_iShadowMapMethod == SHADOWMAP_METHOD_NVIDIA ) {
		return tex2Dproj( shadowMap, shadowMapUV ).r;
		//return tex2D( shadowMap, shadowMapUV ).r;
    } else if ( b_iShadowMapMethod == SHADOWMAP_METHOD_ATI ) {
		// :TODO: Fetch 4?
		return tex2D( shadowMap, shadowMapUV.xy ).r > shadowMapUV.z;   
	} else return 0;
    //return tex2D( shadowMap, shadowMapUV ).r > ( shadowMapUV.z * p_fUseExplicitShadowCompare );     // 0 for Nvidia, 1 for ATI
}

//--------------------------------------------------------------------------------------------------
half4 ShadowIntensity(	VertexTransport vertOut, float4 shadowMapUV, float2 softShadowUV, half2 vHeightMapUV, sampler2D sHeightMap ) {
	// Soft shadow samples.
	
    // Compute shadow intensity.
    half4 cShadowColor;
	if ( b_useShadows ) {
        if ( b_iShadowMapMethod == SHADOWMAP_METHOD_ATI || b_iUseSoftShadows ) {
			shadowMapUV = shadowMapUV / shadowMapUV.w;
		}
		
		if ( b_iUseSoftShadows ) {
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

                //return half4( saturate( ddist_duv.x ), saturate( ddist_duv.y ), 0.0f, 1.0f );
            }

			// Grab random rotation vector.
			float3 rotation;
			rotation.xy     = normalize( tex2D( p_sRotationTexture, softShadowUV  ).ra );
            rotation.z      = -rotation.y;

			// Do 2 taps at a time.
			for ( int i = 0; i < b_iSoftShadowTaps / 2; i++ ) {
				// Rotate 2 kernel samples.
				float4 rotOffset = rotation.xzxz * p_vSoftShadowTapOffsets[i].xxzz + rotation.yxyx * p_vSoftShadowTapOffsets[i].yyww;
				
				float4 sampleUV = shadowMapUV;
                if ( b_iBiasAdjustment )
    				sampleUV.z += ddist_duv.x * rotOffset.x + ddist_duv.y * rotOffset.y;
				
				// Sample shadow map at 2 offset positions.
				// Use a mad to trick the compiler.
				cShadowColor += SampleShadowMap( p_sShadowMap, sampleUV + rotOffset.xyxx * float4( 1.0f, 1.0f, 0.0f, 0.0f ) );

				sampleUV = shadowMapUV;
                if ( b_iBiasAdjustment )
				    sampleUV.z += ddist_duv.x * rotOffset.z + ddist_duv.y * rotOffset.w;

				cShadowColor += SampleShadowMap( p_sShadowMap, sampleUV + rotOffset.zwxx * float4( 1.0f, 1.0f, 0.0f, 0.0f ) );
			}			
						
			// Average out.
			if ( b_iSoftShadowTaps > 0 )
				cShadowColor = cShadowColor / b_iSoftShadowTaps;
		} else {
			cShadowColor = SampleShadowMap( p_sShadowMap, shadowMapUV );
		}

        if ( b_useTransparentShadows ) {
            half fTransparentOcclusion = SampleShadowMap( p_sTransparentShadowDepthMap, shadowMapUV );
            if ( fTransparentOcclusion < 1.0f )
				cShadowColor.rgb = cShadowColor.rgb * tex2D( p_sTransparentShadowColorMap, shadowMapUV.xy ).rgb;
        }

        /*
        if ( b_useParallaxMapping )
        {
            // :TODO: FIXME
            //cShadowColor = min( cShadowColor, ComputeParallaxOcclusion( vHeightMapUV, shadowLightDirectionTS, sHeightMap ) );

            cShadowColor *= g_fParallaxShadow;

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