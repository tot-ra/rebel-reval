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


func test_camera_ray_selects_nearby_door_aperture() -> void:
	var plan := CityPlan.load_default()
	var node := CityDoors.create(plan)
	root.add_child(node)
	var door_key := "site:door.council_hall.north"
	var door: Dictionary = node.doors[door_key]
	var center: Vector2 = door["center"]
	var hinge: Node3D = door["hinges"][0]
	var origin := Vector3(center.x, hinge.position.y + 2.0, center.y - 3.0)
	var direction := Vector3(0.0, -2.0, 3.0).normalized()
	assert_eq(node.door_at_ray(origin, direction), door_key, "camera ray selects the aperture")
	assert_eq(node.door_at_ray(origin, direction, 1.0), null, "ray reach can reject distant doors")
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
	assert_false(node.is_open(council), "walking up to a closed door does not open it")
	assert_true(node.interact_at(node.doors[council]["center"]), "nearby click selects the door")
	node.update_for(node.doors[council]["center"], 1.0)
	assert_true(node.is_open(council), "explicit interaction opens the door")
	node.update_for(Vector2(100000, 100000), 1.0)
	assert_false(node.is_open(council))
	node.free()


## R-1693: every profiled entrance resolves to exactly one aperture, and the
## portal leaves the walk gap (collision) exactly as wide as that aperture.
func test_portals_bind_one_aperture_and_keep_the_walk_gap() -> void:
	var plan := CityPlan.load_default()
	var bound := {}
	for site in plan.sites:
		for raw: Dictionary in site.data.get("doors", []):
			var id := StringName(raw["id"])
			if not CitySitePortals.PROFILES.has(id):
				continue
			var hit := CitySitePortals.find(site.data, raw)
			assert_false(hit.is_empty(), "%s has one aperture" % id)
			if hit.is_empty():
				continue
			assert_eq(String(hit["op"]["portal"]["door"]), String(id))
			bound[id] = true
			var op: Dictionary = hit["op"]
			var wall: Dictionary = hit["wall"]
			var s0 := float(op["s"]) - float(op["w"]) * 0.5
			var s1 := s0 + float(op["w"])
			var ends := []
			for seg: Dictionary in CitySiteKit.walk_walls([wall]):
				var wa := Vector2(wall["a"][0], wall["a"][1])
				ends.append(roundf((seg["a"] as Vector2).distance_to(wa) * 100.0))
				ends.append(roundf((seg["b"] as Vector2).distance_to(wa) * 100.0))
			assert_true(
				ends.has(roundf(s0 * 100.0)) and ends.has(roundf(s1 * 100.0)), "%s gap" % id
			)
	assert_eq(bound.size(), CitySitePortals.PROFILES.size(), "no stale portal IDs")


## Orders stay on their wall, below its top and clear of neighbouring openings;
## the leaf fits behind the stop and swings flat into the rear arch.
func test_portal_masonry_fits_its_wall_and_clears_the_swing() -> void:
	var plan := CityPlan.load_default()
	for site in plan.sites:
		for raw: Dictionary in site.data.get("doors", []):
			var id := StringName(raw["id"])
			if not CitySitePortals.PROFILES.has(id):
				continue
			var hit := CitySitePortals.find(site.data, raw)
			var op: Dictionary = hit["op"]
			var wall: Dictionary = hit["wall"]
			var thick := float(wall["thick"])
			var o := CitySiteKit._opening(op, false)
			var section := CitySitePortals.rings(o, op, thick)
			var face: Dictionary = section[0][0]
			var rear: Dictionary = section[-1][0]
			var length := Vector2(wall["a"][0], wall["a"][1]).distance_to(
				Vector2(wall["b"][0], wall["b"][1])
			)
			for ring: Dictionary in [face, rear]:
				assert_true(float(ring["s"]) > 0.2, "%s inside its wall" % id)
				assert_true(float(ring["s"]) + float(ring["w"]) < length - 0.2, "%s end" % id)
				assert_true(CitySiteKit._top(ring) < float(wall["y1"]) - 0.3, "%s top" % id)
			for other: Dictionary in wall.get("openings", []):
				if other == op or String(other.get("kind", "")) == "recess":
					continue
				var oo := CitySiteKit._opening(other, false)
				var apart := (
					float(oo["s"]) > float(face["s"]) + float(face["w"])
					or float(oo["s"]) + float(oo["w"]) < float(face["s"])
					or float(oo["sill"]) > CitySiteKit._top(face)
				)
				assert_true(apart, "%s orders clear of %s" % [id, other])
			var depth := CitySitePortals.leaf_depth(op)
			assert_true(depth + 0.1 <= thick, "%s leaf inside the wall" % id)
			assert_true(depth >= float(op["portal"]["depth"]) - 0.001, "never pulled outward")
			assert_true(section[-2][1] <= depth - CitySitePortals.CLEAR + 0.001)
			var head := CitySitePortals.grow(o, CitySitePortals.OVERLAP)
			assert_true(float(rear["spring"]) >= float(head["apex"]) + 0.05, "%s head clear" % id)
			# Opened 90 deg, strap ironwork (0.1 m) beside the overlap stays in the rebate.
			assert_true(CitySitePortals.OVERLAP + 0.1 < CitySitePortals.REBATE)


## Shaped leaves meet the springing at the jamb, reach the apex in the middle
## of a single leaf (at the meeting edge of a pair) and keep the triangle bound.
func test_shaped_leaf_follows_the_pointed_head() -> void:
	var head := Vector2(1.9, 3.6)
	for style: StringName in [&"plank", &"parish", &"ecclesiastical"]:
		for leaves: int in [1, 2]:
			var w: float = head.x / leaves
			var mesh := Details.mesh(style, w, 2.5, 0, head)
			var bounds := mesh.get_aabb()
			assert_true(absf(bounds.end.y - 3.6) < 0.02, "%s reaches the apex" % style)
			assert_true(bounds.position.x >= -0.001 and bounds.end.x <= w + 0.001)
			assert_true(absf(Details.top(0.0, 2.5, head) - 2.5) < 0.001)
			assert_true(absf(Details.top(head.x * 0.5, 2.5, head) - 3.6) < 0.001)
			var triangles := 0
			for surface in mesh.get_surface_count():
				triangles += mesh.surface_get_array_len(surface) / 3
			assert_true(triangles < 4500)
	assert_ne(Details.mesh(&"plank", 1.9, 2.5), Details.mesh(&"plank", 1.9, 2.5, 0, head))


## Runtime leaves of a portal hang deeper by the profile's shift, overlap the
## stop, open 90 deg inward, and keep proximity on the authored door line.
func test_portal_leaves_hang_behind_the_stop() -> void:
	var plan := CityPlan.load_default()
	var node := CityDoors.create(plan)
	var checked := 0
	for site in plan.sites:
		for d: Dictionary in site.doors:
			if not CitySitePortals.PROFILES.has(d["id"]):
				continue
			var record: Dictionary = node.doors["site:%s" % d["id"]]
			assert_eq(record["center"], (d["a"] + d["b"]) * 0.5)
			assert_eq(record["angle"], CitySitePortals.OPEN_ANGLE)
			var hinge: Node3D = record["hinges"][0]
			var frame := CitySitePortals.leaf(site, d["id"], hinge.position.y)
			var moved: Vector2 = Vector2(hinge.position.x, hinge.position.z) - d["a"]
			var inward: Vector2 = d["inward"]
			assert_true(absf(moved.dot(inward) - float(frame["depth_shift"])) < 0.01)
			assert_true(frame["apex"] > frame["spring"], "%s cut to its head" % d["id"])
			checked += 1
	assert_eq(checked, CitySitePortals.PROFILES.size())
	node.free()


## The council hall builds its own rectangular apertures: both leaves fill them
## (flat lintel under the tympanum) and the market portal is not dressed as a
## window (R-1693).
func test_council_leaves_fill_their_apertures() -> void:
	var Parts := preload("res://scripts/city/sites/raekoja_plats_parts.gd")
	var plan := CityPlan.load_default()
	for site in plan.sites:
		if site.id != &"site.raekoja_plats":
			continue
		for d: Dictionary in site.doors:
			var width: float = (d["a"] as Vector2).distance_to(d["b"])
			if d["id"] == &"door.council_hall.north":
				assert_true(absf(width - Parts.PORTAL_W) < 0.001, "market portal width")
				assert_true(absf(float(d["height"]) - 0.05 - Parts.PORTAL_H) < 0.04)
			elif d["id"] == &"door.council_hall.dornse":
				assert_true(absf(width - (Parts.PART_DOOR.y - Parts.PART_DOOR.x)) < 0.001)
				assert_true(absf(float(d["height"]) - 0.05 - Parts.PART_DOOR_H) < 0.04)


## The chancel's south buttress stood on the priests' door; the bay line now
## clears the door's outermost order (R-1693).
func test_st_mary_buttress_clears_the_priests_door() -> void:
	var Builder := preload("res://scripts/city/sites/st_mary_builder.gd")
	var plan := CityPlan.load_default()
	for site in plan.sites:
		if site.id != &"site.st_mary":
			continue
		for raw: Dictionary in site.data["doors"]:
			if raw["id"] != "door.st_mary.priests":
				continue
			var hit := CitySitePortals.find(site.data, raw)
			var o := CitySiteKit._opening(hit["op"], false)
			var face: Dictionary = CitySitePortals.rings(o, hit["op"], 1.3)[0][0]
			# The wall runs east to west (x = 14 - s); buttress half-width 0.55.
			var east_edge := 14.0 - float(face["s"])
			assert_true(Builder.CHANCEL_BAY - 0.55 > east_edge + 0.2, "buttress clear")
