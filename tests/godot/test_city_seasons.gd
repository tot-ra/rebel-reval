extends "res://tests/godot/test_case.gd"

## ADR 0045 city seasons: leaf fall by tree and wind, water plants and moat ice.

const OCT := {"day": 20, "month": 10, "year": 1343}
const JAN := {"day": 15, "month": 1, "year": 1343}
const JUL := {"day": 15, "month": 7, "year": 1343}


func _doy(date: Dictionary) -> float:
	return SeasonState.day_of_year_for(date)


func test_leaf_shedding_follows_leaves_and_wind() -> void:
	assert_eq(CityLeafFall.shed_weight(&"birch", JAN, 0.9), 0.0, "a bare tree sheds nothing")
	var calm := CityLeafFall.shed_weight(&"birch", OCT, 0.1)
	var windy := CityLeafFall.shed_weight(&"birch", OCT, 0.8)
	assert_true(calm > 0.0, "October crowns shed even in a lull")
	assert_true(windy > calm * 1.5, "a stiff wind strips more leaves")
	assert_eq(CityLeafFall.shed_weight(&"birch", JUL, 0.1), 0.0, "summer crowns hold fast")
	assert_true(CityLeafFall.shed_weight(&"birch", JUL, 0.9) > 0.0, "a gale shakes summer leaves")


func test_tree_lod_lists_trees_near_a_point() -> void:
	var lod := CityTreeLod.new()
	var far := MultiMesh.new()
	far.transform_format = MultiMesh.TRANSFORM_3D
	far.instance_count = 2
	var transforms: Array[Transform3D] = [
		Transform3D(Basis.from_scale(Vector3.ONE * 2.0), Vector3(10.0, 1.0, 10.0)),
		Transform3D(Basis.IDENTITY, Vector3(300.0, 0.0, 300.0)),
	]
	var colors: Array[Color] = [Color.WHITE, Color.WHITE]
	lod.register(&"birch", 1.0, far, transforms, colors, false)
	var near := lod.trees_near(Vector3(12.0, 0.0, 12.0), 20.0)
	assert_eq(near.size(), 1)
	assert_eq(near[0][0], &"birch")
	assert_almost_eq(float(near[0][2]), 2.0, 0.001, "scale rides along for crown size")
	lod.free()


func test_water_plants_die_back_with_the_cold() -> void:
	assert_true(SeasonState.reed_standing(_doy(JUL)) > 0.99)
	assert_almost_eq(SeasonState.reed_standing(_doy(JAN)), 0.0, 0.001)
	assert_true(SeasonState.water_plant_vigour(_doy(JUL)) > 0.99)
	assert_almost_eq(SeasonState.water_plant_vigour(_doy(JAN)), 0.0, 0.001)
	assert_true(SeasonState.reed_dead_share(_doy(OCT)) > 0.4, "autumn reeds are yellowing")
	assert_almost_eq(SeasonState.reed_dead_share(_doy(JUL)), 0.0, 0.001)
	# Lily flowers need warmer water than the pads.
	assert_true(SeasonState.lily_flower_share(_doy(JUL)) > 0.5)
	assert_almost_eq(SeasonState.lily_flower_share(_doy(OCT)), 0.0, 0.001)


func test_moat_plants_thin_out_in_winter() -> void:
	var root := Node3D.new()
	var xf: Array[Transform3D] = []
	var colors: Array[Color] = []
	for i in 10:
		xf.append(Transform3D(Basis.IDENTITY, Vector3(float(i), 0.0, 0.0)))
		colors.append(Color.WHITE)
	CityMoatPlants._add_reeds(root, xf, colors)
	CityMoatPlants.apply_season(root, _doy(JUL))
	var reeds := root.get_node("Reeds") as MultiMeshInstance3D
	assert_eq(reeds.multimesh.visible_instance_count, 10)
	assert_true(reeds.visible)
	CityMoatPlants.apply_season(root, _doy(JAN))
	assert_eq(reeds.multimesh.visible_instance_count, 0, "a hard winter leaves no reeds")
	assert_false(reeds.visible)
	root.free()


func test_moat_freezes_by_temperature() -> void:
	assert_almost_eq(SeasonState.ice_cover_target(SeasonState.ICE_FRESH, _doy(JUL)), 0.0, 0.001)
	assert_true(SeasonState.ice_cover_target(SeasonState.ICE_FRESH, _doy(JAN)) > 0.2)
	var feb := {"day": 15, "month": 2, "year": 1343}
	assert_true(SeasonState.ice_cover_target(SeasonState.ICE_FRESH, _doy(feb)) > 0.5)
