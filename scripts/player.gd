extends CharacterBody2D

class_name Player

const MeleeAttackResolverScript := preload("res://scripts/combat/melee_attack_resolver.gd")
const AttackProfileScript := preload("res://scripts/combat/attack_profile.gd")
const AttackProfileResolverScript := preload("res://scripts/combat/attack_profile_resolver.gd")
const NpcPushScript := preload("res://scripts/physics/npc_push.gd")

signal melee_attack_resolved(targets: Array[Node2D], profile: AttackProfile)
signal health_changed(current: float, maximum: float)

# Logic px/s (32 px = 1 world unit): a readable walk and a believable sprint.
# MapViewRuntime.RUN_ANIMATION_MIN_SPEED sits midway between these.
@export var walk_speed = 100
@export var run_speed = 240
@export var combat_input_enabled := true

@onready var animation_player: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@onready var health_bar: ProgressBar = $HealthBar
@onready var stamina_bar: ProgressBar = $StaminaBar

var health: float = 100.0
var max_health: float = 100.0
var stamina: float = 100.0
var max_stamina: float = 100.0
const STAMINA_DRAIN_RATE := 10.0 # per second

var _screen_right_in_logic := Vector2.RIGHT
var _screen_down_in_logic := Vector2.DOWN
var _facing_direction := Vector2.DOWN
var action_state_machine := PlayerActionStateMachine.new()
var _active_attack_profile: AttackProfile = AttackProfile.unarmed()
var _attack_charge_sec: float = 0.0
var _attack_charge_active: bool = false

func _ready() -> void:
	CollisionLayers.apply_player(self)
	add_to_group(MeleeAttackResolver.DAMAGEABLE_GROUP)
	_sync_resource_bars()
	if not action_state_machine.attack_impact.is_connected(_on_attack_impact):
		action_state_machine.attack_impact.connect(_on_attack_impact)
	if not action_state_machine.state_changed.is_connected(_on_action_state_changed):
		action_state_machine.state_changed.connect(_on_action_state_changed)
	DoorNavigator.on_trigger_player_spawn.connect(_on_spawn)
	navigation_agent.velocity_computed.connect(Callable(self, "_on_velocity_computed"))

func _on_spawn(position: Vector2, direction: String):
	global_position=position
	if animation_player != null:
		animation_player.play("walk_"+direction)
		animation_player.stop()

var _map_definition: MapDefinition
var _map_grid: MapTerrainGrid


func configure_map_movement(definition: MapDefinition, grid: MapTerrainGrid) -> void:
	_map_definition = definition
	_map_grid = grid


func _physics_process(_delta):
	action_state_machine.tick(_delta)
	_process_action_input(_delta)

	if _movement_blocked():
		velocity = Vector2.ZERO
		_sync_resource_bars()
		move_and_slide()
		update_animation(_combat_or_locomotion_animation("idle"))
		return

	if not action_state_machine.allows_movement():
		velocity = Vector2.ZERO
		_sync_resource_bars()
		move_and_slide()
		update_animation(_combat_or_locomotion_animation(action_state_machine.get_animation_base()))
		return

	var screen_direction := ScreenDirectionInput.read_axis()
	var movement_direction := movement_direction_for_screen_input(screen_direction)
	var new_animation = "idle"
	
	if not movement_direction.is_zero_approx():
		_facing_direction = movement_direction.normalized()
		var encumbrance := _get_encumbrance_speed_multiplier()
		var terrain_speed := _get_terrain_speed_multiplier()
		var current_speed = run_speed * encumbrance * terrain_speed
		
		if Input.is_action_pressed("ui_shift"):
			new_animation = "walk"
			current_speed = walk_speed * encumbrance * terrain_speed
		else:
			new_animation = "run"
		
		navigation_agent.set_target_position(global_position)
		velocity = movement_direction * current_speed
		
	else:
		if not navigation_agent.is_navigation_finished():
			var current_agent_position: Vector2 = global_position
			var next_path_position: Vector2 = navigation_agent.get_next_path_position()

			velocity = run_speed * _get_encumbrance_speed_multiplier() * _get_terrain_speed_multiplier() * (next_path_position - current_agent_position).normalized()
			if not velocity.is_zero_approx():
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

func _process_action_input(delta: float) -> void:
	if not combat_input_enabled or _movement_blocked():
		return
	if _supports_charged_attack():
		_process_charged_attack_input(delta)
	else:
		_process_instant_attack_input()
	for kind in PlayerActionInput.read_pressed_actions():
		if kind == PlayerActionKind.Kind.ATTACK:
			continue
		action_state_machine.try_start_action(kind)
	action_state_machine.set_guard_held(PlayerActionInput.read_guard_held())


func _process_instant_attack_input() -> void:
	for kind in PlayerActionInput.read_pressed_actions():
		if kind != PlayerActionKind.Kind.ATTACK:
			continue
		var profile := _resolve_attack_profile(false)
		if stamina < profile.stamina_cost:
			continue
		_prepare_attack_for_profile(profile)
		if action_state_machine.try_start_action(kind):
			stamina = maxf(0.0, stamina - profile.stamina_cost)
			_sync_resource_bars()


func _process_charged_attack_input(delta: float) -> void:
	if action_state_machine.state != PlayerActionState.State.MOVE:
		_reset_attack_charge()
		return
	if PlayerActionInput.read_attack_just_pressed():
		_attack_charge_active = true
		_attack_charge_sec = 0.0
	if _attack_charge_active and PlayerActionInput.read_attack_held():
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
		SessionState.state,
		SessionState.content_db
	)


func _charge_threshold_sec() -> float:
	return AttackProfileResolverScript.charge_threshold_sec_for_state(
		SessionState.state,
		SessionState.content_db
	)


func apply_hit_stun() -> void:
	action_state_machine.apply_hit()


func take_damage(amount: float, _source: Node = null, _damage_type: StringName = &"") -> float:
	if amount <= 0.0 or health <= 0.0 or is_combat_invulnerable():
		return 0.0
	var previous := health
	health = clampf(health - amount, 0.0, max_health)
	var applied := previous - health
	_sync_resource_bars()
	health_changed.emit(health, max_health)
	if applied > 0.0:
		apply_hit_stun()
	return applied


func view_facing() -> Vector2:
	return _facing_direction


func view_animation() -> StringName:
	var animation_base := _combat_or_locomotion_animation(_current_locomotion_animation())
	if animation_base == "attack":
		return _active_attack_profile.animation
	return StringName(animation_base)


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
	var targets: Array[Node2D] = MeleeAttackResolverScript.strike(
		self,
		_facing_direction,
		profile.reach_px,
		profile.facing_dot,
		profile.damage,
		profile.damage_type
	)
	melee_attack_resolved.emit(targets, profile)


func _on_action_state_changed(_previous: PlayerActionState.State, current: PlayerActionState.State) -> void:
	if current != PlayerActionState.State.ATTACK:
		_active_attack_profile = _resolve_attack_profile()


func _resolve_attack_profile(use_charged: bool = false) -> AttackProfile:
	return AttackProfileResolverScript.resolve_for_state(
		SessionState.state,
		SessionState.content_db,
		use_charged
	)


func prepare_attack_profile(profile: AttackProfile) -> void:
	_prepare_attack_for_profile(profile)


func _prepare_attack_for_profile(profile: AttackProfile) -> void:
	_active_attack_profile = profile
	action_state_machine.attack_duration_sec = profile.attack_duration_sec
	action_state_machine.attack_impact_sec = profile.impact_timing_sec


func is_combat_invulnerable() -> bool:
	return action_state_machine.is_invulnerable()


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
		_screen_right_in_logic * screen_direction.x
		+ _screen_down_in_logic * screen_direction.y
	)
	return logic_direction.normalized() if not logic_direction.is_zero_approx() else Vector2.ZERO

func _movement_blocked() -> bool:
	if not get_tree().get_nodes_in_group(&"demo_dialogue_active").is_empty():
		return true
	var inventory := get_node_or_null("InventoryController") as InventoryController
	if inventory != null and inventory.is_open():
		return true
	var journal := get_node_or_null("JournalController") as JournalController
	if journal != null and journal.is_open():
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
	return MapTerrainMovement.speed_multiplier_at(_map_definition, _map_grid, global_position)


func _apply_npc_pushes(movement_velocity: Vector2, delta: float) -> void:
	NpcPushScript.apply_player_contact_pushes(self, movement_velocity, delta)


func _update_movement_resources(delta: float, is_moving: bool) -> void:
	# Health changes belong to damage/healing systems, never to locomotion or idle.
	if is_moving:
		stamina = maxf(0.0, stamina - delta * STAMINA_DRAIN_RATE)

func _sync_resource_bars() -> void:
	health_bar.max_value = max_health
	health_bar.value = health
	stamina_bar.max_value = max_stamina
	stamina_bar.value = stamina

func _on_velocity_computed(safe_velocity):
	velocity = safe_velocity
	print("Safe velocity computed: ", safe_velocity)

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
		final_animation = "idle_south" # + _get_animation_direction(direction_to_mouse)

	# Only change the animation if the state has changed
	if animation_player.animation != final_animation and final_animation != "":
		animation_player.play(final_animation)
