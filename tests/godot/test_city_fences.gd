extends "res://tests/godot/test_case.gd"

## Country fences are wattle, pole or dry-stone, never sawn boards (CityFences).


func test_kind_is_stable_and_historical() -> void:
	var counts := {&"wattle": 0, &"pole": 0, &"stone": 0}
	for i in 200:
		var id := "pasture.%02d" % i
		var kind := CityFences.kind_for(id)
		assert_eq(kind, CityFences.kind_for(id), "kind is deterministic")
		assert_true(counts.has(kind), "known kind %s" % kind)
		counts[kind] += 1
	assert_true(counts[&"wattle"] > counts[&"pole"], "wattle is the commonest fence")
	assert_true(counts[&"pole"] > counts[&"stone"], "stone walls are the rarest")
	assert_true(counts[&"stone"] > 0, "some stone walls exist")


func test_each_kind_builds_geometry() -> void:
	var poly := PackedVector2Array([Vector2(0, 0), Vector2(6, 0), Vector2(6, 5), Vector2(0, 5)])
	var ground := func(_p: Vector2) -> float: return 0.0
	var found: Array[StringName] = []
	for i in 400:
		var id := "t.%d" % i
		var kind := CityFences.kind_for(id)
		if found.has(kind):
			continue
		found.append(kind)
		var root := Node3D.new()
		CityFences.build(root, id, poly, ground, 100.0)
		assert_eq(root.get_child_count(), 1, "%s builds one node" % kind)
		root.free()
	assert_eq(found.size(), 3, "all three kinds reachable")
