extends "res://tests/godot/test_case.gd"

## R-1800: journal, inventory, spellforge and controls share the Escape-menu skin
## and pick up the enhanced-focus setting each time they open.

const MenuStyle := preload("res://scripts/ui/pause_menu_style.gd")
const SettingsScript := preload("res://scripts/settings/gameplay_accessibility_settings.gd")
const JournalScript := preload("res://scripts/journal/journal_overlay.gd")
const SpellforgeScript := preload("res://scripts/magic/spellforge_hud.gd")
const SpellforgeModelScript := preload("res://scripts/magic/spellforge_model.gd")
const ControlsScript := preload("res://scripts/ui/controls_overlay.gd")
const CONTENT_DIRS: Array[String] = ["res://content/examples/valid", "res://content/demo"]


func test_each_overlay_uses_the_shared_panel_scrim_and_theme() -> void:
	_set_enhanced_focus(false)
	for overlay: CanvasLayer in _open_overlays():
		var root := overlay.get_child(0) as Control
		if overlay is SpellforgeHud:
			root = overlay.find_child("SpellforgeRoot", false, false) as Control
		assert_true(root != null and root.theme != null, "%s root has the shared theme" % overlay.name)
		assert_eq(root.theme.default_font_size, 16)
		var panel := _first_panel(root)
		assert_true(panel != null, "%s has a panel" % overlay.name)
		var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
		assert_true(style != null)
		assert_eq(style.bg_color, MenuStyle.OVERLAY_FILL)
		var dim := _first_dim(root)
		assert_true(dim != null)
		assert_eq(dim.color, MenuStyle.SCRIM)
		overlay.queue_free()


func test_reopening_an_overlay_applies_enhanced_focus() -> void:
	_set_enhanced_focus(false)
	var overlays := _open_overlays()
	_set_enhanced_focus(true)
	for overlay: CanvasLayer in overlays:
		overlay.call("open")
		var root := overlay.get_child(0) as Control
		if overlay is SpellforgeHud:
			root = overlay.find_child("SpellforgeRoot", false, false) as Control
		var focus := root.theme.get_stylebox("focus", "Button") as StyleBoxFlat
		assert_eq(focus.border_width_left, UiFocusTheme.focus_border_width())
		assert_eq(focus.border_width_left, 4, "%s reopened with the wide focus ring" % overlay.name)
		overlay.queue_free()
	_set_enhanced_focus(false)


func _open_overlays() -> Array[CanvasLayer]:
	var state := GameState.new()
	var db := ContentDB.new()
	assert_true(db.load_from_directories(CONTENT_DIRS))
	var journal: CanvasLayer = JournalScript.new()
	journal.name = "Journal"
	journal.configure(state, db)
	var bag := InventoryBag.new()
	bag.set_content_db(db)
	var inventory := InventoryOverlay.new()
	inventory.name = "Inventory"
	var model := SpellforgeModelScript.new() as SpellforgeModel
	model.configure(state, db)
	var spellforge: CanvasLayer = SpellforgeScript.new()
	spellforge.name = "Spellforge"
	spellforge.configure(model)
	var controls: CanvasLayer = ControlsScript.new()
	controls.name = "Controls"
	controls.configure(UserSettings)
	var overlays: Array[CanvasLayer] = [journal, inventory, spellforge, controls]
	for overlay in overlays:
		_tree().root.add_child(overlay)
	inventory.configure(bag, db)
	inventory.configure_state(state)
	for overlay in overlays:
		overlay.call("open")
	return overlays


func _first_panel(node: Node) -> PanelContainer:
	for child in node.get_children():
		if child is PanelContainer:
			return child
		var found := _first_panel(child)
		if found != null:
			return found
	return null


func _first_dim(node: Node) -> ColorRect:
	for child in node.get_children():
		if child is ColorRect:
			return child
	return null


func _set_enhanced_focus(enabled: bool) -> void:
	var gameplay = SettingsScript.default_settings()
	gameplay.enhanced_focus_contrast = enabled
	UserSettings.apply_gameplay_accessibility_settings(gameplay, false)


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree
