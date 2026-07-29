extends "res://tests/godot/test_case.gd"

const MapBuilder := preload("res://scripts/map/map_builder.gd")
const MapView3D := preload("res://scripts/map/view3d/map_view_3d.gd")
const MapViewDecals := preload("res://scripts/map/view3d/map_view_decals.gd")
const SmithyCourtyard := preload("res://scripts/map/smithy_courtyard_definition.gd")


func _showcase_definition(with_decals: bool) -> MapDefinition:
	var definition := MapDefinition.new()
	definition.map_id = &"decal_test"
	definition.seed = MapTypes.DEFAULT_SEED
	definition.cell_size = MapTypes.DEFAULT_CELL_SIZE
	definition.size_cells = Vector2i(10, 10)
	definition.base_terrain = MapTypes.TERRAIN_GRASS
	definition.player_spawn = Vector2(5.0, 5.0) * float(definition.cell_size)
	definition.location = &"test"
	definition.scope = &"prototype"
	definition.active = false
	definition.palette = &"clean_painted"
	definition.fingerprint = "decal_test_v1"
	definition.camera_bounds = definition.cell_rect_to_world_rect(Rect2i(0, 0, 10, 10))
	definition.source_references = ["tests/godot/test_map_view_decals.gd"]
	if with_decals:
		definition.decals = [
			{"id": &"soot_1", "kind": MapTypes.DECAL_KIND_SOOT, "position": Vector2(16.0, 16.0)},
			{"id": &"mud_1", "kind": MapTypes.DECAL_KIND_MUD, "position": Vector2(32.0, 32.0), "radius": 1.2},
			{"id": &"blood_1", "kind": MapTypes.DECAL_KIND_BLOOD, "position": Vector2(48.0, 24.0), "rotation": 0.5},
		]
	return definition


func test_decals_placed_from_map_data() -> void:
	var def := _showcase_definition(true)
	var grid := MapBuilder.build(def)
	var view := MapView3D.create(def, grid)
	var decals_node := view.get_node_or_null("Decals") as Node3D
	assert_true(decals_node != null, "Decals node must be added during assembly")
	assert_eq(decals_node.get_child_count(), 3, "Three authored decals must produce three child nodes")
	var soot := decals_node.get_node("Decal_soot_1") as MeshInstance3D
	assert_true(soot != null, "Soot decal must exist")
	assert_eq(soot.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "Decals must not cast shadows")
	assert_eq(soot.gi_mode, GeometryInstance3D.GI_MODE_DISABLED, "Decals must not affect GI")
	var material := soot.material_override as ShaderMaterial
	assert_true(material != null, "Decal must use a soft-edge ShaderMaterial")
	assert_true(material.shader != null, "Decal shader must be assigned")
	var mask: Variant = material.get_shader_parameter("mask_texture")
	assert_true(mask != null, "Decal must bind an authored alpha mask texture")
	# Decals must sit on sampled ground, not under cobble/dirt relief.
	assert_true(soot.position.y >= MapViewDecals.GROUND_LIFT - 0.001, "Decal Y must clear ground lift")
	view.free()


func test_decal_mask_library_covers_all_kinds() -> void:
	for kind in MapTypes.ALL_DECAL_KINDS:
		var path := "res://assets/materials/decals/%s.png" % String(kind)
		assert_true(ResourceLoader.exists(path), "Missing decal mask: %s" % path)


func test_decals_ignore_invalid_kind() -> void:
	var def := _showcase_definition(false)
	def.decals = [
		{"id": &"bad", "kind": &"nonexistent_kind", "position": Vector2(10.0, 10.0)},
		{"id": &"good", "kind": MapTypes.DECAL_KIND_GRIME, "position": Vector2(20.0, 20.0)},
	]
	var grid := MapBuilder.build(def)
	var view := MapView3D.create(def, grid)
	var decals_node := view.get_node_or_null("Decals") as Node3D
	assert_true(decals_node != null, "Decals node must exist even with invalid entries")
	assert_eq(decals_node.get_child_count(), 1, "Invalid decal kind must be skipped")
	view.free()


func test_clearing_decals_does_not_affect_gameplay() -> void:
	var def := _showcase_definition(true)
	var grid_before := MapBuilder.build(def)
	var fingerprint_before := grid_before.fingerprint()
	def.decals.clear()
	var grid_after := MapBuilder.build(def)
	var fingerprint_after := grid_after.fingerprint()
	assert_eq(fingerprint_before, fingerprint_after, "Removing decals must not change grid fingerprint")


func test_clear_helper_removes_decal_nodes() -> void:
	var def := _showcase_definition(true)
	var view := MapView3D.create(def, MapBuilder.build(def))
	assert_true(view.get_node_or_null("Decals") != null)
	MapViewDecals.clear(view)
	assert_true(view.get_node_or_null("Decals") == null, "clear() must remove the Decals node")
	view.free()


func test_smithy_courtyard_authors_wear_decals() -> void:
	var definition := SmithyCourtyard.create()
	assert_true(definition.decals.size() >= 3, "Prototype courtyard should carry forge and threshold wear")
	var kinds: Dictionary = {}
	for decal in definition.decals:
		kinds[decal.get("kind", &"")] = true
	assert_true(kinds.has(MapTypes.DECAL_KIND_SOOT), "Forge pad needs soot")
	assert_true(kinds.has(MapTypes.DECAL_KIND_MUD), "Lane threshold needs mud")


func test_kalev_smithy_authors_wear_decals() -> void:
	var KalevSmithyDefinition := preload("res://scripts/map/definitions/lower_town/kalev_smithy_definition.gd")
	var definition: MapDefinition = KalevSmithyDefinition.create()
	assert_true(definition.decals.size() >= 4, "Smithy interior needs forge, door, and yard decals")
	var kinds: Dictionary = {}
	for decal in definition.decals:
		kinds[decal.get("kind", &"")] = true
	assert_true(kinds.has(MapTypes.DECAL_KIND_SOOT), "Forge bay needs soot")
	assert_true(kinds.has(MapTypes.DECAL_KIND_MUD), "Courtyard door needs mud")
	assert_true(kinds.has(MapTypes.DECAL_KIND_GRIME), "Living bay needs grime")


func test_lower_town_slice_authors_wear_decals() -> void:
	var LowerTownSliceDefinition := preload("res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd")
	var definition: MapDefinition = LowerTownSliceDefinition.create()
	assert_true(definition.decals.size() >= 4, "Lower Town slice needs threshold and yard decals")
	var kinds: Dictionary = {}
	for decal in definition.decals:
		kinds[decal.get("kind", &"")] = true
	assert_true(kinds.has(MapTypes.DECAL_KIND_SOOT), "Courtyard anvil needs soot")
	assert_true(kinds.has(MapTypes.DECAL_KIND_MUD), "District doors need mud")
	assert_true(kinds.has(MapTypes.DECAL_KIND_WET_THRESHOLD), "Smithy threshold needs wet wear")
