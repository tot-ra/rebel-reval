extends "res://tests/godot/test_case.gd"

const ITEM_SPEARHEAD := &"item.seized_spearhead"
const EquipmentSilhouetteScene := preload("res://scripts/inventory/equipment_silhouette.gd")
const InventoryUiThemeScene := preload("res://scripts/inventory/inventory_ui_theme.gd")


func test_overlay_shows_numeric_meters_and_readable_labels() -> void:
	var overlay := InventoryOverlay.new()
	var bag := InventoryBag.new()
	var db := ContentDB.new()
	db.load_from_directories(["res://content/examples/valid", "res://content/demo"])
	bag.set_content_db(db)
	bag.try_add(ITEM_SPEARHEAD)

	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(overlay)
	overlay.configure(bag, db)
	overlay.configure_state(GameState.new())
	overlay.open()

	assert_true(overlay._weight_value != null, "weight value label must exist")
	assert_true(overlay._volume_value != null, "volume value label must exist")
	assert_true(String(overlay._weight_value.text).contains("/"), "weight must show current / max")
	assert_true(String(overlay._weight_value.text).ends_with("kg"), "weight unit must be kg")
	assert_true(String(overlay._volume_value.text).contains("cells"), "volume must show cell count")

	var placement := bag.get_placement_at_cell(0, 0)
	var short := overlay.item_short_label(placement)
	assert_true(short.length() >= 4, "short label must stay readable")
	assert_false(short.begins_with("Sei"), "must not stump long names to Sei")
	assert_true(short.to_lower().begins_with("spear"), "seized spearhead should show spear stem")

	var close_button := overlay.find_child("CloseButton", true, false) as Button
	assert_true(close_button != null, "mouse users need a Close button")
	close_button.pressed.emit()
	assert_false(overlay.is_open())

	overlay.queue_free()


func test_short_label_for_forge_hammer_keeps_both_words() -> void:
	var overlay := InventoryOverlay.new()
	var record := {"name": "Forge hammer", "category": "weapon"}
	var short: String = overlay._short_label(record, 1)
	assert_true(short.to_lower().contains("forg") or short.to_lower().contains("hamm"))
	assert_true(short.length() >= 4)


func test_overlay_uses_historical_satchel_theme() -> void:
	var overlay := InventoryOverlay.new()
	var bag := InventoryBag.new()
	var db := ContentDB.new()
	db.load_from_directories(["res://content/examples/valid", "res://content/demo"])
	bag.set_content_db(db)

	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(overlay)
	overlay.configure(bag, db)
	overlay.open()

	var title := overlay.find_child("BagTitle", true, false) as Label
	assert_true(title != null, "title label must exist")
	assert_eq(title.text, "Satchel")
	assert_eq(
		title.get_theme_color("font_color"),
		InventoryUiThemeScene.BRASS_BRIGHT,
		"title should use brass parchment gold from the Reval HUD family"
	)

	var panel := overlay.find_child("BagPanel", true, false) as PanelContainer
	assert_true(panel != null, "bag panel must exist")
	var panel_style := panel.get_theme_stylebox("panel") as StyleBoxFlat
	assert_true(panel_style != null, "panel must use a flat stylebox")
	assert_eq(panel_style.bg_color, InventoryUiThemeScene.PANEL_BG)
	assert_eq(panel_style.border_color, InventoryUiThemeScene.PANEL_BORDER)

	assert_true(overlay._cell_buttons.size() > 0, "grid cells must exist")
	var empty_style := overlay._cell_buttons[0].get_theme_stylebox("normal") as StyleBoxFlat
	assert_true(empty_style != null, "cells must use leather styleboxes")
	assert_eq(empty_style.bg_color, InventoryUiThemeScene.LEATHER_EMPTY)



func test_overlay_exposes_rich_equipment_paper_doll_and_ornament() -> void:
	var overlay := InventoryOverlay.new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(overlay)
	overlay.open()

	var ornament := overlay.find_child("OrnamentFrame", true, false)
	assert_true(ornament != null, "bag panel needs scalable ornamental brasswork")
	var equipment_panel := overlay.find_child("EquipmentPanel", true, false) as PanelContainer
	assert_true(equipment_panel != null, "paper doll needs a dedicated framed equipment panel")

	var expected_slots: Array[StringName] = [
		&"head", &"back", &"body", &"arms", &"belt", &"legs", &"feet", &"left_hand", &"right_hand"
	]
	assert_eq(EquipmentSilhouetteScene.SLOT_ORDER, expected_slots)
	for slot: StringName in expected_slots:
		assert_true(overlay._silhouette._slot_rects.has(slot), "%s socket must be visible" % slot)
		var rect: Rect2 = overlay._silhouette._slot_rects[slot]
		assert_true(rect.size.x > 30.0 and rect.size.y > 25.0, "%s socket must remain usable" % slot)

	overlay.queue_free()
