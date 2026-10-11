extends RichTextLabel

## One start-screen entry in the Escape-menu skin (R-1799): dark plate, bronze focus bar and the
## pause_menu_style.gd type scale. Hover moves focus, so mouse, keyboard and gamepad share a single
## highlight. Subclasses override activate().
## WHY a RichTextLabel and gui_input (not a Button): the packaged walkthrough, platform smoke and
## capture hosts press Start by emitting gui_input with a mouse click, which a Button would ignore.

const MenuStyle := preload("res://scripts/ui/pause_menu_style.gd")

const FONT_SIZE := 18
const TEXT_COLOR := Color("e7ddc9")
const ACTIVE_COLOR := Color("fff0cb")


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	scroll_active = false
	autowrap_mode = TextServer.AUTOWRAP_OFF
	horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_theme_font_size_override("normal_font_size", FONT_SIZE)
	add_theme_color_override("default_color", TEXT_COLOR)
	add_theme_stylebox_override("normal", MenuStyle.panel(Color(0.08, 0.09, 0.09, 0.7)))
	var focus := MenuStyle.panel(Color(0, 0, 0, 0))
	UiFocusTheme.apply_button_focus_style(focus, MenuStyle.GOLD)
	add_theme_stylebox_override("focus", focus)
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
	focus_entered.connect(_set_active.bind(true))
	focus_exited.connect(_set_active.bind(false))


## Override in each entry.
func activate() -> void:
	pass


## Shared by Continue and Load: install the save and go to its recorded scene and spawn.
func resume_save(slot: int) -> bool:
	if not SessionState.load_game(slot):
		push_warning("Failed to load save slot %d" % slot)
		return false
	var state: GameState = SessionState.state
	DoorNavigator.go_to_scene(state.player.location_id, state.player.spawn_id)
	return true


## Hidden entries leave the focus ring; main_menu.gd restacks the visible ones.
func set_available(available: bool) -> void:
	visible = available
	focus_mode = Control.FOCUS_ALL if available else Control.FOCUS_NONE


func _on_gui_input(event: InputEvent) -> void:
	if _is_activate_event(event):
		activate()


func _on_mouse_entered() -> void:
	if focus_mode != Control.FOCUS_NONE:
		grab_focus()


func _set_active(active: bool) -> void:
	add_theme_color_override("default_color", ACTIVE_COLOR if active else TEXT_COLOR)
	# Plate brightens like the Escape menu's hover/pressed buttons.
	var fill := Color("33322b") if active else Color(0.08, 0.09, 0.09, 0.7)
	add_theme_stylebox_override("normal", MenuStyle.panel(fill))


func _is_activate_event(event: InputEvent) -> bool:
	return (
		event.is_action_pressed(&"ui_accept")
		or (
			event is InputEventMouseButton
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
			and (event as InputEventMouseButton).pressed
		)
	)
