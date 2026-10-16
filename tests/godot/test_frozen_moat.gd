extends "res://tests/godot/test_case.gd"

## Frozen inland water and wind-blown snow (docs/SYSTEMS/SEASONS.md): solid ice on
## the moat and stream carries Kalev, thin ice and open water do not; the snow on
## the ice is not swept by the live wind; dry snow drifts and blows in a wind.

## A pool of the raised Hareapea stream (test_city_water_realism.gd).
const POOL := Vector2(617.64, 294.69)


func _stream_world() -> CityWorld3D:
	var world := CityWorld3D.new()
	world.plan = CityPlan.load_default()
	var hj: Dictionary = world.plan.data["harjapea"]
	var trace := CityPlan.points(hj["points"])
	var halves := world._stream_wet_halves(trace, hj["widths"], hj["surfaces"])
	world._stream_water(trace, halves, hj["surfaces"])
	world.stream_segment_count = world.moat_water.size()
	world.lake_segment_end = world.moat_water.size()
	world.stream_material = world._stream_material()
	world.plan.ice_deck = world.ice_deck_at
	return world


func _done(world: CityWorld3D) -> void:
	# The plan is cached across tests: do not leave the hook behind.
	world.plan.ice_deck = Callable()
	world.free()


func test_open_water_is_waded() -> void:
	var world := _stream_world()
	var plan := world.plan
	world.fresh_ice = 0.0
	assert_true(is_nan(plan.ice_deck_height(POOL)), "no ice in summer")
	assert_almost_eq(plan.walk_height(POOL), plan.ground_height(POOL), 0.001)
	assert_true(world.water_surface_at(POOL) - plan.walk_height(POOL) > 0.2, "Kalev wades")
	_done(world)


func test_solid_ice_carries_kalev() -> void:
	var world := _stream_world()
	var plan := world.plan
	world.fresh_ice = 1.0
	var surface := world.water_surface_at(POOL)
	assert_almost_eq(plan.ice_deck_height(POOL), surface, 0.001)
	assert_almost_eq(plan.walk_height(POOL), surface, 0.001, "he stands on the ice")
	assert_almost_eq(maxf(surface - plan.walk_height(POOL), 0.0), 0.0, 0.001, "no water column")
	# Dry bank beside it is still the ground.
	var bank := POOL + Vector2(25.0, 0.0)
	assert_almost_eq(plan.walk_height(bank), plan.ground_height(bank), 0.001)
	_done(world)


func test_thin_ice_does_not_bear() -> void:
	var world := _stream_world()
	world.fresh_ice = CityWorld3D.ICE_BEARING - 0.05
	assert_true(is_nan(world.plan.ice_deck_height(POOL)), "a skin of ice breaks")
	# Freezing moving water lags: half-thick ice still leaves the deep run open.
	world.fresh_ice = 0.45
	var column := world.water_surface_at(POOL) - world.plan.ground_height(POOL)
	assert_eq(world.ice_bears(0, 0.05), true, "the shallows freeze first")
	assert_eq(world.ice_bears(0, 3.0), false, "deep running water stays open")
	assert_true(column > 0.0)
	# No blowing snow off water that is still open in its middle.
	world.fresh_ice = 0.36
	assert_true(is_nan(world.ice_level_near(POOL, 45.0)), "open water feeds no drift")
	world.fresh_ice = 1.0
	assert_false(is_nan(world.ice_level_near(POOL, 45.0)), "solid ice does")
	_done(world)


func test_footsteps_on_the_ice() -> void:
	var world := _stream_world()
	var plan := world.plan
	world.fresh_ice = 1.0
	var depth := func(xz: Vector2) -> float:
		return maxf(world.water_surface_at(xz) - plan.walk_height(xz), 0.0)
	var sampler := CitySurfaceSampler.new(plan, depth)
	var foot := Vector3(POOL.x, plan.walk_height(POOL), POOL.y)
	assert_eq(sampler.surface_at(foot, 0.0, 0.0, 0.8), SurfaceResolver.SURFACE_SNOW)
	assert_eq(sampler.surface_at(foot, 0.0, 0.0, 0.0), SurfaceResolver.SURFACE_STONE)
	assert_almost_eq(sampler.soft_ground_drag(POOL, 1.0), 1.0, 0.001, "no mud under the ice")
	_done(world)


## The snow on the ice used to follow the live wind heading; rotating its streaks
## about the world origin slid them across the moat like flowing water.
func test_snow_on_ice_ignores_the_live_wind() -> void:
	for path: String in [
		"res://scripts/city/city_moat_water.gdshader",
		"res://scripts/map/view3d/map_view_water.gdshader",
	]:
		var code := (load(path) as Shader).code
		var at := code.find("ice_look(")
		assert_true(at >= 0)
		var call := code.substr(at, 220)
		assert_true(call.contains("ICE_SNOW_DRIFT"), "%s drifts snow on a fixed heading" % path)


func test_blowing_snow_needs_wind_dry_snow_and_cover() -> void:
	var calm := CityBlowingSnow.strength(0.2, -8.0, 0.0, 0.0, 0.8)
	assert_almost_eq(calm.x + calm.y, 0.0, 0.001, "a breeze leaves the snow lying")
	var fresh := CityBlowingSnow.strength(0.6, -8.0, 0.0, 0.0, 0.8)
	assert_true(fresh.x > 0.9, "10 m/s streams dry snow along the ground")
	assert_true(fresh.y < 0.3, "but throws little of it overhead")
	var gale := CityBlowingSnow.strength(0.95, -8.0, 0.0, 0.0, 0.8)
	assert_true(gale.y > 0.9, "a gale raises a ground blizzard")
	var wet := CityBlowingSnow.strength(0.95, 0.5, 0.0, 0.0, 0.8)
	assert_almost_eq(wet.x + wet.y, 0.0, 0.001, "wet snow does not blow")
	var thaw := CityBlowingSnow.strength(0.95, -8.0, 1.0, 0.0, 0.8)
	assert_almost_eq(thaw.x + thaw.y, 0.0, 0.001, "a wet film binds it")
	var crust := CityBlowingSnow.strength(0.95, -8.0, 0.0, 1.0, 0.8)
	assert_true(crust.y < gale.y * 0.5, "a refrozen crust holds most of it")
	var bare := CityBlowingSnow.strength(0.95, -8.0, 0.0, 0.0, 0.02)
	assert_almost_eq(bare.x + bare.y, 0.0, 0.001, "no snow, nothing to blow")
