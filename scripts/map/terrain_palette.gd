class_name TerrainPalette
extends RefCounted

## Deterministic terrain accents constrained by the selected P0-036 visual profile.


static func base_color(
	terrain_id: StringName,
	target: StringName = MapVisualStyle.TARGET_CLEAN_PAINTED,
	time_of_day: StringName = MapVisualStyle.TIME_DAY
) -> Color:
	return MapVisualStyle.terrain_color(terrain_id, target, time_of_day)


static func cell_hash(cell: Vector2i, seed: int, terrain_id: StringName) -> int:
	var terrain_salt := int(terrain_id.hash())
	return ((cell.x * 374761393) + (cell.y * 668265263) + seed + terrain_salt) & 0x7fffffff


static func pattern_color(
	terrain_id: StringName,
	cell: Vector2i,
	local: Vector2,
	seed: int,
	target: StringName = MapVisualStyle.TARGET_CLEAN_PAINTED,
	time_of_day: StringName = MapVisualStyle.TIME_DAY,
	style_variant: StringName = &""
) -> Color:
	var base := base_color(terrain_id, target, time_of_day)
	base *= TerrainVegetation.ground_color_tint(style_variant)
	var hash := cell_hash(cell, seed, terrain_id)
	var strength := 0.06
	match target:
		MapVisualStyle.TARGET_PIXEL:
			strength = 0.11
		MapVisualStyle.TARGET_WOODCUT:
			strength = 0.14
		MapVisualStyle.TARGET_CLEAN_PAINTED:
			strength = 0.055

	match terrain_id:
		MapTypes.TERRAIN_GRASS:
			if style_variant == TerrainVegetation.VARIANT_GRASS_FLOWERS and (hash + int(local.x) + int(local.y * 2.0)) % 11 == 0:
				return base.lerp(Color8(196, 118, 142), 0.42)
			return base.lightened(strength) if (hash + int(local.x * 3.0) + int(local.y)) % 5 == 0 else base.darkened(strength * 0.35)
		MapTypes.TERRAIN_SAND:
			return base.lightened(strength * 0.75) if (hash + int(local.x + local.y * 2.0)) % 4 == 0 else base.darkened(strength * 0.20)
		MapTypes.TERRAIN_HAY:
			return base.lightened(strength) if (int(local.y) + hash) % 3 == 0 else base.darkened(strength * 0.40)
		MapTypes.TERRAIN_DIRT:
			return base.lightened(strength * 0.40) if hash % 7 < 2 else base.darkened(strength * 0.35)
		MapTypes.TERRAIN_COBBLESTONE:
			var phase := (hash + int(local.x / 4.0) * 3 + int(local.y / 4.0) * 5) % 7
			return base.lightened(strength * 0.60) if phase < 2 else base.darkened(strength * 0.35)
		MapTypes.TERRAIN_WATER:
			return base.lightened(strength) if (int(local.y) + hash) % 5 < 2 else base.darkened(strength * 0.25)
		MapTypes.TERRAIN_STONE:
			return base.darkened(strength * 0.70) if (int(local.x + local.y) + hash) % 6 == 0 else base.lightened(strength * 0.20)
		_:
			return base
