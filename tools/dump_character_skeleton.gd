extends SceneTree

## Debug dump of the shared rig skeleton rest layout (bone parents, rest
## origins, global rest heights) used when calibrating proportion constants.
## godot --headless --path . --script tools/dump_character_skeleton.gd

const KALEV_SCENE := preload("res://assets/characters/kalev/kalev.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var rig: SharedCharacterRig = KALEV_SCENE.instantiate()
	root.add_child(rig)
	await process_frame
	var skeleton := rig.skeleton()
	if skeleton == null:
		push_error("No skeleton found")
		quit(1)
		return
	for bone_index in skeleton.get_bone_count():
		var parent := skeleton.get_bone_parent(bone_index)
		var parent_name := skeleton.get_bone_name(parent) if parent >= 0 else "-"
		var rest := skeleton.get_bone_rest(bone_index)
		var global_rest := skeleton.get_bone_global_rest(bone_index)
		print("%-24s parent=%-16s rest_origin=%s global_y=%.4f" % [
			skeleton.get_bone_name(bone_index),
			parent_name,
			rest.origin,
			global_rest.origin.y,
		])
	quit(0)
