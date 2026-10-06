extends "res://tests/godot/test_case.gd"

## R-1187: seasonal foliage is a pure function of the campaign date.

const DECIDUOUS: Array[StringName] = [&"birch", &"oak", &"maple", &"apple", &"willow"]
const CONIFERS: Array[StringName] = [&"spruce", &"pine", &"juniper"]


func _date(day: int, month: int, year: int = 1343) -> Dictionary:
	return {"day": day, "month": month, "year": year}


func _density(species: StringName, date: Dictionary) -> float:
	return float(VegetationPhenology.state_for(species, date)["leaf_density"])


func test_deciduous_trees_are_bare_in_winter() -> void:
	for species in DECIDUOUS:
		for date in [_date(15, 1), _date(20, 2), _date(15, 12), _date(20, 11)]:
			assert_eq(_density(species, date), 0.0, "%s must be bare on %s" % [species, date])
			assert_eq(VegetationPhenology.hit_leaf_count(species, date, 2.0), 0)


func test_slice_opening_date_reads_as_early_spring() -> void:
	# The vertical slice opens on 21 April 1343: sparse fresh leaves, not summer.
	var date := GameCalendar.DEFAULT_DATE
	var birch := VegetationPhenology.state_for(&"birch", date)
	assert_true(
		float(birch["leaf_density"]) >= 0.25 and float(birch["leaf_density"]) <= 0.45,
		"early leafers show a bud-burst crown, got %s" % birch["leaf_density"]
	)
	assert_true(float(birch["leaf_scale"]) < 0.7, "young leaves are small")
	assert_true(float(birch["freshness"]) > 0.6, "young leaves are light yellow-green")
	assert_true(
		_density(&"oak", date) < _density(&"birch", date), "oak flushes later than birch"
	)
	assert_true(_density(&"oak", date) > 0.0, "oak shows first buds, not a winter tree")
	assert_false(bool(birch["fruit_visible"]))
	assert_false(bool(VegetationPhenology.state_for(&"apple", date)["fruit_visible"]))


func test_summer_crowns_are_full_and_green() -> void:
	for species in DECIDUOUS:
		var state := VegetationPhenology.state_for(species, _date(15, 7))
		assert_eq(float(state["leaf_density"]), 1.0)
		assert_eq(float(state["leaf_scale"]), 1.0)
		assert_eq(float(state["autumn"]), 0.0)
	assert_true(bool(VegetationPhenology.state_for(&"cherry", _date(15, 7))["fruit_visible"]))
	assert_true(bool(VegetationPhenology.state_for(&"apple", _date(10, 9))["fruit_visible"]))


func test_mid_october_is_coloured_and_shedding() -> void:
	for species in DECIDUOUS:
		var state := VegetationPhenology.state_for(species, _date(12, 10))
		assert_true(float(state["autumn"]) > 0.6, "%s colours by mid October" % species)
		assert_true(float(state["fall_rate"]) > 0.5, "%s sheds in October" % species)
		assert_true(float(state["leaf_density"]) > 0.0 and float(state["leaf_density"]) < 1.0)
	var maple := VegetationPhenology.falling_leaf_colors(&"maple", _date(12, 10))
	var birch := VegetationPhenology.falling_leaf_colors(&"birch", _date(12, 10))
	assert_true(maple[0].r > maple[0].g * 1.5, "maple falls red")
	assert_true(birch[0].g > birch[0].b * 2.0, "birch falls gold")


func test_conifers_keep_needles_all_year() -> void:
	for species in CONIFERS:
		for month in range(1, 13):
			var state := VegetationPhenology.state_for(species, _date(15, month))
			assert_eq(float(state["leaf_density"]), 1.0)
			assert_eq(float(state["autumn"]), 0.0)
		assert_true(
			float(VegetationPhenology.state_for(species, _date(15, 1))["winter_dull"]) > 0.8
		)
		assert_true(VegetationPhenology.hit_leaf_count(species, _date(15, 1), 1.0) >= 1)


func test_density_is_continuous_and_deterministic() -> void:
	for species in DECIDUOUS:
		var date := _date(1, 1)
		var previous := _density(species, date)
		for _day in 365:
			date = GameCalendar.add_days(date, 1)
			var current := _density(species, date)
			assert_true(absf(current - previous) <= 0.2, "%s density jumps on %s" % [species, date])
			assert_eq(current, _density(species, date))
			previous = current


func test_julian_leap_year_dates_are_accepted() -> void:
	# 1344 is a Julian leap year; 29 February must resolve to a bare winter tree.
	var state := VegetationPhenology.state_for(&"birch", _date(29, 2, 1344))
	assert_eq(float(state["leaf_density"]), 0.0)
	# After the leap day, 20 April 1344 has the same day-of-year as 21 April 1343.
	assert_eq(
		VegetationPhenology.state_for(&"birch", _date(20, 4, 1344))["leaf_density"],
		VegetationPhenology.state_for(&"birch", _date(21, 4, 1343))["leaf_density"],
		"leap day shifts the day-of-year by one"
	)


func test_heavier_hits_drop_more_leaves() -> void:
	var date := _date(10, 10)
	var light := VegetationPhenology.hit_leaf_count(&"birch", date, 1.0)
	var heavy := VegetationPhenology.hit_leaf_count(&"birch", date, 1.6)
	assert_true(heavy > light and light > 0)
	assert_true(
		light > VegetationPhenology.hit_leaf_count(&"birch", _date(10, 7), 1.0),
		"autumn crowns are looser than summer crowns"
	)
