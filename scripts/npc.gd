extends CharacterBody2D

class_name NPC

@export var walk_speed = 200
@export var run_speed = 400
@export var hostile := false

@onready var animation_player = get_node_or_null("AnimatedSprite2D")
@onready var navigation_agent = get_node_or_null("NavigationAgent2D")

var _push_recovery_sec := 0.0


func _ready():
	CollisionLayers.apply_npc(self)
	add_to_group(NpcPush.PUSH_GROUP)
	if navigation_agent != null:
		navigation_agent.velocity_computed.connect(Callable(self, "_on_velocity_computed"))

func _on_spawn(position: Vector2, direction: String):
	global_position=position
	animation_player.play("walk_"+direction)
	animation_player.stop()


func is_pushable_by_player() -> bool:
	return not hostile


func _physics_process(_delta):
	if NpcPush.apply_queued_push(self, _delta):
		_push_recovery_sec = 0.35
		update_animation("idle")
		return

	if _push_recovery_sec > 0.0:
		_push_recovery_sec -= _delta
		velocity = Vector2.ZERO
		update_animation("idle")
		return

	var new_animation = "idle"
	
	if navigation_agent != null and not navigation_agent.is_navigation_finished():
		var current_agent_position: Vector2 = global_position
		var next_path_position: Vector2 = navigation_agent.get_next_path_position()

		velocity = run_speed * (next_path_position - current_agent_position).normalized()
		
		navigation_agent.set_velocity(velocity)
		new_animation = "run"
		
		if not NpcPush.player_blocks_body(self):
			move_and_slide()
		else:
			velocity = Vector2.ZERO
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
