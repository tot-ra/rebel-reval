class_name UrbanPopulationController
extends Node

## Lower Town runtime bridge from phase/calendar inputs to the crowd renderer.
## WHY: UrbanPopulationProfile stays renderer-agnostic; this controller resolves
## profiles, places actors on authored zones, and never mutates GameState.

const ProfileScript := preload("res://scripts/world/urban_population_profile.gd")
const MapBindingScript := preload("res://scripts/world/urban_population_map_binding.gd")
const PlacementScript := preload("res://scripts/world/urban_population_placement.gd")
const MarketDayModelScript := preload("res://scripts/world/market_day_model.gd")
const PressureScript := preload("res://scripts/faction/district_pressure_model.gd")
const MeshBuilderScript := preload("res://scripts/map/view3d/map_view_mesh_builder.gd")

const DEFAULT_CAPACITY := 64
const DEFAULT_REPLAY_SEED := 1343

var location_id: StringName = &""

var _definition: MapDefinition
var _grid: MapTerrainGrid
var _view_runtime
var _state: GameState
var _replay_seed := DEFAULT_REPLAY_SEED
var _market_day_active := false
var _sync_key := ""
var _active_profile: Dictionary = {}


func setup(
	definition: MapDefinition,
	grid: MapTerrainGrid,
	view_runtime,
	map_location_id: StringName,
	replay_seed: int = DEFAULT_REPLAY_SEED
) -> void:
	location_id = map_location_id
	_definition = definition
	_grid = grid
	_view_runtime = view_runtime
	_replay_seed = replay_seed
	if definition == null or definition.map_id != MapBindingScript.LOWER_TOWN_MAP_ID:
		return
	if view_runtime != null:
		view_runtime.configure_crowd(DEFAULT_CAPACITY, _replay_seed)
	_connect_state(SessionState.state)
	if not SessionState.state_replaced.is_connected(_on_state_replaced):
		SessionState.state_replaced.connect(_on_state_replaced)


func _exit_tree() -> void:
	if SessionState.state_replaced.is_connected(_on_state_replaced):
		SessionState.state_replaced.disconnect(_on_state_replaced)
	_disconnect_state(_state)


func _process(_delta: float) -> void:
	_sync_population()


func set_market_day_active(active: bool) -> void:
	if _market_day_active == active:
		return
	_market_day_active = active
	_sync_key = ""
	_sync_population()


func set_population_enabled(enabled: bool) -> void:
	if _view_runtime != null:
		_view_runtime.set_crowd_enabled(enabled)


func get_active_profile() -> Dictionary:
	return _active_profile.duplicate(true)


func crowd_active_count() -> int:
	if _view_runtime == null:
		return 0
	return _view_runtime.crowd_active_count()


func sync_for_test(
	phase_id: StringName,
	elapsed_days: int,
	market_day: bool = false,
	replay_seed: int = -1
) -> void:
	if _state != null:
		_state.set_phase(phase_id)
	if _view_runtime != null:
		_view_runtime.cycle_elapsed_days = maxi(elapsed_days, 0)
	_market_day_active = market_day
	if replay_seed >= 0:
		_replay_seed = replay_seed
	_sync_key = ""
	_sync_population()


func _on_state_replaced(_previous: GameState, current: GameState, _reason: StringName) -> void:
	_connect_state(current)


func _connect_state(state: GameState) -> void:
	_disconnect_state(_state)
	_state = state
	if _state == null:
		return
	if not _state.phase_changed.is_connected(_on_phase_changed):
		_state.phase_changed.connect(_on_phase_changed)
	if not _state.faction_event_recorded.is_connected(_on_pressure_changed):
		_state.faction_event_recorded.connect(_on_pressure_changed)
	_sync_key = ""
	_sync_population()


func _disconnect_state(state: GameState) -> void:
	if state == null:
		return
	if state.phase_changed.is_connected(_on_phase_changed):
		state.phase_changed.disconnect(_on_phase_changed)
	if state.faction_event_recorded.is_connected(_on_pressure_changed):
		state.faction_event_recorded.disconnect(_on_pressure_changed)


func _on_phase_changed(_previous: StringName, _next: StringName) -> void:
	_sync_key = ""
	_sync_population()


func _on_pressure_changed(_event_id: StringName, _faction_id: StringName) -> void:
	_sync_key = ""
	_sync_population()


func _sync_population() -> void:
	if _definition == null or _definition.map_id != MapBindingScript.LOWER_TOWN_MAP_ID:
		return
	var phase_id := _current_phase_id()
	var date := _current_date(phase_id)
	var context := _profile_context()
	var next_key := "%s|%s|%s|%s|%d" % [
		String(phase_id),
		GameCalendar.format_date(date),
		str(_market_day_active),
		str(context),
		_replay_seed,
	]
	if next_key == _sync_key:
		return
	_sync_key = next_key
	var profile := ProfileScript.resolve_for_context(phase_id, date, _replay_seed, context)
	_active_profile = profile
	_apply_profile_to_renderer(profile)


func _apply_profile_to_renderer(profile: Dictionary) -> void:
	if _view_runtime == null or _view_runtime.view == null:
		return
	var renderer: MapViewCrowdRenderer = _view_runtime.get_crowd_renderer()
	if renderer == null:
		return
	renderer.clear_actors()
	var placements := PlacementScript.build_placements(_definition, _grid, profile)
	for placement: Dictionary in placements:
		var logic_position: Vector2 = placement["position"]
		var world_position: Vector3 = _view_runtime.view.world_position(logic_position)
		var ground_y := MeshBuilderScript.ground_height(
			_definition,
			Vector2(world_position.x, world_position.z)
		)
		renderer.set_actor_position(
			int(placement["actor_index"]),
			Vector3(world_position.x, ground_y + 0.02, world_position.z)
		)


func _current_phase_id() -> StringName:
	if _state != null:
		return _state.get_phase()
	return GameState.PHASE_INVESTIGATION_MORNING


func _current_date(phase_id: StringName) -> Dictionary:
	var elapsed_days := 0
	if _view_runtime != null:
		elapsed_days = _view_runtime.cycle_elapsed_days
	return MarketDayModelScript.resolve_date(phase_id, elapsed_days)


func _profile_context() -> Dictionary:
	var context := {"market_day": _market_day_active}
	if _state == null or location_id.is_empty():
		return context
	var pressure := PressureScript.resolve_for_location(location_id, _state)
	var tier := int(pressure.get("pressure_tier", PressureScript.TIER_NORMAL))
	if tier >= PressureScript.TIER_CRACKDOWN:
		context["crackdown"] = true
	elif tier >= PressureScript.TIER_TENSE:
		context["tense"] = true
	return context
