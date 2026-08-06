extends SceneTree

## R-419 / R-446 evidence capture for readable Lower Town population clusters.
## WHY: the urban population profile is renderer-agnostic, so this tool supplies a
## deterministic, view-only placement layer for acceptance evidence without
## changing GameState, the production rrmap, or gameplay actor ownership.

const LowerTown := preload("res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd")
const Profile := preload("res://scripts/world/urban_population_profile.gd")
const Placement := preload("res://scripts/world/urban_population_placement.gd")
const CrowdRenderer := preload("res://scripts/map/view3d/map_view_crowd_renderer.gd")
const OUTPUT_DIR := "res://docs/reports/images/population"
const MANIFEST_PATH := "res://docs/reports/population_clusters_r419.json"
const REPORT_PATH := "res://docs/reports/r419_lower_town_population_clusters.md"
const VIEWPORT_SIZE := Vector2i(1280, 720)
const DATE_OFF_DAY := {"day": 22, "month": 4, "year": 1343}
const DATE_MARKET_DAY := {"day": 24, "month": 4, "year": 1343}
const PHASE_DAY := GameState.PHASE_INVESTIGATION_MORNING
const PHASE_NIGHT := GameState.PHASE_INVESTIGATION_NIGHT
const CAPACITY := 64

const SCENARIOS: Array[Dictionary] = [
	{
		"id": "day",
		"label": "Ordinary day",
		"profile": Profile.PROFILE_DAY,
		"phase": PHASE_DAY,
		"date": DATE_OFF_DAY,
		"seed": 1343,
		"focus": Vector2(2340.0, 1930.0),
		"camera_size": 24.0,
	},
	{
		"id": "market_day",
		"label": "Market day",
		"profile": Profile.PROFILE_MARKET_DAY,
		"phase": PHASE_DAY,
		"date": DATE_MARKET_DAY,
		"seed": 2024,
		"focus": Vector2(720.0, 1810.0),
		"camera_size": 22.0,
	},
	{
		"id": "night_checkpoint",
		"label": "Night checkpoint",
		"profile": Profile.PROFILE_NIGHT,
		"phase": PHASE_NIGHT,
		"date": DATE_OFF_DAY,
		"seed": 1343,
		"focus": Vector2(3490.0, 1820.0),
		"camera_size": 20.0,
	},
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var definition: MapDefinition = LowerTown.create()
	var errors := definition.validate()
	if not errors.is_empty():
		for error in errors:
			push_error("Lower Town definition invalid: %s" % error)
		quit(1)
		return
	var grid := MapBuilder.build(definition)
	var manifest := {
		"task": "R-419",
		"map_id": String(definition.map_id),
		"source": "res://content/maps/lower_town_slice.rrmap",
		"viewport_px": [VIEWPORT_SIZE.x, VIEWPORT_SIZE.y],
		"capacity": CAPACITY,
		"scenarios": [],
	}
	for scenario: Dictionary in SCENARIOS:
		var result := await _capture_scenario(definition, grid, scenario)
		if result.is_empty():
			quit(1)
			return
		(manifest["scenarios"] as Array).append(result)
	_write_json(MANIFEST_PATH, manifest)
	_write_report(manifest)
	print("R-419 population capture complete: %s" % MANIFEST_PATH)
	quit(0)


func _capture_scenario(
	definition: MapDefinition,
	grid: MapTerrainGrid,
	scenario: Dictionary
) -> Dictionary:
	var profile_id: StringName = scenario["profile"]
	var profile := Profile.resolve(profile_id, scenario["phase"], scenario["date"], int(scenario["seed"]))
	var placements := Placement.build_placements(definition, grid, profile)
	if placements.size() != int(profile["total_count"]):
		push_error(
			"Could not place full %s profile: %d/%d" %
			[String(profile_id), placements.size(), int(profile["total_count"])]
		)
		return {}

	var viewport := SubViewport.new()
	viewport.name = "PopulationCapture_%s" % String(scenario["id"])
	viewport.size = VIEWPORT_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var view := MapView3D.create(definition, grid, MapView3D.TIME_NIGHT if profile_id == Profile.PROFILE_NIGHT else MapView3D.TIME_DAY)
	viewport.add_child(view)
	var camera := view.view_camera()
	var focus_world := view.world_position(scenario["focus"])
	camera.position = focus_world + camera.transform.basis.z * 26.0
	camera.size = float(scenario["camera_size"])
	camera.current = true

	var crowd := CrowdRenderer.new()
	crowd.name = "PopulationCrowd"
	crowd.configure(CAPACITY, int(profile["seed"]))
	view.add_child(crowd)
	for placement: Dictionary in placements:
		var logic_position: Vector2 = placement["position"]
		var world_position := view.world_position(logic_position)
		var ground_y := MapViewMeshBuilder.ground_height(
			definition,
			Vector2(world_position.x, world_position.z)
		)
		crowd.set_actor_position(
			int(placement["actor_index"]),
			Vector3(world_position.x, ground_y + 0.02, world_position.z)
		)

	_add_overlay(viewport, scenario, profile, placements.size())
	for _frame in 5:
		await process_frame
	var image := viewport.get_texture().get_image()
	var output := "%s/lower_town_population_%s.png" % [OUTPUT_DIR, scenario["id"]]
	var error := image.save_png(ProjectSettings.globalize_path(output))
	if error != OK:
		push_error("Could not save population capture %s: %s" % [output, error_string(error)])
		viewport.queue_free()
		return {}
	var result := {
		"id": scenario["id"],
		"label": scenario["label"],
		"profile_id": String(profile["profile_id"]),
		"phase_id": String(profile["phase_id"]),
		"date": profile["date"],
		"seed": profile["seed"],
		"civilian_count": profile["civilian_count"],
		"watch_count": profile["watch_count"],
		"total_count": profile["total_count"],
		"renderer_capacity": crowd.capacity(),
		"active_count": crowd.active_count(),
		"placement_zone_counts": _zone_counts(placements),
		"capture": output,
		"viewport_px": [image.get_width(), image.get_height()],
	}
	crowd.clear_actors()
	viewport.queue_free()
	await process_frame
	print("R-419 capture: %s (%d actors)" % [output, int(result["total_count"])])
	return result


func _zone_counts(placements: Array[Dictionary]) -> Dictionary:
	var counts := {}
	for placement: Dictionary in placements:
		var zone_id: String = placement["zone_id"]
		counts[zone_id] = int(counts.get(zone_id, 0)) + 1
	return counts


func _add_overlay(
	viewport: SubViewport,
	scenario: Dictionary,
	profile: Dictionary,
	placed_count: int
) -> void:
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(overlay)
	var title := Label.new()
	title.position = Vector2(28.0, 24.0)
	title.text = "LOWER TOWN POPULATION  |  %s" % String(scenario["label"]).to_upper()
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.96, 0.90, 0.77, 1.0))
	title.add_theme_color_override("font_shadow_color", Color(0.05, 0.04, 0.03, 0.9))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	title.size = Vector2(900.0, 38.0)
	overlay.add_child(title)
	var subtitle := Label.new()
	subtitle.position = Vector2(30.0, 58.0)
	subtitle.text = "profile=%s  civilians=%d  watch=%d  placed=%d  seed=%d" % [
		String(profile["profile_id"]),
		int(profile["civilian_count"]),
		int(profile["watch_count"]),
		placed_count,
		int(profile["seed"]),
	]
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color(0.89, 0.85, 0.76, 1.0))
	subtitle.size = Vector2(1100.0, 30.0)
	overlay.add_child(subtitle)


func _write_json(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write %s" % path)
		return
	file.store_string(JSON.stringify(payload, "  ") + "\n")
	file.close()


func _write_report(manifest: Dictionary) -> void:
	var lines: Array[String] = [
		"# R-419 Lower Town population cluster captures",
		"",
		"Evidence-only GPU captures for readable deterministic population clusters on the production Lower Town map.",
		"The capture tool does not mutate `GameState`, the rrmap source, or runtime actor ownership.",
		"",
		"## Acceptance",
		"",
		"- Source map: `res://content/maps/lower_town_slice.rrmap`",
		"- Viewport: %d x %d PNG per scenario" % [VIEWPORT_SIZE.x, VIEWPORT_SIZE.y],
		"- Renderer capacity: %d; profile actors remain logically registered and are placed only on walkable cells." % CAPACITY,
		"- Placement is deterministic from each profile's date, phase, and seed; building, water, prop, and actor clearances are checked before capture.",
		"",
		"| Scenario | Profile | Civilians | Watch | Active | Capacity | Capture |",
		"| --- | --- | ---: | ---: | ---: | ---: | --- |",
	]
	for scenario: Dictionary in manifest["scenarios"]:
		lines.append(
			"| %s | `%s` | %d | %d | %d | %d | [%s](images/population/%s) |" % [
				scenario["label"],
				scenario["profile_id"],
				int(scenario["civilian_count"]),
				int(scenario["watch_count"]),
				int(scenario["active_count"]),
				int(scenario["renderer_capacity"]),
				String(scenario["id"]),
				String(scenario["capture"]).get_file(),
			]
		)
	lines.append_array([
		"",
		"## Reproduction",
		"",
		"```sh",
		"/Applications/Godot.app/Contents/MacOS/Godot --path . --editor --headless --import",
		"/Applications/Godot.app/Contents/MacOS/Godot --path . --rendering-method mobile --rendering-driver metal --script tools/capture_lower_town_population.gd",
		"```",
		"",
		"The second command requires a rendering-capable session. The JSON manifest records the exact profile inputs and output dimensions.",
	])
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write %s" % REPORT_PATH)
		return
	file.store_string("\n".join(lines) + "\n")
	file.close()
