extends "res://tests/godot/test_case.gd"

const BLUEPRINT_SCRIPT := preload("res://scripts/map/definitions/lower_town/lower_town_slice_rrmap_factory.gd")
const DEFINITION_SCRIPT := preload("res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd")


func test_registry_audit_discovers_and_compiles_every_blueprint_source() -> void:
	var diagnostics := MapBlueprintAudit.run()
	var errors: Array[String] = []
	for diagnostic in diagnostics:
		if diagnostic.is_error():
			errors.append(diagnostic.format())
	assert_true(errors.is_empty(), str(errors))
	assert_eq(MapBlueprintAudit.discover_blueprint_sources().size(), MapBlueprintRegistry.entries().size())


func test_preview_runtime_chunk_navigation_and_3d_share_canonical_definition() -> void:
	var direct := MapBlueprintCompiler.compile_with_diagnostics(BLUEPRINT_SCRIPT.create())
	var runtime_definition: MapDefinition = DEFINITION_SCRIPT.create()
	assert_true(direct.is_ok(), str(direct.errors))
	if not direct.is_ok() or runtime_definition == null:
		return
	var canonical: MapDefinition = direct.definition
	assert_eq(runtime_definition.fingerprint, canonical.fingerprint)

	var preview := MapBlueprintEditorPreview.new()
	preview.blueprint_factory = BLUEPRINT_SCRIPT
	var preview_result := preview.compile_blueprint()
	assert_true(preview_result.is_ok(), str(preview_result.errors))
	if preview_result.is_ok():
		assert_eq(preview_result.definition.fingerprint, canonical.fingerprint)
	preview.free()

	var grid := MapBuilder.build(canonical)
	var canonical_snapshot := MapParitySnapshot.serialize(canonical, grid)
	assert_eq(MapParitySnapshot.serialize(runtime_definition, MapBuilder.build(runtime_definition)), canonical_snapshot)

	var chunk_index := MapChunkRuntimeIndex.build(canonical, 32)
	assert_eq(chunk_index.location_id, canonical.location)
	assert_eq(chunk_index.map_fingerprint, canonical.fingerprint)
	assert_eq(chunk_index.object_ids().size(), _stable_object_count(canonical))

	var navigation := MapNavBuilder.create_navigation_region(canonical, grid)
	assert_true(navigation.navigation_polygon != null)
	var view := MapView3D.create(canonical, grid)
	# Large maps stream only nearby chunks initially. Load every indexed consumer
	# chunk before asserting that the 3D builder can regenerate every map object.
	var all_chunks: Array[Vector2i] = []
	for object_id in chunk_index.object_ids():
		for chunk: Vector2i in chunk_index.record(object_id).get("consumer_chunks", []):
			if not all_chunks.has(chunk):
				all_chunks.append(chunk)
	view._update_active_chunks(all_chunks)
	assert_eq(view.get_node("Buildings").get_child_count(), canonical.buildings.size())
	assert_eq(view.get_node("Props").get_child_count(), canonical.props.size())
	assert_eq(MapParitySnapshot.serialize(canonical, grid), canonical_snapshot, "navigation and 3D consumers must not mutate canonical semantics")
	navigation.free()
	view.free()


func _stable_object_count(definition: MapDefinition) -> int:
	return (
		definition.buildings.size()
		+ definition.props.size()
		+ definition.transitions.size()
		+ definition.interaction_anchors.size()
		+ definition.view_landmarks.size()
		+ definition.direction_signs.size()
	)
