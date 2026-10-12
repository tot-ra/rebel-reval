extends "res://tests/godot/test_case.gd"

## R-1907: the walking speed table per ground surface (docs/SYSTEMS/SEAMLESS_CITY.md,
## "Ground speed"). Pins the user-chosen numbers so a tweak is a deliberate edit.

const SurfaceSpeed := preload("res://scripts/player/surface_speed.gd")


func test_table_matches_the_agreed_fractions() -> void:
	assert_eq(SurfaceSpeed.PAVED, 1.0)
	assert_almost_eq(SurfaceSpeed.DRY_EARTH, 0.95, 0.0001)
	assert_almost_eq(SurfaceSpeed.GRASS, 0.85, 0.0001)
	assert_almost_eq(SurfaceSpeed.WET_MUD, 0.6, 0.0001)
	assert_almost_eq(SurfaceSpeed.SNOW_SHALLOW, 0.8, 0.0001)
	assert_almost_eq(SurfaceSpeed.SNOW_DEEP, 0.3, 0.0001)
	assert_almost_eq(SurfaceSpeed.WADE_DEEP, 0.15, 0.0001)


func test_soft_ground_runs_from_dry_to_soaked() -> void:
	assert_almost_eq(SurfaceSpeed.soft_ground(0.0), SurfaceSpeed.DRY_EARTH, 0.0001)
	assert_almost_eq(SurfaceSpeed.soft_ground(1.0), SurfaceSpeed.WET_MUD, 0.0001)
	var half := SurfaceSpeed.soft_ground(0.5)
	assert_true(half < SurfaceSpeed.DRY_EARTH and half > SurfaceSpeed.WET_MUD)
	assert_almost_eq(SurfaceSpeed.soft_ground(-1.0), SurfaceSpeed.DRY_EARTH, 0.0001)
	assert_almost_eq(SurfaceSpeed.soft_ground(2.0), SurfaceSpeed.WET_MUD, 0.0001)


func test_city_paving_is_free_and_earth_gets_slower_when_wet() -> void:
	var plan := CityPlan.load_default()
	var sampler := CitySurfaceSampler.new(plan)
	var paved := Vector2.INF
	var earth := Vector2.INF
	var y := plan.bounds.position.y
	while y < plan.bounds.end.y and (paved == Vector2.INF or earth == Vector2.INF):
		var x := plan.bounds.position.x
		while x < plan.bounds.end.x:
			var p := Vector2(x, y)
			if plan.building_at(p) < 0 and plan.site_at(p) == null:
				var surface := sampler.ground_surface(p)
				if paved == Vector2.INF and surface == SurfaceResolver.SURFACE_STONE:
					if sampler.soft_ground_drag(p, 1.0) > 0.999:
						paved = p
				if earth == Vector2.INF and surface == SurfaceResolver.SURFACE_DIRT:
					if sampler.soft_ground_drag(p, 0.0) < 0.951:
						earth = p
			x += 7.0
		y += 7.0
	assert_true(paved != Vector2.INF, "found fully paved ground")
	assert_true(earth != Vector2.INF, "found bare packed earth")
	assert_almost_eq(sampler.soft_ground_drag(earth, 0.0), SurfaceSpeed.DRY_EARTH, 0.03)
	assert_true(
		sampler.soft_ground_drag(earth, 1.0) < sampler.soft_ground_drag(earth, 0.0) - 0.2,
		"soaked earth is much slower than dry"
	)


func test_city_wading_slows_without_a_terrain_grid() -> void:
	# The seamless city has no MapTerrainGrid; wading must still drag (R-1907 fix).
	var player = preload("res://scripts/player.gd").new()
	player.set_water_depth_provider(func(_logic: Vector2) -> float: return 1.0)
	player._update_water(0.016)
	assert_eq(player.water_medium(), PlayerSwimState.Medium.WADE)
	assert_true(player.terrain_speed_multiplier() < 0.4, "throat-deep water drags hard")
	player.free()
