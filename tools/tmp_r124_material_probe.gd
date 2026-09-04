extends SceneTree

const KALEV_SCENE := preload("res://assets/characters/kalev/kalev.tscn")
const HENNING_SCENE := preload("res://assets/characters/variants/henning.tscn")


func _init() -> void:
	var root := Node3D.new()
	root.name = "ProbeRoot"
	root.add_child(KALEV_SCENE.instantiate())
	root.add_child(HENNING_SCENE.instantiate())
	root.call_deferred("_probe", root)
	root.call_deferred("_quit")
	root.set_meta("probe_tree", self)


func _probe(root: Node3D) -> void:
	for character: Node in root.get_children():
		print("CHARACTER ", character.name)
		for found: Node in character.get_node("Model").find_children(
			"*", "MeshInstance3D", true, false
		):
			var mesh_instance := found as MeshInstance3D
			if mesh_instance.mesh == null:
				continue
			for surface_index: int in mesh_instance.mesh.get_surface_count():
				var source := mesh_instance.mesh.surface_get_material(surface_index)
				var active := mesh_instance.get_active_material(surface_index)
				if source == null:
					continue
				print(
					"  ",
					mesh_instance.name,
					"[",
					surface_index,
					"] source=",
					source.resource_name,
					" type=",
					source.get_class(),
					" active=",
					active.get_class() if active != null else "null"
				)
				if active is BaseMaterial3D:
					var material := active as BaseMaterial3D
					print(
						"    profile=",
						SharedCharacterRig.CHARACTER_PBR_MATERIAL_PROFILES.get(
							StringName(source.resource_name), {}
						),
						" rough=",
						material.roughness,
						" metal=",
						material.metallic,
						" shade=",
						material.shading_mode
					)


func _quit() -> void:
	quit()
