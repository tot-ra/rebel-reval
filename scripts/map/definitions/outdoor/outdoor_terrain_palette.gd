class_name OutdoorTerrainPalette
extends RefCounted

## Outdoor-only material colors. IDs are shared MapTypes; this helper keeps the
## saturated style-lock-v1.1 stable while outdoor renderers retain historically plausible ground.


static func color(terrain: StringName) -> Color:
	match terrain:
		MapTypes.TERRAIN_GRASS:
			return Color8(79, 149, 79)
		MapTypes.TERRAIN_MEADOW:
			return Color8(114, 175, 78)
		MapTypes.TERRAIN_SAND:
			return Color8(210, 167, 94)
		MapTypes.TERRAIN_COAST_SAND:
			return Color8(200, 162, 106)
		MapTypes.TERRAIN_HAY:
			return Color8(227, 184, 63)
		MapTypes.TERRAIN_STRAW:
			return Color8(201, 151, 50)
		# Reval streets are packed earth over limestone rubble and building waste, not
		# tropical laterite. The former saturated terracotta read as red clay desert at
		# gameplay range; a grey-ochre keeps the historical limestone-dust street tone
		# while the earth pattern supplies the hue variation the flat fill was missing.
		MapTypes.TERRAIN_DIRT:
			return Color8(106, 97, 84)
		MapTypes.TERRAIN_FARM_SOIL:
			return Color8(94, 78, 60)
		MapTypes.TERRAIN_MUD:
			return Color8(86, 77, 65)
		MapTypes.TERRAIN_FOREST_FLOOR:
			return Color8(52, 101, 62)
		MapTypes.TERRAIN_BOG:
			return Color8(49, 93, 80)
		# Blue-gray variation keeps stone colorful without turning paving into painted tile.
		MapTypes.TERRAIN_COBBLESTONE:
			return Color8(127, 145, 161)
		MapTypes.TERRAIN_CASTLE_PAVING:
			return Color8(141, 160, 176)
		MapTypes.TERRAIN_WATER:
			return Color8(22, 143, 170)
		# The Pirita must read as a proper blue river, not a green-tinted shallow.
		# Pull green well below blue so neither the palette nor the bed seen through
		# the clear current casts an algae-like hue on the wide meanders.
		MapTypes.TERRAIN_RIVER_WATER:
			return Color8(24, 127, 183)
		MapTypes.TERRAIN_SHALLOW_WATER:
			return Color8(45, 168, 196)
		MapTypes.TERRAIN_DEEP_WATER:
			return Color8(20, 92, 131)
		# Tallinn building stone is warm grey limestone, not the blue granite the
		# earlier tint implied. Keeping it close to the paving value also stops
		# stone aprons from flaring against the street they sit in.
		MapTypes.TERRAIN_STONE:
			return Color8(150, 145, 133)
		_:
			return TerrainPalette.base_color(terrain)
