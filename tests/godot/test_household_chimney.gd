extends "res://tests/godot/test_case.gd"

## The house chimney and the hearth line up (docs/SYSTEMS/HOUSEHOLDS.md): the
## stack through the roof sits on the gable wall right over the hearth's own
## brick flue, and an enterable house gets a chimney breast between them.


func _flue_offset() -> AABB:
	var model := MapViewDomesticHearthModels.add_model(Node3D.new(), {"id": "test"})
	var flue := model.find_child("Flue*", true, false) as MeshInstance3D
	assert_true(flue != null, "the hearth GLB has a Flue mesh")
	var box := flue.get_aabb()
	var xform := Transform3D.IDENTITY
	var node: Node = flue
	while node != model and node != null:
		xform = (node as Node3D).transform * xform
		node = node.get_parent()
	var out := xform * box
	model.get_parent().free()
	return out


func test_flue_constants_match_the_hearth_model() -> void:
	var box := _flue_offset()
	var centre := box.get_center()
	assert_almost_eq(centre.x, 0.0, 0.02, "flue centred across the hearth")
	assert_almost_eq(
		centre.z, HouseholdLayout.HEARTH_FLUE_BACK, 0.02, "flue behind the origin (+Z, the back)"
	)
	assert_almost_eq(box.end.y, HouseholdLayout.HEARTH_FLUE_TOP, 0.02, "flue top")


func test_hearths_stand_under_their_chimneys() -> void:
	var plan := CityPlan.load_default()
	var interiors := CityInteriors.create(plan, CitizenRoster.load_default(), [])
	var houses := 0
	var aligned := 0
	var misses: Array = []
	for i in plan.buildings.size():
		var b: Dictionary = plan.buildings[i]
		if not bool(b.get("enterable", false)) or String(b["kind"]) != "house":
			continue
		var household := interiors.household_at(i)
		if household.is_empty():
			continue
		var built := CityBuildingBuilder.build_building(
			b, plan.footprint(i), plan.floor_height(i), true, plan.ground_height
		)
		var top: Vector3 = built["chimney"]
		if top == Vector3.INF:
			continue
		var chimney := Vector2(top.x, top.z)
		var lay := HouseholdLayout.build(plan, i, household, chimney)
		if lay.hearth < 0:
			continue
		houses += 1
		var item: Dictionary = lay.items[lay.hearth]
		var yaw := float(item["yaw"])
		# Local +Z (the hearth's back, where its flue is) in plan xz.
		var back := Vector2(sin(yaw), cos(yaw))
		var flue: Vector2 = item["pos"] + back * HouseholdLayout.HEARTH_FLUE_BACK
		if flue.distance_to(chimney) < 0.05:
			aligned += 1
		else:
			misses.append(String(b["id"]))
	assert_true(houses > 20, "enough houses with a chimney to check (%d)" % houses)
	assert_eq(misses, [], "hearth flue under the chimney in %d/%d houses" % [aligned, houses])


func test_chimney_sits_on_a_gable_away_from_the_door() -> void:
	var plan := CityPlan.load_default()
	var checked := 0
	for i in plan.buildings.size():
		var b: Dictionary = plan.buildings[i]
		if String(b["kind"]) != "house" or b.get("door") == null:
			continue
		var built := CityBuildingBuilder.build_building(
			b, plan.footprint(i), plan.floor_height(i), false, plan.ground_height
		)
		var top: Vector3 = built["chimney"]
		if top == Vector3.INF:
			continue
		checked += 1
		var door := Vector2(b["door"][0], b["door"][1])
		var clear := Vector2(top.x, top.z).distance_to(door)
		assert_true(clear >= 3.0, "%s chimney clear of the door" % b["id"])
		assert_true(top.y > float(built["frame"]["ridge"]), "%s stack tops the ridge" % b["id"])
		if checked >= 200:
			break
	assert_true(checked > 20, "checked %d chimneys" % checked)
