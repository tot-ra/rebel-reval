class_name HingepuuHub
extends CanvasLayer

## A small explorable reflection space layered over the city. The city player stays
## alive and stationary underneath, making the return position exact by construction.
signal reflection_requested
## SW-2: the hero chose to face a guilt phantom (an entry of GuiltPhantoms.phantoms_for).
signal phantom_duel_requested(phantom: Dictionary)

const SAVE_KEY := &"hingepuu.return_context"
const ACTIVE_KEY := &"hingepuu.active"
const BOUNDS := Rect2(96.0, 104.0, 1728.0, 800.0)
const START := Vector2(960.0, 690.0)
const MARKS := [Vector2(960, 300), Vector2(580, 440), Vector2(1340, 440)]
## Where each school's phantom waits, on the ground below the tree (hub logic coordinates).
const PHANTOM_SPOTS: Dictionary = {
	GuiltLedger.SCHOOL_CHURCH: Vector2(400, 640),
	GuiltLedger.SCHOOL_FOLK: Vector2(960, 860),
	GuiltLedger.SCHOOL_CIVIC: Vector2(1520, 640),
}
const REACH := 120.0
const DEFAULT_HINT := "Move: WASD / arrows / left stick   ·   E / A: mark   ·   Esc: return"

var _state: GameState
var _city_actor: Node2D
var _actor_position := START
var _canvas: Control
var _hint: Label
var _active := false
var _phantoms: Array[Dictionary] = []
## True while a phantom duel is open over the hub; the hub then ignores input.
var _duel_open := false
var _phantom_hint_shown := false


func _ready() -> void:
	layer = 24
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false


func enter(state: GameState, actor: Node2D) -> bool:
	if state == null or actor == null or _active:
		return false
	_state = state
	_city_actor = actor
	if state.get_location_state(ACTIVE_KEY) != "true":
		# Persist the return point in GameState's existing JSON-safe location-state bag.
		state.set_location_state(SAVE_KEY, "%f,%f" % [actor.global_position.x, actor.global_position.y])
	_state.set_location_state(ACTIVE_KEY, "true")
	_active = true
	visible = true
	_actor_position = START
	add_to_group("modal_input_overlay")
	refresh_phantoms()
	return true


func leave(actor: Node2D = null) -> bool:
	if not _active or _state == null:
		return false
	var target := actor if actor != null else _city_actor
	if target == null:
		return false
	var parts := String(_state.get_location_state(SAVE_KEY)).split(",")
	if parts.size() == 2:
		target.global_position = Vector2(float(parts[0]), float(parts[1]))
	_state.set_location_state(ACTIVE_KEY, "false")
	_state = null
	_city_actor = null
	_active = false
	_duel_open = false
	_phantoms.clear()
	visible = false
	remove_from_group("modal_input_overlay")
	return true


func restore_after_load(state: GameState, actor: Node2D) -> bool:
	if state == null or actor == null or state.get_location_state(ACTIVE_KEY) != "true":
		return false
	_state = state
	_city_actor = actor
	_active = true
	visible = true
	add_to_group("modal_input_overlay")
	refresh_phantoms()
	return true


func is_active() -> bool:
	return _active


func get_actor_position() -> Vector2:
	return _actor_position


## Re-read the phantoms from the guilt ledger (on enter and after every phantom duel).
func refresh_phantoms() -> void:
	_phantoms = GuiltPhantoms.phantoms_for(_state.guilt if _state != null else null)
	_canvas.queue_redraw()


func phantoms() -> Array[Dictionary]:
	return _phantoms.duplicate()


static func phantom_spot(phantom: Dictionary) -> Vector2:
	return PHANTOM_SPOTS.get(phantom.get("school", &""), START)


## The phantom within reach of `at`, or {}.
func phantom_near(at: Vector2) -> Dictionary:
	for phantom in _phantoms:
		if at.distance_to(phantom_spot(phantom)) < REACH:
			return phantom
	return {}


## Walk the hub actor to a point (tests, scripted beats); clamped to the hub bounds.
func set_actor_position(at: Vector2) -> void:
	_actor_position = Vector2(
		clampf(at.x, BOUNDS.position.x, BOUNDS.end.x), clampf(at.y, BOUNDS.position.y, BOUNDS.end.y)
	)
	_canvas.queue_redraw()


## Face the phantom within reach of the actor. False when none is near or a duel is open.
func request_phantom_duel() -> bool:
	if not _active or _duel_open:
		return false
	var phantom := phantom_near(_actor_position)
	if phantom.is_empty():
		return false
	phantom_duel_requested.emit(phantom.duplicate())
	return true


## The controller marks a phantom duel as open or closed; closing re-reads the phantoms.
func set_duel_open(open: bool) -> void:
	_duel_open = open
	if not open and _active:
		refresh_phantoms()


func is_duel_open() -> bool:
	return _duel_open


func _process(delta: float) -> void:
	if not _active or _duel_open:
		return
	var movement := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	_actor_position += movement * 260.0 * delta
	_actor_position.x = clampf(_actor_position.x, BOUNDS.position.x, BOUNDS.end.x)
	_actor_position.y = clampf(_actor_position.y, BOUNDS.position.y, BOUNDS.end.y)
	_canvas.queue_redraw()
	var near := phantom_near(_actor_position)
	if not near.is_empty():
		_hint.text = "%s  ·  %s guilt  ·  E / A: face it" % [near["name"], near["tier_word"]]
		_phantom_hint_shown = true
	elif _phantom_hint_shown:
		_hint.text = DEFAULT_HINT
		_phantom_hint_shown = false
	if Input.is_action_just_pressed("interact"):
		if not near.is_empty():
			request_phantom_duel()
		elif _actor_position.distance_to(MARKS[0]) < REACH:
			reflection_requested.emit()
		elif _actor_position.distance_to(MARKS[1]) < REACH or _actor_position.distance_to(MARKS[2]) < REACH:
			_hint.text = "A mark stirs in the branches. Its meaning will become clear in time."
		else:
			leave()
	elif Input.is_action_just_pressed("ui_cancel"):
		leave()


func _draw_hub() -> void:
	if not _active:
		return
	var size := _canvas.size
	_canvas.draw_rect(Rect2(Vector2.ZERO, size), Color("101820"), true)
	_canvas.draw_rect(Rect2(0, size.y * 0.69, size.x, size.y * 0.31), Color("182322"), true)
	# A symbolic folklore image, not a historical reconstruction or new asset.
	var trunk := Vector2(size.x * 0.5, size.y * 0.56)
	_canvas.draw_line(trunk, Vector2(size.x * 0.5, size.y * 0.13), Color("806c45"), 42.0, true)
	for point in [Vector2(size.x * 0.25, size.y * 0.22), Vector2(size.x * 0.76, size.y * 0.19), Vector2(size.x * 0.36, size.y * 0.34), Vector2(size.x * 0.67, size.y * 0.36)]:
		_canvas.draw_line(trunk, point, Color("806c45"), 18.0, true)
	for mark in MARKS:
		var point: Vector2 = mark * size / Vector2(1920.0, 1080.0)
		_canvas.draw_circle(point, 24.0, Color("d3b76b"))
		_canvas.draw_circle(point, 12.0, Color("26332c"))
	_draw_phantoms(size)
	_canvas.draw_circle(_actor_position * size / Vector2(1920.0, 1080.0), 14.0, Color("e9e2cc"))


## Pale wisps, larger and denser by tier. Procedural only (asset freeze P0-040).
func _draw_phantoms(size: Vector2) -> void:
	var ratio := size / Vector2(1920.0, 1080.0)
	for phantom in _phantoms:
		var point := phantom_spot(phantom) * ratio
		var tier := int(phantom.get("tier", 1))
		var radius := 18.0 + 8.0 * tier
		for ring in 3:
			var alpha := 0.12 + 0.08 * tier - 0.05 * ring
			_canvas.draw_circle(point - Vector2(0, ring * radius * 0.5), radius * (1.0 - 0.22 * ring), Color(0.72, 0.8, 0.9, alpha))
		_canvas.draw_circle(point - Vector2(radius * 0.25, radius * 0.9), 3.0, Color("101820"))
		_canvas.draw_circle(point - Vector2(-radius * 0.25, radius * 0.9), 3.0, Color("101820"))


func _build_ui() -> void:
	_canvas = Control.new()
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_hub)
	add_child(_canvas)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 12)
	_canvas.add_child(column)
	var title := Label.new()
	title.text = "HINGEPUU  ·  THE SOUL-TREE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	column.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	_hint = Label.new()
	_hint.text = DEFAULT_HINT
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_hint)
