class_name FactionHeraldry
extends RefCounted

## Readable 1343-era faction cloth for towers, courtyard banners, and ship
## mastheads. Patterns stay simple (cross / pale / solid) so small pennants
## remain legible without heraldic textures. Vitalienbrüder fly no flag.

const DANISH_CROWN := &"danish_crown"
const LIVONIAN_ORDER := &"livonian_order"
const HANSEATIC := &"hanseatic"
const HARJU_KINGS := &"harju_kings"
const BLACK_CLOAKS := &"black_cloaks"
const CULT_METSIK := &"cult_metsik"
const PSKOV_NOVGOROD := &"pskov_novgorod"
const VITALIENBRUDER := &"vitalienbruder"

const ALL_FACTIONS: Array[StringName] = [
	DANISH_CROWN,
	LIVONIAN_ORDER,
	HANSEATIC,
	HARJU_KINGS,
	BLACK_CLOAKS,
	CULT_METSIK,
	PSKOV_NOVGOROD,
	VITALIENBRUDER,
]

const PATTERN_SOLID := &"solid"
const PATTERN_CROSS := &"cross"
const PATTERN_PALE := &"pale"
const PATTERN_FESS := &"fess"
const PATTERN_NONE := &"none"

## Stable building IDs that should fly a faction even when the map omits
## faction=. Keep this list short and historical; prefer authored faction=.
const BUILDING_DEFAULTS: Dictionary = {
	&"castle_keep_tower": DANISH_CROWN,
	&"pikk_jalg_gate_tower": DANISH_CROWN,
	&"pikk_jalg_gate_east_tower": DANISH_CROWN,
	&"toompea_garden_gate_west_tower": DANISH_CROWN,
	&"toompea_garden_gate_east_tower": DANISH_CROWN,
	&"monastery_wall_tower_northwest": DANISH_CROWN,
	&"monastery_wall_tower_west_mid": DANISH_CROWN,
	&"coast_gate_west_tower": DANISH_CROWN,
	&"merchant_wall_tower_northwest": HANSEATIC,
	&"viru_gate_north_tower": DANISH_CROWN,
	&"viru_gate_south_tower": DANISH_CROWN,
}


static func is_known(faction_id: StringName) -> bool:
	return String(faction_id).is_empty() or ALL_FACTIONS.has(faction_id)


static func resolve(source: Dictionary) -> StringName:
	if source.has("faction"):
		return StringName(source["faction"])
	var object_id := StringName(source.get("id", &""))
	if BUILDING_DEFAULTS.has(object_id):
		return BUILDING_DEFAULTS[object_id]
	return &""


static func shows_flag(faction_id: StringName) -> bool:
	return pattern_for(faction_id) != PATTERN_NONE


static func pattern_for(faction_id: StringName) -> StringName:
	match faction_id:
		DANISH_CROWN, LIVONIAN_ORDER:
			return PATTERN_CROSS
		HANSEATIC:
			return PATTERN_PALE
		PSKOV_NOVGOROD:
			return PATTERN_FESS
		VITALIENBRUDER:
			return PATTERN_NONE
		_:
			return PATTERN_SOLID


static func field_color(faction_id: StringName) -> Color:
	match faction_id:
		DANISH_CROWN:
			return Color8(198, 36, 40)
		LIVONIAN_ORDER:
			return Color8(236, 232, 224)
		HANSEATIC:
			return Color8(176, 44, 48)
		HARJU_KINGS:
			return Color8(52, 98, 58)
		BLACK_CLOAKS:
			return Color8(36, 34, 40)
		CULT_METSIK:
			return Color8(64, 78, 42)
		PSKOV_NOVGOROD:
			return Color8(48, 78, 148)
		VITALIENBRUDER:
			return Color8(42, 40, 38)
		_:
			# Municipal / unmarked city cloth - matches the prior generic pennant.
			return Color8(168, 52, 48)


static func charge_color(faction_id: StringName) -> Color:
	match faction_id:
		DANISH_CROWN:
			return Color8(242, 242, 240)
		LIVONIAN_ORDER:
			return Color8(28, 28, 30)
		HANSEATIC:
			return Color8(242, 240, 236)
		HARJU_KINGS:
			return Color8(212, 176, 72)
		BLACK_CLOAKS:
			return Color8(88, 84, 92)
		CULT_METSIK:
			return Color8(120, 92, 48)
		PSKOV_NOVGOROD:
			return Color8(228, 198, 72)
		_:
			return Color8(232, 228, 220)


static func color_at(faction_id: StringName, uv: Vector2) -> Color:
	var field := field_color(faction_id)
	var charge := charge_color(faction_id)
	match pattern_for(faction_id):
		PATTERN_CROSS:
			# Offset toward the hoist so a Nordic / Teutonic cross still reads on
			# a triangular fly that tapers away from the staff.
			var cx := 0.36
			var arm_x := 0.11
			var arm_y := 0.16
			if absf(uv.x - cx) <= arm_x or absf(uv.y - 0.5) <= arm_y:
				return charge
			return field
		PATTERN_PALE:
			return charge if uv.x < 0.5 else field
		PATTERN_FESS:
			return charge if uv.y < 0.5 else field
		_:
			return field


## Triangular tower / mast pennant. UV.x = 0 at the hoist for cloth wind.
## Subdivided so cross / pale charges stay readable after vertex-color interp.
static func pennant_mesh(faction_id: StringName) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hoist_top := Vector3(0.0, 0.12, 0.0)
	var hoist_bottom := Vector3(0.0, -0.42, 0.0)
	var fly := Vector3(0.95, -0.12, 0.0)
	var rows := 6
	var cols := 5
	for col in cols:
		var u0 := float(col) / float(cols)
		var u1 := float(col + 1) / float(cols)
		var top0 := hoist_top.lerp(fly, u0)
		var top1 := hoist_top.lerp(fly, u1)
		var bot0 := hoist_bottom.lerp(fly, u0)
		var bot1 := hoist_bottom.lerp(fly, u1)
		for row in rows:
			var v0 := float(row) / float(rows)
			var v1 := float(row + 1) / float(rows)
			var a := top0.lerp(bot0, v0)
			var b := top0.lerp(bot0, v1)
			var c := top1.lerp(bot1, v1)
			var d := top1.lerp(bot1, v0)
			_add_colored_quad(
				surface, faction_id,
				a, Vector2(u0, v0),
				b, Vector2(u0, v1),
				c, Vector2(u1, v1),
				d, Vector2(u1, v0)
			)
			_add_colored_quad(
				surface, faction_id,
				a, Vector2(u0, v0),
				d, Vector2(u1, v0),
				c, Vector2(u1, v1),
				b, Vector2(u0, v1)
			)
	surface.generate_normals()
	return surface.commit()


## Rectangular courtyard or facade banner hung from a vertical staff.
static func banner_mesh(faction_id: StringName, width: float = 0.72, height: float = 1.05) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols := 6
	var rows := 8
	for col in cols:
		var u0 := float(col) / float(cols)
		var u1 := float(col + 1) / float(cols)
		for row in rows:
			var v0 := float(row) / float(rows)
			var v1 := float(row + 1) / float(rows)
			var a := Vector3(width * u0, height * (0.5 - v0), 0.0)
			var b := Vector3(width * u0, height * (0.5 - v1), 0.0)
			var c := Vector3(width * u1, height * (0.5 - v1), 0.0)
			var d := Vector3(width * u1, height * (0.5 - v0), 0.0)
			_add_colored_quad(
				surface, faction_id,
				a, Vector2(u0, v0),
				b, Vector2(u0, v1),
				c, Vector2(u1, v1),
				d, Vector2(u1, v0)
			)
			_add_colored_quad(
				surface, faction_id,
				a, Vector2(u0, v0),
				d, Vector2(u1, v0),
				c, Vector2(u1, v1),
				b, Vector2(u0, v1)
			)
	surface.generate_normals()
	return surface.commit()


static func _add_colored_quad(
	surface: SurfaceTool,
	faction_id: StringName,
	a: Vector3, uv_a: Vector2,
	b: Vector3, uv_b: Vector2,
	c: Vector3, uv_c: Vector2,
	d: Vector3, uv_d: Vector2
) -> void:
	_add_colored_vertex(surface, faction_id, a, uv_a)
	_add_colored_vertex(surface, faction_id, b, uv_b)
	_add_colored_vertex(surface, faction_id, c, uv_c)
	_add_colored_vertex(surface, faction_id, a, uv_a)
	_add_colored_vertex(surface, faction_id, c, uv_c)
	_add_colored_vertex(surface, faction_id, d, uv_d)


static func _add_colored_vertex(
	surface: SurfaceTool,
	faction_id: StringName,
	vertex: Vector3,
	uv: Vector2
) -> void:
	surface.set_color(color_at(faction_id, uv))
	surface.set_uv(uv)
	surface.add_vertex(vertex)
