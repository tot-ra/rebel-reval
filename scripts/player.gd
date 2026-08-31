class_name Player
extends CharacterBody2D

signal melee_attack_resolved(targets: Array[Node2D], profile: AttackProfile)
signal health_changed(current: float, maximum: float)
signal died

const MeleeAttackResolverScript := preload("res://scripts/combat/melee_attack_resolver.gd")
const AttackProfileScript := preload("res://scripts/combat/attack_profile.gd")
const AttackProfileResolverScript := preload("res://scripts/combat/attack_profile_resolver.gd")
const NpcPushScript := preload("res://scripts/physics/npc_push.gd")
const DEATH_SCREEN_PATH := "res://scenes/death/death_screen.tscn"
const STAMINA_DRAIN_RATE := 10.0  # per second
const DODGE_STAMINA_COST := 18.0
const DODGE_DISTANCE_PX := 80.0
const DODGE_DEFAULT_SIDE := Vector2.RIGHT

# Logic px/s (32 px = 1 world unit): a readable walk and a believable sprint.
# MapViewRuntime.RUN_ANIMATION_MIN_SPEED sits midway between these.
@export var walk_speed = 100
@export var run_speed = 240
@export var combat_input_enabled := true

var health: float = 100.0
var max_health: float = 100.0
var stamina: float = 100.0
var max_stamina: float = 100.0
var action_state_machine := PlayerActionStateMachine.new()
var combat_vitals := CombatVitals.new()

var _screen_right_in_logic := Vector2.RIGHT
var _screen_down_in_logic := Vector2.DOWN
var _facing_direction := Vector2.DOWN
var _camera_facing_direction := Vector2.ZERO
var _active_attack_profile: AttackProfile = AttackProfile.unarmed()
var _attack_charge_sec: float = 0.0
var _attack_charge_active: bool = false
var _last_hit_result: CombatHitResult
var _pending_dodge_direction := Vector2.ZERO
var _pending_dodge_facing := Vector2.ZERO
var _dodge_direction := Vector2.ZERO
var _dodge_facing := Vector2.ZERO
var _dodge_animation: StringName = &"dodge_right"
var _dodge_distance_remaining := 0.0
var _death_transition_started := false
var _map_definition: MapDefinition
var _map_grid: MapTerrainGrid
var _mud_wetness_provider: Callable

@onready var animation_player: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
# Optional so headless unit tests can construct Player.new() without the full scene.
@onready var navigation_agent: NavigationAgent2D = get_node_or_null("NavigationAgent2D")
@onready var health_ring: CharacterHealthRing = get_node_or_null("HealthRing")
@onready var stamina_bar: ProgressBar = get_node_or_null("StaminaBar")

func _ready() -> void:
	CollisionLayers.apply_player(self)
	add_to_group(MeleeAttackResolver.DAMAGEABLE_GROUP)
	_configure_combat_vitals()
	_sync_resource_bars()
	if not action_state_machine.attack_impact.is_connected(_on_attack_impact):
		action_state_machine.attack_impact.connect(_on_attack_impact)
	if not action_state_machine.action_started.is_connected(_on_action_started):
		action_state_machine.action_started.connect(_on_action_started)
	if not action_state_machine.state_changed.is_connected(_on_action_state_changed):
		action_state_machine.state_changed.connect(_on_action_state_changed)
	action_state_machine.action_start_validator = _can_start_action
	DoorNavigator.on_trigger_player_spawn.connect(_on_spawn)
	if navigation_agent != null:
		navigation_agent.velocity_computed.connect(Callable(self, "_on_velocity_computed"))


func _on_spawn(position: Vector2, direction: String):
	global_position = position
	if animation_player != null:
		animation_player.play("walk_" + direction)
		animation_player.stop()

func configure_map_movement(definition: MapDefinition, grid: MapTerrainGrid) -> void:
	_map_definition = definition
	_map_grid = grid


func set_mud_wetness_provider(provider: Callable) -> void:
	_mud_wetness_provider = provider


func _physics_process(_delta):
	# Capture the portion of this physics interval that still belongs to DODGE
	# before tick() can transition into recovery. This keeps travel independent
	# of frame rate without extending the 0.28 s action/i-frame window.
	var dodge_motion_sec := 0.0
	var was_dodging := action_state_machine.state == PlayerActionState.State.DODGE
	if was_dodging:
		dodge_motion_sec = minf(
			_delta,
			maxf(
				0.0,
				action_state_machine.dodge_duration_sec - action_state_machine.state_elapsed_sec
			)
		)
	action_state_machine.tick(_delta)
	combat_vitals.tick(_delta)
	_process_action_input(_delta)
	if not was_dodging and action_state_machine.state == PlayerActionState.State.DODGE:
		dodge_motion_sec = minf(_delta, action_state_machine.dodge_duration_sec)

	if _movement_blocked():
		velocity = Vector2.ZERO
		_sync_resource_bars()
		move_and_slide()
		update_animation(_combat_or_locomotion_animation("idle"))
		return

	if dodge_motion_sec > 0.0:
		_move_dodge(dodge_motion_sec)
		_sync_resource_bars()
		update_animation(_combat_or_locomotion_animation(action_state_machine.get_animation_base()))
		return

	if not action_state_machine.allows_movement():
		velocity = Vector2.ZERO
		move_and_slide()
		_sync_resource_bars()
		update_animation(_combat_or_locomotion_animation(action_state_machine.get_animation_base()))
		return

	var screen_direction := ScreenDirectionInput.read_axis()
	var movement_direction := movement_direction_for_screen_input(screen_direction)
	var new_animation = "idle"

	if not movement_direction.is_zero_approx():
		if _camera_facing_direction.is_zero_approx():
			_facing_direction = movement_direction.normalized()
		var encumbrance := _get_encumbrance_speed_multiplier()
		var terrain_speed := _get_terrain_speed_multiplier()
		var current_speed = run_speed * encumbrance * terrain_speed

		if Input.is_action_pressed("ui_shift"):
			new_animation = "walk"
			current_speed = walk_speed * encumbrance * terrain_speed
		else:
			new_animation = "run"

		if navigation_agent != null:
			navigation_agent.set_target_position(global_position)
		velocity = movement_direction * current_speed

	else:
		if navigation_agent != null and not navigation_agent.is_navigation_finished():
			var current_agent_position: Vector2 = global_position
			var next_path_position: Vector2 = navigation_agent.get_next_path_position()

			velocity = (
				run_speed
				* _get_encumbrance_speed_multiplier()
				* _get_terrain_speed_multiplier()
				* (next_path_position - current_agent_position).normalized()
			)
			if not velocity.is_zero_approx() and _camera_facing_direction.is_zero_approx():
				_facing_direction = velocity.normalized()

			navigation_agent.set_velocity(velocity)
			new_animation = "run"
		else:
			velocity = Vector2.ZERO

	_update_movement_resources(_delta, new_animation != "idle")
	_sync_resource_bars()
	var movement_velocity := velocity
	move_and_slide()
	_apply_npc_pushes(movement_velocity, _delta)
	update_animation(_combat_or_locomotion_animation(new_animation))


func _process_action_input(_delta: float) -> void:
	if not combat_input_enabled or _movement_blocked():
		return
	# Keyboard and gamepad attacks must commit on press. The mouse primary-action
	# controller owns its separate hold-to-charge path, so Space never leaves the
	# player walking while waiting for a release event.
	_process_instant_attack_input()
	for kind in PlayerActionInput.read_pressed_actions():
		if kind == PlayerActionKind.Kind.ATTACK:
			continue
		if kind == PlayerActionKind.Kind.DODGE:
			try_start_dodge()
			continue
		action_state_machine.try_start_action(kind)
	action_state_machine.set_guard_held(PlayerActionInput.read_guard_held())


func try_start_dodge(direction: Vector2 = Vector2.ZERO) -> bool:
	_pending_dodge_facing = _current_dodge_facing()
	_pending_dodge_direction = (
		direction.normalized() if not direction.is_zero_approx() else _requested_dodge_direction()
	)
	var was_free_to_start := action_state_machine.state == PlayerActionState.State.MOVE
	var started := action_state_machine.try_start_action(PlayerActionKind.Kind.DODGE)
	if was_free_to_start and not started:
		_pending_dodge_direction = Vector2.ZERO
		_pending_dodge_facing = Vector2.ZERO
	return started


func _requested_dodge_direction() -> Vector2:
	var movement_direction := movement_direction_for_screen_input(ScreenDirectionInput.read_axis())
	if not movement_direction.is_zero_approx():
		return movement_direction
	var facing := _current_dodge_facing()
	# No-input dodge is deliberately the character's right side. It is stable in
	# every camera mode and communicates why the Dodge_Right clip was selected.
	return Vector2(facing.y, -facing.x) * DODGE_DEFAULT_SIDE.x


func _current_dodge_facing() -> Vector2:
	if not _camera_facing_direction.is_zero_approx():
		return _camera_facing_direction.normalized()
	if not _facing_direction.is_zero_approx():
		return _facing_direction.normalized()
	return Vector2.DOWN


func _can_start_action(kind: PlayerActionKind.Kind) -> bool:
	return kind != PlayerActionKind.Kind.DODGE or stamina >= DODGE_STAMINA_COST


func _on_action_started(kind: PlayerActionKind.Kind) -> void:
	if kind != PlayerActionKind.Kind.DODGE:
		return
	_dodge_facing = (
		_pending_dodge_facing.normalized()
		if not _pending_dodge_facing.is_zero_approx()
		else _current_dodge_facing()
	)
	_dodge_direction = _pending_dodge_direction
	if _dodge_direction.is_zero_approx():
		_dodge_direction = Vector2(_dodge_facing.y, -_dodge_facing.x)
	_dodge_direction = _dodge_direction.normalized()
	_dodge_animation = dodge_animation_for_direction(_dodge_direction, _dodge_facing)
	_facing_direction = _dodge_facing
	_pending_dodge_direction = Vector2.ZERO
	_pending_dodge_facing = Vector2.ZERO
	_dodge_distance_remaining = DODGE_DISTANCE_PX
	stamina = maxf(0.0, stamina - DODGE_STAMINA_COST)
	_sync_resource_bars()


static func dodge_animation_for_direction(direction: Vector2, facing: Vector2) -> StringName:
	var normalized_facing := facing.normalized() if not facing.is_zero_approx() else Vector2.DOWN
	var normalized_direction := (
		direction.normalized()
		if not direction.is_zero_approx()
		else Vector2(normalized_facing.y, -normalized_facing.x)
	)
	var right := Vector2(normalized_facing.y, -normalized_facing.x)
	var forward_amount := normalized_direction.dot(normalized_facing)
	var right_amount := normalized_direction.dot(right)
	if absf(right_amount) > absf(forward_amount):
		return &"dodge_right" if right_amount >= 0.0 else &"dodge_left"
	return &"dodge_forward" if forward_amount >= 0.0 else &"dodge_backward"


func _move_dodge(delta: float) -> void:
	var intended_distance := minf(
		_dodge_distance_remaining,
		DODGE_DISTANCE_PX * delta / action_state_machine.dodge_duration_sec
	)
	if intended_distance <= 0.0:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	# move_and_slide owns collision resolution and uses the engine physics step.
	# Scale velocity so direct focused-test calls with an explicit delta cover the
	# same bounded distance as real physics callbacks.
	var physics_delta := maxf(get_physics_process_delta_time(), 0.0001)
	velocity = _dodge_direction * intended_distance / physics_delta
	var before := global_position
	move_and_slide()
	var traveled := (global_position - before).dot(_dodge_direction)
	_dodge_distance_remaining = maxf(0.0, _dodge_distance_remaining - maxf(0.0, traveled))


## Public entry for the context-sensitive primary click (left mouse button in
## first/third person). Mirrors the instant-attack path so mouse, keyboard, and
## gamepad attacks share the same state, stamina, and profile rules.
func request_primary_attack() -> bool:
	if not combat_input_enabled or _movement_blocked():
		return false
	var profile := _resolve_attack_profile(false)
	if stamina < profile.stamina_cost:
		return false
	_prepare_attack_for_profile(profile)
	if not action_state_machine.try_start_action(PlayerActionKind.Kind.ATTACK):
		return false
	stamina = maxf(0.0, stamina - profile.stamina_cost)
	_sync_resource_bars()
	return true


## Exposed so the click router can hold the primary button to charge instead of
## swinging on press when the equipped technique supports charging.
func supports_charged_attack() -> bool:
	return _supports_charged_attack()


func _process_instant_attack_input() -> void:
	for kind in PlayerActionInput.read_pressed_actions():
		if kind != PlayerActionKind.Kind.ATTACK:
			continue
		request_primary_attack()


func _process_charged_attack_input(delta: float) -> void:
	if action_state_machine.state != PlayerActionState.State.MOVE:
		_reset_attack_charge()
		return
	var attack_held := PlayerActionInput.read_attack_held()
	if PlayerActionInput.read_attack_just_pressed() or (attack_held and not _attack_charge_active):
		_attack_charge_active = true
		_attack_charge_sec = 0.0
	if _attack_charge_active and attack_held:
		_attack_charge_sec += delta
	if PlayerActionInput.read_attack_just_released() and _attack_charge_active:
		_commit_attack_from_charge_hold(_attack_charge_sec)


func commit_attack_from_charge_hold(hold_sec: float) -> bool:
	return _commit_attack_from_charge_hold(hold_sec)


func _commit_attack_from_charge_hold(hold_sec: float) -> bool:
	if action_state_machine.state != PlayerActionState.State.MOVE:
		_reset_attack_charge()
		return false
	var charged := hold_sec >= _charge_threshold_sec()
	_reset_attack_charge()
	var profile := _resolve_attack_profile(charged)
	if stamina < profile.stamina_cost:
		return false
	_prepare_attack_for_profile(profile)
	if not action_state_machine.try_start_action(PlayerActionKind.Kind.ATTACK):
		return false
	stamina = maxf(0.0, stamina - profile.stamina_cost)
	_sync_resource_bars()
	return true


func _reset_attack_charge() -> void:
	_attack_charge_active = false
	_attack_charge_sec = 0.0


func _supports_charged_attack() -> bool:
	return AttackProfileResolverScript.state_supports_charged_attack(
		SessionState.state, SessionState.content_db
	)


func _charge_threshold_sec() -> float:
	return AttackProfileResolverScript.charge_threshold_sec_for_state(
		SessionState.state, SessionState.content_db
	)


func apply_hit_stun() -> void:
	PlayerActionInput.reset_guard_toggle()
	action_state_machine.apply_hit()


func take_damage(
	amount: float,
	_source: Node = null,
	_damage_type: StringName = &"",
	swing_id: int = 0,
	pierces_guard: bool = false
) -> float:
	_sync_vitals_from_fields()
	var pose := CombatDefensePose.from_action_machine(
		action_state_machine, combat_vitals.parry_window_sec
	)
	# Dodge invulnerability remains owned by the action machine; vitals also
	# tracks post-hit i-frames so both player and combat actors share one rule.
	if action_state_machine.is_invulnerable():
		pose.is_action_invulnerable = true
	var result := combat_vitals.resolve_hit(amount, pose, swing_id, pierces_guard)
	_last_hit_result = result
	if result.died and has_node("/root/SessionState"):
		# Capture before the deferred scene change; the value is intentionally not
		# part of GameState so it cannot leak into saves or long-lived session data.
		SessionState.set_fatal_hit_damage_type(_damage_type)
	_sync_fields_from_vitals()
	_sync_resource_bars()
	if result.health_damage > 0.0:
		health_changed.emit(health, max_health)
		apply_hit_stun()
	elif result.outcome == CombatHitResult.OUTCOME_HIT:
		# Zero-amount open hits should not happen, but keep stun aligned with HIT.
		apply_hit_stun()
	return result.health_damage


func last_hit_result() -> CombatHitResult:
	return _last_hit_result


func is_combat_dead() -> bool:
	return combat_vitals.is_dead()


func view_facing() -> Vector2:
	if (
		action_state_machine.state == PlayerActionState.State.DODGE
		and not _dodge_facing.is_zero_approx()
	):
		return _dodge_facing
	return _facing_direction


func set_view_facing(direction: Vector2) -> void:
	if direction.is_zero_approx():
		return
	_facing_direction = direction.normalized()


func set_camera_facing(direction: Vector2) -> void:
	_camera_facing_direction = (
		direction.normalized() if not direction.is_zero_approx() else Vector2.ZERO
	)
	if not _camera_facing_direction.is_zero_approx():
		_facing_direction = _camera_facing_direction


func view_animation() -> StringName:
	# WHY: Charged attacks intentionally commit on release, but the player must
	# still see the hammer wind-up while Space/gamepad X is held.
	if _attack_charge_active:
		return _resolve_attack_profile(true).animation
	var animation_base := _combat_or_locomotion_animation(_current_locomotion_animation())
	if animation_base == "attack":
		return _active_attack_profile.animation
	if animation_base == "dodge":
		return _dodge_animation
	if animation_base == "recovery":
		# Recovery is a logic-only lock window; the shared humanoid has no
		# dedicated recovery clip, so keep the map presentation at idle.
		return &"idle"
	return StringName(animation_base)


func view_animation_elapsed_sec() -> float:
	if _attack_charge_active:
		return _attack_charge_sec
	if action_state_machine.state == PlayerActionState.State.ATTACK:
		return action_state_machine.state_elapsed_sec
	return 0.0


func _current_locomotion_animation() -> String:
	if _movement_blocked():
		return "idle"
	if not action_state_machine.allows_movement():
		return action_state_machine.get_animation_base()
	if not velocity.is_zero_approx():
		if Input.is_action_pressed("ui_shift"):
			return "walk"
		return "run"
	return "idle"


func _on_attack_impact() -> void:
	var profile := _active_attack_profile
	var targets: Array[Node2D] = MeleeAttackResolverScript.strike_with_profile(
		self, _facing_direction, profile
	)
	melee_attack_resolved.emit(targets, profile)


func _on_action_state_changed(
	_previous: PlayerActionState.State, current: PlayerActionState.State
) -> void:
	if current != PlayerActionState.State.ATTACK:
		_active_attack_profile = _resolve_attack_profile()


func _resolve_attack_profile(use_charged: bool = false) -> AttackProfile:
	return AttackProfileResolverScript.resolve_for_state(
		SessionState.state, SessionState.content_db, use_charged
	)


func prepare_attack_profile(profile: AttackProfile) -> void:
	_prepare_attack_for_profile(profile)


func _prepare_attack_for_profile(profile: AttackProfile) -> void:
	_active_attack_profile = profile
	action_state_machine.attack_duration_sec = profile.attack_duration_sec
	action_state_machine.attack_impact_sec = profile.impact_timing_sec


func is_combat_invulnerable() -> bool:
	return action_state_machine.is_invulnerable() or combat_vitals.is_hit_invulnerable()


func _configure_combat_vitals() -> void:
	combat_vitals.configure(health, max_health, stamina, max_stamina)
	if not combat_vitals.died.is_connected(_on_combat_vitals_died):
		combat_vitals.died.connect(_on_combat_vitals_died)


func _on_combat_vitals_died() -> void:
	died.emit()
	# Test, debug, and prototype hosts intentionally keep their local death/retry
	# behavior. Release gameplay scenes are the only scenes that enter the death
	# epilogue and end the current run.
	if _death_transition_started or not _should_show_death_screen():
		return
	_death_transition_started = true
	call_deferred("_open_death_screen")


func _should_show_death_screen() -> bool:
	var tree := get_tree()
	if tree == null or not is_inside_tree():
		return false
	var scene := tree.current_scene
	if scene == null:
		return false
	var scene_path := scene.scene_file_path
	return not (
		scene_path.begins_with("res://scenes/tests/")
		or scene_path.begins_with("res://scenes/debug/")
		or scene_path.begins_with("res://scenes/map_prototype/")
	)


func _open_death_screen() -> void:
	if not is_inside_tree():
		return
	var error := get_tree().change_scene_to_file(DEATH_SCREEN_PATH)
	if error != OK:
		_death_transition_started = false
		push_error("Could not open the death screen: %s" % error_string(error))


func _sync_vitals_from_fields() -> void:
	combat_vitals.health = health
	combat_vitals.max_health = max_health
	combat_vitals.stamina = stamina
	combat_vitals.max_stamina = max_stamina


func _sync_fields_from_vitals() -> void:
	health = combat_vitals.health
	max_health = combat_vitals.max_health
	stamina = combat_vitals.stamina
	max_stamina = combat_vitals.max_stamina


func _combat_or_locomotion_animation(locomotion_animation: String) -> String:
	if not action_state_machine.allows_movement():
		return action_state_machine.get_animation_base()
	return locomotion_animation


func set_screen_movement_basis(logic_right: Vector2, logic_down: Vector2) -> void:
	if logic_right.is_zero_approx() or logic_down.is_zero_approx():
		push_warning("Screen movement basis must contain two non-zero directions")
		return
	# Both vectors come from the same screen-space sample distance. Preserve
	# their relative lengths so diagonal input also stays diagonal on screen.
	_screen_right_in_logic = logic_right
	_screen_down_in_logic = logic_down


func movement_direction_for_screen_input(screen_direction: Vector2) -> Vector2:
	var logic_direction := (
		_screen_right_in_logic * screen_direction.x + _screen_down_in_logic * screen_direction.y
	)
	return logic_direction.normalized() if not logic_direction.is_zero_approx() else Vector2.ZERO


func is_movement_input_blocked() -> bool:
	return _movement_blocked()


func request_navigation_target(logic_position: Vector2) -> void:
	if navigation_agent == null or _movement_blocked():
		return
	if not action_state_machine.allows_movement():
		return
	navigation_agent.set_target_position(logic_position)


func _movement_blocked() -> bool:
	if not get_tree().get_nodes_in_group(&"demo_dialogue_active").is_empty():
		return true
	var inventory := get_node_or_null("InventoryController") as InventoryController
	if inventory != null and inventory.is_open():
		return true
	var journal := get_node_or_null("JournalController") as JournalController
	if journal != null and journal.is_open():
		return true
	var world_map := get_node_or_null("WorldMapController") as WorldMapController
	if world_map != null and world_map.is_open():
		return true
	var reflection := get_node_or_null("ReflectionController") as ReflectionController
	if reflection != null and reflection.is_open():
		return true
	# WHY: only visible modal hosts block locomotion. Closed overlays must leave
	# the group (see ControlsOverlay / ReflectionOverlay), but ignore invisible
	# members so a stale membership cannot freeze the player.
	for node in get_tree().get_nodes_in_group(&"modal_input_overlay"):
		if node is CanvasLayer and (node as CanvasLayer).visible:
			return true
		if node is CanvasItem and (node as CanvasItem).visible:
			return true
	var commission := get_node_or_null("ForgeCommissionController") as ForgeCommissionController
	return commission != null and commission.is_open()


func _get_encumbrance_speed_multiplier() -> float:
	if not has_node("/root/SessionState"):
		return 1.0
	return SessionState.state.bag.get_speed_multiplier()


func _get_terrain_speed_multiplier() -> float:
	if _map_definition == null or _map_grid == null:
		return 1.0
	var mud_wetness := 0.0
	if _mud_wetness_provider.is_valid():
		mud_wetness = float(_mud_wetness_provider.call())
	return MapTerrainMovement.speed_multiplier_at(
		_map_definition, _map_grid, global_position, mud_wetness
	)


func _apply_npc_pushes(movement_velocity: Vector2, delta: float) -> void:
	NpcPushScript.apply_player_contact_pushes(self, movement_velocity, delta)


func _update_movement_resources(delta: float, is_moving: bool) -> void:
	# Health changes belong to damage/healing systems, never to locomotion or idle.
	if is_moving:
		stamina = maxf(0.0, stamina - delta * STAMINA_DRAIN_RATE)


func _sync_resource_bars() -> void:
	if health_ring != null:
		health_ring.set_health(health, max_health)
	if stamina_bar != null:
		stamina_bar.max_value = max_stamina
		stamina_bar.value = stamina


func _on_velocity_computed(safe_velocity: Vector2) -> void:
	velocity = safe_velocity


func _get_animation_direction(direction_vector: Vector2) -> String:
	var direction_suffix = ""
	# Check length to avoid returning a suffix for a zero vector
	if direction_vector.length_squared() > 0:
		if direction_vector.y < 0:
			direction_suffix += "_north"
		else:
			direction_suffix += "_south"

		if direction_vector.x > 0:
			direction_suffix += "_east"
		if direction_vector.x < 0:
			direction_suffix += "_west"

	return direction_suffix


func update_animation(base_animation: String):
	if animation_player == null:
		return
	var final_animation = ""

	if base_animation == "run" or base_animation == "walk":
		# Player is moving based on input
		final_animation = base_animation + _get_animation_direction(velocity)
	else:
		# Player is idle, face the mouse
		var mouse_pos = get_global_mouse_position()
		var direction_to_mouse = mouse_pos - global_position
		final_animation = "idle_south"  # + _get_animation_direction(direction_to_mouse)

	# Only change the animation if the state has changed
	if animation_player.animation != final_animation and final_animation != "":
		animation_player.play(final_animation)
