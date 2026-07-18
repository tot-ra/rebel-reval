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

var state: GameState = GameState.new()
var content_db: ContentDB = ContentDB.new()
var save_service: SaveService = SaveService.new()

var _demo_seeded := false


func _ready() -> void:
	content_db.load_from_directories(DEMO_CONTENT_DIRS)
	state.bag.set_content_db(content_db)
	state.phase_changed.connect(_on_phase_changed)
	_seed_demo_bag_if_empty()


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
	state.phase_changed.connect(_on_phase_changed)


func _on_phase_changed(_previous: StringName, _next: StringName) -> void:
	# Phase boundaries are the slice autosave hook until P1-017 owns richer transitions.
	if not save_service.save_game(state):
		push_warning("Phase-boundary autosave failed for phase %s" % String(_next))


func _seed_demo_bag_if_empty() -> void:
	if _demo_seeded or not state.bag.is_empty():
		return
	_demo_seeded = true
	state.bag.try_add(&"item.forge_hammer")
	# Kalev starts with his working hammer in hand; stow it from the bag (I).
	state.equip_from_bag(&"right_hand", &"item.forge_hammer")
	# Seized spearhead starts on the anvil; WorldItemController seeds it on forge load.
