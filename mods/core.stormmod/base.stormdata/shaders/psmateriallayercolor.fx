
//--------------------------------------------------------------------------------------------------
HALF4 SampleLayer (
    in VertexTransport vertOut, 
    SLayerConfig layerSettings, 
    typeSampler sLayer,
    typeTexture tLayer,
    SEnvMappings envMappings, 
    bool allowEnvio,
    inout float3x2 mTriPlanarUVs[c_maxNumLayers]
) {
    // use constant color
    //
    if ( layerSettings.b_iUseConstantColor )
        return layerSettings.p_cConstantColor;

    float4 vUV = GetUVEmitter(vertOut, layerSettings.b_iUVEmitter, layerSettings.p_vMultiplyAddAlphaTrans.w, layerSettings.p_mUVTransform );

    // tri planar mapping
    #if textureEnum == TEXTURE_TYPE_2D || textureEnum == TEXTURE_TYPE_UNDEFINED
        if (IsTriPlanarMappingFX(layerSettings.b_iUVMapping)) {
            float3 normal, weights;
            if (TriPlanarIsWorldFX(layerSettings.b_iUVMapping)) {
                normal = INTERPOLANT_Normal.xyz;
                weights = float3(INTERPOLANT_FogColor.x, INTERPOLANT_FogColor.y, vUV.w);
            }
            else {
                normal = INTERPOLANT_VectorUI0.xyz;
                weights = INTERPOLANT_TriPlanarWeights.xyz;
            }

            // Non-array because compiler was not vectorizing as array.
            float2 uvZ;
            float2 uvY;
            float2 uvX;
            if (layerSettings.b_iTriPlanarUvId >= c_maxNumLayers) {
                if (layerSettings.b_iLayerId < c_maxNumLayers) {
                    uvZ = mTriPlanarUVs[layerSettings.b_iLayerId][0];
                    uvY = mTriPlanarUVs[layerSettings.b_iLayerId][1];
                    uvX = mTriPlanarUVs[layerSettings.b_iLayerId][2];
                }
                else {
                    TriplanarAtlas(layerSettings.p_vAtlasParams, normal, vUV.xyz, uvZ, uvY, uvX);
                }
            }
            else {
                uvZ = mTriPlanarUVs[layerSettings.b_iTriPlanarUvId][0];
                uvY = mTriPlanarUVs[layerSettings.b_iTriPlanarUvId][1];
                uvX = mTriPlanarUVs[layerSettings.b_iTriPlanarUvId][2];
            }

            return SampleTriPlanarTexture(sLayer, tLayer, uvZ, uvY, uvX, weights);
        }
    #endif

    if ( allowEnvio ) {
        if ( layerSettings.b_iUVMapping == UVMAP_REFLECT_CUBICENVIO || layerSettings.b_iUVMapping == UVMAP_CUBICENVIO )
            vUV = GenEnvioUV( envMappings, layerSettings.b_iUVMapping );
        else if ( layerSettings.b_iUVMapping == UVMAP_REFLECT_SPHERICALENVIO || layerSettings.b_iUVMapping == UVMAP_SPHERICALENVIO ) 
            vUV = GenEnvioUV( envMappings, layerSettings.b_iUVMapping );
    }

    if ( layerSettings.b_iIsRTTTexture )
        vUV.xy = vUV.xy * layerSettings.p_vRTTTextureOffsetScale.zw + layerSettings.p_vRTTTextureOffsetScale.xy;

    #if textureEnum == TEXTURE_TYPE_2D
        return sampleTex2D( tLayer, sLayer, vUV.xy );
    #elif textureEnum == TEXTURE_TYPE_CUBE
        return sampleTexCube( tLayer, sLayer, vUV.xyz );
    #elif textureEnum == TEXTURE_TYPE_VOLUME
        return sampleTex3D( tLayer, sLayer, vUV.xyz );
    #else
        if (layerSettings.b_iTextureType == TEXTURE_TYPE_2D)
            return sampleTex2D( tLayer, sLayer, vUV.xy );
        else if(layerSettings.b_iTextureType == TEXTURE_TYPE_CUBE)
            return sampleTexCube( tLayer, sLayer, vUV.xyz );
        else if(layerSettings.b_iTextureType == TEXTURE_TYPE_VOLUME)
            return sampleTex3D( tLayer, sLayer, vUV.xyz );
    #endif
    
    return 0;
}

//--------------------------------------------------------------------------------------------------
HALF4 SampleLayerGrad (
    in VertexTransport vertOut, 
    SLayerConfig layerSettings, 
    typeSampler sLayer,
    typeTexture tLayer,
    SEnvMappings envMappings, 
    bool allowEnvio,
    HALF4 ddx,
    HALF4 ddy
) {
    // use constant color
    //
    if ( layerSettings.b_iUseConstantColor )
        return layerSettings.p_cConstantColor;

    float4 vUV = GetUVEmitter(vertOut, layerSettings.b_iUVEmitter, layerSettings.p_vMultiplyAddAlphaTrans.w, layerSettings.p_mUVTransform);

    if ( allowEnvio ) {
        if ( layerSettings.b_iUVMapping == UVMAP_REFLECT_CUBICENVIO || layerSettings.b_iUVMapping == UVMAP_CUBICENVIO )
            vUV = GenEnvioUV( envMappings, layerSettings.b_iUVMapping );
        else if ( layerSettings.b_iUVMapping == UVMAP_REFLECT_SPHERICALENVIO || layerSettings.b_iUVMapping == UVMAP_SPHERICALENVIO ) 
            vUV = GenEnvioUV( envMappings, layerSettings.b_iUVMapping );
    }

    if ( layerSettings.b_iIsRTTTexture )
        vUV.xy = vUV.xy * layerSettings.p_vRTTTextureOffsetScale.zw + layerSettings.p_vRTTTextureOffsetScale.xy;

    #if textureEnum == TEXTURE_TYPE_2D
        return sampleTex2Dgrad( tLayer, sLayer, vUV.xy, ddx.xy, ddy.xy );
    #elif textureEnum == TEXTURE_TYPE_CUBE
        return sampleTexCubegrad( tLayer, sLayer, vUV.xyz, ddx.xyz, ddy.xyz );
    #elif textureEnum == TEXTURE_TYPE_VOLUME
        return sampleTex3Dgrad( tLayer, sLayer, vUV.xyzw, ddx.xyz, ddy.xyz );
    #else
        if (layerSettings.b_iTextureType == TEXTURE_TYPE_2D)
            return sampleTex2Dgrad( tLayer, sLayer, vUV.xy, ddx.xy, ddy.xy );
        else if(layerSettings.b_iTextureType == TEXTURE_TYPE_CUBE)
            return sampleTexCubegrad( tLayer, sLayer, vUV.xyz, ddx.xyz, ddy.xyz );
        else if(layerSettings.b_iTextureType == TEXTURE_TYPE_VOLUME)
            return sampleTex3Dgrad( tLayer, sLayer, vUV.xyz, ddx.xyz, ddy.xyz );
    #endif
    
    return 0;
}

//--------------------------------------------------------------------------------------------------
HALF4 SampleLayerBias (
    in VertexTransport vertOut, 
    SLayerConfig layerSettings, 
    typeSampler sLayer,
    typeTexture tLayer,
    SEnvMappings envMappings, 
    bool allowEnvio,
    float bias
) {
    // use constant color
    //
    if ( layerSettings.b_iUseConstantColor )
        return layerSettings.p_cConstantColor;

    float4 vUV = GetUVEmitter(vertOut, layerSettings.b_iUVEmitter, layerSettings.p_vMultiplyAddAlphaTrans.w, layerSettings.p_mUVTransform);

    if ( allowEnvio ) {
        if ( layerSettings.b_iUVMapping == UVMAP_REFLECT_CUBICENVIO || layerSettings.b_iUVMapping == UVMAP_CUBICENVIO )
            vUV = GenEnvioUV( envMappings, layerSettings.b_iUVMapping );
        else if ( layerSettings.b_iUVMapping == UVMAP_REFLECT_SPHERICALENVIO || layerSettings.b_iUVMapping == UVMAP_SPHERICALENVIO ) 
            vUV = GenEnvioUV( envMappings, layerSettings.b_iUVMapping );
    }

    if ( layerSettings.b_iIsRTTTexture )
        vUV.xy = vUV.xy * layerSettings.p_vRTTTextureOffsetScale.zw + layerSettings.p_vRTTTextureOffsetScale.xy;

    #if textureEnum == TEXTURE_TYPE_2D
        return sampleTex2Dbias( tLayer, sLayer, float4( vUV.xyz, bias ) );
    #elif textureEnum == TEXTURE_TYPE_CUBE
        return sampleTexCubebias( tLayer, sLayer, float4( vUV.xyz, bias ) );
    #elif textureEnum == TEXTURE_TYPE_VOLUME
        return sampleTex3Dbias( tLayer, sLayer, float4( vUV.xyz, bias ) );
    #else
        if (layerSettings.b_iTextureType == TEXTURE_TYPE_2D)
            return sampleTex2Dbias( tLayer, sLayer, float4( vUV.xyz, bias ) );
        else if(layerSettings.b_iTextureType == TEXTURE_TYPE_CUBE)
            return sampleTexCubebias( tLayer, sLayer, float4( vUV.xyz, bias ) );
        else if(layerSettings.b_iTextureType == TEXTURE_TYPE_VOLUME)
            return sampleTex3Dbias( tLayer, sLayer, float4( vUV.xyz, bias ) );
    #endif
    
    return 0;
}

//--------------------------------------------------------------------------------------------------
HALF4 SampleLayerLevel (
    in VertexTransport vertOut, 
    SLayerConfig layerSettings, 
    typeSampler sLayer,
    typeTexture tLayer,
    SEnvMappings envMappings, 
    bool allowEnvio,
    float lod
) {
    // use constant color
    //
    if ( layerSettings.b_iUseConstantColor )
        return layerSettings.p_cConstantColor;

    float4 vUV = GetUVEmitter(vertOut, layerSettings.b_iUVEmitter, layerSettings.p_vMultiplyAddAlphaTrans.w, layerSettings.p_mUVTransform);

    if ( allowEnvio ) {
        if ( layerSettings.b_iUVMapping == UVMAP_REFLECT_CUBICENVIO || layerSettings.b_iUVMapping == UVMAP_CUBICENVIO )
            vUV = GenEnvioUV( envMappings, layerSettings.b_iUVMapping );
        else if ( layerSettings.b_iUVMapping == UVMAP_REFLECT_SPHERICALENVIO || layerSettings.b_iUVMapping == UVMAP_SPHERICALENVIO ) 
            vUV = GenEnvioUV( envMappings, layerSettings.b_iUVMapping );
    }

    if ( layerSettings.b_iIsRTTTexture )
        vUV.xy = vUV.xy * layerSettings.p_vRTTTextureOffsetScale.zw + layerSettings.p_vRTTTextureOffsetScale.xy;

    #if textureEnum == TEXTURE_TYPE_2D
        return sampleTex2Dlod( tLayer, sLayer, float4( vUV.xyz, lod ) );
    #elif textureEnum == TEXTURE_TYPE_CUBE
        return sampleTexCubelod( tLayer, sLayer, float4( vUV.xyz, lod ) );
    #elif textureEnum == TEXTURE_TYPE_VOLUME
        return sampleTex3Dlod( tLayer, sLayer, float4( vUV.xyz, lod ) );
    #else
        if (layerSettings.b_iTextureType == TEXTURE_TYPE_2D)
            return sampleTex2Dlod( tLayer, sLayer, float4( vUV.xyz, lod ) );
        else if(layerSettings.b_iTextureType == TEXTURE_TYPE_CUBE)
            return sampleTexCubelod( tLayer, sLayer, float4( vUV.xyz, lod ) );
        else if(layerSettings.b_iTextureType == TEXTURE_TYPE_VOLUME)
            return sampleTex3Dlod( tLayer, sLayer, float4( vUV.xyz, lod ) );
    #endif
    
    return 0;
}

//--------------------------------------------------------------------------------------------------
HALF4 ComputeLayerColor( 
    in VertexTransport vertOut, 
    SLayerConfig layerSettings, 
    typeSampler sLayer,
    typeTexture tLayer, 
    SEnvMappings envMappings, 
    HALF fMask,
    bool allowEnvio,
    HALF3 vNormal,
    inout float3x2 mTriPlanarUVs[c_maxNumLayers] 
) {
    HALF4 cColor = SampleLayer( vertOut, layerSettings, sLayer, tLayer, envMappings, allowEnvio, mTriPlanarUVs );
    return ComputeLayerColorInternal( vertOut, layerSettings, fMask, cColor, vNormal );
}

HALF4 ComputeLayerColorGrad( 
    in VertexTransport vertOut, 
    SLayerConfig layerSettings, 
    typeSampler sLayer,
    typeTexture tLayer, 
    SEnvMappings envMappings, 
    HALF fMask,
    bool allowEnvio,
    HALF3 vNormal,
    HALF4 ddx,
    HALF4 ddy
) {
    HALF4 cColor = SampleLayerGrad( vertOut, layerSettings, sLayer, tLayer, envMappings, allowEnvio, ddx, ddy );
    return ComputeLayerColorInternal( vertOut, layerSettings, fMask, cColor, vNormal );
}

HALF4 ComputeLayerColorBias( 
    in VertexTransport vertOut, 
    SLayerConfig layerSettings, 
    typeSampler sLayer,
    typeTexture tLayer, 
    SEnvMappings envMappings, 
    HALF fMask,
    bool allowEnvio,
    HALF3 vNormal,
    float bias 
) {
    HALF4 cColor = SampleLayerBias( vertOut, layerSettings, sLayer, tLayer, envMappings, allowEnvio, bias );
    return ComputeLayerColorInternal( vertOut, layerSettings, fMask, cColor, vNormal );
}

HALF4 ComputeLayerColorLevel( 
    in VertexTransport vertOut, 
    SLayerConfig layerSettings, 
    typeSampler sLayer,
    typeTexture tLayer, 
    SEnvMappings envMappings, 
    HALF fMask,
    bool allowEnvio,
    HALF3 vNormal,
    float lod
) {
    HALF4 cColor = SampleLayerLevel( vertOut, layerSettings, sLayer, tLayer, envMappings, allowEnvio, lod );
    return ComputeLayerColorInternal( vertOut, layerSettings, fMask, cColor, vNormal );
}
