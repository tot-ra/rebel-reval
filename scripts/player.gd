extends CharacterBody2D

class_name Player

@export var speed = 300
@export var run_speed = 900

@onready var animation_player = $AnimatedSprite2D

func _ready():
	DoorNavigator.on_trigger_player_spawn.connect(_on_spawn)

func _on_spawn(position: Vector2, direction: String):
	global_position=position
	animation_player.play("walk_"+direction)
	animation_player.stop()

func _physics_process(_delta):
	var current_speed = speed
	if Input.is_action_pressed("ui_shift"):
		current_speed = run_speed
	
	var direction_x = Input.get_axis("ui_left", "ui_right")
	var direction_y = Input.get_axis("ui_up", "ui_down")
	
	if direction_x && direction_y:
		current_speed = current_speed * 0.7
	
	# --- Velocity ---
	if direction_x:
		velocity.x = direction_x * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		
	if direction_y:
		velocity.y = direction_y * current_speed
	else:
		velocity.y = move_toward(velocity.y, 0, current_speed)

	update_animation()
	move_and_slide()

func update_animation():
	var new_animation
	
	new_animation = "idle" 
	
	if velocity.length() > 0:
		if Input.is_action_pressed("ui_shift"):
			new_animation = "run"
		else:
			new_animation = "walk"
		
		
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
