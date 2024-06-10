//==================================================================================================
//
// Copyright Blizzard Entertainment 2003-2006
//
// Deferred (point) light shader.
//==================================================================================================

#include "ShaderSystem.fx"

#ifdef VERTEX_SHADER

struct Input {
    float4  vPosition       : POSITION_;
};

#include "MaterialDefines.fx"
#include "VSCommon.fx"
#include "VSUtils.fx"
#include "VSShadow.fx"

float3x4    p_mWVTransform;                 // World-View transform.
float3x4    p_mWorldTransform;              // World transform.
float4x4    p_mWVPTransform;                // World-View-Projection transform.

//--------------------------------------------------------------------------------------------------
// Main vertex shader body.
//--------------------------------------------------------------------------------------------------
VertexTransport DeferredLightVertexMain( Input vertIn ) {
    VertexTransport vertOut;
    InitShader( vertOut );
    vertOut.HPos				= mul( vertIn.vPosition, p_mWVPTransform );
    INTERPOLANT_BackBufferUV    = GetBackBufferUV( vertOut.HPos, b_useViewport );
    INTERPOLANT_HPosAsUV        = vertOut.HPos;
#ifdef COMPILING_SHADER_FOR_OPENGL
    vertOut.HPos.y *= -1.0;
    vertOut.HPos.z = 2.0 * (vertOut.HPos.z - (0.5 * vertOut.HPos.w));
#endif
    return vertOut;
}

#endif  // VERTEX_SHADER

#ifdef PIXEL_SHADER

#include "LightTypes.fx"
#include "PSUtils.fx"
#include "PSCommon.fx"
#include "PSDebugModes.fx"
#include "PSShadow.fx"

sampler2D   p_sDiffuseMap;
sampler2D	p_sSpecularMap;
float4      p_vPositionRecipRadius;
HALF4       p_cColorAttenMultiplier;
HALF3		p_vDirection;
HALF3		p_vFalloffBiasScaleAndHotSpotMultiplier;
float4		p_vUVToViewPos;
float       p_fShadowMapSize;
float4x4    p_mPTransform;                // Projection transform.

#define LIGHT_DEBUG_NONE            0
#define LIGHT_DEBUG_COLORS          1
#define LIGHT_DEBUG_SINGLE_LIGHT    2

//--------------------------------------------------------------------------------------------------
// Main pixel shader body.
//--------------------------------------------------------------------------------------------------
half4 DeferredLightPixelMain( in VertexTransport vertOut ) : COLOR {
    InitShader( vertOut );

	float2 vOffsetUV;
    float2 vUV;
    float4 vViewPos;

    if ( b_useVSBackBufferUV ) {
        vUV = INTERPOLANT_BackBufferUV;
		vOffsetUV = vUV + p_vRecipRenderTargetSizeOffset.zw;							// Offset it so it samples exact pixels.
		vViewPos.xz = vUV.xy * p_vUVToViewPos.xy + p_vUVToViewPos.zw;		            // View vector	
    } else  {
        if ( VPOS_SEMANTIC ) {
			// Optimized version.
            // Offset it so it samples exact pixels. Map to [0..1] with 1/2 pixel offset
			vOffsetUV = INTERPOLANT_HPosAsUV * p_vRecipRenderTargetSizeOffset.xy + p_vRecipRenderTargetSizeOffset.zw;	

		    // Equation is INTERPOLANT_HPosAsUV * half2( 2.0f, -2.0f ) * 0.5 * p_vCameraNearSize * p_vRecipRenderTargetSize     Map to [0..CamWidth]
            // + half2( -1.0f, 1.0f ) ) * 0.5 * p_vCameraNearSize                                                               Map to [-CamWidth/2..CamWidth/2]
		    vViewPos.xz = INTERPOLANT_HPosAsUV.xy * p_vUVToViewPos.xy + p_vUVToViewPos.zw;			
        } else {
			vUV = GetBackBufferUV( vertOut, b_useViewport, false );
			vOffsetUV = vUV + p_vRecipRenderTargetSizeOffset.zw;					// Offset it so it samples exact pixels.
		    // Equation is vUV * half2( 2.0f, -2.0f ) + half2( -1.0f, 1.0f ) ) * 0.5 * p_vCameraNearSize
		    vViewPos.xz = vUV.xy * p_vUVToViewPos.xy + p_vUVToViewPos.zw;			
        }
	}
	
    float4 vNormalDepth = SampleNormalDepth( p_sNormalDepthMap, vOffsetUV );
    half4 cDiffuse      = tex2D( p_sDiffuseMap, vOffsetUV );
    half4 cSpecular;
    if ( b_useDeffSpecularPower ) {
		cSpecular = tex2D( p_sSpecularMap, vOffsetUV );
        if ( b_iUse8BitHDR )
            cSpecular.a *= 100.0f;
    } else {
		cSpecular.rgb = tex2D( p_sSpecularMap, vOffsetUV ).rgb;
		cSpecular.a = p_vSpecColorSpecularity.a;
	}

    PIXEL_NORMAL = normalize( PIXEL_NORMAL );	// :TODO: Toggle this out. Ony needed for terrain.
    
    vViewPos.yw = half2( PIXEL_DEPTH, 1.0f );
    vViewPos.xz = vViewPos.xz * ( PIXEL_DEPTH * p_mPTransform[1][3] + p_mPTransform[3][3] );

    /*
    vViewPos.y = 0.0f;
    if ( abs( vViewPos.x ) < 0.001f || abs( vViewPos.z ) < 0.001f )
        return half4( 1.0f, 1.0f, 1.0f, 1.0f );
    return half4( frac( vViewPos.xyz ), 1.0f );
    */

    // :TODO: Work in view space, not world space.
    // Back to world space
    float3 vPos = mul( p_mInvViewTransform, vViewPos ).xyz;

    half3 lightDiffSpecIntensity;
    if ( b_iLightType == LIGHTTYPE_POINT ) {
		ComputePointLight(	vertOut, PIXEL_NORMAL, vPos, p_vPositionRecipRadius.xyz, p_vPositionRecipRadius.w, p_cColorAttenMultiplier.w, 
							USE_SPECULAR, cSpecular.w, lightDiffSpecIntensity );
	} else if ( b_iLightType == LIGHTTYPE_SPOT ) {
		ComputeSpotLight(	vertOut, PIXEL_NORMAL, vPos, p_vPositionRecipRadius.xyz, p_vDirection, p_vPositionRecipRadius.w, p_cColorAttenMultiplier.w, 
							p_vFalloffBiasScaleAndHotSpotMultiplier.x, p_vFalloffBiasScaleAndHotSpotMultiplier.y, 
                            p_vFalloffBiasScaleAndHotSpotMultiplier.z, 
							USE_SPECULAR, cSpecular.w, lightDiffSpecIntensity );	
	}

	// :TODO: Deferred parallax mapping
    float4 vShadowMapUV = mul( float4( vPos, 1 ), p_mShadowTransform );  

	// Since spot light shadows have a fixed viewpoint, just use the shadow map UV for the shadow map noise.
    half4 cShadowColor = ShadowIntensity( vertOut, vShadowMapUV, vShadowMapUV.xy * p_fShadowMapSize / 32.0f, half2( 0.0f, 0.0f ), p_sShadowMap );

	if ( b_iAffectedByAO )
		cShadowColor *= cDiffuse.a;
		
    if ( b_iDebugMode == LIGHTING_ONLY ) {
        cDiffuse = 1.0f;
		cSpecular = 1.0f;
    } else if ( b_iDebugMode == DIFFUSE_LIGHTING_ONLY ) {
		cDiffuse = 1.0f;
		cSpecular = 0.0f;
    } else if ( b_iDebugMode == SPECULAR_LIGHTING_ONLY ) {
		cDiffuse = 0.0f;
		cSpecular = 1.0f;
    } else if ( b_iDebugMode == DIFFUSE_ONLY )
		cSpecular = 0.0f;
    else if ( b_iDebugMode == SPECULAR_ONLY )
		cDiffuse = 0.0f;
    else if ( b_iDebugMode == SHADOWS_ONLY )
		return half4( cShadowColor.rgb, 1.0f );
	else if ( b_iDebugMode == LIGHTING_OVERLAP )
		return 1.0f / 8.0f;
	else if ( b_iDebugMode == OVERDRAW )
        return 0;
    else if ( b_iDebugMode != NO_DEBUG )
        return 0.0f;

#ifdef COMPILING_SHADER_FOR_OPENGL
    if ( b_iLightDebugMode == LIGHT_DEBUG_COLORS ) {
        half3 zero3 = half3(0.0f, 0.0f, 0.0f);
        bool3 spec3 = (cSpecular.rgb * p_vSpecColorSpecularity.rgb * lightDiffSpecIntensity.y) != zero3;
        bool spectest = spec3.x && spec3.y && spec3.z;
        bool3 diff3 = (cDiffuse.rgb * p_cColorAttenMultiplier.xyz * lightDiffSpecIntensity.x) == zero3;
        bool difftest = diff3.x && diff3.y && diff3.z;
        if (    b_iUseSpecular &&
                lightDiffSpecIntensity.y >= 0.02f &&
                spectest ) {
            if ( cShadowColor.a > 0.0f )
                return half4( 0.0f, 0.0f, 1.0f, 1.0f );     // Blue = specular highlight
            else return half4( 1.0f, 0.0f, 0.0f, 1.0f );    // Dark blue = shadowed specular
        } else if ( lightDiffSpecIntensity.x <= 0.02f ||
                    difftest )
            return half4( 1.0f, 0.0f, 0.0f, 1.0f ); // Red = <= 1% contribution sample
        else if ( cShadowColor.a == 0.0f )
            return half4( 1.0f, 0.0f, 0.0f, 1.0f ); // Dark green = shadowed light pixel
        else
            return half4( 0.0f, 1.0f, 0.0f, 1.0f );     // Green = lit pixel 
    }
#else
    if ( b_iLightDebugMode == LIGHT_DEBUG_COLORS ) {
        if (    b_iUseSpecular &&
                lightDiffSpecIntensity.y >= 0.02f 
                //&& ( cSpecular.rgb * p_vSpecColorSpecularity.rgb * lightDiffSpecIntensity.y ) != half3( 0.0f, 0.0f, 0.0f ) 
                ) {
            if ( cShadowColor.a > 0.0f )
                return half4( 0.0f, 0.0f, 1.0f, 1.0f );     // Blue = specular highlight
            else return half4( 0.5f, 0.0f, 0.0f, 1.0f );    // Dark red = shadowed specular
        } else if ( lightDiffSpecIntensity.x <= 0.02f ) 
            //|| ( cDiffuse.rgb * p_cColorAttenMultiplier.xyz * lightDiffSpecIntensity.x ) == half3( 0.0f, 0.0f, 0.0f ) )
            return half4( 1.0f, 0.0f, 0.0f, 1.0f );         // Red = <= 1% contribution sample
        else if ( cShadowColor.a == 0.0f )
            return half4( 0.5f, 0.0f, 0.0f, 1.0f );         // Dark red = shadowed light pixel
        else if ( cShadowColor.a < 1.0f ) 
            return half4( 0.0f, 0.5f, 0.0f, 1.0f );         // Dark Green = partially lit pixel
        else return half4( 0.0f, 1.0f, 0.0f, 1.0f );        // Green = lit pixel
    }
#endif

    half4 result;
    result.rgb = cDiffuse * p_cColorAttenMultiplier.xyz * lightDiffSpecIntensity.x * cShadowColor.rgb;
    if ( b_iUseSpecular )
		result.rgb += cSpecular.rgb * p_vSpecColorSpecularity.rgb * lightDiffSpecIntensity.y * cShadowColor.rgb;
    result.a = 1.0f;
    if ( b_iUse8BitHDR )
        result.rgb *= 0.5f;

    return result;
}

#endif  // PIXEL_SHADER