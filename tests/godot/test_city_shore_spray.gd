extends "res://tests/godot/test_case.gd"

## Event-driven shore spray (WR-6, docs/SYSTEMS/CITY_SEA.md): bursts follow the
## breaking wave's phase, are deterministic, silent at calm and bounded per tier.

const Spray := preload("res://scripts/city/city_shore_spray.gd")
const ShoreField := preload("res://scripts/city/city_shore_field.gd")


func _spray(plan: CityPlan, shore: Dictionary) -> Node3D:
	var spray := Spray.new()
	spray.configure(plan, shore["contour"], shore)
	return spray


func test_crest_event_fires_once_per_crest_and_not_on_first_sample() -> void:
	var none := -2147483648
	assert_false(Spray.fires(3.4, none), "first sample only records the crest")
	var last := Spray.crest_event(3.4, none)
	assert_eq(last, 3)
	assert_false(Spray.fires(3.99, last), "same crest does not refire")
	assert_true(Spray.fires(4.01, last), "next crest fires")
	assert_eq(Spray.crest_event(4.01, last), 4)
	assert_eq(Spray.crest_event(2.0, last), 3, "event id never goes backwards")
	assert_true(Spray.fires(-0.5 + 1.2, Spray.crest_event(-0.5, none)), "negative cycles work")


func test_tier_budgets_grow_and_are_bounded() -> void:
	var previous_slots := 0
	var previous_ceiling := 0
	for budget in [160, 420, 640]:
		var slots := Spray.slot_count(budget)
		var ceiling := Spray.particle_ceiling(budget)
		assert_true(slots > previous_slots, "slots grow with tier %d" % budget)
		assert_true(ceiling > previous_ceiling, "ceiling grows with tier %d" % budget)
		assert_true(ceiling < 14000, "ceiling %d stays bounded at %d" % [ceiling, budget])
		assert_true(Spray.mist_budget(budget) < budget and Spray.sheet_budget(budget) < budget)
		previous_slots = slots
		previous_ceiling = ceiling


func test_burst_seed_and_ratio_are_deterministic() -> void:
	assert_eq(Spray.burst_seed(3, 41), Spray.burst_seed(3, 41))
	assert_true(Spray.burst_seed(3, 41) != Spray.burst_seed(3, 42), "new crest, new seed")
	assert_true(Spray.burst_ratio(1.0, 1.0) > Spray.burst_ratio(1.0, 0.1), "gale throws more")
	assert_true(Spray.burst_ratio(0.0, 0.0) >= 0.1, "ratio has a floor")
	assert_false(Spray.gale_tears(2, 9, 0.0), "no tearing without a gale")
	var tears := 0
	for event in 200:
		if Spray.gale_tears(1, event, 1.0):
			tears += 1
	assert_true(tears > 100 and tears < 200, "full gale tears most crests (%d)" % tears)


func test_bursts_follow_breakers_deterministically_and_calm_is_silent() -> void:
	var plan := CityPlan.load_default()
	var shore := ShoreField.bake(plan)
	var at: Vector2 = (shore["contour"] as PackedVector2Array)[0]
	var counts: Array[int] = []
	var spots: Array[Vector2] = []
	for run in 2:
		var spray := _spray(plan, shore)
		spray.set_wind(0.95)
		spray.place_slots(at)
		var total := 0
		# Three 9 s wave periods at 0.5 s steps.
		for step in 56:
			total += spray.update_events(float(step) * 0.5)
		counts.append(total)
		spots.append(spray._slots[0].spot)
		var budget := int(MapViewMaterials.WATER_MATERIALS.sea_lod_preset()["spray_particles"])
		assert_eq(spray._slots.size(), Spray.slot_count(budget))
		spray.free()
	assert_true(counts[0] > 0, "breakers produce bursts in a gale")
	assert_eq(counts[0], counts[1], "same phase, same bursts")
	assert_eq(spots[0], spots[1], "same placement")
	var calm := _spray(plan, shore)
	calm.set_wind(0.2)
	calm.place_slots(at)
	var quiet := 0
	for step in 56:
		quiet += calm.update_events(float(step) * 0.5)
	assert_eq(quiet, 0, "nothing at calm")
	calm.free()
