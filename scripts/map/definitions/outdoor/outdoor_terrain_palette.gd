class_name OutdoorTerrainPalette
extends RefCounted

## Outdoor-only material colors. IDs are shared MapTypes; this helper keeps the
## approved city style stable while outdoor renderers gain historically plausible ground.


static func color(terrain: StringName) -> Color:
	match terrain:
		MapTypes.TERRAIN_GRASS: return Color8(82, 121, 61)
		MapTypes.TERRAIN_MEADOW: return Color8(102, 133, 72)
		MapTypes.TERRAIN_SAND: return Color8(199, 171, 112)
		MapTypes.TERRAIN_COAST_SAND: return Color8(184, 165, 120)
		MapTypes.TERRAIN_HAY: return Color8(205, 164, 68)
		MapTypes.TERRAIN_STRAW: return Color8(181, 143, 71)
		MapTypes.TERRAIN_DIRT: return Color8(112, 78, 54)
		MapTypes.TERRAIN_FARM_SOIL: return Color8(96, 63, 42)
		MapTypes.TERRAIN_MUD: return Color8(78, 63, 49)
		MapTypes.TERRAIN_FOREST_FLOOR: return Color8(76, 82, 54)
		MapTypes.TERRAIN_BOG: return Color8(73, 91, 69)
		MapTypes.TERRAIN_COBBLESTONE: return Color8(105, 106, 100)
		MapTypes.TERRAIN_CASTLE_PAVING: return Color8(120, 120, 111)
		MapTypes.TERRAIN_WATER: return Color8(58, 116, 143)
		MapTypes.TERRAIN_SHALLOW_WATER: return Color8(75, 137, 155)
		MapTypes.TERRAIN_DEEP_WATER: return Color8(44, 86, 116)
		MapTypes.TERRAIN_STONE: return Color8(126, 127, 118)
		_: return TerrainPalette.base_color(terrain)
