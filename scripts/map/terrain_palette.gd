class_name TerrainPalette
extends RefCounted

## Base colors and deterministic procedural accents for terrain IDs.


static func base_color(terrain_id: StringName) -> Color:
	match terrain_id:
		MapTypes.TERRAIN_GRASS:
			return Color(0.32, 0.52, 0.28, 1.0)
		MapTypes.TERRAIN_SAND:
			return Color(0.82, 0.72, 0.46, 1.0)
		MapTypes.TERRAIN_HAY:
			return Color(0.78, 0.66, 0.18, 1.0)
		MapTypes.TERRAIN_DIRT:
			return Color(0.45, 0.32, 0.22, 1.0)
		MapTypes.TERRAIN_COBBLESTONE:
			return Color(0.46, 0.44, 0.42, 1.0)
		MapTypes.TERRAIN_WATER:
			return Color(0.22, 0.38, 0.62, 1.0)
		MapTypes.TERRAIN_STONE:
			return Color(0.56, 0.58, 0.62, 1.0)
		_:
			return Color.MAGENTA


static func cell_hash(cell: Vector2i, seed: int, terrain_id: StringName) -> int:
	var terrain_salt := int(terrain_id.hash())
	return ((cell.x * 374761393) + (cell.y * 668265263) + seed + terrain_salt) & 0x7fffffff


static func accent_offset(cell: Vector2i, seed: int, terrain_id: StringName) -> Vector2:
	var hash := cell_hash(cell, seed, terrain_id)
	var angle := float(hash % 360) * (TAU / 360.0)
	var radius := float((hash >> 8) % 5) + 1.0
	return Vector2(cos(angle), sin(angle)) * radius


static func pattern_color(terrain_id: StringName, cell: Vector2i, local: Vector2, seed: int) -> Color:
	var base := base_color(terrain_id)
	var hash := cell_hash(cell, seed, terrain_id)
	var accent_strength := 0.08 + float(hash % 7) * 0.01

	match terrain_id:
		MapTypes.TERRAIN_GRASS:
			if fmod(float(hash) + local.x + local.y * 3.0, 5.0) < 1.2:
				return base.lightened(accent_strength)
			return base.darkened(accent_strength * 0.5)
		MapTypes.TERRAIN_SAND:
			var grain := fmod(float(hash) + local.x * 1.7 + local.y * 2.3, 3.0)
			if grain < 0.8:
				return base.lightened(0.10)
			if grain > 2.2:
				return base.darkened(0.08)
			return base
		MapTypes.TERRAIN_HAY:
			if int(local.y + hash % 3) % 3 == 0:
				return base.lightened(0.16)
			if int(local.x + local.y * 2.0) % 5 == 0:
				return Color(0.70, 0.58, 0.14, 1.0)
			return base.darkened(0.06)
		MapTypes.TERRAIN_DIRT:
			if hash % 9 < 3:
				return base.lightened(0.06)
			return base.darkened(0.05)
		MapTypes.TERRAIN_COBBLESTONE:
			var pebble := Vector2i(int(local.x / 5.0), int(local.y / 5.0))
			var pebble_hash := cell_hash(cell + pebble, seed, terrain_id)
			var pebble_phase := fmod(float(pebble_hash % 16), 16.0)
			if pebble_phase < 4.0:
				return base.lightened(0.10)
			if pebble_phase > 12.0:
				return base.darkened(0.10)
			return base.lightened(0.02)
		MapTypes.TERRAIN_WATER:
			if int(local.y + hash % 5) % 6 < 2:
				return base.lightened(0.10)
			return base.darkened(0.04)
		MapTypes.TERRAIN_STONE:
			var slab := Vector2i(int(local.x / 12.0), int(local.y / 12.0))
			var slab_hash := cell_hash(cell + slab, seed, terrain_id)
			if slab_hash % 5 == 0:
				return base.lightened(0.08)
			if (int(local.x) + int(local.y)) % 12 < 2:
				return base.darkened(0.14)
			return base.darkened(0.03)
		_:
			return base
