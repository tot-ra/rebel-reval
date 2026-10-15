extends "res://tests/godot/test_case.gd"

## St Catherine's Dominican friary as an ADR 0032 landmark site (R-1718, with
## R-1727 and R-1124): registry and placement, the close cleared of strip
## houses, rooms and HUD names, doors, the profiled west portal and the
## 1343 massing (no tower).

const BUILDER := preload("res://scripts/city/sites/st_catherine_builder.gd")


func _plan() -> CityPlan:
	return CityPlan.load_default()


func _site(plan: CityPlan) -> CitySite:
	for site in plan.sites:
		if site.id == &"site.st_catherine":
			return site
	return null


func test_st_catherine_registered_and_placed() -> void:
	var plan := _plan()
	var site := _site(plan)
	assert_true(site != null, "site.st_catherine loads from the registry with a compiled placement")
	if site == null:
		return
	assert_true(
		site.level > 9.0 and site.level < 14.0,
		"terrace level comes from the lane at the south door"
	)
	var church := site.to_world(Vector2(39.0, -10.0))
	assert_true(site.occupies(church), "the church footprint covers the nave")
	assert_true(site.data["presentation"].is_empty(), "strict 1343: no presentation exceptions")


func test_st_catherine_close_has_no_strip_houses() -> void:
	var plan := _plan()
	var site := _site(plan)
	if site == null:
		assert_true(false, "site.st_catherine loads")
		return
	var close := site.world_polygon(site.data["close"]["polygon"])
	var ids := {}
	for i in plan.buildings.size():
		ids[String(plan.buildings[i]["id"])] = true
		var ring := plan.footprint(i)
		var c := Vector2.ZERO
		for p in ring:
			c += p
		c /= float(ring.size())
		assert_true(
			not Geometry2D.is_point_in_polygon(c, close),
			"%s stands inside the friary close" % plan.buildings[i]["id"]
		)
		var overlap := 0.0
		for piece in Geometry2D.intersect_polygons(ring, close):
			overlap += absf(CityBuildingBuilder.signed_area(piece))
		var id := String(plan.buildings[i]["id"])
		assert_true(overlap <= 1.0, "%s overlaps the close by %.1f m²" % [id, overlap])
	for rid: String in site.data["replaces"]:
		assert_true(not ids.has(rid), "%s is replaced by the friary" % rid)


func test_st_catherine_rooms_and_hud_names() -> void:
	var plan := _plan()
	var site := _site(plan)
	if site == null:
		assert_true(false, "site.st_catherine loads")
		return
	for probe: Array in [
		[Vector2(30.0, -10.0), &"room.nave"],
		[Vector2(57.0, -10.0), &"room.choir"],
		[Vector2(30.0, -20.0), &"room.cloister_south"],
		[Vector2(30.0, -41.5), &"room.cloister_north"],
		[Vector2(16.5, -30.0), &"room.cloister_west"],
		[Vector2(50.5, -30.0), &"room.cloister_east"],
	]:
		assert_eq(plan.site_room_at(site.to_world(probe[0]))["room"]["id"], probe[1])
	var choir := plan.walk_height(site.to_world(Vector2(57.0, -10.0)))
	var nave := plan.walk_height(site.to_world(Vector2(30.0, -10.0)))
	assert_true(absf(choir - nave - 0.45) < 0.05, "the friars' choir is three steps above the nave")
	var garth := plan.site_room_at(site.to_world(Vector2(33.0, -30.0)))
	assert_true(garth.is_empty(), "the garth is open ground")


func test_st_catherine_doors_and_west_portal() -> void:
	var plan := _plan()
	var site := _site(plan)
	if site == null:
		assert_true(false, "site.st_catherine loads")
		return
	var ids: Array = []
	for d: Dictionary in site.doors:
		ids.append(String(d["id"]))
	for id: String in [
		"door.st_catherine.west", "door.st_catherine.south", "door.st_catherine.cloister"
	]:
		assert_true(id in ids, "%s hangs a leaf" % id)
	var portal := false
	for w: Dictionary in site.data["fabric"]:
		if String(w["id"]) == "church.west":
			for op: Dictionary in w["openings"]:
				portal = portal or op.has("portal")
	assert_true(portal, "the west door opening is a profiled portal (CitySitePortals)")
	# The precinct gate and the yard gate are open arches in the close wall.
	var gates := 0
	for w: Dictionary in site.data["fabric"]:
		if String(w["id"]).begins_with("precinct."):
			for op: Dictionary in w.get("openings", []):
				if String(op["kind"]) == "arch" and float(op["w"]) >= 1.4:
					gates += 1
	assert_eq(gates, 2, "the close has a west gate and a yard gate")


func test_st_catherine_model_has_no_tower() -> void:
	var plan := _plan()
	var site := _site(plan)
	if site == null:
		assert_true(false, "site.st_catherine loads")
		return
	var root: Node3D = BUILDER.build(site, plan)
	for path: String in [
		"Church/Lower",
		"Church/Upper",
		"Church/Roof",
		"Cloister/Roof",
		"Ranges",
		"Precinct",
		"GarthWell",
		"Yard",
	]:
		assert_true(root.get_node_or_null(path) != null, "the friary model has %s" % path)
	var roof := root.get_node("Church/Roof") as MeshInstance3D
	var top := roof.mesh.get_aabb().end.y
	# Ridge 19.5 m plus the small bell turret and its cross; a tower would be 30 m+.
	assert_true(top < 26.0, "mendicant church: ridge turret only, no tower (top %.1f m)" % top)
	assert_eq(root.get_meta(&"chimneys", []).size(), 1, "the kitchen stack smokes")
	root.free()


func test_st_catherine_range_rooms_open_from_the_cloister() -> void:
	var plan := _plan()
	var site := _site(plan)
	if site == null:
		assert_true(false, "site.st_catherine loads")
		return
	var ids: Array = []
	for d: Dictionary in site.doors:
		ids.append(String(d["id"]))
	for room: String in [
		"sacristy",
		"chapter_house",
		"dorter_stair",
		"refectory",
		"kitchen",
		"stores",
		"infirmary",
		"granary",
		"lay_hall"
	]:
		assert_true("door.st_catherine.%s" % room in ids, "%s has a door" % room)
	for probe: Array in [
		[Vector2(55.0, -29.1), &"room.chapter_house"],
		[Vector2(57.0, -44.0), &"room.refectory"],
		[Vector2(24.0, -47.5), &"room.kitchen"],
		[Vector2(10.75, -36.0), &"room.lay_hall"],
		[Vector2(57.0, -21.0), &"room.sacristy"],
	]:
		assert_eq(plan.site_room_at(site.to_world(probe[0]))["room"]["id"], probe[1])


func test_st_catherine_friars_keep_the_hours() -> void:
	var plan := _plan()
	var site := _site(plan)
	var roster := CitizenRoster.load_default()
	if site == null or roster == null:
		assert_true(false, "site and citizen roster load")
		return
	var friars: Array[int] = []
	for i in roster.count():
		var r: Dictionary = roster.residents[i]
		if String(r["household"]) == "hh.inst_st_catherine_friary" and String(r["trade"]) == "monk":
			friars.append(i)
	assert_eq(friars.size(), 24, "the census friars live in the friary")
	for i in friars:
		var terce := roster.resolve(i, 9.6)
		var room := plan.site_room_at(terce["pos"])
		assert_true(
			not room.is_empty() and room["room"]["id"] == &"room.choir",
			"%s sings terce in the choir" % roster.residents[i]["name"]
		)
		assert_false(
			bool(roster.resolve(i, 3.6)["visible"]), "back in the dormitory after the night office"
		)
		var dinner := plan.site_room_at(roster.resolve(i, 11.9)["pos"])
		assert_true(
			not dinner.is_empty() and dinner["room"]["id"] == &"room.refectory",
			"%s dines in the refectory" % roster.residents[i]["name"]
		)
		var cloth: Array = roster.residents[i]["cloth"]
		assert_true(absf(float(cloth[0]) - 0.84) < 0.01, "white habit")


## ADR 0052: the infirmary (plausible composite) at the east end of the north
## range, its anchor and spawn, opening from the cloister towards the physic bed.
func test_st_catherine_infirmary_room_spawn_and_physic_bed() -> void:
	var plan := _plan()
	var site := _site(plan)
	if site == null:
		assert_true(false, "site.st_catherine loads")
		return
	var spawn := CityTravel.spawn_position(plan, "st_catherine_infirmary")
	assert_false(CityTravel.site_spawn(plan, "st_catherine_infirmary").is_empty())
	assert_true(DoorNavigator.has_spawn(&"reval_city", &"st_catherine_infirmary"))
	assert_eq(plan.site_room_at(spawn)["room"]["id"], &"room.infirmary")
	assert_eq(plan.site_room_at(site.to_world(Vector2(41.0, -47.0)))["room"]["id"], &"room.stores")
	var anchor := Vector2.INF
	for a: Dictionary in site.data["anchors"]:
		if String(a["id"]) == "anchor.st_catherine.infirmary":
			anchor = site.to_world(Vector2(a["at"][0], a["at"][1]))
	assert_true(anchor != Vector2.INF, "anchor.st_catherine.infirmary exists")
	assert_eq(plan.site_room_at(anchor)["room"]["id"], &"room.infirmary")
	for p: Vector2 in [spawn, anchor]:
		for poly in site.solids:
			assert_false(Geometry2D.is_point_in_polygon(p, poly), "%s is clear of furniture" % p)
	var beds := 0
	for item: Dictionary in site.data["dressing"]:
		if String(item["id"]).begins_with("infirmary.bed"):
			beds += 1
	assert_true(beds >= 3, "the infirmary has beds")
	var physic := false
	for b: Dictionary in site.data["garth"]["herb_beds"]:
		physic = physic or String(b.get("serves", "")) == "room.infirmary"
	assert_true(physic, "a garth herb bed serves the infirmary")
	var notes := " ".join(PackedStringArray(site.data["period_notes"]))
	assert_true(notes.contains("Infirmary") and notes.contains("plausible composite"))
