extends "res://tests/godot/test_case.gd"

const PREVIEW_SCRIPT := preload("res://scripts/map/map_blueprint_editor_preview.gd")
const BLUEPRINT_SCRIPT := preload("res://scripts/map/definitions/lower_town/lower_town_slice_blueprint.gd")
const REVAL_EAST_SCENE := preload("res://scenes/reval_east/reval_east.tscn")


func test_preview_compiles_with_production_map_blueprint_compiler() -> void:
	var preview := PREVIEW_SCRIPT.new()
	preview.blueprint_factory = BLUEPRINT_SCRIPT
	var result: MapBlueprintCompileResult = preview.compile_blueprint()
	var direct := MapBlueprintCompiler.compile_with_diagnostics(BLUEPRINT_SCRIPT.create())
	assert_true(result.is_ok(), str(result.errors))
	assert_true(direct.is_ok(), str(direct.errors))
	if result.is_ok() and direct.is_ok():
		assert_eq(result.definition.fingerprint, direct.definition.fingerprint)
		assert_eq(result.definition.buildings, direct.definition.buildings)
		assert_eq(result.definition.props, direct.definition.props)
		assert_eq(result.definition.view_landmarks, direct.definition.view_landmarks)
		assert_eq(result.definition.interaction_anchors, direct.definition.interaction_anchors)
	preview.free()


func test_preview_is_inert_at_runtime_until_intentionally_rebuilt() -> void:
	var preview := PREVIEW_SCRIPT.new()
	preview.blueprint_factory = BLUEPRINT_SCRIPT
	assert_false(preview.rebuild_preview(), "normal runtime code must not build editor preview nodes")
	assert_true(preview.preview_root() == null)
	assert_true(preview.rebuild_preview(true), "explicit rebuild is available for tests or intentional runtime authoring")
	var generated := preview.preview_root()
	assert_true(generated != null)
	if generated != null:
		assert_true(bool(generated.get_meta("preview_only", false)))
		assert_eq(generated.owner, null, "generated root must never be scene-owned")
		assert_true(generated.get_node_or_null("Gameplay") == null, "preview must not assemble transitions")
		assert_true(generated.get_node_or_null("Navigation") == null, "navigation overlay must not add a live region")
		assert_eq(_count_enabled_collision_objects(generated), 0, "preview visuals must not participate in physics")
	preview.free()


func test_generated_preview_nodes_do_not_pack_into_scene() -> void:
	var host := Node2D.new()
	host.name = "Host"
	var preview := PREVIEW_SCRIPT.new()
	preview.name = "Preview"
	host.add_child(preview)
	preview.owner = host
	preview.blueprint_factory = BLUEPRINT_SCRIPT
	assert_true(preview.rebuild_preview(true))

	var packed := PackedScene.new()
	assert_eq(packed.pack(host), OK)
	var restored := packed.instantiate()
	assert_true(restored.get_node_or_null("Preview") != null, "authored preview component should remain")
	assert_true(
		restored.get_node_or_null("Preview/%s" % PREVIEW_SCRIPT.GENERATED_ROOT_NAME) == null,
		"derived preview nodes must not serialize into .tscn or exported PackedScene data"
	)
	restored.free()
	host.free()


func test_reval_east_contains_only_the_editor_safe_preview_component() -> void:
	var scene := REVAL_EAST_SCENE.instantiate()
	var preview := scene.get_node_or_null("MapBlueprintPreview")
	assert_true(preview != null, "Lower Town migration scene needs the reusable preview component")
	if preview != null:
		assert_eq(preview.blueprint_factory, BLUEPRINT_SCRIPT)
		assert_true(preview.get_node_or_null(PREVIEW_SCRIPT.GENERATED_ROOT_NAME) == null)
	scene.free()


func _count_enabled_collision_objects(root: Node) -> int:
	var count := 0
	if root is CollisionObject2D:
		var object := root as CollisionObject2D
		if object.collision_layer != 0 or object.collision_mask != 0:
			count += 1
	for child in root.get_children(true):
		count += _count_enabled_collision_objects(child)
	return count
