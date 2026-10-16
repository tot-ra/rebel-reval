class_name MapViewRuntimeActors
extends RefCounted

## Mirrors 2D logic actors, health, animation, and equipment into the 3D map view.
## MapViewRuntime remains the scene-facing facade while this helper owns actor
## synchronization state and signal lifecycles.

const MotionStylePresenter := preload("res://scripts/motion/motion_style_presenter.gd")
const WALK_ANIMATION_MIN_SPEED := 5.0
## Logic px/s above which locomotion reads as running (midpoint between the
## player's walk and run speeds).
const RUN_ANIMATION_MIN_SPEED := 140.0
## World units (metres) from the player within which NPC foot plants are
## sampled and heard (R-1641). Past it a step is inaudible under the city bed,
## and skipping the skeleton update there keeps a crowd cheap.
const NPC_FOOTSTEP_RADIUS := 16.0
## Rigs far from the player are posed every 4th / 8th frame (staggered per actor) with the
## elapsed time folded into delta: a city holds hundreds of people and posing all of them
## every frame cost ~10 ms of CPU. Near actors (about 70 m) stay at full rate.
const PerfProbeScript := preload("res://scripts/debug/perf_probe.gd")
const MAX_NEW_RIGS_PER_SWEEP := 2
const NEAR_SYNC_DISTANCE_SQ := 4900.0
const MID_SYNC_DISTANCE_SQ := 19600.0

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
## actor -> [last logic position, rig position computed for it]
## (idle actors skip the terrain lookup).
var _ground_cache: Dictionary = {}
var _actors_without_rig: Dictionary = {}
var _equipment_state: GameState
var _content_db: ContentDB
var _request_screen_shake: Callable
## Set by MapViewRuntime to MapViewRuntimeAmbient.play_footstep (ADR 0035).
var _footstep_callback: Callable
## Set to MapViewRuntimeAmbient.play_npc_footstep (R-1641).
var _npc_footstep_callback: Callable
## Set to MapViewRuntimeAmbient.play_swim_stroke (R-1648).
var _swim_stroke_callback: Callable
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
	# The player uses screen-space vitals. Remove only its presentation ring so
	# swimming cannot show it again; enemy and NPC rings remain untouched.
	var player_ring := _player_rig.get_node_or_null("HealthRing")
	if player_ring != null:
		_player_rig.remove_child(player_ring)
		player_ring.queue_free()
	_view = map_view
	_follow_player = follow_player
	_logic_direction_toward_camera = logic_direction_toward_camera


func rebind_view(map_definition: MapDefinition, map_view: MapView3D) -> void:
	_definition = map_definition
	_view = map_view
	_sample_owning_ground = true


func set_footstep_callback(
	callback: Callable, npc_callback: Callable = Callable(), swim_callback: Callable = Callable()
) -> void:
	_footstep_callback = callback
	_npc_footstep_callback = npc_callback
	_swim_stroke_callback = swim_callback


func set_screen_shake_callback(callback: Callable) -> void:
	_request_screen_shake = callback
	_bind_player_attack_feedback()


func _bind_player_attack_feedback() -> void:
	if _player == null or not _player.has_signal("melee_attack_resolved"):
		return
	if not _player.melee_attack_resolved.is_connected(_on_player_melee_attack_resolved):
		_player.melee_attack_resolved.connect(_on_player_melee_attack_resolved)


## Runs every frame (sync_view_actors), so it walks the actor group, not the scene: the
## seamless city has about 30 000 nodes and a find_children("*") sweep cost ~9 ms a frame.
func register_view_actors(scene_root: Node) -> void:
	var tree := scene_root.get_tree()
	if tree == null:
		return
	var pending: Array[Node2D] = []
	for found: Node in tree.get_nodes_in_group(&"map_view_actor"):
		if not found is Node2D or _actor_rigs.has(found) or not scene_root.is_ancestor_of(found):
			continue
		pending.append(found as Node2D)
	if pending.is_empty():
		return
	# Building a rig (scene instance, skeleton, animations) is the one expensive step (~7 ms);
	# a crowd streaming in used to build hundreds in one frame (a 170 ms hitch). After the first
	# frames only the nearest few are built per frame.
	if pending.size() > MAX_NEW_RIGS_PER_SWEEP and Engine.get_process_frames() > 2:
		var from := _player.global_position if _player != null else Vector2.ZERO
		pending.sort_custom(
			func(a: Node2D, b: Node2D) -> bool:
				return a.global_position.distance_squared_to(from) < b.global_position.distance_squared_to(from)
		)
		pending.resize(MAX_NEW_RIGS_PER_SWEEP)
	for actor: Node2D in pending:
		register_view_actor(actor)


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
	var t := PerfProbeScript.start()
	if _host != null:
		register_view_actors(_host.get_parent())
	PerfProbeScript.stop(&"view_runtime/actors/register", t)
	var frame := Engine.get_process_frames()
	var posed := 0
	var skipped := 0
	var player_pos := _player_rig.global_position if _player_rig != null else Vector3.ZERO
	# Untyped key: a typed loop variable errors on actors freed since the last
	# frame (e.g. people streamed out of a city site).
	for key: Variant in _actor_rigs.keys():
		if not is_instance_valid(key):
			var stale_rig: Variant = _actor_rigs[key]
			if is_instance_valid(stale_rig):
				(stale_rig as Node).queue_free()
			_actor_rigs.erase(key)
			_ground_cache.erase(key)
			_actors_without_rig.erase(key)
			continue
		var actor := key as Node2D
		if _sample_owning_ground and not _actor_in_current_map(actor):
			continue
		var rig := _actor_rigs[actor] as SharedCharacterRig
		var stride := _sync_stride(rig, player_pos)
		if stride > 1 and (frame + actor.get_instance_id()) % stride != 0:
			skipped += 1
			continue
		posed += 1
		_sync_view_actor(actor, rig, false, delta * stride)
	PerfProbeScript.note(
		&"actors", "%d rigs, %d posed, %d skipped this frame" % [_actor_rigs.size(), posed, skipped]
	)


func _sync_stride(rig: SharedCharacterRig, player_pos: Vector3) -> int:
	if rig == null or _player_rig == null:
		return 1
	var d2 := rig.global_position.distance_squared_to(player_pos)
	if d2 < NEAR_SYNC_DISTANCE_SQ:
		return 1
	return 4 if d2 < MID_SYNC_DISTANCE_SQ else 8


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
	# A hop lifts the rig off the ground; logic stays flat (PlayerJumpState).
	if _player.has_method("jump_height"):
		_player_rig.position.y += float(_player.call("jump_height"))
	# Sitting lowers the rig so the sit clips rest on the seat (SITTING.md).
	if _player.has_method("seat_height_offset"):
		_player_rig.position.y += float(_player.call("seat_height_offset"))
	# Velocity carries the time-flow multiplier; gait choice must not.
	var raw_flow: Variant = _player.get(&"time_flow_scale")
	var flow_scale := float(raw_flow) if raw_flow != null else 1.0
	var speed := _player.velocity.length() / maxf(flow_scale, 0.01)
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
	var stroke := _swimmer.consume_stroke()
	if in_water and not String(stroke).is_empty() and _swim_stroke_callback.is_valid():
		_swim_stroke_callback.call(_player_rig.global_position, stroke)
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
	if not in_water:
		MotionStylePresenter.humanoid(
			_player_rig, delta, speed * MapViewBridge.world_scale(_definition.cell_size),
			MotionStylePresenter.vitals_conditions(_player)
		)
	# The jump reads the hero's situation and poses the rig (ADR 0053).
	if _player.has_method("leap_pose"):
		MotionStylePresenter.leap(_player_rig, _player.call("leap_pose") as Dictionary)
		_player.set(&"leap_channels", MotionStylePresenter.channels_of(_player_rig))
	if moving:
		var planted_foot := _player_rig.consume_foot_plant()
		if not planted_foot.is_empty():
			var global_foot := _player_rig.foot_world_position(planted_foot)
			var foot := _local_world(global_foot) if _sample_owning_ground else global_foot
			_view.add_mud_footprint_at(foot, _player.velocity.normalized())
			# Same contact event and the same sampling point as the mud print,
			# so the sound matches the ground the sole actually hits.
			if _footstep_callback.is_valid():
				_footstep_callback.call(foot, speed, global_foot)
			# Puddle VFX is independent of audio settings and only runs on the city adapter.
			if _view.has_method("emit_puddle_step"):
				var surface := StringName(_view.call("footstep_surface_at", foot))
				_view.call("emit_puddle_step", foot, surface, _player.velocity.normalized())
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
	if (
		_player != null and _player.has_signal(&"weapon_drawn_changed")
		and not _player.is_connected(&"weapon_drawn_changed", _apply_weapon_stance)
	):
		_player.connect(&"weapon_drawn_changed", _apply_weapon_stance)


func disconnect_equipment_state() -> void:
	if _equipment_state == null:
		return
	if _equipment_state.equipment_changed.is_connected(_sync_equipment_slot):
		_equipment_state.equipment_changed.disconnect(_sync_equipment_slot)
	_equipment_state = null


static func hide_player_canvas(player: CharacterBody2D) -> void:
	# The rig replaces the greybox rectangle; screen-space PlayerVitalsHud presents health and stamina.
	for node_name in ["GreyboxVisual", "HealthRing", "StaminaBar"]:
		var node := player.get_node_or_null(node_name) as CanvasItem
		if node != null:
			node.visible = false


func _sync_view_actor(actor: Node2D, rig: SharedCharacterRig, snap: bool, delta: float) -> void:
	var t := PerfProbeScript.start()
	# Terrain height and wall-walk / prop elevation cost ~50 us per actor; a person standing
	# still keeps its pose, so it is only recomputed when the actor has moved.
	var logic := actor.global_position
	var cached: Array = _ground_cache.get(actor, [])
	if not snap and cached.size() == 2 and logic.is_equal_approx(cached[0]):
		rig.position = cached[1]
	else:
		_view.sync_actor(rig, logic)
		if _sample_owning_ground:
			_apply_owning_ground_height(rig)
		_ground_cache[actor] = [logic, rig.position]
	# Actors whose pose sits on furniture (CitySiteActor) lift or lower the rig.
	if actor.has_method(&"view_height_offset"):
		rig.position.y += float(actor.call(&"view_height_offset"))
	PerfProbeScript.stop(&"view_runtime/actors/ground", t)
	t = PerfProbeScript.start()
	_sync_actor_health_ring(rig, actor)
	PerfProbeScript.stop(&"view_runtime/actors/health_ring", t)
	t = PerfProbeScript.start()
	var facing := Vector2.DOWN
	if actor.has_method("view_facing"):
		facing = actor.call("view_facing") as Vector2
	if snap:
		rig.set_facing(facing)
	else:
		rig.face_toward(facing, delta)
	PerfProbeScript.stop(&"view_runtime/actors/facing", t)
	t = PerfProbeScript.start()
	var wanted := &"idle"
	if actor.has_method("view_animation"):
		wanted = actor.call("view_animation") as StringName
	# Newly added rigs enter the tree on add_child(), so their AnimationPlayer
	# is ready before we ask for a canonical state.
	if not rig.is_node_ready():
		PerfProbeScript.stop(&"view_runtime/actors/animation", t)
		return
	if rig.current_canonical_animation() != wanted:
		rig.play_animation(wanted)
	var actor_velocity := actor.get("velocity") as Vector2
	var world_speed := actor_velocity.length() * MapViewBridge.world_scale(_definition.cell_size)
	rig.set_locomotion_speed(world_speed)
	PerfProbeScript.stop(&"view_runtime/actors/animation", t)
	t = PerfProbeScript.start()
	MotionStylePresenter.humanoid(
		rig, delta, world_speed, MotionStylePresenter.vitals_conditions(actor)
	)
	PerfProbeScript.stop(&"view_runtime/actors/motion_style", t)
	t = PerfProbeScript.start()
	_emit_npc_footstep(rig, actor_velocity.length())
	PerfProbeScript.stop(&"view_runtime/actors/footstep", t)


## NPC steps ride the same rig contact event as the player's (R-1641), so a
## walker's sound matches its stride on every map. Only rigs within
## NPC_FOOTSTEP_RADIUS of the player are sampled.
func _emit_npc_footstep(rig: SharedCharacterRig, speed: float) -> void:
	if not _npc_footstep_callback.is_valid() or _player_rig == null:
		return
	if speed <= WALK_ANIMATION_MIN_SPEED or not rig.visible:
		return
	if rig.global_position.distance_to(_player_rig.global_position) > NPC_FOOTSTEP_RADIUS:
		return
	var planted_foot := rig.consume_foot_plant()
	if planted_foot.is_empty():
		return
	var global_foot := rig.foot_world_position(planted_foot)
	var foot := _local_world(global_foot) if _sample_owning_ground else global_foot
	_npc_footstep_callback.call(foot, speed, global_foot)


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
	return (
		global_position
		- Vector2(parent.position.x, parent.position.z) * float(_definition.cell_size)
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
	_strike_vegetation(profile)
	if targets.is_empty() or profile == null or not _request_screen_shake.is_valid():
		return
	if profile.animation not in [&"hammer_attack", &"hammer_charged_attack"]:
		return
	var amount := 0.18
	if profile.animation == &"hammer_charged_attack":
		amount = 0.28
	_request_screen_shake.call(amount)


## R-1187: every landed swing (hit or whiff) may shake a tree in reach and
## knock leaves loose. Heavy blows shake harder and drop more.
func _strike_vegetation(profile: AttackProfile) -> void:
	if profile == null or _player == null or _view == null or not is_instance_valid(_view):
		return
	if not _player.has_method("facing_direction"):
		return
	var strength := 1.6 if profile.is_heavy else 1.0
	_view.strike_vegetation(
		_player.global_position,
		_player.call("facing_direction"),
		profile.reach_px,
		profile.facing_dot,
		strength
	)


static func _sync_actor_health_ring(rig: SharedCharacterRig, actor: Node) -> void:
	var ring := rig.get_node_or_null("HealthRing") as CharacterHealthRing3D
	if ring == null:
		return
	if not ("health" in actor) or not ("max_health" in actor):
		return
	ring.set_health(float(actor.health), float(actor.max_health))
	if "stamina" in actor and "max_stamina" in actor:
		ring.set_stamina(float(actor.stamina), float(actor.max_stamina))


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
	_apply_weapon_stance()


## R-1886: a sheathed hero carries nothing in his hands; drawing shows what is equipped.
func _apply_weapon_stance(_drawn: bool = false) -> void:
	if _player_rig == null:
		return
	var drawn := (
		_player == null or not (&"weapon_drawn" in _player)
		or bool(_player.get(&"weapon_drawn"))
	)
	for slot: StringName in [&"right_hand", &"left_hand"]:
		var held := _player_rig.equipped(slot)
		if held != null:
			held.visible = drawn
