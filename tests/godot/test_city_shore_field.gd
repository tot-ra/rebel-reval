extends "res://tests/godot/test_case.gd"

## The city's shore field and spray (docs/SYSTEMS/CITY_SEA.md): the sea shader only
## draws surf where a shore distance field is bound, so the bake must find the
## waterline, mark gentle shore as beach and give a sheet band over it.

const ShoreField := preload("res://scripts/city/city_shore_field.gd")


func _bake() -> Array:
	var plan := CityPlan.load_default()
	return [plan, ShoreField.bake(plan)]


func test_bake_finds_waterline_and_beach() -> void:
	var baked := _bake()
	var shore: Dictionary = baked[1]
	assert_true(shore["texture"] is Texture2D, "field texture is built")
	var contour: PackedVector2Array = shore["contour"]
	assert_true(contour.size() > 200, "the coast yields waterline segments")
	var distance: PackedFloat32Array = shore["distance"]
	var water := 0
	var land := 0
	var beach := 0.0
	var near := 0
	for index in distance.size():
		if distance[index] > 0.0:
			water += 1
		else:
			land += 1
		if absf(distance[index]) < ShoreField.MAX_DISTANCE:
			near += 1
			beach += (shore["beach"] as PackedFloat32Array)[index]
	assert_true(water > 0 and land > 0, "both sea and land are present")
	assert_true(near > 0 and beach / float(near) > 0.2, "gentle shore is flagged as beach")


func test_sheet_lies_on_the_ground_above_the_waterline() -> void:
	var baked := _bake()
	var plan: CityPlan = baked[0]
	var mesh: ArrayMesh = ShoreField.build_sheet(plan, baked[1])
	assert_true(mesh != null, "beaches get a swash sheet")
	var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for index in range(0, vertices.size(), 997):
		var v := vertices[index]
		assert_true(
			absf(v.y - plan.ground_height(Vector2(v.x, v.z)) - ShoreField.SHEET_LIFT) < 0.001,
			"sheet vertex rides the terrain"
		)
