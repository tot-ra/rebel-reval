extends CharacterBody2D

class_name Player

@export var walk_speed = 200
@export var run_speed = 400

@onready var animation_player = $AnimatedSprite2D
@onready var navigation_agent = $NavigationAgent2D

func _ready():
	DoorNavigator.on_trigger_player_spawn.connect(_on_spawn)
	navigation_agent.velocity_computed.connect(Callable(self, "_on_velocity_computed"))

func _on_spawn(position: Vector2, direction: String):
	global_position=position
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
		
		print("Player velocity: ", velocity)
		navigation_agent.set_target_position(global_position)
		if direction_x && direction_y:
			current_speed = current_speed * 0.7
		
		velocity.x = direction_x * current_speed
		velocity.y = direction_y * current_speed
		
	else:
		if not navigation_agent.is_navigation_finished():
			var current_agent_position: Vector2 = global_position
			var next_path_position: Vector2 = navigation_agent.get_next_path_position()

			velocity = run_speed * (next_path_position - current_agent_position).normalized()
			
			print("navigating new_velocity:", velocity)
			
			navigation_agent.set_velocity(velocity)
			new_animation = "run"
		else:
			velocity = Vector2.ZERO
			print("navigation_agent.is_navigation_finished")

	move_and_slide()
	update_animation(new_animation)

func _on_velocity_computed(safe_velocity):
	velocity = safe_velocity
	print("Safe velocity computed: ", safe_velocity)

func update_animation(new_animation: String):
	if velocity.length() > 0:		
		if velocity.y > 0:
			new_animation = new_animation + "_south"
		if velocity.y < 0:
			new_animation = new_animation + "_north"
		
		# Player is moving
		if velocity.x > 0:
			new_animation = new_animation + "_east"
		if velocity.x < 0:
			new_animation = new_animation + "_west"
			
			
		
	# Only change the animation if the state has changed
	if animation_player.animation != new_animation:
		animation_player.play(new_animation)
