extends "res://tests/godot/test_case.gd"

## Kitchen gardens (R-1645, docs/SYSTEMS/FARMLAND.md): the wattle-edged bed model
## shared by the `kitchen_garden` prop and the farmhouse yards of the open city.

const Models := preload("res://scripts/map/view3d/map_view_kitchen_garden_models.gd")


func _prop(id: String) -> Node3D:
	return MapViewMeshBuilder.build_prop(
		{"id": StringName(id), "kind": MapTypes.PROP_KIND_KITCHEN_GARDEN, "position": Vector2.ZERO},
		MapTypes.DEFAULT_CELL_SIZE
	)


func _named(root: Node, prefix: String) -> Array[Node]:
	var out: Array[Node] = []
	for child in root.find_children("%s*" % prefix, "", true, false):
		out.append(child)
	return out


func test_prop_is_soil_wattle_and_crop_rows_not_spheres() -> void:
	var prop := _prop("prop.garden.a")
	assert_eq(_named(prop, "Bed").size(), 2, "two beds")
	assert_eq(_named(prop, "Soil").size(), 2, "tilled soil in each bed")
	assert_eq(_named(prop, "Wattle").size(), 2, "wattle round each bed")
	var crops := _named(prop, "Crop_")
	assert_eq(crops.size(), 2, "a crop row set per bed")
	for crop: Node in crops:
		assert_true((crop as MultiMeshInstance3D).multimesh.instance_count >= 6, "%s is planted in rows" % crop.name)  # gdlint: ignore=max-line-length
	for mesh: Node in prop.find_children("*", "MeshInstance3D", true, false):
		assert_false((mesh as MeshInstance3D).mesh is SphereMesh, "no sphere stands in for a plant")
	prop.free()


func test_soil_faces_up_and_is_brown() -> void:
	var mesh := Models.soil_mesh(Vector2(3.0, 1.0), 0)
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	# The vertex nearest the bed centre: corners are smoothed with the side skirt.
	var middle := 0
	for i in vertices.size():
		if Vector2(vertices[i].x, vertices[i].z).length() < Vector2(vertices[middle].x, vertices[middle].z).length():  # gdlint: ignore=max-line-length
			middle = i
	assert_true(normals[middle].y > 0.8, "the soil top faces the sky")
	assert_true(colors[0].r > colors[0].b and colors[0].g < 0.4, "the soil is dark brown")


func test_neighbouring_beds_grow_different_crops_and_are_deterministic() -> void:
	var a := _prop("prop.garden.b")
	var b := _prop("prop.garden.b")
	var crops_a: Array = []
	var crops_b: Array = []
	for bed: Node in _named(a, "Bed"):
		crops_a.append(bed.get_meta(&"crop"))
	for bed: Node in _named(b, "Bed"):
		crops_b.append(bed.get_meta(&"crop"))
	assert_eq(crops_a, crops_b, "same id, same garden")
	assert_true(crops_a[0] != crops_a[1], "neighbouring beds grow different crops")
	a.free()
	b.free()


func test_bare_soil_before_the_garden_sprouts() -> void:
	var root := Node3D.new()
	Models.add_model(root, "garden.bare", Vector2(3.0, 1.0), 2, 0.4, 0.0)
	assert_eq(_named(root, "Crop_").size(), 0, "no plants on freshly dug beds")
	assert_eq(_named(root, "Soil").size(), 2, "the beds are still there")
	root.free()


func test_every_farmhouse_keeps_a_garden_clear_of_buildings_roads_and_fields() -> void:
	var plan := CityPlan.load_default()
	var features := CityFarmland.features_for(plan)
	var gardens: Array[Dictionary] = []
	var land: Array[Dictionary] = []
	for f in features:
		if f["kind"] == &"kitchen_garden":
			gardens.append(f)
		else:
			land.append(f)
	var houses := 0
	for f: Dictionary in plan.data["farmsteads"]:
		var index := plan.building_index_by_id(String(f["building"]))
		if index >= 0 and String(plan.buildings[index]["kind"]) == "house":
			houses += 1
	# A few farmhouses sit on cramped or steep plots; most must have a garden.
	assert_true(gardens.size() >= int(houses * 0.75), "%d of %d farmhouses keep a garden" % [gardens.size(), houses])  # gdlint: ignore=max-line-length
	var ids := {}
	for g in gardens:
		assert_false(ids.has(g["id"]), "%s is unique" % g["id"])
		ids[g["id"]] = true
		var poly: PackedVector2Array = g["polygon"]
		for index in plan.buildings_near(g["centre"], 40.0):
			assert_true(Geometry2D.intersect_polygons(poly, plan.footprint(index)).is_empty(), "%s clear of %s" % [g["id"], plan.buildings[index]["id"]])  # gdlint: ignore=max-line-length
		for p in poly:
			assert_true(CityShore.road_raster_at(plan, p).r <= CityFarmland.GARDEN_ROAD_BODY, "%s off the road" % g["id"])  # gdlint: ignore=max-line-length
		for f in land:
			assert_true(Geometry2D.intersect_polygons(poly, f["polygon"]).is_empty(), "%s clear of %s" % [g["id"], f["id"]])  # gdlint: ignore=max-line-length
	var again := CityFarmland.kitchen_gardens_for(plan, land)
	assert_eq(again.size(), gardens.size(), "placement is deterministic")
	for i in again.size():
		assert_eq(again[i]["centre"], gardens[i]["centre"], "%s stays put" % gardens[i]["id"])


func test_city_garden_builds_beds_on_the_garden_calendar() -> void:
	var plan := CityPlan.load_default()
	var farmland := CityFarmland.create(plan)
	var garden := {}
	for f in CityFarmland.features_for(plan):
		if f["kind"] == &"kitchen_garden":
			garden = f
			break
	assert_false(garden.is_empty(), "a garden exists")
	# update_for builds one feature per call; stream until the garden is in.
	var built: Array[Node] = []
	for _step in 400:
		farmland.update_for(garden["centre"])
		built = farmland.find_children("KitchenGarden", "", true, false)
		if not built.is_empty():
			break
	assert_true(built.size() >= 1, "the garden streams in near its farmhouse")
	assert_eq(_named(built[0], "Bed").size(), int(garden["beds"]), "bed count follows the plan")
	farmland.free()
