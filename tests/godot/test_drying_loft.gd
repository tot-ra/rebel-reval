extends "res://tests/godot/test_case.gd"

## Grain-drying loft and threshing floor of smoke dwellings (DryingLoft,
## docs/SYSTEMS/FARMLAND.md).

const HEAD_HEIGHT := 1.9


func _dwellings(plan: CityPlan) -> Array:
	var found: Array = []
	for i in plan.buildings.size():
		if String(plan.buildings[i].get("type", "")) == "smoke_room":
			found.append(i)
	return found


func _layout(plan: CityPlan, index: int) -> HouseholdLayout:
	return HouseholdLayout.build(plan, index, plan.buildings[index].get("household", {}))


func _of_kind(layout: HouseholdLayout, kind: StringName) -> Array:
	return layout.items.filter(func(it: Dictionary) -> bool: return it.get("loft") == kind)


func test_load_follows_the_harvest_season() -> void:
	var april := DryingLoft.sheaf_load(111.0)  # 21 April: the slice opening
	var july := DryingLoft.sheaf_load(190.0)  # rye not yet cut
	var september := DryingLoft.sheaf_load(260.0)
	var january := DryingLoft.sheaf_load(15.0)
	assert_true(april < 0.15, "a few bundles or none in spring (%f)" % april)
	assert_eq(july, 0.0, "poles bare before the harvest")
	assert_eq(september, 1.0, "poles full in the drying season")
	assert_true(january > april and january < 1.0, "winter: part-emptied by threshing")
	assert_almost_eq(DryingLoft.sheaf_load(0.0), DryingLoft.sheaf_load(366.0), 0.001)
	assert_true(DryingLoft.sheaf_shown(0.5, 260.0))
	assert_false(DryingLoft.sheaf_shown(0.5, 190.0))


func test_smoke_dwellings_get_poles_sheaves_and_threshing_floor() -> void:
	var plan := CityPlan.load_site("harju")
	var dwellings := _dwellings(plan)
	assert_eq(dwellings.size(), 7)
	var anteroom_floors := 0
	for index: int in dwellings:
		var layout := _layout(plan, index)
		var poles := _of_kind(layout, &"loft_pole")
		var sheaves := _of_kind(layout, &"loft_sheaf")
		var bid := String(plan.buildings[index]["id"])
		assert_true(poles.size() >= 4 and poles.size() <= DryingLoft.POLE_MAX, "%s poles" % bid)
		assert_true(sheaves.size() >= poles.size(), "%s sheaves" % bid)
		for pole: Dictionary in poles:
			assert_true(float(pole["y"]) > HEAD_HEIGHT, "%s pole above head" % bid)
			assert_false(bool(pole["solid"]))
			assert_true(float(pole["len"]) > 1.0, "%s pole spans the room" % bid)
			assert_true(Geometry2D.is_point_in_polygon(pole["pos"], layout.inner), "%s pole inside" % bid)
		for sheaf: Dictionary in sheaves:
			assert_true(float(sheaf["y"]) > HEAD_HEIGHT)
			assert_true(float(sheaf["rank"]) >= 0.0 and float(sheaf["rank"]) < 1.0)
			assert_true(Geometry2D.is_point_in_polygon(sheaf["pos"], layout.inner), "%s sheaf inside" % bid)
		if not _of_kind(layout, &"straw_litter").is_empty():
			anteroom_floors += 1
			assert_eq(_of_kind(layout, &"threshing_flail").size(), 2, "%s flails" % bid)
			# The litter lies beyond the poles, in the anteroom end of the house.
			var litter: Dictionary = _of_kind(layout, &"straw_litter")[0]
			var litter_along: float = (litter["pos"] - layout.axis_origin).dot(layout.axis)
			var first_pole: float = (poles[0]["pos"] - layout.axis_origin).dot(layout.axis)
			var last_pole: float = (poles[-1]["pos"] - layout.axis_origin).dot(layout.axis)
			assert_true(
				litter_along < minf(first_pole, last_pole) or litter_along > maxf(first_pole, last_pole),
				"%s litter outside the poles" % bid
			)
	assert_eq(anteroom_floors, 7, "every dwelling has a threshing floor")


func test_loft_does_not_touch_slots_or_the_rest_of_the_layout() -> void:
	var plan := CityPlan.load_site("harju")
	var index: int = _dwellings(plan)[0]
	var layout := _layout(plan, index)
	for item: Dictionary in layout.items:
		if item.has("loft"):
			assert_false(bool(item["solid"]), "loft items never collide")
	# The same dwelling without the loft keeps every regular item and slot.
	var plain: Array = layout.items.filter(func(it: Dictionary) -> bool: return not it.has("loft"))
	assert_true(plain.size() > 3, "ordinary furnishings are there")
	assert_true(layout.hearth >= 0 and not layout.slots_of(&"sleep").is_empty())


func test_loft_layout_is_deterministic() -> void:
	var plan := CityPlan.load_site("harju")
	for index: int in _dwellings(plan):
		var a := _layout(plan, index)
		var b := _layout(plan, index)
		assert_eq(a.items.size(), b.items.size())
		for k in a.items.size():
			assert_eq(a.items[k]["pos"], b.items[k]["pos"])
			assert_eq(a.items[k].get("rank"), b.items[k].get("rank"))


func test_town_houses_get_no_loft() -> void:
	var plan := CityPlan.load_default()
	var checked := 0
	for i in plan.buildings.size():
		var b: Dictionary = plan.buildings[i]
		if String(b.get("type", "")) == "smoke_room" or not bool(b.get("enterable", false)):
			continue
		if b.get("door") == null or b.get("household") == null:
			continue
		var layout := HouseholdLayout.build(plan, i, b["household"])
		assert_true(_of_kind(layout, &"loft_pole").is_empty())
		checked += 1
		if checked >= 5:
			break


func test_models_build() -> void:
	for kind: StringName in DryingLoft.KINDS:
		var model := DryingLoft.build_model(
			{"loft": kind, "len": 3.0, "size": Vector3(2.0, 0.0, 1.0), "seed": 7}
		)
		assert_true(model.get_child_count() == 1, "%s has a mesh" % kind)
		model.free()
