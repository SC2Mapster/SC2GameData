//==================================================================================================
//
// Copyright Blizzard Entertainment 2003-2007
//
// Common shader code.
//==================================================================================================

#ifndef VS_UTILS
#define VS_UTILS

#ifdef VERTEX_SHADER

#include "Common.fx"

// :TODO: Share this function.
//--------------------------------------------------------------------------------------------------
// Decompress normal/tangent/binormal basis.
void DecompressRightHandedBasis( inout HALF3 vNormalWS, inout HALF3 vTangentWS, out HALF3 vBinormalWS ) {
    vNormalWS   = DecodeNormal( vNormalWS );
    vTangentWS  = DecodeNormal( vTangentWS );
    vBinormalWS = normalize( cross( vTangentWS, vNormalWS  ));
}

//--------------------------------------------------------------------------------------------------
half3x3 MakeRotation( HALF fAngle, HALF3 vAxis ) {
    HALF fS;
    HALF fC;
    sincos( fAngle, fS, fC );
	HALF fOneC      = 1.0f - fC;
	half3x3 result;
	/*
    HALF fXX       = vAxis.x * vAxis.x;
    HALF fYY       = vAxis.y * vAxis.y;
    HALF fZZ       = vAxis.z * vAxis.z;
    HALF fXY       = vAxis.x * vAxis.y;
    HALF fYZ       = vAxis.y * vAxis.z;
    HALF fZX       = vAxis.z * vAxis.x;
    HALF fXS       = vAxis.x * fS;
    HALF fYS       = vAxis.y * fS;
    HALF fZS       = vAxis.z * fS;
    
    result = half3x3(       fOneC * fXX +  fC, fOneC * fXY + fZS, fOneC * fZX - fYS,
                            fOneC * fXY - fZS, fOneC * fYY +  fC, fOneC * fYZ + fXS,
                            fOneC * fZX + fYS, fOneC * fYZ - fXS, fOneC * fZZ +  fC
    );
	*/

	result[0][0] = fOneC * vAxis.x * vAxis.x + fC;
	result[1][1] = fOneC * vAxis.y * vAxis.y + fC;
	result[2][2] = fOneC * vAxis.z * vAxis.z + fC;
    
	HALF fXY = vAxis.x * vAxis.y;
    HALF fZS = vAxis.z * fS;
	result[1][0] = fOneC * fXY + fZS;
	result[0][1] = fOneC * fXY - fZS;

    HALF fZX       = vAxis.z * vAxis.x;
    HALF fYS       = vAxis.y * fS;
	result[2][0] = fOneC * fZX - fYS;
	result[0][2] = fOneC * fZX + fYS;

    HALF fYZ       = vAxis.y * vAxis.z;
    HALF fXS       = vAxis.x * fS;
	result[2][1] = fOneC * fYZ + fXS;
	result[1][2] = fOneC * fYZ - fXS;
    return result;
}

//--------------------------------------------------------------------------------------------------
HALF3 Rotate( HALF3 vec, HALF fAngle, HALF4 vAxis ) {
	// vAxis.w is expected to be 1
    HALF3 fSfCOneC;
    sincos( fAngle, fSfCOneC.x, fSfCOneC.y );
	fSfCOneC.z = 1.0f - fSfCOneC.y;
	HALF3 result;
	HALF3 row;

	// Contrived and less than optimal speed-wise, but minimizes temp registers.
	{
		row = vAxis.xxz * vAxis.xyz * fSfCOneC.z;
		row += HALF3( 1.0f, 1.0f, -1.0f ) * fSfCOneC.yxx * vAxis.wzy;
		//row.x = fSfCOneC.z * vAxis.x * vAxis.x + fSfCOneC.y;
		//row.y = fSfCOneC.z * vAxis.x * vAxis.y + vAxis.z * fSfCOneC.x;
		//row.z = fSfCOneC.z * vAxis.z * vAxis.x - vAxis.y * fSfCOneC.x;
		result.x = dot( vec, row );
	}
	{
		row = vAxis.xyy * vAxis.yyz * fSfCOneC.z;
		row += HALF3( -1.0f, 1.0f, 1.0f ) * fSfCOneC.xyx * vAxis.zwx;
		//row.x = fSfCOneC.z * vAxis.x * vAxis.y - vAxis.z * fSfCOneC.x;
		//row.y = fSfCOneC.z * vAxis.y * vAxis.y + fSfCOneC.y;
		//row.z = fSfCOneC.z * vAxis.y * vAxis.z + vAxis.x * fSfCOneC.x;
		result.y = dot( vec, row );
	}
	{
		row = vAxis.zyz * vAxis.xzz * fSfCOneC.z;
		row += HALF3( 1.0f, -1.0f, 1.0f ) * fSfCOneC.xxy * vAxis.yxw;
		//row.x = fSfCOneC.z * vAxis.z * vAxis.x + vAxis.y * fSfCOneC.x;
		//row.y = fSfCOneC.z * vAxis.y * vAxis.z - vAxis.x * fSfCOneC.x;
		//row.z = fSfCOneC.z * vAxis.z * vAxis.z + fSfCOneC.y;
		result.z = dot( vec, row );
	}
	return result;
}

// :TODO: Share function.
//--------------------------------------------------------------------------------------------------
float2 GetBackBufferUV( in float4 vHPos, bool handleViewport ) {
    float3 vPos = vHPos.xyz / vHPos.w;
    float2 vResult = vPos.xy * HALF2( 0.5f, -0.5f ) + 0.5f;     // To [0..1]
    //vResult += p_vRenderTargetOffset;
    if ( handleViewport )
        return p_vViewportOrigin + vResult * p_vViewportScale;
    else return vResult;
}

//--------------------------------------------------------------------------------------------------
float3 ComputeGridTangent (float3 normal) {
    const float3 c_forward=float3(0,1,0);
    float3 tangent = cross(c_forward, normal);
    float m = dot(tangent, tangent);
    
    // if m==0 then tangent=float3(1,0,0)
    tangent += (1-sign(m))*float3(1,0,0);
	tangent = normalize(tangent);
    
    return tangent;
}

#endif  // VERTEX_SHADER

#endif  // VS_UTILS