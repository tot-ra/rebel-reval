extends "res://tests/godot/test_case.gd"

## CitySurfaceSampler (R-1641): the seamless city has no terrain grid, so its
## footsteps read the plan's floors and land-use rasters. Points are found in
## the shipped plan rather than hard-coded, so a regenerated plan keeps the
## test meaningful.


func _plan() -> CityPlan:
	return CityPlan.load_default()


func _centroid(ring: PackedVector2Array) -> Vector2:
	var sum := Vector2.ZERO
	for p in ring:
		sum += p
	return sum / float(ring.size())


func _foot(xz: Vector2) -> Vector3:
	return Vector3(xz.x, 0.0, xz.y)


func _free_ground(plan: CityPlan, xz: Vector2) -> bool:
	return (
		plan.building_at(xz) < 0
		and plan.site_at(xz) == null
		and is_nan(plan.bridge_deck_height(xz))
		and not (plan.has_coast() and plan.ground_height(xz) < 1.5)
	)


func test_house_floor_is_wood_and_church_floor_is_stone() -> void:
	var plan := _plan()
	var sampler := CitySurfaceSampler.new(plan)
	var checked := {}
	for i in plan.buildings.size():
		var kind := String(plan.buildings[i].get("kind", ""))
		if checked.has(kind) or not kind in ["house", "church"]:
			continue
		var at := _centroid(plan.footprint(i))
		if plan.building_at(at) != i or plan.site_at(at) != null:
			continue
		var expected := (
			SurfaceResolver.SURFACE_STONE if kind == "church" else SurfaceResolver.SURFACE_WOOD
		)
		assert_eq(sampler.surface_at(_foot(at)), expected, "%s floor" % kind)
		checked[kind] = true
	assert_true(checked.has("house"), "the plan must have a free-standing house")


func test_bridge_deck_is_wood() -> void:
	var plan := _plan()
	var bridges: Array = plan.data.get("bridges", [])
	assert_false(bridges.is_empty(), "the plan must have a bridge")
	var at := Vector2(bridges[0]["at"][0], bridges[0]["at"][1])
	var sampler := CitySurfaceSampler.new(plan)
	assert_eq(sampler.surface_at(_foot(at)), SurfaceResolver.SURFACE_WOOD)


func test_smithy_floor_is_beaten_earth() -> void:
	var plan := _plan()
	var sampler := CitySurfaceSampler.new(plan)
	for site in plan.sites:
		if site.id != &"site.kalev_smithy" or site.floors.is_empty():
			continue
		var at := _centroid(site.floors[0]["polygon"])
		assert_eq(sampler.surface_at(_foot(at)), SurfaceResolver.SURFACE_DIRT)
		return
	assert_true(false, "the plan must place Kalev's smithy with a floor")


## Water the foot stands in wins over every floor and the painted ground, and
## its depth picks a splash or wading (R-1648).
func test_water_wins_over_ground() -> void:
	var plan := _plan()
	var at := _centroid(plan.footprint(0))
	var ankle := CitySurfaceSampler.new(plan, func(_xz: Vector2) -> float: return 0.1)
	assert_eq(ankle.surface_at(_foot(at)), SurfaceResolver.SURFACE_WATER_SHALLOW)
	var thigh := CitySurfaceSampler.new(plan, func(_xz: Vector2) -> float: return 0.8)
	assert_eq(thigh.surface_at(_foot(at)), SurfaceResolver.SURFACE_WATER_WADE)


## The real sea wades a little way out from the beach (R-1648): somewhere the
## plan's water is deep enough, the foot hears wading, not a splash.
func test_sea_shelf_wades() -> void:
	var plan := _plan()
	if not plan.has_coast():
		return
	var sea_depth := func(xz: Vector2) -> float: return maxf(-plan.walk_height(xz), 0.0)
	var sampler := CitySurfaceSampler.new(plan, sea_depth)
	var found_wade := false
	for gx in range(121):
		for gz in range(121):
			var xz := plan.bounds.position + plan.bounds.size * Vector2(gx, gz) / 120.0
			var depth := float(sea_depth.call(xz))
			if depth <= 0.0 or depth >= PlayerSwimState.SWIM_ENTER_DEPTH:
				continue
			var surface := sampler.surface_at(_foot(xz))
			if depth >= SurfaceResolver.WADE_SURFACE_DEPTH:
				found_wade = found_wade or surface == SurfaceResolver.SURFACE_WATER_WADE
	assert_true(found_wade, "wadeable sea must be heard as wading somewhere on the coast")


## Every painted layer the shader draws is heard as its own surface somewhere
## on the open ground of the plan.
func test_painted_ground_layers_map_to_their_surfaces() -> void:
	var plan := _plan()
	var sampler := CitySurfaceSampler.new(plan)
	var found := {}
	var step := 6.0
	var y := plan.bounds.position.y
	while y < plan.bounds.end.y and found.size() < 4:
		var x := plan.bounds.position.x
		while x < plan.bounds.end.x:
			var xz := Vector2(x, y)
			if _free_ground(plan, xz):
				found[sampler.ground_surface(xz)] = true
			x += step
		y += step
	for surface: StringName in [
		SurfaceResolver.SURFACE_STONE, SurfaceResolver.SURFACE_DIRT, SurfaceResolver.SURFACE_GRASS
	]:
		assert_true(found.has(surface), "no %s ground found in the city" % surface)


## Rain fills the shader's earth basins: puddles appear only with standing
## water, never on baked ground, and only over soft ground.
func test_puddles_follow_rain_and_drought() -> void:
	var plan := _plan()
	var sampler := CitySurfaceSampler.new(plan)
	var wet := 0
	var probes := 0
	var step := 1.7
	var y := plan.bounds.position.y + plan.bounds.size.y * 0.3
	while y < plan.bounds.end.y and probes < 4000:
		var x := plan.bounds.position.x
		while x < plan.bounds.end.x and probes < 4000:
			var xz := Vector2(x, y)
			if _free_ground(plan, xz) and sampler.ground_surface(xz) == SurfaceResolver.SURFACE_DIRT:
				probes += 1
				if sampler.puddle_depth(xz, 1.0, 0.0) > CitySurfaceSampler.PUDDLE_MIN_DEPTH:
					wet += 1
					assert_eq(
						sampler.surface_at(_foot(xz), 1.0, 0.0), SurfaceResolver.SURFACE_PUDDLE
					)
					assert_eq(sampler.surface_at(_foot(xz), 0.0, 0.0), SurfaceResolver.SURFACE_DIRT)
					assert_eq(sampler.surface_at(_foot(xz), 1.0, 1.0), SurfaceResolver.SURFACE_DIRT)
			x += step
		y += step
	assert_true(probes > 100, "the scan must reach open dirt")
	assert_true(wet > 0, "full rain must leave some puddles on dirt")
	assert_true(wet < probes, "rain must not flood every patch of dirt")


## Cobbled streets and cart-road ruts hold water too (the shader's cobble_pool and
## rut_pool), so a boot there must hear and splash as a puddle.
func test_puddles_form_on_paving_and_in_cart_ruts() -> void:
	var plan := _plan()
	var sampler := CitySurfaceSampler.new(plan)
	var paved_wet := 0
	var rut_wet := 0
		# Whole-plan scan: paving and roads lie far from the plan's top rows.
	var step := 2.6
	var y := plan.bounds.position.y
	while y < plan.bounds.end.y:
		var x := plan.bounds.position.x
		while x < plan.bounds.end.x:
			var xz := Vector2(x, y)
			if _free_ground(plan, xz):
				if sampler.puddle_depth(xz, 1.0, 0.0) > CitySurfaceSampler.PUDDLE_MIN_DEPTH:
					var ground := sampler.ground_surface(xz)
					if ground == SurfaceResolver.SURFACE_STONE:
						paved_wet += 1
						assert_eq(
							sampler.surface_at(_foot(xz), 1.0, 0.0), SurfaceResolver.SURFACE_PUDDLE
						)
					elif CityShore.road_raster_at(plan, xz).r > 0.3:
						rut_wet += 1
			x += step
		y += step
	assert_true(paved_wet > 0, "rain must leave puddles on cobbles")
	assert_true(rut_wet > 0, "rain must fill cart ruts")


## The ported noise must match the shader's GLSL formula.
func test_hash_matches_the_shader_formula() -> void:
	# p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33);
	# fract((p3.x + p3.y) * p3.z), by hand for p = (1, 2).
	var p3 := Vector3(0.1031, 0.2062, 0.1031)
	var d := p3.dot(Vector3(p3.y, p3.z, p3.x) + Vector3.ONE * 33.33)
	p3 += Vector3.ONE * d
	var v := (p3.x + p3.y) * p3.z
	assert_almost_eq(CitySurfaceSampler.hash12(Vector2(1.0, 2.0)), v - floorf(v), 1e-9)
	var n := CitySurfaceSampler.value_noise(Vector2(3.4, -7.9))
	assert_true(n >= 0.0 and n <= 1.0)
