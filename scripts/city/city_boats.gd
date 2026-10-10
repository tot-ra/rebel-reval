class_name CityBoats
extends RefCounted

## Small working craft of the 1343 shore (history/dossiers/topography/
## kalamaja-fishing-shore-1343.md, docs/reports/baltic_vessels_1343.md), built as
## lofted clinker hulls in metres: a fishing clinker boat, a skiff, a flat-bottomed
## cargo lighter for the roadstead transfer, and the overturned boat on trestles.
## No Reval fishing-boat wreck is published, so these are comparanda-based
## plausible composites. Each hull is one mesh with vertex-coloured strakes.

const STATIONS := 15
const STRAKES := 6
const TAR := Color(0.36, 0.27, 0.18)
const PLANK := Color(0.52, 0.4, 0.28)
const WEATHERED := Color(0.62, 0.55, 0.46)

## kind -> {length, beam, depth, flat (bottom flatness 0..1), stem (rise of the ends),
## sheer (gunwale lift at the ends), tarred, deck_y (usable floor above the keel)}.
const KINDS := {
	&"clinker": {
		"length": 7.4, "beam": 2.2, "depth": 0.95, "flat": 0.25, "stem": 0.55,
		"tarred": false, "floor": 0.28,
	},
	&"skiff": {
		"length": 4.6, "beam": 1.6, "depth": 0.7, "flat": 0.35, "stem": 0.35,
		"tarred": false, "floor": 0.22,
	},
	&"lighter": {
		"length": 10.5, "beam": 3.6, "depth": 1.15, "flat": 0.8, "stem": 0.25,
		"tarred": true, "floor": 0.35,
	},
}

static var _meshes: Dictionary = {}


## Mesh of `kind` with +x the bow, keel at y 0, centred on x.
static func hull_mesh(kind: StringName) -> ArrayMesh:
	if _meshes.has(kind):
		return _meshes[kind]
	var spec: Dictionary = KINDS[kind]
	var length: float = spec["length"]
	var beam: float = spec["beam"]
	var depth: float = spec["depth"]
	var flat: float = spec["flat"]
	var stem: float = spec["stem"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Station rows from keel to gunwale, port to starboard: ring[s][k] for k in -STRAKES..STRAKES.
	var rings: Array = []
	for s in STATIONS:
		var t := float(s) / (STATIONS - 1)
		var x := (t - 0.5) * length
		var u := absf(t * 2.0 - 1.0)  # 0 amidships .. 1 at the stems
		var half := beam * 0.5 * pow(1.0 - pow(u, 2.6), 0.62)
		var rise := stem * pow(u, 2.2)
		var keel_y := rise * 0.55 * (1.0 - flat * 0.8)
		var top_y := depth + rise
		var ring: Array[Vector3] = []
		for k in range(-STRAKES, STRAKES + 1):
			var a := float(k) / STRAKES  # -1 port gunwale .. 0 keel .. 1 starboard gunwale
			var side := absf(a)
			# Section: flat floor (flat share), then flaring sides to the gunwale.
			var floor_w := flat * 0.55
			var w := 0.0
			var y := 0.0
			if side <= floor_w:
				w = side / maxf(floor_w, 0.001) * half * floor_w
				y = keel_y
			else:
				var q := (side - floor_w) / (1.0 - floor_w)
				w = half * (floor_w + q * (1.0 - floor_w))
				y = lerpf(keel_y, top_y, pow(q, 1.35))
			ring.append(Vector3(x, y, signf(a) * w))
		rings.append(ring)
	var tarred: bool = spec["tarred"]
	for s in STATIONS - 1:
		for k in STRAKES * 2:
			var a: Vector3 = rings[s][k]
			var b: Vector3 = rings[s + 1][k]
			var c: Vector3 = rings[s + 1][k + 1]
			var d: Vector3 = rings[s][k + 1]
			var strake := int(absf(float(k) + 0.5 - STRAKES))
			var tone := (TAR if tarred else PLANK).lerp(WEATHERED, 0.25 + 0.12 * float(strake % 2))
			if strake == STRAKES - 1:
				tone = tone.darkened(0.15)  # the sheer strake
			for tri: Array in [[a, c, b], [a, d, c]]:
				var normal: Vector3 = ((tri[1] - tri[0]).cross(tri[2] - tri[0])).normalized()
				for v: Vector3 in tri:
					st.set_color(tone)
					st.set_normal(normal)
					st.add_vertex(v)
					# Inside faces too, so the open hull is solid from both sides.
				for v: Vector3 in [tri[0], tri[2], tri[1]]:
					st.set_color(tone.darkened(0.12))
					st.set_normal(-normal)
					st.add_vertex(v)
	# Floor boards and thwarts read the interior from above.
	var floor_y: float = float(spec["floor"])
	for i in 3:
		var tx := (float(i) - 1.0) * length * 0.2
		_box(
			st, Vector3(tx, floor_y + depth * 0.42, 0.0), Vector3(0.18, 0.06, beam * 0.78),
			PLANK.darkened(0.1)
		)
	_box(
		st, Vector3(0.0, floor_y + 0.02, 0.0), Vector3(length * 0.72, 0.04, beam * 0.5),
		PLANK.darkened(0.25)
	)
	var mesh := st.commit()
	_meshes[kind] = mesh
	return mesh


static func _box(st: SurfaceTool, c: Vector3, size: Vector3, tone: Color) -> void:
	var h := size * 0.5
	var faces := [
		[
			Vector3(1, 0, 0),
			Vector3(h.x, -h.y, -h.z), Vector3(h.x, -h.y, h.z),
			Vector3(h.x, h.y, h.z), Vector3(h.x, h.y, -h.z)
		],
		[
			Vector3(-1, 0, 0),
			Vector3(-h.x, -h.y, h.z), Vector3(-h.x, -h.y, -h.z),
			Vector3(-h.x, h.y, -h.z), Vector3(-h.x, h.y, h.z)
		],
		[
			Vector3(0, 1, 0),
			Vector3(-h.x, h.y, -h.z), Vector3(h.x, h.y, -h.z),
			Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z)
		],
		[
			Vector3(0, 0, 1),
			Vector3(h.x, -h.y, h.z), Vector3(-h.x, -h.y, h.z),
			Vector3(-h.x, h.y, h.z), Vector3(h.x, h.y, h.z)
		],
		[
			Vector3(0, 0, -1),
			Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z),
			Vector3(h.x, h.y, -h.z), Vector3(-h.x, h.y, -h.z)
		],
	]
	for f: Array in faces:
		for idx: int in [1, 2, 3, 1, 3, 4]:
			st.set_color(tone)
			st.set_normal(f[0])
			st.add_vertex(c + (f[idx] as Vector3))


## A hull node (mesh + wood material), keel at the node origin.
static func build(kind: StringName, fittings := true) -> Node3D:
	var root := Node3D.new()
	root.name = "Boat_%s" % kind
	var inst := MeshInstance3D.new()
	inst.mesh = hull_mesh(kind)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.9
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	inst.material_override = material
	root.add_child(inst)
	if fittings and (kind == &"clinker" or kind == &"skiff"):
		_oars_and_mast(root, kind)
	if fittings and kind == &"lighter":
		_cargo(root)
	return root


static func _oars_and_mast(root: Node3D, kind: StringName) -> void:
	var spec: Dictionary = KINDS[kind]
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.45, 0.34, 0.24)
	wood.roughness = 0.9
	for side: float in [-1.0, 1.0]:
		var oar := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.06, 0.04, 2.6 if kind == &"clinker" else 1.8)
		oar.mesh = mesh
		oar.material_override = wood
		oar.position = Vector3(
			0.1, float(spec["depth"]) + 0.25, side * (float(spec["beam"]) * 0.5 + 0.55)
		)
		oar.rotation = Vector3(0.0, 0.25 * side, 0.18)
		root.add_child(oar)
	if kind == &"clinker":
		var mast := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.04
		cyl.bottom_radius = 0.06
		cyl.height = 4.2
		mast.mesh = cyl
		mast.material_override = wood
		mast.position = Vector3(-0.9, 2.2, 0.0)
		root.add_child(mast)


static func _cargo(root: Node3D) -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.5, 0.38, 0.27)
	wood.roughness = 0.9
	for i in 4:
		var barrel := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.34
		cyl.bottom_radius = 0.34
		cyl.height = 0.9
		barrel.mesh = cyl
		barrel.material_override = wood
		barrel.position = Vector3(-1.6 + i * 0.85, 1.0, (i % 2) * 0.8 - 0.4)
		root.add_child(barrel)


## Overturned boat on two trestles: a hull flipped keel-up, for the boatwright
## ground and the net yards.
static func overturned(kind: StringName = &"clinker") -> Node3D:
	var root := Node3D.new()
	root.name = "OverturnedBoat"
	var hull := build(kind, false)
	var depth: float = KINDS[kind]["depth"]
	hull.rotation.z = PI
	hull.position.y = depth + 0.55
	root.add_child(hull)
	var timber := StandardMaterial3D.new()
	timber.albedo_color = Color(0.4, 0.3, 0.2)
	for x: float in [-1.5, 1.5]:
		var trestle := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.18, 0.55, 1.5)
		trestle.mesh = mesh
		trestle.material_override = timber
		trestle.position = Vector3(x, 0.27, 0.0)
		root.add_child(trestle)
	return root
