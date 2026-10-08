extends "res://tests/godot/test_case.gd"

## R-1400: discrete world-space clouds, their ground shadows, and storm-cell lightning.

const CloudCellsScript := preload("res://scripts/map/view3d/cloud_cells.gd")
const SkyWeather := preload("res://scripts/map/view3d/sky_weather_3d.gd")
const CLOUD_SHADOW_SHADER := preload("res://scripts/map/view3d/cloud_shadow_pass.gdshader")
const GOD_RAY_SHADER := preload("res://scripts/map/view3d/god_ray_pass.gdshader")


func test_cell_field_is_a_pure_function_of_clock_drift_and_counts() -> void:
	var a := CloudCellsScript.new()
	var b := CloudCellsScript.new()
	a.update(123.4, Vector2(0.03, -0.01), Vector2(6.5, 1.2))
	b.update(123.4, Vector2(0.03, -0.01), Vector2(6.5, 1.2))
	assert_eq(a.uniforms(), b.uniforms(), "same inputs must rebuild the same cells")
	assert_eq(a.uniforms().size(), CloudCellsScript.SLOTS * 2, "two vec4 per slot")


func test_weather_decides_how_many_cells_show() -> void:
	var clear := CloudCellsScript.counts_for(0.30, 0.0)
	var cloudy := CloudCellsScript.counts_for(0.66, 0.16)
	var storm := CloudCellsScript.counts_for(0.40, 1.0)
	assert_true(clear.x >= 3.0 and clear.x < cloudy.x, "fair weather shows a few cumulus")
	assert_eq(clear.y, 0.0, "a clear sky grows no thunderhead")
	assert_eq(cloudy.y, 0.0, "plain cloud cover grows no thunderhead")
	assert_true(storm.y >= 2.0, "a storm grows cumulonimbus cells")


func test_cells_drift_with_the_shared_cloud_offset() -> void:
	var cells := CloudCellsScript.new()
	cells.update(10.0, Vector2.ZERO, Vector2(13.0, 0.0))
	var before: Vector3 = cells.centers[0]
	cells.update(10.0, Vector2(0.01, 0.0), Vector2(13.0, 0.0))
	var after: Vector3 = cells.centers[0]
	var moved := CloudCellsScript.wrap_delta(Vector2(after.x, after.z), Vector2(before.x, before.z))
	assert_almost_eq(moved.x, 0.01 * CloudCellsScript.METRES_PER_UV, 0.01, "cells move with the wind")
	assert_almost_eq(moved.y, 0.0, 0.01, "drift has no cross component here")


func test_cells_live_grow_and_dissipate() -> void:
	var cells := CloudCellsScript.new()
	var seen_born := false
	var seen_full := false
	for step in 400:
		cells.update(float(step) * 0.5, Vector2.ZERO, Vector2(1.0, 0.0))
		var w: float = cells.weights[0]
		if w < 0.05:
			seen_born = true
		if w > 0.95:
			seen_full = true
	assert_true(seen_born and seen_full, "a cell must appear, mature, and fade over its life")


func test_a_cell_shadows_the_ground_under_it_along_the_sun() -> void:
	var cells := CloudCellsScript.new()
	cells.update(0.0, Vector2.ZERO, Vector2(1.0, 0.0))
	# Pin slot 0 mid-life so the test does not depend on the hashed phase.
	cells.weights[0] = 1.0
	cells.centers[0] = Vector3(1000.0, 700.0, 1000.0)
	cells.radii[0] = 300.0
	cells.heights[0] = 300.0
	var sun := Vector3(0.5, 0.8, 0.0).normalized()
	var layer: float = 700.0 + 300.0 * 0.35
	# Ground point whose sun ray passes through the cell centre at its shadow layer.
	var under := Vector3(1000.0 - sun.x / sun.y * layer, 0.0, 1000.0)
	assert_true(cells.shadow_at(under, sun) > 0.7, "the ground under a cumulus is shadowed")
	assert_true(
		cells.shadow_at(Vector3(1000.0, 0.0, 1000.0) + Vector3(0.0, 0.0, 900.0), sun) < 0.05,
		"ground well beside the cloud stays in sun"
	)
	# The shadow follows the sun, not the point straight below the cloud.
	assert_true(
		cells.shadow_at(under, sun) > cells.shadow_at(Vector3(1600.0, 0.0, 1000.0), sun),
		"a low sun throws the shadow away from the point under the cloud"
	)


func test_wrap_delta_takes_the_nearest_periodic_copy() -> void:
	var d := CloudCellsScript.wrap_delta(
		Vector2(10.0, 0.0), Vector2(CloudCellsScript.DOMAIN - 10.0, 0.0)
	)
	assert_almost_eq(d.x, 20.0, 0.001, "a cell across the seam is 20 units away, not a domain")


func test_lightning_is_born_only_in_a_mature_storm_cell() -> void:
	var sky = SkyWeather.new()
	sky.auto_weather = false
	sky.set_weather(SkyWeather.WEATHER_STORM)
	sky.advance(SkyWeather.TRANSITION_SECONDS)
	var strikes := 0
	var was_flashing := false
	for step in 3000:
		sky.advance(0.05)
		var flashing: bool = sky.lightning_flash() > 0.0
		if flashing and not was_flashing:
			strikes += 1
			var origin: Vector3 = sky.lightning_origin()
			var cells = sky.cloud_cells()
			var inside := false
			for slot in range(CloudCellsScript.CUMULUS_SLOTS, CloudCellsScript.SLOTS):
				var c: Vector3 = cells.centers[slot]
				var offset := CloudCellsScript.wrap_delta(
					Vector2(origin.x, origin.z), Vector2(c.x, c.z), CloudCellsScript.KIND_STORM
				)
				if (
					offset.length() <= float(cells.radii[slot]) * 0.5
					and origin.y >= c.y
					and origin.y <= c.y + float(cells.heights[slot])
					and float(cells.weights[slot]) >= CloudCellsScript.STORM_MATURE_WEIGHT
				):
					inside = true
			assert_true(inside, "every strike must start inside a charged cumulonimbus")
			if sky.lightning_kind() == SkyWeather.LIGHTNING_KIND_GROUND:
				assert_almost_eq(sky.lightning_ground().y, 0.0, 0.001, "a ground stroke ends on the ground")
		was_flashing = flashing
	assert_true(strikes >= 3, "a thunderstorm must keep striking from its cells")
	sky.free()


func test_no_storm_cell_means_no_lightning_even_with_thunder() -> void:
	var sky = SkyWeather.new()
	sky.auto_weather = false
	sky.advance(1.0)
	# Thunder without storm development: the profile asks for strikes, but no
	# cumulonimbus grows, so the sky must hold its charge instead of striking.
	sky._current[&"thunder"] = 1.0
	for step in 2000:
		sky.advance(0.05)
		assert_eq(sky.cloud_cells().max_weight(CloudCellsScript.KIND_STORM), 0.0, "no storm cells")
		assert_eq(sky.lightning_flash(), 0.0, "lightning must never strike without a storm cell")
	sky.free()


func test_cell_clock_and_strike_survive_save_and_load() -> void:
	var source = SkyWeather.new()
	source.auto_weather = false
	source.set_weather(SkyWeather.WEATHER_STORM)
	for step in 400:
		source.advance(0.05)
	var restored = SkyWeather.new()
	assert_true(restored.restore_state(source.snapshot_state().to_dict()), "state must restore")
	assert_almost_eq(
		restored.cloud_cell_clock(), source.cloud_cell_clock(), 0.0001, "cell clock persists"
	)
	assert_eq(
		restored.cloud_cells().uniforms(), source.cloud_cells().uniforms(), "cells rebuild exactly"
	)
	assert_eq(restored.lightning_origin(), source.lightning_origin(), "strike origin persists")
	assert_eq(restored.lightning_kind(), source.lightning_kind(), "strike kind persists")
	source.free()
	restored.free()


func test_sun_behind_a_cell_dims_the_sun_glint() -> void:
	var sky = SkyWeather.new()
	var cells = sky.cloud_cells()
	for slot in CloudCellsScript.SLOTS:
		cells.weights[slot] = 0.0
	var sun := Vector3(0.0, 0.8, -0.6).normalized()
	assert_almost_eq(sky.cells_clear_toward(sun), 1.0, 0.0001, "no cells: the sun is clear")
	cells.weights[0] = 1.0
	cells.radii[0] = 300.0
	cells.heights[0] = 300.0
	var layer := 700.0 + 300.0 * 0.35
	cells.centers[0] = Vector3(0.0, 700.0, sun.z / sun.y * layer)
	assert_true(sky.cells_clear_toward(sun) < 0.3, "a cell in front of the sun blocks it")
	sky.free()


func test_shaders_consume_the_cells() -> void:
	assert_true(
		"cells_ground_shadow" in CLOUD_SHADOW_SHADER.code, "ground shadows come from the cells"
	)
	assert_true("cells_ground_shadow" in GOD_RAY_SHADER.code, "god rays are cut by the cells")
	var sky_code: String = SkyWeather.SKY_SHADER.code
	assert_true("cells_volume" in sky_code, "the dome ray-marches the cells")
	assert_true("lightning_origin" in sky_code, "the bolt starts in its storm cell")
