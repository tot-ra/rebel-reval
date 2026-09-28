extends "res://tests/godot/test_case.gd"

## WB-08 / R-980: the checked-in reval_outdoor world-layout manifest, the
## WorldHost streaming policy (prefetch, eviction hysteresis, residency cap), seam
## handover without re-creating globals, the travel boundary, and the scene-swap
## fallback for a failed or blocked mount. WB-08c / R-1044: staged in-flight
## mounts, cancel-on-evict, delayed-I/O readiness misses, retry backoff and
## save/load across a seam and mid-mount.

const CELL := MapTypes.DEFAULT_CELL_SIZE
## Synthetic strip A | B | C, each STRIP_W x STRIP_H cells.
const STRIP_W := 100
const STRIP_H := 40

static var _compiled: Dictionary = {}


func test_manifest_is_deterministic_over_ten_builds_and_checked_in() -> void:
	var compiled := _real_members()
	assert_eq(compiled["errors"], [] as Array[String])
	var texts: Dictionary = {}
	for _build in 10:
		var manifest := MapWorldLayout.build_manifest(
			compiled["definitions"],
			MapWorldLayout.REVAL_OUTDOOR_MEMBERS,
			&"lower_town_slice",
			MapWorldLayout.DEFAULT_WORLD_GROUP_ID,
			compiled["sources"]
		)
		assert_true(manifest["valid"], str(manifest["errors"]))
		texts[MapWorldLayout.manifest_file_text(manifest)] = true
	assert_eq(texts.size(), 1, "ten builds produce one manifest text")
	var checked_in := FileAccess.get_file_as_string(MapWorldLayout.REVAL_OUTDOOR_MANIFEST_PATH)
	assert_true(
		texts.has(checked_in),
		"content/world/reval_outdoor_layout.json is stale; run tools/build_world_layout.gd"
	)


func test_manifest_placement_tree_is_rooted_and_cycle_free() -> void:
	var manifest := MapWorldLayout.load_manifest()
	assert_eq(manifest["locations"].size(), MapWorldLayout.REVAL_OUTDOOR_MEMBERS.size())
	var parents: Dictionary = {}
	for entry in manifest["locations"]:
		parents[entry["location_id"]] = entry["placement_parent"]
	assert_eq(parents[manifest["root_location_id"]], "", "root has no parent")
	for location_id in parents.keys():
		var cursor: String = location_id
		var seen: Dictionary = {}
		while not String(parents[cursor]).is_empty():
			assert_false(seen.has(cursor), "placement cycle through %s" % cursor)
			if seen.has(cursor):
				break
			seen[cursor] = true
			cursor = parents[cursor]
		assert_eq(cursor, manifest["root_location_id"], "%s reaches the root" % location_id)


func test_manifest_keeps_travel_and_interiors_out_of_seams() -> void:
	var manifest := MapWorldLayout.load_manifest()
	var members: Dictionary = {}
	for member in MapWorldLayout.REVAL_OUTDOOR_MEMBERS:
		members[String(member["location_id"])] = true
	var seam_transitions: Dictionary = {}
	for seam in manifest["seams"]:
		assert_true(members.has(seam["base_map_id"]) and members.has(seam["neighbor_map_id"]))
		assert_eq(seam["alignment"], "physical")
		seam_transitions["%s/%s" % [seam["base_map_id"], seam["base_transition_id"]]] = true
		seam_transitions["%s/%s" % [seam["neighbor_map_id"], seam["neighbor_transition_id"]]] = true
	for explicit in manifest["explicit_transitions"]:
		var key := "%s/%s" % [explicit["location_id"], explicit["transition_id"]]
		assert_false(seam_transitions.has(key), "%s is both explicit and a seam" % key)
		if explicit["alignment"] == "travel":
			assert_eq(explicit["reason"], MapWorldLayout.EXPLICIT_REASON_TRAVEL)
		if String(explicit["destination_scene_id"]).begins_with("world_"):
			assert_eq(explicit["destination_location_id"], "", "%s leaves the group" % key)
	# The forge door and the outer-wall road stay explicit.
	var layout := MapWorldLayout.layout_from_manifest(manifest)
	assert_true(layout["valid"], str(layout["errors"]))
	var host := _configured_host(layout)
	assert_false(host.is_transition_streamed(&"lower_town_slice", &"smithy_door_transition"))
	assert_false(host.is_transition_streamed(&"lower_town_slice", &"workers_outer_wall_road"))
	assert_true(host.is_transition_streamed(&"lower_town_slice", &"vana_turg_boundary"))
	_dispose(host)


func test_travel_map_authored_as_physical_seam_is_rejected() -> void:
	# "w" is the world map's own suffix in _strip_map, so the apertures pair.
	var travel := _strip_map(&"world.harju", 1, [&"a"], [])
	var members := [{"location_id": &"map_a", "scene_id": &"scene_a"}]
	var manifest := MapWorldLayout.build_manifest(
		[_strip_map(&"map_a", 0, [], [&"w"]), travel], members, &"map_a", &"test_outdoor"
	)
	assert_false(manifest["valid"])
	var errors := "\n".join(manifest["errors"])
	assert_true(MapWorldLayout.DIAG_SEAM_OUTSIDE_GROUP in errors, errors)
	assert_true(MapWorldLayout.DIAG_NOT_A_MEMBER in errors, errors)
	assert_false(MapWorldLayout.layout_from_manifest(manifest)["valid"])


func test_span_mismatch_blocks_one_seam_but_keeps_placement() -> void:
	var map_c := _strip_map(&"map_c", 2, [&"b"], [])
	map_c.transitions[0]["rect"] = Rect2(0, 12 * CELL, CELL, 6 * CELL)
	var manifest := _strip_manifest([_strip_a(), _strip_b(), map_c])
	assert_true(manifest["valid"], str(manifest["errors"]))
	var statuses: Dictionary = {}
	for seam in manifest["seams"]:
		statuses[seam["neighbor_map_id"] + seam["base_map_id"]] = seam["status"]
	assert_eq(statuses.values().count(MapWorldLayout.SEAM_STATUS_BLOCKED), 1)
	var layout := MapWorldLayout.layout_from_manifest(manifest)
	assert_eq(layout["seams"].size(), 1)
	assert_eq(layout["blocked_seams"].size(), 1)
	assert_eq(
		layout["blocked_seams"][0]["diagnostics"], [MapWorldLayout.DIAG_SEAM_SPAN_MISMATCH]
	)


func test_tampered_manifest_is_refused() -> void:
	var manifest := _strip_manifest([_strip_a(), _strip_b(), _strip_c()])
	assert_true(MapWorldLayout.layout_from_manifest(manifest)["valid"])
	manifest["locations"][1]["origin_cell"] = [101, 0]
	var layout := MapWorldLayout.layout_from_manifest(manifest)
	assert_false(layout["valid"])
	assert_true("fingerprint" in "\n".join(layout["errors"]))


func test_prefetch_mounts_exactly_the_expected_neighbours() -> void:
	var host := _strip_host()
	host.update_streaming(_at(50))
	assert_eq(host.owning_location_id(), &"map_a")
	assert_eq(host.mounted_location_ids(), [&"map_a"], "50 cells from the seam is outside 48")
	host.update_streaming(_at(60))
	assert_eq(host.mounted_location_ids(), [&"map_a", &"map_b"], "40 cells: prefetch B only")
	host.update_streaming(_at(99))
	assert_eq(host.mounted_location_ids(), [&"map_a", &"map_b"], "C is not a neighbour of A")
	_dispose(host)


func test_eviction_respects_hysteresis() -> void:
	var host := _strip_host()
	host.update_streaming(_at(60))
	assert_array_contains(host.mounted_location_ids(), &"map_b")
	var mounts: Array[StringName] = []
	host.location_mounted.connect(func(location_id: StringName) -> void: mounts.append(location_id))
	# Pacing across the prefetch line (48 cells) must not thrash B.
	for x in [53.0, 51.0, 45.0, 51.0, 40.0, 54.0]:
		host.update_streaming(_at(x))
		assert_array_contains(host.mounted_location_ids(), &"map_b", "B stays at x=%s" % x)
	assert_eq(mounts, [] as Array[StringName])
	host.update_streaming(_at(35))
	assert_eq(host.mounted_location_ids(), [&"map_a"], "65 cells is past the 64-cell band")
	_dispose(host)


func test_crossing_a_seam_keeps_player_camera_clock_and_store() -> void:
	var host := WorldHost.new()
	host.additive_residency_enabled = true
	(Engine.get_main_loop() as SceneTree).root.add_child(host)
	assert_true(host.create_globals(_strip_layout()))
	host.location_loader = func(location_id: StringName) -> bool:
		return host.mount_location(location_id)
	var player := host.player_owner as Node2D
	var camera := host.camera_owner
	var camera_transform := camera.global_transform
	var camera_size := camera.size
	var store := host.stable_state_store
	host.set_clock_progress(0.37)
	var changes: Array = []
	host.owning_location_changed.connect(
		func(previous: StringName, current: StringName) -> void: changes.append([previous, current])
	)
	var previous_position := _at(60)
	var velocity := Vector2(0.5 * CELL, 0.0)
	# Walk A -> B -> C in half-cell steps like a player; the host must never
	# write the player, so position and velocity stay exactly what we drive.
	for step in 360:
		var position := previous_position + velocity
		player.global_position = position
		host.update_streaming(player.global_position)
		assert_eq(host.player_owner, player)
		assert_true(player.global_position.distance_to(position) <= 0.01)
		assert_true((player.global_position - previous_position).distance_to(velocity) <= 0.01)
		previous_position = position
		assert_true(host.mounted_location_ids().size() <= host.residency_cap)
		assert_true(host.mounted_location_ids().has(host.owning_location_id()))
	assert_eq(changes, [[&"map_a", &"map_b"], [&"map_b", &"map_c"]])
	assert_eq(host.owning_location_id(), &"map_c")
	assert_true(is_instance_valid(player) and player.is_inside_tree())
	assert_eq(host.camera_owner, camera)
	assert_true(camera.global_transform.is_equal_approx(camera_transform))
	assert_eq(camera.size, camera_size)
	assert_true(is_equal_approx(host.clock_progress, 0.37))
	assert_eq(host.stable_state_store, store)
	assert_eq(host.global_census()["player"], 1)
	assert_eq(host.global_census()["camera"], 1)
	_dispose(host)


func test_residency_cap_holds_on_a_full_reval_circuit() -> void:
	var layout := MapWorldLayout.layout_from_manifest(MapWorldLayout.load_manifest())
	assert_true(layout["valid"], str(layout["errors"]))
	var host := _configured_host(layout)
	host.location_loader = func(location_id: StringName) -> bool:
		return host.mount_location(location_id)
	var route: Array[StringName] = [
		&"lower_town_slice", &"market_civic_quarter", &"south_quarter", &"archbishops_garden",
		&"toompea_quarter", &"monastery_quarter", &"north_quarter", &"reval_harbor_north",
		&"reval_harbor_east", &"reval_harbor_north", &"north_quarter", &"monastery_quarter",
		&"toompea_quarter", &"market_civic_quarter", &"lower_town_slice",
		&"viru_gate_foreland", &"lower_town_slice",
	]
	var visited: Array[StringName] = []
	var peak := 0
	for index in route.size() - 1:
		var from_id := route[index]
		var to_id := route[index + 1]
		assert_false(host.seam_between(from_id, to_id).is_empty(), "%s-%s streams" % [from_id, to_id])
		var waypoints := [
			_center(layout, from_id), _seam_midpoint(layout, from_id, to_id), _center(layout, to_id)
		]
		for leg in 2:
			var start: Vector2 = waypoints[leg]
			var end: Vector2 = waypoints[leg + 1]
			var steps := maxi(1, ceili(start.distance_to(end) / float(4 * CELL)))
			for step in steps + 1:
				var result := host.update_streaming(start.lerp(end, float(step) / float(steps)))
				assert_eq(result["fallback"], {}, "no fallback on a streamable route")
				var resident := host.mounted_location_ids()
				peak = maxi(peak, resident.size())
				assert_true(resident.size() <= host.residency_cap, "cap holds: %s" % [resident])
				assert_true(resident.has(host.owning_location_id()))
				if not visited.has(host.owning_location_id()):
					visited.append(host.owning_location_id())
	assert_eq(visited.size(), MapWorldLayout.REVAL_OUTDOOR_MEMBERS.size(), "circuit covers all ten")
	assert_true(peak >= 2, "prefetch actually overlapped neighbours")
	# Leaving the last seam behind evicts the neighbour again.
	host.update_streaming(_center(layout, &"viru_gate_foreland"))
	_dispose(host)


func test_travel_and_non_members_never_stream() -> void:
	var layout := MapWorldLayout.layout_from_manifest(MapWorldLayout.load_manifest())
	var members: Array = []
	for member in MapWorldLayout.REVAL_OUTDOOR_MEMBERS:
		members.append(member["location_id"])
	for entry in layout["locations"]:
		var location_id: StringName = entry["location_id"]
		var bounds: Rect2 = entry["global_bounds"]
		for sample in [bounds.position, bounds.end - Vector2.ONE, bounds.get_center()]:
			var plan := WorldHostResidencyPolicy.plan(
				layout, location_id, sample, [location_id], 1e9, 1e9, 99
			)
			for planned in plan["desired"]:
				assert_true(members.has(planned), "%s is a member" % planned)
	var host := _configured_host(layout)
	for explicit in layout["explicit_transitions"]:
		assert_false(
			host.is_transition_streamed(
				StringName(explicit["location_id"]), StringName(explicit["transition_id"])
			)
		)
	_dispose(host)


func test_forced_mount_failure_falls_back_to_scene_swap() -> void:
	var host := _strip_host()
	host.scene_swap_fallback_enabled = true
	host.location_loader = func(location_id: StringName) -> bool:
		return location_id != &"map_b" and host.mount_location(location_id)
	var requests: Array = []
	host.scene_swap_fallback_requested.connect(
		func(location_id: StringName, request: Dictionary) -> void:
			requests.append([location_id, request])
	)
	host.update_streaming(_at(60))
	assert_eq(host.mounted_location_ids(), [&"map_a"], "prefetch failure leaves A resident")
	assert_eq(host.mount_failure_count(&"map_b"), 1)
	assert_true(requests.is_empty(), "no swap until the player reaches the seam")
	host.update_streaming(_at(100.5))
	host.update_streaming(_at(101.0))
	assert_eq(requests.size(), 1, "one request per edge visit")
	assert_eq(requests[0][0], &"map_b")
	assert_eq(requests[0][1]["transition_id"], &"to_map_b")
	assert_eq(requests[0][1]["from_location_id"], &"map_a")
	assert_eq(host.owning_location_id(), &"map_a", "the player is never owned by unloaded space")
	assert_array_contains(host.mounted_location_ids(), &"map_a")

	# With the degrade path off the owner still stays put and nothing is emitted.
	var strict := _strip_host()
	strict.scene_swap_fallback_enabled = false
	strict.location_loader = func(_location_id: StringName) -> bool: return false
	strict.set_owning_location(&"map_a")
	assert_true(strict.mount_location(&"map_a"))
	var strict_result := strict.update_streaming(_at(101.0))
	assert_eq(strict_result["fallback"], {})
	assert_eq(strict.owning_location_id(), &"map_a")
	_dispose(strict)
	_dispose(host)


func test_blocked_seam_crossing_uses_its_explicit_transition() -> void:
	var map_c := _strip_map(&"map_c", 2, [&"b"], [])
	map_c.transitions[0]["rect"] = Rect2(0, 12 * CELL, CELL, 6 * CELL)
	var layout := MapWorldLayout.layout_from_manifest(
		_strip_manifest([_strip_a(), _strip_b(), map_c])
	)
	var host := _configured_host(layout)
	host.scene_swap_fallback_enabled = true
	host.location_loader = func(location_id: StringName) -> bool:
		return host.mount_location(location_id)
	host.update_streaming(_at(150))
	assert_eq(host.owning_location_id(), &"map_b")
	assert_false(host.mounted_location_ids().has(&"map_c"), "blocked seams never prefetch")
	var result := host.update_streaming(_at(201))
	assert_eq(result["fallback"]["transition_id"], &"to_map_c")
	assert_eq(host.owning_location_id(), &"map_b")
	_dispose(host)


func test_repeated_navigation_bake_and_free_leaves_no_objects() -> void:
	var definition := _strip_a()
	var grid: MapTerrainGrid = MapBuilder.build(definition)
	for _warmup in 2:
		MapNavBuilder.release_navigation_region(
			MapNavBuilder.create_navigation_region(definition, grid)
		)
	MapNavBuilder.flush_deferred_bakes()
	var before := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	for _bake in 5:
		MapNavBuilder.release_navigation_region(
			MapNavBuilder.create_navigation_region(definition, grid)
		)
	MapNavBuilder.flush_deferred_bakes()
	var after := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	assert_eq(
		after,
		before,
		"bake+free must release the region RID and NavigationPolygon (delta %+d)"
		% (after - before)
	)


func test_flag_off_streaming_is_inert() -> void:
	var host := _strip_host()
	host.set_additive_residency_enabled(false)
	var result := host.update_streaming(_at(60))
	assert_eq(result["mounted"], [] as Array[StringName])
	assert_eq(host.mounted_location_ids(), [] as Array[StringName])
	assert_eq(
		float(ProjectSettings.get_setting(WorldHost.STREAMING_PREFETCH_BAND_SETTING, 0.0)),
		WorldHost.DEFAULT_PREFETCH_BAND_CELLS
	)
	assert_eq(
		float(ProjectSettings.get_setting(WorldHost.STREAMING_EVICTION_BAND_SETTING, 0.0)),
		WorldHost.DEFAULT_EVICTION_BAND_CELLS
	)
	assert_eq(
		int(ProjectSettings.get_setting(WorldHost.STREAMING_RESIDENCY_CAP_SETTING, 0)),
		WorldHost.DEFAULT_RESIDENCY_CAP
	)
	assert_false(bool(ProjectSettings.get_setting(WorldHost.ADDITIVE_RESIDENCY_SETTING, false)))
	_dispose(host)


# --- WB-08c (R-1044): staged in-flight mounts and seam saves ------------------
# The harness never awaits coroutines, so every staged test pumps
# update_streaming() synchronously and sleeps briefly for the worker.


func test_staged_prefetch_mounts_only_a_finished_package() -> void:
	var host := _staged_host()
	var mounts: Array[StringName] = []
	host.location_mounted.connect(func(location_id: StringName) -> void: mounts.append(location_id))
	var result := host.update_streaming(_at(60))
	assert_eq(result["mounted"], [] as Array[StringName], "no synchronous neighbour mount")
	assert_eq(host.pending_location_ids(), [&"map_b"])
	assert_eq(host.mounted_location_ids(), [&"map_a"], "an in-flight mount is not resident")
	var exposed := [false]
	_pump(host, _at(60), func() -> bool:
		if host.pending_location_ids().has(&"map_b") and host.is_seam_active_between(&"map_a", &"map_b"):
			exposed[0] = true
		return host.mounted_location_ids().has(&"map_b"))
	assert_false(exposed[0], "the seam never activates toward an in-flight mount")
	assert_eq(mounts, [&"map_b"] as Array[StringName])
	assert_eq(host.pending_location_ids(), [] as Array[StringName])
	var view := host.hosted_view(&"map_b")
	assert_true(view != null and view.is_hosted(), "the staged view binds the host globals")
	assert_true(view.is_assembly_complete(), "a prefetch mounts a complete view")
	assert_true(host.hosted_bootstrap(&"map_b").get("definition") is MapDefinition)
	assert_true(host.is_seam_active_between(&"map_a", &"map_b"))
	var census := host.global_census()
	assert_eq([census["player"], census["camera"], census["sun"], census["sky_weather"]], [1, 1, 1, 1])
	_dispose(host)


func test_evicting_an_in_flight_mount_cancels_and_leaks_nothing() -> void:
	var host := _staged_host()
	# One cycle of each kind first warms shared caches (materials, height fields),
	# so the counted cycles below see only their own nodes and objects.
	_run_cancel_cycle(host, WorldHostMountQueue.Phase.ASSEMBLING)
	host.mount_queue.prepare_delay_msec = 150
	_run_cancel_cycle(host, WorldHostMountQueue.Phase.PREPARING)
	_run_cancel_cycle(host, WorldHostMountQueue.Phase.ENTERING)
	MapNavBuilder.flush_deferred_bakes()
	var orphans_before := _orphan_ids()
	var objects_before := Performance.get_monitor(Performance.OBJECT_COUNT)
	var mounts: Array[StringName] = []
	host.location_mounted.connect(func(location_id: StringName) -> void: mounts.append(location_id))
	_run_cancel_cycle(host, WorldHostMountQueue.Phase.ASSEMBLING)
	host.mount_queue.prepare_delay_msec = 150
	_run_cancel_cycle(host, WorldHostMountQueue.Phase.PREPARING)
	_run_cancel_cycle(host, WorldHostMountQueue.Phase.ENTERING)
	assert_eq(mounts, [] as Array[StringName], "a cancelled mount never mounts")
	assert_eq(_unreleased_orphans(orphans_before), [] as Array[String], "no node leaks")
	# Freed navigation regions release their server RID and polygon on the next
	# NavigationServer2D flush (R-1073); play flushes on the physics tick.
	MapNavBuilder.flush_deferred_bakes()
	assert_eq(
		Performance.get_monitor(Performance.OBJECT_COUNT) - objects_before,
		0.0,
		"no object or RID owner leaks"
	)
	_dispose(host)


# --- WB-08e (R-1069): sliced tree entry and exit ------------------------------


func test_geometry_strip_is_only_required_for_multimesh_teardown() -> void:
	var leaf := MeshInstance3D.new()
	leaf.mesh = BoxMesh.new()
	assert_false(
		WorldHostPackageInspector.needs_geometry_strip(leaf),
		"a leaf mesh can free without the dummy-renderer mesh-null hitch"
	)
	var batch := MultiMeshInstance3D.new()
	assert_true(
		WorldHostPackageInspector.needs_geometry_strip(batch),
		"MultiMesh still strips before free"
	)
	var holder := Node3D.new()
	holder.add_child(batch)
	assert_true(
		WorldHostPackageInspector.needs_geometry_strip(holder),
		"an atomic parent that still owns a MultiMesh must strip"
	)
	holder.remove_child(batch)
	batch.free()
	leaf.free()
	holder.free()


func test_split_for_entry_rebuilds_the_same_tree_and_keeps_scripted_nodes_whole() -> void:
	var root := _wide_tree()
	var before := _tree_signature(root)
	var scripted := root.get_node("Busy/Flock")
	var units := WorldHostPackageInspector.split_for_entry(root, 4)
	assert_true(units.size() > 4, "a wide tree splits into many slices (%d)" % units.size())
	assert_eq(units[0], [null, root], "the view itself is the first slice")
	assert_eq(scripted.get_child_count(), 6, "a scripted subtree enters whole")
	for unit in units:
		assert_true(unit[0] != scripted, "no slice starts inside a scripted node")
	var staging := Node3D.new()
	for unit in units:
		(unit[0] if unit[0] != null else staging).add_child(unit[1])
	assert_eq(_tree_signature(root), before, "re-adding the slices in order rebuilds the tree")
	staging.free()


func test_sliced_entry_stays_hidden_and_mounts_the_synchronous_tree() -> void:
	var host := _staged_host()
	host.mount_queue.frame_budget_usec = 0  # one slice (or view unit) per tick
	host.update_streaming(_at(60))
	_pump(host, _at(60), func() -> bool:
		return host.mount_queue.phase_of(&"map_b") == WorldHostMountQueue.Phase.ENTERING)
	var entering_ticks := 0
	var exposed := false
	var staging: Node3D = null
	while not host.mounted_location_ids().has(&"map_b") and entering_ticks < 5000:
		var view := host.mount_queue.pending_view(&"map_b")
		if view != null and view.is_inside_tree():
			staging = view.get_parent() as Node3D
			exposed = exposed or staging.is_visible_in_tree()
			exposed = exposed or host.is_seam_active_between(&"map_a", &"map_b")
		host.update_streaming(_at(60))
		entering_ticks += 1
	assert_true(host.mounted_location_ids().has(&"map_b"), "sliced entry finishes")
	assert_true(entering_ticks > 1, "the view entered over several ticks (%d)" % entering_ticks)
	assert_false(exposed, "an entering view is hidden and its seam stays sealed")
	var mounted_view := host.hosted_view(&"map_b")
	assert_eq(host.mounted_location_root(&"map_b"), staging, "the staging root becomes the view root")
	assert_true(mounted_view.is_visible_in_tree(), "the mount reveals the view")
	var definition := _strip_b()
	var synchronous := MapView3D.create_hosted(
		definition, MapBuilder.build(definition), host.view_globals()
	)
	assert_eq(_tree_signature(mounted_view), _tree_signature(synchronous), "staged equals synchronous")
	MapView3D._strip_geometry_materials(synchronous)
	synchronous.free()
	_dispose(host)


func test_eviction_detaches_gameplay_at_once_and_frees_the_view_in_slices() -> void:
	var host := _staged_host()
	host.update_streaming(_at(60))
	_pump(host, _at(60), func() -> bool: return host.mounted_location_ids().has(&"map_b"))
	MapNavBuilder.flush_deferred_bakes()
	var orphans_before := _orphan_ids()
	var logic_root := host.mounted_location_root(&"map_b", false)
	var view_root := host.mounted_location_root(&"map_b") as Node3D
	host.mount_queue.frame_budget_usec = 0  # one slice per tick
	var result := host.update_streaming(_at(35))
	assert_array_contains(result["evicted"], &"map_b")
	assert_false(logic_root.is_inside_tree(), "navigation and collision leave in the evicting tick")
	assert_false(host.is_seam_active_between(&"map_a", &"map_b"))
	assert_true(view_root.is_inside_tree() and not view_root.visible, "the view is hidden, not freed")
	assert_ne(String(view_root.name), "map_b", "the evicting root frees the location name")
	var ticks := 0
	while host.mount_queue.evicting_count() > 0 and ticks < 20000:
		host.update_streaming(_at(35))
		ticks += 1
	assert_true(ticks > 1, "teardown ran over several ticks (%d)" % ticks)
	assert_eq(host.mount_queue.evicting_count(), 0)
	assert_eq(_unreleased_orphans(orphans_before), [] as Array[String], "no node leaks")
	host.mount_queue.frame_budget_usec = int(WorldHostMountQueue.Assembly.frame_budget_msec() * 1000.0)
	host.update_streaming(_at(60))
	_pump(host, _at(60), func() -> bool: return host.mounted_location_ids().has(&"map_b"))
	var remounted := host.mounted_location_root(&"map_b")
	assert_eq(String(remounted.name), "map_b", "remounts under its own name")
	_dispose(host)


func test_delayed_io_holds_the_player_at_the_seam_and_records_the_miss() -> void:
	var host := _staged_host(400)
	host.scene_swap_fallback_enabled = true
	var requests: Array = []
	host.scene_swap_fallback_requested.connect(
		func(location_id: StringName, _request: Dictionary) -> void: requests.append(location_id)
	)
	host.update_streaming(_at(60))
	var result := host.update_streaming(_at(101))
	assert_eq(result["waiting"], &"map_b", "the player is held in front of the in-flight mount")
	assert_eq(host.owning_location_id(), &"map_a", "unloaded space never owns the player")
	assert_eq(result["fallback"], {}, "a healthy in-flight mount is not a failure")
	host.update_streaming(_at(101))
	var misses := host.mount_queue.misses()
	assert_eq(misses.size(), 1, "one readiness miss per edge visit")
	assert_eq(misses[0]["location_id"], "map_b")
	assert_eq(misses[0]["from_location_id"], "map_a")
	assert_eq(misses[0]["phase"], "PREPARING", "the delayed prepare is what missed")
	assert_false(misses[0]["logic_package_ready"])
	assert_true(int(misses[0]["waited_ticks"]) >= 1)
	_pump(host, _at(101), func() -> bool: return host.owning_location_id() == &"map_b")
	assert_eq(host.owning_location_id(), &"map_b", "the crossing completes once B is mounted")
	assert_eq(requests, [], "no scene swap while waiting")
	assert_eq(host.mount_queue.misses().size(), 1)
	_dispose(host)


func test_only_decoration_left_mounts_early_and_refines_in_place() -> void:
	var host := _staged_host()
	host.mount_queue.frame_budget_usec = 0  # exactly one view unit per tick
	host.update_streaming(_at(60))
	_pump(host, _at(60), func() -> bool:
		return host.mount_queue.phase_of(&"map_b") == WorldHostMountQueue.Phase.ASSEMBLING)
	var view := host.mount_queue.pending_view(&"map_b")
	assert_false(WorldHostMountQueue.only_decoration_left(view))
	var held := host.update_streaming(_at(101))
	assert_eq(held["waiting"], &"map_b", "ground and buildings missing: the seam stays closed")
	host.update_streaming(_at(60))
	while not WorldHostMountQueue.only_decoration_left(view):
		host.update_streaming(_at(60))
	# WB-08e: the built part is verified on a worker and enters in slices first,
	# so the player waits at the sealed seam for a few more ticks.
	var result := host.update_streaming(_at(101))
	assert_eq(result["waiting"], &"map_b", "the early mount is not walked inside this tick")
	var paused_units := view.pending_assembly_unit_count()
	var units_at_mount := [-1]
	host.location_mounted.connect(
		func(_location_id: StringName) -> void:
			units_at_mount[0] = view.pending_assembly_unit_count()
	)
	_pump(host, _at(101), func() -> bool: return host.owning_location_id() == &"map_b")
	assert_eq(units_at_mount[0], paused_units, "decoration paused until the mount")
	assert_eq(host.owning_location_id(), &"map_b")
	assert_true(host.is_seam_active_between(&"map_a", &"map_b"), "collision truth is complete")
	assert_eq(host.hosted_view(&"map_b"), view)
	assert_false(view.is_assembly_complete(), "decoration defers past activation")
	var logic_root := host.mounted_location_root(&"map_b", false)
	assert_true(logic_root.find_children("WorldBounds", "StaticBody2D", true, false).size() == 1)
	var misses := host.mount_queue.misses()
	assert_eq(misses.size(), 2, "the held visit and the early mount are separate misses")
	assert_true(misses[1]["early_mounted"])
	var deferred := StringName(misses[1]["deferred_from_stage"])
	assert_true(
		WorldHostMountQueue.Assembly.STAGES.find(deferred)
		>= WorldHostMountQueue.Assembly.STAGES.find(WorldHostMountQueue.FIRST_DEFERRABLE_STAGE),
		"only decoration was deferred (%s)" % deferred
	)
	host.set_clock_progress(0.42)
	_pump(host, _at(101), func() -> bool: return view.is_assembly_complete())
	assert_eq(host.mount_queue.phase_of(&"map_b"), -1, "a refined mount leaves the queue")
	assert_almost_eq(view.cycle_progress, 0.42, 0.0001, "the host clock wins over the initial time")
	_dispose(host)


func test_failed_staged_prepare_backs_off_before_retrying() -> void:
	var host := _staged_host()
	host.definition_provider = func(location_id: StringName) -> MapDefinition:
		return null if location_id == &"map_b" else _strip_definition(location_id)
	host.update_streaming(_at(60))
	_pump(host, _at(60), func() -> bool: return host.mount_failure_count(&"map_b") == 1)
	assert_eq(host.pending_location_ids(), [] as Array[StringName])
	for _tick in WorldHostMountQueue.RETRY_BACKOFF_TICKS - 1:
		host.update_streaming(_at(60))
		assert_eq(host.pending_location_ids(), [] as Array[StringName], "no retry inside the backoff")
	host.update_streaming(_at(60))
	assert_eq(host.pending_location_ids(), [&"map_b"], "retried once the backoff elapsed")
	_pump(host, _at(60), func() -> bool: return host.mount_failure_count(&"map_b") == 2)
	host.scene_swap_fallback_enabled = true
	var result := host.update_streaming(_at(101))
	assert_eq(result["waiting"], &"", "a failed mount is not waited for")
	assert_eq(result["fallback"].get("transition_id"), &"to_map_b")
	assert_eq(host.mount_failure_count(&"map_b"), 2, "the edge does not rebuild inside the backoff")
	assert_eq(host.owning_location_id(), &"map_a")
	_dispose(host)


func test_save_on_either_side_of_a_seam_and_mid_mount_round_trips() -> void:
	var state := GameState.new()
	var host := _staged_host(300, state)
	var driver := WorldHostStreamingDriver.attach(host)
	assert_true(driver != null)
	var player := host.player_owner as Node2D
	player.global_position = _at(90.25) + Vector2(0.0, 3.5)
	driver.tick()
	assert_eq(host.pending_location_ids(), [&"map_b"], "the save below is taken mid-mount")
	state.map_world_state.record_object_delta(&"map_b", &"prop:crate", {"moved": true})
	state.set_quest_state(&"quest.bitter_brew", &"active")
	var loaded_a := _save_round_trip(state)
	var world: Dictionary = loaded_a.map_world_state.save_payload()["world_state"]
	assert_eq((world["map_b"]["entities"] as Dictionary).size(), 0, "no player in the pending map")
	var text := loaded_a.map_world_state.canonical_text()
	for forbidden in ["PREPARING", "pending", "chunk", "/root/"]:
		assert_false(forbidden in text, "save payload carries no %s" % forbidden)
	_assert_resumes(loaded_a, &"scene_a", &"map_a", player.global_position, &"map_b")

	var owns_b := func() -> bool: return host.owning_location_id() == &"map_b"
	_pump_driver(driver, player, _at(110.5), owns_b)
	var loaded_b := _save_round_trip(state)
	var a_record := loaded_b.map_world_state.entity_state(&"map_a", WorldHostSeamSave.PLAYER_OBJECT_ID)
	assert_false(a_record.get("resume", true), "the crossing released A's record")
	_assert_resumes(loaded_b, &"scene_b", &"map_b", player.global_position, &"map_a")

	host.get_parent().remove_child(host)
	var b_record := state.map_world_state.entity_state(&"map_b", WorldHostSeamSave.PLAYER_OBJECT_ID)
	assert_false(b_record.get("resume", true), "a scene swap releases the live record")
	_dispose(host)


# --- helpers -----------------------------------------------------------------


func _real_members() -> Dictionary:
	# Compiling ten districts takes ~1.5 s; compile once per suite run.
	if _compiled.is_empty():
		_compiled = MapWorldLayout.compile_members()
	return _compiled


func _strip_host() -> WorldHost:
	var host := _configured_host(_strip_layout())
	host.location_loader = func(location_id: StringName) -> bool:
		return host.mount_location(location_id)
	return host


func _configured_host(layout: Dictionary) -> WorldHost:
	var host := WorldHost.new()
	host.name = "WorldHostSeamCrossing"
	host.additive_residency_enabled = true
	host.prefetch_band_cells = WorldHost.DEFAULT_PREFETCH_BAND_CELLS
	host.eviction_band_cells = WorldHost.DEFAULT_EVICTION_BAND_CELLS
	host.residency_cap = WorldHost.DEFAULT_RESIDENCY_CAP
	(Engine.get_main_loop() as SceneTree).root.add_child(host)
	var player := Node2D.new()
	var camera := Camera3D.new()
	var session := Node.new()
	host.add_child(player)
	host.add_child(camera)
	host.add_child(session)
	assert_true(host.configure(layout, player, camera, session), str(layout.get("errors", [])))
	return host


func _dispose(host: WorldHost) -> void:
	host.unmount_all()
	if host.get_parent() != null:
		host.get_parent().remove_child(host)
	host.free()


## Global logic position `x_cells` along the strip, on its middle row.
func _at(x_cells: float) -> Vector2:
	return Vector2(x_cells * CELL, 0.5 * STRIP_H * CELL)


func _center(layout: Dictionary, location_id: StringName) -> Vector2:
	for entry in layout["locations"]:
		if entry["location_id"] == location_id:
			return (entry["global_bounds"] as Rect2).get_center()
	return Vector2.ZERO


func _seam_midpoint(layout: Dictionary, first_id: StringName, second_id: StringName) -> Vector2:
	var first := Rect2()
	var second := Rect2()
	for entry in layout["locations"]:
		if entry["location_id"] == first_id:
			first = entry["global_bounds"]
		elif entry["location_id"] == second_id:
			second = entry["global_bounds"]
	return first.grow(1.0).intersection(second.grow(1.0)).get_center()


func _strip_layout() -> Dictionary:
	var layout := MapWorldLayout.layout_from_manifest(
		_strip_manifest([_strip_a(), _strip_b(), _strip_c()])
	)
	assert_true(layout["valid"], str(layout["errors"]))
	return layout


func _strip_manifest(definitions: Array[MapDefinition]) -> Dictionary:
	var members := [
		{"location_id": &"map_a", "scene_id": &"scene_a"},
		{"location_id": &"map_b", "scene_id": &"scene_b"},
		{"location_id": &"map_c", "scene_id": &"scene_c"},
	]
	return MapWorldLayout.build_manifest(definitions, members, &"map_a", &"test_outdoor")


func _strip_a() -> MapDefinition:
	return _strip_map(&"map_a", 0, [], [&"b"])


func _strip_b() -> MapDefinition:
	return _strip_map(&"map_b", 1, [&"a"], [&"c"])


func _strip_c() -> MapDefinition:
	return _strip_map(&"map_c", 2, [&"b"], [])


## A STRIP_W x STRIP_H map with one 8-cell aperture on the west edge per `west`
## neighbour and on the east edge per `east` neighbour. `_index` only documents
## the intended strip slot; placement comes from the reciprocal transitions.
func _strip_map(
	map_id: StringName, _index: int, west: Array[StringName], east: Array[StringName]
) -> MapDefinition:
	var definition := MapDefinition.new()
	definition.map_id = map_id
	definition.location = StringName("loc.%s" % map_id)
	definition.cell_size = CELL
	definition.size_cells = Vector2i(STRIP_W, STRIP_H)
	definition.base_terrain = MapTypes.TERRAIN_GRASS
	definition.player_spawn = Vector2(CELL, CELL)
	definition.scope = &"prototype"
	definition.active = false
	definition.palette = &"clean_painted"
	definition.fingerprint = "%s-fingerprint" % map_id
	var own := String(map_id).get_slice("_", 1) if String(map_id).begins_with("map_") else "w"
	var transitions: Array[Dictionary] = []
	for neighbor in west:
		transitions.append({
			"id": StringName("to_map_%s" % neighbor),
			"rect": Rect2(0, 16 * CELL, CELL, 8 * CELL),
			"spawn_id": StringName("%s_from_%s" % [own, neighbor]),
			"destination_spawn_id": StringName("%s_from_%s" % [neighbor, own]),
			"destination_scene_id": StringName("scene_%s" % neighbor),
		})
	for neighbor in east:
		transitions.append({
			"id": StringName("to_map_%s" % neighbor),
			"rect": Rect2((STRIP_W - 1) * CELL, 16 * CELL, CELL, 8 * CELL),
			"spawn_id": StringName("%s_from_%s" % [own, neighbor]),
			"destination_spawn_id": StringName("%s_from_%s" % [neighbor, own]),
			"destination_scene_id": StringName("scene_%s" % neighbor),
		})
	definition.transitions = transitions
	return definition


## A phase-3 host with staged mounts on, `entry_id` entered synchronously as the
## owner (a launch never stages the active map). `state` backs the session.
func _staged_host(
	delay_msec := 0, state: GameState = null, entry_id: StringName = &"map_a"
) -> WorldHost:
	var host := WorldHost.new()
	host.name = "WorldHostStagedMounts"
	host.additive_residency_enabled = true
	host.prefetch_band_cells = WorldHost.DEFAULT_PREFETCH_BAND_CELLS
	host.eviction_band_cells = WorldHost.DEFAULT_EVICTION_BAND_CELLS
	host.residency_cap = WorldHost.DEFAULT_RESIDENCY_CAP
	(Engine.get_main_loop() as SceneTree).root.add_child(host)
	var session := _session_node(state if state != null else GameState.new())
	host.add_child(session)
	assert_true(host.create_globals(_strip_layout(), {"session": session}))
	host.mount_queue.enabled = true
	host.mount_queue.prepare_delay_msec = delay_msec
	host.definition_provider = _strip_definition
	assert_true(host.enter_location(entry_id, _strip_definition(entry_id)))
	host.set_owning_location(entry_id)
	return host


func _session_node(state: GameState) -> Node:
	var script := GDScript.new()
	script.source_code = "extends Node\nvar state: GameState\n"
	script.reload()
	var session := Node.new()
	session.name = "Session"
	session.set_script(script)
	session.set("state", state)
	return session


## Called on a worker by staged mounts; builds fresh immutable definitions.
func _strip_definition(location_id: StringName) -> MapDefinition:
	match location_id:
		&"map_a":
			return _strip_a()
		&"map_b":
			return _strip_b()
		&"map_c":
			return _strip_c()
	return null


## Streaming ticks at `position` until `done`; sleeps so the worker can run.
func _pump(host: WorldHost, position: Vector2, done: Callable, timeout_msec := 60000) -> void:
	var deadline := Time.get_ticks_msec() + timeout_msec
	while not done.call():
		assert_true(Time.get_ticks_msec() < deadline, "timed out pumping staged mounts")
		if Time.get_ticks_msec() >= deadline:
			return
		host.update_streaming(position)
		OS.delay_usec(500)


func _pump_driver(
	driver: WorldHostStreamingDriver, player: Node2D, position: Vector2, done: Callable
) -> void:
	var deadline := Time.get_ticks_msec() + 60000
	player.global_position = position
	while not done.call() and Time.get_ticks_msec() < deadline:
		driver.tick()
		OS.delay_usec(500)
	driver.tick()
	assert_true(done.call(), "timed out walking the driver across the seam")


## Starts B, lets it reach `stop_phase`, walks away past the eviction band and
## waits until any worker result has drained.
func _run_cancel_cycle(host: WorldHost, stop_phase: int) -> void:
	host.update_streaming(_at(60))
	assert_eq(host.pending_location_ids(), [&"map_b"])
	if stop_phase == WorldHostMountQueue.Phase.ASSEMBLING:
		host.mount_queue.frame_budget_usec = 0
		_pump(host, _at(60), func() -> bool:
			return host.mount_queue.phase_of(&"map_b") == WorldHostMountQueue.Phase.ASSEMBLING)
		for _unit in 6:  # stop inside the view plan, with nodes already built
			host.update_streaming(_at(60))
	elif stop_phase == WorldHostMountQueue.Phase.ENTERING:
		host.mount_queue.frame_budget_usec = 0  # one slice per tick
		_pump(host, _at(60), func() -> bool:
			return host.mount_queue.phase_of(&"map_b") == WorldHostMountQueue.Phase.ENTERING)
		host.update_streaming(_at(60))  # part of the view is inside the staging root
	assert_eq(host.mount_queue.phase_of(&"map_b"), stop_phase)
	var result := host.update_streaming(_at(35))
	assert_array_contains(result["evicted"], &"map_b", "eviction reports the cancelled mount")
	assert_eq(host.pending_location_ids(), [] as Array[StringName])
	assert_eq(host.mounted_location_ids(), [&"map_a"])
	_pump(host, _at(35), func() -> bool:
		return host.mount_queue.draining_count() == 0 and host.mount_queue.evicting_count() == 0)
	host.mount_queue.frame_budget_usec = int(WorldHostMountQueue.Assembly.frame_budget_msec() * 1000.0)
	host.mount_queue.prepare_delay_msec = 0


## Pre-order "depth class name" rows of `root`; generated "@" names are
## instance-specific, so only their class counts.
func _tree_signature(root: Node) -> Array[String]:
	var rows: Array[String] = []
	_append_signature(root, 0, rows)
	return rows


func _append_signature(node: Node, depth: int, rows: Array[String]) -> void:
	var node_name := String(node.name)
	rows.append(
		"%d %s %s" % [depth, node.get_class(), "" if node_name.begins_with("@") else node_name]
	)
	for child in node.get_children():
		_append_signature(child, depth + 1, rows)


## A detached tree with wide plain containers and one scripted, atomic subtree.
func _wide_tree() -> Node3D:
	var root := Node3D.new()
	root.name = "View"
	var busy := Node3D.new()
	busy.name = "Busy"
	root.add_child(busy)
	for index in 12:
		var mesh := MeshInstance3D.new()
		mesh.name = "Mesh%d" % index
		busy.add_child(mesh)
	var flock := Node3D.new()
	flock.name = "Flock"
	var script := GDScript.new()
	script.source_code = "extends Node3D\n"
	script.reload()
	flock.set_script(script)
	busy.add_child(flock)
	for index in 6:
		var bird := Node3D.new()
		bird.name = "Bird%d" % index
		flock.add_child(bird)
	var quiet := Node3D.new()
	quiet.name = "Quiet"
	root.add_child(quiet)
	quiet.add_child(Node3D.new())
	return root


## SaveService on disk and back, exactly like a player save and load.
func _save_round_trip(state: GameState) -> GameState:
	var service := SaveService.new()
	service.save_directory = "user://test_r1044_seam_saves"
	assert_true(service.save_game(state, 0))
	var loaded := service.load_game(0)
	for path in [service.slot_path(0), service.backup_path(0)]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	assert_true(loaded["ok"], str(loaded["errors"]))
	return loaded["state"] as GameState


## Launches `location_id` from a loaded save like a scene would (spawn placement
## first), and checks the driver's first tick restores the saved position.
func _assert_resumes(
	loaded: GameState,
	scene_id: StringName,
	location_id: StringName,
	expected: Vector2,
	neighbor_id: StringName
) -> void:
	assert_eq(loaded.player.location_id, scene_id)
	assert_eq(loaded.get_quest_state(&"quest.bitter_brew"), &"active")
	assert_eq(loaded.map_world_state.object_delta(&"map_b", &"prop:crate"), {"moved": true})
	var probe := _configured_host(_strip_layout())
	assert_eq(WorldHostSeamSave.location_for_scene(probe, scene_id), location_id)
	_dispose(probe)
	var host := _staged_host(0, loaded, location_id)
	var driver := WorldHostStreamingDriver.attach(host)
	var player := host.player_owner as Node2D
	player.global_position = host.location_origin_logic_position(location_id) + Vector2(CELL, CELL)
	driver.tick()
	assert_true(player.global_position.distance_to(expected) <= 0.01, "resumes the saved sub-cell")
	assert_eq(host.owning_location_id(), location_id)
	var resident := host.mounted_location_ids() + host.pending_location_ids()
	assert_array_contains(resident, neighbor_id, "the neighbour streams in again after load")
	player.global_position += Vector2(CELL, 0.0)
	var moved := player.global_position
	driver.tick()
	assert_eq(player.global_position, moved, "the saved position is consumed once")
	_dispose(host)


static func _orphan_ids() -> Dictionary:
	var ids := {}
	for id in Node.get_orphan_node_ids():
		ids[id] = true
	return ids


static func _unreleased_orphans(before: Dictionary) -> Array[String]:
	var leaked: Array[String] = []
	for id in Node.get_orphan_node_ids():
		if before.has(id):
			continue
		var node := instance_from_id(id) as Node
		if node != null and not node.is_queued_for_deletion():
			leaked.append("%s (%s)" % [node.name, node.get_class()])
	return leaked
