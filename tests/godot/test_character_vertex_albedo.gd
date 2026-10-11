extends "res://tests/godot/test_case.gd"

## P0-189: COLOR_0 fibre/strand tints must reach albedo. ADR 0022 bakes
## complexion into the skin map, so Anatomy_Head may have no vertex tint.

const KALEV_SCENE := preload("res://assets/characters/kalev/kalev.tscn")
const HENNING_SCENE := preload("res://assets/characters/variants/henning.tscn")
const TOWNSWOMAN_SCENE := preload("res://assets/characters/variants/townswoman.tscn")


func test_kalev_beard_vertex_tint_reaches_albedo() -> void:
	_assert_tinted_surfaces_use_albedo(KALEV_SCENE, "Kalev")
	_assert_named_surface_carries_tint(KALEV_SCENE, "Hair_Beard")


func test_henning_beard_vertex_tint_reaches_albedo() -> void:
	_assert_tinted_surfaces_use_albedo(HENNING_SCENE, "Henning")
	_assert_named_surface_carries_tint(HENNING_SCENE, "Hair_Beard")


func test_townswoman_tinted_surfaces_use_albedo() -> void:
	_assert_tinted_surfaces_use_albedo(TOWNSWOMAN_SCENE, "Townswoman")


func _assert_tinted_surfaces_use_albedo(scene: PackedScene, label: String) -> void:
	var rig := _instantiate(scene)
	for found: Node in rig.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := found as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface: int in mesh_instance.mesh.get_surface_count():
			if not SharedCharacterRig.surface_carries_vertex_tint(
				mesh_instance.mesh, surface
			):
				continue
			var material := mesh_instance.get_active_material(surface) as BaseMaterial3D
			assert_true(
				material != null and material.vertex_color_use_as_albedo,
				"%s %s surface %d must multiply COLOR_0" % [
					label, mesh_instance.name, surface
				]
			)
	_free_rig(rig)


func _assert_named_surface_carries_tint(scene: PackedScene, mesh_name: String) -> void:
	var rig := _instantiate(scene)
	var mesh_instance := _mesh(rig, mesh_name)
	assert_true(mesh_instance != null, "missing %s" % mesh_name)
	assert_true(
		SharedCharacterRig.surface_carries_vertex_tint(mesh_instance.mesh, 0),
		"%s COLOR_0 must be a non-white strand tint" % mesh_name
	)
	var material := mesh_instance.get_active_material(0) as BaseMaterial3D
	assert_true(material.vertex_color_use_as_albedo)
	_free_rig(rig)


func _instantiate(scene: PackedScene) -> SharedCharacterRig:
	var rig := scene.instantiate() as SharedCharacterRig
	(Engine.get_main_loop() as SceneTree).root.add_child(rig)
	return rig


func _free_rig(rig: SharedCharacterRig) -> void:
	SharedCharacterRig._detach_render_geometry(rig)
	rig.free()


func _mesh(rig: SharedCharacterRig, mesh_name: String) -> MeshInstance3D:
	for found: Node in rig.find_children("*", "MeshInstance3D", true, false):
		if String(found.name) == mesh_name:
			return found as MeshInstance3D
	return null
