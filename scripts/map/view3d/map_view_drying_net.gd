class_name MapViewDryingNet
extends Node3D

## R-1640: a long net of grey weathered hemp hung over a pole rack to dry, as in
## the Kalamaja net yards (history/dossiers/topography/kalamaja-fishing-shore-1343.md:
## "nets dried horizontal on poles"). Untarred hemp and flax bleach to grey on
## the shore, so the twine is grey, not the brown of the tarred stored nets.
##
## The net is draped over the pole: one particle row rests on the pole, the float
## side hangs in front (-z) and the sinker side behind (+z). A coarse Verlet cloth
## driven by the shared WindField carries the swing and belly of the whole sheet;
## the shader draws the knotted diamond mesh and adds the fine shiver a 0.5 m
## particle grid cannot hold. Visual only: no collision, no gameplay state.

const NET_SHADER := preload("res://scripts/map/view3d/map_view_drying_net.gdshader")

## Fixed step keeps the cloth deterministic and frame-rate independent.
const STEP := 1.0 / 30.0
const MAX_STEPS_PER_FRAME := 3
const ITERATIONS := 2
## Particle spacing in metres. WHY coarse: GDScript solves every constraint on the
## CPU; at 0.5 m an 11 m net is ~300 particles and costs well under 0.1 ms a step.
const SEGMENT := 0.5
const GRAVITY := 9.8
## Velocity kept per step; wet hemp is heavy and the mesh bleeds air, so it damps fast.
const DAMPING := 0.965
## Downwind acceleration at local wind strength 1.0 (m/s^2). About 20 degrees of
## swing in a fresh breeze, 35 degrees in a storm (atan(F / g)).
const WIND_ACCEL := 9.0
## Cross-wind flutter acceleration at full turbulence.
const FLUTTER_ACCEL := 1.6
## The cloth sleeps outside this camera distance and keeps its last pose.
const ACTIVE_RANGE := 55.0
const SETTLE_STEPS := 90
const GROUND_CLEARANCE := 0.03

## Weathered untarred hemp, sun-bleached on the shore (near-neutral mid grey).
const TWINE_GREY := Color(0.44, 0.435, 0.405)
## A hanging net is gathered on its pole: about 1.8 m of net per metre of pole,
## so the diamonds close into tall slits (shader `gather`) and the sheet folds
## into accordion pleats (FOLD_DEPTH, alternating per particle column).
const GATHER := 1.8
const FOLD_DEPTH := 0.22
const POLE_WOOD_STEM := "res://assets/materials/pbr/bridge_timber/bridge_timber_1"
const POST_RADIUS := 0.075
const POLE_RADIUS := 0.055
const FLOAT_EVERY := 2
const SINKER_EVERY := 2

static var _cache: Dictionary = {}

var net_id := ""
var net_length := 7.0
## Hanging length of the float side; the sinker side hangs 85% of it.
var net_drop := 2.0
var pole_height := 2.6
## Tests and review captures pin the weather; the city reads the shared field.
var wind_override: WindField.Params = null

var _cols := 0
var _rows := 0
var _pole_row := 0
var _pos := PackedVector3Array()
var _prev := PackedVector3Array()
var _inv_mass := PackedFloat32Array()
var _normals := PackedVector3Array()
var _uvs := PackedVector2Array()
var _indices := PackedInt32Array()
var _pairs := PackedInt32Array()
var _rest := PackedFloat32Array()
var _mesh := ArrayMesh.new()
var _cloth: MeshInstance3D
var _floats: MultiMeshInstance3D
var _sinkers: MultiMeshInstance3D
var _accumulator := 0.0
var _sim_time := 0.0
var _sleeping := true
var _phase := 0.0


## Builds a ready-to-place rack with its net already settled under gravity.
static func create(
	id: String, length: float = 7.0, drop: float = 2.0, height: float = 2.6
) -> MapViewDryingNet:
	var net := MapViewDryingNet.new()
	net.name = "DryingNet_%s" % id.replace(".", "_")
	net.net_id = id
	net.net_length = maxf(length, 2.0)
	net.net_drop = clampf(drop, 0.8, height - 0.25)
	net.pole_height = height
	net.set_meta(&"drying_net", true)
	net._build()
	return net


func _build() -> void:
	# WHY a seeded phase and fold pattern: every rack must look hung by a
	# different hand, yet the same id always rebuilds the same net.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(net_id)
	_phase = rng.randf() * TAU
	_build_rack(rng)
	_build_cloth(rng)
	_build_weights()
	simulate(SETTLE_STEPS)
	_sleeping = true


func _process(delta: float) -> void:
	if not _wants_simulation():
		_sleeping = true
		return
	if _sleeping:
		# Waking from sleep must not replay the seconds spent asleep.
		_sleeping = false
		_accumulator = 0.0
	_accumulator += minf(delta, STEP * MAX_STEPS_PER_FRAME)
	var steps := 0
	while _accumulator >= STEP and steps < MAX_STEPS_PER_FRAME:
		_step(WindField.clock())
		_accumulator -= STEP
		steps += 1
	if steps > 0:
		_update_mesh()


func _wants_simulation() -> bool:
	if not is_visible_in_tree():
		return false
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera == null:
		return false
	return camera.global_position.distance_to(global_position) <= ACTIVE_RANGE


## Advances the cloth `steps` fixed steps from `start_time` (WindField clock
## seconds) and refreshes the mesh. Used by settling, tests and captures.
func simulate(steps: int, start_time: float = -1.0) -> void:
	var t := _sim_time if start_time < 0.0 else start_time
	for i in steps:
		_step(t + i * STEP)
	_update_mesh()


func is_sleeping() -> bool:
	return _sleeping


func particle_grid() -> Vector2i:
	return Vector2i(_cols, _rows)


func particle_position(col: int, row: int) -> Vector3:
	return _pos[row * _cols + col]


func pole_row_index() -> int:
	return _pole_row


func cloth_mesh() -> ArrayMesh:
	return _mesh


func cloth_material() -> ShaderMaterial:
	return _cloth.material_override as ShaderMaterial


# --- rack --------------------------------------------------------------------


func _build_rack(rng: RandomNumberGenerator) -> void:
	var rack := Node3D.new()
	rack.name = "Rack"
	add_child(rack)
	var timber := pole_wood()
	var lashing := _lashing_material()
	var posts := maxi(2, ceili(net_length / 4.0) + 1)
	var half := net_length * 0.5 + 0.2
	for i in posts:
		var x := lerpf(-half, half, float(i) / float(posts - 1))
		var lean := Vector3(rng.randf_range(-0.05, 0.05), 0.0, rng.randf_range(-0.05, 0.05))
		var top := Vector3(x, pole_height - 0.02, 0.0)
		# Posts are dug in: the foot sits below grade so uneven shore never shows a gap.
		_spar(rack, "Post%d" % i, Vector3(x, -0.35, 0.0) + lean, top, POST_RADIUS, timber)
		# A forked top cradles the pole; real racks used a cut branch fork.
		for side: float in [-1.0, 1.0]:
			_spar(
				rack,
				"Post%dFork%s" % [i, "A" if side < 0.0 else "B"],
				top,
				top + Vector3(0.0, 0.26, side * 0.13),
				POST_RADIUS * 0.6,
				timber
			)
		_spar(
			rack,
			"Post%dLashing" % i,
			top + Vector3(0.0, 0.02, 0.0),
			top + Vector3(0.0, 0.14, 0.0),
			POST_RADIUS * 1.2,
			lashing
		)
	# End braces keep a long loaded pole from racking along its length.
	for side: float in [-1.0, 1.0]:
		var end_x := side * half
		_spar(
			rack,
			"EndBrace%s" % ("W" if side < 0.0 else "E"),
			Vector3(end_x + side * 0.85, -0.1, 0.0),
			Vector3(end_x, pole_height * 0.62, 0.0),
			0.045,
			timber
		)
	_spar(
		rack,
		"Pole",
		Vector3(-half - 0.3, pole_height + POLE_RADIUS, 0.0),
		Vector3(half + 0.3, pole_height + POLE_RADIUS, 0.0),
		POLE_RADIUS,
		timber
	)


func _spar(
	parent: Node3D,
	node_name: String,
	start: Vector3,
	end: Vector3,
	radius: float,
	material: Material
) -> void:
	var direction := end - start
	if direction.is_zero_approx():
		return
	var inst := MeshInstance3D.new()
	inst.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.88
	mesh.bottom_radius = radius
	mesh.height = direction.length()
	mesh.radial_segments = 7
	mesh.rings = 1
	inst.mesh = mesh
	inst.position = (start + end) * 0.5
	inst.quaternion = Quaternion(Vector3.UP, direction.normalized())
	inst.material_override = material
	parent.add_child(inst)


# --- cloth -------------------------------------------------------------------


func _build_cloth(rng: RandomNumberGenerator) -> void:
	_cols = maxi(2, ceili(net_length / SEGMENT) + 1)
	var front_rows := maxi(2, ceili(net_drop / SEGMENT))
	var back_drop := net_drop * 0.85
	var back_rows := front_rows
	_pole_row = front_rows
	_rows = front_rows + back_rows + 1
	var pin_y := pole_height + POLE_RADIUS * 2.0
	var count := _cols * _rows
	_pos.resize(count)
	_prev.resize(count)
	_inv_mass.resize(count)
	_normals.resize(count)
	_uvs.resize(count)
	var fold_phase := rng.randf() * TAU
	var fold_wave := rng.randf_range(1.3, 2.1)
	for row in _rows:
		# Signed hang distance from the pole: negative is the float side (front).
		var hang: float
		if row < _pole_row:
			hang = -net_drop * float(_pole_row - row) / float(front_rows)
		elif row > _pole_row:
			hang = back_drop * float(row - _pole_row) / float(back_rows)
		else:
			hang = 0.0
		var side := signf(hang)
		var depth := absf(hang)
		for col in _cols:
			var x := lerpf(-net_length * 0.5, net_length * 0.5, float(col) / float(_cols - 1))
			# Gathered pleats: alternate columns fold out and in like an accordion,
			# deeper down the hang where the net is free to open.
			var pleat := (
				(1.0 if col % 2 == 0 else -1.0)
				* FOLD_DEPTH
				* (0.75 + 0.5 * absf(sin(float(col) * 0.7 + fold_phase)))
			)
			var sway := sin(float(col) * fold_wave * 0.31 + fold_phase) * 0.1
			var fold := (
				pleat * (0.35 + 0.65 * smoothstep(0.0, 0.6, depth))
				+ sway * smoothstep(0.0, 1.0, depth)
			)
			var p := Vector3(x, pin_y - depth, side * (0.07 + depth * 0.05) + fold)
			var i := row * _cols + col
			_pos[i] = p
			_prev[i] = p
			_inv_mass[i] = 0.0 if row == _pole_row else 1.0
			# UV in metres: u along the pole, v the hang distance. The shader
			# turns this into the knotted diamond mesh at true scale.
			_uvs[i] = Vector2(x + net_length * 0.5, hang)
	# Structural constraints only (along and across the hang): shear springs would
	# double the solve cost for a sheet whose pleats are meant to collapse.
	for row in _rows:
		for col in _cols:
			var i := row * _cols + col
			if col + 1 < _cols:
				_add_constraint(i, i + 1)
			if row + 1 < _rows:
				_add_constraint(i, i + _cols)
	for row in _rows - 1:
		for col in _cols - 1:
			var a := row * _cols + col
			var b := a + 1
			var c := a + _cols
			var d := c + 1
			_indices.append_array(PackedInt32Array([a, c, b, b, c, d]))
	_compute_normals()
	_cloth = MeshInstance3D.new()
	_cloth.name = "NetCloth"
	_cloth.mesh = _mesh
	_cloth.material_override = net_material()
	_cloth.set_instance_shader_parameter(&"motion_phase", _phase)
	# The cloth moves inside a fixed volume; a custom AABB spares a per-step
	# recompute and keeps the swung-out sheet from being culled.
	_mesh.custom_aabb = AABB(
		Vector3(-net_length * 0.5 - 1.5, -0.1, -2.6),
		Vector3(net_length + 3.0, pole_height + 0.6, 5.2)
	)
	_cloth.set_meta(&"wind_animated", true)
	add_child(_cloth)


func _add_constraint(a: int, b: int) -> void:
	_pairs.append(a)
	_pairs.append(b)
	_rest.append(_pos[a].distance_to(_pos[b]))


func _step(time: float) -> void:
	_sim_time = time + STEP
	var params := wind_override if wind_override != null else WindField.current()
	var origin := global_position if is_inside_tree() else position
	var basis_inv := (global_basis if is_inside_tree() else basis).inverse()
	var xz := Vector2(origin.x, origin.z)
	var local_strength := WindField.local_strength(xz, time, params)
	var wind := basis_inv * Vector3(params.direction.x, 0.0, params.direction.y)
	wind.y = 0.0
	if not wind.is_zero_approx():
		wind = wind.normalized()
	var across := Vector3(-wind.z, 0.0, wind.x)
	var flutter_amp := FLUTTER_ACCEL * params.turbulence * (0.3 + local_strength)
	var gravity := Vector3(0.0, -GRAVITY, 0.0)
	var dt2 := STEP * STEP
	for i in _pos.size():
		if _inv_mass[i] == 0.0:
			continue
		var p := _pos[i]
		var n := _normals[i]
		# A net is porous: it takes part of the push even edge-on, the rest
		# through the face it shows to the wind.
		var facing := 0.35 + 0.65 * absf(n.dot(wind))
		var col := i % _cols
		var row := i / _cols
		var flutter := sin(time * 2.7 + float(col) * 0.55 + float(row) * 0.8 + _phase)
		var accel := (
			gravity
			+ wind * (WIND_ACCEL * local_strength * facing)
			+ across * (flutter * flutter_amp)
		)
		var next := p + (p - _prev[i]) * DAMPING + accel * dt2
		_prev[i] = p
		_pos[i] = next
	for _iteration in ITERATIONS:
		for k in _rest.size():
			var a := _pairs[k * 2]
			var b := _pairs[k * 2 + 1]
			var wa := _inv_mass[a]
			var wb := _inv_mass[b]
			var w := wa + wb
			if w == 0.0:
				continue
			var delta := _pos[b] - _pos[a]
			var dist := delta.length()
			if dist < 0.00001:
				continue
			var correction := delta * ((dist - _rest[k]) / (dist * w))
			_pos[a] += correction * wa
			_pos[b] -= correction * wb
	# The shore under the rack is treated as flat at the rack origin; hems that
	# reach it drag instead of sinking.
	for i in _pos.size():
		if _pos[i].y < GROUND_CLEARANCE:
			_pos[i].y = GROUND_CLEARANCE
			_prev[i].x = lerpf(_prev[i].x, _pos[i].x, 0.5)
			_prev[i].z = lerpf(_prev[i].z, _pos[i].z, 0.5)
	_compute_normals()


func _compute_normals() -> void:
	for row in _rows:
		for col in _cols:
			var left := _pos[row * _cols + maxi(col - 1, 0)]
			var right := _pos[row * _cols + mini(col + 1, _cols - 1)]
			var down := _pos[maxi(row - 1, 0) * _cols + col]
			var up := _pos[mini(row + 1, _rows - 1) * _cols + col]
			var n := (right - left).cross(up - down)
			_normals[row * _cols + col] = (
				n.normalized() if n.length_squared() > 0.0 else Vector3.BACK
			)


func _update_mesh() -> void:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _pos
	arrays[Mesh.ARRAY_NORMAL] = _normals
	arrays[Mesh.ARRAY_TEX_UV] = _uvs
	arrays[Mesh.ARRAY_INDEX] = _indices
	_mesh.clear_surfaces()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_update_weights()


# --- floats and sinkers --------------------------------------------------------


func _build_weights() -> void:
	_floats = _weight_multimesh("Floats", _float_mesh(), (_cols + FLOAT_EVERY - 1) / FLOAT_EVERY)
	_sinkers = _weight_multimesh(
		"Sinkers", _sinker_mesh(), (_cols + SINKER_EVERY - 1) / SINKER_EVERY
	)


func _weight_multimesh(node_name: String, mesh: Mesh, count: int) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = count
	mm.custom_aabb = _mesh.custom_aabb
	var inst := MultiMeshInstance3D.new()
	inst.name = node_name
	inst.multimesh = mm
	add_child(inst)
	return inst


func _update_weights() -> void:
	# Bark floats ride the bottom hem of the front (float) side, stone sinkers
	# the hem behind the pole, so both follow the cloth instead of floating free.
	var k := 0
	for col in range(0, _cols, FLOAT_EVERY):
		_floats.multimesh.set_instance_transform(k, _hem_transform(col, 0))
		k += 1
	k = 0
	for col in range(0, _cols, SINKER_EVERY):
		_sinkers.multimesh.set_instance_transform(k, _hem_transform(col, _rows - 1))
		k += 1


func _hem_transform(col: int, row: int) -> Transform3D:
	var i := row * _cols + col
	var along := _pos[row * _cols + mini(col + 1, _cols - 1)] - _pos[row * _cols + maxi(col - 1, 0)]
	if along.is_zero_approx():
		along = Vector3.RIGHT
	var x := along.normalized()
	var n := _normals[i]
	var y := n.cross(x)
	if y.length_squared() < 0.0001:
		y = Vector3.UP
	y = y.normalized()
	var z := x.cross(y).normalized()
	return Transform3D(Basis(x, y, z), _pos[i])


# --- shared resources ------------------------------------------------------------


static func net_material() -> ShaderMaterial:
	if _cache.has(&"net"):
		return _cache[&"net"]
	var material := ShaderMaterial.new()
	material.shader = NET_SHADER
	material.set_shader_parameter(&"twine_color", TWINE_GREY)
	material.set_shader_parameter(&"gather", GATHER)
	_cache[&"net"] = material
	return material


## Grey weathered pole timber, the same stock the shore fences are cut from.
static func pole_wood() -> StandardMaterial3D:
	if _cache.has(&"pole_wood"):
		return _cache[&"pole_wood"]
	var material := StandardMaterial3D.new()
	material.albedo_texture = load(POLE_WOOD_STEM + "_albedo.png")
	material.albedo_color = Color(0.7, 0.66, 0.6)
	material.normal_enabled = true
	material.normal_texture = load(POLE_WOOD_STEM + "_normal.png")
	material.uv1_scale = Vector3(0.5, 2.0, 1.0)
	material.roughness = 0.95
	_cache[&"pole_wood"] = material
	return material


static func _lashing_material() -> StandardMaterial3D:
	if _cache.has(&"lashing"):
		return _cache[&"lashing"]
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.34, 0.32, 0.27)
	material.roughness = 1.0
	_cache[&"lashing"] = material
	return material


static func _float_mesh() -> Mesh:
	if _cache.has(&"float"):
		return _cache[&"float"]
	# Rolled birch-bark float, threaded on the headrope along the hem.
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.045
	mesh.bottom_radius = 0.045
	mesh.height = 0.13
	mesh.radial_segments = 8
	mesh.rings = 1
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.56, 0.47, 0.35)
	material.roughness = 0.95
	mesh.material = material
	# Lie the float along the hem (local x) instead of upright.
	var arrays := mesh.get_mesh_arrays()
	var rotated := ArrayMesh.new()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var turn := Basis(Vector3.BACK, PI * 0.5)
	for v in verts.size():
		verts[v] = turn * verts[v]
		normals[v] = turn * normals[v]
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = null
	rotated.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	rotated.surface_set_material(0, material)
	_cache[&"float"] = rotated
	return rotated


static func _sinker_mesh() -> Mesh:
	if _cache.has(&"sinker"):
		return _cache[&"sinker"]
	# Pierced beach stone tied to the footrope.
	var mesh := SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.07
	mesh.radial_segments = 8
	mesh.rings = 4
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.4, 0.4, 0.38)
	material.roughness = 0.9
	mesh.material = material
	_cache[&"sinker"] = mesh
	return mesh


static func reset_cache() -> void:
	_cache.clear()
