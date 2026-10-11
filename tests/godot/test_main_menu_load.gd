extends "res://tests/godot/test_case.gd"

const MainMenuScene := preload("res://scenes/menu/main_menu.tscn")
const SaveListOverlay := preload("res://scenes/menu/save_list_overlay.gd")
const PauseMenuStyle := preload("res://scripts/ui/pause_menu_style.gd")

var _original_save_service: SaveService
var _save_directory := ""


func before_each() -> void:
	_original_save_service = SessionState.save_service
	_save_directory = _temp_dir("main_menu_load")
	var service := SaveService.new()
	service.save_directory = _save_directory
	SessionState.save_service = service


func after_each() -> void:
	SessionState.save_service = _original_save_service
	if not _save_directory.is_empty():
		_remove_tree(_save_directory)
	_save_directory = ""
	super.after_each()

func test_load_label_hidden_without_saves() -> void:
	var menu := MainMenuScene.instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(menu)
	var load_label := menu.get_node("Load label") as Control
	assert_false(load_label.visible)
	menu.free()


func test_load_label_visible_when_save_exists() -> void:
	var state := GameState.new()
	state.player.location_id = &"forge"
	state.set_phase(GameState.PHASE_PROLOGUE_DAY)
	assert_true(SessionState.save_service.save_game(state))

	var menu := MainMenuScene.instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(menu)
	var load_label := menu.get_node("Load label") as Control
	assert_true(load_label.visible)
	menu.free()


func test_load_label_focusable_when_save_exists() -> void:
	var state := GameState.new()
	state.player.location_id = &"forge"
	state.set_phase(GameState.PHASE_PROLOGUE_DAY)
	assert_true(SessionState.save_service.save_game(state))

	var menu := MainMenuScene.instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(menu)
	var start := menu.get_node("Start label") as Control
	var load_label := menu.get_node("Load label") as Control
	var credits := menu.get_node("Credits label") as Control

	assert_true(load_label.visible)
	assert_eq(load_label.focus_mode, Control.FOCUS_ALL)
	# R-1799: the Escape-menu bronze focus bar replaced the empty focus box.
	var focus := load_label.get_theme_stylebox("focus") as StyleBoxFlat
	assert_true(focus != null)
	assert_eq(focus.border_color, PauseMenuStyle.GOLD)
	assert_true(focus.border_width_top >= 1)
	assert_eq(start.focus_neighbor_bottom, NodePath("../Load label"))
	assert_eq(load_label.focus_neighbor_top, NodePath("../Start label"))
	assert_eq(load_label.focus_neighbor_bottom, NodePath("../Credits label"))
	assert_eq(credits.focus_neighbor_top, NodePath("../Load label"))

	menu.free()


func test_focus_ring_skips_hidden_load_label() -> void:
	var menu := MainMenuScene.instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(menu)
	var start := menu.get_node("Start label") as Control
	var load_label := menu.get_node("Load label") as Control
	var credits := menu.get_node("Credits label") as Control
	assert_eq(load_label.focus_mode, Control.FOCUS_NONE)
	assert_eq(start.focus_neighbor_bottom, NodePath("../Credits label"))
	assert_eq(credits.focus_neighbor_top, NodePath("../Start label"))
	menu.free()


func test_continue_hidden_without_saves_and_start_leads() -> void:
	var menu := MainMenuScene.instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(menu)
	var continue_label := menu.get_node("Continue label") as Control
	var start := menu.get_node("Start label") as Control
	var exit_label := menu.get_node("Exit label") as Control
	assert_false(continue_label.visible)
	assert_eq(continue_label.focus_mode, Control.FOCUS_NONE)
	assert_eq(menu.visible_entries()[0], start)
	assert_eq(start.focus_neighbor_top, NodePath("../Exit label"))
	assert_eq(exit_label.focus_neighbor_bottom, NodePath("../Start label"))
	menu.free()


func test_continue_leads_and_targets_latest_save() -> void:
	var state := GameState.new()
	state.player.location_id = &"forge"
	assert_true(SessionState.save_service.save_game(state, 1))
	# Continue must follow list_saves() order (newest first), whatever the timestamps resolve to.
	var newer := GameState.new()
	newer.player.location_id = &"reval_east"
	assert_true(SessionState.save_service.save_game(newer, 3))
	var saves := SessionState.list_saves()

	var menu := MainMenuScene.instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(menu)
	var continue_label := menu.get_node("Continue label") as Control
	var start := menu.get_node("Start label") as Control
	var exit_label := menu.get_node("Exit label") as Control
	assert_true(continue_label.visible)
	assert_eq(continue_label.focus_mode, Control.FOCUS_ALL)
	assert_eq(continue_label.latest_slot(), int(saves[0]["slot"]))
	assert_eq(menu.visible_entries()[0], continue_label)
	assert_eq(continue_label.focus_neighbor_bottom, NodePath("../Start label"))
	assert_eq(start.focus_neighbor_top, NodePath("../Continue label"))
	assert_eq(exit_label.focus_neighbor_bottom, NodePath("../Continue label"))
	assert_true(continue_label.position.y < start.position.y)
	menu.free()


func test_entries_are_left_aligned_in_one_column() -> void:
	var menu := MainMenuScene.instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(menu)
	var entries: Array[Control] = menu.visible_entries()
	assert_true(entries.size() >= 4)
	for index in entries.size():
		var entry := entries[index] as RichTextLabel
		assert_eq(entry.position.x, entries[0].position.x)
		assert_eq(entry.horizontal_alignment, HORIZONTAL_ALIGNMENT_LEFT)
		if index > 0:
			assert_true(entry.position.y > entries[index - 1].position.y)
	menu.free()


func test_hover_moves_focus_and_brightens_entry() -> void:
	var menu := MainMenuScene.instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(menu)
	var credits := menu.get_node("Credits label") as RichTextLabel
	credits.mouse_entered.emit()
	assert_true(credits.has_focus())
	assert_eq(credits.get_theme_color("default_color"), Color("fff0cb"))
	var library := menu.get_node("Assets library label") as RichTextLabel
	library.mouse_entered.emit()
	assert_false(credits.has_focus())
	assert_eq(credits.get_theme_color("default_color"), Color("e7ddc9"))
	menu.free()


func test_save_list_overlay_fills_menu_and_centres_panel() -> void:
	var menu := MainMenuScene.instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(menu)

	var overlay: Control = SaveListOverlay.new()
	menu.add_child(overlay)

	assert_eq(overlay.anchor_left, 0.0)
	assert_eq(overlay.anchor_top, 0.0)
	assert_eq(overlay.anchor_right, 1.0)
	assert_eq(overlay.anchor_bottom, 1.0)
	var panel := overlay.get_node("Panel") as PanelContainer
	assert_eq(panel.anchor_left, 0.5)
	assert_eq(panel.anchor_top, 0.5)
	assert_eq(panel.anchor_right, 0.5)
	assert_eq(panel.anchor_bottom, 0.5)

	menu.free()
func test_save_list_overlay_lists_every_slot() -> void:
	var state := GameState.new()
	state.player.location_id = &"reval_east"
	state.set_phase(GameState.PHASE_INVESTIGATION_NIGHT)
	assert_true(SessionState.save_service.save_game(state, 2))

	var menu := MainMenuScene.instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(menu)

	var overlay: Control = SaveListOverlay.new()
	menu.add_child(overlay)
	await (Engine.get_main_loop() as SceneTree).process_frame

	# Why: %UniqueName needs owner in-tree. A runtime-built overlay has none.
	var entry_list := overlay.find_child("EntryList", true, false) as VBoxContainer
	assert_eq(entry_list.get_child_count(), 1)
	var load_btn := entry_list.get_child(0).get_node("HBox/LoadBtn") as Button
	assert_true(load_btn != null)

	menu.free()


func _temp_dir(label: String) -> String:
	return "user://test_saves/%s_%d" % [label, Time.get_ticks_usec()]


func _remove_tree(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		DirAccess.remove_absolute(path)
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry != "." and entry != "..":
			var child := "%s/%s" % [path, entry]
			if DirAccess.dir_exists_absolute(child):
				_remove_tree(child)
			else:
				DirAccess.remove_absolute(child)
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)
