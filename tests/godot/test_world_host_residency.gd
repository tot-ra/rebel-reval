extends "res://tests/godot/test_case.gd"

## WB-06 / R-978: WorldHost phase 3 owns exactly one set of globals across any
## number of mounted locations, rejects packages that create a global or repeat a
## stable handle, and attaches every location navigation region to one map.
## WB-06c / R-1039: real baked location regions are inset by agent_radius, so
## the host must bridge each active seam with a deterministic NavigationLink2D.

const CELL := 32


func test_flag_defaults_off_in_project_settings() -> void:
	assert_false(
		bool(ProjectSettings.get_setting(WorldHost.ADDITIVE_RESIDENCY_SETTING, false)),
		"phase 3 ships behind a default-off flag"
	)
	var host := WorldHost.new()
	assert_false(host.additive_residency_enabled)
	assert_false(host.owns_globals())
	assert_eq(host.view_globals(), {})
	host.free()


func test_two_mounted_locations_share_one_global_set() -> void:
	var host := _hosted()
	assert_true(host.owns_globals())
	assert_true(host.enter_location(&"map_a", _map_a()))
	assert_true(host.enter_location(&"map_b", _map_b()))
	assert_eq(host.mounted_location_ids(), [&"map_a", &"map_b"])
	assert_eq(host.global_census(), _one_of_each())

	var camera := host.camera_owner
	var player := host.player_owner
	for location_id in [&"map_a", &"map_b"]:
		var view := _hosted_view(host, location_id)
		assert_true(view != null and view.is_hosted(), "%s mounts a hosted view" % location_id)
		assert_eq(view.view_camera(), camera, "%s draws through the host camera" % location_id)
		assert_eq(view.environment_node(), host.world_environment)
		assert_eq(view.environment_weather(), host.sky_weather)
		assert_eq(
			host.validate_location_package(location_id, host.mounted_location_root(location_id)),
			[] as Array[Dictionary]
		)

	# Unmounting a location leaves every global alive and unique.
	assert_true(host.unmount_location(&"map_b"))
	assert_eq(host.mounted_location_ids(), [&"map_a"])
	assert_eq(host.global_census(), _one_of_each())
	assert_true(is_instance_valid(camera) and camera.is_inside_tree())
	assert_true(is_instance_valid(player) and player.is_inside_tree())
	assert_eq(host.world_environment.environment, host.environment)
	_dispose(host)


func test_package_that_creates_a_global_is_rejected_with_named_diagnostic() -> void:
	var host := _hosted()
	var rejected: Array = []
	host.package_rejected.connect(
		func(location_id: StringName, diagnostics: Array) -> void:
			rejected.append([location_id, diagnostics])
	)
	var view_package := Node3D.new()
	view_package.name = "RoguePackage"
	var rogue_camera := Camera3D.new()
	rogue_camera.name = "RogueCamera"
	view_package.add_child(rogue_camera)

	assert_false(host.mount_location(&"map_a", null, view_package))
	var diagnostics := host.last_rejection()
	assert_eq(diagnostics.size(), 1)
	assert_eq(diagnostics[0]["code"], WorldHost.DIAG_PACKAGE_CREATES_GLOBAL)
	assert_eq(diagnostics[0]["detail"], "camera")
	assert_eq(diagnostics[0]["node_path"], "RogueCamera")
	assert_eq(rejected.size(), 1)
	assert_eq(host.mounted_location_ids(), [] as Array[StringName])
	view_package.free()

	# A self-contained (non-hosted) view creates its own sun, environment, camera
	# and sky, so it is exactly the package phase 3 must refuse.
	var definition := _map_a()
	var standalone := MapView3D.create(definition, MapBuilder.build(definition))
	assert_false(host.mount_location(&"map_a", null, standalone))
	var kinds: Array[String] = []
	for diagnostic in host.last_rejection():
		assert_eq(diagnostic["code"], WorldHost.DIAG_PACKAGE_CREATES_GLOBAL)
		kinds.append(String(diagnostic["detail"]))
	kinds.sort()
	assert_eq(kinds, ["camera", "sky_weather", "sun", "world_environment"] as Array[String])
	assert_eq(host.global_census(), _one_of_each())
	standalone.free()
	_dispose(host)


func test_duplicate_stable_handles_are_rejected() -> void:
	var host := _hosted()
	var definition := _map_a()
	assert_true(host.enter_location(&"map_a", definition))
	assert_true(host.stable_handle_count() > 0, "doors and anchors carry stable handles")
	# The same authored package mounted a second time repeats every
	# {location_id, object_id} handle and must not mount.
	var repeat := MapSceneBootstrap.assemble_location_package(definition)
	assert_false(host.mount_location(&"map_b", repeat))
	var diagnostics := host.last_rejection()
	assert_eq(diagnostics.size(), 1)
	assert_eq(diagnostics[0]["code"], WorldHost.DIAG_DUPLICATE_STABLE_HANDLE)
	assert_eq(diagnostics[0]["detail"], "map_a/transition:to_map_b")
	assert_eq(host.mounted_location_ids(), [&"map_a"])
	repeat.free()
	_dispose(host)


func test_location_regions_share_one_navigation_map_and_path_crosses_seam() -> void:
	var host := _hosted()
	assert_true(host.mount_location(&"map_a", _flat_region_package(&"map_a")))
	assert_true(host.mount_location(&"map_b", _flat_region_package(&"map_b")))
	var map_rid := host.navigation_map()
	for location_id in [&"map_a", &"map_b"]:
		var region := _region_of(host, location_id)
		assert_eq(region.get_navigation_map(), map_rid, "%s region on host map" % location_id)
	await _sync_navigation()
	assert_eq(NavigationServer2D.map_get_regions(map_rid).size(), 2)

	# map_b sits four cells east of map_a in the layout, so this route starts in
	# map_a and ends in map_b on the one host map.
	var start := Vector2(1.5 * CELL, 2.0 * CELL)
	var goal := Vector2(6.5 * CELL, 2.0 * CELL)
	assert_eq(host.observe_global_logic_position(start), &"map_a")
	assert_eq(host.observe_global_logic_position(goal), &"map_b")
	var path := NavigationServer2D.map_get_path(map_rid, start, goal, true)
	assert_true(path.size() >= 2, "a path exists across the seam")
	assert_true(path[path.size() - 1].distance_to(goal) < 0.5, "path reaches map_b")

	assert_true(host.unmount_location(&"map_b"))
	await _sync_navigation()
	assert_eq(NavigationServer2D.map_get_regions(map_rid).size(), 1)
	_dispose(host)


func test_built_location_package_navigation_joins_host_map() -> void:
	var host := _hosted()
	assert_true(host.enter_location(&"map_a", _map_a()))
	var region := _region_of(host, &"map_a")
	assert_true(region != null, "logic package carries its navigation region")
	assert_eq(region.get_navigation_map(), host.navigation_map())
	await _sync_navigation()
	assert_eq(NavigationServer2D.map_get_regions(host.navigation_map()).size(), 1)
	_dispose(host)


func test_host_clock_drives_every_mounted_view() -> void:
	var host := _hosted()
	assert_true(host.enter_location(&"map_a", _map_a()))
	assert_true(host.enter_location(&"map_b", _map_b()))
	host.set_clock_progress(0.95)
	host.advance_clock(DayNightCycle.CYCLE_DURATION_SECONDS * 0.1)
	assert_eq(host.clock_completed_days, 1)
	assert_true(absf(host.clock_progress - 0.05) < 0.0001)
	for location_id in [&"map_a", &"map_b"]:
		assert_true(absf(_hosted_view(host, location_id).cycle_progress - host.clock_progress) < 0.0001)
	_dispose(host)


func test_save_identity_is_host_owned_and_unchanged() -> void:
	var host := _hosted()
	assert_true(host.enter_location(&"map_a", _map_a()))
	var door := host.stable_handle_owner(
		{"location_id": "map_a", "object_id": "transition:to_map_b"}
	)
	assert_true(door is Area2D, "stable handle resolves to the mounted door")
	var store := host.stable_state_store
	assert_true(store != null)
	var handle := store.stable_handle(&"map_a", &"transition:to_map_b")
	assert_eq(handle, door.get_meta(&"stable_handle"))
	assert_true(store.record_object_delta(&"map_a", &"transition:to_map_b", {"locked": true}))
	var payload := store.save_payload()
	var reloaded := MapStableStateStore.new()
	assert_eq(reloaded.load_payload(payload), [] as Array[String])
	assert_eq(reloaded.object_delta(&"map_a", &"transition:to_map_b"), {"locked": true})
	assert_eq(reloaded.canonical_text(), store.canonical_text())
	_dispose(host)


func test_flag_off_host_keeps_globals_but_mounts_nothing() -> void:
	var host := _hosted(false)
	assert_true(host.owns_globals())
	assert_false(host.enter_location(&"map_a", _map_a()))
	assert_eq(host.last_rejection()[0]["code"], WorldHost.DIAG_RESIDENCY_INACTIVE)
	assert_eq(host.mounted_location_ids(), [] as Array[StringName])
	assert_eq(host.global_census(), _one_of_each())
	_dispose(host)


func test_seam_link_points_sit_inside_each_inset_region() -> void:
	var layout := MapWorldLayout.build([_map_a(), _map_b()], &"map_a", &"test_outdoor")
	assert_true(layout["valid"], "fixture maps share a physical east-west seam")
	assert_eq((layout["seams"] as Array).size(), 1)
	var points := MapWorldLayout.seam_navigation_link_points(
		layout, layout["seams"][0], MapNavBuilder.AGENT_RADIUS
	)
	assert_eq(points.size(), 2)
	var radius := MapNavBuilder.AGENT_RADIUS
	var start: Vector2 = points[0]
	var end: Vector2 = points[1]
	assert_true(
		start.x >= radius and start.x <= 4.0 * CELL - radius,
		"start stays inside map_a walkable: %s" % start
	)
	assert_true(
		end.x >= 4.0 * CELL + radius and end.x <= 8.0 * CELL - radius,
		"end stays inside map_b walkable: %s" % end
	)
	assert_true(absf(end.x - start.x) > radius, "link spans the 32 px inset gap")


func test_baked_packages_have_no_path_until_the_host_adds_seam_links() -> void:
	# R-1041: prove the shared seam-link path on the phase-3 host that owns
	# globals via create_globals(), not only on the phase-2 configure() host.
	var host := _hosted()
	assert_true(host.mount_location(&"map_a", MapSceneBootstrap.assemble_location_package(_map_a())))
	assert_true(host.mount_location(&"map_b", MapSceneBootstrap.assemble_location_package(_map_b())))
	var map_rid := host.navigation_map()
	for location_id in [&"map_a", &"map_b"]:
		var region := _region_of(host, location_id)
		assert_true(region != null, "%s package carries a baked region" % location_id)
		assert_eq(region.get_navigation_map(), map_rid)
	await _sync_navigation()

	var start := Vector2(2.0 * CELL, 2.0 * CELL)
	var goal := Vector2(6.0 * CELL, 2.0 * CELL)
	assert_eq(host.observe_global_logic_position(start), &"map_a")
	assert_eq(host.observe_global_logic_position(goal), &"map_b")

	var links := host.get_node(WorldHost.SEAM_LINKS_NAME).get_children()
	assert_true(links.size() >= 1, "host installs a link on the active seam")
	var path := NavigationServer2D.map_get_path(map_rid, start, goal, true)
	assert_true(path.size() >= 2, "a path exists across the baked inset gap")
	assert_true(path[path.size() - 1].distance_to(goal) < CELL, "path reaches map_b")

	for link_node in links:
		(link_node as NavigationLink2D).enabled = false
	await _sync_navigation()
	var blocked := NavigationServer2D.map_get_path(map_rid, start, goal, true)
	assert_true(
		blocked.is_empty() or blocked[blocked.size() - 1].distance_to(goal) > CELL,
		"without the link the 32 px inset gap blocks click navigation"
	)
	_dispose(host)


func test_phase2_configured_host_still_adds_seam_links() -> void:
	var host := _configured_host()
	assert_true(host.mount_location(&"map_a", MapSceneBootstrap.assemble_location_package(_map_a())))
	assert_true(host.mount_location(&"map_b", MapSceneBootstrap.assemble_location_package(_map_b())))
	var map_rid := host.navigation_map()
	await _sync_navigation()
	var start := Vector2(2.0 * CELL, 2.0 * CELL)
	var goal := Vector2(6.0 * CELL, 2.0 * CELL)
	assert_eq(host.observe_global_logic_position(start), &"map_a")
	assert_eq(host.observe_global_logic_position(goal), &"map_b")
	var links := host.get_node(WorldHost.SEAM_LINKS_NAME).get_children()
	assert_true(links.size() >= 1, "phase-2 host still installs a seam link")
	var path := NavigationServer2D.map_get_path(map_rid, start, goal, true)
	assert_true(path.size() >= 2, "phase-2 path still crosses the baked inset gap")
	assert_true(path[path.size() - 1].distance_to(goal) < CELL, "path reaches map_b")
	_dispose(host)


func test_flag_off_bake_bytes_stay_identical() -> void:
	var definition := _map_a()
	var grid := MapBuilder.build(definition)
	var first := MapNavBuilder.bake_navigation_polygon(definition, grid)
	var second := MapNavBuilder.bake_navigation_polygon(definition, grid)
	assert_eq(first.get_polygon_count(), second.get_polygon_count())
	assert_eq(first.vertices, second.vertices)
	assert_eq(first.agent_radius, MapNavBuilder.AGENT_RADIUS)


func _hosted(enabled: bool = true) -> WorldHost:
	var host := WorldHost.new()
	host.name = "WorldHostUnderTest"
	host.additive_residency_enabled = enabled
	(Engine.get_main_loop() as SceneTree).root.add_child(host)
	var layout := MapWorldLayout.build([_map_a(), _map_b()], &"map_a", &"test_outdoor")
	assert_true(host.create_globals(layout), "host creates its globals")
	return host


## Phase 2 host: configure() binds owners created elsewhere; no create_globals().
## R-1039 landed seam links here; R-1041 keeps this helper as a regression that
## the shared mount_location path still works without owns_globals().
func _configured_host() -> WorldHost:
	var host := WorldHost.new()
	host.name = "WorldHostSeamNav"
	host.additive_residency_enabled = true
	(Engine.get_main_loop() as SceneTree).root.add_child(host)
	var player := Node2D.new()
	var camera := Camera3D.new()
	var session := Node.new()
	host.add_child(player)
	host.add_child(camera)
	host.add_child(session)
	var layout := MapWorldLayout.build([_map_a(), _map_b()], &"map_a", &"test_outdoor")
	assert_true(host.configure(layout, player, camera, session))
	return host


func _dispose(host: WorldHost) -> void:
	host.unmount_all()
	if host.get_parent() != null:
		host.get_parent().remove_child(host)
	host.free()


func _one_of_each() -> Dictionary:
	return {
		"player": 1,
		"player_rig": 1,
		"camera": 1,
		"world_environment": 1,
		"sun": 1,
		"sky_weather": 1,
		"hud": 1,
	}


func _hosted_view(host: WorldHost, location_id: StringName) -> MapView3D:
	var root := host.mounted_location_root(location_id, true)
	for child in root.get_children():
		if child is MapView3D:
			return child as MapView3D
	return null


func _region_of(host: WorldHost, location_id: StringName) -> NavigationRegion2D:
	var root := host.mounted_location_root(location_id, false)
	if root == null:
		return null
	var found := root.find_children("*", "NavigationRegion2D", true, false)
	return found.front() as NavigationRegion2D if not found.is_empty() else null


## A package whose region covers the full 4x4-cell map with no agent-radius
## inset, so the two regions share the seam edge exactly.
func _flat_region_package(location_id: StringName) -> Node2D:
	var package := Node2D.new()
	package.name = "FlatPackage_%s" % location_id
	var region := NavigationRegion2D.new()
	region.name = "Navigation"
	var polygon := NavigationPolygon.new()
	var size := float(4 * CELL)
	polygon.vertices = PackedVector2Array(
		[Vector2.ZERO, Vector2(size, 0.0), Vector2(size, size), Vector2(0.0, size)]
	)
	polygon.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	region.navigation_polygon = polygon
	package.add_child(region)
	return package


## Godot 4.7 iterates navigation maps asynchronously: the first iteration after
## a mount can still be empty (closest point (0, 0)), and region polygons land a
## few physics frames later. Four frames were enough only while the harness never
## awaited these tests (R-1053); 30 frames covers the observed second iteration.
func _sync_navigation() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	for _frame in 30:
		await tree.physics_frame


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
