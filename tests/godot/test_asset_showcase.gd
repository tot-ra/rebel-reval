extends "res://tests/godot/test_case.gd"

const Definition := preload("res://scenes/debug/asset_showcase_definition.gd")
const SMALL_SHOWCASE_SCENE := "res://scenes/debug/asset_showcase.tscn"
const LARGE_SHOWCASE_SCENE := "res://scenes/debug/asset_showcase_large.tscn"


func test_showcase_definitions_are_valid_and_complete() -> void:
	var small_definition := Definition.create_small()
	var large_definition := Definition.create_large()
	assert_eq(small_definition.validate(), [], "small-item showcase must satisfy the production map contract")
	assert_eq(large_definition.validate(), [], "large-item showcase must satisfy the production map contract")
	assert_true(large_definition.zones.size() >= MapTypes.ALL_TERRAINS.size())
	assert_true(small_definition.zones.is_empty(), "terrain catalog belongs only on the large-item map")

	var shown_terrains: Array[StringName] = []
	for zone in large_definition.zones:
		shown_terrains.append(zone["terrain"] as StringName)
	for terrain in MapTypes.ALL_TERRAINS:
		assert_true(shown_terrains.has(terrain), "missing large showcase terrain: %s" % terrain)

	var small_props := _prop_kinds(small_definition)
	var large_props := _prop_kinds(large_definition)
	for kind in MapTypes.ALL_PROP_KINDS:
		assert_true(
			small_props.has(kind) or large_props.has(kind),
			"missing showcase prop kind: %s" % kind
		)
		if kind in Definition.LARGE_PROP_KINDS:
			assert_true(large_props.has(kind), "large prop is on the wrong map: %s" % kind)
			assert_false(small_props.has(kind), "large prop leaked onto the small map: %s" % kind)
		else:
			assert_true(small_props.has(kind), "small prop is on the wrong map: %s" % kind)
	# wall_walk_access is an architectural variant on the large map; its generic
	# stairs sample remains in the small-object catalog.
	assert_true(large_props.has(MapTypes.PROP_KIND_STAIRS))

	var shown_buildings: Array[StringName] = []
	for building in large_definition.buildings:
		shown_buildings.append(building["kind"] as StringName)
	for kind in MapTypes.ALL_BUILDING_KINDS:
		assert_true(shown_buildings.has(kind), "missing large showcase building kind: %s" % kind)
	assert_true(small_definition.buildings.is_empty(), "building catalog belongs only on the large-item map")


func test_large_showcase_uses_a_spacious_grid() -> void:
	assert_true(Definition.TERRAIN_PATCH_SIZE.x > 12)
	assert_true(Definition.TERRAIN_PATCH_SIZE.y > 10)
	assert_true(Definition.LARGE_PROP_SPACING_CELLS.x > Definition.SMALL_PROP_SPACING_CELLS.x * 2)
	assert_true(Definition.LARGE_PROP_SPACING_CELLS.y > Definition.SMALL_PROP_SPACING_CELLS.y * 2)
	for left_index in Definition.BUILDING_SPECS.size():
		var left: Rect2i = Definition.BUILDING_SPECS[left_index]["cell_rect"]
		for right_index in range(left_index + 1, Definition.BUILDING_SPECS.size()):
			var right: Rect2i = Definition.BUILDING_SPECS[right_index]["cell_rect"]
			assert_false(left.intersects(right), "large building samples must not overlap")


func test_showcases_include_review_variants_and_animation_catalogs() -> void:
	assert_eq(Definition.GATE_SPECS.size(), 3, "oak, ironbound, and portcullis need dedicated samples")
	assert_eq(AssetShowcase.HUMANOID_SCENES.size(), 8, "all current humanoid character scenes need comparison samples")
	assert_true(
		AssetShowcase.HUMANOID_SCENES.any(
			func(scene: PackedScene) -> bool: return scene.resource_path.ends_with("danish_warrior.tscn")
		),
		"small debug showcase must include the Danish warrior"
	)
	assert_eq(SharedCharacterRig.CANONICAL_ANIMATIONS.size(), 15)
	assert_eq(CatRig.REQUIRED_ANIMATIONS.size(), 5)
	assert_true(ResourceLoader.exists(AssetShowcase.CART_SCENE_PATH, "PackedScene"))
	for facade in AssetShowcase.FACADE_ASSETS:
		assert_true(ResourceLoader.exists(facade["path"], "PackedScene"), "missing facade sample: %s" % facade["path"])


func test_showcase_scenes_and_debug_destinations_are_loadable() -> void:
	assert_eq(DebugOverlay.ASSET_SHOWCASE_SCENE, SMALL_SHOWCASE_SCENE)
	assert_eq(DebugOverlay.LARGE_ASSET_SHOWCASE_SCENE, LARGE_SHOWCASE_SCENE)
	assert_eq(DebugOverlay.ASSET_SHOWCASE_SCENES, [SMALL_SHOWCASE_SCENE, LARGE_SHOWCASE_SCENE])
	_assert_showcase_scene(SMALL_SHOWCASE_SCENE, Definition.SHOWCASE_SMALL)
	_assert_showcase_scene(LARGE_SHOWCASE_SCENE, Definition.SHOWCASE_LARGE)


func _prop_kinds(definition: MapDefinition) -> Array[StringName]:
	var kinds: Array[StringName] = []
	for prop in definition.props:
		var kind: StringName = prop["kind"]
		if kind not in kinds:
			kinds.append(kind)
	return kinds


func _assert_showcase_scene(path: String, expected_kind: StringName) -> void:
	assert_true(ResourceLoader.exists(path, "PackedScene"))
	var scene := load(path) as PackedScene
	assert_true(scene != null)
	var root := scene.instantiate() as AssetShowcase
	assert_true(root != null)
	assert_eq(StringName(root.showcase_kind), expected_kind)
	assert_true(root.has_node("Actors/Player"), "gallery must remain walkable with the production player")
	root.free()
