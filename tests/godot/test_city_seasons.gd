extends "res://tests/godot/test_case.gd"

## ADR 0045 city seasons: leaf fall by tree and wind, water plants and moat ice,
## and (R-2075) the day's weather on the ice: thaw, refreeze, glaze, lag by kind.

const OCT := {"day": 20, "month": 10, "year": 1343}
const JAN := {"day": 15, "month": 1, "year": 1343}
const JUL := {"day": 15, "month": 7, "year": 1343}

## R-2075 dates (ANOMALY_SEED): a cold spell 16-20 January 1343, then a thaw.
const COLD_DAY := {"day": 18, "month": 1, "year": 1343}
const THAW_DAY := {"day": 23, "month": 1, "year": 1343}
## About sunrise (08:24), the coldest hour of a January day.
const DAWN := 0.35
const NOON := 0.55


func _doy(date: Dictionary) -> float:
	return SeasonState.day_of_year_for(date)


func test_leaf_shedding_follows_leaves_and_wind() -> void:
	assert_eq(CityLeafFall.shed_weight(&"birch", JAN, 0.9), 0.0, "a bare tree sheds nothing")
	var calm := CityLeafFall.shed_weight(&"birch", OCT, 0.1)
	var windy := CityLeafFall.shed_weight(&"birch", OCT, 0.8)
	assert_true(calm > 0.0, "October crowns shed even in a lull")
	assert_true(windy > calm * 1.5, "a stiff wind strips more leaves")
	assert_eq(CityLeafFall.shed_weight(&"birch", JUL, 0.1), 0.0, "summer crowns hold fast")
	assert_true(CityLeafFall.shed_weight(&"birch", JUL, 0.9) > 0.0, "a gale shakes summer leaves")
	assert_eq(CityLeafFall.shed_weight(&"spruce", JAN, 0.9), 0.0, "winter conifers keep their needles")
	assert_eq(
		CityLeafFall.shed_weight(&"pine", JUL, 0.9), 0.0, "city leaf particles are deciduous-only"
	)


## Real crowns drop a few tenths of a leaf per second in calm air and a few in a
## gale; the emitter must not saturate into a leaf blizzard near a handful of trees.
func test_leaf_fall_rate_per_tree_is_realistic() -> void:
	var per_weight := CityLeafFall.LEAVES_PER_SECOND_PER_WEIGHT
	var calm := CityLeafFall.shed_weight(&"birch", OCT, 0.2) * per_weight
	var gale := CityLeafFall.shed_weight(&"birch", OCT, 1.0) * per_weight
	print("birch Oct 20 leaves/s per tree: calm %.2f, gale %.2f" % [calm, gale])
	assert_true(calm > 0.05 and calm < 1.0, "calm October tree: a trickle, got %.2f/s" % calm)
	assert_true(gale < 3.0, "a gale strips leaves but not as a blizzard, got %.2f/s" % gale)


func test_tree_lod_lists_trees_near_a_point() -> void:
	var lod := CityTreeLod.new()
	var far := MultiMesh.new()
	far.transform_format = MultiMesh.TRANSFORM_3D
	far.instance_count = 2
	var transforms: Array[Transform3D] = [
		Transform3D(Basis.from_scale(Vector3.ONE * 2.0), Vector3(10.0, 1.0, 10.0)),
		Transform3D(Basis.IDENTITY, Vector3(300.0, 0.0, 300.0)),
	]
	var colors: Array[Color] = [Color.WHITE, Color.WHITE]
	lod.register(&"birch", 1.0, far, transforms, colors, false)
	var near := lod.trees_near(Vector3(12.0, 0.0, 12.0), 20.0)
	assert_eq(near.size(), 1)
	assert_eq(near[0][0], &"birch")
	assert_almost_eq(float(near[0][2]), 2.0, 0.001, "scale rides along for crown size")
	lod.free()


func test_water_plants_die_back_with_the_cold() -> void:
	assert_true(SeasonState.reed_standing(_doy(JUL)) > 0.99)
	assert_almost_eq(SeasonState.reed_standing(_doy(JAN)), 0.0, 0.001)
	assert_true(SeasonState.water_plant_vigour(_doy(JUL)) > 0.99)
	assert_almost_eq(SeasonState.water_plant_vigour(_doy(JAN)), 0.0, 0.001)
	assert_true(SeasonState.reed_dead_share(_doy(OCT)) > 0.4, "autumn reeds are yellowing")
	assert_almost_eq(SeasonState.reed_dead_share(_doy(JUL)), 0.0, 0.001)
	# Lily flowers need warmer water than the pads.
	assert_true(SeasonState.lily_flower_share(_doy(JUL)) > 0.5)
	assert_almost_eq(SeasonState.lily_flower_share(_doy(OCT)), 0.0, 0.001)


func test_moat_plants_thin_out_in_winter() -> void:
	var root := Node3D.new()
	var xf: Array[Transform3D] = []
	var colors: Array[Color] = []
	for i in 10:
		xf.append(Transform3D(Basis.IDENTITY, Vector3(float(i), 0.0, 0.0)))
		colors.append(Color.WHITE)
	CityMoatPlants._add_reeds(root, xf, colors)
	CityMoatPlants.apply_season(root, _doy(JUL))
	var reeds := root.get_node("Reeds") as MultiMeshInstance3D
	assert_eq(reeds.multimesh.visible_instance_count, 10)
	assert_true(reeds.visible)
	CityMoatPlants.apply_season(root, _doy(JAN))
	assert_eq(reeds.multimesh.visible_instance_count, 0, "a hard winter leaves no reeds")
	assert_false(reeds.visible)
	root.free()


func test_moat_floaters_are_textured_cut_outs() -> void:
	var root := Node3D.new()
	var xf: Array[Transform3D] = [Transform3D.IDENTITY]
	var colors: Array[Color] = [Color.WHITE]
	CityMoatPlants._add_floating(
		root,
		"LilyPads",
		CityMoatPlants._pad_mesh(),
		xf,
		colors,
		CityMoatPlants.PAD_TINT,
		CityMoatPlants.PAD_TEXTURE
	)
	CityMoatPlants._add_reeds(root, xf, colors)
	var pad_mat := (root.get_node("LilyPads") as MultiMeshInstance3D).material_override
	assert_eq(pad_mat.albedo_texture, CityMoatPlants.PAD_TEXTURE)
	assert_eq(pad_mat.transparency, BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR)
	var reed_mat := (root.get_node("Reeds") as MultiMeshInstance3D).material_override
	assert_eq(reed_mat.albedo_texture, CityMoatPlants.BLADE_TEXTURE)
	assert_false(pad_mat.texture_repeat, "the pad UV overshoot must clamp, not wrap")
	# The pad UVs cover the photo (overshooting by about 1 %) so the scissor,
	# not the 16-gon, draws the leaf outline.
	var uvs: PackedVector2Array = CityMoatPlants._pad_mesh().surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
	for uv in uvs:
		assert_true(uv.x >= -0.01 and uv.x <= 1.01 and uv.y >= -0.01 and uv.y <= 1.01)
	root.free()


func test_moat_freezes_by_temperature() -> void:
	assert_almost_eq(SeasonState.ice_cover_target(SeasonState.ICE_FRESH, _doy(JUL)), 0.0, 0.001)
	assert_true(SeasonState.ice_cover_target(SeasonState.ICE_FRESH, _doy(JAN)) > 0.2)
	var feb := {"day": 15, "month": 2, "year": 1343}
	assert_true(SeasonState.ice_cover_target(SeasonState.ICE_FRESH, _doy(feb)) > 0.5)


## ADR 0045 task 6: puddles skin over first, the sea shore last; the sea material
## and the ground shader take the ice the city pushes in apply_season.
func test_puddles_and_sea_shore_freeze_in_order() -> void:
	var feb := {"day": 5, "month": 2, "year": 1343}
	assert_almost_eq(SeasonState.ice_cover_target(SeasonState.ICE_SEA, _doy(JUL)), 0.0, 0.001)
	var puddle := SeasonState.ice_cover_target(SeasonState.ICE_PUDDLE, _doy(feb))
	var fresh := SeasonState.ice_cover_target(SeasonState.ICE_FRESH, _doy(feb))
	var sea := SeasonState.ice_cover_target(SeasonState.ICE_SEA, _doy(feb))
	assert_true(puddle >= fresh and fresh > sea, "puddles, then the moat, then the sea")
	assert_true(sea > 0.15, "a mean February lines the shore with fast ice, got %.2f" % sea)
	MapViewMaterials.apply_sea_ice(0.4, 0.7)
	var water := MapViewMaterials.water_surface(MapTypes.TERRAIN_SHALLOW_WATER)
	assert_almost_eq(float(water.get_shader_parameter("sea_ice")), 0.4, 0.001)
	assert_almost_eq(float(water.get_shader_parameter("sea_ice_snow")), 0.7, 0.001)
	MapViewMaterials.apply_sea_ice(0.0, 0.0)
	assert_almost_eq(float(water.get_shader_parameter("sea_ice")), 0.0, 0.001)
	var uniforms: Array[String] = []
	var ground := load("res://scripts/city/city_ground.gdshader") as Shader
	for u: Dictionary in ground.get_shader_uniform_list():
		uniforms.append(String(u["name"]))
	assert_true("puddle_ice" in uniforms and "coast_ice" in uniforms)
	assert_true("ice_melt" in uniforms and "ice_glaze" in uniforms)


## The day's anomaly is a pure function of the date: equal on every call and
## after the memo is dropped, spells last several days, winter swings wider than
## summer, and over decades it averages out to the climate.
func test_daily_anomaly_is_deterministic_with_spells() -> void:
	var first := SeasonState.temperature_anomaly_c(THAW_DAY)
	SeasonState._anomaly_memo.clear()
	assert_eq(SeasonState.temperature_anomaly_c(THAW_DAY), first, "same date, same weather")
	assert_true(SeasonState.day_temperature_c(COLD_DAY) < -8.0, "the cold spell is a hard frost")
	assert_true(SeasonState.day_temperature_c(THAW_DAY) > 1.0, "the thaw lifts the day above zero")
	var winter_sq := 0.0
	var summer_sq := 0.0
	var winter_sum := 0.0
	var lag_product := 0.0
	var days := 0
	for year in range(1300, 1340):
		var jan := SeasonState.day_index({"day": 1, "month": 1, "year": year})
		var jul := SeasonState.day_index({"day": 1, "month": 7, "year": year})
		for k in 59:
			var a := SeasonState.anomaly_for_day(jan + k)
			winter_sq += a * a
			winter_sum += a
			lag_product += a * SeasonState.anomaly_for_day(jan + k + 1)
			summer_sq += pow(SeasonState.anomaly_for_day(jul + k), 2.0)
			days += 1
	var winter_sd := sqrt(winter_sq / days)
	print("anomaly: winter sd %.2f summer sd %.2f winter mean %.2f lag-1 r %.2f" % [
		winter_sd, sqrt(summer_sq / days), winter_sum / days, lag_product / winter_sq
	])
	assert_true(winter_sd > 3.5 and winter_sd < 6.5, "Tallinn winter days swing by about 5 C")
	assert_true(sqrt(summer_sq / days) < winter_sd * 0.7, "summer days are steadier")
	assert_true(absf(winter_sum / days) < 0.8, "anomalies keep the climate's mean")
	assert_true(lag_product / winter_sq > 0.6, "weather comes in spells, not day-by-day noise")


## Puddles answer the hour, the moat the last fortnight, the sea the last month:
## across a winter the biggest day-to-day change shrinks in that order.
func test_ice_lags_puddles_fast_moat_slow_sea_slowest() -> void:
	var jump := {SeasonState.ICE_PUDDLE: 0.0, SeasonState.ICE_FRESH: 0.0, SeasonState.ICE_SEA: 0.0}
	var start := {"day": 1, "month": 12, "year": 1342}
	var previous := {}
	for k in 120:
		var date := GameCalendar.add_days(start, k)
		var today := {
			SeasonState.ICE_PUDDLE: float(SeasonState.ice_weather(date, NOON, 0.3)["ice_puddle"]),
			SeasonState.ICE_FRESH: SeasonState.ice_cover_for(SeasonState.ICE_FRESH, date),
			SeasonState.ICE_SEA: SeasonState.ice_cover_for(SeasonState.ICE_SEA, date),
		}
		for kind in today:
			if not previous.is_empty():
				jump[kind] = maxf(jump[kind], absf(today[kind] - previous[kind]))
		previous = today
	print("largest daily ice change: ", jump)
	assert_true(jump[SeasonState.ICE_PUDDLE] > jump[SeasonState.ICE_FRESH])
	assert_true(jump[SeasonState.ICE_FRESH] > jump[SeasonState.ICE_SEA])
	assert_true(jump[SeasonState.ICE_SEA] > 0.0, "the sea still follows the weather")
	# A thaw after a cold spell: puddles go soft at noon, the moat keeps its ice.
	var thaw := SeasonState.ice_weather(THAW_DAY, NOON, 0.2)
	assert_true(float(thaw["ice_puddle"]) < 0.3, "puddle ice softens on a thaw noon")
	assert_true(SeasonState.ice_cover_for(SeasonState.ICE_FRESH, THAW_DAY) > 0.5, "the moat holds")
	# ...but not under lying snow: the ground is frozen, so the puddle stays ice
	# (wet with melt), never open water cut into the snow. Bare ground follows the hour.
	var thaw_ice := float(thaw["ice_puddle"])
	var snow := VegetationPhenology.snow_cover_for(THAW_DAY)
	assert_true(snow > 0.5, "the thaw day lies in the snow season")
	assert_eq(SeasonState.puddle_ice_with_snow(thaw_ice, snow), 1.0, "snowed puddles stay frozen")
	assert_eq(SeasonState.puddle_ice_with_snow(thaw_ice, 0.0), thaw_ice, "bare ground: the hour")
	# A mild spell thins the moat below what the mean climate would give.
	var mild := {"day": 22, "month": 2, "year": 1343}
	assert_true(
		SeasonState.ice_cover_for(SeasonState.ICE_FRESH, mild)
		< SeasonState.ice_cover_target(SeasonState.ICE_FRESH, _doy(mild)) - 0.2,
		"thin ice after a mild spell"
	)


## A thaw day: frozen at night, meltwater film at noon; the night after it the
## film is glaze. A hard-frost day has neither.
func test_thaw_melts_by_day_and_refreezes_into_glaze() -> void:
	var night := SeasonState.ice_weather(THAW_DAY, DAWN, 0.2)
	var noon := SeasonState.ice_weather(THAW_DAY, NOON, 0.2)
	assert_true(float(noon["air_c"]) > 1.0 and float(night["air_c"]) < float(noon["air_c"]) - 3.0)
	assert_true(float(night["ice_puddle"]) > float(noon["ice_puddle"]) + 0.2, "overnight freeze")
	assert_true(float(noon["melt"]) > 0.7, "wet film on the ice at a thaw noon")
	var after := SeasonState.ice_weather(GameCalendar.add_days(THAW_DAY, 3), DAWN, 0.0)
	assert_true(float(after["glaze"]) > 0.3, "the thaw water refreezes into glaze")
	var cold := SeasonState.ice_weather(COLD_DAY, NOON, 0.0)
	assert_eq(float(cold["melt"]), 0.0)
	assert_eq(float(cold["glaze"]), 0.0, "no thaw, no glaze")
	assert_eq(float(cold["ice_puddle"]), 1.0)
	# Overcast flattens the day: a cloudy noon is cooler than a clear one.
	var cloudy := SeasonState.ice_weather(THAW_DAY, NOON, 1.0)
	assert_true(float(cloudy["air_c"]) < float(noon["air_c"]) - 1.0)


## Rain on a thaw day falls as rain, frozen soil cannot drink it, so it stands in
## puddles faster than on soft spring soil; at night the puddles freeze and keep
## their water instead of drying.
func test_rain_on_frozen_ground_pools_and_freezes_overnight() -> void:
	var thaw := _rainy_sky(THAW_DAY, NOON)
	var share := thaw.precipitation_snow_share()
	assert_true(share < 0.5, "a thaw day rains, got %.2f" % share)
	assert_true(SeasonState.soil_frost(THAW_DAY) > 0.9, "the soil is still frozen")
	var spring := _rainy_sky({"day": 10, "month": 5, "year": 1343}, NOON)
	thaw._puddle_wetness = 0.0
	spring._puddle_wetness = 0.0
	thaw.advance(4.0)
	spring.advance(4.0)
	assert_true(thaw.puddle_wetness() > spring.puddle_wetness() * 1.4, "frozen ground runs off")
	thaw.set_weather(SkyWeather3D.WEATHER_CLOUDLESS)
	thaw.advance(SkyWeather3D.TRANSITION_SECONDS + 1.0)
	thaw.presentation_snapshot(DAWN, 0.0)
	assert_true(thaw.air_temperature_c() < -1.0, "a clear dawn after the thaw freezes")
	var held := thaw.puddle_wetness()
	thaw.advance(60.0)
	assert_eq(thaw.puddle_wetness(), held, "frozen puddles do not evaporate")
	thaw.free()
	spring.free()


## Snow lying on a thaw day melts into the hollows even without rain.
func test_thaw_meltwater_fills_puddles() -> void:
	var sky := _rainy_sky(THAW_DAY, NOON)
	sky.set_weather(SkyWeather3D.WEATHER_CLOUDLESS)
	sky.advance(SkyWeather3D.TRANSITION_SECONDS + 1.0)
	sky._puddle_wetness = 0.0
	var before := sky.puddle_wetness()
	sky.advance(20.0)
	assert_true(sky.puddle_wetness() > before + 0.1, "meltwater stands on the frozen ground")
	sky.free()


## The air temperature only reads saved weather state (date, cycle progress,
## cloud profile), so a save round trip continues identically.
func test_air_temperature_survives_a_save_round_trip() -> void:
	var sky := _rainy_sky(THAW_DAY, NOON)
	sky.advance(3.0)
	var state = sky.snapshot_state(NOON, 0)
	var restored := SkyWeather3D.new()
	assert_true(restored.restore_state(state.to_dict()))
	assert_eq(restored.air_temperature_c(), sky.air_temperature_c())
	sky.advance(5.0)
	restored.advance(5.0)
	assert_eq(restored.puddle_wetness(), sky.puddle_wetness())
	sky.free()
	restored.free()


## CityWorld3D pushes the hourly ice weather to the moat and sea materials.
func test_city_pushes_ice_weather_to_water() -> void:
	var world := CityWorld3D.new()
	world.sky_weather = SkyWeather3D.new()
	world.sky_weather.set_calendar_date(THAW_DAY)
	var moat := ShaderMaterial.new()
	world.water_materials.append(moat)
	world.apply_ice_weather(NOON, 0.2, 0.0, 0.0)
	assert_true(float(moat.get_shader_parameter("ice_melt")) > 0.7)
	var sea := MapViewMaterials.water_surface(MapTypes.TERRAIN_SHALLOW_WATER)
	assert_true(float(sea.get_shader_parameter("sea_ice_melt")) > 0.7)
	world.sky_weather.set_calendar_date(COLD_DAY)
	world.apply_ice_weather(NOON, 0.2, 0.0, 0.0)
	assert_eq(float(moat.get_shader_parameter("ice_melt")), 0.0)
	MapViewMaterials.apply_sea_ice_weather(0.0, 0.0)
	world.sky_weather.free()
	world.free()


func _rainy_sky(date: Dictionary, progress: float) -> SkyWeather3D:
	var sky := SkyWeather3D.new()
	sky.auto_weather = false
	sky.set_calendar_date(date)
	sky.presentation_snapshot(progress, 1.0)
	sky.set_weather(SkyWeather3D.WEATHER_RAIN)
	sky.advance(SkyWeather3D.TRANSITION_SECONDS + 1.0)
	return sky


func test_snow_patches_follow_cover() -> void:
	var spot := Vector2(123.4, -56.7)
	assert_eq(CitySnow.patch(spot, 0.0), 0.0)
	assert_almost_eq(CitySnow.patch(spot, 1.0), 1.0, 0.001, "deep winter covers everything")
	assert_eq(CitySnow.patch(spot, 0.5), CitySnow.patch(spot, 0.5), "deterministic")
	var covered := 0
	for i in 200:
		if CitySnow.patch(Vector2(i * 7.3, i * 3.1), 0.2) > CitySnow.LYING:
			covered += 1
	assert_true(covered > 10 and covered < 190, "thin cover is patchy, got %d/200" % covered)


func test_snow_takes_footprints_where_paving_would_not() -> void:
	var plan := CityPlan.load_default()
	var paved := func(_p: Vector2) -> Color: return Color(1, 0, 0, 0)
	var bare := CityGroundTrail.create(plan, paved)
	bare.update_for(Vector2(0, -400), 0.016)
	var snowy := CityGroundTrail.create(plan, paved)
	snowy.snow_cover = 1.0
	snowy.update_for(Vector2(0, -400), 0.016)
	var pos := Vector2(0, -400)
	for i in 80:
		pos += Vector2(0.25, 0.0)
		bare.update_for(pos, 0.016)
		snowy.update_for(pos, 0.016)
	var pressed_bare := 0
	var pressed_snow := 0
	var x := 0.0
	while x < 20.0:
		var at := Vector2(x, -400.0 + CityGroundTrail.FOOT_SPREAD)
		if bare.value_at(at) < 0.4:
			pressed_bare += 1
		if snowy.value_at(at) < 0.4:
			pressed_snow += 1
		x += CityGroundTrail.CELL
	assert_eq(pressed_bare, 0, "paving takes no print")
	assert_true(pressed_snow > 10, "snow takes prints, counted %d cells" % pressed_snow)
	bare.free()
	snowy.free()


func test_footsteps_in_snow_crunch() -> void:
	var plan := CityPlan.load_default()
	var sampler := CitySurfaceSampler.new(plan)
	var checked := 0
	var y := plan.bounds.position.y + plan.bounds.size.y * 0.3
	while y < plan.bounds.end.y and checked < 20:
		var x := plan.bounds.position.x
		while x < plan.bounds.end.x and checked < 20:
			var xz := Vector2(x, y)
			var foot := Vector3(xz.x, 0.0, xz.y)
			if (
				plan.ground_height(xz) > 3.0
				and plan.building_at(xz) < 0
				and plan.site_at(xz) == null
				and is_nan(plan.bridge_deck_height(xz))
				and sampler.ground_surface(xz) == SurfaceResolver.SURFACE_GRASS
			):
				checked += 1
				assert_eq(sampler.surface_at(foot, 0.0, 0.0, 0.0), SurfaceResolver.SURFACE_GRASS)
				assert_eq(sampler.surface_at(foot, 0.0, 0.0, 1.0), SurfaceResolver.SURFACE_SNOW)
			x += 9.7
		y += 9.7
	assert_true(checked > 5, "the scan must reach open turf")
	# Boards and flagstones are never snow.
	for kept: StringName in [SurfaceResolver.SURFACE_WOOD, SurfaceResolver.SURFACE_STONE]:
		assert_eq(SurfaceResolver.with_snow(kept, true), kept)
	assert_eq(
		SurfaceResolver.with_snow(SurfaceResolver.SURFACE_MUD, true), SurfaceResolver.SURFACE_SNOW
	)


func test_snow_depth_grows_with_cover_and_drifts() -> void:
	var spot := Vector2(123.4, -56.7)
	assert_eq(CitySnow.depth_at(spot, 0.0), 0.0)
	assert_true(CitySnow.depth_at(spot, 1.0) > CitySnow.depth_at(spot, 0.5))
	var lo := INF
	var hi := 0.0
	for i in 300:
		var d := CitySnow.depth_at(Vector2(i * 13.7, i * 5.3), 1.0)
		lo = minf(lo, d)
		hi = maxf(hi, d)
	assert_true(hi > 0.5, "drifts pile past half a metre at full cover, got %.2f" % hi)
	assert_true(hi - lo > 0.3, "depth varies a lot across the country")


func test_walking_slows_by_snow_depth() -> void:
	assert_eq(CitySnow.walk_drag(0.0), 1.0)
	assert_eq(CitySnow.walk_drag(CitySnow.DRAG_START), 1.0, "a dusting is free")
	var lying := CitySnow.walk_drag(CitySnow.DRAG_START + 0.001)
	assert_almost_eq(lying, CitySnow.SurfaceSpeed.SNOW_SHALLOW, 0.01, "lying snow: 80%")
	var knee := CitySnow.walk_drag(0.3)
	assert_true(knee < lying and knee > CitySnow.SurfaceSpeed.SNOW_DEEP, "deeper is slower")
	assert_almost_eq(CitySnow.walk_drag(CitySnow.DRAG_DEEP), CitySnow.SurfaceSpeed.SNOW_DEEP, 0.001)
	assert_almost_eq(CitySnow.walk_drag(0.9), CitySnow.SurfaceSpeed.SNOW_DEEP, 0.001, "30% floor")


func test_snow_map_is_bare_on_paving_and_deeper_in_woods() -> void:
	var plan := CityPlan.load_default()
	var trees: Array = plan.data.get("trees", [])
	CitySnow.bake(plan, func(_p: Vector2) -> Color: return Color(0, 1, 0, 0), trees, [])
	var open_total := 0.0
	var samples := 0
	var wood_total := 0.0
	var wood_samples := 0
	for t: Array in trees.slice(0, 400):
		var at := Vector2(float(t[0]), float(t[1]))
		if plan.building_at(at) >= 0 or plan.ground_height(at) < 0.4:
			continue
		wood_total += CitySnow.factor_at(at)
		wood_samples += 1
	for i in 400:
		var at := plan.bounds.position + Vector2(fmod(i * 97.3, 1500.0), fmod(i * 61.1, 1500.0))
		if plan.building_at(at) >= 0 or plan.ground_height(at) < 0.4:
			continue
		open_total += CitySnow.factor_at(at)
		samples += 1
	assert_true(wood_samples > 20 and samples > 20)
	var woods := wood_total / float(wood_samples)
	var open := open_total / float(samples)
	assert_true(woods > open * 0.9, "woods hold at least as much snow: %.2f vs %.2f" % [woods, open])
	CitySnow.bake(plan, func(_p: Vector2) -> Color: return Color(1, 0, 0, 0), trees, [])
	var paved_max := 0.0
	for i in 200:
		paved_max = maxf(paved_max, CitySnow.factor_at(plan.bounds.position + Vector2(i * 7.1, i * 7.9)))
	assert_true(paved_max < 0.15, "paving stays clear, got %.2f" % paved_max)
	CitySnow.clear_map()


## The 8 m depth map bled snow through walls and lifted the ground above interior
## floors; the 1 m shelter mask must keep every enterable house and site room dry.
func test_snow_never_lies_indoors() -> void:
	var plan := CityPlan.load_default()
	var turf := func(_p: Vector2) -> Color: return Color(0, 1, 0, 0)
	CitySnow.bake(plan, turf, plan.data.get("trees", []), [])
	var polygons: Array[PackedVector2Array] = []
	for i in plan.buildings.size():
		if bool(plan.buildings[i].get("enterable", false)):
			polygons.append(plan.footprint(i))
	for site in plan.sites:
		for room: Dictionary in site.rooms:
			polygons.append(room["polygon"])
	assert_true(polygons.size() > 50)
	var checked := 0
	var snowy := 0
	for ring in polygons:
		var box := Rect2(ring[0], Vector2.ZERO)
		for q in ring:
			box = box.expand(q)
		for y in range(int(box.position.y), int(box.end.y) + 1, 2):
			for x in range(int(box.position.x), int(box.end.x) + 1, 2):
				var p := Vector2(x, y)
				if not Geometry2D.is_point_in_polygon(p, ring):
					continue
				checked += 1
				if CitySnow.depth_at(p, 1.0) > 0.0:
					snowy += 1
	assert_true(checked > 1000, "sampled %d interior points" % checked)
	assert_eq(snowy, 0, "interior points under snow")
	CitySnow.clear_map()
