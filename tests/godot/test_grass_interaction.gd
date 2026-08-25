extends "res://tests/godot/test_case.gd"

const MapViewMaterialShaders := preload("res://scripts/map/view3d/map_view_material_shaders.gd")


func test_grass_shader_declares_character_interaction_uniforms() -> void:
	var code := MapViewMaterialShaders.GRASS_SHADER_CODE
	assert_true(code.contains("interact_center"), "grass shader must sample character world XZ")
	assert_true(code.contains("interact_strength"), "grass shader must scale tip parting")
	assert_true(code.contains("interact_push"), "grass shader must lean with movement wake")
	assert_true(code.contains("interact_radius"), "grass shader must soft-falloff around the body")


func test_grass_interaction_uniforms_follow_character_motion() -> void:
	MapViewMaterials.apply_grass_interaction(Vector2(4.0, -2.5), Vector2(3.2, 0.0))
	var grass := MapViewMaterials.grass_blades()
	assert_eq(
		grass.get_shader_parameter("interact_center"),
		Vector2(4.0, -2.5),
		"interaction center must match the character ground point"
	)
	assert_eq(
		grass.get_shader_parameter("interact_push"),
		Vector2(1.0, 0.0),
		"push must normalize movement into a wake direction"
	)
	var moving_strength := float(grass.get_shader_parameter("interact_strength"))
	assert_true(moving_strength > 0.10, "walking must raise tip parting above the idle pocket")
	assert_true(moving_strength <= 0.22, "tip parting must stay capped for readable blades")

	MapViewMaterials.apply_grass_interaction(Vector2(1.0, 1.0), Vector2.ZERO)
	var idle_strength := float(grass.get_shader_parameter("interact_strength"))
	assert_true(idle_strength >= 0.10, "standing still must still open a soft pocket around the feet")
	assert_true(idle_strength < moving_strength, "idle parting must be weaker than a walking wake")
	assert_eq(
		grass.get_shader_parameter("interact_push"),
		Vector2.ZERO,
		"idle interaction must clear the wake direction"
	)

	MapViewMaterials.clear_grass_interaction()
	assert_eq(
		float(grass.get_shader_parameter("interact_strength")),
		0.0,
		"clear must disable character parting when no player drives the view"
	)


func test_map_view_scales_logic_velocity_into_world_grass_interaction() -> void:
	var definition := MapDefinition.new()
	definition.cell_size = MapTypes.DEFAULT_CELL_SIZE
	var view := MapView3D.new()
	view.definition = definition
	view.update_grass_interaction(Vector2(64.0, 96.0), Vector2(160.0, 0.0))
	var grass := MapViewMaterials.grass_blades()
	# 64 logic px / 32 cell size = 2 world units on X; Z mirrors logic Y.
	assert_eq(
		grass.get_shader_parameter("interact_center"),
		Vector2(2.0, 3.0),
		"logic pose must convert through MapViewBridge into grass world XZ"
	)
	assert_eq(
		grass.get_shader_parameter("interact_push"),
		Vector2(1.0, 0.0),
		"logic velocity must keep its heading after world scaling"
	)
	MapViewMaterials.clear_grass_interaction()
	view.free()
