extends "res://tests/godot/test_case.gd"

## R-1549: a pickup's model, not its floor marker, owns the focus silhouette.
const SENSOR := preload("res://scenes/interaction/interactable.tscn")
const LOCATION := &"loc.outline_test"
const OBJECT := &"world.outline_test"
const ITEM := &"item.forge_bearded_axe"


class RigRuntime:
	extends Node
	var rig: Node3D

	func get_actor_rig(_actor: Node2D) -> Node3D:
		return rig


func test_explicit_mesh_root_and_descendants_restore_their_overlays() -> void:
	var f := _fixture()
	var mesh := _mesh(f.root)
	var authored := StandardMaterial3D.new()
	mesh.material_overlay = authored
	var nested := _mesh(mesh)
	f.indicator.set_outline_root(mesh)
	f.sensor.set_focused(true)
	assert_true(mesh.material_overlay is ShaderMaterial, "include the root mesh")
	assert_eq((mesh.material_overlay as ShaderMaterial).get_shader_parameter("silhouette_limit"), 1.0)
	assert_true(nested.material_overlay == mesh.material_overlay, "include nested meshes")
	f.sensor.set_focused(false)
	assert_true(mesh.material_overlay == authored, "restore the original overlay")
	assert_true(nested.material_overlay == null)
	f.root.free()


func test_hidden_subtrees_empty_meshes_and_unbound_siblings_are_excluded() -> void:
	var f := _fixture()
	var model := Node3D.new()
	f.root.add_child(model)
	var visible_mesh := _mesh(model)
	var hidden_parent := Node3D.new()
	hidden_parent.visible = false
	model.add_child(hidden_parent)
	var hidden_mesh := _mesh(hidden_parent)
	var empty_mesh := MeshInstance3D.new()
	model.add_child(empty_mesh)
	var sibling := _mesh(f.root)
	f.indicator.set_outline_root(model)
	f.sensor.set_focused(true)
	assert_true(visible_mesh.material_overlay is ShaderMaterial)
	assert_true(hidden_mesh.material_overlay == null, "hidden ancestors must be respected")
	assert_true(empty_mesh.material_overlay == null)
	assert_true(sibling.material_overlay == null, "never search the scene by proximity")
	f.root.free()


func test_disable_and_reenable_refresh_the_external_overlay_immediately() -> void:
	var f := _fixture()
	var mesh := _mesh(f.root)
	f.indicator.set_outline_root(mesh)
	f.sensor.set_focused(true)
	f.indicator.set_enabled(false)
	assert_true(mesh.material_overlay == null, "hiding the marker must clear its model")
	assert_false((f.indicator.get_node("FocusRing") as MeshInstance3D).visible)
	f.indicator.set_enabled(true)
	assert_true(mesh.material_overlay is ShaderMaterial)
	f.root.free()


func test_sensor_disable_is_observed_by_the_indicator() -> void:
	var f := _fixture()
	var mesh := _mesh(f.root)
	f.indicator.set_outline_root(mesh)
	f.sensor.set_focused(true)
	f.sensor.enabled = false
	f.indicator._process(0.0)
	assert_true(mesh.material_overlay == null)
	assert_false(f.indicator.visible)
	f.root.free()


func test_destroyed_sensor_clears_the_outline_on_the_next_sync() -> void:
	var f := _fixture()
	var mesh := _mesh(f.root)
	f.indicator.set_outline_root(mesh)
	f.sensor.set_focused(true)
	f.sensor.free()
	f.indicator._process(0.0)
	assert_true(mesh.material_overlay == null)
	assert_false(f.indicator.visible)
	f.root.free()


func test_freeing_the_indicator_restores_an_authored_overlay() -> void:
	var f := _fixture()
	var mesh := _mesh(f.root)
	var authored := StandardMaterial3D.new()
	mesh.material_overlay = authored
	f.indicator.set_outline_root(mesh)
	f.sensor.set_focused(true)
	f.indicator.free()
	assert_true(mesh.material_overlay == authored, "unbind must not leave a yellow model")
	f.root.free()


func test_rebinding_a_focused_indicator_clears_the_previous_model() -> void:
	var f := _fixture()
	var first := _mesh(f.root)
	var second := _mesh(f.root)
	f.indicator.set_outline_root(first)
	f.sensor.set_focused(true)
	f.indicator.set_outline_root(second)
	assert_true(first.material_overlay == null)
	assert_true(second.material_overlay is ShaderMaterial)
	f.root.free()


func test_later_overlay_owner_is_not_erased_when_focus_leaves() -> void:
	var f := _fixture()
	var mesh := _mesh(f.root)
	f.indicator.set_outline_root(mesh)
	f.sensor.set_focused(true)
	var replacement := StandardMaterial3D.new()
	mesh.material_overlay = replacement
	f.sensor.set_focused(false)
	assert_true(mesh.material_overlay == replacement)
	f.root.free()


func test_freed_visual_root_can_be_unfocused_without_errors() -> void:
	var f := _fixture()
	var mesh := _mesh(f.root)
	f.indicator.set_outline_root(mesh)
	f.sensor.set_focused(true)
	mesh.free()
	f.sensor.set_focused(false)
	f.root.free()


func test_actor_rig_fallback_still_outlines_and_restores_visible_meshes() -> void:
	var f := _fixture()
	var runtime := RigRuntime.new()
	f.root.add_child(runtime)
	var mesh := _mesh(f.root)
	runtime.rig = mesh
	f.indicator._view_runtime = runtime
	f.sensor.set_focused(true)
	assert_true(mesh.material_overlay is ShaderMaterial, "keep the NPC fallback")
	f.sensor.set_focused(false)
	assert_true(mesh.material_overlay == null)
	f.root.free()


func test_item_view_exposes_only_the_model_and_handles_missing_models() -> void:
	var root := _root()
	var template := _mesh(null)
	var packed := PackedScene.new()
	assert_eq(packed.pack(template), OK)
	template.free()
	var view := WorldItemView.new()
	root.add_child(view)
	view.configure(packed, Vector2.ZERO, MapTypes.DEFAULT_CELL_SIZE)
	assert_true(view.get_item_visual_root() is MeshInstance3D)
	assert_false(view.has_node("PickupOutline"), "no floor frame: pickups show only the contour")
	view.configure(null, Vector2.ZERO, MapTypes.DEFAULT_CELL_SIZE)
	assert_true(view.get_item_visual_root() == null)
	root.free()


func test_controller_spawn_binds_the_actual_pickup_model_and_unbind_clears_it() -> void:
	restore_demo_session()
	var root := _root()
	var runtime := MapViewRuntime.new()
	root.add_child(runtime)
	runtime.set_process(false)
	var controller := WorldItemController.new()
	root.add_child(controller)
	var state: GameState = SessionState.state
	assert_true(state.place_world_item(LOCATION, OBJECT, ITEM, Vector2(64, 32)))
	state.mark_world_defaults_seeded(LOCATION)
	controller.setup(root, MapDefinition.new(), runtime, null, LOCATION)
	controller.set_process(false)
	assert_eq(controller._views.size(), 1)
	var item: WorldItem = controller._views.keys()[0]
	var view: WorldItemView = controller._views[item]
	var sensor: Interactable = controller._interactables[item]
	assert_true(view.get_item_visual_root() != null, "resolve the real catalog world_scene")
	sensor.set_focused(true)
	var meshes := view.get_item_visual_root().find_children("*", "MeshInstance3D", true, false)
	assert_false(meshes.is_empty(), "the actual pickup must have model meshes")
	for node: Node in meshes:
		assert_true((node as MeshInstance3D).material_overlay is ShaderMaterial)
	assert_false(view.has_node("PickupOutline"), "no floor frame lighting the pickup from below")
	var indicator: InteractableWorldIndicator = controller._indicators[item]
	assert_false(
		(indicator.get_node("FocusRing") as MeshInstance3D).visible,
		"pickups get no floor ring"
	)
	# Cursor hover alone (no proximity focus) draws the contour.
	sensor.set_focused(false)
	for node: Node in meshes:
		assert_true((node as MeshInstance3D).material_overlay == null)
	controller._set_view_hovered(item, true)
	for node: Node in meshes:
		assert_true((node as MeshInstance3D).material_overlay is ShaderMaterial)
	controller._set_view_hovered(item, false)
	for node: Node in meshes:
		assert_true((node as MeshInstance3D).material_overlay == null)
	sensor.set_focused(true)
	controller._interactable_binder.unbind(sensor)
	# Binder frees the marker deferred; its exit hook must restore the external model.
	await (Engine.get_main_loop() as SceneTree).process_frame
	for node: Node in meshes:
		assert_true((node as MeshInstance3D).material_overlay == null)
	assert_true(state.is_world_item_placed(LOCATION, OBJECT), "presentation cannot pick up the item")
	root.free()
	restore_demo_session()


func _fixture() -> Dictionary:
	var root := _root()
	var sensor: Interactable = SENSOR.instantiate()
	root.add_child(sensor)
	var indicator := InteractableWorldIndicator.new()
	root.add_child(indicator)
	indicator.attach(sensor, MapTypes.DEFAULT_CELL_SIZE)
	return {"root": root, "sensor": sensor, "indicator": indicator}


func _root() -> Node2D:
	var root := Node2D.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(root)
	return root


func _mesh(parent: Node) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	if parent != null:
		parent.add_child(mesh)
	return mesh
