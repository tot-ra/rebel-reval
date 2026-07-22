class_name MapVisualStyle
extends RefCounted

## Rendering-only profiles for P0-036. None of these values may alter gameplay geometry.

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
	return apply_time(day_color, time_of_day)


static func role_color(role: StringName, target: StringName, time_of_day: StringName) -> Color:
	var day_color := Color.MAGENTA
	match target:
		TARGET_PIXEL:
			day_color = _pixel_role(role)
		TARGET_WOODCUT:
			day_color = _woodcut_role(role)
		TARGET_CLEAN_PAINTED:
			day_color = _clean_role(role)
	return apply_time(day_color, time_of_day, role in [&"window", &"water_highlight"])


static func apply_time(day_color: Color, time_of_day: StringName, emissive: bool = false) -> Color:
	if time_of_day == TIME_DAY:
		return day_color
	if emissive:
		return day_color.lerp(Color8(238, 177, 92), 0.58)
	# Night shifts every profile toward moonlit blue while retaining terrain recognition.
	var night := Color(day_color.r * 0.43, day_color.g * 0.50, day_color.b * 0.66, day_color.a)
	return night.lerp(Color8(25, 35, 58, day_color.a8), 0.20)


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
		MapTypes.TERRAIN_COBBLESTONE: return Color8(112, 107, 101)
		MapTypes.TERRAIN_WATER: return Color8(52, 103, 124)
		MapTypes.TERRAIN_RIVER_WATER: return Color8(76, 137, 160)
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
		MapTypes.TERRAIN_COBBLESTONE: return Color8(126, 119, 105)
		MapTypes.TERRAIN_WATER: return Color8(66, 99, 105)
		MapTypes.TERRAIN_RIVER_WATER: return Color8(84, 128, 139)
		MapTypes.TERRAIN_STONE: return Color8(145, 136, 116)
		MapTypes.TERRAIN_ASH: return Color8(104, 98, 92)
		MapTypes.TERRAIN_TIMBER_FLOOR: return Color8(122, 86, 56)
		MapTypes.TERRAIN_PLASTER: return Color8(198, 178, 140)
		_: return Color.MAGENTA


static func _clean_terrain(terrain_id: StringName) -> Color:
	match terrain_id:
		MapTypes.TERRAIN_GRASS: return Color8(93, 126, 78)
		MapTypes.TERRAIN_SAND: return Color8(199, 171, 112)
		MapTypes.TERRAIN_HAY: return Color8(205, 164, 68)
		MapTypes.TERRAIN_DIRT: return Color8(124, 88, 65)
		MapTypes.TERRAIN_COBBLESTONE: return Color8(126, 125, 121)
		MapTypes.TERRAIN_WATER: return Color8(58, 116, 143)
		MapTypes.TERRAIN_RIVER_WATER: return Color8(83, 145, 169)
		MapTypes.TERRAIN_STONE: return Color8(147, 147, 139)
		MapTypes.TERRAIN_ASH: return Color8(108, 104, 98)
		MapTypes.TERRAIN_TIMBER_FLOOR: return Color8(126, 88, 58)
		MapTypes.TERRAIN_PLASTER: return Color8(205, 184, 146)
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
		&"ink": return Color8(43, 38, 36)
		&"soot": return Color8(58, 51, 43)
		&"plaster": return Color8(205, 184, 146)
		&"timber": return Color8(83, 55, 42)
		&"roof": return Color8(111, 59, 49)
		&"stone": return Color8(145, 145, 137)
		&"metal": return Color8(70, 79, 82)
		&"wood": return Color8(119, 77, 45)
		&"hay": return Color8(205, 164, 68)
		&"window": return Color8(104, 158, 177)
		&"water_highlight": return Color8(101, 177, 196)
		&"character_cloth": return Color8(178, 61, 49)
		&"character_skin": return Color8(216, 169, 123)
		&"character_apron": return Color8(83, 99, 101)
		&"ember": return Color8(224, 108, 48)
		&"flower": return Color8(204, 112, 138)
		&"vegetation": return Color8(78, 112, 64)
		_: return Color.MAGENTA
