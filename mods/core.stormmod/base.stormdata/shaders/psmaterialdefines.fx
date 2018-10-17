//==================================================================================================
//
// Copyright Blizzard Entertainment 2003-2005
//
// This is the shader code for models.
//==================================================================================================

#ifndef PS_MATERIAL_DEFINES
#define PS_MATERIAL_DEFINES

#ifdef PIXEL_SHADER

//==================================================================================================
// Enums

// Color sources.
#define COLORSRC_SAMPLER        0
#define COLORSRC_CUBESAMPLER    1
#define COLORSRC_CONSTANT       2

// Material types.
#define MATERIALTYPE_GLOSS          0
#define MATERIALTYPE_EMISSIVE       1
#define MATERIALTYPE_ENVIO          2
#define MATERIALTYPE_MASK           3

// Material classes.
#define MATERIALCLASS_UNIT          0
#define MATERIALCLASS_BUILDING      1
#define MATERIALCLASS_DOODAD        2
#define MATERIALCLASS_SPECIALFX     3

// Layer operations.
#define LAYEROP_MOD						0
#define LAYEROP_MOD2X					1
#define LAYEROP_ADD						2
#define LAYEROP_LERP					3
#define LAYEROP_TEAMCOLOR_EMISSIVE_ADD  4
#define LAYEROP_TEAMCOLOR_DIFFUSE_ADD   5
#define LAYEROP_ADD_NO_ALPHA			6

// Channel selectors.
#define CHANNELSELECT_RGB           0
#define CHANNELSELECT_RGBA          1
#define CHANNELSELECT_A             2
#define CHANNELSELECT_R             3
#define CHANNELSELECT_G             4
#define CHANNELSELECT_B             5

// Specularity types.
#define SPECULAR_RGB                0
#define SPECULAR_A_ONLY             1

// Debug render modes
#define NO_DEBUG_RENDER_MODE        0
#define RENDER_TANGENTS_MODE        1
#define RENDER_NO_HITTESTTIGHT_MODE 2
#define RENDER_NO_HITTESTFUZZY_MODE 3

// Fresnel modes
#define FRESNELMODE_NONE            0
#define FRESNELMODE_STANDARD        1
#define FRESNELMODE_INVERTED        2

//--------------------------------------------------------------------------------------------------
HALF4 ChooseChannel( int iChannelSelect, HALF4 cResult ) {
	if ( iChannelSelect == CHANNELSELECT_R )
	    cResult = cResult.rrrr;
	else if ( iChannelSelect == CHANNELSELECT_G )
	    cResult = cResult.gggg;
	else if ( iChannelSelect == CHANNELSELECT_B )
	    cResult = cResult.bbbb;
	else if ( iChannelSelect == CHANNELSELECT_A )
	    cResult = cResult.aaaa;
	else if ( iChannelSelect == CHANNELSELECT_RGB )
        cResult.a = 1;
	return cResult;
}

#endif  // PIXEL_SHADER

#endif  // PS_MATERIAL_DEFINES