class_name CityDungLive
extends Node3D

## Live dung near Kalev (R-2175, docs/SYSTEMS/ANIMAL_DUNG.md), on top of the
## static per-date layer of CityDung:
## - animals walking within LIVE_RADIUS of Kalev drop a fresh dropping of their
##   kind (CityDung.SPECIES_KIND) about every LIVE_SPACING metres they walk; the
##   newest LIVE_CAP lie in a ring buffer drawn by their own MultiMesh batches;
## - a foot (CityGroundTrail.footfall: Kalev's and every tracked citizen's) that
##   lands on a drop, static or live, squashes it flat and drags a brown smear
##   forward; the boot then leaves MUDDY_PRINTS fainter brown prints.
## Everything here is cosmetic: no GameState, nothing saved, and the static
## layer stays deterministic per date (its squashes reset when CityDung rebuilds).
## A sibling of CityDung (world/CityDungLive) so the static rebuild leaves it be.

const LIVE_CAP := 64
const LIVE_RADIUS := 30.0
## Metres an animal walks per dropping, by dung kind.
const LIVE_SPACING := {
	&"cow_pat": 60.0, &"horse_balls": 45.0, &"pellets": 30.0, &"pig": 45.0, &"hare": 80.0,
	&"fowl": 25.0,
}
## How far behind the animal's middle the dropping lands.
const LIVE_BEHIND := {
	&"cow_pat": 1.3, &"horse_balls": 1.4, &"pellets": 0.6, &"pig": 0.6, &"hare": 0.15,
	&"fowl": 0.15,
}
## An animal that jumps further than this between feeds starts counting afresh.
const LIVE_TELEPORT := 4.0
## A foot within the drop's radius (metres at size 1) plus FOOT_REACH squashes it
## to SQUASH_Y of its height, spread SQUASH_SPREAD wider (squashed_mesh: the
## flattened copy has its own normals, a squashed instance basis would bend them).
const HIT_RADIUS := {
	&"cow_pat": 0.17, &"horse_balls": 0.13, &"pellets": 0.1, &"pig": 0.1, &"hare": 0.13,
	&"fowl": 0.15,
}
const FOOT_REACH := 0.1
const SQUASH_Y := 0.3
const SQUASH_SPREAD := 1.15
const SMEAR_CAP := 32
## The smear dragged off the drop, and a muddy print after it (metres).
const SMEAR_SIZE := Vector2(0.46, 0.2)
const PRINT_SIZE := Vector2(0.26, 0.11)
const SMEAR_LIFT := 0.015
const MUDDY_PRINTS := 2
## Fresh muck smears dark and wet; a dried crust crumbles to a paler streak.
## Albedos sit low like the dung meshes' (the R-1748 exposure gain lifts them).
const SMEAR_WET := Color(0.17, 0.12, 0.06, 0.95)
const SMEAR_DRY := Color(0.27, 0.21, 0.13, 0.8)
## Cap on boots tracked as muddy, so walkers that despawn mid-print are dropped.
const MUDDY_MAX := 64

static var _smear_mesh: ArrayMesh
static var _squashed_meshes: Dictionary = {}
static var _smear_material: StandardMaterial3D

var dung: CityDung
var plan: CityPlan
## Settled snow cover 0..1 (fed from the ground trail): drops lie on the snow.
var snow_cover := 0.0

## Live drops, oldest first once the ring is full: {kind, at, yaw, size, color,
## stage, squashed, facing}. A trodden static pat moves in here too (its static
## instance is hidden), so it is gone once the ring recycles its slot.
var _live: Array[Dictionary] = []
var _live_next := 0
## Animals being watched for a drop: key -> {at, walked, next, rng, seen}.
var _walkers: Dictionary = {}
var _tick := 0
## Smears, a ring of at most SMEAR_CAP: [Transform3D, Color].
var _smears: Array = []
var _smear_next := 0
var _muddy: Dictionary = {}
## Static instances by whole-metre cell -> [placement index]; rebuilt whenever
## CityDung rebuilds its batches (its first batch node changes).
var _cells: Dictionary = {}
var _batches: Array = []  # per placement index: [MultiMeshInstance3D, instance index]
var _indexed_first: Object = null
var _indexed_size := -1
var _squashed: Dictionary = {}
var _live_batches: Node3D
var _smear_batch: MultiMeshInstance3D


static func create(city_dung: CityDung) -> CityDungLive:
	var node := CityDungLive.new()
	node.name = "CityDungLive"
	node.dung = city_dung
	node.plan = city_dung.plan
	node._live_batches = Node3D.new()
	node._live_batches.name = "Drops"
	node.add_child(node._live_batches)
	return node


## One animal near Kalev, once a frame (CityTrailFeed). `focus` is Kalev.
func track_animal(key: Variant, world_xz: Vector2, species: StringName, focus: Vector2) -> void:
	if not CityDung.SPECIES_KIND.has(species) or world_xz.distance_to(focus) > LIVE_RADIUS:
		_walkers.erase(key)
		return
	var kind: StringName = CityDung.SPECIES_KIND[species]
	var mark: Dictionary = _walkers.get(key, {})
	if mark.is_empty() or (mark["at"] as Vector2).distance_to(world_xz) > LIVE_TELEPORT:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(str(key))
		# Start part-way through the interval so a herd does not drop in step.
		_walkers[key] = {
			"at": world_xz, "walked": 0.0, "rng": rng, "seen": _tick,
			"next": float(LIVE_SPACING[kind]) * rng.randf_range(0.2, 1.2),
		}
		return
	mark["seen"] = _tick
	var step := world_xz - (mark["at"] as Vector2)
	if step.length() < 0.0001:
		return
	mark["at"] = world_xz
	mark["walked"] = float(mark["walked"]) + step.length()
	if float(mark["walked"]) < float(mark["next"]):
		return
	var rng: RandomNumberGenerator = mark["rng"]
	mark["walked"] = 0.0
	mark["next"] = float(LIVE_SPACING[kind]) * rng.randf_range(0.6, 1.4)
	var at := world_xz - step.normalized() * float(LIVE_BEHIND[kind])
	drop(species, at, rng.randf() * TAU, rng.randf_range(0.85, 1.15))


## Forget animals not fed since the last call (out of range, despawned), and
## follow a date rebuild of the static layer.
func end_frame() -> void:
	if dung != null:
		_index_static()
	for key in _walkers.keys():
		if int(_walkers[key]["seen"]) < _tick:
			_walkers.erase(key)
	_tick += 1


## Lays one fresh dropping of `species` at `at`, recycling the oldest when full.
## Returns false where dung may not lie (foundations, moat, landmark sites).
func drop(species: StringName, at: Vector2, yaw: float, size := 1.0) -> bool:
	if not CityDung.SPECIES_KIND.has(species) or not CityFauna._is_dry(plan, at):
		return false
	var kind: StringName = CityDung.SPECIES_KIND[species]
	_push({
		"kind": kind, "at": at, "yaw": yaw, "size": size, "stage": CityDung.STAGE_WET,
		"color": (
			(CityDung.SPEC[kind]["fresh"] as Color) * CityDung.SPECIES_TINT.get(species, Color.WHITE)
		),
		"squashed": false, "facing": Vector2.RIGHT, "static": false,
	})
	return true


func _push(entry: Dictionary) -> void:
	if _live.size() < LIVE_CAP:
		_live.append(entry)
	else:
		_live[_live_next] = entry
		_live_next = (_live_next + 1) % LIVE_CAP
	_rebuild_live()


func live_drops() -> Array[Dictionary]:
	return _live


## Every smear as [Transform3D, Color] (for tests).
func smears() -> Array:
	return _smears


## A foot comes down at `foot_xz` heading `facing` (CityGroundTrail.footfall).
## Squashes the first unsquashed drop under it; a boot that trod in one leaves
## brown prints on its next steps. Returns true when something was squashed.
func step_on(key: Variant, foot_xz: Vector2, facing: Vector2) -> bool:
	var dir := facing.normalized() if facing.length() > 0.0001 else Vector2.RIGHT
	var stage := _squash_live(foot_xz, dir)
	if stage < 0:
		stage = _squash_static(foot_xz, dir)
	if stage >= 0:
		var color := SMEAR_DRY if stage == CityDung.STAGE_CRUST else SMEAR_WET
		_add_smear(foot_xz, dir, SMEAR_SIZE, color)
		if _muddy.size() >= MUDDY_MAX:
			_muddy.clear()
		_muddy[key] = [MUDDY_PRINTS, color]
		return true
	if _muddy.has(key):
		var left := int(_muddy[key][0])
		var color: Color = _muddy[key][1]
		# Each print carries less: the last one is barely a stain.
		color.a *= float(left) / float(MUDDY_PRINTS + 1)
		_add_smear(foot_xz - dir * PRINT_SIZE.x * 0.5, dir, PRINT_SIZE, color)
		if left <= 1:
			_muddy.erase(key)
		else:
			_muddy[key][0] = left - 1
	return false


func _squash_live(foot_xz: Vector2, dir: Vector2) -> int:
	for entry in _live:
		if bool(entry["squashed"]):
			continue
		var reach := float(HIT_RADIUS[entry["kind"]]) * float(entry["size"]) + FOOT_REACH
		if (entry["at"] as Vector2).distance_to(foot_xz) < reach:
			entry["squashed"] = true
			entry["facing"] = dir
			_rebuild_live()
			return int(entry["stage"])
	return -1


func _squash_static(foot_xz: Vector2, dir: Vector2) -> int:
	if dung == null:
		return -1
	_index_static()
	var placed := dung.placements()
	var cell := Vector2i(foot_xz.floor())
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			for i: int in _cells.get(cell + Vector2i(dx, dy), []):
				if _squashed.has(i):
					continue
				var entry: Array = placed[i]
				var xf: Transform3D = entry[1]
				var size := xf.basis.get_scale().x
				var reach := float(HIT_RADIUS[entry[0]]) * size + FOOT_REACH
				if Vector2(xf.origin.x, xf.origin.z).distance_to(foot_xz) >= reach:
					continue
				_squashed[i] = true
				# Hide the static instance; the flattened pat lives on in the ring.
				var hidden := Transform3D(Basis.from_scale(Vector3.ONE * 0.0001), xf.origin)
				entry[1] = hidden
				var batch: Array = _batches[i]
				var mmi: MultiMeshInstance3D = batch[0]
				if is_instance_valid(mmi):
					mmi.multimesh.set_instance_transform(int(batch[1]), hidden)
				var kind: StringName = entry[0]
				var stage := int(entry[3])
				var spec: Dictionary = CityDung.SPEC[kind]
				# Summer drying is close enough for the colour of a pat already trodden in.
				var dried := clampf(float(entry[4]) / float(spec["dry"]), 0.0, 1.0)
				_push({
					"kind": kind, "at": Vector2(xf.origin.x, xf.origin.z),
					"yaw": atan2(-xf.basis.x.z, xf.basis.x.x), "size": size, "stage": stage,
					"color": (spec["fresh"] as Color).lerp(Color.WHITE, dried),
					"squashed": true, "facing": dir, "static": true,
				})
				return stage
	return -1


## The drop's instance basis: its yaw and size, and once squashed a little
## longer along the step (the flattening itself is in squashed_mesh).
static func drop_basis(entry: Dictionary) -> Basis:
	var size := float(entry["size"])
	var basis := Basis(Vector3.UP, float(entry["yaw"])).scaled(Vector3(size, size, size))
	if not bool(entry["squashed"]):
		return basis
	var dir: Vector2 = entry["facing"]
	var turn := Basis(Vector3.UP, atan2(-dir.y, dir.x))
	return turn * Basis.from_scale(Vector3(1.12, 1.0, 1.0)) * turn.inverse() * basis


## `kind`'s dung mesh trodden flat: SQUASH_Y of its height, SQUASH_SPREAD wider,
## with normals rebuilt for the new shape.
static func squashed_mesh(kind: StringName) -> ArrayMesh:
	if _squashed_meshes.has(kind):
		return _squashed_meshes[kind]
	var arrays := CityDung.mesh_for(kind).surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in verts.size():
		var v := verts[i]
		verts[i] = Vector3(v.x * SQUASH_SPREAD, v.y * SQUASH_Y, v.z * SQUASH_SPREAD)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = null
	var st := SurfaceTool.new()
	st.create_from_arrays(arrays)
	st.generate_normals()
	var mesh := st.commit()
	_squashed_meshes[kind] = mesh
	return mesh


## Placement index -> its batch node and instance, and a metre-cell lookup.
## CityDung appends placements batch by batch in child order, so the batches'
## instance counts walk the placements in step.
func _index_static() -> void:
	var placed := dung.placements()
	var first: Object = dung.get_child(0) if dung.get_child_count() > 0 else null
	if first == _indexed_first and placed.size() == _indexed_size:
		return
	_indexed_first = first
	_indexed_size = placed.size()
	_cells.clear()
	_batches.clear()
	_squashed.clear()
	_forget_static_squashes()
	for child in dung.get_children():
		var mmi := child as MultiMeshInstance3D
		if mmi == null:
			continue
		for k in mmi.multimesh.instance_count:
			_batches.append([mmi, k])
	if _batches.size() != placed.size():
		push_warning("CityDungLive: %d batch instances for %d placements" % [
			_batches.size(), placed.size()
		])
		_cells.clear()
		return
	for i in placed.size():
		if placed[i][0] == CityDung.KIND_HEAP:
			continue  # nobody squashes a manure heap
		var o: Vector3 = (placed[i][1] as Transform3D).origin
		var cell := Vector2i(Vector2(o.x, o.z).floor())
		if not _cells.has(cell):
			_cells[cell] = []
		(_cells[cell] as Array).append(i)


## The static layer was rebuilt whole: its trodden copies leave the ring.
func _forget_static_squashes() -> void:
	var kept: Array[Dictionary] = []
	for entry in _live:
		if not bool(entry["static"]):
			kept.append(entry)
	if kept.size() == _live.size():
		return
	# Oldest first, so the ring carries on recycling the oldest live drop.
	var ordered: Array[Dictionary] = []
	for k in _live.size():
		var entry: Dictionary = _live[(_live_next + k) % _live.size()]
		if not bool(entry["static"]):
			ordered.append(entry)
	_live = ordered
	_live_next = 0
	_rebuild_live()


func _ground(at: Vector2) -> float:
	return plan.ground_height(at) + CitySnow.depth_at(at, snow_cover)


func _rebuild_live() -> void:
	for child in _live_batches.get_children():
		_live_batches.remove_child(child)
		child.queue_free()
	var batches := {}  # [kind, stage, squashed] -> {transforms, colors}
	for entry in _live:
		var at: Vector2 = entry["at"]
		var xf := Transform3D(drop_basis(entry), Vector3(at.x, _ground(at) - 0.004, at.y))
		var key := [entry["kind"], int(entry["stage"]), bool(entry["squashed"])]
		if not batches.has(key):
			batches[key] = {"transforms": [] as Array[Transform3D], "colors": [] as Array[Color]}
		(batches[key]["transforms"] as Array[Transform3D]).append(xf)
		(batches[key]["colors"] as Array[Color]).append(entry["color"])
	for key: Array in batches:
		var kind: StringName = key[0]
		var mmi := MapViewMeshBuilderPrimitives.multi_mesh(
			"live_%s_s%d%s" % [kind, key[1], "_squashed" if key[2] else ""],
			squashed_mesh(kind) if key[2] else CityDung.mesh_for(kind),
			batches[key]["transforms"], batches[key]["colors"], CityDung.material(key[1]),
			Vector3.ZERO
		)
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = float(CityDung.SPEC[kind]["range"])
		_live_batches.add_child(mmi)


## A smear `size` (length, width) from `from` forward along `dir`.
func _add_smear(from: Vector2, dir: Vector2, size: Vector2, color: Color) -> void:
	var yaw := atan2(-dir.y, dir.x)
	var basis := Basis(Vector3.UP, yaw).scaled(Vector3(size.x, 1.0, size.y))
	var xf := Transform3D(basis, Vector3(from.x, _ground(from) + SMEAR_LIFT, from.y))
	if _smears.size() < SMEAR_CAP:
		_smears.append([xf, color])
	else:
		_smears[_smear_next] = [xf, color]
		_smear_next = (_smear_next + 1) % SMEAR_CAP
	if _smear_batch == null:
		_smear_batch = MultiMeshInstance3D.new()
		_smear_batch.name = "Smears"
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = smear_mesh()
		mm.instance_count = SMEAR_CAP
		mm.visible_instance_count = 0
		_smear_batch.multimesh = mm
		_smear_batch.material_override = smear_material()
		_smear_batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_smear_batch.visibility_range_end = 60.0
		add_child(_smear_batch)
	var mm := _smear_batch.multimesh
	for i in _smears.size():
		mm.set_instance_transform(i, _smears[i][0])
		mm.set_instance_color(i, _smears[i][1])
	mm.visible_instance_count = _smears.size()


## A unit streak along +X from 0 to 1, 1 wide at its fullest: thick where the
## boot came down, thinning to a tail; vertex alpha fades to the edges so it
## reads as a wipe of muck, not a cut-out.
static func smear_mesh() -> ArrayMesh:
	if _smear_mesh != null:
		return _smear_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var steps := 10
	var rows: Array = []
	for i in steps + 1:
		var x := float(i) / float(steps)
		var half := 0.5 * pow(sin(PI * clampf(x * 0.9 + 0.08, 0.0, 1.0)), 0.6) * (1.0 - 0.45 * x)
		var core := lerpf(1.0, 0.25, x)
		rows.append([
			[Vector3(x, 0.0, -half), 0.0], [Vector3(x, 0.0, 0.0), core], [Vector3(x, 0.0, half), 0.0]
		])
	for i in steps:
		for side in 2:
			var a: Array = rows[i][side]
			var b: Array = rows[i][side + 1]
			var c: Array = rows[i + 1][side]
			var d: Array = rows[i + 1][side + 1]
			for v: Array in [a, d, b, a, c, d]:
				st.set_color(Color(1.0, 1.0, 1.0, float(v[1])))
				st.add_vertex(v[0])
	_smear_mesh = st.commit()
	return _smear_mesh


static func smear_material() -> StandardMaterial3D:
	if _smear_material == null:
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		# Matt: a glossy smear catches the low sun and reads pale, not brown.
		m.roughness = 0.85
		m.metallic_specular = 0.2
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_smear_material = m
	return _smear_material
