//==================================================================================================
//
// Copyright Blizzard Entertainment 2003-2005
//
// Shared tone mapping function.
//==================================================================================================

#ifndef PS_TONEMAP
#define PS_TONEMAP

#ifdef PIXEL_SHADER

float p_fExposure;
float p_fContrast;
float p_fGain;
float p_fScale;
float p_fWhitePoint;

#define REINHARD_OPERATOR       0
#define EXPONENTIONAL_OPERATOR  1
#define LOGARITHMIC_OPERATOR    2
#define LINEAR_OPERATOR         3
#define FILMIC_OPERATOR         4

float Tonemap( float fSrcL ) {
    // Scale and gain removed.
    //fSrcL = fSrcL * p_fScale;
    float fTonemappedL;
    if ( b_iOperator == REINHARD_OPERATOR ) {
        fTonemappedL = pow( fSrcL, p_fContrast ) * p_fExposure;
        float fTonemappedLScaled = fTonemappedL * ( 1 + ( fTonemappedL / ( p_fWhitePoint * p_fWhitePoint ) ) );
        fTonemappedL = fTonemappedLScaled / ( 1 + fTonemappedL );

/*
        fTonemappedL = pow( fSrcL, p_fContrast ) * p_fExposure;
        float fTonemappedLScaled = fTonemappedL * ( 1 + ( fTonemappedL / ( p_fWhitePoint * p_fWhitePoint ) );
        fTonemappedL = fTonemappedLScaled / ( 1 + fTonemappedL );
        */
    } else if ( b_iOperator == EXPONENTIONAL_OPERATOR ) {
        //fTonemappedL = p_fGain - exp( -p_fExposure * pow( fSrcL, p_fContrast ) ) * p_fGain;
        fTonemappedL = 1.0f - exp( -p_fExposure * pow( fSrcL, p_fContrast ) );
    } else if ( b_iOperator == LOGARITHMIC_OPERATOR ) {
        fTonemappedL = log ( pow( fSrcL, p_fContrast ) + 1 ) / log ( p_fExposure + 1 );
    } else if ( b_iOperator == LINEAR_OPERATOR ) {
        fTonemappedL = pow( fSrcL, p_fContrast );
    } else if ( b_iOperator == FILMIC_OPERATOR ) {
		//fSrcL = pow( fSrcL, p_fContrast );  // Always 1.0f;
		fTonemappedL = pow( fSrcL, 2.2f ) * p_fExposure;
		float x = fTonemappedL;	              // = max(0, fTonemappedL - pureBlackThreshold);
		
		// Constants are somewhat arbitrary to shape curve
		//  and to scale so the area under the curve is approximately equal to "Exponential" for brightness.
		fTonemappedL = (x*(12.3f*x+.5f))/(x*(12.3f*x+4.0f)+0.02f);
    }
    
    return fTonemappedL;
}

#endif  // PIXEL_SHADER

#endif  // PS_TONEMAP