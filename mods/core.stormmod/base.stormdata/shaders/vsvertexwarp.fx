//==================================================================================================
//
// Copyright Blizzard Entertainment 2003-2007
//
// Vertex warping effect code.
//==================================================================================================

#ifndef VS_VERTEXWARP
#define VS_VERTEXWARP

#ifdef VERTEX_SHADER

#include "ShaderSystem.fx"
#include "VSUtils.fx"

#define MAX_WARPS 1

struct VertexWarp {
    half3x4 vTransform;
    half3x4 vInvTransform;
    HALF2   vStrengthRadius;
};

float4 ApplyWarps( float4 vVertexWS );
float4 ApplyWarp( float4 vVertexWS, VertexWarp warp );

VertexWarp      p_warps[MAX_WARPS];

float3 p_vVertexWarpModelPosition;

//int             p_iWarpCount;

//--------------------------------------------------------------------------------------------------
float4 ApplyWarp( float4 vVertexWS, VertexWarp warp ) {
    // Put in warp space
    float3 vVertex = mul( warp.vInvTransform, vVertexWS );
    float3 vModelPos = mul( warp.vInvTransform, float4( p_vVertexWarpModelPosition, 1.0f ) );
    vModelPos.z = 0;

    float fModelDistance = saturate( length( vModelPos ) / warp.vStrengthRadius.y );
    float fOriginalLength = length( vVertex.xy );

    // Gradient from 0 to 1.
    float fGradient = saturate( fOriginalLength / warp.vStrengthRadius.y );
    float fSquaredGradient = 1.0f - fGradient * fGradient;
    
    float fScalar = warp.vStrengthRadius.x;
    //if ( fScalar < 1.0f )
    //    fScalar = pow( fScalar, 10.0f );

    // Put R from -5 to 1
    float fR = ( 1.0f - fGradient ) * max( 0.0f, pow( 1.5f, fSquaredGradient * 6.0f - 5.0f ) ) * fScalar / 3.0f;
    
    // Apply swirl.
	half3x3 rotation = MakeRotation( fR * fR * 3.1616f * 2.0f, HALF3( 0.0f, 0.0f, 1.0f ) );
    vVertex = mul( rotation, vVertex );

    // Squash to a disc.
    vVertex.z = vVertex.z * pow( fGradient, 6.0f );
    
	//vVertex = Rotate( vVertex, fR * fR * 3.1616f * 2.0f, HALF4( 0.0f, 0.0f, 1.0f, 1.0f ) );
    //float3 vNorm;
    //vNorm.xyz = normalize( vVertex.xyz );
    //vNorm.z = 0;
    //vVertex.xyz = fOriginalLength * ( 1.0f - fR ) * vNorm.xyz;

    // Compress towards center.
    vVertex = vVertex * fModelDistance;

    // Back in world space
    vVertexWS.xyz = mul( warp.vTransform, HALF4( vVertex, 1.0f ) );

    return vVertexWS;
}

//--------------------------------------------------------------------------------------------------
float4 ApplyWarps( float4 vVertexWS ) {
	//Conditional against b_enableVertexWarps removed because the whole fragment is ifdef'ed
	//against the variable.  Reinsert if check if that ever gets removed.
    for ( int i = 0; i < b_iWarpCount; i++ ) {
        vVertexWS = ApplyWarp( vVertexWS, p_warps[i] );
    }
    return vVertexWS;
}

#endif  // VERTEX_SHADER

#endif  // VS_VERTEXWARP