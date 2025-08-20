extends CharacterBody2D

class_name NPC

@export var walk_speed = 200
@export var run_speed = 400

@onready var animation_player = $AnimatedSprite2D
@onready var navigation_agent = $NavigationAgent2D

func _ready():
	navigation_agent.velocity_computed.connect(Callable(self, "_on_velocity_computed"))

func _on_spawn(position: Vector2, direction: String):
	global_position=position
	animation_player.play("walk_"+direction)
	animation_player.stop()

func _physics_process(_delta):
	var new_animation = "idle"
	
	if not navigation_agent.is_navigation_finished():
		var current_agent_position: Vector2 = global_position
		var next_path_position: Vector2 = navigation_agent.get_next_path_position()

		velocity = run_speed * (next_path_position - current_agent_position).normalized()
		
		navigation_agent.set_velocity(velocity)
		new_animation = "run"
		
		move_and_slide()
		update_animation(new_animation)
	else:
		velocity = Vector2.ZERO


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
