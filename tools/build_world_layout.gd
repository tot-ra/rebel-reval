extends SceneTree

## WB-08 / R-980: build the checked-in `reval_outdoor` world-layout manifest.
##
##   godot --headless --path . --script tools/build_world_layout.gd            # write
##   godot --headless --path . --script tools/build_world_layout.gd -- --check # compare
##   godot --headless --path . --script tools/build_world_layout.gd -- --group=<id> [--check]
##
## No `--group` builds `reval_outdoor`. An unknown group id exits 1. A declared group
## with no members (`reval_hinterland` until UF-15) exits 0 and writes nothing.
##
## `--check` exits 1 when the checked-in file differs from a fresh build, so a map
## edit that moves a seam cannot ship with a stale manifest.


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var check := args.has("--check")
	var group_id := MapWorldLayout.DEFAULT_WORLD_GROUP_ID
	for arg in args:
		if arg.begins_with("--group="):
			group_id = StringName(arg.trim_prefix("--group="))
	var group := MapWorldLayout.group_entry(group_id)
	if group.is_empty():
		printerr("%s unknown world group: %s" % [MapWorldLayout.DIAG_GROUP_UNKNOWN, group_id])
		quit(1)
		return
	var members: Array = group["members"]
	if members.is_empty():
		print("world group %s declares no members; nothing to build" % group_id)
		quit(0)
		return
	var registry_errors := MapWorldLayout.validate_registry()
	for error in registry_errors:
		printerr("error: %s" % error)
	var compiled := MapWorldLayout.compile_members(members)
	for error in compiled["errors"]:
		push_error(error)
	var manifest := MapWorldLayout.build_manifest(
		compiled["definitions"],
		members,
		StringName(group["root_location_id"]),
		group_id,
		compiled["sources"]
	)
	var text := MapWorldLayout.manifest_file_text(manifest)
	var path := String(group["manifest_path"])
	for warning in manifest["warnings"]:
		print("warning: %s" % warning)
	for error in manifest["errors"]:
		printerr("error: %s" % error)
	var exit_code := (
		0
		if bool(manifest["valid"]) and compiled["errors"].is_empty() and registry_errors.is_empty()
		else 1
	)
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
