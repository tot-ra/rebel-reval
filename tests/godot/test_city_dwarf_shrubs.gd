extends "res://tests/godot/test_case.gd"

## R-2127: dwarf shrubs and berry ground cover - stage calendar, model budget,
## placement per habitat (closed stand, coastal heath, wood edge, bog) and the
## calendar swap.

const Meshes := preload("res://scripts/city/city_dwarf_shrub_meshes.gd")
const JAN := 15
const MAY := 135
const JUL := 196
const SEP := 258


func _shrubs(plan: CityPlan) -> CityDwarfShrubs:
	var parent := Node3D.new()
	var node := CityDwarfShrubs.build(plan, parent)
	parent.remove_child(node)
	parent.free()
	return node


func test_stage_calendar_by_species() -> void:
	var expected := {
		&"bilberry": [&"bare", &"flower", &"fruit", &"autumn"],
		&"cowberry": [&"winter", &"leaf", &"leaf", &"fruit"],
		&"heather": [&"winter", &"leaf", &"leaf", &"flower"],
		&"crowberry": [&"winter", &"leaf", &"leaf", &"fruit"],
		&"cloudberry": [&"none", &"flower", &"fruit", &"autumn"],
		&"cranberry": [&"winter", &"leaf", &"flower", &"fruit"],
		&"bog_rosemary": [&"winter", &"flower", &"leaf", &"leaf"],
		&"wild_strawberry": [&"none", &"flower", &"fruit", &"leaf"],
	}
	var days := [JAN, MAY, JUL, SEP]
	for species: StringName in expected:
		for i in days.size():
			assert_eq(
				CityDwarfShrubs.stage_for(species, days[i]),
				expected[species][i],
				"%s on day %d" % [species, days[i]]
			)
	assert_eq(CityDwarfShrubs.stage_for(&"cowberry", 160), &"flower", "cowberry flowers in June")


func test_every_stage_has_a_model_within_budget() -> void:
	for species: StringName in Meshes.SPECIES:
		var stages := Meshes.stages(species)
		assert_false(stages.is_empty(), "%s has stages" % species)
		for day in range(1, 367):
			var stage := CityDwarfShrubs.stage_for(species, day)
			if stage != Meshes.STAGE_NONE:
				assert_true(
					stage in stages, "%s day %d stage %s has a model" % [species, day, stage]
				)
		for stage: StringName in stages:
			var mesh := Meshes.mesh_for(species, stage)
			assert_true(mesh != null, "%s %s mesh" % [species, stage])
			var tris := Meshes.triangle_count(mesh)
			assert_true(
				tris > 20 and tris <= Meshes.MAX_TRIANGLES,
				"%s %s: %d triangles within budget" % [species, stage, tris]
			)


func test_fruit_and_flower_stages_add_geometry() -> void:
	var leafy := Meshes.triangle_count(Meshes.mesh_for(&"bilberry", &"leaf"))
	assert_true(
		Meshes.triangle_count(Meshes.mesh_for(&"bilberry", &"fruit")) > leafy,
		"bilberry fruit adds berries"
	)
	assert_true(
		Meshes.triangle_count(Meshes.mesh_for(&"bilberry", &"bare")) < leafy,
		"bare bilberry has no leaves"
	)
	assert_true(
		(
			Meshes.triangle_count(Meshes.mesh_for(&"wild_strawberry", &"fruit"))
			> Meshes.triangle_count(Meshes.mesh_for(&"wild_strawberry", &"leaf"))
		),
		"strawberries hang"
	)


func test_default_plan_is_deterministic() -> void:
	var a := _shrubs(CityPlan.load_default())
	var b := _shrubs(CityPlan.load_default())
	var pa := a.placements()
	var pb := b.placements()
	assert_true(pa.size() > 2000, "the city grows a real ground cover (%d clumps)" % pa.size())
	assert_eq(pa.size(), pb.size(), "same plan, same clump count")
	var same := true
	for i in pa.size():
		if pa[i][0] != pb[i][0] or not (pa[i][1] as Transform3D).is_equal_approx(pb[i][1]):
			same = false
			break
	assert_true(same, "same plan, same transforms")
	a.free()
	b.free()


func test_species_follow_their_habitat() -> void:
	var plan := CityPlan.load_default()
	var node := _shrubs(plan)
	for species: StringName in [
		&"bilberry", &"cowberry", &"heather", &"crowberry", &"wild_strawberry"
	]:
		assert_true(node.instance_count(species) > 0, "%s grows in Reval" % species)
	for species: StringName in [&"cloudberry", &"cranberry", &"bog_rosemary", &"sphagnum"]:
		assert_eq(node.instance_count(species), 0, "no %s without an authored bog" % species)
	var woods := _grid(CityForestFloor.wooded_trees(plan))
	var heath := _grid(CityDwarfShrubs.heath_trees(plan))
	var edges := _grid(CityDwarfShrubs.edge_trees(plan))
	var stray := {}
	var roads := CityForestFloor._roads_image(plan)
	var on_road := 0
	for entry: Array in node.placements():
		var species: StringName = entry[0]
		var o: Vector3 = (entry[1] as Transform3D).origin
		var p := Vector2(o.x, o.z)
		if not CityForestFloor._ground_ok(plan, roads, p):
			on_road += 1
		var ok := true
		match species:
			&"bilberry":
				ok = _near(woods, p)
			&"heather", &"crowberry":
				ok = _near(heath, p)
			&"cowberry":
				ok = _near(woods, p) or _near(heath, p)
			&"wild_strawberry":
				ok = _near(edges, p)
		if not ok:
			stray[species] = int(stray.get(species, 0)) + 1
	assert_eq(on_road, 0, "no clump on a cart road or in the moat")
	assert_true(stray.is_empty(), "every clump stands in its habitat (strays: %s)" % stray)
	node.free()


func test_bog_grows_inside_its_polygon() -> void:
	var square := [[0.0, 0.0], [40.0, 0.0], [40.0, 40.0], [0.0, 40.0]]
	var bog := {"id": "bog.test", "polygon": square}
	var flat := func(_q: Vector2) -> float: return 0.0
	var rows := CityDwarfShrubs.bog_placements(bog, flat, 1.0)
	var again := CityDwarfShrubs.bog_placements(bog, flat, 1.0)
	assert_eq(rows.size(), again.size(), "bog placement is deterministic")
	var counts := {}
	var outside := 0
	for row: Array in rows:
		counts[row[0]] = int(counts.get(row[0], 0)) + 1
		var o: Vector3 = (row[1] as Transform3D).origin
		# Mats are placed inside; berries on a mat sit up to 0.3 units off its centre.
		if o.x < -0.3 or o.x > 40.3 or o.z < -0.3 or o.z > 40.3:
			outside += 1
	assert_eq(outside, 0, "every bog clump lies inside the bog")
	for species: StringName in [
		&"sphagnum", &"cranberry", &"cloudberry", &"bog_rosemary", &"crowberry"
	]:
		assert_true(int(counts.get(species, 0)) > 0, "%s grows on the bog (%s)" % [species, counts])
	assert_true(int(counts[&"sphagnum"]) > 200, "the bog is carpeted with sphagnum")


func test_calendar_swaps_stages_and_hides_dead_plants() -> void:
	var node := _shrubs(CityPlan.load_default())
	node.set_calendar_date({"year": 1343, "month": 1, "day": 15})
	var jan := node.visible_species()
	assert_false(jan.has(&"wild_strawberry"), "no strawberry above ground in January")
	assert_array_contains(jan, &"cowberry", "evergreen cowberry stays in January")
	assert_array_contains(jan, &"heather", "heather stays in January")
	assert_eq(node.current_stage(&"heather"), &"winter", "heather is winter brown")
	assert_array_contains(jan, &"bilberry", "bilberry twigs stay in January")
	assert_eq(node.current_stage(&"bilberry"), &"bare", "bilberry is bare in January")
	node.set_calendar_date({"year": 1343, "month": 7, "day": 15})
	assert_eq(node.current_stage(&"bilberry"), &"fruit", "bilberries in July")
	assert_array_contains(node.visible_species(), &"wild_strawberry", "strawberries in July")
	node.set_calendar_date({"year": 1343, "month": 9, "day": 15})
	assert_eq(node.current_stage(&"heather"), &"flower", "heather in flower in September")
	assert_eq(node.current_stage(&"bilberry"), &"autumn", "bilberry leaves red in September")
	node.free()


func _grid(trees: Array) -> Dictionary:
	var grid := {}
	for t: Array in trees:
		grid[Vector2i(floori(float(t[0]) / 12.0), floori(float(t[1]) / 12.0))] = true
	return grid


## Within one 12-unit cell of a listed tree (patches reach about 9 units out).
func _near(grid: Dictionary, p: Vector2) -> bool:
	var c := Vector2i(floori(p.x / 12.0), floori(p.y / 12.0))
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			if grid.has(c + Vector2i(dx, dz)):
				return true
	return false
