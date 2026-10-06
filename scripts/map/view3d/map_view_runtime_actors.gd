class_name MapViewRuntimeActors
extends RefCounted

## Mirrors 2D logic actors, health, animation, and equipment into the 3D map view.
## MapViewRuntime remains the scene-facing facade while this helper owns actor
## synchronization state and signal lifecycles.

const WALK_ANIMATION_MIN_SPEED := 5.0
## Logic px/s above which locomotion reads as running (midpoint between the
## player's walk and run speeds).
const RUN_ANIMATION_MIN_SPEED := 170.0

var _host: Node3D
var _definition: MapDefinition
var _player: CharacterBody2D
var _player_rig: SharedCharacterRig
var _view: MapView3D
var _follow_player: Callable
var _logic_direction_toward_camera: Callable
var _last_facing := Vector2.ZERO
var _last_player_health := -1.0
var _actor_rigs: Dictionary = {}
var _actors_without_rig: Dictionary = {}
var _equipment_state: GameState
var _content_db: ContentDB
var _request_screen_shake: Callable
var _sample_owning_ground := false
var _swimmer := MapViewSwimmerPresenter.new()


func configure(
	runtime_host: Node3D,
	map_definition: MapDefinition,
	logic_player: CharacterBody2D,
	runtime_player_rig: SharedCharacterRig,
	map_view: MapView3D,
	follow_player: Callable,
	logic_direction_toward_camera: Callable
) -> void:
	_host = runtime_host
	_definition = map_definition
	_player = logic_player
	_player_rig = runtime_player_rig
	_view = map_view
	_follow_player = follow_player
	_logic_direction_toward_camera = logic_direction_toward_camera


func rebind_view(map_definition: MapDefinition, map_view: MapView3D) -> void:
	_definition = map_definition
	_view = map_view
	_sample_owning_ground = true


func set_screen_shake_callback(callback: Callable) -> void:
	_request_screen_shake = callback
	_bind_player_attack_feedback()


func _bind_player_attack_feedback() -> void:
	if _player == null or not _player.has_signal("melee_attack_resolved"):
		return
	if not _player.melee_attack_resolved.is_connected(_on_player_melee_attack_resolved):
		_player.melee_attack_resolved.connect(_on_player_melee_attack_resolved)


func register_view_actors(scene_root: Node) -> void:
	for found: Node in scene_root.find_children("*", "", true, false):
		if not found.is_in_group(&"map_view_actor") or not found is Node2D:
			continue
		register_view_actor(found as Node2D)


## Mirrors a single logic actor into the 3D view. Controllers that spawn NPCs
## after MapViewRuntime.install() must call this, otherwise the body exists for
## collision and interaction but no one is visible on the map.
func register_view_actor(actor: Node2D) -> void:
	if actor == null or _actor_rigs.has(actor):
		return
	var rig_scene: PackedScene = actor.get("rig_scene") as PackedScene
	if rig_scene == null and actor.has_method("view_rig_scene"):
		rig_scene = actor.call("view_rig_scene") as PackedScene
	if rig_scene == null:
		if not _actors_without_rig.has(actor):
			_actors_without_rig[actor] = true
			push_warning("Map view actor %s has no rig_scene" % actor.name)
		return
	_actors_without_rig.erase(actor)
	var rig := rig_scene.instantiate() as SharedCharacterRig
	if rig == null:
		push_warning("Map view actor %s rig is not a SharedCharacterRig" % actor.name)
		return
	rig.name = "%sRig" % actor.name
	_host.add_child(rig)
	_actor_rigs[actor] = rig
	_hide_actor_canvas(actor)
	_sync_view_actor(actor, rig, true, 0.0)


func sync_view_actors(delta: float) -> void:
	# Encounter controllers spawn enemies after install(); rescan the scene root so
	# those damageable actors become visible in the same frame without requiring
	# every quest controller to know about 3D presentation internals.
	if _view == null or not is_instance_valid(_view):
		return
	if _host != null:
		register_view_actors(_host.get_parent())
	for actor: Node2D in _actor_rigs.keys():
		if not is_instance_valid(actor):
			var stale_rig: SharedCharacterRig = _actor_rigs[actor]
			if is_instance_valid(stale_rig):
				stale_rig.queue_free()
			_actor_rigs.erase(actor)
			_actors_without_rig.erase(actor)
			continue
		if _sample_owning_ground and not _actor_in_current_map(actor):
			continue
		_sync_view_actor(actor, _actor_rigs[actor] as SharedCharacterRig, false, delta)


func get_actor_rig(actor: Node2D) -> SharedCharacterRig:
	if actor == null:
		return null
	return _actor_rigs.get(actor) as SharedCharacterRig


func sync_player(snap: bool, delta: float = 0.0) -> void:
	if _view == null or not is_instance_valid(_view):
		return
	_view.sync_actor(_player_rig, _player.global_position)
	if _sample_owning_ground:
		_apply_owning_ground_height(_player_rig)
	var speed := _player.velocity.length()
	var moving := speed > WALK_ANIMATION_MIN_SPEED
	if moving:
		_last_facing = _player.velocity.normalized()
	elif _last_facing.is_zero_approx():
		# Spawn-facing must use the snapped camera offset, not pre-sync positions.
		_last_facing = _logic_direction_toward_camera.call() as Vector2
	# Grass MultiMeshes share one material; drive tip parting from the live
	# logic pose so walking through meadow/fern scatter reads as contact.
	if _sample_owning_ground:
		_view.update_grass_interaction(_local_logic(_player.global_position), _player.velocity)
	else:
		_view.update_grass_interaction(_player.global_position, _player.velocity)
	var facing := _player.velocity if moving else _last_facing
	if _player.has_method("view_facing"):
		facing = _player.call("view_facing") as Vector2
		if not facing.is_zero_approx():
			_last_facing = facing.normalized()
	if snap or not moving:
		_player_rig.set_facing(facing)
	else:
		_player_rig.face_toward(facing, delta)
	var wanted: StringName = &"idle"
	if _player.has_method("view_animation"):
		wanted = _player.call("view_animation") as StringName
	elif moving:
		wanted = &"run" if speed > RUN_ANIMATION_MIN_SPEED else &"walk"
	var in_water := _apply_swimmer(delta)
	if in_water and _swimmer.is_stroking():
		# The procedural stroke poses the limbs over a calm base clip.
		wanted = &"idle"
	if _player_rig.current_canonical_animation() != wanted:
		_player_rig.play_animation(wanted)
	# Camera follows the rig after the swimmer placed it, so a diver drags it down.
	_follow_player.call(snap, delta)
	if _player.has_method("view_animation_elapsed_sec"):
		var duration := 0.0
		if _player.has_method("view_animation_duration_sec"):
			duration = float(_player.call("view_animation_duration_sec"))
		_player_rig.sync_action_presentation(
			wanted, float(_player.call("view_animation_elapsed_sec")), duration
		)
	_player_rig.set_locomotion_speed(speed * MapViewBridge.world_scale(_definition.cell_size))
	if moving:
		var planted_foot := _player_rig.consume_foot_plant()
		if not planted_foot.is_empty():
			var foot := _player_rig.foot_world_position(planted_foot)
			if _sample_owning_ground:
				foot = _local_world(foot)
			_view.add_mud_footprint_at(foot, _player.velocity.normalized())
	else:
		_player_rig.consume_foot_plant()
	_sync_actor_health_ring(_player_rig, _player)


func _apply_swimmer(delta: float) -> bool:
	if _view == null or not _player.has_method("water_depth"):
		return false
	var parent_offset := Vector2.ZERO
	var parent := _view.get_parent() as Node3D
	if _sample_owning_ground and parent != null:
		parent_offset = Vector2(parent.position.x, parent.position.z)
	return _swimmer.apply(
		_player_rig, _player, _view, parent_offset, _player.velocity.length(), delta
	)


func bind_player_health_ring() -> void:
	if _player == null or not _player.has_signal("health_changed"):
		return
	if "health" in _player:
		_last_player_health = float(_player.health)
	if not _player.health_changed.is_connected(_on_player_health_changed):
		_player.health_changed.connect(_on_player_health_changed)


func bind_equipment_state(current: GameState, content_db: ContentDB) -> void:
	disconnect_equipment_state()
	_equipment_state = current
	_content_db = content_db
	if _equipment_state == null:
		return
	for slot: StringName in SharedCharacterRig.EQUIPMENT_SLOTS:
		_sync_equipment_slot(slot)
	if not _equipment_state.equipment_changed.is_connected(_sync_equipment_slot):
		_equipment_state.equipment_changed.connect(_sync_equipment_slot)


func disconnect_equipment_state() -> void:
	if _equipment_state == null:
		return
	if _equipment_state.equipment_changed.is_connected(_sync_equipment_slot):
		_equipment_state.equipment_changed.disconnect(_sync_equipment_slot)
	_equipment_state = null


static func hide_player_canvas(player: CharacterBody2D) -> void:
	# The rig replaces the greybox rectangle; the 3D overhead health bar mirrors logic health.
	for node_name in ["GreyboxVisual", "HealthRing", "StaminaBar"]:
		var node := player.get_node_or_null(node_name) as CanvasItem
		if node != null:
			node.visible = false


func _sync_view_actor(actor: Node2D, rig: SharedCharacterRig, snap: bool, delta: float) -> void:
	_view.sync_actor(rig, actor.global_position)
	if _sample_owning_ground:
		_apply_owning_ground_height(rig)
	_sync_actor_health_ring(rig, actor)
	var facing := Vector2.DOWN
	if actor.has_method("view_facing"):
		facing = actor.call("view_facing") as Vector2
	if snap:
		rig.set_facing(facing)
	else:
		rig.face_toward(facing, delta)
	var wanted := &"idle"
	if actor.has_method("view_animation"):
		wanted = actor.call("view_animation") as StringName
	# Newly added rigs enter the tree on add_child(), so their AnimationPlayer
	# is ready before we ask for a canonical state.
	if not rig.is_node_ready():
		return
	if rig.current_canonical_animation() != wanted:
		rig.play_animation(wanted)
	var actor_velocity := actor.get("velocity") as Vector2
	rig.set_locomotion_speed(
		actor_velocity.length() * MapViewBridge.world_scale(_definition.cell_size)
	)


func _actor_in_current_map(actor: Node2D) -> bool:
	if _definition == null:
		return true
	var local := _local_logic(actor.global_position)
	var size := _definition.world_size()
	return local.x >= 0.0 and local.y >= 0.0 and local.x < size.x and local.y < size.y


func _local_logic(global_position: Vector2) -> Vector2:
	if _definition == null or _view == null:
		return global_position
	var parent := _view.get_parent() as Node3D
	if parent == null:
		return global_position
	return global_position - Vector2(parent.position.x, parent.position.z) * float(
		_definition.cell_size
	)


func _local_world(world_position: Vector3) -> Vector3:
	if _view == null:
		return world_position
	var parent := _view.get_parent() as Node3D
	if parent == null:
		return world_position
	return world_position - parent.position


func _apply_owning_ground_height(rig: Node3D) -> void:
	if _view == null or _definition == null or rig == null:
		return
	var local_xz := Vector2(rig.position.x, rig.position.z)
	var parent := _view.get_parent() as Node3D
	if parent != null:
		local_xz -= Vector2(parent.position.x, parent.position.z)
	var local_logic := _local_logic(
		Vector2(rig.position.x, rig.position.z) * float(_definition.cell_size)
	)
	var surface_elevation := maxf(
		MapWallWalkAccess.elevation_at(_definition, local_logic),
		MapClimbableProps.elevation_at(_definition, local_logic)
	)
	rig.position.y = MapViewMeshBuilder.ground_height(_definition, local_xz) + surface_elevation


static func _hide_actor_canvas(actor: Node2D) -> void:
	for child: Node in actor.get_children():
		if child is CanvasItem and not child is CollisionShape2D and not child is NavigationAgent2D:
			(child as CanvasItem).visible = false


func _on_player_health_changed(current: float, maximum: float) -> void:
	if (
		_last_player_health >= 0.0
		and current < _last_player_health
		and _request_screen_shake.is_valid()
	):
		_request_screen_shake.call(0.35)
	_last_player_health = current
	var ring := _player_rig.get_node_or_null("HealthRing") as CharacterHealthRing3D
	if ring != null:
		ring.set_health(current, maximum)


func _on_player_melee_attack_resolved(targets: Array[Node2D], profile: AttackProfile) -> void:
	if targets.is_empty() or profile == null or not _request_screen_shake.is_valid():
		return
	if profile.animation not in [&"hammer_attack", &"hammer_charged_attack"]:
		return
	var amount := 0.18
	if profile.animation == &"hammer_charged_attack":
		amount = 0.28
	_request_screen_shake.call(amount)


static func _sync_actor_health_ring(rig: SharedCharacterRig, actor: Node) -> void:
	var ring := rig.get_node_or_null("HealthRing") as CharacterHealthRing3D
	if ring == null:
		return
	if not ("health" in actor) or not ("max_health" in actor):
		return
	ring.set_health(float(actor.health), float(actor.max_health))


func _sync_equipment_slot(slot: StringName) -> void:
	if _equipment_state == null or _player_rig == null:
		return
	var item_id := _equipment_state.equipped_item(slot)
	if item_id.is_empty():
		_player_rig.unequip(slot)
		return
	var record: Dictionary = _content_db.get_item(item_id) if _content_db != null else {}
	var gameplay: Dictionary = record.get("gameplay", {})
	var equip_info: Dictionary = gameplay.get("equip", {})
	var scene_path := String(equip_info.get("scene", ""))
	if scene_path.is_empty():
		_player_rig.unequip(slot)
		return
	_player_rig.equip(slot, load(scene_path) as PackedScene)
