extends "res://tests/godot/test_case.gd"

## Storybook mammal coats must stay lit. An unlit Sketchfab coat ignores the
## night cycle and reads as a glowing animal beside darkened buildings.


func test_mammal_coats_receive_scene_lighting() -> void:
	for id: String in ["forge_cat", "sheep", "dog", "pig", "goat", "boar", "fox", "hare", "rat", "cow", "cow_holstein"]:
		var model := (load("res://assets/storybook/%s/%s.glb" % [id, id]) as PackedScene).instantiate()
		var found_coat := false
		for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			for surface: int in mesh.mesh.get_surface_count():
				var material := mesh.mesh.surface_get_material(surface)
				assert_true(
					material is StandardMaterial3D,
					"%s coat must import as StandardMaterial3D" % id
				)
				var std := material as StandardMaterial3D
				assert_ne(
					std.shading_mode,
					BaseMaterial3D.SHADING_MODE_UNSHADED,
					"%s must receive night lighting" % id
				)
				assert_false(std.emission_enabled, "%s must not self-illuminate" % id)
				found_coat = true
		assert_true(found_coat, "%s needs a coat mesh" % id)
		model.free()
