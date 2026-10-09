class_name ChurchMurals
extends RefCounted

## Painted church walls (R-1396, CI-04): mural plates laid on the inner face
## of the lime-washed walls as textured quads a few millimetres proud of the
## wall (decals are not available in the GL Compatibility renderer).
##
## - Consecration crosses: the twelve crosses of a consecrated church, a cross
##   pattee in a double ring, at about 2.6 m between the windows.
## - Dado: a painted curtain at the foot of the wall with a foliage band over it,
##   on walls whose inner face is plain `limewash` (the `painted` wash material
##   paints its own dado and frieze from the same plates).
##
## Plates come from tools/build_church_mural_plates.py. Geometry is built in
## site-local space and cut at the interior cutaway height like the walls.

const PLATES := {
	"cross": "res://assets/textures/churches/murals/consecration_cross.png",
	"drapery": "res://assets/textures/churches/murals/dado_drapery.png",
	"foliage": "res://assets/textures/churches/murals/foliage_band.png",
}
const SHADER := preload("res://scripts/city/city_mural.gdshader")
const CROSS_SIZE := 0.62
const CROSS_Y := 2.6  # centre above the wall's floor
const DRAPERY_H := 1.3
const FOLIAGE_H := 0.2
## Metres of wall per plate repeat (plates are 2:1 and 8:1).
const DRAPERY_TILE := DRAPERY_H * 2.0
const FOLIAGE_TILE := FOLIAGE_H * 8.0
## Lift off the wall: enough to clear depth fighting at interior distances.
const LIFT := 0.006


## Paints the walls of `fabric` and hangs the result under the site's
## Lower/Upper nodes (split at `cut`). `crosses` are explicit cross centres
## (`[centre, into_room]` pairs); empty places twelve between the windows.
static func paint(
	lower: Node3D,
	upper: Node3D,
	site: CitySite,
	fabric: Array,
	cut: float,
	floor_y: float,
	crosses: Array = [],
	dado := true
) -> void:
	var shell := CityBuildingBuilder.Shell.new()
	for spot: Array in crosses if not crosses.is_empty() else cross_spots(fabric):
		_cross(shell, spot[0], spot[1])
	if dado:
		for w: Dictionary in fabric:
			if String(w.get("inner", "painted")) == "limewash":
				_dado(shell, w)
	var parts := shell.split_at(cut)
	var material := func(key: String) -> Material: return _material(key, site.level + floor_y)
	for k in 2:
		var part: CityBuildingBuilder.Shell = parts[k]
		var inst := MeshInstance3D.new()
		inst.name = "Murals"
		inst.mesh = part.to_mesh(material)
		if inst.mesh.get_surface_count() == 0:
			inst.free()
			continue
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(lower if k == 0 else upper).add_child(inst)


## Twelve cross centres (fewer if the walls are short): midpoints between the
## openings of the long lime-washed walls, picked evenly in fabric order.
static func cross_spots(fabric: Array, count := 12) -> Array:
	var spots: Array = []
	for w: Dictionary in fabric:
		if String(w.get("inner", "painted")) != "limewash":
			continue
		var face := _face(w)
		var marks: Array[float] = [face["s0"]]
		for op: Dictionary in w.get("openings", []):
			marks.append(float(op["s"]))
		marks.append(face["s1"])
		marks.sort()
		for i in marks.size() - 1:
			if marks[i + 1] - marks[i] < 2.2:
				continue
			var s := (marks[i] + marks[i + 1]) * 0.5
			if _blocked(w, s - CROSS_SIZE, s + CROSS_SIZE, CROSS_Y + CROSS_SIZE):
				continue
			var p: Vector2 = face["at"].call(s)
			spots.append([Vector3(p.x, face["floor"] + CROSS_Y, p.y), face["into"]])
	if spots.size() <= count:
		return spots
	var picked: Array = []
	for i in count:
		picked.append(spots[int(float(i) * spots.size() / count)])
	return picked


static func _cross(shell: CityBuildingBuilder.Shell, centre: Vector3, into: Vector3) -> void:
	var along := into.cross(Vector3.UP).normalized()
	var half := CROSS_SIZE * 0.5
	_plate(
		shell,
		"cross",
		centre - along * half - Vector3(0, half, 0) + into * LIFT,
		along,
		CROSS_SIZE,
		CROSS_SIZE,
		1.0,
		into
	)


## A curtain from the floor to DRAPERY_H and a foliage band over it, along
## the wall's inner face, broken at doors, arches and low windows.
static func _dado(shell: CityBuildingBuilder.Shell, w: Dictionary) -> void:
	var face := _face(w)
	var top := DRAPERY_H + FOLIAGE_H
	var spans: Array[Vector2] = [Vector2(face["s0"], face["s1"])]
	for op: Dictionary in w.get("openings", []):
		if float(op.get("sill", 0.12)) - face["floor"] > top:
			continue
		var h0 := float(op["s"]) - float(op["w"]) * 0.5
		var h1 := h0 + float(op["w"])
		var next: Array[Vector2] = []
		for sp in spans:
			if h0 >= sp.y or h1 <= sp.x:
				next.append(sp)
				continue
			if h0 > sp.x:
				next.append(Vector2(sp.x, h0))
			if h1 < sp.y:
				next.append(Vector2(h1, sp.y))
		spans = next
	var into: Vector3 = face["into"]
	for sp in spans:
		if sp.y - sp.x < 0.3:
			continue
		var a: Vector2 = face["at"].call(sp.x)
		var b: Vector2 = face["at"].call(sp.y)
		var along := Vector3(b.x - a.x, 0, b.y - a.y).normalized()
		var base := Vector3(a.x, face["floor"], a.y) + into * LIFT
		var length := sp.y - sp.x
		_plate(shell, "drapery", base, along, length, DRAPERY_H, length / DRAPERY_TILE, into)
		_plate(
			shell,
			"foliage",
			base + Vector3(0, DRAPERY_H, 0),
			along,
			length,
			FOLIAGE_H,
			length / FOLIAGE_TILE,
			into
		)


## Inner face of a fabric wall as SiteKit.wall builds it: the span along the
## wall, a point at distance s, the room-facing normal and the floor height.
static func _face(w: Dictionary) -> Dictionary:
	var a := Vector2(w["a"][0], w["a"][1])
	var b := Vector2(w["b"][0], w["b"][1])
	var inside := Vector2(w["inside"][0], w["inside"][1])
	var thick := float(w["thick"])
	var length := a.distance_to(b)
	var dir := (b - a) / length
	var out := Vector2(-dir.y, dir.x)
	if out.dot(inside - (a + b) * 0.5) > 0.0:
		out = -out
	return {
		"s0": float(w.get("inner_from", thick)),
		"s1": length - float(w.get("inner_to", thick)),
		"at": func(s: float) -> Vector2: return a + dir * s - out * thick,
		"into": Vector3(-out.x, 0, -out.y),
		"floor": float(w.get("floor", 0.12)),
	}


## True when an opening of `w` overlaps [s0, s1] below `top` above the floor.
static func _blocked(w: Dictionary, s0: float, s1: float, top: float) -> bool:
	var floor_y := float(w.get("floor", 0.12))
	for op: Dictionary in w.get("openings", []):
		var h0 := float(op["s"]) - float(op["w"]) * 0.5
		var h1 := h0 + float(op["w"])
		if h1 > s0 and h0 < s1 and float(op.get("sill", 0.12)) - floor_y < top:
			return true
	return false


## Quad from `base` running `width` along `along` and `height` up, facing
## `into`; u repeats `u_repeat` times, v runs top (0) to bottom (1).
static func _plate(
	shell: CityBuildingBuilder.Shell,
	key: String,
	base: Vector3,
	along: Vector3,
	width: float,
	height: float,
	u_repeat: float,
	into: Vector3
) -> void:
	var up := Vector3(0, height, 0)
	var p00 := base
	var p10 := base + along * width
	var p11 := p10 + up
	var p01 := base + up
	var uv00 := Vector2(0, 1)
	var uv10 := Vector2(u_repeat, 1)
	var uv11 := Vector2(u_repeat, 0)
	var uv01 := Vector2(0, 0)
	shell.tri_out(key, p00, p10, p11, Color.WHITE, into, uv00, uv10, uv11)
	shell.tri_out(key, p00, p11, p01, Color.WHITE, into, uv00, uv11, uv01)


static func _material(key: String, floor_y: float) -> Material:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("plate", load(PLATES[key]))
	mat.set_shader_parameter("floor_y", floor_y)
	mat.set_shader_parameter("indoor_ao", CitySiteKit.CHURCH_WASH_BRIGHTNESS)
	return mat
