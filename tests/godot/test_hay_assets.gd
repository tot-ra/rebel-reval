extends "res://tests/godot/map_view_3d_test_base.gd"

const HayMeshes := preload("res://scripts/map/view3d/map_view_hay_meshes.gd")
const ForelandDefinition := preload("res://scripts/map/definitions/outdoor/viru_gate_foreland_definition.gd")
const HAY_TEXTURE_PATH := "res://assets/materials/production/hay_fibers.png"


func test_hay_stack_uses_irregular_rick_with_loose_straw() -> void:
	var stack := MapViewMeshBuilder.build_prop(
		{"id": &"hay_store", "kind": MapTypes.PROP_KIND_HAY_STACK, "position": Vector2.ZERO},
		MapTypes.DEFAULT_CELL_SIZE
	)
	assert_true(stack.has_node("HayRick/HayBody"), "hay stack needs a single irregular solid body")
	assert_true(stack.has_node("HayRick/LooseStraw"), "hay stack needs silhouette-breaking loose fibers")
	assert_false(stack.has_node("Mound"), "smooth sphere placeholder must be removed")
	assert_false(stack.has_node("Crown"), "stack must not read as two intersecting pumpkins")

	var stats := HayMeshes.geometry_stats(0)
	var bounds: AABB = stats["aabb"]
	assert_true(bounds.size.x >= 1.5 and bounds.size.x <= 2.2, "rick must preserve its authored two-cell read")
	assert_true(bounds.size.y >= 1.1 and bounds.size.y <= 1.4, "rick needs a believable hand-piled crown")
	assert_true(bounds.position.y >= -0.001, "yard rick must remain grounded")
	assert_true(int(stats["triangles"]) >= 250 and int(stats["triangles"]) <= 450, "shared rick must stay lightweight")

	var body := stack.get_node("HayRick/HayBody") as MeshInstance3D
	var arrays := body.mesh.surface_get_arrays(0)
	assert_true((arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array).size() > 0, "hay body requires portable UVs")
	assert_true((arrays[Mesh.ARRAY_COLOR] as PackedColorArray).size() > 0, "hay body needs deterministic layer tone variation")
	var material := body.material_override as StandardMaterial3D
	assert_eq(material.albedo_texture.resource_path, HAY_TEXTURE_PATH, "rick must use the production fiber texture")
	assert_true(material.uv1_triplanar, "irregular body needs continuous triplanar fibers")
	stack.free()


func test_hay_wagon_reuses_compact_fibrous_load() -> void:
	var wagon := MapViewMeshBuilder.build_prop(
		{"id": &"east.hay_wagon", "kind": MapTypes.PROP_KIND_HAY_WAGON, "position": Vector2.ZERO},
		MapTypes.DEFAULT_CELL_SIZE
	)
	assert_true(wagon.has_node("HayLoad/HayBody"), "Pirita wagon needs a shaped shared hay load")
	assert_true(wagon.has_node("HayLoad/LooseStraw"), "wagon load needs visible overhanging straw")
	assert_false(wagon.has_node("LoadA"), "wagon must not keep sphere load placeholders")
	assert_false(wagon.has_node("LoadB"), "wagon must not keep sphere load placeholders")
	wagon.free()


func test_hay_texture_is_production_size_varied_and_exactly_seamless() -> void:
	var texture := load(HAY_TEXTURE_PATH) as Texture2D
	assert_ne(texture, null, "production hay fiber texture must import")
	var image := texture.get_image()
	assert_eq(image.get_size(), Vector2i(512, 512))
	var minimum := 1.0
	var maximum := 0.0
	for y in image.get_height():
		for x in image.get_width():
			var value := image.get_pixel(x, y).r
			minimum = minf(minimum, value)
			maximum = maxf(maximum, value)
	for y in image.get_height():
		assert_eq(image.get_pixel(0, y), image.get_pixel(image.get_width() - 1, y), "left/right hay seam must be welded")
	for x in image.get_width():
		assert_eq(image.get_pixel(x, 0), image.get_pixel(x, image.get_height() - 1), "top/bottom hay seam must be welded")
	assert_true(maximum - minimum > 0.35, "fiber albedo needs readable overlapping light and shadow")


func test_hay_terrain_builds_batched_ochre_stubble_in_pirita() -> void:
	var definition: MapDefinition = ForelandDefinition.create()
	var grid := MapBuilder.build(definition)
	var scatter := MapViewMeshBuilder.build_scatter(
		definition,
		grid,
		Rect2i(Vector2i(104, 75), Vector2i(52, 31))
	)
	var stubble := scatter.get_node_or_null("HayStubble") as MultiMeshInstance3D
	assert_ne(stubble, null, "Pirita hay meadow needs geometric cut-straw silhouettes")
	assert_true(stubble.multimesh.instance_count >= 80, "harvested meadow band needs readable but batched stubble coverage")
	assert_eq(scatter.find_children("HayStubble", "MultiMeshInstance3D", true, false).size(), 1, "hay ground cover must stay in one draw batch")
	scatter.free()
