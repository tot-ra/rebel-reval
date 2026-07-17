extends Node

## Session-scoped GameState holder. Inventory and quest flags survive map transitions
## within one play session until save/load lands in P1-007/P1-008.

const DEMO_CONTENT_DIRS: Array[String] = [
	"res://content/demo",
	"res://content/demo/support",
	"res://content/examples/valid",
]

var state: GameState = GameState.new()
var content_db: ContentDB = ContentDB.new()

var _demo_seeded := false


func _ready() -> void:
	content_db.load_from_directories(DEMO_CONTENT_DIRS)
	state.bag.set_content_db(content_db)
	_seed_demo_bag_if_empty()


func _seed_demo_bag_if_empty() -> void:
	if _demo_seeded or not state.bag.is_empty():
		return
	_demo_seeded = true
	state.bag.try_add(&"item.forge_hammer")
	state.bag.try_add(&"item.seized_spearhead")
	# Kalev starts with his working hammer in hand; stow it from the bag (I).
	state.equip_from_bag(&"right_hand", &"item.forge_hammer")
