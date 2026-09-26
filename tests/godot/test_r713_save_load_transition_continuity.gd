extends "res://tests/godot/test_case.gd"

## R-854: a mid-transition weather snapshot must survive SaveService plus an
## adjacent-map bind without creating a second environment owner.

const EastDefinition := preload(
	"res://scripts/map/definitions/outdoor/reval_harbor_east_definition.gd"
)
const MapBuilder := preload("res://scripts/map/map_builder.gd")
const MapParitySnapshot := preload("res://scripts/map/map_parity_snapshot.gd")
const NorthDefinition := preload(
	"res://scripts/map/definitions/outdoor/reval_harbor_north_definition.gd"
)
const SkyWeather := preload("res://scripts/map/view3d/sky_weather_3d.gd")

const REPORT_PATH := "res://docs/reports/r713_sky_weather_acceptance.md"
const CONTINUATION_SECONDS := 0.25

var _original_state: GameState
var _original_save_service: SaveService
var _save_directory := ""


func before_each() -> void:
	_original_state = SessionState.state
	_original_save_service = SessionState.save_service
	super.before_each()


func after_each() -> void:
	var active := SessionState.active_environment_runtime()
	if active != null:
		SessionState.unbind_environment_runtime(active)
	SessionState.save_service = _original_save_service
	SessionState.replace_state(_original_state, &"test_cleanup")
	if not _save_directory.is_empty():
		_remove_tree(_save_directory)
	_save_directory = ""
	super.after_each()


func test_saved_mid_transition_weather_binds_one_owner_on_next_map() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	assert_true(tree != null and SessionState != null, "fixture requires SessionState")
	if tree == null or SessionState == null:
		return

	var service := SaveService.new()
	_save_directory = "user://test_saves/r854_continuity_%d" % Time.get_ticks_usec()
	service.save_directory = _save_directory
	SessionState.save_service = service
	SessionState.state.set_environment_state(null)

	var source := _build_runtime(tree, "R854Source", NorthDefinition.create())
	assert_true(
		SessionState.bind_environment_runtime(source),
		"source presenter must bind through SessionState",
	)
	assert_eq(
		_active_environment_owner_count([source]),
		1,
		"source handoff must leave exactly one active WorldEnvironment owner",
	)

	# Rain mid-blend, not a settled clear default, so a reset cannot pass.
	source.cycle_progress = 0.18
	source.cycle_elapsed_days = 3
	source.view.set_calendar_date({"day": 7, "month": 5, "year": 1343})
	var source_weather := source.environment_weather() as SkyWeather
	source_weather.auto_weather = false
	source_weather.set_weather(SkyWeather.WEATHER_RAIN)
	source_weather.advance(SkyWeather.TRANSITION_SECONDS * 0.4)
	source.view.apply_cycle_progress(source.cycle_progress)
	var source_snapshot := source.environment_snapshot()
	assert_eq(String(source_snapshot.get("weather", "")), "rain")
	assert_true(
		float(source_snapshot.get("transition_progress", 1.0)) < 1.0,
		"the saved snapshot must still be mid-transition",
	)

	assert_true(
		SessionState.save_game(),
		"SessionState must persist the captured weather snapshot",
	)
	SessionState.unbind_environment_runtime(source)
	source.free()
	assert_true(SessionState.load_game(), "SessionState must restore the same envelope")

	var loaded_environment := SessionState.state.get_environment_state()
	assert_eq(
		MapParitySnapshot.serialize_value(loaded_environment),
		MapParitySnapshot.serialize_value(source_snapshot),
		"save/load must keep the complete weather payload, not a fresh default",
	)

	var destination := _build_runtime(tree, "R854Destination", EastDefinition.create())
	assert_true(
		SessionState.bind_environment_runtime(destination),
		"destination presenter must bind the restored canonical snapshot",
	)
	assert_eq(
		SessionState.active_environment_runtime(),
		destination,
		"destination presenter must become the only SessionState owner",
	)
	assert_true(
		destination.view.environment_binding_active(),
		"destination presenter must own the live environment binding",
	)
	assert_eq(
		_active_environment_owner_count([destination]),
		1,
		"load-plus-handoff must leave exactly one active WorldEnvironment owner",
	)

	var restored_snapshot := destination.environment_snapshot()
	_assert_continuity_fields(source_snapshot, restored_snapshot)
	assert_eq(
		MapParitySnapshot.serialize_value(restored_snapshot),
		MapParitySnapshot.serialize_value(source_snapshot),
		"the destination presenter must rehydrate the same canonical weather state",
	)

	var control := SkyWeather.new()
	assert_true(control.restore_state(loaded_environment))
	var destination_weather := destination.environment_weather() as SkyWeather
	control.advance(CONTINUATION_SECONDS)
	destination_weather.advance(CONTINUATION_SECONDS)
	var continued: Dictionary = destination_weather.snapshot_state(
		destination.cycle_progress, destination.cycle_elapsed_days
	).to_dict()
	var control_continued: Dictionary = control.snapshot_state(
		destination.cycle_progress, destination.cycle_elapsed_days
	).to_dict()
	assert_eq(
		MapParitySnapshot.serialize_value(continued),
		MapParitySnapshot.serialize_value(control_continued),
		"restored weather must continue deterministically after the map bind",
	)
	control.free()
	SessionState.unbind_environment_runtime(destination)
	destination.free()


func test_malformed_environment_payload_stays_fail_closed() -> void:
	var state := GameState.new()
	var weather := SkyWeather.new()
	weather.auto_weather = false
	weather.set_weather(SkyWeather.WEATHER_STORM)
	weather.advance(SkyWeather.TRANSITION_SECONDS * 0.3)
	assert_true(state.set_environment_state(weather.snapshot_state(0.2, 1).to_dict()))
	weather.free()

	var payload := state.save_payload()
	payload["environment"] = {"schema_version": 99, "weather": "rain"}
	var restored := GameState.new()
	var errors := restored.load_payload(payload)
	assert_true(errors.size() > 0, "unsupported weather schema must fail closed")
	assert_true("environment" in ", ".join(errors))
	assert_true(
		restored.get_environment_state().is_empty(),
		"a rejected environment must not become the live canonical snapshot",
	)

	var rejected := SkyWeather.new()
	assert_false(
		rejected.restore_state({"schema_version": 99, "weather": "rain"}),
		"a presenter must reject a foreign weather schema",
	)
	rejected.free()


func test_report_records_save_load_transition_fixture() -> void:
	var report := FileAccess.get_file_as_string(REPORT_PATH)
	assert_true(not report.is_empty(), "R-713 acceptance report must exist")
	for required_anchor: String in [
		"R-854",
		"test_r713_save_load_transition_continuity.gd",
		"one environment owner",
		"mid-transition",
	]:
		assert_true(
			report.contains(required_anchor),
			"acceptance report must record the R-854 fixture: %s" % required_anchor,
		)


func _assert_continuity_fields(source: Dictionary, restored: Dictionary) -> void:
	assert_eq(String(restored.get("weather", "")), String(source.get("weather", "")))
	assert_eq(
		String(restored.get("transition_from_weather", "")),
		String(source.get("transition_from_weather", "")),
	)
	assert_true(
		is_equal_approx(
			float(restored.get("transition_progress", -1.0)),
			float(source.get("transition_progress", -2.0))
		),
		"transition progress must survive save/load and the map bind",
	)
	assert_eq(int(restored.get("elapsed_days", -1)), int(source.get("elapsed_days", -2)))
	assert_true(
		is_equal_approx(
			float(restored.get("cycle_progress", -1.0)),
			float(source.get("cycle_progress", -2.0))
		),
		"calendar clock progress must survive save/load and the map bind",
	)
	assert_eq(
		MapParitySnapshot.serialize_value(restored.get("calendar_date", {})),
		MapParitySnapshot.serialize_value(source.get("calendar_date", {})),
		"calendar date must survive save/load and the map bind",
	)
	assert_true(
		is_equal_approx(
			float(restored.get("puddle_wetness", -1.0)),
			float(source.get("puddle_wetness", -2.0))
		),
		"wetness accumulator must survive save/load and the map bind",
	)
	assert_eq(
		restored.get("seconds_since_rain", null),
		source.get("seconds_since_rain", null),
		"rain accumulator must survive save/load and the map bind",
	)
	assert_eq(
		MapParitySnapshot.serialize_value(restored.get("cloud_offset", [])),
		MapParitySnapshot.serialize_value(source.get("cloud_offset", [])),
		"cloud offset must survive save/load and the map bind",
	)
	assert_eq(
		MapParitySnapshot.serialize_value(restored.get("cloud_detail_offset", [])),
		MapParitySnapshot.serialize_value(source.get("cloud_detail_offset", [])),
		"cloud detail offset must survive save/load and the map bind",
	)


func _build_runtime(
	tree: SceneTree, runtime_name: String, definition: MapDefinition
) -> MapViewRuntime:
	var runtime := MapViewRuntime.new()
	runtime.name = runtime_name
	runtime._definition = definition
	runtime.view = MapView3D.create(definition, MapBuilder.build(definition))
	tree.root.add_child(runtime)
	runtime.add_child(runtime.view)
	return runtime


func _active_environment_owner_count(runtimes: Array[MapViewRuntime]) -> int:
	var count := 0
	for runtime: MapViewRuntime in runtimes:
		var environment := runtime.view.environment_node()
		if runtime.view.environment_binding_active() and environment.environment != null:
			count += 1
	return count


func _remove_tree(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		DirAccess.remove_absolute(path)
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var child := path.path_join(entry)
			if DirAccess.dir_exists_absolute(child):
				_remove_tree(child)
			else:
				DirAccess.remove_absolute(child)
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)
