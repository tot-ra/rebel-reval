extends "res://tests/godot/test_case.gd"

## Landmark sites in the seamless city (ADR 0032): registry, compiled
## placement, replaced buildings, floors, rooms, HUD names and doors.


func _plan() -> CityPlan:
	return CityPlan.load_default()


func _site(id: StringName) -> CitySite:
	for site in _plan().sites:
		if site.id == id:
			return site
	return null


func test_registry_sites_load_with_compiled_placement() -> void:
	var site := _site(&"site.raekoja_plats")
	assert_true(site != null, "site.raekoja_plats loads from the registry")
	assert_true(site.level > 15.0, "terrace level comes from the compiled plan")


func test_replaced_generic_buildings_are_gone() -> void:
	for b: Dictionary in _plan().buildings:
		assert_true(String(b["id"]) != "bldg.lm.town_hall", "generic town hall is replaced")


func test_hall_floor_room_and_hud_name() -> void:
	var plan := _plan()
	var site := _site(&"site.raekoja_plats")
	var diele := site.to_world(Vector2(0.0, 2.0))
	assert_almost_eq(plan.walk_height(diele), site.level + 0.12, 0.001)
	assert_eq(plan.site_room_at(diele)["room"]["id"], &"room.diele")
	assert_eq(plan.location_at(diele)["building"], "Inside: Council hall (diele)")
	var dornse := site.to_world(Vector2(8.0, 3.0))
	assert_eq(plan.site_room_at(dornse)["room"]["id"], &"room.dornse")
	var dais := site.to_world(Vector2(-11.0, 0.0))
	assert_almost_eq(plan.walk_height(dais), site.level + 0.4, 0.001, "the court dais is raised")
	var outside := site.to_world(Vector2(0.0, -20.0))
	assert_true(plan.site_room_at(outside).is_empty(), "the forum is not inside the hall")


func test_people_have_roles_poses_and_stand_on_floors() -> void:
	var site := _site(&"site.raekoja_plats")
	var roles := {}
	for person: Dictionary in site.people:
		roles[person["id"]] = person["pose"]
		assert_false(site.floor_at(person["at"]).is_empty(), "%s is on a floor" % person["id"])
	assert_eq(roles[&"vogt"], &"sit")
	assert_eq(roles[&"burgomaster.1"], &"sit")
	assert_true(roles.has(&"scribe") and roles.has(&"kammerer"), "scribe and Kämmerer at work")


func test_door_gap_leads_from_the_forum_onto_the_floor() -> void:
	var site := _site(&"site.raekoja_plats")
	var d: Dictionary = site.doors[0]
	var mid: Vector2 = (d["a"] + d["b"]) * 0.5
	var inward: Vector2 = d["inward"]
	assert_false(site.floor_at(mid + inward * 1.0).is_empty(), "inside the door is hall floor")
	assert_true(site.floor_at(mid - inward * 1.0).is_empty(), "outside the door is the forum")


func test_holy_spirit_rooms_choir_step_and_glass() -> void:
	var plan := _plan()
	var site := _site(&"site.holy_spirit")
	assert_true(site != null, "site.holy_spirit loads")
	var nave := site.to_world(Vector2(18.0, -3.0))
	var choir := site.to_world(Vector2(34.0, -3.5))
	assert_eq(plan.site_room_at(nave)["room"]["id"], &"room.nave")
	assert_eq(plan.site_room_at(choir)["room"]["id"], &"room.choir")
	assert_almost_eq(
		plan.walk_height(choir) - plan.walk_height(nave), 0.25, 0.001, "choir one step up"
	)
	var glazed := 0
	for w: Dictionary in site.data["fabric"]:
		for op: Dictionary in w.get("openings", []):
			glazed += 1 if bool(op.get("glass", false)) else 0
	assert_true(glazed >= 10, "nave and choir lancets carry stained glass")
	assert_eq(site.data["presentation"][0]["what"], "west tower (1360) with a shingled helm")
