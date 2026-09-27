extends SceneTree

## WB-08 / R-980: build the checked-in `reval_outdoor` world-layout manifest.
##
##   godot --headless --path . --script tools/build_world_layout.gd            # write
##   godot --headless --path . --script tools/build_world_layout.gd -- --check # compare
##
## `--check` exits 1 when the checked-in file differs from a fresh build, so a map
## edit that moves a seam cannot ship with a stale manifest.


func _init() -> void:
	var check := OS.get_cmdline_user_args().has("--check")
	var compiled := MapWorldLayout.compile_members()
	for error in compiled["errors"]:
		push_error(error)
	var manifest := MapWorldLayout.build_manifest(
		compiled["definitions"],
		MapWorldLayout.REVAL_OUTDOOR_MEMBERS,
		&"lower_town_slice",
		MapWorldLayout.DEFAULT_WORLD_GROUP_ID,
		compiled["sources"]
	)
	var text := MapWorldLayout.manifest_file_text(manifest)
	var path := MapWorldLayout.REVAL_OUTDOOR_MANIFEST_PATH
	for warning in manifest["warnings"]:
		print("warning: %s" % warning)
	for error in manifest["errors"]:
		printerr("error: %s" % error)
	var exit_code := 0 if bool(manifest["valid"]) and compiled["errors"].is_empty() else 1
	if check:
		var current := FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
		if current != text:
			printerr("%s is stale; rerun tools/build_world_layout.gd" % path)
			exit_code = 1
		else:
			print("%s is current (%s)" % [path, manifest["fingerprint"]])
	else:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(text)
		file.close()
		print("wrote %s (%s)" % [path, manifest["fingerprint"]])
	quit(exit_code)
