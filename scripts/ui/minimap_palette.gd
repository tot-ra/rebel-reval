class_name MinimapPalette
extends RefCounted

## Semantic terrain colors for the minimap. Uses readable value contrast rather
## than art-bible textures so the HUD stays useful before P0-040 lands.


static func color_for_cell(
	definition: MapDefinition,
	grid: MapTerrainGrid,
	cell: Vector2i,
	blocked: Dictionary
) -> Color:
	if blocked.has(cell):
		return Color(0.22, 0.2, 0.18, 1.0)

	var terrain := grid.get_terrain(cell)
	if MapTypes.WATER_TERRAINS.has(terrain):
		return Color(0.18, 0.38, 0.62, 1.0)

	match terrain:
		MapTypes.TERRAIN_COBBLESTONE, MapTypes.TERRAIN_CASTLE_PAVING, MapTypes.TERRAIN_STONE:
			return Color(0.52, 0.5, 0.46, 1.0)
		MapTypes.TERRAIN_DIRT, MapTypes.TERRAIN_MUD, MapTypes.TERRAIN_FARM_SOIL, MapTypes.TERRAIN_ASH:
			return Color(0.45, 0.34, 0.22, 1.0)
		MapTypes.TERRAIN_TIMBER_FLOOR, MapTypes.TERRAIN_PLASTER, MapTypes.TERRAIN_STRAW, MapTypes.TERRAIN_HAY:
			return Color(0.58, 0.5, 0.38, 1.0)
		MapTypes.TERRAIN_SAND, MapTypes.TERRAIN_COAST_SAND:
			return Color(0.72, 0.66, 0.42, 1.0)
		MapTypes.TERRAIN_FOREST_FLOOR, MapTypes.TERRAIN_BOG:
			return Color(0.28, 0.38, 0.22, 1.0)
		_:
			return Color(0.34, 0.48, 0.28, 1.0)


static func transition_color() -> Color:
	return Color(0.92, 0.78, 0.28, 1.0)
