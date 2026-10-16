class_name SpiritReadingPanel
extends CanvasLayer
## SS-4 (ADR 0041 section 4): reading a soul. While spirit sight is open, resting the mouse
## (or, on a gamepad or with a captured mouse, the camera centre) on a being with a full
## aura for SpiritReading.FOCUS_DELAY opens this card: the seven soul lights bottom-up with
## glyph, aspect name, guarded element and level pips, the strongest and closed lights and
## clarity in words. The hero's awareness light adds temperament, closed-mask reveal and a
## topic hint (SpiritReading.read). Mounted by SpiritSight next to its aura manager.
## Nothing is saved; the card closes when sight closes.

const UiStyle := preload("res://scripts/ui/pause_menu_style.gd")
## Right-hand screen band kept free for MinimapHud (map block + margin + rim overhang).
const MINIMAP_CLEARANCE := 390.0
const ROW_HEIGHT := 22.0
const PIP_COUNT := 5

var manager: SpiritAuraManager
## Spirit-sight controller (parent when mounted); supplies `duel_for` and the content DB.
var sight: Node
var state: GameState
var content_db: ContentDB
var follow_session := true
## Fixtures: a camera and a screen point instead of the viewport camera and the pointer.
var camera_override: Camera3D
var focus_point_override: Variant = null
## Last pointing device: true = mouse cursor, false = camera centre (gamepad stick aim).
var use_pointer := true

## The being whose soul the card shows (null when closed) and the one under the focus.
var target: Node3D
var reading: Dictionary = {}
var _candidate: Node3D
var _dwell := 0.0
var _lost := 0.0

var _panel: PanelContainer
var _title: Label
var _rows: HFlowContainer
var _summary: Label


func _init() -> void:
	layer = 19
	name = "SpiritReadingPanel"
	_panel = PanelContainer.new()
	var style := UiStyle.overlay_panel_style()
	style.set_corner_radius_all(4)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	_panel.add_theme_stylebox_override("panel", style)
	# Top strip, read left to right. WHY: the minimap owns the top-right corner (it used to
	# hide this card), so the strip stops short of it; the Tools pouch moved to the bottom.
	_panel.anchor_left = 0.0
	_panel.anchor_right = 1.0
	_panel.offset_left = 20.0
	_panel.offset_right = -MINIMAP_CLEARANCE
	_panel.offset_top = 20.0
	_panel.offset_bottom = 20.0
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_panel.add_child(box)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 18)
	box.add_child(_title)
	# Lights flow left to right and wrap when the strip is narrow.
	_rows = HFlowContainer.new()
	_rows.add_theme_constant_override("h_separation", 20)
	_rows.add_theme_constant_override("v_separation", 2)
	box.add_child(_rows)
	_summary = Label.new()
	_summary.add_theme_font_size_override("font_size", 14)
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_summary)
	_panel.visible = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if sight == null and get_parent() != null and &"blend" in get_parent():
		sight = get_parent()
	if manager == null and sight != null:
		manager = sight.get_node_or_null("SpiritAuras") as SpiritAuraManager


func _input(event: InputEvent) -> void:
	# Track the pointing device without consuming the event.
	if event is InputEventMouseMotion:
		use_pointer = true
	elif event is InputEventJoypadMotion or event is InputEventJoypadButton:
		use_pointer = false


func _process(delta: float) -> void:
	tick(delta)


func is_open() -> bool:
	return _panel.visible


## One focus step: pick the focused being, run the dwell timer, refresh the open card.
func tick(delta: float) -> void:
	_read_session()
	if not _sight_open():
		close()
		return
	var bodies := _focusable()
	var focused := SpiritReading.pick_focus(
		_camera(), focus_point(), bodies, SpiritReading.FOCUS_RADIUS_PX, _chest_heights(bodies)
	)
	if focused != _candidate:
		_candidate = focused
		_dwell = 0.0
	if focused != null:
		_dwell += delta
		_lost = 0.0
		if focused != target and _dwell >= SpiritReading.FOCUS_DELAY - 0.0001:
			_open(focused)
	elif target != null:
		_lost += delta
		if _lost >= SpiritReading.LOST_GRACE:
			close()
	if target != null and not is_instance_valid(target):
		close()
	elif target != null:
		_refresh()


func close() -> void:
	target = null
	_candidate = null
	_dwell = 0.0
	_lost = 0.0
	reading = {}
	_panel.visible = false


## Mouse cursor, or the viewport centre for a gamepad or a captured mouse.
func focus_point() -> Vector2:
	if focus_point_override != null:
		return focus_point_override
	var viewport := get_viewport()
	if viewport == null:
		return Vector2.ZERO
	if use_pointer and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return viewport.get_mouse_position()
	return viewport.get_visible_rect().size * 0.5


func _sight_open() -> bool:
	if manager == null or not manager.active() or not manager.duel_fighters.is_empty():
		return false
	# Close at once on toggle-off, not when the auras finish fading out.
	if state != null and (sight != null or follow_session) and not state.spirit_sight:
		return false
	return true


## Beings with a full aura, never the hero: the glow tier is too far to read.
func _focusable() -> Array:
	var bodies: Array = []
	for body: Variant in manager.candidates():
		var node := body as Node3D
		if node == null or node.name == SpiritAuraManager.HERO_RIG_NAME:
			continue
		var view := manager.view_for(node)
		if view != null and view.tier == SpiritAuraView.Tier.FULL:
			bodies.append(node)
	return bodies


## Chest height from the aura's unity light (mid sternum) when its anchors are known.
func _chest_heights(bodies: Array) -> Dictionary:
	var heights := {}
	for body: Node3D in bodies:
		var view := manager.view_for(body)
		if view.anchors.size() > 3:
			heights[body] = view.anchors[3].y - body.global_position.y
	return heights


func _camera() -> Camera3D:
	if camera_override != null:
		return camera_override
	return get_viewport().get_camera_3d() if get_viewport() != null else null


func _open(body: Node3D) -> void:
	target = body
	_panel.visible = true
	_refresh()


func _refresh() -> void:
	var view := manager.view_for(target)
	if view == null or view.profile == null:
		close()
		return
	var awareness := SpiritAuraProfile.hero_awareness_level(state)
	var context := _context_for(target)
	context["absent_closed"] = view.closed_as_absent
	var next := SpiritReading.read(view.profile, awareness, context)
	if next == reading:
		return
	reading = next
	_render()


func _context_for(body: Node3D) -> Dictionary:
	var db := content_db
	if db == null and sight != null:
		db = sight.get(&"content_db") as ContentDB
	if db == null and follow_session and is_inside_tree():
		var session := get_node_or_null("/root/SessionState")
		if session != null:
			db = session.get(&"content_db") as ContentDB
	var char_id := SpiritReading.char_id_for(body)
	var duel_id := &""
	if sight != null and sight.has_method("duel_for"):
		duel_id = sight.call("duel_for", char_id, db)
	var context := SpiritReading.context_for(char_id, db, duel_id)
	if String(context["name"]).is_empty() and body.has_meta(&"display_name"):
		context["name"] = String(body.get_meta(&"display_name"))
	# Animals carry no temperament or topic: a stranger duel is fought with people only.
	if manager.view_for(body) != null and manager.view_for(body).closed_as_absent:
		context["temperament"] = []
		context["topic_tags"] = []
	return context


func _render() -> void:
	var who := String(reading["name"])
	_title.text = "Soul lights" if who.is_empty() else "Soul lights of %s" % who
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	# Crown first: the strip reads left to right, crown light leading.
	var lights: Array = reading["lights"].duplicate()
	lights.reverse()
	for light: Dictionary in lights:
		_rows.add_child(_row(light))
	var lines: Array[String] = []
	if not reading["strongest"].is_empty():
		lines.append("Strongest: %s" % ", ".join(reading["strongest"]))
	if not reading["closed"].is_empty():
		lines.append("Closed: %s" % ", ".join(reading["closed"]))
	if int(reading["veiled_count"]) > 0:
		lines.append("Veiled: %d (a keener inner eye sees them)" % int(reading["veiled_count"]))
	lines.append("Clarity: %s" % reading["clarity_word"])
	if not reading["temperament"].is_empty():
		lines.append("Temperament: %s" % ", ".join(reading["temperament"]))
	if not String(reading["topic_hint"]).is_empty():
		lines.append("Weighs on them: %s" % reading["topic_hint"])
	_summary.text = "\n".join(lines)


func _row(light: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var mark := SoulLightMark.new()
	mark.light = light
	mark.custom_minimum_size = Vector2(22.0 + PIP_COUNT * 12.0, ROW_HEIGHT)
	row.add_child(mark)
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 14)
	var text := "%s - %s" % [light["name"], light["element_name"]]
	if light["element"] == &"sight":
		text = "%s - sight, guards none" % light["name"]
	match light["state"]:
		&"veiled":
			text += "  (veiled)"
		&"closed":
			text += "  (closed)"
		&"absent":
			text += "  (absent)"
	if light["strongest"]:
		text += "  strongest"
	label.text = text
	row.add_child(label)
	return row


func _read_session() -> void:
	if sight != null and sight.get(&"state") is GameState:
		state = sight.get(&"state")
		return
	if not follow_session or not is_inside_tree():
		return
	var session := get_node_or_null("/root/SessionState")
	if session != null:
		state = session.get(&"state") as GameState


## Glyph (shape per light, so colour is never the only cue) and five level pips. A veiled
## light draws a hollow glyph and no pips; an absent one a faint outline.
class SoulLightMark:
	extends Control

	var light: Dictionary = {}

	func _draw() -> void:
		var color: Color = light.get("color", Color.WHITE)
		var state: StringName = light.get("state", &"lit")
		var filled := state == &"lit"
		var glyph_color := color if state != &"absent" else Color(color, 0.35)
		_draw_glyph(StringName(light.get("glyph", &"circle")), Vector2(10.0, size.y * 0.5), 8.0,
			glyph_color, filled)
		if state == &"veiled" or state == &"absent":
			return
		var level := int(light.get("level", 0))
		for i in SpiritReadingPanel.PIP_COUNT:
			var center := Vector2(28.0 + i * 12.0, size.y * 0.5)
			if i < level:
				draw_circle(center, 4.0, color)
			else:
				draw_arc(center, 4.0, 0.0, TAU, 12, Color(color, 0.5), 1.0, true)

	func _draw_glyph(kind: StringName, c: Vector2, r: float, color: Color, filled: bool) -> void:
		var points := PackedVector2Array()
		match kind:
			&"square":
				points = [c + Vector2(-r, -r) * 0.8, c + Vector2(r, -r) * 0.8,
					c + Vector2(r, r) * 0.8, c + Vector2(-r, r) * 0.8]
			&"triangle_down":
				points = [c + Vector2(-r, -r * 0.7), c + Vector2(r, -r * 0.7), c + Vector2(0, r)]
			&"triangle_up":
				points = [c + Vector2(0, -r), c + Vector2(r, r * 0.7), c + Vector2(-r, r * 0.7)]
			&"diamond":
				points = [c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)]
			&"star":
				for i in 10:
					var radius := r if i % 2 == 0 else r * 0.45
					var angle := -PI * 0.5 + PI * float(i) / 5.0
					points.append(c + Vector2(cos(angle), sin(angle)) * radius)
			&"eye":
				for i in 16:
					var angle := TAU * float(i) / 16.0
					points.append(c + Vector2(cos(angle) * r, sin(angle) * r * 0.5))
			_:
				for i in 16:
					var angle := TAU * float(i) / 16.0
					points.append(c + Vector2(cos(angle), sin(angle)) * r * 0.85)
		if filled:
			draw_colored_polygon(points, color)
		var outline := points.duplicate()
		outline.append(points[0])
		draw_polyline(outline, color, 1.5, true)
		if kind == &"eye":
			draw_circle(c, r * 0.28, Color(0.05, 0.05, 0.08) if filled else color)
