extends "res://tests/godot/test_case.gd"

## R-1734 oblique swash (docs/SYSTEMS/CITY_SEA.md "Oblique swash and longshore drift"):
## an oblique onshore wind turns the city swash crests by a world-space alongshore phase
## (Snell's conserved slowness), slewed on the ocean clock, and drives a longshore
## current that carries the surf foam along the beach.

const Surface := preload("res://scripts/city/city_water_surface.gd")
const ShoreField := preload("res://scripts/city/city_shore_field.gd")
const ShoreMaterials := preload("res://scripts/map/view3d/map_view_shore_materials.gd")
const SWASH := "res://scripts/map/view3d/shore_swash.gdshaderinc"
const FOAM_STEP := "res://scripts/map/view3d/water_foam_sim.gdshader"
const NORMAL_DEG := 30.0


func _normal() -> Vector2:
	return Vector2(sin(deg_to_rad(NORMAL_DEG)), cos(deg_to_rad(NORMAL_DEG)))


## Straight beach whose depth contours run at 30 degrees to the grid (land along +normal).
func _oblique_plan() -> CityPlan:
	var plan := CityPlan.new()
	plan._nx = 121
	plan._ny = 121
	plan._cell = 2.0
	plan._origin = Vector2(-120.0, -200.0)
	plan.bounds = Rect2(plan._origin, Vector2(240.0, 240.0))
	for j in plan._ny:
		for i in plan._nx:
			var p := plan._origin + Vector2(i, j) * plan._cell
			plan._heights.append(maxf(p.dot(_normal()) * 0.04, -6.0))
	return plan


func _material(along: Vector4) -> ShaderMaterial:
	var material := MapViewMaterials.water_surface(MapTypes.TERRAIN_SHALLOW_WATER).duplicate()
	material.set_shader_parameter("shore_sea_state", 0.95)
	material.set_shader_parameter("shore_along_phase", along)
	return material


func test_slowness_follows_snell_and_only_onshore_winds() -> void:
	var n := _normal()
	var tangent := n.orthogonal()
	var c0 := ShoreMaterials.SWASH_DEEP_CELERITY
	assert_almost_eq(c0, 9.81 * (1638.4 / 182.0) / TAU, 0.0001, "deep-water celerity of the 9 s period")
	var oblique := (n + tangent).normalized()
	var p := ShoreMaterials.swash_along_slowness(oblique, n)
	assert_almost_eq(p.length(), sin(deg_to_rad(45.0)) / c0, 0.00001, "|p| = sin(theta0) / c0")
	assert_true(p.normalized().dot(tangent) > 0.9999, "p points along the downwind tangent")
	assert_almost_eq(p.dot(n), 0.0, 0.000001, "no onshore share")
	for wind: Vector2 in [n, tangent, -n, -n + tangent * 0.5]:
		assert_true(
			ShoreMaterials.swash_along_slowness(wind, n).length() < 0.000001,
			"shore-normal, alongshore and offshore winds keep the crests shore-normal: %s" % wind
		)
	assert_eq(ShoreMaterials.swash_along_slowness(oblique, Vector2.ZERO), Vector2.ZERO, "no beach normal")


func test_obliquity_is_slew_limited_on_the_ocean_clock() -> void:
	var n := _normal()
	var oblique := (n + n.orthogonal()).normalized()
	# Set the bed's normal and centre directly: apply_shore_bed would rebind the shared
	# materials' shore field for every later test.
	ShoreMaterials._along_normal = n
	ShoreMaterials._along_centre = Vector2(5.0, -7.0)
	OceanFftSampler.set_time_override(100.0)
	ShoreMaterials.settle_swash_obliquity()
	ShoreMaterials.apply_swash_obliquity(n)
	assert_eq(ShoreMaterials.swash_along_state(), Vector2.ZERO, "settled on a shore-normal wind")
	OceanFftSampler.set_time_override(102.0)
	ShoreMaterials.apply_swash_obliquity(oblique)
	assert_almost_eq(
		ShoreMaterials.swash_along_state().length(), 2.0 * ShoreMaterials.SWASH_ALONG_RATE, 1e-8,
		"two ocean seconds move p by two rate steps only"
	)
	var water := MapViewMaterials.water_surface(MapTypes.TERRAIN_SHALLOW_WATER)
	var bound: Vector4 = water.get_shader_parameter("shore_along_phase")
	assert_almost_eq(Vector2(bound.z, bound.w).distance_to(Vector2(5.0, -7.0)), 0.0, 0.0001, "centre bound")
	# A time skip (load) snaps to the target.
	OceanFftSampler.set_time_override(102.0 + ShoreMaterials.SWASH_ALONG_SNAP_GAP + 1.0)
	ShoreMaterials.apply_swash_obliquity(oblique)
	assert_true(
		ShoreMaterials.swash_along_state().distance_to(ShoreMaterials.swash_along_slowness(oblique, n))
			< 1e-8,
		"a clock gap snaps to the target"
	)
	# No dominant normal (district maps): the swash stays shore-normal.
	ShoreMaterials._along_normal = Vector2.ZERO
	ShoreMaterials._along_centre = Vector2.ZERO
	ShoreMaterials.settle_swash_obliquity()
	ShoreMaterials.apply_swash_obliquity(oblique)
	assert_eq(water.get_shader_parameter("shore_along_phase"), Vector4.ZERO, "district: shore-normal swash")
	OceanFftSampler.clear_time_override()


func test_bake_finds_the_dominant_beach_normal() -> void:
	var shore := ShoreField.bake(_oblique_plan())
	var normal: Vector2 = shore["along_normal"]
	assert_almost_eq(normal.length(), 1.0, 0.0001, "unit normal")
	assert_true(
		absf(rad_to_deg(normal.angle_to(_normal()))) < 3.0,
		"normal points towards land: %.1f deg off" % rad_to_deg(normal.angle_to(_normal()))
	)
	var centre: Vector2 = shore["along_centre"]
	assert_true(absf(centre.dot(_normal())) < 6.0, "centroid sits on the beach band")
	assert_true(float(shore["along_extent"]) > 50.0, "band extent measured")


func test_city_frequency_shift_stays_small_while_the_wind_turns() -> void:
	var shore := ShoreField.bake(CityPlan.load_default())
	var extent := float(shore["along_extent"])
	assert_true(extent > 100.0, "the city has a beach band")
	# While p slews, the wave frequency at a point moves by rate * distance from centre.
	assert_true(
		ShoreMaterials.SWASH_ALONG_RATE * extent < 0.03,
		"frequency shift %.3f at the far end of the beach" % (ShoreMaterials.SWASH_ALONG_RATE * extent)
	)


func test_cpu_mirror_adds_the_alongshore_phase_and_keeps_the_wrap() -> void:
	var shore := ShoreField.bake(_oblique_plan())
	var n := _normal()
	var p := ShoreMaterials.swash_along_slowness((n + n.orthogonal()).normalized(), n)
	var centre: Vector2 = shore["along_centre"]
	var plain := _material(Vector4.ZERO)
	var turned := _material(Vector4(p.x, p.y, centre.x, centre.y))
	var wrap := MapViewRuntimeEnvironment.OCEAN_TIME_WRAP_SECONDS
	for offset: float in [-40.0, 0.0, 30.0]:
		var xz := centre - n * 6.0 + n.orthogonal() * offset
		var a := float(Surface.bed_state(shore, xz, 7.0, plain)["cycle"])
		var b := float(Surface.bed_state(shore, xz, 7.0, turned)["cycle"])
		assert_almost_eq(a - b, p.dot(xz - centre) / Surface.PERIOD, 0.0001, "delay p.(x - c) at %d" % int(offset))
		var wrapped := float(Surface.bed_state(shore, xz, 7.0 + wrap, turned)["cycle"])
		assert_almost_eq(wrapped - b, 182.0, 0.001, "whole waves per ocean_time wrap")
	# Crests: a quarter of the alongshore wavelength T / |p| downwind lags a quarter
	# cycle (a whole wavelength, ~180 m, leaves this 240 m test coast).
	var lambda_along := Surface.PERIOD / p.length()
	var here := centre - n * 6.0
	var there := here + p.normalized() * lambda_along * 0.25
	var da := float(Surface.bed_state(shore, here, 3.0, turned)["cycle"]) \
		- float(Surface.bed_state(shore, here, 3.0, plain)["cycle"])
	var db := float(Surface.bed_state(shore, there, 3.0, turned)["cycle"]) \
		- float(Surface.bed_state(shore, there, 3.0, plain)["cycle"])
	assert_almost_eq(da - db, 0.25, 0.001, "a quarter cycle per quarter alongshore wavelength")


func test_longshore_current_is_in_the_longuet_higgins_range() -> void:
	var p := sin(deg_to_rad(45.0)) / ShoreMaterials.SWASH_DEEP_CELERITY
	var gale := Surface.longshore_speed(0.95, 1.0, 2.0, p)
	var breeze := Surface.longshore_speed(0.5, 1.0, 2.0, p)
	assert_true(gale > 0.3 and gale < 1.0, "gale at 45 deg: %.2f m/s" % gale)
	assert_true(breeze > 0.2 and breeze < gale, "fresh breeze drifts slower: %.2f m/s" % breeze)
	assert_eq(Surface.longshore_speed(0.95, 1.0, 2.0, 0.0), 0.0, "no obliquity, no current")


func test_shader_constants_and_hooks_match_the_mirror() -> void:
	var swash := FileAccess.get_file_as_string(SWASH)
	assert_true(swash.contains("uniform vec4 shore_along_phase = vec4(0.0);"), "uniform declared, off by default")
	assert_true(
		swash.contains("dot(shore_along_phase.xy, world_xz - shore_along_phase.zw)"),
		"bed-mode cycle carries the alongshore delay"
	)
	assert_true(swash.contains("const float LONGSHORE_K = %s;" % Surface.LONGSHORE_K), "LONGSHORE_K mirrored")
	var step := FileAccess.get_file_as_string(FOAM_STEP)
	assert_true(step.contains("current = shore_longshore_current(s);"), "foam step reads the current")
	assert_true(step.contains("_state_bilinear(vec2(p) + 0.5 - upstream)"), "foam advected upstream")
