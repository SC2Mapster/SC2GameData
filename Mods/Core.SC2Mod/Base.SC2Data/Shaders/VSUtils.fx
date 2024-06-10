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
void DecompressRightHandedBasis( inout half3 vNormalWS, inout half3 vTangentWS, out half3 vBinormalWS ) {
    vNormalWS   = DecodeNormal( vNormalWS );
    vTangentWS  = DecodeNormal( vTangentWS );
    vBinormalWS = normalize( cross( vTangentWS, vNormalWS  ));
}

//--------------------------------------------------------------------------------------------------
half SmoothStep( half fX ) {
    return fX * fX * ( 3.0f - 2.0f * fX );
}

//--------------------------------------------------------------------------------------------------
half3x3 MakeRotation( half fAngle, half3 vAxis ) {
    half fS;
    half fC;
    sincos( fAngle, fS, fC );
	half fOneC      = 1.0f - fC;
	half3x3 result;
	/*
    half fXX       = vAxis.x * vAxis.x;
    half fYY       = vAxis.y * vAxis.y;
    half fZZ       = vAxis.z * vAxis.z;
    half fXY       = vAxis.x * vAxis.y;
    half fYZ       = vAxis.y * vAxis.z;
    half fZX       = vAxis.z * vAxis.x;
    half fXS       = vAxis.x * fS;
    half fYS       = vAxis.y * fS;
    half fZS       = vAxis.z * fS;
    
    result = half3x3(       fOneC * fXX +  fC, fOneC * fXY + fZS, fOneC * fZX - fYS,
                            fOneC * fXY - fZS, fOneC * fYY +  fC, fOneC * fYZ + fXS,
                            fOneC * fZX + fYS, fOneC * fYZ - fXS, fOneC * fZZ +  fC
    );
	*/

	result[0][0] = fOneC * vAxis.x * vAxis.x + fC;
	result[1][1] = fOneC * vAxis.y * vAxis.y + fC;
	result[2][2] = fOneC * vAxis.z * vAxis.z + fC;
    
	half fXY = vAxis.x * vAxis.y;
    half fZS = vAxis.z * fS;
	result[1][0] = fOneC * fXY + fZS;
	result[0][1] = fOneC * fXY - fZS;

    half fZX       = vAxis.z * vAxis.x;
    half fYS       = vAxis.y * fS;
	result[2][0] = fOneC * fZX - fYS;
	result[0][2] = fOneC * fZX + fYS;

    half fYZ       = vAxis.y * vAxis.z;
    half fXS       = vAxis.x * fS;
	result[2][1] = fOneC * fYZ + fXS;
	result[1][2] = fOneC * fYZ - fXS;
    return result;
}

//--------------------------------------------------------------------------------------------------
half3 Rotate( half3 vec, half fAngle, half4 vAxis ) {
	// vAxis.w is expected to be 1
    half3 fSfCOneC;
    sincos( fAngle, fSfCOneC.x, fSfCOneC.y );
	fSfCOneC.z = 1.0f - fSfCOneC.y;
	half3 result;
	half3 row;

	// Contrived and less than optimal speed-wise, but minimizes temp registers.
	{
		row = vAxis.xxz * vAxis.xyz * fSfCOneC.z;
		row += half3( 1.0f, 1.0f, -1.0f ) * fSfCOneC.yxx * vAxis.wzy;
		//row.x = fSfCOneC.z * vAxis.x * vAxis.x + fSfCOneC.y;
		//row.y = fSfCOneC.z * vAxis.x * vAxis.y + vAxis.z * fSfCOneC.x;
		//row.z = fSfCOneC.z * vAxis.z * vAxis.x - vAxis.y * fSfCOneC.x;
		result.x = dot( vec, row );
	}
	{
		row = vAxis.xyy * vAxis.yyz * fSfCOneC.z;
		row += half3( -1.0f, 1.0f, 1.0f ) * fSfCOneC.xyx * vAxis.zwx;
		//row.x = fSfCOneC.z * vAxis.x * vAxis.y - vAxis.z * fSfCOneC.x;
		//row.y = fSfCOneC.z * vAxis.y * vAxis.y + fSfCOneC.y;
		//row.z = fSfCOneC.z * vAxis.y * vAxis.z + vAxis.x * fSfCOneC.x;
		result.y = dot( vec, row );
	}
	{
		row = vAxis.zyz * vAxis.xzz * fSfCOneC.z;
		row += half3( 1.0f, -1.0f, 1.0f ) * fSfCOneC.xxy * vAxis.yxw;
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
    float2 vResult = vPos.xy * half2( 0.5f, -0.5f ) + 0.5f;     // To [0..1]
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