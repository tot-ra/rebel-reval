extends Node

## Session-scoped GameState holder. Inventory and quest flags survive map transitions
## within one play session and across manual save/load via SaveService (P1-007).

## Demo gameplay items/dialogue plus the validated example corpus. Do not list
## `content/demo/support` here: `content/demo` already recurses into it and
## would register duplicate IDs. Runtime uses `content/examples/support` for
## shared character references instead of the trimmed demo-only copies.
const DEMO_CONTENT_DIRS: Array[String] = [
	"res://content/demo",
	"res://content/examples/support",
	"res://content/examples/valid",
]

const DebugStatePresetsScript := preload("res://scripts/debug/debug_state_presets.gd")
const DebugStateInspectorScript := preload("res://scripts/debug/debug_state_inspector.gd")

const STATE_REPLACE_REASON_MANUAL_LOAD := &"manual_load"
const STATE_REPLACE_REASON_DEBUG_PRESET := &"debug_preset"

var state: GameState = GameState.new()
var content_db: ContentDB = ContentDB.new()
var save_service: SaveService = SaveService.new()
var debug_presets = DebugStatePresetsScript.new()

## Emitted exactly once after the canonical state and its bag ContentDB binding
## are installed. Long-lived consumers must disconnect from `previous` and bind
## to `current` before this ordered notification returns.
signal state_replaced(previous: GameState, current: GameState, reason: StringName)

var _demo_seeded := false
var _inspector: CanvasLayer


func _ready() -> void:
	content_db.load_from_directories(DEMO_CONTENT_DIRS)
	state.bag.set_content_db(content_db)
	_seed_demo_bag_if_empty()
	debug_presets.load_manifest()
	if OS.is_debug_build():
		_install_debug_inspector()


func apply_debug_preset(preset_id: String) -> bool:
	var result: Dictionary = debug_presets.apply_preset(preset_id)
	if not bool(result.get("ok", false)):
		push_warning(
			"Debug preset %s failed: %s" % [preset_id, String(result.get("error", ""))]
		)
		return false
	_demo_seeded = true
	replace_state(result["state"] as GameState, STATE_REPLACE_REASON_DEBUG_PRESET)
	return true


func save_game(slot: int = SaveService.DEFAULT_SLOT) -> bool:
	return save_service.save_game(state, slot)


func load_game(slot: int = SaveService.DEFAULT_SLOT) -> bool:
	var result: Dictionary = save_service.load_game(slot)
	if not result["ok"]:
		push_warning("Save load failed: %s" % ", ".join(result["errors"]))
		return false
	replace_state(result["state"] as GameState, STATE_REPLACE_REASON_MANUAL_LOAD)
	return true


func has_save(slot: int = SaveService.DEFAULT_SLOT) -> bool:
	return save_service.has_save(slot)


## The only live-state replacement path. Installing the canonical reference and
## bag dependency before notifying listeners prevents consumers from observing a
## half-bound state. Phase presentation runs last because it may hide props that
## WorldItemController recreates in its state_replaced handler.
func replace_state(replacement: GameState, reason: StringName) -> bool:
	if replacement == null:
		push_warning("Cannot replace SessionState with a null GameState")
		return false
	var previous := state
	state = replacement
	state.bag.set_content_db(content_db)
	state_replaced.emit(previous, state, reason)
	if has_node("/root/PhaseDirector"):
		# PhaseDirector normally receives the signal above, but explicit rebinding
		# also repairs startup/test ordering where it has not connected yet.
		PhaseDirector.rebind_session_state()
	return true


func _seed_demo_bag_if_empty() -> void:
	if _demo_seeded or not state.bag.is_empty():
		return
	_demo_seeded = true
	state.bag.try_add(&"item.forge_hammer")
	# Kalev starts with his working hammer in hand; stow it from the bag (I).
	state.equip_from_bag(&"right_hand", &"item.forge_hammer")
	# Seized spearhead starts on the anvil; WorldItemController seeds it on forge load.


func _install_debug_inspector() -> void:
	_inspector = DebugStateInspectorScript.new()
	_inspector.name = "DebugStateInspector"
	add_child(_inspector)
	_inspector.configure(debug_presets, Callable(self, "apply_debug_preset"))
