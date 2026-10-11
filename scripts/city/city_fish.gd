class_name CityFish
extends Node3D

## Schools of Baltic herring and the odd perch over the shallows (kalamaja-fishing-
## shore-1343.md: the shore lives off spring herring). Deterministic school
## centres on 0.35 to 1.1 m of water; a school is only alive while Kalev is within
## RANGE of it, then its fish circle and dart in a tight shoal just under the
## surface. Visual only: nothing here is caught, hit or saved.

const CELL := 14.0
const RANGE := 70.0
const FREE_RANGE := 95.0
const MAX_SCHOOLS := 7
const FISH_PER_SCHOOL := 11
const SEED := 4141
## Preserve deterministic school IDs in the clear shallows.
const MIN_DEPTH := 0.35
const MAX_DEPTH := 1.1
## Generated, textured models (tools/assets/fish/): one mesh each, in the mesh-space
## box fish_transform fits to the water column. UV2.y is the part (0 body, 1 fin).
const HERRING_MODEL := preload("res://assets/animals/fish/herring/herring.gltf")
const PERCH_MODEL := preload("res://assets/animals/fish/perch/perch.gltf")
const HERRING_ALBEDO := preload("res://assets/animals/fish/herring/herring_albedo.png")
const PERCH_ALBEDO := preload("res://assets/animals/fish/perch/perch_albedo.png")
## Uniform instance scale: the models keep the proportions of their illustrations.
const HERRING_SCALE := 0.26
const PERCH_SCALE := 0.3
const PerfProbeScript := preload("res://scripts/debug/perf_probe.gd")

var plan: CityPlan
var player: Node2D
var _centres: Array[Dictionary] = []
var _live: Dictionary = {}
var _fish_mesh: Mesh
var _perch_mesh: Mesh
var _fish_material: ShaderMaterial
var _perch_material: ShaderMaterial
var _since := 1.0
var _time := 0.0


static func create(city_plan: CityPlan, kalev: Node2D) -> CityFish:
	var node := CityFish.new()
	node.name = "Fish"
	node.plan = city_plan
	node.player = kalev
	node._centres = school_centres(city_plan)
	node._prepare()
	return node


## Deterministic schools: {id, at: Vector2, depth, species}. Pure data for tests.
static func school_centres(city_plan: CityPlan) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var r := city_plan.bounds
	for j in int(r.size.y / CELL):
		for i in int(r.size.x / CELL):
			var rng := RandomNumberGenerator.new()
			rng.seed = hash(Vector2i(i, j)) ^ SEED
			if rng.randf() > 0.3:
				continue
			var at := r.position + (Vector2(i, j) + Vector2(rng.randf(), rng.randf())) * CELL
			var depth := -city_plan.ground_height(at)
			if depth < MIN_DEPTH or depth > MAX_DEPTH:
				continue
			(
				out
				. append(
					{
						"id": "school.%d.%d" % [i, j],
						"at": at,
						"depth": depth,
						"species": &"perch" if rng.randf() < 0.18 else &"herring",
					}
				)
			)
	return out


func _prepare() -> void:
	_fish_mesh = species_mesh(false)
	_perch_mesh = species_mesh(true)
	_fish_material = _species_material(HERRING_ALBEDO, 1.0)
	_perch_material = _species_material(PERCH_ALBEDO, 0.0)


## The single mesh of a species model: +X forward, nose at x 0.5, tail tips no
## further back than x -0.78, every fin inside y -0.24..0.29 and z +-0.24.
static func species_mesh(perch: bool) -> Mesh:
	var scene := (PERCH_MODEL if perch else HERRING_MODEL).instantiate()
	var holder := scene.find_children("*", "MeshInstance3D", true, false)
	var mesh: Mesh = (holder[0] as MeshInstance3D).mesh
	scene.free()
	return mesh


static func _species_material(albedo: Texture2D, silver: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = preload("res://scripts/city/city_fish.gdshader")
	material.set_shader_parameter("albedo_tex", albedo)
	material.set_shader_parameter("silver", silver)
	return material


func live_count() -> int:
	return _live.size()


func _process(delta: float) -> void:
	var probe_start := PerfProbeScript.start()
	_process_timed(delta)
	PerfProbeScript.stop(&"fish", probe_start)


func _process_timed(delta: float) -> void:
	_time += delta
	if player == null:
		return
	var me := CityPlan.to_world_xz(player.global_position)
	_since += delta
	if _since >= 0.6:
		_since = 0.0
		_stream(me)
	for id: String in _live:
		_animate(_live[id])


func _stream(me: Vector2) -> void:
	for id: String in _live.keys():
		if (_live[id]["centre"] as Vector2).distance_to(me) > FREE_RANGE:
			(_live[id]["node"] as Node).queue_free()
			_live.erase(id)
	for c in _centres:
		if _live.size() >= MAX_SCHOOLS:
			break
		if _live.has(c["id"]) or (c["at"] as Vector2).distance_to(me) > RANGE:
			continue
		_live[c["id"]] = _spawn(c)


func _spawn(c: Dictionary) -> Dictionary:
	var node := MultiMeshInstance3D.new()
	node.name = String(c["id"]).replace(".", "_")
	node.multimesh = MultiMesh.new()
	node.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	node.multimesh.use_custom_data = true
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(c["id"])
	var perch: bool = c["species"] == &"perch"
	var count := 5 if perch else FISH_PER_SCHOOL
	node.multimesh.instance_count = count
	node.multimesh.mesh = _perch_mesh if perch else _fish_mesh
	# Override, not surface material: the imported GLB mesh is a shared resource.
	node.material_override = _perch_material if perch else _fish_material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	var fish: Array[Dictionary] = []
	for k in count:
		var phase := rng.randf() * TAU
		node.multimesh.set_instance_custom_data(k, Color(phase, float(perch), 0, 0))
		fish.append(
			{
				"phase": phase,
				"r": rng.randf_range(0.4, 1.5),
				"dy": rng.randf_range(0.12, 0.27),
				"speed": rng.randf_range(0.25, 0.5),
				"scale": Vector3.ONE * (PERCH_SCALE if perch else HERRING_SCALE)
			}
		)
	return {"node": node, "centre": c["at"], "fish": fish, "swing": rng.randf() * TAU}


## Reject a wander into the bank instead of letting fish orbit through dry sand.
static func wet_position(city_plan: CityPlan, centre: Vector2, candidate: Vector2) -> Vector2:
	var p := candidate
	for _attempt in 4:
		if city_plan.ground_height(p) < -0.22:
			return p
		p = p.lerp(centre, 0.5)
	return centre


func _animate(school: Dictionary) -> void:
	var node: MultiMeshInstance3D = school["node"]
	var fish: Array = school["fish"]
	for i in fish.size():
		node.multimesh.set_instance_transform(i, fish_transform(plan, school, fish[i], _time))


static func fish_transform(
	city_plan: CityPlan, school: Dictionary, fish: Dictionary, time: float
) -> Transform3D:
	var centre: Vector2 = school["centre"]
	var drift := (
		Vector2(
			cos(time * 0.15 + float(school["swing"])), sin(time * 0.12 + float(school["swing"]))
		)
		* 0.65
	)
	var a: float = time * float(fish["speed"]) + float(fish["phase"])
	var candidate := centre + drift + Vector2(cos(a), sin(a)) * float(fish["r"])
	var p := wet_position(city_plan, centre, candidate)
	var basis := Basis(Vector3.UP, -atan2(cos(a), -sin(a))).scaled(fish["scale"])
	# Fit the full fins/tail, not just the origin, between the sloping bed and
	# the rest surface. Four footprint corners bound the small body conservatively.
	var bed := city_plan.ground_height(p)
	for x: float in [-0.78, 0.5]:
		for z: float in [-0.24, 0.24]:
			var corner := basis * Vector3(x, 0.0, z)
			bed = maxf(bed, city_plan.ground_height(p + Vector2(corner.x, corner.z)))
	var scale_y: float = fish["scale"].y
	var fit := clampf((-bed - 0.10) / (0.53 * scale_y), 0.0, 1.0)
	basis = basis.scaled(Vector3.ONE * fit)
	var floor_y := bed + 0.05 + 0.24 * scale_y * fit
	var ceiling_y := -0.05 - 0.29 * scale_y * fit
	var preferred := -float(fish["dy"]) + 0.025 * sin(time * 2.0 + float(fish["phase"]))
	var y := clampf(preferred, minf(floor_y, ceiling_y), ceiling_y)
	return Transform3D(basis, Vector3(p.x, y, p.y))
