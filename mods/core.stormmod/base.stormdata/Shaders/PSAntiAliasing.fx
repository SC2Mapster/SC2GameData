// FXAA 3.10 (-ish) by Timothy Lottes
//   http://timothylottes.blogspot.com/

float2  p_vAAEdgeThreshold;
float2  p_vAASubPixel;

#define MODE_OFF            0
#define MODE_FXAA3          1
#define MODE_SUBPIXEL       2
#define MODE_EDGEDIRECTION  3

// Quality modes (1 .. 3)
#define FXAA_QUALITY    3

// Same as 12
#if (FXAA_QUALITY == 1)
    #define FXAA_SAMPLES    5
    #define FXAA_STEP0    1.0
    #define FXAA_STEP1    1.5
    #define FXAA_STEP2    2.0
    #define FXAA_STEP3    4.0
    #define FXAA_STEP4    12.0
    #define FXAA_STEP5    12.0
    #define FXAA_STEP6    12.0
    #define FXAA_STEP7    12.0
    
// Same as 23
#elif (FXAA_QUALITY == 2)
    #define FXAA_SAMPLES    6
    #define FXAA_STEP0    1.0
    #define FXAA_STEP1    1.5
    #define FXAA_STEP2    2.0
    #define FXAA_STEP3    2.0
    #define FXAA_STEP4    2.0
    #define FXAA_STEP5    8.0
    #define FXAA_STEP6    8.0
    #define FXAA_STEP7    8.0

// Same as 25
#else
    #define FXAA_SAMPLES    8
    #define FXAA_STEP0    1.0
    #define FXAA_STEP1    1.5
    #define FXAA_STEP2    2.0
    #define FXAA_STEP3    2.0
    #define FXAA_STEP4    2.0
    #define FXAA_STEP5    2.0
    #define FXAA_STEP6    4.0
    #define FXAA_STEP7    8.0

#endif

#define LumaType    float

#ifdef COMPILING_SHADER_FOR_OPENGL
    #define sample2Doff(t, p, o, r)     sample2D(t, p + (o * r))
    #define sample2Dtop(t, p)           sample2D(t, p)
#else
    #define sample2Doff(t, p, o, r)     sample2Dlod(t, float4(p + (o * r), 0, 0))
    #define sample2Dtop(t, p)           sample2Dlod(t, float4(p, 0, 0))
#endif

LumaType GetLuma(float4 cIn) {
    return cIn.a;
}

float4 FxaaPixelShader(
    // {xy} = center of pixel
    float2 pos,
    // {xyzw} = not used on FXAA3 Quality
    float4 posPos,      
    // This must be from a constant/uniform.
    // {x_} = 1.0/screenWidthInPixels
    // {_y} = 1.0/screenHeightInPixels
    float2 vRcpFrame,
    // {xyzw} = not used on FXAA3 Quality
    float4 rcpFrameOpt 
) {   
    float2 vPos;
    vPos.x = pos.x;
    vPos.y = pos.y;
    float4 cCenter = sample2Dtop(p_sSrcMap, vPos);
    float fLumaCenter = GetLuma(cCenter);
    float fLumaDown = GetLuma(sample2Doff(p_sSrcMap, vPos, float2( 0, 1), vRcpFrame.xy));
    float fLumaRight = GetLuma(sample2Doff(p_sSrcMap, vPos, float2( 1, 0), vRcpFrame.xy));
    float fLumaUp = GetLuma(sample2Doff(p_sSrcMap, vPos, float2( 0,-1), vRcpFrame.xy));
    float fLumaLeft = GetLuma(sample2Doff(p_sSrcMap, vPos, float2(-1, 0), vRcpFrame.xy));
    
    // Determine luma range
    float fLumaMaxDownCenter = max(fLumaDown, fLumaCenter);
    float fLumaMinDownCenter = min(fLumaDown, fLumaCenter);
    float fLumaMaxRightDownCenter = max(fLumaRight, fLumaMaxDownCenter); 
    float fLumaMinRightDownCenter = min(fLumaRight, fLumaMinDownCenter); 
    float fLumaMaxUpLeft = max(fLumaUp, fLumaLeft);
    float fLumaMinUpLeft = min(fLumaUp, fLumaLeft);
    float fLumaRangeMax = max(fLumaMaxUpLeft, fLumaMaxRightDownCenter);
    float fLumaRangeMin = min(fLumaMinUpLeft, fLumaMinRightDownCenter);
    float fLumaRangeMaxScaled = fLumaRangeMax * p_vAAEdgeThreshold.x;
    float fLumaRange = fLumaRangeMax - fLumaRangeMin;
    float fLumaRangeMaxClamped = max(p_vAAEdgeThreshold.y, fLumaRangeMaxScaled);
    
#if !CPP_SHADER  // If we return during the CPP shader simulation then we don't mark any of the static branches below as valid. This is bad!
    // If luma range was too low, the pixel does not suffer from aliasing
    if(fLumaRange < fLumaRangeMaxClamped) {
        if ((b_iAAMode == MODE_SUBPIXEL) || (b_iAAMode == MODE_EDGEDIRECTION))
            return float4(0,0,0,0);
        else
            return cCenter;
    }
#endif

    // Determine direction and subpixel aliasing
    float fSubpixel;
    bool bHorizontal;
    {
        float fLumaUpLeft = GetLuma(sample2Doff(p_sSrcMap, vPos, float2(-1,-1), vRcpFrame.xy));
        float fLumaDownRight = GetLuma(sample2Doff(p_sSrcMap, vPos, float2( 1, 1), vRcpFrame.xy));
        float fLumaUpRight = GetLuma(sample2Doff(p_sSrcMap, vPos, float2( 1,-1), vRcpFrame.xy));
        float fLumaDownLeft = GetLuma(sample2Doff(p_sSrcMap, vPos, float2(-1, 1), vRcpFrame.xy));

        float fLumaUpDown = fLumaUp + fLumaDown;
        float fLumaLeftRight = fLumaLeft + fLumaRight;
        float fEdgeCenterHorz = (-2.0 * fLumaCenter) + fLumaUpDown;
        float fEdgeCenterVert = (-2.0 * fLumaCenter) + fLumaLeftRight;

        float fLumaRightCorners = fLumaUpRight + fLumaDownRight;
        float fLumaUpCorners = fLumaUpLeft + fLumaUpRight;
        float fEdgeRight = (-2.0 * fLumaRight) + fLumaRightCorners;
        float fEdgeUp = (-2.0 * fLumaUp) + fLumaUpCorners;

        float fLumaLeftCorners = fLumaUpLeft + fLumaDownLeft;
        float fLumaDownCorners = fLumaDownLeft + fLumaDownRight;
        float fEdgeLeft = (-2.0 * fLumaLeft) + fLumaLeftCorners;
        float fEdgeDown = (-2.0 * fLumaDown) + fLumaDownCorners;
    
        float fEdgeHorzCombined = abs(fEdgeCenterHorz) * 2.0 + abs(fEdgeLeft) + abs(fEdgeRight);
        float fEdgeVertCombined = abs(fEdgeCenterVert) * 2.0 + abs(fEdgeUp) + abs(fEdgeDown);

        bHorizontal = fEdgeHorzCombined >= fEdgeVertCombined;
    
        if (b_iAAMode == MODE_EDGEDIRECTION)
            return float4(0, (bHorizontal) ? 1.0 : 0, (bHorizontal) ? 0 : 1.0,0);     
    
        // Subpixel aliasing calculations
        float fLumaRangeRcp = 1.0/fLumaRange;
        float fLumaUpDownLeftRight = fLumaUpDown + fLumaLeftRight;
        float fLumaAllCorners = fLumaLeftCorners + fLumaRightCorners; 
        
        // Determine overall luminance of 9x9 pixel block and determine how much center pixel differs
        float fLumaFull = fLumaUpDownLeftRight * 2.0 + fLumaAllCorners; 
        float fLumaCenterDiff = (fLumaFull * (1.0/12.0)) - fLumaCenter;
        fLumaCenterDiff -= min(fLumaCenterDiff,0.0) * p_vAASubPixel.y;  // Test to decrease highlight removal
        float fLumaCenterDiffNormalized = saturate(abs(fLumaCenterDiff) * fLumaRangeRcp);
        
        // Modify linear value to get an S - curve
        float fSubpixelLinear = ((-2.0)*fLumaCenterDiffNormalized) + 3.0;
        float fSubpixelQuadratic = fLumaCenterDiffNormalized * fLumaCenterDiffNormalized;
        float fSubpixelProduct = fSubpixelLinear * fSubpixelQuadratic;
        float fSubpixelFinal = fSubpixelProduct * fSubpixelProduct;
        
        // Apply user-controlled subpixel blend value
        fSubpixel = fSubpixelFinal * p_vAASubPixel.x;
        
        if (b_iAAMode == MODE_SUBPIXEL)
            return float4(1.0,fSubpixel,0.0,0.0);
    }
    
    // Determine side of pixel to search
    float fLengthSign;
    float fGradient;
    float fLumaTarget;
    {
        float fLumaFront = (bHorizontal) ? fLumaUp : fLumaLeft;
        float fLumaBack = (bHorizontal) ? fLumaDown : fLumaRight;
        fLengthSign = (bHorizontal) ? vRcpFrame.y : vRcpFrame.x;

        float fGradientFront = fLumaFront - fLumaCenter;
        float fGradientBack = fLumaBack - fLumaCenter;
        float fLumaFrontCenter = fLumaFront + fLumaCenter;
        float fLumaBackCenter = fLumaBack + fLumaCenter;
        
        float fGradientFrontAbs = abs(fGradientFront);
        float fGradientBackAbs = abs(fGradientBack);
        if (fGradientFrontAbs >= fGradientBackAbs) {
            fGradient = fGradientFrontAbs;
            fLengthSign = -fLengthSign;
            fLumaTarget = fLumaFrontCenter;
        } 
        else {
            fGradient = fGradientBackAbs;
            fLumaTarget = fLumaBackCenter;
        }
    }
    
    // Initialize search parameters
    float2 vPosBase;
    vPosBase.x = vPos.x;
    vPosBase.y = vPos.y;
    float2 vStep;
    vStep.x = (!bHorizontal) ? 0.0 : vRcpFrame.x;
    vStep.y = ( bHorizontal) ? 0.0 : vRcpFrame.y;
    if(!bHorizontal) vPosBase.x += fLengthSign * 0.5;
    if( bHorizontal) vPosBase.y += fLengthSign * 0.5;

    // Initialize search positions, sample first luma
    float2 vPosFront = vPosBase - vStep;
    float2 vPosBack = vPosBase + vStep;
    float fLumaEndFront = GetLuma(sample2Dtop(p_sSrcMap, vPosFront));
    float fLumaEndBack = GetLuma(sample2Dtop(p_sSrcMap, vPosBack));
    
    // 1.0/4.0 used to be user-setable constant
    float fGradientScaled = fGradient * 1.0/4.0;
    float fLumaDiff = fLumaCenter - fLumaTarget * 0.5;
    bool bLumaCenterIsLess = fLumaDiff < 0.0;
    
    // Start loop - search for ends of line
    fLumaEndFront -= fLumaTarget * 0.5;
    fLumaEndBack -= fLumaTarget * 0.5;
    bool bDoneFront = abs(fLumaEndFront) >= fGradientScaled;
    bool bDoneBack = abs(fLumaEndBack) >= fGradientScaled;
    if(!bDoneFront) vPosFront -= vStep * FXAA_STEP0;
    bool bNotDone = (!bDoneFront) || (!bDoneBack);
    if(!bDoneBack) vPosBack += vStep * FXAA_STEP0;

    // Loop unrolled
    if(bNotDone) {
        if(!bDoneFront) fLumaEndFront = GetLuma(sample2Dtop(p_sSrcMap, vPosFront.xy));
        if(!bDoneBack) fLumaEndBack = GetLuma(sample2Dtop(p_sSrcMap, vPosBack.xy));
        if(!bDoneFront) fLumaEndFront = fLumaEndFront - fLumaTarget * 0.5;
        if(!bDoneBack) fLumaEndBack = fLumaEndBack - fLumaTarget * 0.5;
        bDoneFront = abs(fLumaEndFront) >= fGradientScaled;
        bDoneBack = abs(fLumaEndBack) >= fGradientScaled;
        if(!bDoneFront) vPosFront -= vStep * FXAA_STEP1;
        bNotDone = (!bDoneFront) || (!bDoneBack);
        if(!bDoneBack) vPosBack += vStep * FXAA_STEP1;
        
        if(bNotDone) {
            if(!bDoneFront) fLumaEndFront = GetLuma(sample2Dtop(p_sSrcMap, vPosFront.xy));
            if(!bDoneBack) fLumaEndBack = GetLuma(sample2Dtop(p_sSrcMap, vPosBack.xy));
            if(!bDoneFront) fLumaEndFront = fLumaEndFront - fLumaTarget * 0.5;
            if(!bDoneBack) fLumaEndBack = fLumaEndBack - fLumaTarget * 0.5;
            bDoneFront = abs(fLumaEndFront) >= fGradientScaled;
            bDoneBack = abs(fLumaEndBack) >= fGradientScaled;
            if(!bDoneFront) vPosFront -= vStep * FXAA_STEP2;
            bNotDone = (!bDoneFront) || (!bDoneBack);
            if(!bDoneBack) vPosBack += vStep * FXAA_STEP2;
            
            if(bNotDone) {
                if(!bDoneFront) fLumaEndFront = GetLuma(sample2Dtop(p_sSrcMap, vPosFront.xy));
                if(!bDoneBack) fLumaEndBack = GetLuma(sample2Dtop(p_sSrcMap, vPosBack.xy));
                if(!bDoneFront) fLumaEndFront = fLumaEndFront - fLumaTarget * 0.5;
                if(!bDoneBack) fLumaEndBack = fLumaEndBack - fLumaTarget * 0.5;
                bDoneFront = abs(fLumaEndFront) >= fGradientScaled;
                bDoneBack = abs(fLumaEndBack) >= fGradientScaled;
                if(!bDoneFront) vPosFront -= vStep * FXAA_STEP3;
                bNotDone = (!bDoneFront) || (!bDoneBack);
                if(!bDoneBack) vPosBack += vStep * FXAA_STEP3;
                
                if(bNotDone) {
                    if(!bDoneFront) fLumaEndFront = GetLuma(sample2Dtop(p_sSrcMap, vPosFront.xy));
                    if(!bDoneBack) fLumaEndBack = GetLuma(sample2Dtop(p_sSrcMap, vPosBack.xy));
                    if(!bDoneFront) fLumaEndFront = fLumaEndFront - fLumaTarget * 0.5;
                    if(!bDoneBack) fLumaEndBack = fLumaEndBack - fLumaTarget * 0.5;
                    bDoneFront = abs(fLumaEndFront) >= fGradientScaled;
                    bDoneBack = abs(fLumaEndBack) >= fGradientScaled;
                    if(!bDoneFront) vPosFront.x -= vStep * FXAA_STEP4;
                    bNotDone = (!bDoneFront) || (!bDoneBack);
                    if(!bDoneBack) vPosBack.x += vStep * FXAA_STEP4; 
                    
                    if(bNotDone && (FXAA_SAMPLES > 5)) {
                        if(!bDoneFront) fLumaEndFront = GetLuma(sample2Dtop(p_sSrcMap, vPosFront.xy));
                        if(!bDoneBack) fLumaEndBack = GetLuma(sample2Dtop(p_sSrcMap, vPosBack.xy));
                        if(!bDoneFront) fLumaEndFront = fLumaEndFront - fLumaTarget * 0.5;
                        if(!bDoneBack) fLumaEndBack = fLumaEndBack - fLumaTarget * 0.5;
                        bDoneFront = abs(fLumaEndFront) >= fGradientScaled;
                        bDoneBack = abs(fLumaEndBack) >= fGradientScaled;
                        if(!bDoneFront) vPosFront.x -= vStep * FXAA_STEP5;
                        bNotDone = (!bDoneFront) || (!bDoneBack);
                        if(!bDoneBack) vPosBack.x += vStep * FXAA_STEP5; 
                        
                        if(bNotDone && (FXAA_SAMPLES > 6)) {
                            if(!bDoneFront) fLumaEndFront = GetLuma(sample2Dtop(p_sSrcMap, vPosFront.xy));
                            if(!bDoneBack) fLumaEndBack = GetLuma(sample2Dtop(p_sSrcMap, vPosBack.xy));
                            if(!bDoneFront) fLumaEndFront = fLumaEndFront - fLumaTarget * 0.5;
                            if(!bDoneBack) fLumaEndBack = fLumaEndBack - fLumaTarget * 0.5;
                            bDoneFront = abs(fLumaEndFront) >= fGradientScaled;
                            bDoneBack = abs(fLumaEndBack) >= fGradientScaled;
                            if(!bDoneFront) vPosFront.x -= vStep * FXAA_STEP6;
                            bNotDone = (!bDoneFront) || (!bDoneBack);
                            if(!bDoneBack) vPosBack.x += vStep * FXAA_STEP6; 
                            
                            if(bNotDone && (FXAA_SAMPLES > 7)) {
                                if(!bDoneFront) fLumaEndFront = GetLuma(sample2Dtop(p_sSrcMap, vPosFront.xy));
                                if(!bDoneBack) fLumaEndBack = GetLuma(sample2Dtop(p_sSrcMap, vPosBack.xy));
                                if(!bDoneFront) fLumaEndFront = fLumaEndFront - fLumaTarget * 0.5;
                                if(!bDoneBack) fLumaEndBack = fLumaEndBack - fLumaTarget * 0.5;
                                bDoneFront = abs(fLumaEndFront) >= fGradientScaled;
                                bDoneBack = abs(fLumaEndBack) >= fGradientScaled;
                                if(!bDoneFront) vPosFront.x -= vStep * FXAA_STEP7;
                                if(!bDoneBack) vPosBack.x += vStep * FXAA_STEP7;
                            } 
                        } 
                    } 
                } 
            } 
        } 
    }                
    
    // Determine distance and final gradient                
    float fDistanceFront = (bHorizontal) ? vPos.x - vPosFront.x : vPos.y - vPosFront.y;
    float fDistanceBack = (bHorizontal) ? vPosBack.x - vPos.x : vPosBack.y - vPos.y;
    
    bool bFrontDiffers = (fLumaEndFront < 0.0) != bLumaCenterIsLess;
    float fSpanLength = (fDistanceFront + fDistanceBack);
    bool bBackDiffers = (fLumaEndBack < 0.0) != bLumaCenterIsLess;
    float fSpanLengthRcp = 1.0/fSpanLength;
    
    // Determine if we are actually on the right side of the line
    bool bSpanDiff;
    float fDistance;
    if (fDistanceFront < fDistanceBack) {
        bSpanDiff = bFrontDiffers;
        fDistance = fDistanceFront;
    }
    else {
        bSpanDiff = bBackDiffers;
        fDistance = fDistanceBack;
    }
    float fPixelOffset = (fDistance * (-fSpanLengthRcp)) + 0.5;
    float fPixelOffsetFinal = bSpanDiff ? fPixelOffset : 0.0;
        
    // Include subpixel blend, sample screen texture
    fPixelOffsetFinal = max(fPixelOffsetFinal, fSubpixel);
    if(!bHorizontal) vPos.x += fPixelOffsetFinal * fLengthSign;
    if( bHorizontal) vPos.y += fPixelOffsetFinal * fLengthSign;
    return sample2Dtop(p_sSrcMap, vPos);
}

// Entry point to AntiAliasing postprocess
HALF4 PostProcessAntiAliasing( VertexTransport vertOut ) {
    float4 vRcpOpt = float4(p_vRecipSrcSizeOffset.xy,p_vRecipSrcSizeOffset.xy);
    vRcpOpt.xy *= 2.0;
    vRcpOpt.zw *= 0.5;
    float4 vPosCorners;
    vPosCorners.xy = READ_INTERPOLANT_UV(0).xy - vRcpOpt.zw;
    vPosCorners.zw = READ_INTERPOLANT_UV(0).xy + vRcpOpt.zw;
    return FxaaPixelShader(READ_INTERPOLANT_UV(0).xy,vPosCorners,p_vRecipSrcSizeOffset.xy,vRcpOpt);
}