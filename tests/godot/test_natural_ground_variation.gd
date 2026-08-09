extends "res://tests/godot/test_case.gd"

## Natural ground keeps the authored grass plate, but must not expose its short
## repeat as a regular checkerboard from the gameplay camera.


func test_natural_ground_shader_uses_continuous_variation() -> void:
	var material := MapViewMaterials.blended_ground(731)
	var shader := material.shader
	assert_true(shader != null, "blended ground must have a shader")
	assert_true(
		shader.code.contains("sample_natural_ground") and shader.code.contains("natural_warp"),
		"grass sampling must use continuous world-space variation"
	)
	assert_true(
		shader.code.contains("natural_ground_variation"),
		"natural ground variation must be an explicit material control"
	)
	assert_eq(material.get_shader_parameter("natural_ground_variation"), 0.72)


func test_natural_ground_variation_is_applied_to_all_grass_family_layers() -> void:
	var shader_source := MapViewMaterialShaders.TERRAIN_BLEND_SHADER_CODE
	assert_true(shader_source.contains("layer >= 0 && layer <= 3"), "grass, meadow, forest floor, and bog share the varied sampler")
	assert_true(shader_source.contains("natural_ground_uv_scale"), "natural ground keeps the authored repeat control")
