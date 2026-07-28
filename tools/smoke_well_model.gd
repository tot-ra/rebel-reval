extends SceneTree

## Quick compile/assembly smoke for the well prop: builds the prop headlessly
## and verifies the production model structure without the GPU renderer.

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var prop := MapViewMeshBuilder.build_prop(
		{"id": &"smoke_well", "kind": MapTypes.PROP_KIND_WELL, "position": Vector2.ZERO},
		MapTypes.DEFAULT_CELL_SIZE
	)
	if prop == null:
		push_error("WELL_SMOKE: build_prop returned null")
		quit(1)
		return
	root.add_child(prop)
	var model := prop.get_node_or_null("WellModel")
	if model == null:
		push_error("WELL_SMOKE: WellModel node missing")
		quit(1)
		return
	var required := ["Shaft", "Curb", "Water", "PostLeft", "PostRight", "Windlass", "RopeWrap", "CrankArm", "CrankHandle", "Rope", "Bucket", "BucketHandle", "RidgeBeam", "Roof"]
	for node_name in required:
		if model.get_node_or_null(node_name) == null:
			push_error("WELL_SMOKE: missing node %s" % node_name)
			quit(1)
			return
	var mesh_count := 0
	for child in model.get_children():
		if child is MeshInstance3D and child.mesh != null:
			mesh_count += 1
	print("WELL_SMOKE_OK meshes=%d" % mesh_count)
	quit(0)
