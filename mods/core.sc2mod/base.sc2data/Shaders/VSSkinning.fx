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

// CShaderCore relies on this being in the first register for an optimization, on D3D9 we need to force it
#if CPP_SHADER || VSVersion > SHADER_VERSION_VS_30 || defined(COMPILING_SHADER_FOR_OPENGL) || defined(COMPILING_SHADER_FOR_METAL)
    half3x4    p_mBlendMatrices[MAX_BONE_MATRICES];       // Transposed for efficiency
#else
    half3x4    p_mBlendMatrices[MAX_BONE_MATRICES] : register(c0);
#endif

//--------------------------------------------------------------------------------------------------
void Skin( inout float4 vPosition, inout HALF3 vNormal, inout HALF3 vTangent, inout HALF3 vBinormal, HALF4 vBlendWeights, HALF4 vBlendIndices ) {
#ifdef COMPILING_SHADER_FOR_OPENGL
	// In OpenGL these won't be swizzled by the driver
	int4 iBoneIndices    = (int4)vBlendIndices;
	HALF4 vSwizzledBlendWeights  = vBlendWeights.xyzw;
#else
	int4 iBoneIndices    = D3DCOLORtoUBYTE4(vBlendIndices);
	HALF4 vSwizzledBlendWeights  = vBlendWeights.zyxw;
#endif	
	half3x4 mBlendMatrix;

    // Skin position and normal.
	if ( b_iBlendWeightCount > 0 ) {
	    if ( b_iBlendWeightCount == 1 ) {
#ifdef COMPILING_SHADER_FOR_METAL
			vPosition.xyz	    =   mul( p_mBlendMatrices[iBoneIndices[2]], vPosition );
			vNormal             =   mul( (half3x3)p_mBlendMatrices[iBoneIndices[2]], vNormal );  
#else
		    vPosition.xyz	    =   mul( p_mBlendMatrices[iBoneIndices[0]], vPosition );
			vNormal             =   mul( (half3x3)p_mBlendMatrices[iBoneIndices[0]], vNormal );  
#endif 
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
#ifdef COMPILING_SHADER_FOR_METAL
			vTangent		=   mul( p_mBlendMatrices[iBoneIndices[2]], float4(vTangent, 0.0f) );
			vBinormal	    =   mul( p_mBlendMatrices[iBoneIndices[2]], float4(vBinormal, 0.0f) );
#else
			vTangent		=   mul( p_mBlendMatrices[iBoneIndices[0]], float4(vTangent, 0.0f) );
		    vBinormal	    =   mul( p_mBlendMatrices[iBoneIndices[0]], float4(vBinormal, 0.0f) );
#endif 
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