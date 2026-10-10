class_name CityFish
extends Node3D

## Schools of Baltic herring and the odd perch over the shallows (kalamaja-fishing-
## shore-1343.md: the shore lives off spring herring). Deterministic school
## centres on 0.35 to 1.1 m of water; a school is only alive while Kalev is within
## RANGE of it, then its fish circle and dart in a tight shoal just under the
## surface (the sea absorbs light fast, deeper fish would not be seen). Visual only: nothing here
## is caught, hit or saved.

const CELL := 14.0
const RANGE := 70.0
const FREE_RANGE := 95.0
const MAX_SCHOOLS := 7
const FISH_PER_SCHOOL := 11
const SEED := 4141
## The sea shader hides everything below about a metre of water, so the shoals
## keep to the clear shallows where the bed and the fish show through.
const MIN_DEPTH := 0.35
const MAX_DEPTH := 1.1

var plan: CityPlan
var player: Node2D
var _centres: Array[Dictionary] = []
var _live: Dictionary = {}
var _fish_mesh: Mesh
var _material: StandardMaterial3D
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
			out.append(
				{
					"id": "school.%d.%d" % [i, j],
					"at": at,
					"depth": depth,
					"species": &"perch" if rng.randf() < 0.18 else &"herring",
				}
			)
	return out


func _prepare() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 8
	mesh.rings = 4
	_fish_mesh = mesh
	_material = StandardMaterial3D.new()
	_material.albedo_color = Color(0.75, 0.8, 0.84)
	_material.metallic = 0.35
	_material.roughness = 0.35
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED


func live_count() -> int:
	return _live.size()


func _process(delta: float) -> void:
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
	var node := Node3D.new()
	node.name = String(c["id"]).replace(".", "_")
	add_child(node)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(c["id"])
	var perch: bool = c["species"] == &"perch"
	var fish: Array[Dictionary] = []
	for k in FISH_PER_SCHOOL if not perch else 5:
		var inst := MeshInstance3D.new()
		inst.mesh = _fish_mesh
		inst.material_override = _material
		inst.scale = Vector3(0.34, 0.07, 0.1) if not perch else Vector3(0.28, 0.12, 0.08)
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(inst)
		fish.append(
			{
				"node": inst,
				"phase": rng.randf() * TAU,
				"r": rng.randf_range(0.8, 3.2),
				"dy": rng.randf_range(0.1, 0.28),
				"speed": rng.randf_range(0.5, 1.1) * (1.0 if not perch else 0.45),
			}
		)
	return {"node": node, "centre": c["at"], "fish": fish, "swing": rng.randf() * TAU}


func _animate(school: Dictionary) -> void:
	var centre: Vector2 = school["centre"]
	var drift := Vector2(
		cos(_time * 0.05 + float(school["swing"])), sin(_time * 0.04 + float(school["swing"]))
	) * 5.0
	for f: Dictionary in school["fish"]:
		var a: float = _time * float(f["speed"]) + float(f["phase"])
		var pulse := 1.0 + 0.25 * sin(_time * 0.6 + float(f["phase"]))
		var p := centre + drift + Vector2(cos(a), sin(a)) * float(f["r"]) * pulse
		var node: MeshInstance3D = f["node"]
		node.position = Vector3(p.x, -float(f["dy"]) + 0.06 * sin(_time * 3.0 + float(f["phase"])), p.y)
		var tangent := Vector2(-sin(a), cos(a))
		node.rotation.y = -atan2(tangent.y, tangent.x)
