extends CharacterBody2D

class_name Player

@export var walk_speed = 200
@export var run_speed = 1000

@onready var animation_player: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@onready var health_bar: ProgressBar = $HealthBar
@onready var stamina_bar: ProgressBar = $StaminaBar

var health: float = 100.0
var max_health: float = 100.0
var stamina: float = 100.0
var max_stamina: float = 100.0
const STAMINA_DRAIN_RATE := 10.0 # per second

func _ready() -> void:
	_sync_resource_bars()
	DoorNavigator.on_trigger_player_spawn.connect(_on_spawn)
	navigation_agent.velocity_computed.connect(Callable(self, "_on_velocity_computed"))

func _on_spawn(position: Vector2, direction: String):
	global_position=position
	if animation_player != null:
		animation_player.play("walk_"+direction)
		animation_player.stop()

func _physics_process(_delta):
	var direction_x = Input.get_axis("ui_left", "ui_right")
	var direction_y = Input.get_axis("ui_up", "ui_down")
	var new_animation = "idle"
	
	if direction_x != 0 or direction_y != 0:
		var current_speed = run_speed
		
		if Input.is_action_pressed("ui_shift"):
			new_animation = "walk"
			current_speed = walk_speed
		else:
			new_animation = "run"
		
		navigation_agent.set_target_position(global_position)
		if direction_x && direction_y:
			current_speed = current_speed / 1.4 # normalize vector for diagonal movement to be 1/sqrt(2)
		
		velocity.x = direction_x * current_speed
		velocity.y = direction_y * current_speed
		
	else:
		if not navigation_agent.is_navigation_finished():
			var current_agent_position: Vector2 = global_position
			var next_path_position: Vector2 = navigation_agent.get_next_path_position()

			velocity = run_speed * (next_path_position - current_agent_position).normalized()
			
			navigation_agent.set_velocity(velocity)
			new_animation = "run"
		else:
			velocity = Vector2.ZERO

	_update_movement_resources(_delta, new_animation != "idle")
	_sync_resource_bars()
	move_and_slide()
	update_animation(new_animation)

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
