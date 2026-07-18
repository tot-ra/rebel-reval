extends CharacterBody2D

class_name Player

# Logic px/s (32 px = 1 world unit): a readable walk and a believable sprint.
# MapViewRuntime.RUN_ANIMATION_MIN_SPEED sits midway between these.
@export var walk_speed = 100
@export var run_speed = 240

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

func _ready() -> void:
	_sync_resource_bars()
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
	if _movement_blocked():
		velocity = Vector2.ZERO
		_sync_resource_bars()
		move_and_slide()
		update_animation("idle")
		return

	var screen_direction := ScreenDirectionInput.read_axis()
	var movement_direction := movement_direction_for_screen_input(screen_direction)
	var new_animation = "idle"
	
	if not movement_direction.is_zero_approx():
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
			
			navigation_agent.set_velocity(velocity)
			new_animation = "run"
		else:
			velocity = Vector2.ZERO

	_update_movement_resources(_delta, new_animation != "idle")
	_sync_resource_bars()
	move_and_slide()
	update_animation(new_animation)

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
	var controller := get_node_or_null("InventoryController") as InventoryController
	return controller != null and controller.is_open()


func _get_encumbrance_speed_multiplier() -> float:
	if not has_node("/root/SessionState"):
		return 1.0
	return SessionState.state.bag.get_speed_multiplier()


func _get_terrain_speed_multiplier() -> float:
	if _map_definition == null or _map_grid == null:
		return 1.0
	return MapTerrainMovement.speed_multiplier_at(_map_definition, _map_grid, global_position)


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
