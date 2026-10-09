class_name Player
extends CharacterBody2D

signal melee_attack_resolved(targets: Array[Node2D], profile: AttackProfile)
## Emitted after the hero talks himself through it; carries SelfTalk.perform's result.
signal self_talk_performed(result: Dictionary)
signal health_changed(current: float, maximum: float)
signal died
signal water_medium_changed(previous: PlayerSwimState.Medium, current: PlayerSwimState.Medium)

const SpiritSightScript := preload("res://scripts/combat/spirit_sight.gd")

const MeleeAttackResolverScript := preload("res://scripts/combat/melee_attack_resolver.gd")
const AttackProfileScript := preload("res://scripts/combat/attack_profile.gd")
const AttackProfileResolverScript := preload("res://scripts/combat/attack_profile_resolver.gd")
const NpcPushScript := preload("res://scripts/physics/npc_push.gd")
const DEATH_SCREEN_PATH := "res://scenes/death/death_screen.tscn"
const STAMINA_DRAIN_RATE := 10.0  # per second
const DODGE_STAMINA_COST := 18.0
const DODGE_DISTANCE_PX := 80.0
const DODGE_DEFAULT_SIDE := Vector2.RIGHT
## Roll (COMBAT_ANIMATION.md §3): longer, i-framed only while tucked, and the
## body turns into the roll unless the input points backward.
const ROLL_STAMINA_COST := 22.0
const ROLL_DISTANCE_PX := 112.0
## Travel happens while tucked; the get-up after this is in place.
const ROLL_TRAVEL_SEC := 0.5
## Input pointing this far behind the facing rolls backward without turning.
const ROLL_BACKWARD_DOT := -0.6
## Held guard turns a sideways roll into a strafe roll: the body tumbles shoulder
## over shoulder and keeps facing the threat. Within this cosine of the lateral axis.
const ROLL_SIDE_DOT := 0.5
## Soft target lock: an attack turns toward a hostile this far beyond reach.
const SOFT_LOCK_REACH_MULT := 1.8
const SOFT_LOCK_FACING_DOT := 0.0
## The lunge never carries the body into the soft-locked target.
const LUNGE_STOP_PX := 30.0

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
## Body build of the hero (ADR 0033): the apprentice is a teen; scales move timing,
## damage, reach and stamina.
var combat_build: StringName = CombatMoveCatalog.BUILD_TEEN
var self_talk := SelfTalk.new()

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
var _pending_roll_direction := Vector2.ZERO
var _pending_roll_strafe := false
var _roll_direction := Vector2.ZERO
var _roll_facing := Vector2.ZERO
var _roll_animation: StringName = CombatMoveCatalog.ROLL_FORWARD
var _cast_animation: StringName = CombatMoveCatalog.CAST_SELF
## Validated before the attack starts so stamina and the started move agree.
var _validated_attack_profile: AttackProfile
var _soft_lock_target: Node2D
## Scripted displacement (roll travel, attack lunge) measured along its axis.
var _scripted_motion_traveled := 0.0
var _death_transition_started := false
var _map_definition: MapDefinition
var _map_grid: MapTerrainGrid
var _map_origin := Vector2.ZERO
var _water_depth_provider := Callable()
var _mud_wetness_provider: Callable
## Walking drag from ground cover, 1 = none (tall grass, ADR 0039).
var _ground_drag_provider: Callable
## ADR 0021: derived from the water column under the body every physics tick.
var _swim := PlayerSwimState.new()

@onready var animation_player: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
# Optional so headless unit tests can construct Player.new() without the full scene.
@onready var navigation_agent: NavigationAgent2D = get_node_or_null("NavigationAgent2D")
@onready var health_ring: CharacterHealthRing = get_node_or_null("HealthRing")
@onready var stamina_bar: ProgressBar = get_node_or_null("StaminaBar")

func _ready() -> void:
	CollisionLayers.apply_player(self)
	add_to_group(CrowdYield.PLAYER_GROUP)
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
	var sight := SpiritSightScript.new()
	sight.name = "SpiritSight"
	add_child(sight)
	DoorNavigator.on_trigger_player_spawn.connect(_on_spawn)
	if navigation_agent != null:
		navigation_agent.velocity_computed.connect(Callable(self, "_on_velocity_computed"))


func _on_spawn(position: Vector2, direction: String):
	global_position = position
	if animation_player != null:
		animation_player.play("walk_" + direction)
		animation_player.stop()

func configure_map_movement(
	definition: MapDefinition, grid: MapTerrainGrid, origin: Vector2 = Vector2.ZERO
) -> void:
	_map_definition = definition
	_map_grid = grid
	# Hosted play keeps the player in world-global logic; terrain cells are
	# authored in location space, so sample at global - origin.
	_map_origin = origin


func terrain_speed_multiplier() -> float:
	return _get_terrain_speed_multiplier()


func set_mud_wetness_provider(provider: Callable) -> void:
	_mud_wetness_provider = provider


## Callable returning a 0..1 speed multiplier for the ground under the player.
func set_ground_drag_provider(provider: Callable) -> void:
	_ground_drag_provider = provider


## Water medium under the body (ADR 0021): walk, wade, swim or dive.
func water_medium() -> PlayerSwimState.Medium:
	return _swim.medium


func water_depth() -> float:
	return _swim.depth


## Depth of the body centre below the surface: 0 floating, positive while diving.
func swim_submersion() -> float:
	return _swim.submersion


func breath_fraction() -> float:
	return _swim.breath_fraction()


## Locations without a terrain grid (the seamless city) report the water column
## under a logic position themselves.
func set_water_depth_provider(provider: Callable) -> void:
	_water_depth_provider = provider


func _update_water(delta: float) -> void:
	var previous := _swim.medium
	var depth := (
		float(_water_depth_provider.call(global_position))
		if _water_depth_provider.is_valid()
		else PlayerWaterTraversal.depth_at(_map_definition, _map_grid, global_position - _map_origin)
	)
	var dive_held := (
		Input.is_action_pressed(&"player_dive")
		and combat_input_enabled
		and not _movement_blocked()
	)
	_swim.update(depth, dive_held, delta)
	if _swim.out_of_breath_event:
		stamina = maxf(0.0, stamina - PlayerSwimState.OUT_OF_BREATH_STAMINA_PENALTY)
		_sync_resource_bars()
	if _swim.medium != previous:
		water_medium_changed.emit(previous, _swim.medium)


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
	_update_water(_delta)
	# Water and scripted movement invalidate sight before this tick accepts actions.
	get_node("SpiritSight").enforce_availability()
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
		match action_state_machine.state:
			PlayerActionState.State.ROLL:
				_move_roll()
			PlayerActionState.State.ATTACK:
				_move_attack_lunge()
			_:
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

		if _swim.is_swimming():
			# A swimmer cannot stroll or sprint: one stroke speed per medium.
			new_animation = "run"
			current_speed = run_speed * encumbrance * _swim.speed_multiplier()
		elif is_walking():
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
				(walk_speed if is_walking() else run_speed)
				* _get_encumbrance_speed_multiplier()
				* _get_terrain_speed_multiplier()
				* (next_path_position - current_agent_position).normalized()
			)
			if not velocity.is_zero_approx() and _camera_facing_direction.is_zero_approx():
				_facing_direction = velocity.normalized()

			navigation_agent.set_velocity(velocity)
			new_animation = "walk" if is_walking() else "run"
		else:
			velocity = Vector2.ZERO

	_update_movement_resources(_delta, new_animation != "idle")
	_sync_resource_bars()
	var movement_velocity := velocity
	move_and_slide()
	_apply_npc_pushes(movement_velocity, _delta)
	update_animation(_combat_or_locomotion_animation(new_animation))


func _process_action_input(_delta: float) -> void:
	if not combat_input_enabled or _movement_blocked() or is_spirit_sight_active():
		return
	# One attack button for every device: a tap commits the next light strike of
	# the chain on release, holding past the threshold commits the heavy strike
	# without waiting for release (COMBAT_ANIMATION.md §2).
	_process_attack_charge_input(_delta)
	self_talk.tick(_delta)
	if InputMap.has_action(&"player_self_talk") and Input.is_action_just_pressed(&"player_self_talk"):
		perform_self_talk()
	for kind in PlayerActionInput.read_pressed_actions():
		if kind == PlayerActionKind.Kind.DODGE:
			try_start_dodge()
			continue
		if kind == PlayerActionKind.Kind.ROLL:
			try_start_roll()
			continue
		action_state_machine.try_start_action(kind)
	action_state_machine.set_guard_held(PlayerActionInput.read_guard_held())


## Talk himself through it (ADR 0033): a short damage-reduction buff, seen by nearby witnesses.
func perform_self_talk() -> Dictionary:
	var state: GameState = SessionState.state if has_node("/root/SessionState") else null
	var witnesses := SelfTalk.witnesses_near(get_tree(), global_position)
	var result := self_talk.perform(state, combat_vitals, witnesses)
	self_talk_performed.emit(result)
	return result


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


## Space roll. Forward, left and right turn the body into the roll (Witcher
## style); backward or no input rolls back while still facing the threat.
func try_start_roll(direction: Vector2 = Vector2.ZERO) -> bool:
	var requested := (
		direction.normalized()
		if not direction.is_zero_approx()
		else movement_direction_for_screen_input(ScreenDirectionInput.read_axis())
	)
	_pending_roll_direction = requested
	_pending_roll_strafe = PlayerActionInput.read_guard_held()
	var was_free_to_start := action_state_machine.state == PlayerActionState.State.MOVE
	var started := action_state_machine.try_start_action(PlayerActionKind.Kind.ROLL)
	if was_free_to_start and not started:
		_pending_roll_direction = Vector2.ZERO
	return started


static func roll_plan(requested: Vector2, facing: Vector2, strafe: bool = false) -> Dictionary:
	var normalized_facing := facing.normalized() if not facing.is_zero_approx() else Vector2.DOWN
	if strafe and not requested.is_zero_approx():
		var lateral := requested.normalized().dot(Vector2(normalized_facing.y, -normalized_facing.x))
		if absf(lateral) >= ROLL_SIDE_DOT:
			return {
				"direction": requested.normalized(),
				"facing": normalized_facing,
				"animation": CombatMoveCatalog.ROLL_LEFT if lateral > 0.0 else CombatMoveCatalog.ROLL_RIGHT,
			}
	if (
		requested.is_zero_approx()
		or requested.normalized().dot(normalized_facing) <= ROLL_BACKWARD_DOT
	):
		return {
			"direction": -normalized_facing,
			"facing": normalized_facing,
			"animation": CombatMoveCatalog.ROLL_BACKWARD,
		}
	var direction := requested.normalized()
	return {"direction": direction, "facing": direction, "animation": CombatMoveCatalog.ROLL_FORWARD}


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
	# ADR 0021: no attacks, guard or dodge while swimming or diving.
	if _swim.blocks_combat() or is_spirit_sight_active():
		return false
	match kind:
		PlayerActionKind.Kind.DODGE:
			return stamina >= DODGE_STAMINA_COST
		PlayerActionKind.Kind.ROLL:
			return stamina >= ROLL_STAMINA_COST
		PlayerActionKind.Kind.ATTACK:
			action_state_machine.combo_length = CombatMoveCatalog.combo_length(
				AttackProfileResolverScript.weapon_class_for_state(
					SessionState.state, SessionState.content_db
				)
			)
			var heavy := action_state_machine.next_attack_is_heavy()
			var profile := _resolve_move_profile(heavy, action_state_machine.next_combo_step(heavy))
			if stamina < profile.stamina_cost:
				return false
			_validated_attack_profile = profile
			return true
	return true


func _on_action_started(kind: PlayerActionKind.Kind) -> void:
	match kind:
		PlayerActionKind.Kind.ATTACK:
			_start_attack()
		PlayerActionKind.Kind.ROLL:
			_start_roll()
		PlayerActionKind.Kind.DODGE:
			_start_dodge()


func _start_attack() -> void:
	var profile := _validated_attack_profile
	_validated_attack_profile = null
	if profile == null:
		profile = _resolve_move_profile(
			action_state_machine.attack_is_heavy, action_state_machine.combo_step
		)
	_prepare_attack_for_profile(profile)
	stamina = maxf(0.0, stamina - profile.stamina_cost)
	_scripted_motion_traveled = 0.0
	_soft_lock_target = PlayerPrimaryAction.find_hostile_in_front(
		self, _facing_direction, profile.reach_px * SOFT_LOCK_REACH_MULT, SOFT_LOCK_FACING_DOT
	)
	if _soft_lock_target != null:
		_facing_direction = (_soft_lock_target.global_position - global_position).normalized()
	_sync_resource_bars()


func _start_roll() -> void:
	var plan := roll_plan(_pending_roll_direction, _current_dodge_facing(), _pending_roll_strafe)
	_pending_roll_direction = Vector2.ZERO
	_pending_roll_strafe = false
	_roll_direction = plan["direction"]
	_roll_facing = plan["facing"]
	_roll_animation = plan["animation"]
	# Kalev ends the roll facing where he rolled; a mounted camera re-aims him.
	_facing_direction = _roll_facing
	_scripted_motion_traveled = 0.0
	stamina = maxf(0.0, stamina - ROLL_STAMINA_COST)
	_sync_resource_bars()


func _start_dodge() -> void:
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
	var traveled := _slide_exact(_dodge_direction * intended_distance).dot(_dodge_direction)
	_dodge_distance_remaining = maxf(0.0, _dodge_distance_remaining - maxf(0.0, traveled))


## Ease-out travel: the push-off is fast, the tuck decelerates, the get-up is
## in place. Distance is a function of elapsed time, so frame rate cannot
## change how far a roll goes.
func _move_roll() -> void:
	var ratio := clampf(action_state_machine.state_elapsed_sec / ROLL_TRAVEL_SEC, 0.0, 1.0)
	var eased := 1.0 - (1.0 - ratio) * (1.0 - ratio)
	_advance_scripted_motion(_roll_direction, ROLL_DISTANCE_PX * eased)


## Weight: the body steps into the strike between wind-up and impact, and
## stops short of a soft-locked target instead of shoving into it.
func _move_attack_lunge() -> void:
	var profile := _active_attack_profile
	if profile == null or profile.lunge_px <= 0.0:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	var target_distance := profile.lunge_px * smoothstep(
		0.0, maxf(profile.impact_timing_sec, 0.001), action_state_machine.state_elapsed_sec
	)
	if is_instance_valid(_soft_lock_target):
		var gap := global_position.distance_to(_soft_lock_target.global_position) - LUNGE_STOP_PX
		target_distance = minf(target_distance, _scripted_motion_traveled + maxf(gap, 0.0))
	_advance_scripted_motion(_facing_direction, target_distance)


func _advance_scripted_motion(direction: Vector2, target_distance: float) -> void:
	var step := target_distance - _scripted_motion_traveled
	if step <= 0.0 or direction.is_zero_approx():
		velocity = Vector2.ZERO
		move_and_slide()
		return
	var axis := direction.normalized()
	_scripted_motion_traveled += maxf(0.0, _slide_exact(axis * step).dot(axis))


## WHY: move_and_slide multiplies velocity by the physics step inside a physics
## callback but by the idle frame delta outside one (focused tests, scripted
## calls), so dividing by the wrong step made dodges and rolls overshoot. Using
## the step move_and_slide will actually apply keeps travel an exact function
## of the action clock while collision still resolves like ordinary walking.
func _slide_exact(motion: Vector2) -> Vector2:
	var before := global_position
	var step := (
		get_physics_process_delta_time() if Engine.is_in_physics_frame() else get_process_delta_time()
	)
	velocity = motion / maxf(step, 0.0001)
	move_and_slide()
	velocity = Vector2.ZERO
	return global_position - before


## Public entry for the context-sensitive primary click (left mouse button in
## first/third person). Mirrors the instant-attack path so mouse, keyboard, and
## gamepad attacks share the same state, stamina, and profile rules.
func request_primary_attack() -> bool:
	return _request_attack(false)


## Heavy strike entry for tests and scripted callers.
func request_heavy_attack() -> bool:
	return _request_attack(true)


## Starts the attack now, or buffers it as the next combo step while a swing,
## roll or recovery is still running. Returns true only when it started now.
func _request_attack(heavy: bool) -> bool:
	if (
		not combat_input_enabled or _movement_blocked()
		or _swim.blocks_combat() or is_spirit_sight_active()
	):
		return false
	return action_state_machine.try_start_attack(heavy)


## Exposed so the click router can hold the primary button to charge instead of
## swinging on press. Every move set has a heavy strike.
func supports_charged_attack() -> bool:
	return _supports_charged_attack()


## Mouse press (MapClickInputController) and keyboard/gamepad press share this.
func begin_attack_charge() -> void:
	if not combat_input_enabled or _movement_blocked() or is_spirit_sight_active():
		return
	_attack_charge_active = true
	_attack_charge_sec = 0.0


## Release before the threshold commits the next light strike.
func release_attack_charge() -> bool:
	if not _attack_charge_active:
		return false
	return _commit_attack_from_charge_hold(_attack_charge_sec)


func is_attack_charging() -> bool:
	return _attack_charge_active


func _process_attack_charge_input(delta: float) -> void:
	if PlayerActionInput.read_attack_just_pressed():
		begin_attack_charge()
	if not _attack_charge_active:
		return
	_attack_charge_sec += delta
	if PlayerActionInput.read_attack_just_released():
		release_attack_charge()
	elif _attack_charge_sec >= _charge_threshold_sec():
		# Holding is the heavy verb: it fires at the threshold, not on release.
		_commit_attack_from_charge_hold(_attack_charge_sec)


func commit_attack_from_charge_hold(hold_sec: float) -> bool:
	return _commit_attack_from_charge_hold(hold_sec)


func _commit_attack_from_charge_hold(hold_sec: float) -> bool:
	_reset_attack_charge()
	if _swim.blocks_combat() or is_spirit_sight_active():
		return false
	return _request_attack(_supports_charged_attack() and hold_sec >= _charge_threshold_sec())


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


## Shared heal hook for timed magic effects: keeps the mirrored fields and the
## health ring in step with vitals. Returns the health actually restored.
func receive_magic_heal(amount: float) -> float:
	_sync_vitals_from_fields()
	var restored := combat_vitals.heal(amount)
	if restored <= 0.0:
		return 0.0
	_sync_fields_from_vitals()
	_sync_resource_bars()
	health_changed.emit(health, max_health)
	return restored


func last_hit_result() -> CombatHitResult:
	return _last_hit_result


func is_combat_dead() -> bool:
	return combat_vitals.is_dead()


## Spell casts resolve instantly in MagicResolver; this only plays the matching
## gesture and briefly roots Kalev. Casting is refused mid-swing or mid-roll so
## the body never shows two verbs at once.
func can_begin_cast() -> bool:
	return action_state_machine.state in [
		PlayerActionState.State.MOVE,
		PlayerActionState.State.RECOVERY,
		PlayerActionState.State.GUARD,
	]


func begin_cast_gesture(delivery_kind: String) -> bool:
	var move := CombatMoveCatalog.action_move(CombatMoveCatalog.cast_move_for_delivery(delivery_kind))
	if action_state_machine.state == PlayerActionState.State.GUARD:
		action_state_machine.set_guard_held(false)
	if not action_state_machine.try_start_cast(move.duration_sec):
		return false
	_cast_animation = move.id
	return true


func view_facing() -> Vector2:
	if (
		action_state_machine.state == PlayerActionState.State.DODGE
		and not _dodge_facing.is_zero_approx()
	):
		return _dodge_facing
	if (
		action_state_machine.state == PlayerActionState.State.ROLL
		and not _roll_facing.is_zero_approx()
	):
		return _roll_facing
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
	var animation_base := _combat_or_locomotion_animation(_current_locomotion_animation())
	if animation_base == "attack":
		return _active_attack_profile.animation
	if animation_base == "dodge":
		return _dodge_animation
	if animation_base == "roll":
		return _roll_animation
	if animation_base == "cast":
		return _cast_animation
	if animation_base == "recovery":
		# Recovery is a logic-only lock window; the shared humanoid has no
		# dedicated recovery clip, so keep the map presentation at idle.
		return &"idle"
	return StringName(animation_base)


## Action clock for the rig: every committed action is presented against the
## state machine clock, so the visible contact frame and the logic impact agree
## at any frame rate.
func view_animation_elapsed_sec() -> float:
	if action_state_machine.state in [
		PlayerActionState.State.ATTACK,
		PlayerActionState.State.DODGE,
		PlayerActionState.State.ROLL,
		PlayerActionState.State.CAST,
		PlayerActionState.State.HIT,
	]:
		return action_state_machine.state_elapsed_sec
	return 0.0


## Logic length of the running action, so clip-scaled actions (dodge, hit)
## fill exactly the window the state machine gives them.
func view_animation_duration_sec() -> float:
	match action_state_machine.state:
		PlayerActionState.State.ATTACK:
			return action_state_machine.attack_duration_sec
		PlayerActionState.State.DODGE:
			return action_state_machine.dodge_duration_sec
		PlayerActionState.State.ROLL:
			return action_state_machine.roll_duration_sec
		PlayerActionState.State.CAST:
			return action_state_machine.cast_duration_sec
		PlayerActionState.State.HIT:
			return action_state_machine.hit_duration_sec
	return 0.0


func is_spirit_sight_active() -> bool:
	return has_node("/root/SessionState") and SessionState.state.spirit_sight


func is_walking() -> bool:
	return is_spirit_sight_active() or Input.is_action_pressed("ui_shift")


func leave_spirit_sight() -> void:
	get_node("SpiritSight").leave_immediately()


func spirit_sight_blocked() -> bool:
	return (
		not combat_input_enabled or _movement_blocked() or _swim.is_swimming()
		or action_state_machine.state != PlayerActionState.State.MOVE
		or is_attack_charging()
	)


func _current_locomotion_animation() -> String:
	if _movement_blocked():
		return "idle"
	if not action_state_machine.allows_movement():
		return action_state_machine.get_animation_base()
	if not velocity.is_zero_approx():
		if is_walking():
			return "walk"
		return "run"
	return "idle"


## World-facing direction on the logic plane; read by presentation (R-1187
## tree strikes) so it never has to reach into private movement state.
func facing_direction() -> Vector2:
	return _facing_direction


func _on_attack_impact() -> void:
	var profile := _active_attack_profile
	var targets: Array[Node2D] = MeleeAttackResolverScript.strike_with_profile(
		self, _facing_direction, profile
	)
	if has_node("/root/SessionState"):
		PhysicalBlowGuilt.record_hits(SessionState.state, targets)
	melee_attack_resolved.emit(targets, profile)


func _on_action_state_changed(
	_previous: PlayerActionState.State, current: PlayerActionState.State
) -> void:
	if current != PlayerActionState.State.ATTACK:
		_active_attack_profile = _resolve_attack_profile()


func _resolve_attack_profile(use_charged: bool = false) -> AttackProfile:
	return AttackProfileResolverScript.resolve_for_state(
		SessionState.state, SessionState.content_db, use_charged, combat_build
	)


func _resolve_move_profile(heavy: bool, combo_step: int) -> AttackProfile:
	return AttackProfileResolverScript.resolve_move(
		SessionState.state, SessionState.content_db, heavy, combo_step, combat_build
	)


func prepare_attack_profile(profile: AttackProfile) -> void:
	_prepare_attack_for_profile(profile)


func _prepare_attack_for_profile(profile: AttackProfile) -> void:
	_active_attack_profile = profile
	action_state_machine.attack_duration_sec = profile.attack_duration_sec
	action_state_machine.attack_impact_sec = profile.impact_timing_sec
	action_state_machine.attack_cancel_sec = profile.cancel_sec
	# Evading out of a swing is allowed once the blow has landed.
	action_state_machine.evade_cancel_sec = minf(
		profile.cancel_sec, profile.impact_timing_sec + CombatMoveCatalog.EVADE_CANCEL_AFTER_IMPACT_SEC
	)


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
	return _get_ground_drag_multiplier() * _get_map_terrain_speed_multiplier()


func _get_ground_drag_multiplier() -> float:
	if _swim.medium != PlayerSwimState.Medium.WALK or not _ground_drag_provider.is_valid():
		return 1.0
	return clampf(float(_ground_drag_provider.call()), 0.1, 1.0)


func _get_map_terrain_speed_multiplier() -> float:
	if _map_definition == null or _map_grid == null:
		return 1.0
	# ADR 0021: wading drag replaces the dry-ground terrain factor; swimming speed is
	# applied separately in _physics_process.
	if _swim.medium == PlayerSwimState.Medium.WADE:
		return _swim.speed_multiplier()
	if _swim.is_swimming():
		return _swim.speed_multiplier()
	var mud_wetness := 0.0
	if _mud_wetness_provider.is_valid():
		mud_wetness = float(_mud_wetness_provider.call())
	return MapTerrainMovement.speed_multiplier_at(
		_map_definition, _map_grid, global_position - _map_origin, mud_wetness
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
