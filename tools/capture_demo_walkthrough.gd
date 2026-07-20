extends SceneTree

## Compatibility wrapper. Prefer the host scene so autoloads resolve:
##   godot --path . res://tools/capture_demo_walkthrough_host.tscn
## This entry point only redirects for older docs that still pass --script.

func _initialize() -> void:
	call_deferred("_redirect")


func _redirect() -> void:
	push_warning(
		"tools/capture_demo_walkthrough.gd is a redirect; use res://tools/capture_demo_walkthrough_host.tscn"
	)
	change_scene_to_file("res://tools/capture_demo_walkthrough_host.tscn")
