extends "res://tests/godot/test_case.gd"

## ADR 0031: the continuous Reval 1343 plan, its terrain, fortifications,
## enterable buildings and logic collision.

const Fort := preload("res://scripts/city/city_fortification_builder.gd")


func _plan() -> CityPlan:
	return CityPlan.load_default()


func test_plan_loads_with_heightfield_and_buildings() -> void:
	var plan := _plan()
	assert_eq(String(plan.data.get("schema", "")), CityPlan.SCHEMA)
	assert_true(plan.buildings.size() > 400, "walled town and Toompea plots")
	assert_true(plan.streets.size() > 80)
	var size := plan.height_grid_size()
	assert_true(size.x > 500 and size.y > 500)
	assert_almost_eq(plan.metres_per_unit, 1.0, 0.001)


func test_toompea_stands_above_the_forum_and_the_sea_is_below_the_coastal_gate() -> void:
	var plan := _plan()
	var mpu := plan.metres_per_unit
	var forum := plan.ground_height(Vector2(5, -10) / mpu) * mpu
	var lossi := plan.ground_height(Vector2(-370, 175) / mpu) * mpu
	var coastal_gate: Dictionary = plan.gate("gate.coastal")
	var gate_h := plan.ground_height(Vector2(coastal_gate["at"][0], coastal_gate["at"][1])) * mpu
	var lift := lossi - forum
	# H01/H12, ADR 0029 relief target: the table stands ~19-26 m over the town.
	assert_true(lift > 18.0 and lift < 30.0, "Toompea lift %.1f m" % lift)
	# H11: the Coastal Gate stands 5-8 m above the 1343 harbour ground.
	assert_true(gate_h > 3.0 and gate_h < 10.0, "Coastal Gate %.1f m above the 1343 sea" % gate_h)
	var beach := plan.ground_height(
		Vector2(coastal_gate["at"][0], coastal_gate["at"][1] - 110.0 / mpu)
	)
	assert_true(beach < 1.0, "the shore lies north of the Coastal Gate")


func test_hill_ways_climb_steadily() -> void:
	var plan := _plan()
	for name: String in ["Pikk jalg", "Lühike jalg"]:
		var points := PackedVector2Array()
		for s: Dictionary in plan.streets:
			if s["name"] == name:
				points.append_array(CityPlan.points(s["points"]))
		assert_true(points.size() >= 4, "%s is in the plan" % name)
		var lo := INF
		var hi := -INF
		for p in points:
			var h := plan.ground_height(p)
			lo = minf(lo, h)
			hi = maxf(hi, h)
		assert_true((hi - lo) * plan.metres_per_unit > 10.0, "%s climbs the klint" % name)


func test_eight_gates_with_1343_states() -> void:
	var plan := _plan()
	var gates: Array = plan.data["gates"]
	assert_eq(gates.size(), 8)
	var states := {}
	for g: Dictionary in gates:
		states[g["id"]] = g["state"]
	assert_eq(states["gate.long_hill"], "wooden", "Long Leg gate is wooden until 1380")
	assert_eq(states["gate.short_hill"], "wooden")
	assert_eq(states["gate.viru"], "unfinished", "no 1370s Viru foregate")


func test_no_post_1343_towers_are_built() -> void:
	var plan := _plan()
	var ids: Array = []
	for t: Dictionary in plan.data["towers"]:
		ids.append(t["id"])
	for forbidden: String in [
		"tower.fat_margaret", "tower.kiek_in_de_kok", "tower.neitsitorn", "tower.pikk_hermann"
	]:
		assert_false(ids.has(forbidden), "%s postdates spring 1343" % forbidden)
	for required: String in [
		"tower.nunnatorn", "tower.kuldjala", "tower.rentenitorn", "tower.stolting"
	]:
		assert_true(ids.has(required), "%s stands in 1343" % required)
	for b: Dictionary in plan.buildings:
		var name := String(b.get("name_1343", ""))
		assert_false(name.contains("Margaret"), "no Fat Margaret building")


func test_building_lookup_and_floor_height() -> void:
	var plan := _plan()
	var found := -1
	for i in plan.buildings.size():
		if bool(plan.buildings[i]["enterable"]):
			found = i
			break
	assert_true(found >= 0)
	var ring := plan.footprint(found)
	var centroid := Vector2.ZERO
	for p in ring:
		centroid += p
	centroid /= ring.size()
	if Geometry2D.is_point_in_polygon(centroid, ring):
		assert_eq(plan.building_at(centroid), found)
		assert_almost_eq(plan.walk_height(centroid), plan.floor_height(found), 0.001)
	# The floor never sits below the ground anywhere under the footprint.
	for p in ring:
		assert_true(plan.floor_height(found) >= plan.ground_height(p) - 0.01)


func test_enterable_house_interior_matches_exterior_minus_wall() -> void:
	var plan := _plan()
	for i in plan.buildings.size():
		var b: Dictionary = plan.buildings[i]
		if not bool(b["enterable"]) or String(b["material"]) == "limestone":
			continue
		var ring := CityBuildingBuilder.normalized_ring(plan.footprint(i))
		var inner: Array = Geometry2D.offset_polygon(
			ring, -CityBuildingBuilder.TIMBER_WALL, Geometry2D.JOIN_MITER
		)
		assert_false(inner.is_empty())
		var outer_area := absf(CityBuildingBuilder.signed_area(ring))
		var inner_area := absf(CityBuildingBuilder.signed_area(inner[0]))
		var perimeter := 0.0
		for k in ring.size():
			perimeter += ring[k].distance_to(ring[(k + 1) % ring.size()])
		# Inner area = outer - perimeter * wall (+ corner terms): the same room.
		assert_almost_eq(
			inner_area, outer_area - perimeter * CityBuildingBuilder.TIMBER_WALL, perimeter * 0.1
		)
		var built := CityBuildingBuilder.build_building(
			b, plan.footprint(i), plan.floor_height(i), true
		)
		var shell: CityBuildingBuilder.Shell = built["shell"]
		assert_true(shell.surfaces.has("floor"), "interior floor")
		assert_true(shell.surfaces.has("interior"), "interior walls")
		assert_true((built["roof"] as CityBuildingBuilder.Shell).triangle_count() > 0)
		return
	fail("no timber enterable house in the plan")


func test_roof_follows_ridge_and_walls_meet_it() -> void:
	var ring := PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(10, 6), Vector2(0, 6)])
	var frame := CityBuildingBuilder.roof_frame(ring, 0.0, 5.0, 45.0)
	assert_almost_eq(float(frame["half"]), 3.0, 0.001)
	assert_almost_eq(CityBuildingBuilder.roof_height(frame, Vector2(5, 3)), 8.0, 0.001)
	assert_almost_eq(CityBuildingBuilder.roof_height(frame, Vector2(5, 0)), 5.0, 0.001)


func test_collision_leaves_door_gap_and_blocks_cliffs() -> void:
	var plan := _plan()
	var root := Node2D.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(root)
	var collision := CityCollisionBuilder.build(plan, root)
	var shapes := 0
	for body in collision.get_children():
		shapes += body.get_child_count()
	assert_true(shapes > 1000, "buildings, walls and terrain blocks: %d" % shapes)
	await (Engine.get_main_loop() as SceneTree).physics_frame
	var space := root.get_world_2d().direct_space_state
	# Through the town hall door: the ray from outside to the hall centre is clear.
	for i in plan.buildings.size():
		var b: Dictionary = plan.buildings[i]
		if String(b.get("landmark_id", "")) != "landmark.town_hall":
			continue
		var door := Vector2(b["door"][0], b["door"][1])
		var out := Vector2(cos(float(b["door"][2])), sin(float(b["door"][2])))
		var query := PhysicsRayQueryParameters2D.create(
			CityPlan.to_logic(door + out * 2.0),
			CityPlan.to_logic(door - out * 1.5),
			CollisionLayers.WORLD
		)
		assert_true(space.intersect_ray(query).is_empty(), "the hall door is open")
		var side := Vector2(-out.y, out.x)
		var blocked := PhysicsRayQueryParameters2D.create(
			CityPlan.to_logic(door + side * 3.5 + out * 2.0),
			CityPlan.to_logic(door + side * 3.5 - out * 1.5),
			CollisionLayers.WORLD
		)
		assert_false(space.intersect_ray(blocked).is_empty(), "the wall beside the door is solid")
	# The north cliff of Toompea cannot be walked up.
	var cliff_foot := Vector2(-300, -175) / plan.metres_per_unit
	var cliff_top := Vector2(-320, -100) / plan.metres_per_unit
	var climb := PhysicsRayQueryParameters2D.create(
		CityPlan.to_logic(cliff_foot), CityPlan.to_logic(cliff_top), CollisionLayers.WORLD
	)
	assert_false(space.intersect_ray(climb).is_empty(), "the klint blocks")
	root.queue_free()


func test_toompea_wall_opens_where_the_hill_ways_cross() -> void:
	var plan := _plan()
	var streets := {}
	for o: Dictionary in plan.data["toompea_openings"]:
		streets[o["street"]] = true
	assert_true(streets.has("Pikk jalg"))
	assert_true(streets.has("Lühike jalg"))


func test_castle_has_corner_towers() -> void:
	var points := Fort.castle_tower_points(_plan())
	assert_eq(points.size(), 4)


func test_every_enterable_house_has_a_hinged_door_in_its_gap() -> void:
	var plan := _plan()
	var doors := CityDoors.create(plan)
	var enterable := 0
	for i in plan.buildings.size():
		if bool(plan.buildings[i]["enterable"]):
			enterable += 1
			assert_true(doors.doors.has(i), "door for %s" % plan.buildings[i]["id"])
	assert_true(enterable > 400)
	# Walking up to a door swings it inward; walking away shuts it.
	var index := -1
	for k: int in doors.doors:
		if bool(plan.buildings[k]["enterable"]):
			index = k
			break
	var center: Vector2 = doors.doors[index]["center"]
	for i in 30:
		doors.update_for(center, 0.05)
	assert_true(doors.is_open(index))
	for i in 30:
		doors.update_for(center + Vector2(40, 40), 0.05)
	assert_false(doors.is_open(index))
	doors.free()


func test_hud_names_district_street_and_building() -> void:
	var plan := _plan()
	var forum: Dictionary = plan.point_of_interest("poi.forum")
	var where := plan.location_at(Vector2(forum["at"][0], forum["at"][1]))
	assert_eq(where["district"], "Lower Town")
	var gate: Dictionary = plan.gate("gate.viru")
	var inside := Vector2(gate["at"][0], gate["at"][1]) - Vector2(25, 0)
	assert_true(String(plan.location_at(inside)["street"]).begins_with("Viru"))
	var lossi := plan.location_at(Vector2(-370, 175) / plan.metres_per_unit)
	assert_eq(lossi["district"], "Toompea")
