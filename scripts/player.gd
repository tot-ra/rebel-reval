extends CharacterBody2D

@export var speed = 200

func _physics_process(_delta):
	var direction_x = Input.get_axis("ui_left", "ui_right")
	var direction_y = Input.get_axis("ui_up", "ui_down")
	
	print("Direction: ", Vector2(direction_x, direction_y))
	
	if direction_x:
		velocity.x = direction_x * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		
	if direction_y:
		velocity.y = direction_y * speed
	else:
		velocity.y = move_toward(velocity.y, 0, speed)

	print("Velocity: ", velocity)
	move_and_slide()
