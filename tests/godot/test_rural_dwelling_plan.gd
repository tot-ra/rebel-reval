extends "res://tests/godot/test_case.gd"

## 1343 smoke dwellings (R-1929, docs/SYSTEMS/FARMLAND.md "Rural dwelling plan"):
## plan data from the generators, one seam rule with the map-view facade, the
## log partition, heap oven and threshing gate, and the furnished rooms.

const RuralPlan := preload("res://scripts/city/rural_dwelling_plan.gd")
## Kalev's collision capsule is 1 m wide (CityBuildingBuilder.OUTBUILDING_DOORS).
const CAPSULE := 1.0


func _rural(plan: CityPlan) -> Array[int]:
	var out: Array[int] = []
	for i in plan.buildings.size():
		if plan.buildings[i].has("rural_plan"):
			out.append(i)
	return out


func test_farm_houses_and_barn_dwellings_carry_a_plan() -> void:
	var plan := CityPlan.load_default()
	var cottages := 0
	var barns := 0
	for b: Dictionary in plan.data["buildings"]:
		var district := String(b["id"]).split(".")[1]
		var farm_house := (
			String(b["kind"]) == "house" and district in ["harju", "karja", "toompea_foot"]
		)
		if farm_house:
			assert_eq(RuralPlan.form(b), RuralPlan.SMOKE_COTTAGE, "%s is a smoke cottage" % b["id"])
			cottages += 1
		elif String(b.get("type", "")) == "barn_dwelling":
			assert_eq(RuralPlan.form(b), RuralPlan.BARN_DWELLING, "%s has two bays" % b["id"])
			barns += 1
		else:
			assert_false(b.has("rural_plan"), "%s keeps its town plan" % b["id"])
	assert_true(cottages >= 40, "farm-suburb smoke cottages, got %d" % cottages)
	assert_true(barns >= 5, "suburban barn-dwellings, got %d" % barns)
	var site := CityPlan.load_site("harju")
	for b: Dictionary in site.data["buildings"]:
		if String(b.get("type", "")) == "smoke_room":
			assert_eq(RuralPlan.form(b), RuralPlan.BARN_DWELLING, "%s has two bays" % b["id"])


func test_seam_is_the_map_view_rule_and_the_door_opens_on_the_threshing_floor() -> void:
	for plan: CityPlan in [CityPlan.load_default(), CityPlan.load_site("harju")]:
		var ids := {}
		for i in _rural(plan):
			var b: Dictionary = plan.buildings[i]
			var rp := RuralPlan.of(b)
			for key in ["oven", "inner_door", "gate"]:
				if rp.has(key):
					var id := String(rp[key]["id"])
					assert_eq(id, "%s.%s" % [b["id"], key], "stable %s id" % key)
					assert_false(ids.has(id), "%s unique" % id)
					ids[id] = true
			assert_true(
				RuralPlan.in_heated_bay(b, RuralPlan.oven(b)["at"]),
				"%s oven is in the warm room" % b["id"]
			)
			if not RuralPlan.is_barn(b):
				continue
			# One rule with the facade: the heated share is the map-view seam,
			# stepped down (not below 0.3) only to keep the outer door clear.
			var share := float(rp["share"])
			assert_true(
				share <= MapViewRuralDwellingModels.ROOM_SHARE + 0.0001, "%s share" % b["id"]
			)
			assert_true(share >= 0.3 - 0.0001, "%s share floor" % b["id"])
			if b["door"] != null:
				var door := Vector2(b["door"][0], b["door"][1])
				assert_false(
					RuralPlan.in_heated_bay(b, door),
					"%s door opens on the threshing floor" % b["id"]
				)
			if rp.has("gate"):
				var gate := Vector2(rp["gate"]["at"][0], rp["gate"]["at"][1])
				assert_false(
					RuralPlan.in_heated_bay(b, gate), "%s gate is on the threshing bay" % b["id"]
				)
				assert_true(float(rp["gate"]["w"]) >= 1.75, "%s gate takes a cart" % b["id"])
			assert_true(
				RuralPlan.inner_door_size(b).x >= CAPSULE + 0.15,
				"%s inner door passes Kalev" % b["id"]
			)


func test_smoke_dwellings_have_low_doors_no_chimney_and_their_parts() -> void:
	var plan := CityPlan.load_default()
	var checked := {}
	for i in _rural(plan):
		var b: Dictionary = plan.buildings[i]
		if checked.has(RuralPlan.form(b)) or not bool(b["enterable"]):
			continue
		checked[RuralPlan.form(b)] = true
		var size := CityBuildingBuilder.door_size(b)
		assert_true(size.x >= CAPSULE + 0.15, "%s door passes Kalev" % b["id"])
		assert_true(size.y < CityBuildingBuilder.DOOR_HEIGHT, "%s door is low" % b["id"])
		var built := CityBuildingBuilder.build_building(
			b, plan.footprint(i), plan.floor_height(i), true
		)
		assert_eq(built["chimney"], Vector3.INF, "%s has no chimney" % b["id"])
		var shell: CityBuildingBuilder.Shell = built["shell"]
		assert_true(shell.surfaces.has("clay"), "%s has an earth floor" % b["id"])
		assert_false(shell.surfaces.has("interior"), "%s is not limewashed" % b["id"])
		assert_false(shell.surfaces.has("glass:clear"), "%s has no glazed window" % b["id"])
	assert_eq(checked.size(), 2, "both forms built")


func test_barn_dwelling_collision_closes_the_partition_but_the_inner_door() -> void:
	var plan := CityPlan.load_default()
	for i in _rural(plan):
		var b: Dictionary = plan.buildings[i]
		if not RuralPlan.is_barn(b) or not bool(b["enterable"]):
			continue
		var ring := CityBuildingBuilder.wall_ring(b, plan.footprint(i))
		var inner := CityBuildingBuilder.normalized_ring(
			(
				Geometry2D
				. offset_polygon(ring, -CityBuildingBuilder.TIMBER_WALL, Geometry2D.JOIN_MITER)[0]
			)
		)
		var solids := RuralPlan.solids(b, inner, CityBuildingBuilder.TIMBER_WALL)
		assert_eq(solids.size(), 3, "%s oven and two partition pieces" % b["id"])
		var span := RuralPlan.seam_span(b, inner)
		var door := RuralPlan.inner_door(b, span)
		for poly in solids:
			assert_false(
				Geometry2D.is_point_in_polygon(door, poly), "%s inner doorway is open" % b["id"]
			)
		return
	fail("no enterable barn-dwelling")


func test_harju_smoke_room_lives_in_the_heated_bay() -> void:
	var plan := CityPlan.load_site("harju")
	var interiors := CityInteriors.create(plan, CitizenRoster.load_for(plan), [])
	var seen := 0
	for i in _rural(plan):
		var b: Dictionary = plan.buildings[i]
		if not interiors.is_lived_in(i):
			continue
		var layout := interiors.layout(i)
		assert_true(layout.items[layout.hearth].has("oven"), "%s hearth is the heap oven" % b["id"])
		assert_eq(layout.rooms.size(), 2, "%s threshing floor and warm room" % b["id"])
		assert_eq(layout.partitions.size(), 1, "%s one log partition" % b["id"])
		assert_true(
			(layout.partitions[0]["walls"] as Array).is_empty(),
			"%s wall is the builder's" % b["id"]
		)
		assert_eq(layout.living_room(), 1, "%s lives in the heated bay" % b["id"])
		assert_eq(layout.room_of(layout.entry), 0, "%s enters over the threshing floor" % b["id"])
		for slot: Dictionary in layout.slots_of(&"sleep"):
			assert_true(
				RuralPlan.in_heated_bay(b, slot["pos"]), "%s sleeps in the warm room" % b["id"]
			)
		seen += 1
	interiors.free()
	assert_true(seen >= 5, "furnished Harju smoke rooms, got %d" % seen)


func test_plan_is_deterministic() -> void:
	var a := CityPlan.load_site("harju")
	var b := CityPlan.load_site("harju")
	for i in _rural(a):
		assert_eq(RuralPlan.of(a.buildings[i]), RuralPlan.of(b.buildings[i]))
