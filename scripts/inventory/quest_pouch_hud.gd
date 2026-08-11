class_name QuestPouchHud
extends CanvasLayer

## Always-on HUD strip for at most three quest tools (P2-015). Separate from the
## grid satchel opened with I; uses the same oak/brass tokens as InventoryUiTheme.

const InventoryUiThemeScene := preload("res://scripts/inventory/inventory_ui_theme.gd")
const QuestPouchModelScript := preload("res://scripts/inventory/quest_pouch_model.gd")
const SLOT_SIZE := 44
const SLOT_GAP := 6
const PANEL_MARGIN := 20.0

var _content_db: ContentDB
var _slot_buttons: Array[Button] = []
var _title_label: Label


func configure(content_db: ContentDB) -> void:
	_content_db = content_db
	if is_node_ready():
		_refresh([])


func _ready() -> void:
	layer = 9
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_refresh([])


func refresh(item_ids: Array[StringName]) -> void:
	if not is_node_ready():
		return
	_refresh(item_ids)


func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.name = "QuestPouchPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	panel.offset_left = PANEL_MARGIN
	panel.offset_top = PANEL_MARGIN
	panel.offset_right = PANEL_MARGIN + 180
	panel.offset_bottom = PANEL_MARGIN + 88
	InventoryUiThemeScene.apply_panel(panel)
	add_child(panel)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(layout)

	_title_label = Label.new()
	_title_label.name = "QuestPouchTitle"
	_title_label.text = "Tools"
	InventoryUiThemeScene.apply_caption(_title_label)
	layout.add_child(_title_label)

	var row := HBoxContainer.new()
	row.name = "QuestPouchSlots"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", SLOT_GAP)
	layout.add_child(row)

	_slot_buttons.clear()
	for index in QuestPouchModelScript.MAX_VISIBLE_SLOTS:
		var button := Button.new()
		button.name = "QuestPouchSlot%d" % index
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		button.toggle_mode = false
		button.disabled = true
		_apply_empty_slot_style(button)
		row.add_child(button)
		_slot_buttons.append(button)


func _refresh(item_ids: Array[StringName]) -> void:
	if _slot_buttons.is_empty():
		return
	_title_label.visible = not item_ids.is_empty()
	for index in _slot_buttons.size():
		var button := _slot_buttons[index]
		if index >= item_ids.size():
			_apply_empty_slot(button)
			continue
		_apply_item_slot(button, item_ids[index])


func _apply_empty_slot(button: Button) -> void:
	button.disabled = true
	button.text = ""
	button.icon = null
	button.tooltip_text = "Empty tool slot"
	_apply_empty_slot_style(button)


func _apply_item_slot(button: Button, item_id: StringName) -> void:
	button.disabled = false
	var record: Dictionary = {}
	if _content_db != null:
		record = _content_db.get_item(item_id)
	var name_text := String(record.get("name", String(item_id)))
	button.tooltip_text = name_text
	button.text = _short_label(name_text)

	var icon_path := String(record.get("icon", ""))
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		var icon_tex: Texture2D = ResourceLoader.load(icon_path) as Texture2D
		if icon_tex != null:
			button.icon = icon_tex
			button.expand_icon = true
			button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
			button.text = ""
		else:
			button.icon = null
	else:
		button.icon = null

	var category := String(record.get("category", ""))
	var tint: Color = InventoryUiThemeScene.CATEGORY_COLORS.get(
		category, InventoryUiThemeScene.SLOT_FILLED
	)
	_apply_filled_slot_style(button, tint)


static func _short_label(name_text: String) -> String:
	var words := name_text.strip_edges().split(" ", false)
	if words.is_empty():
		return "?"
	if words.size() == 1:
		return words[0].substr(0, mini(4, words[0].length()))
	return "%s %s" % [words[0].substr(0, 1), words[1].substr(0, mini(3, words[1].length()))]


static func _apply_empty_slot_style(button: Button) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = InventoryUiThemeScene.SLOT_EMPTY
	style.border_color = InventoryUiThemeScene.PANEL_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("disabled", style)


static func _apply_filled_slot_style(button: Button, fill: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = InventoryUiThemeScene.BRASS
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_stylebox_override("disabled", style)
