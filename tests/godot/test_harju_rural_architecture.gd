extends "res://tests/godot/test_case.gd"

const RRMAP_PATH := "res://content/maps/world_harju.rrmap"


func test_harju_parses_as_an_inactive_evidence_linked_rural_prototype() -> void:
	var parsed := MapRrmapParser.parse_file(RRMAP_PATH)
	assert_true(parsed.is_ok(), str(parsed.formatted_diagnostics()))
	if not parsed.is_ok():
		return
	assert_eq(parsed.definition.map_id, &"world.harju")
	assert_eq(parsed.definition.size_cells, Vector2i(52, 30))
	assert_eq(parsed.definition.scope, &"prototype")
	assert_false(parsed.definition.active)
	assert_true("history/dossiers/hinterland/harju-village-and-manor.md" in parsed.definition.source_references)
	assert_true("history/dossiers/architecture/rural-smoke-dwelling-and-farmstead-1343.md" in parsed.definition.source_references)


func test_barn_dwelling_keeps_two_bays_and_rejects_late_rural_features() -> void:
	var parsed := MapRrmapParser.parse_file(RRMAP_PATH)
	assert_true(parsed.is_ok(), str(parsed.formatted_diagnostics()))
	if not parsed.is_ok():
		return
	var building := _building(parsed.definition, &"elder_farmstead")
	assert_eq(building.get("primitive"), &"barn_dwelling_1343")
	assert_eq(MapViewMeshBuilderBuildingHouses.house_style(building), MapViewMeshBuilderConfig.HOUSE_STYLE_LOG)
	assert_eq(MapViewMeshBuilderBuildingHouses.roof_style(building), MapViewMeshBuilderConfig.ROOF_STYLE_THATCH)
	var node := MapViewMeshBuilder.build_building(building, parsed.definition.cell_size)
	assert_true(node.has_node("DwellingDoor"), "rehetuba needs its own low boarded door")
	assert_true(node.has_node("ThreshingGate"), "rehealune needs a broad working gate")
	assert_true(node.has_node("BarnDwellingBaySeam"), "the conservative two-part plan must read externally")
	assert_true(node.has_node("SmokeVent"), "the heated room needs an unglazed smoke/light aperture")
	assert_true(node.has_node("LogEnd_0_-1_-1"), "horizontal log construction needs corner heads")
	assert_true(node.has_node("ThatchRidge"), "barn-dwelling uses the conservative thatch lane")
	assert_true(node.has_node("FoundationPad_-1_-1"), "rural sill uses local packing stones")
	assert_false(node.has_node("Plinth"), "rural dwelling must not inherit a continuous urban plinth")
	assert_false(node.has_node("Chimney"), "1343 smoke-room oven is flueless")
	assert_false(node.has_node("Window0"), "later glazed window rhythms must not be back-projected")
	assert_false(node.has_node("DoorStep"), "rural doorway must not inherit the urban stone step")
	assert_false(node.has_node("WindowLights"), "unglazed smoke vents must not glow like city windows")
	node.free()


func test_rural_primitive_material_guard_rejects_masonry_and_tile_defaults() -> void:
	var building := {
		"id": &"guarded_smoke_cottage",
		"kind": MapTypes.BUILDING_KIND_HOUSE,
		"primitive": &"smoke_cottage_1343",
		"wall_material": &"stone",
		"roof_material": &"tile",
	}
	assert_eq(MapViewMeshBuilderBuildingHouses.house_style(building), MapViewMeshBuilderConfig.HOUSE_STYLE_LOG)
	assert_eq(MapViewMeshBuilderBuildingHouses.roof_style(building), MapViewMeshBuilderConfig.ROOF_STYLE_THATCH)
	building["roof_material"] = &"shingle"
	assert_eq(MapViewMeshBuilderBuildingHouses.roof_style(building), MapViewMeshBuilderConfig.ROOF_STYLE_SHINGLE)


func test_harju_farmyard_has_work_surfaces_storage_and_spring_livestock() -> void:
	var parsed := MapRrmapParser.parse_file(RRMAP_PATH)
	assert_true(parsed.is_ok(), str(parsed.formatted_diagnostics()))
	if not parsed.is_ok():
		return
	var required: Array[StringName] = [
		MapTypes.PROP_KIND_ROOT_CELLAR_MOUND,
		MapTypes.PROP_KIND_FARM_CART,
		MapTypes.PROP_KIND_KITCHEN_GARDEN,
		MapTypes.PROP_KIND_FIELD_STRIP,
		MapTypes.PROP_KIND_PASTURE_FENCE,
		MapTypes.PROP_KIND_CATTLE,
		MapTypes.PROP_KIND_SHEEP,
	]
	var present: Dictionary = {}
	for prop in parsed.definition.props:
		present[prop["kind"]] = true
	for kind in required:
		assert_true(present.has(kind), "Harju working yard is missing %s" % kind)


func _building(definition: MapDefinition, building_id: StringName) -> Dictionary:
	for building in definition.buildings:
		if building["id"] == building_id:
			return building
	fail("missing building %s" % building_id)
	return {}
