extends "res://scenes/world/sites/site_level.gd"

## Act 2 hinterland sites (docs/SYSTEMS/REGIONAL_SITES.md): the Harju village,
## the rebel kings' camp and the sacred grove. The regional site level plus the
## few things the plan pipeline does not draw, read from the plan's points of
## interest by kind, so the overlay stays the one source:
##   smoke           a plume over a smoke room or sauna (no chimney: the smoke
##                   leaves through the gable), at `smoke_h_m` above the ground
##   campfire        stone ring, logs, flame, flickering light and a plume,
##                   scaled by `fire_size`; bright at night, embers by day
##   offering_stone  a cup-marked boulder of `size_m` [length, width, height]
##   spring          a small pool of `radius_m` with a stone rim
## Plumes join the shared chimney-smoke streamer (CityChimneySmoke), so they
## take the world wind and the day/night schedule like the city's chimneys.
## Stones, fire rings and the spring rim are solid on the logic plane.
##
## Start directly:
##   godot --path . res://scenes/world/sites/rebel_kings.tscn -- --city-spawn=from_world_harju

const STONE_ALBEDO := "res://assets/materials/pbr/stone/stone_albedo.png"
const STONE_NORMAL := "res://assets/materials/pbr/stone/stone_normal.png"
const TIMBER_ALBEDO := "res://assets/materials/pbr/timber/timber_albedo.png"
const FIRE_STONES := 9

var dressing: Node3D


func _ready() -> void:
	super()
	dressing = dress(plan, world)
	_add_prop_collision()


func _process(delta: float) -> void:
	super(delta)
	if runtime != null and dressing != null:
		apply_dressing_cycle(dressing, runtime.cycle_progress)


## Builds the point-of-interest dressing under `world` and registers the
## plumes with its smoke streamer. Static so capture tools can dress a bare
## CityMapView the same way.
static func dress(site_plan: CityPlan, site_world: CityWorld3D) -> Node3D:
	var root := Node3D.new()
	root.name = "HinterlandDressing"
	site_world.add_child(root)
	for poi: Dictionary in site_plan.data.get("points_of_interest", []):
		var xz := Vector2(poi["at"][0], poi["at"][1])
		var ground := site_plan.ground_height(xz)
		var id := StringName(poi["id"])
		match String(poi.get("kind", "")):
			"smoke":
				var top := Vector3(xz.x, ground + float(poi.get("smoke_h_m", 4.0)), xz.y)
				site_world.smoke.lit.append([top, id])
			"campfire":
				var size := float(poi.get("fire_size", 1.0))
				root.add_child(_campfire(Vector3(xz.x, ground, xz.y), size, id))
				site_world.smoke.lit.append([Vector3(xz.x, ground + 0.9 * size, xz.y), id])
			"offering_stone":
				var s: Array = poi.get("size_m", [1.6, 1.1, 0.7])
				root.add_child(_offering_stone(Vector3(xz.x, ground, xz.y), Vector3(s[0], s[2], s[1]), id))
			"spring":
				root.add_child(_spring(Vector3(xz.x, ground, xz.y), float(poi.get("radius_m", 2.5)), id))
	apply_dressing_cycle(root, 0.5)
	return root


## Day/night for the fires (DomesticHearthLight3D under each campfire).
static func apply_dressing_cycle(root: Node3D, progress: float) -> void:
	for hearth: Node in root.find_children("DomesticHearthLight", "", true, false):
		hearth.call("apply_cycle_progress", progress)


static func _campfire(at: Vector3, size: float, id: StringName) -> Node3D:
	var fire := Node3D.new()
	fire.name = "Campfire_%s" % String(id).get_slice(".", String(id).get_slice_count(".") - 1)
	fire.position = at
	var rng := RandomNumberGenerator.new()
	rng.seed = String(id).hash()
	var stone := _stone_material()
	var ring_r := 0.62 * size
	for i in FIRE_STONES:
		var a := TAU * float(i) / FIRE_STONES + rng.randf_range(-0.12, 0.12)
		var mesh := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.16 * size
		sphere.height = 0.22 * size
		sphere.radial_segments = 8
		sphere.rings = 4
		mesh.mesh = sphere
		mesh.material_override = stone
		mesh.position = Vector3(cos(a) * ring_r, 0.05 * size, sin(a) * ring_r)
		mesh.scale = Vector3.ONE * rng.randf_range(0.8, 1.25)
		fire.add_child(mesh)
	# Three half-burnt logs leaning into the middle.
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.22, 0.17, 0.13)
	wood.roughness = 0.95
	for i in 3:
		var log_mesh := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.06 * size
		cyl.bottom_radius = 0.07 * size
		cyl.height = 0.9 * size
		cyl.radial_segments = 6
		log_mesh.mesh = cyl
		log_mesh.material_override = wood
		var a := TAU * float(i) / 3.0 + rng.randf() * 0.5
		log_mesh.position = Vector3(cos(a) * 0.22 * size, 0.14 * size, sin(a) * 0.22 * size)
		log_mesh.rotation = Vector3(0.0, -a, deg_to_rad(68.0))
		fire.add_child(log_mesh)
	var flame := CandleFlame3D.new()
	flame.configure({"flame_size": 6.5 * size, "flame_particles": 14})
	flame.position = Vector3(0, 0.12 * size, 0)
	fire.add_child(flame)
	var light := OmniLight3D.new()
	light.position = Vector3(0, 0.9 * size, 0)
	fire.add_child(light)
	var hearth := DomesticHearthLight3D.new()
	hearth.configure(
		light,
		flame,
		null,
		{
			"range": 14.0 * size,
			"day_energy": 0.35,
			"night_energy": 5.0 * size,
			"flame_size": 1.0,
			"flicker_phase": rng.randf() * 10.0,
		}
	)
	fire.add_child(hearth)
	return fire


static func _offering_stone(at: Vector3, size: Vector3, id: StringName) -> Node3D:
	var root := Node3D.new()
	root.name = "OfferingStone_%s" % String(id).get_slice(".", String(id).get_slice_count(".") - 1)
	root.position = at
	var rng := RandomNumberGenerator.new()
	rng.seed = String(id).hash()
	root.rotation.y = rng.randf() * TAU
	var boulder := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 14
	sphere.rings = 8
	boulder.mesh = sphere
	boulder.material_override = _stone_material()
	# Half sunk: a granite erratic shows its upper body only.
	boulder.scale = size
	boulder.position = Vector3(0, size.y * 0.18, 0)
	root.add_child(boulder)
	# Cup marks (lohud) on the top face, dark with old offerings.
	var cup_mat := StandardMaterial3D.new()
	cup_mat.albedo_color = Color(0.16, 0.15, 0.13)
	cup_mat.roughness = 1.0
	for i in rng.randi_range(4, 7):
		var cup := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = 0.06
		disc.bottom_radius = 0.045
		disc.height = 0.02
		disc.radial_segments = 10
		cup.mesh = disc
		cup.material_override = cup_mat
		var p := Vector2(rng.randf_range(-0.28, 0.28) * size.x, rng.randf_range(-0.22, 0.22) * size.z)
		var curve := 1.0 - (p.x * p.x) / (size.x * size.x * 0.25) - (p.y * p.y) / (size.z * size.z * 0.25)
		cup.position = Vector3(p.x, size.y * 0.18 + size.y * 0.5 * sqrt(maxf(curve, 0.0)) - 0.004, p.y)
		root.add_child(cup)
	return root


static func _spring(at: Vector3, radius: float, id: StringName) -> Node3D:
	var root := Node3D.new()
	root.name = "Spring_%s" % String(id).get_slice(".", String(id).get_slice_count(".") - 1)
	root.position = at
	var pool := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius * 0.8
	disc.height = 0.06
	disc.radial_segments = 24
	pool.mesh = disc
	pool.material_override = MapViewMaterials.water_surface(MapTypes.TERRAIN_SHALLOW_WATER)
	pool.position = Vector3(0, 0.04, 0)
	root.add_child(pool)
	var stone := _stone_material()
	var rng := RandomNumberGenerator.new()
	rng.seed = String(id).hash()
	var count := int(TAU * radius / 0.7)
	for i in count:
		var a := TAU * float(i) / count + rng.randf_range(-0.08, 0.08)
		var mesh := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = rng.randf_range(0.22, 0.34)
		sphere.height = sphere.radius * 1.3
		sphere.radial_segments = 8
		sphere.rings = 4
		mesh.mesh = sphere
		mesh.material_override = stone
		mesh.position = Vector3(cos(a) * (radius + 0.15), 0.06, sin(a) * (radius + 0.15))
		root.add_child(mesh)
	return root


static func _stone_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(STONE_ALBEDO)
	mat.normal_enabled = true
	mat.normal_texture = load(STONE_NORMAL)
	mat.albedo_color = Color(0.72, 0.7, 0.66)
	mat.roughness = 0.92
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(0.8, 0.8, 0.8)
	return mat


## Fire rings, stones and the spring rim block the walker like the buildings do.
func _add_prop_collision() -> void:
	var body := StaticBody2D.new()
	body.name = "HinterlandPropCollision"
	body.collision_layer = CollisionLayers.WORLD
	for poi: Dictionary in plan.data.get("points_of_interest", []):
		var radius := 0.0
		match String(poi.get("kind", "")):
			"campfire":
				radius = 0.75 * float(poi.get("fire_size", 1.0))
			"offering_stone":
				var s: Array = poi.get("size_m", [1.6, 1.1, 0.7])
				radius = 0.45 * maxf(float(s[0]), float(s[1]))
			"spring":
				radius = float(poi.get("radius_m", 2.5))
		if radius <= 0.0:
			continue
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = radius * CityPlan.LOGIC_PX_PER_UNIT
		shape.shape = circle
		shape.position = CityPlan.to_logic(Vector2(poi["at"][0], poi["at"][1]))
		body.add_child(shape)
	add_child(body)
