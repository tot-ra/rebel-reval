class_name AlmshouseStage
extends Node3D
## Staged backdrop for the almshouse spell duel (R-1334, ADR 0033): a small hall of the
## Holy Spirit almshouse with the apprentice and Porter Hanß facing each other under a
## fixed two-shot camera. Warm hearth light falls on the hero's side, cold window light on
## the porter's, so the duel reads as the boy against the house. Everything is built from
## existing assets (P0-040 asset freeze): realistic-human rigs, the hearth / table / chest
## prop kits and the shared PBR plaster, stone and timber textures. No gameplay lives here.
## R-1365: Kalev's rig steps into the back doorway for his scene and the camera reframes on
## him and the boy; the rigs answer the DialogueRunner speaker group (jaw while they speak)
## and flinch when a duel exchange lands on them.
## R-1389 (ADR 0038): the duel itself is fought on the 3D spirit disc. SpiritArena3D hides the
## hall around the two rigs; frame_arena() lifts the camera over the disc, move_hero() and
## dash_hero() are the boy's footwork, end_arena() puts both back on their marks for Kalev.

const HERO_SCENE := preload("res://assets/characters/variants/apprentice.tscn")
## No bespoke porter body exists yet; a heavy adult townsman reads as the gruff keyholder.
const PORTER_SCENE := preload("res://assets/characters/variants/citizen_m_adult_heavy.tscn")
const HEARTH_KIT := preload("res://assets/props/domestic/hearth/medieval_hearth_kit.glb")
const TABLE_KIT := preload("res://assets/props/furniture/tables/medieval_table_kit/medieval_table_kit.glb")  # gdlint: ignore=max-line-length
const KALEV_SCENE := preload("res://assets/characters/kalev/kalev.tscn")
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
## Speaker ids the rigs answer to in the dialogue speaker group. The porter borrows a crowd
## body, so his variant is re-keyed to the prologue character (see _place_actor).
const PORTER_SPEAKER_ID := &"char.almshouse_porter"
## The back-wall doorway Kalev appears in, between the hearth and the chest.
const DOOR_X := -0.3
const DOOR_WIDTH := 1.1
const DOOR_HEIGHT := 2.3
const KALEV_POSITION := Vector3(DOOR_X, 0.0, -HALL_DEPTH + 0.7)
## Kalev's two-shot: from the porter's side so the boy (front left) and Kalev (doorway)
## separate across the frame instead of stacking along the view axis.
const KALEV_CAMERA_POSITION := Vector3(1.7, 1.55, 3.3)
const KALEV_CAMERA_TARGET := Vector3(-0.55, 1.2, -1.1)
## The porter steps back beside the chest to make room for the smith, still in frame.
const PORTER_YIELD_POSITION := Vector3(1.4, 0.0, -1.9)
## Kalev stands against the dark doorway; without a key of his own he reads as a silhouette.
const KALEV_KEY_POSITION := Vector3(0.6, 2.1, -0.6)
## The rig's `hit` clip is one-shot; the actor returns to idle after this long.
const HIT_RECOVER_SEC := 0.8
## Spirit disc of the duel, centred between the duellists. Large enough for the porter's
## retreat (SpiritArenaMotion.FAR_DISTANCE) but framed whole by the arena camera.
const ARENA_RADIUS := 5.5
## How far from the hall's centre line the boy may stand: inside the side walls.
const ARENA_WALL_REACH := HALL_HALF_WIDTH - 0.5
const ARENA_CAMERA_POSITION := Vector3(0.0, 7.4, 9.8)
const ARENA_CAMERA_TARGET := Vector3(0.0, 0.2, 0.3)
const ARENA_CAMERA_FOV := 50.0
## On the disc the boy stands toward the camera (bottom of the screen) and the porter across
## the disc from him (top); the rigs face +Z, so the boy turns 180 degrees.
const ARENA_HALF_GAP := 1.8
const HERO_WALK_SPEED := 2.4
const HERO_GUARD_SPEED := 1.2
## The arena dodge is a short dash, long enough to clear an attack arc's edge.
const HERO_DASH_SPEED := 7.0
const HERO_DASH_SEC := 0.28

var _hero: Node3D
var _porter: Node3D
var _kalev: Node3D
var _camera: Camera3D
var _hero_mark: Transform3D
var _porter_mark: Transform3D
var _dash_left := 0.0
var _dash_direction := Vector3.ZERO


func _ready() -> void:
	_build_environment()
	_build_hall()
	_build_props()
	_build_lights()
	_hero = _place_actor(HERO_SCENE, "Hero", Vector3(-DUEL_HALF_GAP, 0, 0), FACING_DEG)
	_porter = _place_actor(
		PORTER_SCENE, "Porter", Vector3(DUEL_HALF_GAP, 0, 0), -FACING_DEG, PORTER_SPEAKER_ID
	)
	_camera = Camera3D.new()
	_camera.name = "Camera"
	_camera.fov = CAMERA_FOV
	add_child(_camera)
	_camera.look_at_from_position(CAMERA_POSITION, CAMERA_TARGET)
	_camera.current = true
	_hero_mark = _hero.transform
	_porter_mark = _porter.transform


func hero() -> Node3D:
	return _hero


func porter() -> Node3D:
	return _porter


## Null until bring_in_kalev().
func kalev() -> Node3D:
	return _kalev


func camera() -> Camera3D:
	return _camera


## Kalev's scene: his rig stands in the back doorway facing the boy, the porter yields
## toward the table and the camera reframes on hero + Kalev. Idempotent.
func bring_in_kalev() -> Node3D:
	if _kalev != null:
		return _kalev
	var kalev_yaw := _yaw_toward(KALEV_POSITION, _hero.position)
	_kalev = _place_actor(KALEV_SCENE, "Kalev", KALEV_POSITION, kalev_yaw)
	_porter.position = PORTER_YIELD_POSITION
	var between := (_hero.position + _kalev.position) * 0.5
	_porter.rotation_degrees.y = _yaw_toward(_porter.position, between)
	var key := OmniLight3D.new()
	key.name = "KalevKey"
	key.light_color = WARM
	key.light_energy = 1.4
	key.omni_range = 3.5
	key.position = KALEV_KEY_POSITION
	add_child(key)
	_camera.look_at_from_position(KALEV_CAMERA_POSITION, KALEV_CAMERA_TARGET)
	return _kalev


## Arena start marks: hero at the bottom of the screen, porter at the top. Call before the
## arena host reads the fighters' positions; end_arena() restores the two-shot marks.
func place_arena_marks() -> void:
	_hero.position = Vector3(0.0, 0.0, ARENA_HALF_GAP)
	_hero.rotation_degrees.y = 180.0
	_porter.position = Vector3(0.0, 0.0, -ARENA_HALF_GAP)
	_porter.rotation_degrees.y = 0.0


## Frame the whole spirit disc from above the front of the hall instead of the two-shot.
func frame_arena() -> void:
	# The interior cut-away: the roof comes off so the raised camera looks into the hall.
	_set_cutaway(false)
	_camera.fov = ARENA_CAMERA_FOV
	_camera.look_at_from_position(ARENA_CAMERA_POSITION, ARENA_CAMERA_TARGET)


## After the arena duel: both duellists back on their marks and the two-shot restored, so
## Kalev's scene (bring_in_kalev) frames the same hall whatever footwork the duel had.
func end_arena() -> void:
	_set_cutaway(true)
	_dash_left = 0.0
	_hero.transform = _hero_mark
	_porter.transform = _porter_mark
	_camera.fov = CAMERA_FOV
	_camera.look_at_from_position(CAMERA_POSITION, CAMERA_TARGET)
	_play(_hero, &"idle")
	_play(_porter, &"idle")


## The boy's arena footwork. `direction` is screen-relative (x right, y down); the arena camera
## looks down -Z, so it maps straight onto the floor. Guarding slows him and, like standing
## still, squares him up to the porter, so a raised guard faces the blow (SpiritArenaMotion).
## SpiritArenaHost clamps him to the disc after this moves him.
func move_hero(direction: Vector2, guarding: bool, delta: float) -> void:
	var speed := HERO_GUARD_SPEED if guarding else HERO_WALK_SPEED
	var velocity := Vector3(direction.x, 0.0, direction.y).limit_length(1.0) * speed
	var dashing := _dash_left > 0.0
	if dashing:
		_dash_left -= delta
		velocity = _dash_direction * HERO_DASH_SPEED
	_hero.position += velocity * delta
	# The hall walls stay in the duel and bound the footwork like the disc does.
	_hero.position.x = clampf(_hero.position.x, -ARENA_WALL_REACH, ARENA_WALL_REACH)
	var moving := velocity.length() > 0.01
	if (guarding and not dashing) or not moving:
		_hero.rotation_degrees.y = _yaw_toward(_hero.position, _porter.position)
	else:
		_hero.rotation.y = atan2(velocity.x, velocity.z)
	if dashing:
		_play(_hero, &"run")
	elif guarding:
		_play(_hero, &"guard")
	else:
		_play(_hero, &"walk" if moving else &"idle")


## The arena dodge: a dash along `direction`, or sideways from the porter when standing still.
func dash_hero(direction: Vector2) -> void:
	var along := Vector3(direction.x, 0.0, direction.y)
	if along.length() < 0.1:
		var to_porter := _porter.position - _hero.position
		to_porter.y = 0.0
		along = to_porter.cross(Vector3.UP)
	if along.length() < 0.001:
		return
	_dash_direction = along.normalized()
	_dash_left = HERO_DASH_SEC


## SpiritDuel.exchange_resolved: whoever an exchange hurt flinches. Replies and offensive
## spells that cost the porter pressure hit him; a blow that costs the boy composure hits
## the boy. Buffs, heals, parries and dodges play nothing. Returns the actor that reacted.
func react_to_exchange(result: Dictionary) -> Node3D:
	var target: Node3D = null
	match String(result.get("kind", "")):
		"reply":
			if float(result.get("damage", 0.0)) > 0.0:
				target = _porter
		"spell":
			if String(result.get("arena_effect", "")) in ["pressure", "stagger"]:
				target = _porter
		"incoming":
			if float(result.get("composure_lost", 0.0)) > 0.0:
				target = _hero
	if target != null:
		play_hit(target)
	return target


func play_hit(actor: Node3D) -> void:
	if not actor.has_method(&"play_animation") or not actor.call(&"play_animation", &"hit"):
		return
	get_tree().create_timer(HIT_RECOVER_SEC).timeout.connect(_recover.bind(actor))


## Yaw (degrees) that turns a rig's forward (+Z) from `from` toward `to` on the floor.
static func _yaw_toward(from: Vector3, to: Vector3) -> float:
	var direction := to - from
	return rad_to_deg(atan2(direction.x, direction.z))


## Switch `actor` to `clip` unless it already plays it or is mid-flinch (hit recovers itself).
func _play(actor: Node3D, clip: StringName) -> void:
	if not actor.has_method(&"play_animation"):
		return
	var current: StringName = actor.call(&"current_canonical_animation")
	if current != clip and current != &"hit":
		actor.call(&"play_animation", clip)


func _recover(actor: Node3D) -> void:
	# The actor may be gone (opening skipped) or already doing something else.
	if is_instance_valid(actor) and actor.call(&"current_canonical_animation") == &"hit":
		actor.call(&"play_animation", &"idle")


func _notification(what: int) -> void:
	# WHY: the rigs only detach their geometry when queued for deletion; a direct free() of
	# the opening (tests do this) lets the headless dummy renderer free imported materials
	# before their mesh RIDs and log false errors. Script PREDELETE arrives before Node
	# frees the children, so detaching here covers every rig and prop under the stage.
	if what == NOTIFICATION_PREDELETE:
		SharedCharacterRig._detach_render_geometry(self)


func _place_actor(
	scene: PackedScene, actor_name: String, at: Vector3, yaw_deg: float,
	speaker_id: StringName = &""
) -> Node3D:
	var actor := scene.instantiate() as Node3D
	actor.name = actor_name
	actor.position = at
	actor.rotation_degrees.y = yaw_deg
	# RealisticRig talks when the announced speaker equals its variant id. Re-key a borrowed
	# body on a copy (the shared crowd variant resource must stay untouched) before _ready.
	if not speaker_id.is_empty() and actor.get(&"variant") is CharacterVariant:
		var keyed := (actor.get(&"variant") as CharacterVariant).duplicate() as CharacterVariant
		keyed.stable_id = speaker_id
		actor.set(&"variant", keyed)
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
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
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
	# The doorway Kalev comes through: a dark opening in a timber frame on the back wall.
	var opening := StandardMaterial3D.new()
	opening.albedo_color = Color(0.03, 0.025, 0.02)
	# In front of the stone plinth course (its face is at -HALL_DEPTH + 0.2).
	var door_z := -HALL_DEPTH + 0.23
	var door_at := Vector3(DOOR_X, DOOR_HEIGHT * 0.5, door_z)
	_box("Doorway", Vector3(DOOR_WIDTH, DOOR_HEIGHT, 0.04), door_at, opening)
	for side: float in [-1.0, 1.0]:
		var post_at := Vector3(DOOR_X + side * (DOOR_WIDTH * 0.5 + 0.06), DOOR_HEIGHT * 0.5, door_z)
		_box("DoorPost%d" % int(side), Vector3(0.14, DOOR_HEIGHT, 0.1), post_at, beam)
	var lintel_at := Vector3(DOOR_X, DOOR_HEIGHT + 0.07, door_z)
	_box("DoorLintel", Vector3(DOOR_WIDTH + 0.4, 0.16, 0.1), lintel_at, beam)


func _set_cutaway(roof_on: bool) -> void:
	for roof_name in ["Ceiling", "Beam0", "Beam1", "Beam2", "Beam3"]:
		var roof := get_node_or_null(roof_name) as Node3D
		if roof != null:
			roof.visible = roof_on


func _build_props() -> void:
	# The kit holds cold / embers / lit variants on one origin; show only the lit one.
	var hearth := HEARTH_KIT.instantiate() as Node3D
	hearth.name = "Hearth"
	hearth.add_to_group(SpiritArena3D.GROUP_PROP)
	hearth.position = Vector3(-2.3, 0.0, -HALL_DEPTH + 0.25)
	hearth.rotation_degrees.y = 180.0
	hearth.scale = Vector3.ONE * 1.2
	add_child(hearth)
	_show_only(hearth, &"HearthLit")
	var table := TABLE_KIT.instantiate() as Node3D
	table.name = "Table"
	table.add_to_group(SpiritArena3D.GROUP_FURNITURE)
	table.position = Vector3(3.0, 0.0, -1.4)
	table.rotation_degrees.y = 90.0
	add_child(table)
	_show_only(table, &"LongBoardTable")
	var chest := CHEST.instantiate() as Node3D
	chest.name = "Chest"
	chest.add_to_group(SpiritArena3D.GROUP_FURNITURE)
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
