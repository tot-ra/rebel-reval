extends "res://tests/godot/test_case.gd"

const Capture := preload("res://tools/capture_character_closeup.gd")


func test_lighting_argument_defaults_to_day_and_accepts_both_presets() -> void:
	assert_eq(Capture.lighting_from_args([]), "day")
	assert_eq(Capture.lighting_from_args(["--scene=res://ignored.tscn"]), "day")
	assert_eq(Capture.lighting_from_args(["--lighting=day"]), "day")
	assert_eq(Capture.lighting_from_args(["--lighting=night"]), "night")


func test_invalid_lighting_is_rejected_instead_of_recapturing_day() -> void:
	for value: String in ["", "dusk", "DAY", "night=day"]:
		assert_eq(Capture.lighting_from_args(["--lighting=" + value]), "")


func test_default_stage_keeps_accepted_day_values() -> void:
	var stage := Capture.build_stage()
	var environment := (stage.get_child(0) as WorldEnvironment).environment
	var sun := stage.get_child(1) as DirectionalLight3D
	assert_eq(environment.background_color, Color(0.035, 0.047, 0.047))
	assert_eq(environment.ambient_light_color, Color(0.604, 0.678, 0.741))
	assert_almost_eq(environment.ambient_light_energy, 0.42, 0.00001)
	assert_eq(environment.tonemap_mode, Environment.TONE_MAPPER_FILMIC)
	assert_true(sun.rotation_degrees.is_equal_approx(Vector3(-48.0, -32.0, 0.0)))
	assert_eq(sun.light_color, Color(1.0, 0.86, 0.68))
	assert_true(is_equal_approx(sun.light_energy, 1.15))
	assert_true(sun.shadow_enabled)
	stage.free()


func test_night_changes_light_without_changing_geometry_or_direction() -> void:
	var day := Capture.build_stage("day")
	var night := Capture.build_stage("night")
	var day_environment := (day.get_child(0) as WorldEnvironment).environment
	var night_environment := (night.get_child(0) as WorldEnvironment).environment
	var day_sun := day.get_child(1) as DirectionalLight3D
	var night_sun := night.get_child(1) as DirectionalLight3D
	assert_true(night_environment.ambient_light_energy > 0.0)
	assert_true(night_environment.ambient_light_energy < day_environment.ambient_light_energy)
	assert_true(night_sun.light_energy > 0.0)
	assert_true(night_sun.light_energy < day_sun.light_energy)
	assert_true(night_sun.light_color.b > night_sun.light_color.r)
	assert_eq(night_sun.rotation, day_sun.rotation)
	assert_true(night_sun.shadow_enabled)
	var day_floor := day.get_child(2) as MeshInstance3D
	var night_floor := night.get_child(2) as MeshInstance3D
	assert_eq((night_floor.mesh as PlaneMesh).size, (day_floor.mesh as PlaneMesh).size)
	day.free()
	night.free()
