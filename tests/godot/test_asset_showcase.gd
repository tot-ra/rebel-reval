extends "res://tests/godot/test_case.gd"

const Definition := preload("res://scenes/debug/asset_showcase_definition.gd")
const SHOWCASE_SCENE := "res://scenes/debug/asset_showcase.tscn"


func test_showcase_definition_is_valid_and_complete() -> void:
	var definition := Definition.create()
	assert_eq(definition.validate(), [], "developer showcase map must satisfy the production map contract")
	assert_true(definition.zones.size() >= MapTypes.ALL_TERRAINS.size())

	var shown_terrains: Array[StringName] = []
	for zone in definition.zones:
		shown_terrains.append(zone["terrain"] as StringName)
	for terrain in MapTypes.ALL_TERRAINS:
		assert_true(shown_terrains.has(terrain), "missing showcase terrain: %s" % terrain)

	var shown_props: Array[StringName] = []
	for prop in definition.props:
		shown_props.append(prop["kind"] as StringName)
	for kind in MapTypes.ALL_PROP_KINDS:
		assert_true(shown_props.has(kind), "missing showcase prop kind: %s" % kind)

	var shown_buildings: Array[StringName] = []
	for building in definition.buildings:
		shown_buildings.append(building["kind"] as StringName)
	for kind in MapTypes.ALL_BUILDING_KINDS:
		assert_true(shown_buildings.has(kind), "missing showcase building kind: %s" % kind)


func test_showcase_includes_review_variants_and_animation_catalogs() -> void:
	assert_eq(Definition.GATE_SPECS.size(), 3, "oak, ironbound, and portcullis need dedicated samples")
	assert_eq(AssetShowcase.HUMANOID_SCENES.size(), 7, "all current humanoid character scenes need comparison samples")
	assert_eq(SharedCharacterRig.CANONICAL_ANIMATIONS.size(), 15)
	assert_eq(CatRig.REQUIRED_ANIMATIONS.size(), 5)
	assert_true(ResourceLoader.exists(AssetShowcase.CART_SCENE_PATH, "PackedScene"))
	for facade in AssetShowcase.FACADE_ASSETS:
		assert_true(ResourceLoader.exists(facade["path"], "PackedScene"), "missing facade sample: %s" % facade["path"])


func test_showcase_scene_and_debug_destination_are_loadable() -> void:
	assert_eq(DebugOverlay.ASSET_SHOWCASE_SCENE, SHOWCASE_SCENE)
	assert_true(ResourceLoader.exists(SHOWCASE_SCENE, "PackedScene"))
	var scene := load(SHOWCASE_SCENE) as PackedScene
	assert_true(scene != null)
	var root := scene.instantiate()
	assert_true(root is AssetShowcase)
	assert_true(root.has_node("Actors/Player"), "gallery must remain walkable with the production player")
	root.free()
