extends SceneTree

const KALEV_SCENE := preload("res://assets/characters/kalev/kalev.tscn")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var rig := KALEV_SCENE.instantiate()
	root.add_child(rig)
	await process_frame
	for found: Node in rig.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := found as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface_index: int in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.get_active_material(surface_index)
			print("MATERIAL object=%s surface=%d type=%s material=%s albedo=%s texture=%s normal=%s roughness=%s" % [
				mesh_instance.name,
				surface_index,
				material.get_class() if material != null else "null",
				material.resource_name if material != null else "null",
				material.albedo_color if material is BaseMaterial3D else "n/a",
				material.albedo_texture.resource_path if material is BaseMaterial3D and material.albedo_texture != null else "none",
				material.normal_texture.resource_path if material is BaseMaterial3D and material.normal_texture != null else "none",
				material.roughness if material is BaseMaterial3D else "n/a",
			])
	rig.queue_free()
	await process_frame
	quit(0)
