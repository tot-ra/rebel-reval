extends "res://tests/godot/test_case.gd"

## Landmark sites in the seamless city (ADR 0032): registry, compiled
## placement, replaced buildings, floors, rooms, HUD names and doors.

const ST_OLAF_BUILDER := preload("res://scripts/city/sites/st_olaf_builder.gd")


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


func test_sites_carry_no_posted_people() -> void:
	# Only census citizens (clickable, with a card) populate the city; posted
	# nameless site bodies were removed, so a site manifest must not list any.
	for id: StringName in [&"site.raekoja_plats", &"site.holy_spirit"]:
		assert_true(_site(id).people.is_empty(), "%s has no nameless posted people" % id)


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
	var choir := site.to_world(Vector2(43.0, -3.5))
	assert_eq(plan.site_room_at(nave)["room"]["id"], &"room.nave")
	assert_eq(plan.site_room_at(choir)["room"]["id"], &"room.choir")
	assert_almost_eq(
		plan.walk_height(choir) - plan.walk_height(nave), 0.45, 0.001, "choir up three steps"
	)
	var mid_steps := site.to_world(Vector2(36.3, -3.0))
	var h := plan.walk_height(mid_steps) - plan.walk_height(nave)
	assert_true(h > 0.05 and h < 0.4, "the steps rise between nave and choir")
	var glazed := 0
	for w: Dictionary in site.data["fabric"]:
		for op: Dictionary in w.get("openings", []):
			glazed += 1 if bool(op.get("glass", false)) else 0
	assert_true(glazed >= 10, "nave and choir lancets carry stained glass")
	assert_true(site.data["presentation"].is_empty(), "strict 1343: no presentation exceptions")


func test_st_olaf_hall_tower_and_period_rule() -> void:
	var plan := _plan()
	var site := _site(&"site.st_olaf")
	assert_true(site != null, "site.st_olaf loads")
	assert_eq(plan.site_room_at(site.to_world(Vector2(25.0, 0.0)))["room"]["id"], &"room.nave")
	assert_eq(plan.site_room_at(site.to_world(Vector2(7.0, 0.0)))["room"]["id"], &"room.tower")
	assert_eq(plan.site_room_at(site.to_world(Vector2(49.0, 0.0)))["room"]["id"], &"room.choir")
	var tower_top := 0.0
	for w: Dictionary in site.data["fabric"]:
		if String(w["id"]).begins_with("tower."):
			tower_top = maxf(tower_top, float(w["y1"]))
			assert_almost_eq(float(w["thick"]), 3.2, 0.001, "tower walls ~3.2 m (dossier)")
	assert_true(tower_top <= 31.0, "the tower stops at its lower stage (upper tower 1364+)")
	assert_true(site.data["presentation"].is_empty(), "strict 1343: no presentation exceptions")


func test_church_murals_crosses_and_dado() -> void:
	# R-1396: twelve consecration crosses on the lime-washed walls, painted
	# dado plates on them, and no murals on the St Mary building site.
	var olaf := _site(&"site.st_olaf")
	var spots := ChurchMurals.cross_spots(olaf.data["fabric"])
	assert_eq(spots.size(), 12, "St Olaf: twelve consecration crosses")
	for spot: Array in spots:
		assert_true((spot[1] as Vector3).is_normalized(), "cross faces into the room")
	var built: Node3D = ST_OLAF_BUILDER.build(olaf, _plan())
	# The dado sits below the interior cutaway, the crosses above it.
	var low := built.get_node_or_null("Church/Lower/Murals") as MeshInstance3D
	var high := built.get_node_or_null("Church/Upper/Murals") as MeshInstance3D
	assert_true(low != null and high != null, "St Olaf has mural layers on both sides of the cut")
	if low != null and high != null:
		assert_eq(low.mesh.get_surface_count(), 2, "drapery and foliage plates")
		assert_eq(high.mesh.get_surface_count(), 1, "consecration cross plate")
	built.free()
	var mary: Node3D = load("res://scripts/city/sites/st_mary_builder.gd").build(
		_site(&"site.st_mary"), _plan()
	)
	assert_true(mary.find_child("Murals", true, false) == null, "St Mary is unpainted")
	mary.free()


func test_church_sunlight_through_glass() -> void:
	# R-1451: the roof, upper walls and upper glass keep shadow proxies under
	# the cutaway, the interior carries the coloured-light overlay and every
	# window a shaft.
	var olaf := _site(&"site.st_olaf")
	var fabric: Array = olaf.data["fabric"]
	var glazed := 0
	for w: Dictionary in fabric:
		for op: Dictionary in w.get("openings", []):
			if bool(op.get("glass", false)):
				glazed += 1
	var wins := ChurchSunlight.windows(fabric, 1)
	assert_eq(
		wins.size(), mini(glazed, ChurchSunlight.MAX_WINDOWS), "one record per glazed opening"
	)
	for win: Dictionary in wins:
		assert_true(float(win["depth"]) > 1.0, "window looks into a room")
		assert_eq(int(win["code"]) / 16, 1, "St Olaf glazing programme")
		var out: Vector2 = win["out"]
		assert_true(out.is_normalized(), "outward normal is unit length")
	var built: Node3D = ST_OLAF_BUILDER.build(olaf, _plan())
	for part: String in ["Roof", "Upper", "Upper/Glass"]:
		var node := built.get_node("Church/" + part) as MeshInstance3D
		var proxy := (
			built.get_node_or_null("Church/" + part.get_file() + "Shadow") as MeshInstance3D
		)
		assert_true(proxy != null, "%s keeps a shadow proxy" % part)
		if proxy != null:
			assert_eq(proxy.mesh, node.mesh, "proxy shares the mesh")
			assert_eq(proxy.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)
		assert_eq(
			node.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "no double shadow"
		)
	var overlay := (built.get_node("Church/Lower") as MeshInstance3D).material_overlay
	assert_true(overlay is ShaderMaterial, "interior carries the sunlight overlay")
	if overlay is ShaderMaterial:
		assert_eq((overlay as ShaderMaterial).shader, ChurchSunlight.SUNLIGHT)
		assert_eq((overlay as ShaderMaterial).get_shader_parameter("window_count"), wins.size())
	assert_true(
		(built.get_node("Church/Lower/GlassLow") as MeshInstance3D).material_overlay == null,
		"glass itself is not tinted"
	)
	var shafts := built.get_node_or_null("Church/SunShafts") as MeshInstance3D
	assert_true(shafts != null and shafts.mesh.get_surface_count() == 1, "one shaft mesh")
	built.free()


func test_church_walls_are_dimmed() -> void:
	# R-1472: church washes use the dim church level, not the 0.82 default.
	var built: Node3D = ST_OLAF_BUILDER.build(_site(&"site.st_olaf"), _plan())
	var lower := built.get_node("Church/Lower") as MeshInstance3D
	var found := false
	for k in lower.mesh.get_surface_count():
		var mat := lower.get_surface_override_material(k)
		if mat is ShaderMaterial and (mat as ShaderMaterial).get_shader_parameter("indoor_ao") != null:
			found = true
			assert_eq(
				float((mat as ShaderMaterial).get_shader_parameter("indoor_ao")),
				CitySiteKit.CHURCH_WASH_BRIGHTNESS,
				"church wash is dimmed"
			)
	assert_true(found, "church lower walls carry a bound wash")
	assert_true(CitySiteKit.CHURCH_WASH_BRIGHTNESS < 0.82, "dimmer than the default indoor wash")
	built.free()


func test_st_nicholas_rooms_chapel_and_period_rule() -> void:
	var plan := _plan()
	var site := _site(&"site.st_nicholas")
	assert_true(site != null, "site.st_nicholas loads")
	for probe: Array in [
		[Vector2(-8.0, -8.0), &"room.nave"],
		[Vector2(-29.0, -8.0), &"room.tower"],
		[Vector2(16.0, -8.0), &"room.choir"],
		[Vector2(14.5, -15.5), &"room.sacristy"],
		[Vector2(-10.0, -22.0), &"room.porch"],
		[Vector2(10.0, 13.0), &"room.barbara"],
	]:
		assert_eq(plan.site_room_at(site.to_world(probe[0]))["room"]["id"], probe[1])
	var chapel := plan.walk_height(site.to_world(Vector2(10.0, 13.0)))
	var yard := plan.ground_height(site.to_world(Vector2(0.0, 20.0)))
	assert_true(
		absf(chapel - 0.12 - yard) < 0.3, "the charnel chapel stands on the levelled churchyard"
	)
	assert_true(site.data["presentation"].is_empty(), "strict 1343: no presentation exceptions")


func test_st_mary_building_site_state() -> void:
	var plan := _plan()
	var site := _site(&"site.st_mary")
	assert_true(site != null, "site.st_mary loads")
	assert_eq(plan.site_room_at(site.to_world(Vector2(5.0, -5.0)))["room"]["id"], &"room.chancel")
	assert_eq(
		plan.site_room_at(site.to_world(Vector2(-10.0, -5.0)))["room"]["id"], &"room.finished_bay"
	)
	assert_eq(plan.site_room_at(site.to_world(Vector2(-25.0, -12.0)))["room"]["id"], &"room.site")
	# Walls rise from west to east: the finished bay is the tallest.
	var heights := {}
	for w: Dictionary in site.data["fabric"]:
		if String(w["id"]).begins_with("north.bay"):
			heights[w["id"]] = float(w["y1"])
	assert_true(heights["north.bay1"] > heights["north.bay2"], "east bay finished first")
	assert_true(heights["north.bay3"] > heights["north.bay4"], "west front lowest")
	assert_true(site.data["presentation"].is_empty(), "strict 1343: no presentation exceptions")
