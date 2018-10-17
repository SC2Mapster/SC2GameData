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
#define SPECULAR_GLOSS              8
#define LIGHTING_REGION_MAP         9
#define ALPHAMASK_ONLY              10
#define NORMALS_ONLY                11
#define NORMALMAP_ONLY              12
#define SHADOWS_ONLY                13
#define SHOW_PROBLEMS               14
#define AMBIENT_OCCLUSION_ONLY      15
#define LIGHTING_OVERLAP			16
#define TEXEL_DENSITY               17
#define UV_MAPPING      			18
#define OVERDRAW			        19
#define LIGHT_COUNT					20
#define STATIC_SHADOW_STATUS        21

#endif  // PIXEL_SHADER

#endif  // PS_DEBUGMODES