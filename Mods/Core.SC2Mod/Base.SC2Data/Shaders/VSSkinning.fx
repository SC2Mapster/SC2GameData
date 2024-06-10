#ifndef VS_SKINNING
#define VS_SKINNING

#ifdef VERTEX_SHADER

#include "ShaderSystem.fx"

// :TODO: We won't support VS 1.1. so this should be cleaned up.
#ifdef COMPILING_SHADER_FOR_OPENGL
#define MAX_BONE_MATRICES           64
#else

#if ( VSVersion == SHADER_VERSION_VS_11 )
#define MAX_BONE_MATRICES           21
#else
#define MAX_BONE_MATRICES           64  // this value must match c_MaxBonesSupported
#endif

#endif

half3x4    p_mBlendMatrices[MAX_BONE_MATRICES];       // Transposed for efficiency

void Skin( inout float4 vPosition, inout half3 vNormal, inout half3 vTangent, inout half3 vBinormal, half4 vBlendWeights, half4 vBlendIndices ) {
#ifdef COMPILING_SHADER_FOR_OPENGL
	// In OpenGL these won't be swizzled by the driver
	int4 iBoneIndices    = (int4)vBlendIndices;
	half4 vSwizzledBlendWeights  = vBlendWeights.xyzw;
#else
	int4 iBoneIndices    = D3DCOLORtoUBYTE4(vBlendIndices);
	half4 vSwizzledBlendWeights  = vBlendWeights.zyxw;
#endif	
	half3x4 mBlendMatrix;

    // Skin position and normal.
	if ( b_iBlendWeightCount > 0 ) {
	    if ( b_iBlendWeightCount == 1 ) {
		    vPosition.xyz	    =   mul( p_mBlendMatrices[iBoneIndices[0]], vPosition );
		    vNormal             =   mul( (half3x3)p_mBlendMatrices[iBoneIndices[0]], vNormal );   
        } 
        else {
            mBlendMatrix = p_mBlendMatrices[iBoneIndices[0]] * vSwizzledBlendWeights[0];
		    if ( b_iBlendWeightCount >= 2 ) {
                mBlendMatrix += p_mBlendMatrices[iBoneIndices[1]] * vSwizzledBlendWeights[1];
                mBlendMatrix += p_mBlendMatrices[iBoneIndices[2]] * vSwizzledBlendWeights[2];
                mBlendMatrix += p_mBlendMatrices[iBoneIndices[3]] * vSwizzledBlendWeights[3];
		    }

		    vPosition.xyz	    =   mul( mBlendMatrix, vPosition );
		    vNormal             =   mul( (half3x3)mBlendMatrix, vNormal );   
    	}
    	vNormal = normalize( vNormal );
	}

    // Skin tangents and binormals.
	if ( b_useNormalMapping && b_iBlendWeightCount > 0 ) {
	    if ( b_iBlendWeightCount == 1 ) {
		    vTangent		=   mul( p_mBlendMatrices[iBoneIndices[0]], float4(vTangent, 0.0f) );
		    vBinormal	    =   mul( p_mBlendMatrices[iBoneIndices[0]], float4(vBinormal, 0.0f) );
        } 
        else {
		    vTangent	    =   mul( mBlendMatrix, float4(vTangent, 0.0f) );
		    vBinormal	    =   mul( mBlendMatrix, float4(vBinormal, 0.0f) );
	    }
	    //vTangent     = normalize( vTangent );
	    //vBinormal    = normalize( vBinormal );
	}    
}

#endif      // VERTEX_SHADER

#endif      // VS_SKINNING