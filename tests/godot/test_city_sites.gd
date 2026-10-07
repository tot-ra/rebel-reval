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
	var inside := site.to_world(Vector2(0.0, 2.0))
	assert_almost_eq(plan.walk_height(inside), site.level + 0.12, 0.001)
	var room := plan.site_room_at(inside)
	assert_eq(room["room"]["id"], &"room.council_hall")
	assert_eq(plan.location_at(inside)["building"], "Inside: Council hall")
	var outside := site.to_world(Vector2(0.0, -20.0))
	assert_true(plan.site_room_at(outside).is_empty(), "the forum is not inside the hall")


func test_door_gap_leads_from_the_forum_onto_the_floor() -> void:
	var site := _site(&"site.raekoja_plats")
	var d: Dictionary = site.doors[0]
	var mid: Vector2 = (d["a"] + d["b"]) * 0.5
	var inward: Vector2 = d["inward"]
	assert_false(site.floor_at(mid + inward * 1.0).is_empty(), "inside the door is hall floor")
	assert_true(site.floor_at(mid - inward * 1.0).is_empty(), "outside the door is the forum")
