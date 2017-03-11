//==================================================================================================
//
// Copyright Blizzard Entertainment 2003-2005
//
// A simple full-screen quad used for generating a noise texture
//==================================================================================================

#include "ShaderSystem.fx"

struct VertexTransport {
    HALF4 pos		            : POSITION;
    HALF4 vUV0       	        : TEXCOORD0;
    HALF4 vUV1       	        : TEXCOORD1;
    HALF4 vUV2       	        : TEXCOORD2;
};

#ifdef VERTEX_SHADER

#define UVEmitterCount  1           // :HACK:

struct Input {
    float3  vPosition		: POSITION_;
    HALF4   Color		: COLOR0_;
    HALF2   vUV[1]              : TEXCOORD0_;
};

//--------------------------------------------------------------------------------------------------
float4 EmitNoiseQuadHPos( Input vertIn ) {
    return float4( vertIn.vPosition, 1.0f );
}

//--------------------------------------------------------------------------------------------------
HALF4 EmitNoiseQuadUV( Input vertIn ) {
    return HALF4( vertIn.vPosition.xy * 0.5f + 0.5f, 0, 1 );
}

//--------------------------------------------------------------------------------------------------
VertexTransport NoiseQuadVertexMain( Input vertIn ) {
    VertexTransport output;

    output.pos = EmitNoiseQuadHPos(vertIn);
    output.vUV0 = EmitNoiseQuadUV(vertIn);
    if (b_shadowGenerationPass) {
        output.vUV1 = output.vUV0;
        output.vUV2 = output.vUV0;
    }
    else if (b_normalGenerationPass) {
        output.vUV1 = output.vUV0 + HALF4(1.0f / 256.0f, 0, 0, 0);
        output.vUV2 = output.vUV0 + HALF4(0, -1.0f / 256.0f, 0, 0);
    }
    else {
        output.vUV1 = output.vUV0;
        output.vUV2 = output.vUV0;
    }
#ifdef COMPILING_SHADER_FOR_OPENGL
    output.pos.y *= -1.0;
    output.pos.z = 2.0 * (output.pos.z - (0.5 * output.pos.w));
#endif    
    return output;
}

#endif  // VERTEX_SHADER

#ifdef PIXEL_SHADER

float p_fElapsedTime;
float p_fNoiseTiling;
float p_fHeightMapStrength;
float p_fNoiseScalar;
float p_fHeightThreshold;
float p_fHeightDelta;
float4 p_vHackThreshold;
float4 p_vNeighborSampleOffset;

texDecl2D(p_sNoiseMap);
texDecl2D(p_sHeightMap);

//--------------------------------------------------------------------------------------------------
HALF4 NoiseQuadPixelMain( VertexTransport vertOut ) : COLOR {
    InitShader();

    float2 baseUV = vertOut.vUV0;
    baseUV.y = 1 - baseUV.y;

    if (b_hackPass) {
        float2 dx = ddx( baseUV );
        float2 dy = ddy( baseUV );

        float finalValue = 1.0f;
        for (int x = -4; x <= 4; x++) {
            for (int y = -4; y <= 4; y++) {
                float2 uv;
                uv.x = baseUV.x - x * p_vHackThreshold.z;
                uv.y = baseUV.y - y * p_vHackThreshold.w;
                float4 cSample = sample2Dgrad(p_sHeightMap, uv, dx, dy);
                float value = (cSample.a - p_vHackThreshold.x) * p_vHackThreshold.y;
                finalValue += clamp(value, 0, 1);
            }
        }
        return finalValue / 81.0f;


        //return (cSample0.a < 0) ? 0.0f : 1.0f;
        //return p_fHackThreshold;
    }

    if (b_shadowGenerationPass) {
        float2 uv = vertOut.vUV0.xy;
        float fShadowVal = 1.0f;
        float4 cSample0 = sample2D(p_sHeightMap, uv);
        int iSampleIndex = 0;
        float fHeightThreshold = p_fHeightThreshold;
        while (iSampleIndex < 4) {
            uv += p_vNeighborSampleOffset;
            float4 cSample1 = sample2D(p_sHeightMap, uv);
            fShadowVal *= (cSample1.x - cSample0.x > fHeightThreshold) ? 0.0f : 1.0f;
            fHeightThreshold += p_fHeightDelta;
            iSampleIndex++;
        }
        return fShadowVal;
    }

    else if (b_normalGenerationPass) {
        float4 cSample0 = sample2D(p_sHeightMap, vertOut.vUV0.xy);
        float4 cSample1 = sample2D(p_sHeightMap, vertOut.vUV1.xy);
        float4 cSample2 = sample2D(p_sHeightMap, vertOut.vUV2.xy);

        float fVec0Diff = clamp(((cSample1.x - cSample0.x) * p_fHeightMapStrength), -1.0f, 1.0f);
        float fVec1Diff = clamp(((cSample2.x - cSample0.x) * p_fHeightMapStrength), -1.0f, 1.0f);

        float3 vVec0 = float3(sqrt(1.0f - (fVec0Diff * fVec0Diff)), 0.0f, fVec0Diff);
        float3 vVec1 = float3(0.0f, sqrt(1.0f - (fVec1Diff * fVec1Diff)), fVec1Diff);
        float3 vResult = normalize(cross(vVec0, vVec1));

        return HALF4((vResult * 0.5f) + 0.5f, 1.0f);
    }

    else {
        float4 cSample0 = sample2D(p_sHeightMap, vertOut.vUV0.xy);

        float4 noiseUV0 = vertOut.vUV0 * p_fNoiseTiling;
        float4 noiseUV1 = vertOut.vUV0 * p_fNoiseTiling;
        noiseUV0.x += frac(p_fElapsedTime);
        noiseUV0.y += frac(p_fElapsedTime * 0.05f);
        noiseUV1.x -= frac(p_fElapsedTime);
        noiseUV1.y -= frac(p_fElapsedTime * 0.05f);
        float4 cNoiseSample0 = ((sample2D(p_sNoiseMap, noiseUV0.xy) - 0.5f) * 2.0f);
        float4 cNoiseSample1 = ((sample2D(p_sNoiseMap, noiseUV1.xy) - 0.5f) * 2.0f);
        float4 cNoiseSample = (cNoiseSample0 + cNoiseSample1) * p_fNoiseScalar * cSample0.w;

        return cSample0.x + cNoiseSample.x;
    }
}

#endif      // PIXEL_SHADER