class_name MapVisualStyle
extends RefCounted

## Rendering-only profiles. Pixel and woodcut preserve P0-036 evidence; the clean-painted ID remains a compatibility alias for the saturated style-lock-v1.1 production palette. None of these values may alter gameplay geometry.

const TARGET_PIXEL := &"pixel"
const TARGET_WOODCUT := &"digital_woodcut"
const TARGET_CLEAN_PAINTED := &"clean_painted"
const TIME_DAY := &"day"
const TIME_NIGHT := &"night"

const ALL_TARGETS: Array[StringName] = [TARGET_PIXEL, TARGET_WOODCUT, TARGET_CLEAN_PAINTED]
const ALL_TIMES: Array[StringName] = [TIME_DAY, TIME_NIGHT]

const CHARACTER_HEIGHT_PX := 64
const CHARACTER_FOOTPRINT_PX := Vector2(28.0, 20.0)
const CHARACTER_PIVOT_PX := Vector2(0.0, 18.0)


static func is_valid_target(target: StringName) -> bool:
	return target in ALL_TARGETS


static func is_valid_time(time_of_day: StringName) -> bool:
	return time_of_day in ALL_TIMES


static func terrain_color(terrain_id: StringName, target: StringName, time_of_day: StringName) -> Color:
	var day_color := Color.MAGENTA
	match target:
		TARGET_PIXEL:
			day_color = _pixel_terrain(terrain_id)
		TARGET_WOODCUT:
			day_color = _woodcut_terrain(terrain_id)
		TARGET_CLEAN_PAINTED:
			day_color = _clean_terrain(terrain_id)
	return apply_time(day_color, time_of_day, false, target)


static func role_color(role: StringName, target: StringName, time_of_day: StringName) -> Color:
	var day_color := Color.MAGENTA
	match target:
		TARGET_PIXEL:
			day_color = _pixel_role(role)
		TARGET_WOODCUT:
			day_color = _woodcut_role(role)
		TARGET_CLEAN_PAINTED:
			day_color = _clean_role(role)
	return apply_time(day_color, time_of_day, role in [&"window", &"water_highlight"], target)


static func apply_time(
	day_color: Color,
	time_of_day: StringName,
	emissive: bool = false,
	target: StringName = TARGET_CLEAN_PAINTED
) -> Color:
	if time_of_day == TIME_DAY:
		return day_color
	if target != TARGET_CLEAN_PAINTED:
		if emissive:
			return day_color.lerp(Color8(238, 177, 92), 0.58)
		var legacy_night := Color(day_color.r * 0.43, day_color.g * 0.50, day_color.b * 0.66, day_color.a)
		return legacy_night.lerp(Color8(25, 35, 58, day_color.a8), 0.20)
	if emissive:
		return day_color.lerp(Color8(255, 210, 122), 0.65)
	# Colorful indigo night preserves local hue instead of restoring the old gray wash.
	# Calibration keeps more of the day master so outdoor night does not crush to black.
	var night := Color(day_color.r * 0.64, day_color.g * 0.68, day_color.b * 0.80, day_color.a)
	return night.lerp(Color8(36, 48, 96, day_color.a8), 0.10)


static func outline_width(target: StringName) -> float:
	match target:
		TARGET_PIXEL:
			return 2.0
		TARGET_WOODCUT:
			return 3.0
		_:
			return 1.0


static func terrain_patch_size(target: StringName) -> float:
	match target:
		TARGET_PIXEL:
			return 4.0
		TARGET_WOODCUT:
			return 8.0
		_:
			return 16.0


static func shadow_offset(target: StringName) -> Vector2:
	match target:
		TARGET_PIXEL:
			return Vector2(6.0, 6.0)
		TARGET_WOODCUT:
			return Vector2(8.0, 7.0)
		_:
			return Vector2(7.0, 6.0)


static func shadow_alpha(target: StringName, time_of_day: StringName) -> float:
	var day_alpha := 0.32
	match target:
		TARGET_WOODCUT:
			day_alpha = 0.44
		TARGET_CLEAN_PAINTED:
			day_alpha = 0.22
	return day_alpha * (0.72 if time_of_day == TIME_NIGHT else 1.0)


static func rules_signature(target: StringName, time_of_day: StringName) -> String:
	return "%s:%s:height=%d:pivot=%s:outline=%.1f:shadow=%s@%.2f" % [
		String(target),
		String(time_of_day),
		CHARACTER_HEIGHT_PX,
		str(CHARACTER_PIVOT_PX),
		outline_width(target),
		str(shadow_offset(target)),
		shadow_alpha(target, time_of_day),
	]


static func _pixel_terrain(terrain_id: StringName) -> Color:
	match terrain_id:
		MapTypes.TERRAIN_GRASS: return Color8(86, 111, 64)
		MapTypes.TERRAIN_SAND: return Color8(185, 151, 91)
		MapTypes.TERRAIN_HAY: return Color8(196, 153, 55)
		MapTypes.TERRAIN_DIRT: return Color8(112, 78, 57)
		MapTypes.TERRAIN_COBBLESTONE: return Color8(92, 88, 82)
		MapTypes.TERRAIN_WATER: return Color8(52, 103, 124)
		MapTypes.TERRAIN_RIVER_WATER: return Color8(66, 122, 152)
		MapTypes.TERRAIN_STONE: return Color8(132, 130, 120)
		MapTypes.TERRAIN_ASH: return Color8(96, 92, 88)
		MapTypes.TERRAIN_TIMBER_FLOOR: return Color8(118, 82, 52)
		MapTypes.TERRAIN_PLASTER: return Color8(188, 168, 132)
		_: return Color.MAGENTA


static func _woodcut_terrain(terrain_id: StringName) -> Color:
	match terrain_id:
		MapTypes.TERRAIN_GRASS: return Color8(112, 119, 75)
		MapTypes.TERRAIN_SAND: return Color8(190, 164, 113)
		MapTypes.TERRAIN_HAY: return Color8(174, 140, 62)
		MapTypes.TERRAIN_DIRT: return Color8(125, 91, 67)
		MapTypes.TERRAIN_COBBLESTONE: return Color8(102, 96, 86)
		MapTypes.TERRAIN_WATER: return Color8(66, 99, 105)
		MapTypes.TERRAIN_RIVER_WATER: return Color8(74, 118, 138)
		MapTypes.TERRAIN_STONE: return Color8(145, 136, 116)
		MapTypes.TERRAIN_ASH: return Color8(104, 98, 92)
		MapTypes.TERRAIN_TIMBER_FLOOR: return Color8(122, 86, 56)
		MapTypes.TERRAIN_PLASTER: return Color8(198, 178, 140)
		_: return Color.MAGENTA


static func _clean_terrain(terrain_id: StringName) -> Color:
	match terrain_id:
		MapTypes.TERRAIN_GRASS: return Color8(79, 149, 79)
		MapTypes.TERRAIN_SAND: return Color8(210, 167, 94)
		MapTypes.TERRAIN_HAY: return Color8(227, 184, 63)
		MapTypes.TERRAIN_DIRT: return Color8(154, 90, 63)
		MapTypes.TERRAIN_COBBLESTONE: return Color8(127, 145, 161)
		MapTypes.TERRAIN_WATER: return Color8(22, 143, 170)
		MapTypes.TERRAIN_RIVER_WATER: return Color8(24, 127, 183)
		MapTypes.TERRAIN_STONE: return Color8(158, 173, 185)
		MapTypes.TERRAIN_ASH: return Color8(107, 108, 126)
		MapTypes.TERRAIN_TIMBER_FLOOR: return Color8(107, 63, 53)
		MapTypes.TERRAIN_PLASTER: return Color8(231, 201, 142)
		_: return Color.MAGENTA


static func _pixel_role(role: StringName) -> Color:
	match role:
		&"ink": return Color8(32, 25, 23)
		&"soot": return Color8(48, 42, 36)
		&"plaster": return Color8(180, 157, 119)
		&"timber": return Color8(72, 47, 36)
		&"roof": return Color8(91, 51, 43)
		&"stone": return Color8(126, 125, 118)
		&"metal": return Color8(65, 72, 75)
		&"wood": return Color8(103, 66, 40)
		&"hay": return Color8(197, 153, 55)
		&"window": return Color8(99, 151, 166)
		&"water_highlight": return Color8(89, 163, 179)
		&"character_cloth": return Color8(166, 58, 47)
		&"character_skin": return Color8(205, 157, 111)
		&"character_apron": return Color8(79, 91, 91)
		&"ember": return Color8(214, 98, 42)
		&"flower": return Color8(196, 108, 132)
		&"vegetation": return Color8(72, 104, 58)
		_: return Color.MAGENTA


static func _woodcut_role(role: StringName) -> Color:
	match role:
		&"ink": return Color8(38, 29, 24)
		&"soot": return Color8(52, 44, 36)
		&"plaster": return Color8(205, 184, 142)
		&"timber": return Color8(62, 45, 34)
		&"roof": return Color8(83, 53, 40)
		&"stone": return Color8(145, 136, 116)
		&"metal": return Color8(52, 55, 52)
		&"wood": return Color8(91, 62, 39)
		&"hay": return Color8(178, 142, 62)
		&"window": return Color8(97, 125, 122)
		&"water_highlight": return Color8(103, 142, 143)
		&"character_cloth": return Color8(151, 49, 42)
		&"character_skin": return Color8(195, 156, 111)
		&"character_apron": return Color8(69, 75, 68)
		&"ember": return Color8(196, 88, 38)
		&"flower": return Color8(176, 96, 118)
		&"vegetation": return Color8(68, 96, 54)
		_: return Color.MAGENTA


static func _clean_role(role: StringName) -> Color:
	match role:
		&"ink": return Color8(23, 27, 42)
		&"soot": return Color8(48, 39, 55)
		&"plaster": return Color8(231, 201, 142)
		&"timber": return Color8(107, 63, 53)
		&"roof": return Color8(185, 74, 61)
		&"stone": return Color8(158, 173, 185)
		&"metal": return Color8(57, 76, 101)
		&"wood": return Color8(162, 105, 63)
		&"hay": return Color8(227, 184, 63)
		&"window": return Color8(88, 199, 232)
		&"water_highlight": return Color8(70, 199, 216)
		&"character_cloth": return Color8(217, 54, 77)
		&"character_skin": return Color8(224, 160, 117)
		&"character_apron": return Color8(64, 82, 123)
		&"ember": return Color8(240, 161, 62)
		&"flower": return Color8(201, 74, 155)
		&"vegetation": return Color8(79, 149, 79)
		_: return Color.MAGENTA
