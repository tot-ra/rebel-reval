class_name FadeArea
extends Area2D

@export var target_to_fade: NodePath

var target_node

func _ready():
	target_node = get_node_or_null(target_to_fade)
	if !target_node:
		print("FadeArea: Target node not found!")
		return

	var _error = self.connect("body_entered", _on_body_entered)
	var _error2 = self.connect("body_exited", _on_body_exited)
	print("FadeArea ready for: ", target_node.name)

func _on_body_entered(body):
	if body is Player:
		print("Player entered FadeArea for ", target_node.name)
		_fade(target_node)

func _on_body_exited(body):
	if body is Player:
		print("Player exited FadeArea for ", target_node.name)
		_unfade(target_node)

func _fade(node):
	if _can_fade(node):
		node.modulate.a = 0.3
	
	for child in node.get_children():
		_fade(child)
			
func _unfade(node):
	if _can_fade(node):
		node.modulate.a = 1

	for child in node.get_children():
		_unfade(child)
			
func _can_fade(node):
	return node is CanvasItem
