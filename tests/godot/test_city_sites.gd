extends "res://tests/godot/test_case.gd"

## Landmark sites in the seamless city (ADR 0032): registry, compiled
## placement, replaced buildings, floors, rooms, HUD names and doors.

const RAEKOJA_BUILDER := preload("res://scripts/city/sites/raekoja_plats_builder.gd")
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


func test_council_hall_flag_hides_with_the_roof() -> void:
	# R-1702: the ridge flag lives under Roof, so the interior roof-hide takes it too.
	var built: Node3D = RAEKOJA_BUILDER.build(_site(&"site.raekoja_plats"), _plan())
	var roof := built.get_node("CouncilHall/Roof")
	var flag := roof.get_node_or_null("RidgeFlag") as Node3D
	assert_true(flag != null, "town hall ridge flag exists")
	assert_true(roof.get_node_or_null("RidgeFlagStaff") != null, "ridge flag staff exists")
	if flag != null:
		assert_true(flag.position.y > 6.0, "flag flies above the ridge")
		assert_true(absf(flag.position.x) < 13.0, "flag stands within the hall length")


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
	if shafts != null:
		# The shafts take their colour from the panels, so they carry the
		# glass layout (CUSTOM0) and the point on the glass (CUSTOM1).
		var arrays := (shafts.mesh as ArrayMesh).surface_get_arrays(0)
		var layout := arrays[Mesh.ARRAY_CUSTOM0] as PackedFloat32Array
		var verts := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		assert_eq(layout.size(), verts.size() * 4, "glass layout per shaft vertex")
		assert_true(layout[1] >= 1.0 and layout[0] > 0.0, "layout holds lights and width")
	if overlay is ShaderMaterial:
		var count := int((overlay as ShaderMaterial).get_shader_parameter("occluder_count"))
		# 6 piers x 2 boxes + 2 per bench, then the wall blocks.
		var benches: int = (olaf.data.get("benches", []) as Array).size()
		assert_true(count > 12 + benches * 2, "piers, benches and walls shade the light")
		assert_true(count <= ChurchSunlight.MAX_OCCLUDERS, "occluders fit the cap")
		assert_true(
			(overlay as ShaderMaterial).get_shader_parameter("occluders") is ImageTexture,
			"occluders are uploaded"
		)
	built.free()


func test_church_sunlight_occluders() -> void:
	# R-1474: the boxes the window light is tested against are solid where
	# the fabric is (arcade piers) and open at every opening (glass, arches).
	var spirit := _site(&"site.holy_spirit")
	var fabric: Array = spirit.data["fabric"]
	var pier := AABB(Vector3(10.0, 0.0, 0.0), Vector3(1.5, 7.0, 1.5))
	var boxes := ChurchSunlight.occluder_boxes(fabric, [pier])
	assert_true(_in_any_box(boxes, Vector3(10.75, 3.0, 0.75)), "extra box kept as given")
	# Arcade (a = (1.2, 1.24), along +x, 1.2 thick): arches cover 1.0..5.8
	# and 7.0..11.8 from a, so 6.4 is a pier and 3.4 an arch.
	assert_true(_in_any_box(boxes, Vector3(1.2 + 6.4, 2.0, 1.84)), "arcade pier is solid")
	assert_false(_in_any_box(boxes, Vector3(1.2 + 3.4, 2.0, 1.84)), "arcade arch is open")
	for win: Dictionary in ChurchSunlight.windows(fabric, 0):
		var o: Vector3 = win["origin"]
		var dir: Vector2 = win["dir"]
		var c := o + Vector3(dir.x, 0.0, dir.y) * float(win["width"]) * 0.5
		c.y += float(win["spring"]) * 0.5
		assert_false(_in_any_box(boxes, c), "window glass is not inside a wall block")


static func _in_any_box(boxes: Array[Dictionary], p: Vector3) -> bool:
	for box: Dictionary in boxes:
		var q: Vector3 = p - box["centre"]
		var d: Vector2 = box["dir"]
		var h: Vector3 = box["half"]
		var local := Vector3(q.x * d.x + q.z * d.y, q.y, -q.x * d.y + q.z * d.x)
		if absf(local.x) < h.x and absf(local.y) < h.y and absf(local.z) < h.z:
			return true
	return false


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


## Player-reported stuck spot: slots between nave benches and piers must be
## either shut or wide enough for Kalev's footprint, the middle aisle open,
## and the nave west wall closed either side of the tower arch.
func test_st_nicholas_nave_is_walkable_and_west_wall_closed() -> void:
	var site := _site(&"site.st_nicholas")
	var foot := MapVisualStyle.CHARACTER_FOOTPRINT_PX / CityPlan.LOGIC_PX_PER_UNIT
	var nave := Rect2(-22.6, -18.6, 31.2, 21.2)
	var boxes: Array[Rect2] = []
	for poly: Array in site.data["walk"]["solid"]:
		var r := Rect2(Vector2(poly[0][0], poly[0][1]), Vector2.ZERO)
		for p: Array in poly:
			r = r.expand(Vector2(p[0], p[1]))
		if nave.encloses(r):
			boxes.append(r)
	for i in boxes.size():
		for j in range(i + 1, boxes.size()):
			var a := boxes[i]
			var b := boxes[j]
			var z_gap := maxf(b.position.y - a.end.y, a.position.y - b.end.y)
			var x_gap := maxf(b.position.x - a.end.x, a.position.x - b.end.x)
			if x_gap < 0.0 and z_gap > 0.0:
				assert_true(
					z_gap < foot.y or z_gap > foot.y + 0.25, "snag slot %s / %s" % [a, b]
				)
			if z_gap < 0.0 and x_gap > 0.0:
				assert_true(
					x_gap < foot.x or x_gap > foot.x + 0.2, "snag slot %s / %s" % [a, b]
				)
	# Middle aisle between the north and south nave benches.
	var north_end := -INF
	var south_start := INF
	for b: Dictionary in site.data["benches"]:
		var z := float(b["at"][1])
		if z > -11.0 and z < -5.0:
			if z < -8.0:
				north_end = maxf(north_end, z + float(b["len"]) * 0.5)
			else:
				south_start = minf(south_start, z - float(b["len"]) * 0.5)
	assert_true(south_start - north_end > foot.y + 0.6, "middle aisle is a real aisle")
	var plan := _plan()
	assert_almost_eq(
		plan.walk_height(site.to_world(Vector2(-23.3, -8.0))), site.level + 0.12, 0.001
	)
	var mid_wall := false
	for w: Dictionary in site.data["fabric"]:
		mid_wall = mid_wall or String(w["id"]) == "nave.west.mid"
	assert_true(mid_wall, "nave west wall runs across the tower front")


## Player-reported: Kalev could not get between the Holy Spirit nave benches.
## The site is turned ~26 deg, so Kalev's axis-aligned box is wider across the
## site's gaps than its own size: every gap must be shut or clear that width.
func test_holy_spirit_nave_benches_leave_walkable_aisles() -> void:
	var site := _site(&"site.holy_spirit")
	var foot := MapVisualStyle.CHARACTER_FOOTPRINT_PX / CityPlan.LOGIC_PX_PER_UNIT
	var c := absf(cos(site.rotation))
	var s := absf(sin(site.rotation))
	# Box extent along the site's x and z axes.
	var across_x := foot.x * c + foot.y * s
	var across_z := foot.x * s + foot.y * c
	var nave := Rect2(1.2, -7.0, 35.6, 14.0)
	var boxes: Array[Rect2] = []
	for poly: Array in site.data["walk"]["solid"]:
		var r := Rect2(Vector2(poly[0][0], poly[0][1]), Vector2.ZERO)
		for p: Array in poly:
			r = r.expand(Vector2(p[0], p[1]))
		if nave.encloses(r):
			boxes.append(r)
	# Arcade piers (1.2 m deep, south of the arcade line) and the aisle walls.
	boxes.append(Rect2(1.2, 1.24, 35.6, 1.2))
	boxes.append(Rect2(1.2, -8.2, 35.6, 1.2))
	boxes.append(Rect2(1.2, 7.0, 35.6, 1.2))
	for i in boxes.size():
		for j in range(i + 1, boxes.size()):
			var a := boxes[i]
			var b := boxes[j]
			var z_gap := maxf(b.position.y - a.end.y, a.position.y - b.end.y)
			var x_gap := maxf(b.position.x - a.end.x, a.position.x - b.end.x)
			if x_gap < 0.0 and z_gap > 0.0:
				assert_true(
					z_gap < across_z or z_gap > across_z + 0.3, "snag slot %s / %s" % [a, b]
				)
			if z_gap < 0.0 and x_gap > 0.0:
				assert_true(
					x_gap < across_x or x_gap > across_x + 0.3, "snag slot %s / %s" % [a, b]
				)
	# Middle aisle between the two north bench blocks.
	var wall_end := -INF
	var arcade_start := INF
	for b: Dictionary in site.data["benches"]:
		var z := float(b["at"][1])
		if z < -3.5:
			wall_end = maxf(wall_end, z + float(b["len"]) * 0.5)
		elif z < 0.0:
			arcade_start = minf(arcade_start, z - float(b["len"]) * 0.5)
	assert_true(arcade_start - wall_end > across_z + 0.6, "middle aisle is a real aisle")


## ADR 0052 opening: the almshouse is a furnished sick-room with the ids the
## New Game opening uses (spawn and three anchors), all on the room floor and
## clear of the beds and furniture.
func test_holy_spirit_almshouse_sick_room_and_opening_ids() -> void:
	var plan := _plan()
	var site := _site(&"site.holy_spirit")
	var spawn := CityTravel.site_spawn(plan, "holy_spirit_almshouse")
	assert_false(spawn.is_empty(), "the almshouse owns the holy_spirit_almshouse spawn")
	assert_true(CityTravel.SPAWNS.has(&"holy_spirit_almshouse"), "the city accepts the spawn")
	assert_true(
		DoorNavigator.has_spawn(&"reval_city", &"holy_spirit_almshouse"),
		"the transition manifest registers the spawn"
	)
	var start := CityTravel.spawn_position(plan, "holy_spirit_almshouse")
	assert_eq(plan.site_room_at(start)["room"]["id"], &"room.almshouse")
	var anchors := {}
	for a: Dictionary in site.data["anchors"]:
		anchors[String(a["id"])] = a
	var points: Array[Vector2] = [start]
	for id: String in [
		"anchor.holy_spirit.sickbed",
		"anchor.holy_spirit.sickbed_attendant",
		"anchor.holy_spirit.almshouse_kalev"
	]:
		assert_true(anchors.has(id), "%s exists" % id)
		var at := site.to_world(Vector2(anchors[id]["at"][0], anchors[id]["at"][1]))
		assert_eq(plan.site_room_at(at)["room"]["id"], &"room.almshouse", "%s in the room" % id)
		if id != "anchor.holy_spirit.sickbed":
			points.append(at)
	assert_eq(String(anchors["anchor.holy_spirit.sickbed"]["pose"]), "lie")
	for p in points:
		for poly in site.solids:
			assert_false(Geometry2D.is_point_in_polygon(p, poly), "%s is clear of furniture" % p)
	# The sickbed anchor lies on a bed; the room holds a row of beds.
	var bed := site.to_world(Vector2(44.6, 6.5))
	var on_bed := false
	for poly in site.solids:
		on_bed = on_bed or Geometry2D.is_point_in_polygon(bed, poly)
	assert_true(on_bed, "the sickbed anchor is on a bed")
	var beds := 0
	for item: Dictionary in site.data["dressing"]:
		beds += 1 if String(item.get("object", "")) == "obj.bed_straw_pallet" else 0
	assert_true(beds >= 6, "a row of beds (%d)" % beds)
	var node: Node3D = load(String(site.data["visual"]["script"])).call("build", site, plan)
	var dressing := node.get_node_or_null("Almshouse")
	assert_true(dressing != null and dressing.get_child_count() >= beds, "dressing is built")
	node.free()


func test_kalev_smithy_new_game_starts_inside_the_forge() -> void:
	var plan := _plan()
	var site := _site(&"site.kalev_smithy")
	assert_true(site != null, "site.kalev_smithy loads from the registry")
	for b: Dictionary in plan.buildings:
		assert_true(String(b["id"]) != "bldg.osm.r7239857", "the generic smithy house is replaced")
		assert_true(
			String(b.get("landmark_id", "")) != "landmark.kalev_smithy",
			"no generic house is tagged as the smithy any more"
		)
	# The new-game spawn (almshouse prologue, old forge redirect) is inside.
	var start := CityTravel.spawn_position(plan, "kalev_smithy")
	assert_eq(plan.site_room_at(start)["room"]["id"], &"room.forge")
	assert_eq(plan.location_at(start)["building"], "Inside: Kalev's smithy (forge)")
	assert_almost_eq(plan.walk_height(start), site.level + 0.12, 0.001)
	var spawn := CityTravel.site_spawn(plan, "kalev_smithy")
	assert_false(spawn.is_empty(), "the smithy owns the kalev_smithy spawn and its facing")
	for poly in site.solids:
		assert_false(
			Geometry2D.is_point_in_polygon(start, poly), "Kalev does not start inside furniture"
		)
	# The partition door joins the living bay; the street door opens onto the lane.
	var living := site.to_world(Vector2(3.0, 6.0))
	assert_eq(plan.site_room_at(living)["room"]["id"], &"room.living")


func test_kalev_smithy_model_reuses_the_old_forge_kit() -> void:
	var site := _site(&"site.kalev_smithy")
	var script := load(String(site.data["visual"]["script"])) as Script
	var node: Node3D = script.call("build", site, _plan())
	for path: String in ["Smithy/Lower", "Smithy/Upper", "Smithy/Roof", "Smithy/Furnishings"]:
		assert_true(node.get_node_or_null(path) != null, "%s exists" % path)
	var furnishings := node.get_node("Smithy/Furnishings")
	for name: String in [
		"forge_hearth", "forge_bellows", "forge_anvil", "forge_slack_tub", "forge_stock_rack"
	]:
		assert_true(furnishings.get_node_or_null(name) != null, "forge kit piece %s" % name)
	var hearth := furnishings.get_node("forge_hearth")
	assert_false(
		hearth.find_children("ForgeFireLight", "", true, false).is_empty(),
		"the hearth carries the live forge fire"
	)
	assert_false((node.get_meta(&"chimneys", []) as Array).is_empty(), "the stack smokes")
	node.free()
