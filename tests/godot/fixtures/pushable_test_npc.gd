extends CharacterBody2D

## Minimal pushable logic body for automated movement tests.

@export var hostile := false
@export var move_speed := 120.0

var _push_recovery_sec := 0.0


func _ready() -> void:
	CollisionLayers.apply_npc(self)
	add_to_group(NpcPush.PUSH_GROUP)


func is_pushable_by_player() -> bool:
	return not hostile


func _physics_process(delta: float) -> void:
	if NpcPush.apply_queued_push(self, delta):
		_push_recovery_sec = 0.35
		return

	if _push_recovery_sec > 0.0:
		_push_recovery_sec -= delta
		velocity = Vector2.ZERO
		return

	var agent := get_node_or_null("NavigationAgent2D") as NavigationAgent2D
	if agent == null or agent.is_navigation_finished():
		velocity = Vector2.ZERO
		return

	var next_path_position := agent.get_next_path_position()
	velocity = (next_path_position - global_position).normalized() * move_speed
	if not NpcPush.player_blocks_body(self):
		move_and_slide()
	else:
		velocity = Vector2.ZERO
