class_name CartTransportController
extends Node

## Phase-aware ambient merchant-cart traffic for Lower Town.
## WHY: R-207 authors stable cart props and P2-068 supplies their meshes; this
## controller only decides which authored traffic remains visible in each phase.
## Iron convoy quest state stays owned by SupplyChainController.

const PropStyleVariants := preload("res://scripts/map/map_prop_style_variants.gd")

const FLAG_SIEGE_INLAND_CART_ACTIVE := &"flag.supply.siege_inland_cart_active"
const PHASE_ACT1_CLIMAX := &"phase.act1_climax"

const CORRIDOR_VANATURG_THROAT := PropStyleVariants.CART_CORRIDOR_VANATURG_THROAT
const CORRIDOR_HARBOUR_MARGIN := PropStyleVariants.CART_CORRIDOR_HARBOUR_MARGIN
const CORRIDOR_VIRU_APRON := PropStyleVariants.CART_CORRIDOR_VIRU_APRON

const PROP_VANATURG_QUEUE := &"vanaturg_cart_queue"
const PROP_HARBOUR_GATE_CART := &"gate_cart"
const PROP_VIRU_GRAIN_CART := &"viru_apron_grain_cart"

const TRAFFIC_DESCRIPTORS: Array[Dictionary] = [
	{
		"prop_id": PROP_VANATURG_QUEUE,
		"corridor": CORRIDOR_VANATURG_THROAT,
		"vehicle_class": PropStyleVariants.VEHICLE_CLASS_CART_2W,
		"inland": false,
	},
	{
		"prop_id": PROP_HARBOUR_GATE_CART,
		"corridor": CORRIDOR_HARBOUR_MARGIN,
		"vehicle_class": PropStyleVariants.VEHICLE_CLASS_CART_2W,
		"inland": false,
	},
	{
		"prop_id": PROP_VIRU_GRAIN_CART,
		"corridor": CORRIDOR_VIRU_APRON,
		"vehicle_class": PropStyleVariants.VEHICLE_CLASS_CART_2W,
		"inland": true,
	},
]

var location_id: StringName = &""

var _definition: MapDefinition
var _view_runtime
var _state: GameState
var _sync_key := ""
var _active_traffic: Array[Dictionary] = []


func setup(
	definition: MapDefinition,
	view_runtime,
	map_location_id: StringName,
	state_override: GameState = null
) -> void:
	_definition = definition
	_view_runtime = view_runtime
	location_id = map_location_id
	_connect_state(state_override if state_override != null else SessionState.state)
	if state_override == null and not SessionState.state_replaced.is_connected(_on_state_replaced):
		SessionState.state_replaced.connect(_on_state_replaced)


func _exit_tree() -> void:
	if SessionState.state_replaced.is_connected(_on_state_replaced):
		SessionState.state_replaced.disconnect(_on_state_replaced)
	_disconnect_state(_state)


func _process(_delta: float) -> void:
	_sync_traffic()


func get_active_traffic() -> Array[Dictionary]:
	return _active_traffic.duplicate(true)


func is_inland_cart_active() -> bool:
	return _state != null and _state.get_flag(FLAG_SIEGE_INLAND_CART_ACTIVE)


func sync_for_test(phase_id: StringName) -> void:
	if _state == null:
		return
	_state.set_phase(phase_id)
	_sync_key = ""
	_sync_traffic()


static func traffic_for_phase(
	phase_id: StringName, inland_cart_active: bool = true
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	# Night phases observe the curfew: keep the authored props in the map but do
	# not present them as active ambient traffic. The Act 1 climax retains only
	# harbour-side lighter dressing while inland grain is stalled.
	if phase_id in [GameState.PHASE_INVESTIGATION_NIGHT, GameState.PHASE_CONSEQUENCE_NIGHT]:
		return result
	for descriptor in TRAFFIC_DESCRIPTORS:
		if bool(descriptor["inland"]) and not inland_cart_active:
			continue
		result.append(descriptor.duplicate(true))
	return result


func _on_state_replaced(_previous: GameState, current: GameState, _reason: StringName) -> void:
	_connect_state(current)


func _connect_state(state: GameState) -> void:
	_disconnect_state(_state)
	_state = state
	_sync_key = ""
	if _state != null and not _state.phase_changed.is_connected(_on_phase_changed):
		_state.phase_changed.connect(_on_phase_changed)
	_sync_traffic()


func _disconnect_state(state: GameState) -> void:
	if state != null and state.phase_changed.is_connected(_on_phase_changed):
		state.phase_changed.disconnect(_on_phase_changed)


func _on_phase_changed(_previous: StringName, _next: StringName) -> void:
	_sync_key = ""
	_sync_traffic()


func _sync_traffic() -> void:
	if _state == null or _definition == null:
		return
	var phase_id := _state.get_phase()
	var inland_active := phase_id != PHASE_ACT1_CLIMAX
	_state.set_flag(FLAG_SIEGE_INLAND_CART_ACTIVE, inland_active)
	var next_key := "%s|%s|%s" % [String(location_id), String(phase_id), str(inland_active)]
	if next_key == _sync_key:
		return
	_sync_key = next_key
	_active_traffic = traffic_for_phase(phase_id, inland_active)
	var active_ids: Dictionary = {}
	for descriptor in _active_traffic:
		active_ids[descriptor["prop_id"]] = true
	for descriptor in TRAFFIC_DESCRIPTORS:
		var prop_id: StringName = descriptor["prop_id"]
		if MapVerification.prop_position(_definition, prop_id) == Vector2.ZERO:
			continue
		_set_prop_visible(prop_id, active_ids.has(prop_id))


func _set_prop_visible(prop_id: StringName, visible_state: bool) -> void:
	if _view_runtime == null or _view_runtime.view == null:
		return
	_view_runtime.view.set_prop_visible(prop_id, visible_state)
