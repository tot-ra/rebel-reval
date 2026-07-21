extends Node

## Minimal MapViewRuntime stand-in for talk-glyph height resolution tests.

var _actor_rigs: Dictionary = {}


func register_actor_rig(actor: Node2D, rig: SharedCharacterRig) -> void:
	_actor_rigs[actor] = rig


func get_actor_rig(actor: Node2D) -> SharedCharacterRig:
	if actor == null:
		return null
	return _actor_rigs.get(actor) as SharedCharacterRig
