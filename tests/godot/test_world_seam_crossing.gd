extends "res://tests/godot/test_case.gd"

## WB-08 / R-980: the checked-in reval_outdoor world-layout manifest, the
## WorldHost streaming policy (prefetch, eviction hysteresis, residency cap), seam
## handover without re-creating globals, the travel boundary, and the scene-swap
## fallback for a failed or blocked mount.

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
			var plan := WorldHost.plan_residency(
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
