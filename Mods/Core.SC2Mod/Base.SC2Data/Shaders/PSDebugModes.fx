//==================================================================================================
//
// Copyright Blizzard Entertainment 2003-2005
//
//==================================================================================================

#ifndef PS_DEBUGMODES
#define PS_DEBUGMODES

#ifdef PIXEL_SHADER

#include "ShaderSystem.fx"

// Debug modes
#define NO_DEBUG                    0
#define FULLBRIGHT_DIFFUSE_ONLY     1
#define DIFFUSE_ONLY                2
#define SPECULAR_ONLY               3
#define LIGHTING_ONLY               4
#define DIFFUSE_LIGHTING_ONLY       5
#define SPECULAR_LIGHTING_ONLY      6
#define EMISSIVE_ONLY               7
#define ALPHAMASK_ONLY              8
#define NORMALS_ONLY                9
#define NORMALMAP_ONLY              10
#define SHADOWS_ONLY                11
#define SHOW_PROBLEMS               12
#define AMBIENT_OCCLUSION_ONLY      13
#define LIGHTING_OVERLAP			14
#define TEXEL_DENSITY               15
#define UV_MAPPING      			16
#define OVERDRAW			        17
#define LIGHT_COUNT					18
#define STATIC_SHADOW_STATUS        19

#endif  // PIXEL_SHADER

#endif  // PS_DEBUGMODES