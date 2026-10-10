extends "res://tests/godot/test_case.gd"

## R-1539: exterior rain must stop at the door. The seamless city answers the
## plan's roof test every frame and gates the shared SkyWeather3D exactly like
## the map path gates enclosed room shells: the falling-rain emitter and the
## exterior rain ambience stay off, the muffled roof-drum bed takes over.


func _plan() -> CityPlan:
	return CityPlan.load_default()


func _room_center(plan: CityPlan, site_id: String, room_id: String) -> Vector2:
	for site in plan.sites:
		if String(site.id) != site_id:
			continue
		for r: Dictionary in site.rooms:
			if String(r["id"]) != room_id:
				continue
			var poly: PackedVector2Array = r["polygon"]
			var sum := Vector2.ZERO
			for p in poly:
				sum += p
			return sum / poly.size()
	return Vector2.INF


func _house_inside(plan: CityPlan) -> Vector2:
	for i in plan.buildings.size():
		if not bool(plan.buildings[i].get("enterable", false)):
			continue
		var rect := Rect2(plan.footprint(i)[0], Vector2.ZERO)
		for p in plan.footprint(i):
			rect = rect.expand(p)
		for y in range(5):
			for x in range(5):
				var q := Vector2(
					lerpf(rect.position.x, rect.end.x, (x + 0.5) / 5.0),
					lerpf(rect.position.y, rect.end.y, (y + 0.5) / 5.0)
				)
				if plan.building_at(q) == i:
					return q
	return Vector2.INF


func test_under_roof_covers_rooms_and_houses_but_not_open_ground() -> void:
	var plan := _plan()
	var nave := _room_center(plan, "site.holy_spirit", "room.nave")
	assert_true(nave != Vector2.INF, "precondition: the Holy Spirit nave exists")
	assert_true(plan.is_under_roof(nave), "the nave stands under its roof")
	var house := _house_inside(plan)
	assert_true(house != Vector2.INF, "precondition: an enterable house interior exists")
	assert_true(plan.is_under_roof(house), "a house interior stands under its roof")
	assert_false(plan.is_under_roof(Vector2(-4000.0, -4000.0)), "open ground sees the sky")


func test_city_world_gates_the_shared_weather_under_a_roof() -> void:
	var world := CityWorld3D.new()
	var sky := SkyWeather3D.new()
	world.sky_weather = sky
	world.set_enclosed_interior(true)
	assert_true(world.enclosed_interior, "the city remembers the roof state")
	assert_true(sky.rain_suppressed, "indoors the exterior rain emitter is gated")
	assert_false(sky.rain_emitter_visible(), "no rain streaks fall under a roof")
	world.set_enclosed_interior(false)
	assert_false(world.enclosed_interior, "stepping outside clears the roof state")
	assert_false(sky.rain_suppressed, "outdoors the rain returns")
	sky.free()
	world.free()
