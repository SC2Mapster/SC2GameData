//==================================================================================================
//
// Copyright Blizzard Entertainment 2003-2005
//
//==================================================================================================

#ifndef _MATERIAL_DEFINES
#define _MATERIAL_DEFINES

#define SHADINGMODE_STANDARD            0
#define SHADINGMODE_DISPLACEMENT        1
#define SHADINGMODE_VECTORUI            2
#define SHADINGMODE_TERRAIN             3
#define SHADINGMODE_VOLUME              4
#define SHADINGMODE_MODEL_TRIANGLE_ID   5
#define SHADINGMODE_REFLECTION          6
#define SHADINGMODE_CLOAKING            7

// UV mappings.
#define UVMAP_EXPLICITUV0				0       // Select UV coordinate set 0.
#define UVMAP_EXPLICITUV1				1       // Select UV coordinate set 1.
#define UVMAP_REFLECT_CUBICENVIO        2       // Select cubic environment mapping.
#define UVMAP_REFLECT_SPHERICALENVIO    3       // Select spherical environment mapping.
#define UVMAP_PLANARLOCALZ				4       // Select planar local UVs.
#define UVMAP_PLANARWORLDZ				5       // Select planar world UVs.
#define UVMAP_PARTICLE_FLIPBOOK			6       // Only for particles...
#define UVMAP_CUBICENVIO				7       // Select cubic environment mapping.
#define UVMAP_SPHERICALENVIO			8       // Select spherical environment mapping.
#define UVMAP_EXPLICITUV2				9       // Select UV coordinate set 2.
#define UVMAP_EXPLICITUV3				10      // Select UV coordinate set 3.
#define UVMAP_PLANARLOCALX				11      // Select planar local UVs along X plane.
#define UVMAP_PLANARLOCALY				12      // Select planar local UVs along Y plane.
#define UVMAP_PLANARWORLDX				13      // Select planar world UVs along X plane.
#define UVMAP_PLANARWORLDY				14      // Select planar world UVs along Y plane.
#define UVMAP_SCREENSPACE               15      // Select screen-space UVs.
#define UVMAP_TRIPLANAR_LOCAL           16      // tri planar blending using normals and positions in either world or local space
#define UVMAP_TRIPLANAR_WORLD           17      // tri planar blending using normals and positions in either world or local space
#define UVMAP_TRIPLANAR_WORLD_LOCAL_Z   18

#define TriPlanarIsLocalFX(m)           ((m)==UVMAP_TRIPLANAR_LOCAL)
#define TriPlanarIsWorldFX(m)           ((m)>=UVMAP_TRIPLANAR_WORLD && (m)<=UVMAP_TRIPLANAR_WORLD_LOCAL_Z)
#define IsTriPlanarMappingFX(m)         ((m)>=UVMAP_TRIPLANAR_LOCAL && (m)<=UVMAP_TRIPLANAR_WORLD_LOCAL_Z)


#endif  // _MATERIAL_DEFINES
