extends "res://tests/godot/test_case.gd"


func test_disabled_by_default_and_never_enables_scene_swap_fallback() -> void:
	var host := WorldHost.new()
	assert_false(host.additive_residency_enabled)
	assert_false(host.scene_swap_fallback_enabled)
	assert_false(host.is_additive_residency_active())
	assert_false(host.is_scene_swap_fallback_enabled())
	host.free()


func test_additive_residency_keeps_one_owner_and_global_position_across_seam() -> void:
	var definitions: Array[MapDefinition] = [_map_a(), _map_b()]
	var layout := MapWorldLayout.build(definitions, &"map_a", &"test_outdoor")
	var host := WorldHost.new()
	var player := Node2D.new()
	var camera := Camera3D.new()
	var session := Node.new()
	host.additive_residency_enabled = true
	assert_true(host.configure(layout, player, camera, session))
	assert_true(
		host.mount_location(
			&"map_a", _package(&"shared.player_anchor"), _package(&"map_a.landmark")
		)
	)
	assert_true(
		host.mount_location(&"map_b", _package(&"map_b.landmark"), _package(&"map_b.view_marker"))
	)

	var player_identity := host.player_owner
	var camera_identity := host.camera_owner
	var session_identity := host.session_owner
	var before_crossing := Vector2(3.5 * 32.0, 2.0 * 32.0)
	var after_crossing := Vector2(4.5 * 32.0, 2.0 * 32.0)
	assert_eq(host.observe_global_logic_position(before_crossing), &"map_a")
	assert_eq(host.observed_global_logic_position(), before_crossing)
	assert_eq(host.observe_global_logic_position(after_crossing), &"map_b")
	assert_eq(host.observed_global_logic_position(), after_crossing)
	assert_eq(host.player_owner, player_identity)
	assert_eq(host.camera_owner, camera_identity)
	assert_eq(host.session_owner, session_identity)
	assert_eq(host.mounted_location_ids(), [&"map_a", &"map_b"])
	assert_true(host.is_seam_active_between(&"map_a", &"map_b"))
	assert_eq(host.duplicate_stable_handles(), [])

	var map_b_logic := host.mounted_location_root(&"map_b", false) as Node2D
	var map_b_view := host.mounted_location_root(&"map_b", true) as Node3D
	assert_eq(map_b_logic.position, Vector2(4 * 32, 0))
	assert_eq(map_b_view.position, Vector3(4, 0, 0))
	assert_eq(host.stable_handle_count(), 4)
	host.free()
	player.free()
	camera.free()
	session.free()


func test_seam_requires_reciprocal_residency_and_unmount_keeps_handle_index_unique() -> void:
	var layout := MapWorldLayout.build([_map_a(), _map_b()], &"map_a", &"test_outdoor")
	var host := WorldHost.new()
	var player := Node2D.new()
	var camera := Camera3D.new()
	var session := Node.new()
	host.additive_residency_enabled = true
	assert_true(host.configure(layout, player, camera, session))
	assert_true(host.mount_location(&"map_a"))
	assert_false(host.is_seam_active_between(&"map_a", &"map_b"))
	assert_true(host.mount_location(&"map_b"))
	assert_true(host.is_seam_active_between(&"map_a", &"map_b"))
	assert_true(host.unmount_location(&"map_b"))
	assert_false(host.is_seam_active_between(&"map_a", &"map_b"))
	assert_eq(host.stable_handle_count(), 0)
	host.free()
	player.free()
	camera.free()
	session.free()


func test_duplicate_stable_handle_is_rejected_before_second_location_mount() -> void:
	var layout := MapWorldLayout.build([_map_a(), _map_b()], &"map_a", &"test_outdoor")
	var host := WorldHost.new()
	var player := Node2D.new()
	var camera := Camera3D.new()
	var session := Node.new()
	host.additive_residency_enabled = true
	assert_true(host.configure(layout, player, camera, session))
	assert_true(host.mount_location(&"map_a", _package(&"shared.object")))
	var duplicate := _package(&"shared.object")
	assert_false(host.mount_location(&"map_b", duplicate))
	assert_eq(host.mounted_location_ids(), [&"map_a"])
	assert_eq(
		host.duplicate_stable_handles(), [{"location_id": "map_b", "object_id": "shared.object"}]
	)
	duplicate.free()
	host.free()
	player.free()
	camera.free()
	session.free()


func _package(object_id: StringName) -> Node:
	var package := Node.new()
	package.name = String(object_id).replace(".", "_")
	package.set_meta(&"stable_id", object_id)
	return package


func _map_a() -> MapDefinition:
	var definition := _base_map(&"map_a")
	definition.transitions = [
		{
			"id": &"to_map_b",
			"rect": Rect2(96, 32, 32, 64),
			"spawn_id": &"from_map_b",
			"destination_spawn_id": &"from_map_a",
		}
	]
	return definition


func _map_b() -> MapDefinition:
	var definition := _base_map(&"map_b")
	definition.transitions = [
		{
			"id": &"to_map_a",
			"rect": Rect2(0, 32, 32, 64),
			"spawn_id": &"from_map_a",
			"destination_spawn_id": &"from_map_b",
		}
	]
	return definition


func _base_map(map_id: StringName) -> MapDefinition:
	var definition := MapDefinition.new()
	definition.map_id = map_id
	definition.location = StringName("loc.%s" % map_id)
	definition.cell_size = MapTypes.DEFAULT_CELL_SIZE
	definition.size_cells = Vector2i(4, 4)
	definition.base_terrain = MapTypes.TERRAIN_GRASS
	definition.player_spawn = Vector2(32, 32)
	definition.scope = &"production"
	definition.active = true
	definition.palette = &"clean_painted"
	definition.fingerprint = "%s-fingerprint" % map_id
	return definition
