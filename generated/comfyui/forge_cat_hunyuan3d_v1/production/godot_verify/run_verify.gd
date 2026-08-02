extends SceneTree

const VERIFY_SCENE := "res://generated/comfyui/forge_cat_hunyuan3d_v1/production/godot_verify/verify.tscn"

func _initialize() -> void:
	var packed := load(VERIFY_SCENE) as PackedScene
	if packed == null:
		push_error("Could not load forge-cat verification scene: " + VERIFY_SCENE)
		quit(1)
		return
	root.add_child(packed.instantiate())
