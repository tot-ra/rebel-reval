extends "res://tests/godot/test_case.gd"

const KALEV_SCENE := preload("res://assets/characters/kalev/kalev.tscn")
const RIG_SCENE := preload("res://assets/characters/shared/shared_character_rig.tscn")


# P0-146: skin zones get the wrap-lit skin shader, eye zones the catchlight shader, and no
# other zone may borrow either (a cloth surface must not turn into glossy skin).
func test_legacy_kalev_skin_and_eye_shaders_follow_zone_names() -> void:
	var kalev := _instantiate_legacy_kalev()
	var checked_skin := 0
	var checked_eye := 0
	for found: Node in kalev.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := found as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		for surface_index: int in mesh_instance.mesh.get_surface_count():
			var source_material := mesh_instance.mesh.surface_get_material(surface_index)
			if source_material == null:
				continue
			var material_name := StringName(source_material.resource_name)
			var active := mesh_instance.get_active_material(surface_index)
			var shader: Shader = null
			if active is ShaderMaterial:
				shader = (active as ShaderMaterial).shader
			if material_name in SharedCharacterRig.SKIN_MATERIAL_NAMES:
				assert_eq(
					shader,
					SharedCharacterRig.SKIN_MATERIAL_SHADER,
					"%s must use the skin shader" % material_name
				)
				checked_skin += 1
			elif material_name in SharedCharacterRig.EYE_MATERIAL_NAMES:
				assert_eq(
					shader,
					SharedCharacterRig.EYE_MATERIAL_SHADER,
					"%s must use the eye shader" % material_name
				)
				checked_eye += 1
			else:
				assert_true(
					shader != SharedCharacterRig.SKIN_MATERIAL_SHADER
					and shader != SharedCharacterRig.EYE_MATERIAL_SHADER,
					"%s is not a skin/eye zone and must not use those shaders" % material_name
				)
	assert_true(checked_skin > 0, "hero skin must use the skin shader")
	assert_true(checked_eye > 0, "hero eyes must use the eye shader")
	kalev.queue_free()


# Mirrors test_character_rig.gd: the legacy heroic_humanoid export still carries the
# named material zones that the shader binding keys on.
func _instantiate_legacy_kalev() -> SharedCharacterRig:
	var source := KALEV_SCENE.instantiate() as SharedCharacterRig
	var spec := source.variant
	source.free()
	var rig := RIG_SCENE.instantiate() as SharedCharacterRig
	var imported := rig.get_node("Model/ImportedHumanoid")
	rig.get_node("Model").remove_child(imported)
	imported.free()
	var model := load("res://assets/characters/shared/heroic_humanoid.glb").instantiate() as Node3D
	model.name = "ImportedHumanoid"
	rig.get_node("Model").add_child(model)
	rig.variant = spec
	(Engine.get_main_loop() as SceneTree).root.add_child(rig)
	return rig
