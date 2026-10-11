extends "res://tests/godot/test_case.gd"

## SeasonState: deterministic Tallinn climate by campaign date (ADR 0045).


func _doy(month: int, day: int) -> float:
	return float(GameCalendar.day_of_year({"day": day, "month": month, "year": 1343}))


func test_season_by_month() -> void:
	assert_eq(SeasonState.season_for_day(_doy(1, 15)), SeasonState.WINTER)
	assert_eq(SeasonState.season_for_day(_doy(4, 21)), SeasonState.SPRING)
	assert_eq(SeasonState.season_for_day(_doy(7, 20)), SeasonState.SUMMER)
	assert_eq(SeasonState.season_for_day(_doy(10, 20)), SeasonState.AUTUMN)
	assert_eq(SeasonState.season_for_day(_doy(12, 20)), SeasonState.WINTER)


func test_weights_sum_to_one_all_year() -> void:
	for doy in range(1, 366):
		var weights := SeasonState.season_weights(float(doy))
		var total := 0.0
		for season in SeasonState.SEASONS:
			total += float(weights[season])
		assert_almost_eq(total, 1.0, 0.001, "weights at day %d" % doy)


func test_temperature_extremes() -> void:
	assert_true(SeasonState.mean_temperature_c(30.0) < -3.0)
	assert_true(SeasonState.mean_temperature_c(212.0) > 16.0)


func test_slice_opening_is_not_winter() -> void:
	var snap := SeasonState.snapshot(GameCalendar.DEFAULT_DATE)
	assert_eq(snap["season"], SeasonState.SPRING)
	assert_almost_eq(float(snap["snow_cover_target_m"]), 0.0, 0.001)
	assert_almost_eq(float(snap["ice_fresh"]), 0.0, 0.001)


func test_snow_and_ice_follow_cold() -> void:
	assert_true(SeasonState.snow_cover_target_m(_doy(2, 10)) > 0.2)
	assert_almost_eq(SeasonState.snow_cover_target_m(_doy(7, 10)), 0.0, 0.001)
	assert_true(SeasonState.ice_cover_target(SeasonState.ICE_PUDDLE, _doy(1, 20)) > 0.5)
	# Sea ice trails the cold: thicker in March than a puddle-friendly November.
	assert_true(
		SeasonState.ice_cover_target(SeasonState.ICE_SEA, _doy(3, 1))
		> SeasonState.ice_cover_target(SeasonState.ICE_SEA, _doy(11, 20))
	)


func test_heating_and_clothing_scale_with_cold() -> void:
	var winter_heat := SeasonState.heating_demand(_doy(1, 15))
	var summer_heat := SeasonState.heating_demand(_doy(7, 15))
	assert_true(winter_heat > summer_heat * 3.0)
	assert_true(SeasonState.clothing_warmth(_doy(1, 15)) > 0.8)
	assert_true(SeasonState.clothing_warmth(_doy(7, 15)) < 0.1)


func test_days_until_wraps_to_next_year() -> void:
	var april := {"day": 21, "month": 4, "year": 1343}
	assert_eq(GameCalendar.days_until(april, 4, 22), 1)
	assert_eq(GameCalendar.days_until(april, 4, 21), 366)
	var target := GameCalendar.add_days(april, GameCalendar.days_until(april, 1, 15))
	assert_eq(int(target["month"]), 1)
	assert_eq(int(target["year"]), 1344)
