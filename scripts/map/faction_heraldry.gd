class_name FactionHeraldry
extends RefCounted

## Readable faction cloth for towers, courtyard banners, and ship mastheads.
## Geometric charges stay legible on small pennants without heraldic textures.
##
## Brand source of truth: `scenes/menu/logo.png` (Rebel Reval shield).
## Quadrants map to cloth ids as follows:
## - TL red + white cross -> danish_crown
## - BL white + black cross -> livonian_order
## - TR white + dark swallow -> black_cloaks
## - BR azure + black bear + gold lynx -> novgorod / pskov (joint: pskov_novgorod)
## Hanseatic pale is period merchant cloth, not a logo quadrant.
## vitalienbruder: no flag by design.

const DANISH_CROWN := &"danish_crown"
const LIVONIAN_ORDER := &"livonian_order"
const HANSEATIC := &"hanseatic"
const HARJU_KINGS := &"harju_kings"
const BLACK_CLOAKS := &"black_cloaks"
const CULT_METSIK := &"cult_metsik"
## Ledger umbrella for eastern emissaries. Prefer `novgorod` / `pskov` when
## the map should show the animal charge.
const PSKOV_NOVGOROD := &"pskov_novgorod"
const NOVGOROD := &"novgorod"
const PSKOV := &"pskov"
const VITALIENBRUDER := &"vitalienbruder"

const ALL_FACTIONS: Array[StringName] = [
	DANISH_CROWN,
	LIVONIAN_ORDER,
	HANSEATIC,
	HARJU_KINGS,
	BLACK_CLOAKS,
	CULT_METSIK,
	PSKOV_NOVGOROD,
	NOVGOROD,
	PSKOV,
	VITALIENBRUDER,
]

## Roster markers for docs and UI. Vocabulary matches `characters/README.md`
## and charge motifs from `pattern_for` (cross, swallow, bear, lynx). Vitalienbrüder
## fly no in-game cloth but use the pirate roster emoji in text.
const FACTION_FLAG_EMOJI: Dictionary = {
	DANISH_CROWN: "🇩🇰",
	LIVONIAN_ORDER: "✠", # Teutonic cross (characters/README)
	HANSEATIC: "🇪🇺", # Hanseatic league (characters/README)
	HARJU_KINGS: "✊", # rural rebellion (characters/README rebel block)
	BLACK_CLOAKS: "🐦", # swallow charge on white field
	CULT_METSIK: "🍀", # old ways / sacred groves (characters/README)
	PSKOV_NOVGOROD: "🐻🐆", # joint east emissaries: bear + lynx charges
	NOVGOROD: "🐻", # bear charge
	PSKOV: "🐆", # lynx charge
	VITALIENBRUDER: "🏴‍☠️", # no cloth by design; roster marker only
}

const PATTERN_SOLID := &"solid"
const PATTERN_CROSS := &"cross"
const PATTERN_PALE := &"pale"
const PATTERN_FESS := &"fess"
const PATTERN_BEAR := &"bear"
const PATTERN_LYNX := &"lynx"
## Logo BR quadrant: black bear behind a gold lynx on one azure field.
const PATTERN_BEAR_LYNX := &"bear_lynx"
const PATTERN_SWALLOW := &"swallow"
const PATTERN_NONE := &"none"

## Sparse allowlist: only landmark towers fly cloth when the map omits faction=.
## Ordinary wall.tower styles stay bare so the skyline is not a forest of poles.
## Prefer explicit faction= on the few seats that need identity (keep, gate, guild).
const BUILDING_DEFAULTS: Dictionary = {
	&"castle_keep_tower": DANISH_CROWN,
	&"pikk_jalg_gate_tower": DANISH_CROWN,
	&"pikk_jalg_gate_east_tower": DANISH_CROWN,
	&"monastery_wall_tower_northwest": DANISH_CROWN,
	&"coast_gate_west_tower": DANISH_CROWN,
	&"merchant_wall_tower_northwest": HANSEATIC,
	&"viru_gate_north_tower": DANISH_CROWN,
	&"viru_gate_south_tower": DANISH_CROWN,
	&"center_gate_north_tower": DANISH_CROWN,
	&"center_gate_south_tower": DANISH_CROWN,
}


static func is_known(faction_id: StringName) -> bool:
	return String(faction_id).is_empty() or ALL_FACTIONS.has(faction_id)


static func flag_emoji(faction_id: StringName) -> String:
	return String(FACTION_FLAG_EMOJI.get(faction_id, ""))


static func resolve(source: Dictionary) -> StringName:
	if source.has("faction"):
		return StringName(source["faction"])
	var object_id := StringName(source.get("id", &""))
	if BUILDING_DEFAULTS.has(object_id):
		return BUILDING_DEFAULTS[object_id]
	return &""


static func shows_flag(faction_id: StringName) -> bool:
	# Empty / unknown ids must not plant bare staffs or municipal cloth.
	if String(faction_id).is_empty():
		return false
	return pattern_for(faction_id) != PATTERN_NONE


static func pattern_for(faction_id: StringName) -> StringName:
	match faction_id:
		DANISH_CROWN, LIVONIAN_ORDER:
			return PATTERN_CROSS
		HANSEATIC:
			return PATTERN_PALE
		PSKOV_NOVGOROD:
			# Logo BR quadrant: both animals on one azure cloth.
			return PATTERN_BEAR_LYNX
		NOVGOROD:
			return PATTERN_BEAR
		PSKOV:
			return PATTERN_LYNX
		BLACK_CLOAKS:
			return PATTERN_SWALLOW
		HARJU_KINGS, CULT_METSIK:
			return PATTERN_SOLID
		VITALIENBRUDER, _:
			return PATTERN_NONE


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
			# Logo TR: white field behind the swallow.
			return Color8(242, 242, 240)
		CULT_METSIK:
			return Color8(64, 78, 42)
		PSKOV_NOVGOROD, NOVGOROD, PSKOV:
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
			# Logo TR: dark swallow on white field.
			return Color8(28, 42, 78)
		CULT_METSIK:
			return Color8(120, 92, 48)
		NOVGOROD:
			# Logo BR: black bear.
			return Color8(28, 28, 30)
		PSKOV, PSKOV_NOVGOROD:
			# Logo BR: gold lynx (primary charge when both animals share cloth).
			return Color8(228, 198, 72)
		_:
			return Color8(232, 228, 220)


## Secondary charge for joint east cloth (logo black bear behind the lynx).
static func secondary_charge_color(faction_id: StringName) -> Color:
	if faction_id == PSKOV_NOVGOROD:
		return Color8(28, 28, 30)
	return charge_color(faction_id)


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
		PATTERN_BEAR:
			return charge if _in_bear(uv) else field
		PATTERN_LYNX:
			return charge if _in_lynx(uv) else field
		PATTERN_BEAR_LYNX:
			# Logo stacking: lynx in front wins over the bear silhouette.
			if _in_lynx(uv, Vector2(0.04, -0.02)):
				return charge
			if _in_bear(uv, Vector2(-0.06, 0.04)):
				return secondary_charge_color(faction_id)
			return field
		PATTERN_SWALLOW:
			return charge if _in_swallow(uv) else field
		_:
			return field


## Triangular tower / mast pennant. UV.x = 0 at the hoist for cloth wind.
## Subdivided so cross / pale / beast charges stay readable after vertex-color interp.
static func pennant_mesh(faction_id: StringName) -> ArrayMesh:
	var density := _mesh_density(faction_id)
	var cols := density.x
	var rows := density.y
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hoist_top := Vector3(0.0, 0.12, 0.0)
	var hoist_bottom := Vector3(0.0, -0.42, 0.0)
	var fly := Vector3(0.95, -0.12, 0.0)
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
	var density := _mesh_density(faction_id)
	var cols := density.x
	var rows := density.y
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
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


static func _mesh_density(faction_id: StringName) -> Vector2i:
	match pattern_for(faction_id):
		PATTERN_BEAR, PATTERN_LYNX, PATTERN_SWALLOW:
			return Vector2i(10, 12)
		PATTERN_CROSS:
			return Vector2i(5, 6)
		_:
			return Vector2i(4, 5)


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


## Simplified rampant bear facing the fly edge. Tuned for ~10x12 pennant grids.
## Optional offset shifts the silhouette (joint east cloth puts the bear back-left).
static func _in_bear(uv: Vector2, offset: Vector2 = Vector2.ZERO) -> bool:
	uv -= offset
	if _in_ellipse(uv, Vector2(0.46, 0.58), Vector2(0.17, 0.20)):
		return true
	if _in_ellipse(uv, Vector2(0.62, 0.30), Vector2(0.11, 0.10)):
		return true
	if _in_ellipse(uv, Vector2(0.72, 0.33), Vector2(0.07, 0.045)):
		return true
	if _in_ellipse(uv, Vector2(0.57, 0.20), Vector2(0.045, 0.05)):
		return true
	if _in_ellipse(uv, Vector2(0.66, 0.21), Vector2(0.04, 0.045)):
		return true
	# Raised foreleg and planted legs.
	if _in_oriented_box(uv, Vector2(0.58, 0.48), Vector2(0.16, 0.05), -0.55):
		return true
	if _in_oriented_box(uv, Vector2(0.40, 0.78), Vector2(0.05, 0.14), 0.15):
		return true
	if _in_oriented_box(uv, Vector2(0.52, 0.78), Vector2(0.05, 0.14), -0.1):
		return true
	return false


## Feline "fierce beast" facing the fly: longer legs, tufted ears, short tail.
static func _in_lynx(uv: Vector2, offset: Vector2 = Vector2.ZERO) -> bool:
	uv -= offset
	if _in_ellipse(uv, Vector2(0.48, 0.55), Vector2(0.18, 0.14)):
		return true
	if _in_ellipse(uv, Vector2(0.66, 0.34), Vector2(0.10, 0.09)):
		return true
	# Tufted ears.
	if _in_ellipse(uv, Vector2(0.60, 0.22), Vector2(0.035, 0.06)):
		return true
	if _in_ellipse(uv, Vector2(0.70, 0.22), Vector2(0.035, 0.06)):
		return true
	if _in_oriented_box(uv, Vector2(0.40, 0.76), Vector2(0.04, 0.16), 0.05):
		return true
	if _in_oriented_box(uv, Vector2(0.50, 0.76), Vector2(0.04, 0.16), -0.05):
		return true
	if _in_oriented_box(uv, Vector2(0.58, 0.74), Vector2(0.035, 0.14), -0.2):
		return true
	# Short lynx tail.
	if _in_ellipse(uv, Vector2(0.30, 0.58), Vector2(0.06, 0.035)):
		return true
	return false


## Swallow in flight: forked tail, swept wings, small head toward the fly.
static func _in_swallow(uv: Vector2) -> bool:
	# Body.
	if _in_ellipse(uv, Vector2(0.48, 0.48), Vector2(0.10, 0.055)):
		return true
	# Head.
	if _in_ellipse(uv, Vector2(0.62, 0.44), Vector2(0.055, 0.045)):
		return true
	# Wings (upper and lower sweeps).
	if _in_oriented_box(uv, Vector2(0.42, 0.30), Vector2(0.22, 0.045), -0.55):
		return true
	if _in_oriented_box(uv, Vector2(0.42, 0.66), Vector2(0.22, 0.045), 0.55):
		return true
	# Forked tail toward the hoist.
	if _in_oriented_box(uv, Vector2(0.28, 0.38), Vector2(0.14, 0.035), -0.7):
		return true
	if _in_oriented_box(uv, Vector2(0.28, 0.58), Vector2(0.14, 0.035), 0.7):
		return true
	return false


static func _in_ellipse(uv: Vector2, center: Vector2, radii: Vector2) -> bool:
	if radii.x <= 0.0 or radii.y <= 0.0:
		return false
	var d := (uv - center) / radii
	return d.length_squared() <= 1.0


static func _in_oriented_box(uv: Vector2, center: Vector2, half_extents: Vector2, angle: float) -> bool:
	var local := (uv - center).rotated(-angle)
	return absf(local.x) <= half_extents.x and absf(local.y) <= half_extents.y
