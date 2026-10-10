extends "res://scenes/world/sites/site_level.gd"

## Act 2 hinterland sites (docs/SYSTEMS/REGIONAL_SITES.md): the Harju village,
## the rebel kings' camp and the sacred grove. The regional site level plus the
## few things the plan pipeline does not draw, read from the plan's points of
## interest by kind, so the overlay stays the one source:
##   smoke           a plume over a smoke room or sauna (no chimney: the smoke
##                   leaves through the gable), at `smoke_h_m` above the ground
##   campfire        stone ring, logs, flame, flickering light and a plume,
##                   scaled by `fire_size`; bright at night, embers by day
##   offering_stone  a cup-marked granite boulder (lohukivi) of `size_m`
##                   [length, width, height]; `offerings` puts bread, wool, wax
##                   and coins on it
##   spring          a small pool of `radius_m` with a stone rim
##   holy_oak        the authored ancient oak at `yaw_deg`; `votive_band` ties
##                   linen and wool strips round its bole
##   torch           a tar torch (torvik) on a stake, lit only at night
##   leanto          the grove keeper's pole-and-bark lean-to at `yaw_deg`
##   boundary_cairn  a heap of field stones at the edge of the hiis
## The hiis models come from tools/assets/build_sacred_grove_props.py (R-1660).
## Plumes join the shared chimney-smoke streamer (CityChimneySmoke), so they
## take the world wind and the day/night schedule like the city's chimneys.
## Stones, fire rings, the spring rim, the oak bole, the lean-to and the cairns
## are solid on the logic plane.
##
## Start directly:
##   godot --path . res://scenes/world/sites/rebel_kings.tscn -- --city-spawn=from_world_harju

const DayNightCycle := preload("res://scripts/global/day_night_cycle.gd")
const STONE_ALBEDO := "res://assets/materials/pbr/stone/stone_albedo.png"
const STONE_NORMAL := "res://assets/materials/pbr/stone/stone_normal.png"
const TIMBER_ALBEDO := "res://assets/materials/pbr/timber/timber_albedo.png"
const FIRE_STONES := 9
const PROPS_DIR := "res://assets/props/environment"
const HOLY_OAK_SCENE := PROPS_DIR + "/sacred_grove_ancient_oak/sacred_grove_ancient_oak.glb"
## Reference size of the boulder model (length, height, width), scaled to `size_m`.
const BOULDER_SIZE := Vector3(2.4, 1.0, 1.8)
## Torch head above the ground (top of the resin cap in the model).
const TORCH_HEAD_Y := 1.6
## Collision radius (m) per model kind; offering stones and springs use their size.
const PROP_RADIUS := {"holy_oak": 2.0, "torch": 0.15, "leanto": 1.9, "boundary_cairn": 0.75}
## GLB material name -> shared PBR set [albedo, normal, uv scale, tint]: the hiis
## props ship flat colours and take the shore granite (as the coast's erratics)
## and the tree barks here, triplanar. The granite plate is pale; a boulder in
## the grass shade is a mid tone.
const GRANITE_ALBEDO := "res://assets/props/environment/shore/shore_granite_albedo.png"
const GRANITE_NORMAL := "res://assets/props/environment/shore/shore_granite_normal.png"
const BARK_DIR := "res://assets/materials/pbr/"
const PBR_SWAPS := {
	"hiis_granite": [GRANITE_ALBEDO, GRANITE_NORMAL, 0.7, Color(0.66, 0.65, 0.63)],
	"hiis_fieldstone": [GRANITE_ALBEDO, GRANITE_NORMAL, 1.3, Color(0.7, 0.68, 0.64)],
	"hiis_pine_bark":
	[
		BARK_DIR + "bark_pine/bark_pine_albedo.jpg",
		BARK_DIR + "bark_pine/bark_pine_normal.jpg",
		2.0,
		Color.WHITE,
	],
	"hiis_spruce_bark":
	[
		BARK_DIR + "bark_spruce/bark_spruce_albedo.jpg",
		BARK_DIR + "bark_spruce/bark_spruce_normal.jpg",
		1.2,
		Color.WHITE,
	],
}

static var _pbr_cache: Dictionary = {}

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
				var stone := _offering_stone(Vector3(xz.x, ground, xz.y), Vector3(s[0], s[2], s[1]), id)
				if bool(poi.get("offerings", false)):
					_add_offerings(stone, id)
				root.add_child(stone)
			"spring":
				root.add_child(_spring(Vector3(xz.x, ground, xz.y), float(poi.get("radius_m", 2.5)), id))
			"holy_oak":
				var oak := _model(
					"HolyOak", HOLY_OAK_SCENE, Vector3(xz.x, ground, xz.y), float(poi.get("yaw_deg", 0.0)), id
				)
				if bool(poi.get("votive_band", false)):
					# Fitted to this oak's bole in the same frame (see the generator).
					oak.add_child(_prop_scene("hiis_votive_band").instantiate())
				root.add_child(oak)
			"torch":
				root.add_child(_torch(Vector3(xz.x, ground, xz.y), id))
			"leanto":
				root.add_child(
					_model(
						"Leanto",
						_prop_path("hiis_keeper_leanto"),
						Vector3(xz.x, ground, xz.y),
						float(poi.get("yaw_deg", 0.0)),
						id
					)
				)
			"boundary_cairn":
				var yaw := float(String(id).hash() % 360)
				root.add_child(
					_model("Cairn", _prop_path("hiis_boundary_cairn"), Vector3(xz.x, ground, xz.y), yaw, id)
				)
	apply_dressing_cycle(root, 0.5)
	return root


## Day/night for the fires (DomesticHearthLight3D under each campfire and torch).
## Torches are put out in daylight rather than dimmed: the hearth controller
## keeps a little light at dawn and dusk, which reads as a torch burning at noon.
static func apply_dressing_cycle(root: Node3D, progress: float) -> void:
	var lit := DayNightCycle.day_blend(progress) < 0.5
	for hearth: Node in root.find_children("DomesticHearthLight", "", true, false):
		hearth.call("apply_cycle_progress", progress)
		var torch := hearth.get_parent()
		if String(torch.name).begins_with("Torch_"):
			for flame: GPUParticles3D in torch.find_children("*", "GPUParticles3D", false, false):
				flame.emitting = flame.emitting and lit
			for light: OmniLight3D in torch.find_children("*", "OmniLight3D", false, false):
				light.visible = lit


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
	var yaw := float(String(id).hash() % 360)
	var root := _model("OfferingStone", _prop_path("hiis_cupmark_boulder"), at, yaw, id)
	# Scale the boulder body, not the root: offerings set on it keep their size.
	var boulder := root.get_child(0) as Node3D
	boulder.scale = size / BOULDER_SIZE
	root.set_meta(&"top_y", _top_y(boulder))
	return root


## Bread, wool, wax and coins on the stone's flattened top, a little off centre.
static func _add_offerings(stone: Node3D, id: StringName) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = String(id).hash() + 1
	var gifts := _prop_scene("hiis_offerings").instantiate() as Node3D
	gifts.name = "Offerings"
	var top := float(stone.get_meta(&"top_y"))
	gifts.position = Vector3(rng.randf_range(-0.12, 0.12), top - 0.03, rng.randf_range(-0.08, 0.08))
	gifts.rotation.y = rng.randf() * TAU
	stone.add_child(gifts)


## Highest point of a model's meshes, in the model's parent frame.
static func _top_y(model: Node3D) -> float:
	var top := 0.0
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var to_parent := model.transform * _transform_under(mesh, model)
		var box := mesh.get_aabb()
		for i in 8:
			top = maxf(top, (to_parent * box.get_endpoint(i)).y)
	return top


static func _transform_under(node: Node3D, ancestor: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var n: Node = node
	while n != ancestor and n is Node3D:
		xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf


static func _torch(at: Vector3, id: StringName) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = String(id).hash()
	var torch := _model("Torch", _prop_path("hiis_tar_torch"), at, rng.randf() * 360.0, id)
	var flame := CandleFlame3D.new()
	flame.configure({"flame_size": 2.2, "flame_particles": 8})
	flame.position = Vector3(0.02, TORCH_HEAD_Y, -0.01)
	torch.add_child(flame)
	var light := OmniLight3D.new()
	light.position = Vector3(0.02, TORCH_HEAD_Y + 0.25, -0.01)
	torch.add_child(light)
	# Out by day (no energy, no flame); lit for the night.
	var hearth := DomesticHearthLight3D.new()
	hearth.configure(
		light,
		flame,
		null,
		{
			"range": 9.0,
			"day_energy": 0.0,
			"night_energy": 2.2,
			"flame_size": 1.0,
			"flicker_phase": rng.randf() * 10.0,
		}
	)
	torch.add_child(hearth)
	return torch


## A model under a named root at `at`, turned `yaw_deg`; hiis materials take PBR.
static func _model(
	prefix: String, path: String, at: Vector3, yaw_deg: float, id: StringName
) -> Node3D:
	var root := Node3D.new()
	root.name = "%s_%s" % [prefix, String(id).get_slice(".", String(id).get_slice_count(".") - 1)]
	root.position = at
	root.rotation.y = deg_to_rad(yaw_deg)
	var model := MapViewPackedScenes.load_scene(path).instantiate() as Node3D
	root.add_child(model)
	_swap_pbr(model)
	return root


static func _prop_path(stem: String) -> String:
	return "%s/%s/%s.glb" % [PROPS_DIR, stem, stem]


static func _prop_scene(stem: String) -> PackedScene:
	return MapViewPackedScenes.load_scene(_prop_path(stem))


static func _swap_pbr(model: Node) -> void:
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for i in mesh.mesh.get_surface_count():
			var surface := mesh.mesh.surface_get_material(i)
			var mat_name := String(surface.resource_name) if surface != null else ""
			if PBR_SWAPS.has(mat_name):
				mesh.set_surface_override_material(i, _pbr_material(mat_name))


static func _pbr_material(mat_name: String) -> StandardMaterial3D:
	if not _pbr_cache.has(mat_name):
		var spec: Array = PBR_SWAPS[mat_name]
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = load(spec[0])
		mat.normal_enabled = true
		mat.normal_texture = load(spec[1])
		mat.albedo_color = spec[3]
		mat.roughness = 0.92
		mat.uv1_triplanar = true
		mat.uv1_scale = Vector3.ONE * float(spec[2])
		_pbr_cache[mat_name] = mat
	return _pbr_cache[mat_name]


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


## Fire rings, stones, the spring rim and the hiis models block the walker like
## the buildings do.
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
			var kind:
				radius = float(PROP_RADIUS.get(kind, 0.0))
		if radius <= 0.0:
			continue
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = radius * CityPlan.LOGIC_PX_PER_UNIT
		shape.shape = circle
		shape.position = CityPlan.to_logic(Vector2(poi["at"][0], poi["at"][1]))
		body.add_child(shape)
	add_child(body)
