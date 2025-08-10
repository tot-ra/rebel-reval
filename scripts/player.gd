extends CharacterBody2D

@export var speed = 120

@onready var animation_player = $AnimatedSprite2D

func _physics_process(_delta):
	var direction_x = Input.get_axis("ui_left", "ui_right")
	var direction_y = Input.get_axis("ui_up", "ui_down")
	
	# --- Velocity ---
	if direction_x:
		velocity.x = direction_x * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		
	if direction_y:
		velocity.y = direction_y * speed
	else:
		velocity.y = move_toward(velocity.y, 0, speed)

	update_animation()
	move_and_slide()

func update_animation():
	var new_animation
	
	new_animation = "idle" 
	
	if velocity.length() > 0:
		# Player is moving
		if velocity.x > 0:
			new_animation = "walk_right"
			
		if velocity.y > 0:
			new_animation = "walk_down"
			
		
	# Only change the animation if the state has changed
	if animation_player.animation != new_animation:
		animation_player.play(new_animation)
