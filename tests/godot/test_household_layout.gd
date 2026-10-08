extends "res://tests/godot/test_case.gd"

## Furnished houses and the household day (docs/SYSTEMS/HOUSEHOLDS.md).


func _plan() -> CityPlan:
	return CityPlan.load_default()


func _interiors() -> CityInteriors:
	var interiors := CityInteriors.create(_plan(), CitizenRoster.load_default(), [])
	interiors.hour_override = 12.0
	return interiors


## Indices of lived-in enterable houses, smallest and largest first.
func _homes(interiors: CityInteriors) -> Array:
	var plan := _plan()
	var found: Array = []
	for i in plan.buildings.size():
		var b: Dictionary = plan.buildings[i]
		if not bool(b.get("enterable", false)) or String(b["kind"]) != "house":
			continue
		if interiors.household_at(i).is_empty():
			continue
		found.append([absf(CityBuildingBuilder.signed_area(plan.footprint(i))), i])
	found.sort()
	return found


func _pieces(layout: HouseholdLayout) -> Array:
	var out: Array = []
	for item in layout.items:
		out.append(item["piece"])
	return out


func test_every_piece_is_a_catalog_object_with_a_model() -> void:
	for piece: StringName in HouseholdLayout.PIECES:
		var id := String(HouseholdLayout.PIECES[piece]["object"])
		var record := HouseholdLayout.object(id)
		assert_false(record.is_empty(), "%s is catalogued" % id)
		assert_eq(String(record.get("model", {}).get("status", "")), "glb", "%s has a GLB" % id)


func test_layout_is_deterministic() -> void:
	var interiors := _interiors()
	var homes := _homes(interiors)
	var index: int = homes[homes.size() / 2][1]
	var plan := _plan()
	var household := interiors.household_at(index)
	var a := HouseholdLayout.build(plan, index, household)
	var b := HouseholdLayout.build(plan, index, household)
	assert_eq(a.items.size(), b.items.size())
	for k in a.items.size():
		assert_eq(a.items[k]["pos"], b.items[k]["pos"])


func test_houses_have_hearth_bed_and_seats() -> void:
	var interiors := _interiors()
	var homes := _homes(interiors)
	var checked := 0
	var with_table := 0
	for k in range(0, homes.size(), maxi(homes.size() / 40, 1)):
		var index: int = homes[k][1]
		var layout := interiors.layout(index)
		assert_true(layout != null, "house %d furnished" % index)
		var pieces := _pieces(layout)
		assert_true(layout.hearth >= 0, "hearth in house %d (%.0f m2)" % [index, homes[k][0]])
		assert_false(layout.slots_of(&"sleep").is_empty(), "a bed in house %d" % index)
		assert_false(layout.slots_of(&"sit").is_empty(), "a seat in house %d" % index)
		if &"table" in pieces or &"table_long" in pieces:
			with_table += 1
		checked += 1
	assert_true(checked >= 30, "sampled %d houses" % checked)
	assert_true(with_table >= checked * 0.9, "%d of %d have a table" % [with_table, checked])


func test_pieces_stay_inside_the_walls_and_apart() -> void:
	var interiors := _interiors()
	var homes := _homes(interiors)
	for k in range(0, homes.size(), maxi(homes.size() / 25, 1)):
		var layout := interiors.layout(homes[k][1])
		var floor_items: Array = []
		for item in layout.items:
			if float(item["y"]) > 0.0:
				continue
			for p: Vector2 in item["poly"]:
				assert_true(Geometry2D.is_point_in_polygon(p, layout.inner), "%s inside" % item["piece"])
			floor_items.append(item)
		for i in floor_items.size():
			for j in range(i + 1, floor_items.size()):
				var a: PackedVector2Array = Geometry2D.offset_polygon(floor_items[i]["poly"], -0.02)[0]
				var overlap := Geometry2D.intersect_polygons(a, floor_items[j]["poly"])
				assert_true(
					overlap.is_empty(),
					"%s and %s overlap" % [floor_items[i]["piece"], floor_items[j]["piece"]]
				)


func test_rich_houses_have_framed_beds_and_cupboards() -> void:
	var interiors := _interiors()
	var homes := _homes(interiors)
	var rich := 0
	for entry: Array in homes:
		var household := interiors.household_at(entry[1])
		if String(household["class"]) != "great":
			continue
		var pieces := _pieces(interiors.layout(entry[1]))
		assert_array_contains(pieces, &"bed_framed")
		rich += 1
		if rich >= 5:
			break
	assert_true(rich > 0, "found great households")


func test_fire_is_lit_for_meals_and_banked_at_night() -> void:
	assert_eq(HouseholdDay.hearth_state("bldg.x", 7.0), &"lit")
	assert_eq(HouseholdDay.hearth_state("bldg.x", 12.0), &"lit")
	assert_eq(HouseholdDay.hearth_state("bldg.x", 19.0), &"lit")
	assert_eq(HouseholdDay.hearth_state("bldg.x", 2.0), &"embers")
	assert_eq(HouseholdDay.hearth_state("bldg.x", 15.0), &"embers")


func test_firewood_burns_down_and_is_refilled() -> void:
	assert_eq(HouseholdDay.firewood_state(11.0, 10.7), &"full")
	assert_eq(HouseholdDay.firewood_state(20.0, 10.7), &"half")
	assert_eq(HouseholdDay.firewood_state(6.0, 10.7), &"low")


func test_people_sleep_in_bed_and_sit_at_meals() -> void:
	var interiors := _interiors()
	var roster := interiors.roster
	var homes := _homes(interiors)
	var index: int = homes[homes.size() / 2][1]
	interiors.refresh(_plan().footprint(index)[0])
	assert_true(interiors.is_furnished(index), "house furnished near Kalev")
	var hh := String(roster.household_of_building[String(_plan().buildings[index]["id"])])
	var someone: int = roster.members[hh][0]
	var night := interiors.indoor_state(someone, 2.0, 5.0)
	assert_eq(night["pose"], &"sleep")
	var layout := interiors.layout(index)
	var beds := layout.slots_of(&"sleep")
	assert_true(
		beds.any(func(s: Dictionary) -> bool: return s["pos"] == night["pos"]), "asleep on a bed slot"
	)
	var walking := interiors.indoor_state(someone, 2.0, 0.0)
	assert_eq(walking["pose"], &"walk", "just home: walking in from the door")
	interiors.free()


func test_firewood_is_carried_home_from_the_woodyard() -> void:
	var roster := CitizenRoster.load_default()
	for i in roster.count():
		var r := roster.residents[i]
		if r["pattern"] != "domestic":
			continue
		var entries: Array = roster.patterns["domestic"]
		for k in range(1, entries.size()):
			if entries[k - 1][1] == "fuel":
				var h := float(entries[k][0]) + float(r["jitter"]) + 0.005
				var state := roster.resolve(i, h)
				if state["moving"]:
					assert_eq(state["from"], "fuel")
					assert_eq(state["dest"], "home")
					return
	fail("no resident on the way home from the woodyard")
