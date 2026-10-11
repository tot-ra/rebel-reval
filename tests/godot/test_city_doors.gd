extends "res://tests/godot/test_case.gd"

const Details := preload("res://scripts/city/city_door_details.gd")


func test_wealth_pools_are_deterministic_and_outbuildings_stay_plain() -> void:
	var styles := {}
	for tier in 3:
		for i in 30:
			var b := {"id": "house.%d" % i, "kind": "house"}
			var look := Details.look(b, tier)
			assert_eq(look, Details.look(b, tier))
			assert_true(Details.POOLS[tier].has(look["style"]))
			styles[look["style"]] = true
			b["kind"] = "outbuilding"
			assert_eq(Details.look(b, tier)["style"], &"rough")
	assert_eq(styles.size(), 5, "all residential profiles reachable")


func test_census_override_is_shared_with_windows() -> void:
	var b := {"id": "poor.stone", "material": "limestone"}
	CityHouseWealth.bind_tiers({"poor.stone": CityHouseWealth.POOR})
	var tier := CityHouseWealth.tier_of(b, PackedVector2Array())
	assert_eq(tier, CityHouseWealth.POOR)
	assert_true(Details.POOLS[0].has(Details.look(b, tier)["style"]))
	CityHouseWealth.clear()


func test_profiles_preserve_leaf_bounds_and_separate_iron_material() -> void:
	for style: StringName in [
		&"rough",
		&"plank",
		&"braced",
		&"ledged",
		&"merchant",
		&"studded",
		&"civic",
		&"parish",
		&"ecclesiastical"
	]:
		for width: float in [0.55, 1.3, 2.2]:
			var mesh := Details.mesh(style, width, 2.4)
			assert_eq(mesh, Details.mesh(style, width, 2.4), "cache reuse")
			var bounds := mesh.get_aabb()
			assert_true(bounds.position.x >= -0.001, "%s stays past hinge" % style)
			assert_true(bounds.end.x <= width + 0.001, "%s stays inside meeting edge" % style)
			assert_true(bounds.position.y >= 0 and bounds.end.y <= 2.401)
			assert_true(bounds.size.z > 0.18, "real hardware on both sides")
			var triangles := 0
			for surface in mesh.get_surface_count():
				triangles += mesh.surface_get_array_len(surface) / 3
				if mesh.surface_get_name(surface) == "iron":
					var material := mesh.surface_get_material(surface) as StandardMaterial3D
					assert_true(material.albedo_texture == null, "iron must not sample timber")
					assert_true(material.metallic > 0.5)
			assert_true(triangles < 4500, "bounded per-leaf geometry budget")
			assert_eq(mesh.get_surface_count(), 1 if style == &"rough" else 2)
	assert_ne(Details.mesh(&"plank", 1.3, 2.4, 0), Details.mesh(&"plank", 1.3, 2.4, 1))


func test_ornament_faces_outside_for_both_endpoint_orders_and_double_leaves() -> void:
	for inward in [Vector2(0, 1), Vector2(0, -1)]:
		for double in [false, true]:
			var node := CityDoors.new()
			var record := node._hang(
				"test", Vector2.ZERO, Vector2(2.4, 0), 0, inward, &"civic", Color.WHITE, 2.4, double
			)
			for hinge: Node3D in record["hinges"]:
				var leaf := hinge.get_child(0) as MeshInstance3D
				var facing := hinge.basis * leaf.basis.z
				assert_true(Vector2(facing.x, facing.z).dot(inward) < -0.99)
				var sign_value := CityDoors._inward_sign(hinge, inward)
				leaf.rotation.y = sign_value * CityDoors.OPEN_ANGLE
				var tip := hinge.basis * (leaf.basis * Vector3(1, 0, 0))
				assert_true(Vector2(tip.x, tip.z).dot(inward) > 0.9, "swings inward")
			node.free()


func test_actual_site_profiles_service_fallback_and_open_close() -> void:
	var plan := CityPlan.load_default()
	var node := CityDoors.create(plan)
	var found := {}
	for site in plan.sites:
		for d: Dictionary in site.doors:
			var key := "site:%s" % d["id"]
			var record: Dictionary = node.doors[key]
			assert_eq(record["style"], Details.site_style(d))
			assert_eq(record["site_floor"], d["floor"])
			if Details.SITE_STYLES.has(d["id"]):
				found[d["id"]] = true
			else:
				assert_eq(record["style"], d["style"], "service role kept")
			for hinge: Node3D in record["hinges"]:
				var leaf := hinge.get_child(0) as MeshInstance3D
				var facing := hinge.basis * leaf.basis.z
				var inward: Vector2 = d["inward"]
				assert_true(Vector2(facing.x, facing.z).dot(inward) < -0.99)
	assert_eq(found.size(), Details.SITE_STYLES.size(), "no stale landmark override IDs")
	var council := "site:door.council_hall.north"
	node.update_for(node.doors[council]["center"], 1.0)
	assert_true(node.is_open(council))
	node.update_for(Vector2(100000, 100000), 1.0)
	assert_false(node.is_open(council))
	node.free()
