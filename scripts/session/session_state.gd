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

var state: GameState = GameState.new()
var content_db: ContentDB = ContentDB.new()
var save_service: SaveService = SaveService.new()
var debug_presets = DebugStatePresetsScript.new()

signal debug_state_applied(preset_id: StringName)

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
	# Replace state first, then rebuild world props, then apply phase visibility.
	# PhaseDirector must run after WorldItemController syncs on debug_state_applied.
	state = result["state"] as GameState
	state.bag.set_content_db(content_db)
	_demo_seeded = true
	debug_state_applied.emit(StringName(preset_id))
	if has_node("/root/PhaseDirector"):
		PhaseDirector.rebind_session_state()
	return true


func save_game(slot: int = SaveService.DEFAULT_SLOT) -> bool:
	return save_service.save_game(state, slot)


func load_game(slot: int = SaveService.DEFAULT_SLOT) -> bool:
	var result: Dictionary = save_service.load_game(slot)
	if not result["ok"]:
		push_warning("Save load failed: %s" % ", ".join(result["errors"]))
		return false
	_apply_loaded_state(result["state"] as GameState)
	return true


func has_save(slot: int = SaveService.DEFAULT_SLOT) -> bool:
	return save_service.has_save(slot)


func _apply_loaded_state(loaded: GameState) -> void:
	state = loaded
	state.bag.set_content_db(content_db)
	if has_node("/root/PhaseDirector"):
		PhaseDirector.rebind_session_state()


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
