//==================================================================================================
//
// Copyright Blizzard Entertainment 2003-2005
//
// Splat shader.
//==================================================================================================

#include "ShaderSystem.fx"

//--------------------------------------------------------------------------------------------------
// Vertex Shader
//--------------------------------------------------------------------------------------------------
#ifdef VERTEX_SHADER

#include "VSModelVertexFormat.fx"
#include "VSCommon.fx"
#include "VSEmitters.fx"
#include "VSParallax.fx"
#include "VSLighting.fx"
#include "VSFog.fx"
#include "VSUtils.fx"
#include "MaterialDefines.fx"
#include "VSUVMapping.fx"

float4x4    p_mWorldTransform;
float       p_fSplatAlphaMultiplier;                // alpha multiplier for the splats
HALF4       p_cVectorUIColor;
float4      p_vVectorUIInterpolant0;
float4      p_vVectorUIInterpolant1;                // x == inner radius, y == outer radius, z == falloff, w == 1/falloff
float4      p_vVectorUIInterpolant2;                // x == segment count, y == percent solid, (z,w) == rotation axis
float4      p_vSplatAttenuationPlane;               // attenuation plane for splat
float2      p_fSplatAttenuationScalar_MinHeight;    // attenuation scalar for splats
float4      p_vTangent;

struct SplatVertIn {
    float4  vPosition   : POSITION_;
    HALF4   vNormal     : NORMAL_;
};

//--------------------------------------------------------------------------------------------------
HALF4 EmitSplatVertexColor () {
    if (b_iShadingMode == SHADINGMODE_VECTORUI)
        return p_cVectorUIColor;
    else
        return HALF4(1, 1, 1, p_fSplatAlphaMultiplier);
}

//--------------------------------------------------------------------------------------------------
void SplatDeferredVertexMain(in SplatVertIn vertIn, out VertexTransport vertOut) {
    int b_iUVMapping[8];
    int b_UVRandomOffsetEnable[8];
    InitShader( vertOut, b_iUVMapping, b_UVRandomOffsetEnable );

    HALF3 cVertexSpecularLighting;
    HALF3 cVertexShadowSpecularLighting;
    HALF3 cVertexShadowSpecularLighting2;

    HALF3 vLocalPosition = vertIn.vPosition;    // Preserve the local position (for possible uv mappings based on local vertex position).
    HALF4 vLocalNormal   = vertIn.vNormal;

    vertIn.vPosition = mul(vertIn.vPosition, p_mWorldTransform);
    vertOut.HPos = mul(vertIn.vPosition, p_mVPTransform);

    WRITE_INTERPOLANT_HPosAsUV                (mul(vertIn.vPosition, p_mVPTransform));
    WRITE_INTERPOLANT_WorldPos                (float4(vertIn.vPosition.xyz, 1.0f));   
    WRITE_INTERPOLANT_ViewPos                 (mul(p_mViewTransform, vertIn.vPosition).xyz);
    WRITE_INTERPOLANT_Normal                  (vertIn.vNormal);
    WRITE_INTERPOLANT_Tangent                 (p_vTangent);

    // We may be using vertex alpha for something else, so just recalculate the 4th region
    HALF4 vLightingRegions = HALF4(0, 0, 0, 0);
    HasColor_(vLightingRegions = vertIn.cColor; vLightingRegions.a = 1.0 - (vLightingRegions.r + vLightingRegions.g + vLightingRegions.b));

    WRITE_INTERPOLANT_Diffuse                 (EmitDiffuse(vertIn.vPosition.xyz, vertIn.vNormal, vLightingRegions, cVertexSpecularLighting, cVertexShadowSpecularLighting, cVertexShadowSpecularLighting2));
    WRITE_INTERPOLANT_Specular                (EmitSpecular(cVertexSpecularLighting));
    WRITE_INTERPOLANT_ShadowDiffuse           (EmitShadowDiffuse(vertIn.vNormal, cVertexShadowSpecularLighting, cVertexShadowSpecularLighting2));
    WRITE_INTERPOLANT_ShadowSpecular          (EmitShadowSpecular(cVertexShadowSpecularLighting) );
    WRITE_INTERPOLANT_FogColor                (EmitFogColor(vertIn.vPosition.xyz));
    WRITE_INTERPOLANT_EyeToVertex             (normalize(vertIn.vPosition.xyz - p_vEyePos));
    WRITE_INTERPOLANT_EyeToVertexFresnel      (normalize(vertIn.vPosition.xyz - p_vEyePos));
    WRITE_INTERPOLANT_FOWUV                   (mul(vertIn.vPosition, p_mFOWMatrix) );
    WRITE_INTERPOLANT_VertexColor             (EmitSplatVertexColor());

    //if (b_usePackedUVEmitter) {
    //    for (int i = 0; i < b_iUVEmitterCount / 2; i++) {
    //        GenInterpolantUV(i, 
    //                         HALF4(EmitSplatUV(vertIn, i * 2, vLocalPosition, vLocalNormal, 0, b_iUVMapping).xy, 
    //                               EmitSplatUV(vertIn, (i * 2) + 1, vLocalPosition, vLocalNormal, 0, b_iUVMapping).xy));
    //    }
    //    if (b_iUVEmitterCount % 2)
    //        GenInterpolantUV(b_iUVEmitterCount / 2, 
    //                         EmitSplatUV(vertIn, b_iUVEmitterCount-1, vLocalPosition, vLocalNormal, 0, b_iUVMapping));
    //}
    //else
    //{
    //    for (int i = 0; i < b_iUVEmitterCount; i++) {
    //        GenInterpolantUV(i, EmitSplatUV(vertIn, i, vLocalPosition, vLocalNormal, 0, b_iUVMapping));
    //    }
    //}

    for (int uvIndex = 0; uvIndex < b_iUVEmitterCount; ++uvIndex)
        WRITE_INTERPOLANT_SWIZZLE_UV(uvIndex, xy, float2(vLocalPosition.x + 0.5f, -vLocalPosition.y + 0.5f));

    if (b_iShadingMode == SHADINGMODE_VECTORUI) {
        WRITE_INTERPOLANT_VectorUI0(p_vVectorUIInterpolant0);
        WRITE_INTERPOLANT_VectorUI1(p_vVectorUIInterpolant1);
        WRITE_INTERPOLANT_VectorUI2(p_vVectorUIInterpolant2);
        
        // attenuation params
        WRITE_INTERPOLANT_Vector4(p_vSplatAttenuationPlane);
        WRITE_INTERPOLANT_SWIZZLE_VectorUI0(w, p_fSplatAttenuationScalar_MinHeight.x);
    }
    else {
        // attenuation params
        WRITE_INTERPOLANT_VectorUI0(p_vSplatAttenuationPlane);
        WRITE_INTERPOLANT_SWIZZLE_VectorUI1(xyz, float4(vertIn.vPosition.xyz, 1.0f));
        WRITE_INTERPOLANT_SWIZZLE_VectorUI1(w, p_fSplatAttenuationScalar_MinHeight.x);
        WRITE_INTERPOLANT_SWIZZLE_Tangent(w, p_fSplatAttenuationScalar_MinHeight.y);
    }
        
    // parallax vector
    float3 binormal = normalize(cross(p_vTangent.xyz, vertIn.vNormal.xyz));
    float3 tangent = cross(vertIn.vNormal.xyz, binormal);
    WRITE_INTERPOLANT_ParallaxVector(EmitParallaxVector(vertIn.vPosition.xyz, 
                                                        p_vEyePos, 
                                                        vertIn.vNormal.xyz, 
                                                        tangent,
                                                        binormal));

#ifdef COMPILING_SHADER_FOR_OPENGL
    vertOut.HPos.y *= -1.0;
    vertOut.HPos.z = 2.0 * (vertOut.HPos.z - (0.5 * vertOut.HPos.w));
#endif    
}

#endif // VERTEXSHADER

//--------------------------------------------------------------------------------------------------
// Pixel Shader
//--------------------------------------------------------------------------------------------------
#ifdef PIXEL_SHADER

#include "PSCommon.fx"
#include "PSMainShading.fx"

texDecl2D(p_sDepthMap);
float4x4 p_mWorldInvTransform;
float4x4 p_mViewInvTransform44;
float4x4 p_mProjectionInv;
float2   p_vProjectionXZInv;
float2   p_vResolutionRcp;
float4   p_vViewOffsetMul;   
float4   p_vTangent;

static const float c_fEpsilon = 0.001f;

//--------------------------------------------------------------------------------------------------
float SampleDepth (float2 depthUV) {
    float4 sampledDepth = sample2D(p_sDepthMap, depthUV);

    float depth = 0.0f;
    if (b_iUseHardwareDepth) {
        // hardware depth can be used directly
        depth = sampledDepth.x;
    }
    else {
        // view depth must be decoded
        depth = DecodeDepth(sampledDepth);
    }

    return depth;
}

//--------------------------------------------------------------------------------------------------
float4 ReconstructViewPos (float depth, float2 depthUV) {
    float2 projectedXYPos = float2(depthUV.x * 2 - 1, (1 - depthUV.y) * 2 - 1);
    float4 viewPos;

    if (b_iUseHardwareDepth) {
        float4 projectedPos = float4(projectedXYPos, depth, 1.0f);
        viewPos = mul(projectedPos, p_mProjectionInv);
        viewPos = viewPos / viewPos.w;
    }
    else {
        viewPos.xz = depth * projectedXYPos;
        viewPos.xz *= p_vProjectionXZInv;
        viewPos.yw = float2(depth, 1.0f);
    }

    return viewPos;
}

//--------------------------------------------------------------------------------------------------
SPixelOut SplatDeferredPixelMain(VertexTransportRaw vertOut) {
    if (b_iSplatBoxRender) {
        float2 screenPos = INTERPOLANT_ScreenPos;
#if PIXEL_SHADER_VERSION == SHADER_VERSION_PS_30
        // add 0.5f offset required on DX9
        screenPos += float2(0.5f, 0.5f);
#endif  

        // retrieve the scene depth at this position from the depth buffer
        float2 depthUV = screenPos * p_vResolutionRcp;
        float2 viewUV = screenPos.xy * p_vViewOffsetMul.zw + p_vViewOffsetMul.xy;
        float depth = SampleDepth(depthUV);

        // reconstruct the view position and convert back to object space
        float4 viewPos = ReconstructViewPos(depth, viewUV);
        float4 worldPos = mul(viewPos, p_mViewInvTransform44);
        float4 objPos = mul(worldPos, p_mWorldInvTransform);

        // clip if the object space position is outside of the unit cube ([-0.5..0.5] on any axis)
        clip((0.5f - abs(objPos.xyz) + c_fEpsilon));

        // update positional interpolants to match the reconstructed positions
        WRITE_INTERPOLANT_ViewPos(viewPos.xyz);
        WRITE_INTERPOLANT_WorldPos(worldPos);

        // update material interpolants
        if (b_iShadingMode == SHADINGMODE_STANDARD) {
            // object space axes are from [-0.5f..0.5f] for the unit cube, convert to UV coordinates [0..1] using a 0.5f offset
            for (int uvIndex = 0; uvIndex < b_iUVEmitterCount; ++uvIndex)
                WRITE_INTERPOLANT_SWIZZLE_UV(uvIndex, xy, float2(objPos.x + 0.5f, -objPos.y + 0.5f));

            if (b_useNormalMapping) {
                // sample two neighboring pixels to reconstruct the normal/tangent/binormal
                float2 depthUVRight = float2((screenPos.x + 1.0) * p_vResolutionRcp.x, screenPos.y * p_vResolutionRcp.y);
                float4 worldPosRight = mul(ReconstructViewPos(SampleDepth(depthUVRight), depthUVRight), p_mViewInvTransform44);

                float2 depthUVDown = float2(screenPos.x * p_vResolutionRcp.x, (screenPos.y + 1.0f) * p_vResolutionRcp.y);
                float4 worldPosDown = mul(ReconstructViewPos(SampleDepth(depthUVDown), depthUVDown), p_mViewInvTransform44);

                float4 v1 = worldPosRight - worldPos;
                float4 v2 = worldPosDown - worldPos;

                float3 pixelNormal = normalize(cross(v2, v1));
                //float3 pixelNormal = float3(0.0f, 0.0f, 1.0f);
                float3 pixelBinormal = normalize(cross(p_vTangent, pixelNormal));
                float3 pixelTangent = cross(pixelNormal, pixelBinormal);

                // update interpolants
                WRITE_INTERPOLANT_SWIZZLE_Normal(xyz, pixelNormal);
                WRITE_INTERPOLANT_SWIZZLE_Tangent(xyz, pixelTangent);

                // update parallax vector
                WRITE_INTERPOLANT_ParallaxVector(EmitParallaxVector(worldPos.xyz,
                    p_vEyePos,
                    pixelNormal.xyz,
                    pixelTangent.xyz,
                    pixelBinormal.xyz));
            }
            else {
                // reconstruct normal using ddx/ddy (tangent/binormal are not needed)
                float3 pixelNormal = normalize(cross(ddy(worldPos), ddx(worldPos)));
                WRITE_INTERPOLANT_SWIZZLE_Normal(xyz, pixelNormal);
            }
            // update VectorUI1 worldPos
            WRITE_INTERPOLANT_SWIZZLE_VectorUI1(xyz, worldPos.xyz);

            if (b_iVertexLightingMode != VERTEXLIGHTING_NONE) {
                // update vertex lighting
                HALF3 cVertexDiffuseLighting;
                HALF3 cVertexSpecularLighting;
                HALF3 cVertexShadowSpecularLighting;
                HALF3 cVertexShadowSpecularLighting2;
                HALF3 vHalfVecWS = ComputeHalfVector(worldPos, p_directionalLights[0].vDirection);
                HALF4 cLightingRegionMap;

                VertexTransport tempVertOut;
                Lighting(tempVertOut,
                    false,
                    worldPos,
                    INTERPOLANT_Normal,
                    1.0f,
                    1.0f,
                    p_vSpecColorSpecularity.w,
                    cLightingRegionMap,
                    ALL_LIGHTS,
                    cVertexDiffuseLighting,
                    cVertexSpecularLighting,
                    cVertexShadowSpecularLighting2,
                    vHalfVecWS);

                WRITE_INTERPOLANT_Diffuse(cVertexDiffuseLighting);
                WRITE_INTERPOLANT_Specular(cVertexSpecularLighting);
            }
        }
    }

    // apply material shading
    return DefaultPixelMain(vertOut);
}

#endif