extends "res://tests/godot/test_case.gd"

## Night lighting of the seamless city (docs/SYSTEMS/NIGHT_LIGHTING.md): the night
## fill follows the moon and the snow, lived-in windows carry a glow card for the
## household schedule, and the night watch's lantern burns only in the dark.

const Lighting := preload("res://scripts/map/view3d/map_view_lighting.gd")


func test_night_fill_follows_moon_and_snow() -> void:
	var moonless := Lighting.night_ambient_energy(0.0, 0.0)
	var full := Lighting.night_ambient_energy(1.0, 0.0)
	var full_snow := Lighting.night_ambient_energy(1.0, 1.0)
	assert_true(moonless < full, "a full moon lifts the night fill")
	assert_true(full < full_snow, "snow throws the moonlight back up")
	assert_true(
		Lighting.night_ambient_energy(0.0, 1.0) - moonless < full_snow - full,
		"snow gains less on a moonless night"
	)
	# Compare radiance, not energy: the night fill colour is a dark blue.
	var night_radiance := full_snow * Lighting.AMBIENT_NIGHT_COLOR.srgb_to_linear().get_luminance()
	var day_color := Lighting.AMBIENT_GROUND_BOUNCE_COLOR.srgb_to_linear()
	var day_radiance := Lighting.AMBIENT_DAY_ENERGY * day_color.get_luminance()
	assert_true(night_radiance < day_radiance * 0.5, "moonlit snow stays far below day")


func test_night_street_gain_stays_below_the_day_gain() -> void:
	assert_true(Lighting.outdoor_exposure_gain(0.0) > 1.0, "night streets get a gain too")
	assert_true(Lighting.outdoor_exposure_gain(0.0) < Lighting.outdoor_exposure_gain(1.0))


func _window(look: Dictionary) -> CityBuildingBuilder.Shell:
	var shell := CityBuildingBuilder.Shell.new()
	CityWindows.add_window(
		shell, Vector2(3, 4), Vector2.RIGHT, Vector2.DOWN, 1.0, 0.7, &"plain", look, 0.5
	)
	return shell


func test_lived_in_window_gets_a_glow_card_with_house_inputs() -> void:
	var look := CityWindows.look(RandomNumberGenerator.new(), &"plank", 1)
	assert_false(
		_window(look).surfaces.has("window_glow"), "a house without a household stays dark"
	)
	look["glow"] = Color(0.25, 0.5, 0.0, 1.0)
	var shell := _window(look)
	assert_true(shell.surfaces.has("window_glow"), "a lived-in house gets the glow card")
	var card: CityBuildingBuilder.Surf = shell.surfaces["window_glow"]
	assert_eq(card.verts.size(), 6, "one quad")
	assert_almost_eq(card.colors[0].r, 0.25, 0.001, "house schedule shift rides in red")
	assert_almost_eq(card.colors[0].g, 0.5, 0.001, "wealth tier rides in green")
	assert_almost_eq(card.colors[0].a, 1.0, 0.001, "alpha marks a household")
	# Behind the wall face (the outward normal is +Z here, Vector2.DOWN = (0, 1)).
	assert_true(card.verts[0].z < 4.0, "the card sits inside the opening")
	assert_true(card.normals[0].z > 0.9, "the card faces the street")
	assert_true(
		CityBuildingBuilder.material_for_key("window_glow") is ShaderMaterial,
		"the card has its own additive material"
	)


func test_watch_lantern_burns_only_in_the_dark() -> void:
	var lantern := WatchLantern.new()
	lantern.apply_cycle_progress(0.5)
	assert_false(lantern.lit, "no lantern at noon")
	lantern.apply_cycle_progress(0.0)
	assert_true(lantern.lit, "lit at midnight")
	assert_true(lantern.is_in_group(&"city_cycle_lights"), "the city clock drives it")
	var omni := lantern.get_node("Omni") as OmniLight3D
	assert_true(omni.visible and not omni.shadow_enabled, "an unshadowed candle light")
	lantern.free()


## Regression: the left-hand mount once stood the lantern on its head, inside the sleeve,
## so a guard glowed with no lantern in sight. Lit, it hangs plumb under any fist.
func test_watch_lantern_hangs_plumb_from_a_tilted_fist() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var fist := Node3D.new()
	tree.root.add_child(fist)
	fist.rotation = Vector3(0.4, 1.1, PI * 0.8)
	var lantern := WatchLantern.new()
	fist.add_child(lantern)
	lantern.apply_cycle_progress(0.0)
	lantern._process(0.016)
	var omni := lantern.get_node("Omni") as Node3D
	assert_true(
		omni.global_position.y < lantern.global_position.y - 0.1,
		"the horn body hangs below the bail"
	)
	assert_true(lantern.global_basis.y.normalized().dot(Vector3.UP) > 0.999, "plumb")
	fist.free()
