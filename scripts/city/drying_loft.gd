class_name DryingLoft
extends RefCounted

## Grain-drying loft of a 1343 smoke dwelling (elurehi) and the threshing
## evidence in its anteroom (docs/SYSTEMS/FARMLAND.md, "Drying loft"). Pure
## data and procedural meshes: HouseholdLayout places the items, CityInteriors
## mounts the models and shows a share of the sheaves chosen by `sheaf_load`.
##
## Evidence (history/dossiers/architecture/rural-smoke-dwelling-and-farmstead-1343.md):
## - attested (type level): the heated smoke room also dried grain and a
##   threshing floor adjoined it (Lavi 2001; Estonian Open Air Museum).
## - plausible composite: movable poles (parred) between the walls above the
##   oven, with sheaves laid across them in autumn; the pole count (about 12),
##   2-2.5 m height and wall-to-wall span are 18th-19th c. EVM ethnography of the
##   rehielamu, kept here only as the nearest analogy, not as 1343 measurement.
## - plausible composite: rye and barley, the main grains; threshing with
##   hand flails on the floor of the anteroom.
## Excluded: chambers (first evidence early 17th c.), the large rehealune hall.

## Height of the pole tops above the floor: over head height (EVM 2-2.5 m).
const POLE_Y := 2.05
const POLE_RADIUS := 0.045
## Poles in a room are at most this many, this far apart (EVM: about 12).
const POLE_MAX := 12
const POLE_SPACING := 0.55
## Poles and sheaves keep this far from the walls: the roof slopes down to the
## wall plate, so sheaves at the very wall would poke through it.
const POLE_END_GAP := 0.12
const SHEAF_WALL_GAP := 0.55
const SHEAF_STEP := 0.27
const SHEAF_LENGTH := 0.68
const SHEAF_RADIUS := 0.105

const KINDS := [&"loft_pole", &"loft_sheaf", &"threshing_flail", &"straw_litter"]

## Share (0..1) of the sheaf spots loaded on the day of the year. Rye is cut
## from late July, barley in August, and the sheaves dry in the smoke room
## through the autumn; threshing goes on through the winter, so the poles are
## nearly full in Aug-Oct, thin out to a few bundles by spring and are bare in
## early summer. A derived curve, not a measured 1343 record.
const LOAD_CURVE: Array[Vector2] = [
	Vector2(0, 0.30),
	Vector2(60, 0.12),
	Vector2(130, 0.0),
	Vector2(205, 0.0),
	Vector2(225, 1.0),
	Vector2(285, 1.0),
	Vector2(330, 0.6),
	Vector2(366, 0.30),
]

static var _meshes: Dictionary = {}


## Loaded share of the poles on a day of the year (pure; no saved state).
static func sheaf_load(day_of_year: float) -> float:
	var d := clampf(day_of_year, 0.0, 366.0)
	for i in range(1, LOAD_CURVE.size()):
		var b := LOAD_CURVE[i]
		if d <= b.x:
			var a := LOAD_CURVE[i - 1]
			return lerpf(a.y, b.y, (d - a.x) / maxf(b.x - a.x, 0.001))
	return LOAD_CURVE[-1].y


## Whether a sheaf of `rank` (0..1, seeded per spot) is up on the poles that day.
static func sheaf_shown(rank: float, day_of_year: float) -> bool:
	return rank < sheaf_load(day_of_year)


## A model for a loft item (`item["loft"]` is one of KINDS). `item` carries the
## seeded per-item data (pole "len", litter "seed").
static func build_model(item: Dictionary) -> Node3D:
	var kind: StringName = item["loft"]
	var holder := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.name = String(kind)
	match kind:
		&"loft_pole":
			mesh.mesh = _pole_mesh(float(item["len"]))
			mesh.position.y = -POLE_RADIUS
		&"loft_sheaf":
			mesh.mesh = sheaf_mesh()
			mesh.position.y = SHEAF_RADIUS
		&"threshing_flail":
			mesh.mesh = _cached(&"flail", _flail_mesh)
		&"straw_litter":
			mesh.mesh = _litter_mesh(int(item["seed"]), item["size"])
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(mesh)
	return holder


static func sheaf_mesh() -> Mesh:
	return _cached(&"sheaf", _sheaf_mesh)


static func _cached(key: StringName, build: Callable) -> Mesh:
	if not _meshes.has(key):
		_meshes[key] = build.call()
	return _meshes[key]


static func _material(color: Color, rough := 0.95) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	return m


## A cylinder lying along local X.
static func _lying(radius_top: float, radius_bottom: float, length: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = radius_top
	c.bottom_radius = radius_bottom
	c.height = length
	c.radial_segments = 8
	c.rings = 1
	return c


static func _pole_mesh(length: float) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Smoke-blackened pole: a peeled sapling, slightly thicker at the butt.
	st.append_from(
		_lying(POLE_RADIUS * 0.85, POLE_RADIUS, length), 0, Transform3D(_along_x(), Vector3.ZERO)
	)
	var mesh := st.commit()
	mesh.surface_set_material(0, _material(Color(0.17, 0.12, 0.08)))
	return mesh


static func _along_x() -> Basis:
	return Basis(Vector3(0, 0, 1), PI * 0.5)


## A sheaf laid across two poles: its length runs along local Z (across the
## poles), binding band at the middle, the ear end a little fuller.
static func _sheaf_mesh() -> Mesh:
	var across := Basis(Vector3(1, 0, 0), PI * 0.5)
	var body := SurfaceTool.new()
	body.begin(Mesh.PRIMITIVE_TRIANGLES)
	body.append_from(
		_lying(SHEAF_RADIUS * 1.15, SHEAF_RADIUS * 0.8, SHEAF_LENGTH),
		0,
		Transform3D(across, Vector3.ZERO)
	)
	var mesh := body.commit()
	mesh.surface_set_material(0, _material(Color(0.74, 0.6, 0.29)))
	var band := SurfaceTool.new()
	band.begin(Mesh.PRIMITIVE_TRIANGLES)
	band.append_from(
		_lying(SHEAF_RADIUS * 0.98, SHEAF_RADIUS * 0.98, 0.05),
		0,
		Transform3D(across, Vector3(0, 0, SHEAF_LENGTH * 0.08))
	)
	band.commit(mesh)
	mesh.surface_set_material(1, _material(Color(0.36, 0.26, 0.12)))
	return mesh


## Hand flail lying on the floor: a long handstaff, a short swingle and the cord.
static func _flail_mesh() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wood := Transform3D(_along_x(), Vector3(0, 0.02, 0))
	st.append_from(_lying(0.014, 0.017, 1.45), 0, wood)
	var swingle := Transform3D(_along_x().rotated(Vector3.UP, 0.18), Vector3(1.0, 0.025, 0.05))
	st.append_from(_lying(0.022, 0.022, 0.72), 0, swingle)
	var mesh := st.commit()
	mesh.surface_set_material(0, _material(Color(0.42, 0.31, 0.19)))
	return mesh


## Trodden straw and chaff on the threshing floor: thin stalks laid at random
## angles, seeded by the item so a house always has the same litter.
static func _litter_mesh(seed_value: int, size: Vector3) -> Mesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var box := BoxMesh.new()
	box.size = Vector3(0.5, 0.012, 0.02)
	for k in 26:
		var t := Transform3D(
			Basis(Vector3.UP, rng.randf() * TAU),
			Vector3(
				rng.randf_range(-size.x * 0.5, size.x * 0.5),
				0.006 + rng.randf() * 0.012,
				rng.randf_range(-size.z * 0.5, size.z * 0.5)
			)
		)
		st.append_from(box, 0, t)
	var mesh := st.commit()
	mesh.surface_set_material(0, _material(Color(0.66, 0.54, 0.27)))
	return mesh
