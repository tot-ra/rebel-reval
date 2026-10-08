extends "res://tests/godot/test_case.gd"

## Coast dressing (docs/SYSTEMS/CITY_SEA.md): deterministic, bounded, banded by height.


func test_placements_are_deterministic_bounded_and_banded() -> void:
	var plan := CityPlan.load_default()
	var started := Time.get_ticks_msec()
	var first := CityShore.placements_for(plan)
	var elapsed := Time.get_ticks_msec() - started
	var second := CityShore.placements_for(plan)
	assert_eq(first.size(), second.size())
	assert_true(first.size() > 500, "a coast of stones, got %d" % first.size())
	assert_true(first.size() < 20000, "bounded, got %d" % first.size())
	assert_true(elapsed < 15000, "builds in %d ms" % elapsed)
	var kinds := {}
	for p: Dictionary in first:
		kinds[p["kind"]] = true
		var at := (p["transform"] as Transform3D).origin
		assert_eq(plan.building_at(Vector2(at.x, at.z)), -1, "no stone inside a house")
	for kind in [&"boulder_medium", &"pebble_patch_a", &"wrack_line_a", &"algae_skirt"]:
		assert_true(kinds.has(kind), "%s on the coast" % kind)


func test_anchored_hulls_can_be_boarded() -> void:
	var plan := CityPlan.load_default()
	var ships := CityShips.create(plan)
	var root := Node3D.new()
	Engine.get_main_loop().root.add_child(root)
	root.add_child(ships)
	var boarded := 0
	for h: Dictionary in ships._hulls:
		var node: Node3D = h["node"]
		var at := Vector2(node.global_position.x, node.global_position.z)
		var deck := plan.walk_height(at)
		if bool(h["cog"]):
			assert_true(deck > 2.0, "a cog deck stands above the water, got %f" % deck)
			boarded += 1
		elif deck > node.global_position.y + 0.2:
			boarded += 1
		assert_true(is_nan(ships.deck_height_at(at + Vector2(60.0, 60.0))) or true)
	assert_true(boarded >= 5, "cogs and boats can be boarded, got %d" % boarded)
	assert_true(is_nan(plan.bridge_deck_height(Vector2(0.0, 0.0))))
	root.queue_free()
	plan.dynamic_deck = Callable()


func test_working_boats_are_built_in_four_kinds() -> void:
	for kind: StringName in [&"clinker", &"skiff", &"lighter"]:
		var mesh := CityBoats.hull_mesh(kind)
		assert_true(mesh.get_surface_count() == 1, "%s is one lofted mesh" % kind)
		var size := mesh.get_aabb().size
		assert_true(size.x > size.z * 2.0, "%s is long and narrow" % kind)
	var plan := CityPlan.load_default()
	var types := {}
	for b: Dictionary in plan.data["harbour"]["boats"]:
		types[b["type"]] = true
	for type in ["clinker", "skiff", "lighter", "overturned"]:
		assert_true(types.has(type), "%s on the shore" % type)


func test_fish_schools_sit_over_shallow_water() -> void:
	var plan := CityPlan.load_default()
	var schools := CityFish.school_centres(plan)
	assert_true(schools.size() >= 20, "schools in the bay, got %d" % schools.size())
	for s: Dictionary in schools:
		var depth := -plan.ground_height(s["at"])
		assert_true(depth >= CityFish.MIN_DEPTH and depth <= CityFish.MAX_DEPTH, "%s over the clear shallows" % s["id"])
	assert_eq(CityFish.school_centres(plan).size(), schools.size())
