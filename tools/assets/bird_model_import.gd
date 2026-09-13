@tool
extends EditorScenePostImport
## Preserve authored linear pigmentation with renderer-correct PBR shading.
const PLUMAGE_SHADER := preload("res://assets/storybook/bird_plumage.gdshader")

func _post_import(scene: Node) -> Object:
	for instance: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		for surface: int in instance.mesh.get_surface_count():
			var material := instance.mesh.surface_get_material(surface) as StandardMaterial3D
			if material == null:
				continue
			var imported := ShaderMaterial.new()
			imported.resource_name = material.resource_name
			imported.shader = PLUMAGE_SHADER
			imported.set_shader_parameter("base_color", material.albedo_color)
			imported.set_shader_parameter("albedo_map", material.albedo_texture)
			imported.set_shader_parameter("roughness_map", material.roughness_texture)
			imported.set_shader_parameter("roughness_value", material.roughness)
			var channel := Vector4.ZERO
			channel[material.roughness_texture_channel] = 1.0
			imported.set_shader_parameter("roughness_channel", channel)
			imported.set_shader_parameter("normal_map", material.normal_texture)
			imported.set_shader_parameter("normal_strength", material.normal_scale if material.normal_enabled else 0.0)
			instance.mesh.surface_set_material(surface, imported)
	return scene
