class_name AlmshouseStage
extends Node3D
## Staged backdrop for the almshouse spell duel (R-1334, ADR 0033): a small hall of the
## Holy Spirit almshouse with the apprentice and Porter Hanß facing each other under a
## fixed two-shot camera. Warm hearth light falls on the hero's side, cold window light on
## the porter's, so the duel reads as the boy against the house. Everything is built from
## existing assets (P0-040 asset freeze): realistic-human rigs, the hearth / table / chest
## prop kits and the shared PBR plaster, stone and timber textures. No gameplay lives here.

const HERO_SCENE := preload("res://assets/characters/variants/apprentice.tscn")
## No bespoke porter body exists yet; a heavy adult townsman reads as the gruff keyholder.
const PORTER_SCENE := preload("res://assets/characters/variants/citizen_m_adult_heavy.tscn")
const HEARTH_KIT := preload("res://assets/props/domestic/hearth/medieval_hearth_kit.glb")
const TABLE_KIT := preload("res://assets/props/furniture/tables/medieval_table_kit/medieval_table_kit.glb")  # gdlint: ignore=max-line-length
const CHEST := preload("res://assets/props/furniture/chest_poor_household/chest_poor_household.glb")  # gdlint: ignore=max-line-length
const PLASTER := preload("res://assets/materials/pbr/plaster/plaster_albedo.png")
const STONE := preload("res://assets/materials/pbr/stone/stone_albedo.png")
const TIMBER_FLOOR := preload("res://assets/materials/pbr/timber_floor/timber_floor_albedo.png")

## Hall interior: x across the frame, z toward the camera, back wall at -HALL_DEPTH.
const HALL_HALF_WIDTH := 4.5
const HALL_DEPTH := 3.0
const HALL_HEIGHT := 3.8
## The two duellists stand this far either side of the frame centre.
const DUEL_HALF_GAP := 0.95
## Turned slightly toward the camera (90 would be pure profile).
const FACING_DEG := 72.0
const CAMERA_POSITION := Vector3(0.0, 1.5, 3.6)
const CAMERA_TARGET := Vector3(0.0, 1.2, 0.0)
const CAMERA_FOV := 40.0
const WARM := Color(1.0, 0.62, 0.32)
const COLD := Color(0.55, 0.68, 1.0)

var _hero: Node3D
var _porter: Node3D
var _camera: Camera3D


func _ready() -> void:
	_build_environment()
	_build_hall()
	_build_props()
	_build_lights()
	_hero = _place_actor(HERO_SCENE, "Hero", -DUEL_HALF_GAP, FACING_DEG)
	_porter = _place_actor(PORTER_SCENE, "Porter", DUEL_HALF_GAP, -FACING_DEG)
	_camera = Camera3D.new()
	_camera.name = "Camera"
	_camera.fov = CAMERA_FOV
	add_child(_camera)
	_camera.look_at_from_position(CAMERA_POSITION, CAMERA_TARGET)
	_camera.current = true


func hero() -> Node3D:
	return _hero


func porter() -> Node3D:
	return _porter


func camera() -> Camera3D:
	return _camera


func _notification(what: int) -> void:
	# WHY: the rigs only detach their geometry when queued for deletion; a direct free() of
	# the opening (tests do this) lets the headless dummy renderer free imported materials
	# before their mesh RIDs and log false errors. Script PREDELETE arrives before Node
	# frees the children, so detaching here covers every rig and prop under the stage.
	if what == NOTIFICATION_PREDELETE:
		SharedCharacterRig._detach_render_geometry(self)


func _place_actor(scene: PackedScene, actor_name: String, x: float, yaw_deg: float) -> Node3D:
	var actor := scene.instantiate() as Node3D
	actor.name = actor_name
	actor.position = Vector3(x, 0.0, 0.0)
	actor.rotation_degrees.y = yaw_deg
	add_child(actor)
	# The combat health ring means nothing in a cinematic two-shot.
	var ring := actor.get_node_or_null(^"HealthRing") as Node3D
	if ring != null:
		ring.visible = false
	return actor


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.02, 0.03)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.30, 0.38)
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.fog_enabled = true
	env.fog_light_color = Color(0.10, 0.09, 0.12)
	env.fog_density = 0.02
	var world_env := WorldEnvironment.new()
	world_env.name = "Environment"
	world_env.environment = env
	add_child(world_env)


func _build_hall() -> void:
	var floor_mat := _textured(TIMBER_FLOOR, Vector3(0.6, 0.6, 0.6), Color(0.75, 0.68, 0.6))
	var plaster := _textured(PLASTER, Vector3(0.4, 0.4, 0.4), Color(0.78, 0.74, 0.66))
	var stone := _textured(STONE, Vector3(0.5, 0.5, 0.5), Color(0.7, 0.7, 0.72))
	var beam := _textured(TIMBER_FLOOR, Vector3(1.0, 1.0, 1.0), Color(0.42, 0.32, 0.24))
	var width := HALL_HALF_WIDTH * 2.0
	var depth := HALL_DEPTH + 4.0
	var mid_z := -HALL_DEPTH + depth * 0.5
	_box("Floor", Vector3(width, 0.1, depth), Vector3(0, -0.05, mid_z), floor_mat)
	var back_at := Vector3(0, HALL_HEIGHT * 0.5, -HALL_DEPTH)
	_box("BackWall", Vector3(width, HALL_HEIGHT, 0.3), back_at, plaster)
	# A stone plinth course along the back wall, as in the stone almshouse halls.
	_box("Plinth", Vector3(width, 0.7, 0.36), Vector3(0, 0.35, -HALL_DEPTH + 0.02), stone)
	for side: float in [-1.0, 1.0]:
		_box(
			"SideWall%d" % int(side),
			Vector3(0.3, HALL_HEIGHT, depth),
			Vector3(side * HALL_HALF_WIDTH, HALL_HEIGHT * 0.5, mid_z),
			stone
		)
	_box("Ceiling", Vector3(width, 0.1, depth), Vector3(0, HALL_HEIGHT, mid_z), beam)
	for index in 4:
		_box(
			"Beam%d" % index,
			Vector3(width, 0.22, 0.24),
			Vector3(0, HALL_HEIGHT - 0.2, -HALL_DEPTH + 0.6 + index * 1.4),
			beam
		)
	# The cold side: a deep stone window behind the porter, glowing with grey spring dawn.
	var frame := Vector3(2.1, 2.1, -HALL_DEPTH + 0.05)
	_box("WindowReveal", Vector3(1.0, 1.5, 0.12), frame, stone)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = COLD
	glass.emission_enabled = true
	glass.emission = COLD
	glass.emission_energy_multiplier = 1.2
	_box("WindowLight", Vector3(0.7, 1.2, 0.04), frame + Vector3(0, 0, 0.08), glass)
	_box("WindowMullion", Vector3(0.06, 1.2, 0.06), frame + Vector3(0, 0, 0.11), beam)


func _build_props() -> void:
	# The kit holds cold / embers / lit variants on one origin; show only the lit one.
	var hearth := HEARTH_KIT.instantiate() as Node3D
	hearth.name = "Hearth"
	hearth.position = Vector3(-2.3, 0.0, -HALL_DEPTH + 0.25)
	hearth.rotation_degrees.y = 180.0
	hearth.scale = Vector3.ONE * 1.2
	add_child(hearth)
	_show_only(hearth, &"HearthLit")
	var table := TABLE_KIT.instantiate() as Node3D
	table.name = "Table"
	table.position = Vector3(3.0, 0.0, -1.4)
	table.rotation_degrees.y = 90.0
	add_child(table)
	_show_only(table, &"LongBoardTable")
	var chest := CHEST.instantiate() as Node3D
	chest.name = "Chest"
	chest.position = Vector3(1.0, 0.0, -HALL_DEPTH + 0.55)
	add_child(chest)


func _build_lights() -> void:
	var hearth_light := OmniLight3D.new()
	hearth_light.name = "HearthLight"
	hearth_light.light_color = WARM
	hearth_light.light_energy = 3.0
	hearth_light.omni_range = 7.0
	# No shadows: from in front of the hearth they throw the kit and the hero as giant
	# black cut-outs onto the back wall. The window spot carries the shadows instead.
	hearth_light.position = Vector3(-2.2, 0.7, -HALL_DEPTH + 1.0)
	add_child(hearth_light)
	# Warm key on the hero's face from the hearth side.
	var warm_key := OmniLight3D.new()
	warm_key.name = "WarmKey"
	warm_key.light_color = WARM
	warm_key.light_energy = 1.2
	warm_key.omni_range = 4.0
	warm_key.position = Vector3(-2.2, 1.7, 1.2)
	add_child(warm_key)
	# Cold dawn through the window, raking across the porter.
	var window_light := SpotLight3D.new()
	window_light.name = "WindowLight"
	window_light.light_color = COLD
	window_light.light_energy = 4.0
	window_light.spot_range = 9.0
	window_light.spot_angle = 40.0
	window_light.shadow_enabled = true
	add_child(window_light)
	window_light.look_at_from_position(Vector3(2.4, 2.6, -HALL_DEPTH + 0.3), Vector3(0.6, 0.9, 0.6))
	var cold_rim := OmniLight3D.new()
	cold_rim.name = "ColdRim"
	cold_rim.light_color = COLD
	cold_rim.light_energy = 1.0
	cold_rim.omni_range = 4.0
	cold_rim.position = Vector3(2.4, 1.8, 1.0)
	add_child(cold_rim)


func _box(box_name: String, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = box_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	add_child(instance)
	return instance


static func _textured(texture: Texture2D, uv_scale: Vector3, tint: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.albedo_color = tint
	material.uv1_triplanar = true
	material.uv1_scale = uv_scale
	material.roughness = 0.9
	return material


static func _show_only(kit: Node, keep: StringName) -> void:
	var root := kit.get_child(0) if kit.get_child_count() == 1 else kit
	for child in root.get_children():
		if child is Node3D:
			(child as Node3D).visible = child.name == keep
