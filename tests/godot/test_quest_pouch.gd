extends "res://tests/godot/test_case.gd"

const QuestPouchModelScript := preload("res://scripts/inventory/quest_pouch_model.gd")
const QuestPouchControllerScript := preload("res://scripts/inventory/quest_pouch_controller.gd")

const ITEM_HAMMER := &"item.forge_hammer"
const ITEM_SPEARHEAD := &"item.seized_spearhead"
const ITEM_BITTER_BREW := &"item.bitter_brew_work"
const ITEM_WATCH_BUCKLE := &"item.watch_buckle"
const COMMISSION_BITTER_BREW := &"commission.bitter_brew"
const RECORD_HONEST := &"forged.bitter_brew.honest_work"


func test_model_shows_equipped_hammer_without_quest_flag() -> void:
	var state := GameState.new()
	var db := _load_demo_db()
	state.bag.set_content_db(db)
	state.bag.try_add(ITEM_HAMMER)
	state.equip_from_bag(&"right_hand", ITEM_HAMMER)

	var visible: Array[StringName] = QuestPouchModelScript.visible_item_ids(state, db)
	assert_eq(visible.size(), 1)
	assert_eq(visible[0], ITEM_HAMMER)


func test_model_caps_visible_tools_at_three() -> void:
	var state := GameState.new()
	var db := _load_demo_db()
	state.bag.set_content_db(db)
	state.bag.try_add(ITEM_HAMMER)
	state.add_item(ITEM_SPEARHEAD)
	state.bag.try_add(ITEM_SPEARHEAD)
	state.add_forged_record(
		ForgedRecord.new(RECORD_HONEST, COMMISSION_BITTER_BREW, ITEM_BITTER_BREW, &"honest_work")
	)

	var visible: Array[StringName] = QuestPouchModelScript.visible_item_ids(state, db)
	assert_eq(visible.size(), 3)
	assert_true(visible.has(ITEM_HAMMER))
	assert_true(visible.has(ITEM_SPEARHEAD))
	assert_true(visible.has(ITEM_BITTER_BREW))


func test_model_hides_non_pouch_items_and_empty_slots() -> void:
	var state := GameState.new()
	var db := _load_demo_db()
	state.bag.set_content_db(db)
	state.add_item(ITEM_WATCH_BUCKLE)
	state.bag.try_add(ITEM_WATCH_BUCKLE)

	var visible: Array[StringName] = QuestPouchModelScript.visible_item_ids(state, db)
	assert_eq(visible.size(), 0)


func test_hud_refreshes_on_player_spawn() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var player_scene := preload("res://player.tscn")
	var player: Player = player_scene.instantiate()
	tree.root.add_child(player)
	await tree.process_frame

	var controller: Node = player.get_node("QuestPouchController")
	assert_true(controller != null)
	var hud: CanvasLayer = controller.call("get_hud")
	assert_true(hud != null)

	var title := hud.find_child("QuestPouchTitle", true, false) as Label
	assert_true(title != null)
	assert_true(title.visible, "seeded hammer should populate the quest pouch")

	player.queue_free()


func _load_demo_db() -> ContentDB:
	var db := ContentDB.new()
	assert_true(db.load_from_directories(SessionState.DEMO_CONTENT_DIRS))
	return db
