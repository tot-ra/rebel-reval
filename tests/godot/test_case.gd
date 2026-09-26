extends RefCounted

const ITEM_FORGE_HAMMER := &"item.forge_hammer"
const SENTINEL_ENCOUNTER := &"encounter.watch_checkpoint"
const SENTINEL_MECHANISM := &"mechanism.bitter_brew_crisis"
const AUTOLOAD_ROOT_NAMES: Array[String] = [
	"CursorService",
	"DisplayWindow",
	"DoorNavigator",
	"MusicDirector",
	"PhaseDirector",
	"SessionState",
	"UserSettings",
]
const ISOLATE_REASON := &"test_isolate"

var _failures: Array[String] = []
var _harness_root_baseline: Array[Node] = []

func before_each() -> void:
	_failures.clear()

func after_each() -> void:
	# WHY: file-level isolate_session_globals() is not the only backstop.
	# A test that assigned a narrower ContentDB must leave the demo corpus
	# installed even if a later file skips isolation.
	restore_demo_session()


## Snapshot autoload/root children once so later files cannot inherit leftover
## hosts. Call from the harness before the first test file, not after mounting
## fixtures.
func snapshot_harness_root() -> void:
	_harness_root_baseline.clear()
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	for child: Node in tree.root.get_children():
		_harness_root_baseline.append(child)


## Restore InputMap, SessionState, DoorNavigator, and leaked root nodes.
## Use between test files. Do not call after adding a fixture you still need.
func isolate_session_globals() -> void:
	_release_held_actions()
	var bindings: Variant = load("res://scripts/settings/input_binding_settings.gd")
	bindings.default_settings().apply_to_input_map()
	_free_leaked_root_nodes()
	restore_demo_session(true)
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root.get_node_or_null("DoorNavigator") != null:
		DoorNavigator.load_manifest(true)


## Reload the demo corpus when a prior file left a narrower ContentDB loaded,
## then install a fresh GameState with the starter hammer.
func restore_demo_session(force_reload: bool = false) -> bool:
	if SessionState.content_db == null:
		SessionState.content_db = ContentDB.new()
	if force_reload or not demo_content_ready():
		var db := ContentDB.new()
		if not db.load_from_directories(SessionState.DEMO_CONTENT_DIRS):
			return false
		SessionState.content_db = db
	var fresh := GameState.new()
	if not SessionState.replace_state(fresh, ISOLATE_REASON):
		SessionState.state = fresh
		SessionState.state.bag.set_content_db(SessionState.content_db)
	if SessionState.state.bag.find_placement(ITEM_FORGE_HAMMER) == null:
		if SessionState.state.bag.try_add(ITEM_FORGE_HAMMER) != InventoryBag.AddResult.OK:
			return false
	if SessionState.state.equipped_item(&"right_hand") != ITEM_FORGE_HAMMER:
		if not SessionState.state.equipped_item(&"right_hand").is_empty():
			if not SessionState.state.unequip_to_bag(&"right_hand"):
				return false
		if not SessionState.state.equip_from_bag(&"right_hand", ITEM_FORGE_HAMMER):
			return false
	return true


func demo_content_ready() -> bool:
	var db: ContentDB = SessionState.content_db
	if db == null or not db.is_loaded():
		return false
	return (
		db.has_record(ITEM_FORGE_HAMMER)
		and db.has_record(SENTINEL_ENCOUNTER)
		and db.has_record(SENTINEL_MECHANISM)
	)


func _release_held_actions() -> void:
	for action: StringName in InputMap.get_actions():
		if Input.is_action_pressed(action):
			Input.action_release(action)


func _free_leaked_root_nodes() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var leaked: Array[Node] = []
	for child: Node in tree.root.get_children():
		if _is_protected_root_child(child):
			continue
		leaked.append(child)
	for child: Node in leaked:
		if is_instance_valid(child):
			child.free()


func _is_protected_root_child(child: Node) -> bool:
	if child == null:
		return true
	if not _harness_root_baseline.is_empty():
		return _harness_root_baseline.has(child)
	return AUTOLOAD_ROOT_NAMES.has(child.name)


func assert_true(condition: bool, message: String = "Expected condition to be true") -> void:
	if not condition:
		fail(message)

func assert_false(condition: bool, message: String = "Expected condition to be false") -> void:
	if condition:
		fail(message)

func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if actual != expected:
		var detail := "Expected <%s> but got <%s>" % [str(expected), str(actual)]
		fail(_format_message(message, detail))

func assert_almost_eq(
	actual: float, expected: float, tolerance: float, message: String = ""
) -> void:
	if absf(actual - expected) > tolerance:
		var detail := (
			"Expected <%s> +/- <%s> but got <%s>"
			% [str(expected), str(tolerance), str(actual)]
		)
		fail(_format_message(message, detail))

func assert_ne(actual: Variant, expected: Variant, message: String = "") -> void:
	if actual == expected:
		var detail := "Expected value different from <%s>" % str(expected)
		fail(_format_message(message, detail))

func assert_array_contains(values: Array, expected: Variant, message: String = "") -> void:
	if not values.has(expected):
		var detail := "Expected array to contain <%s>; values were <%s>" % [str(expected), str(values)]
		fail(_format_message(message, detail))

func fail(message: String) -> void:
	_failures.append(message)

func _get_failures() -> Array[String]:
	return _failures.duplicate()

func _format_message(message: String, detail: String) -> String:
	if message.is_empty():
		return detail
	return "%s - %s" % [message, detail]
