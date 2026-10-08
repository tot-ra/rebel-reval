class_name SpiritFormView
extends Control
## The opponent's spirit form in the arena (ADR 0033, R-1335): the `spirit_image_id` of his
## current line (a rusted key, a rod) looms over his body, drawn by `spirit_form.gdshader`
## (procedural, asset freeze P0-040). A full-screen layer: by default it draws the body as a
## dark silhouette at `focus`; `track_3d` instead pins the image over a staged 3D actor and
## hides the silhouette. A pure presentation of a bound SpiritDuel: pressure left shrinks
## and cracks the image, a telegraphed blow swells it, and every blow, reply and cast makes
## it flash and flinch. The duel itself is never changed.

const SHADER := preload("res://scripts/combat/spirit_form.gdshader")
## spirit_image_id -> shader `image_kind`; unknown ids draw a generic wisp (0).
const IMAGE_KINDS: Dictionary = {&"rusted_key": 1, &"rod": 2}
const IMAGE_COLORS: Dictionary = {
	&"rusted_key": Color(0.86, 0.48, 0.24),
	&"rod": Color(0.70, 0.62, 0.88),
}
const DEFAULT_COLOR := Color(0.62, 0.78, 0.95)
## How fast the shown presence follows the real pressure (fraction per second), so a hit
## reads as a visible shrink instead of a jump.
const PRESENCE_EASE_PER_SEC := 1.6
const IMPULSE_DECAY_PER_SEC := 2.8
## Untracked framing: chest at this screen UV, one metre = this share of screen height.
const DEFAULT_FOCUS := Vector2(0.5, 0.56)
const DEFAULT_FRAME_HEIGHT := 0.28
## Chest height above a tracked actor's origin (realistic-human rigs stand on their origin).
const TRACK_CHEST_HEIGHT := 1.3
const CAPTION_WIDTH := 160.0

var image_id: StringName = &""
## Shown values (0..1); `target_presence` is the opponent's pressure ratio.
var presence := 1.0
var target_presence := 1.0
var crack := 0.0
var swell := 0.0
var flash := 0.0
var recoil := 0.0
var focus := DEFAULT_FOCUS
var frame_height := DEFAULT_FRAME_HEIGHT
var show_body := true

var _duel: SpiritDuel
var _rect: ColorRect
var _material: ShaderMaterial
var _caption: Label
var _track_camera: Camera3D
var _track_target: Node3D


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_rect = ColorRect.new()
	_rect.material = _material
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_rect)
	_caption = Label.new()
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.modulate = Color(1, 1, 1, 0.7)
	add_child(_caption)
	_push_uniforms()


## Follow `duel`; call before `duel.begin` so the opening line's image is caught.
func bind(duel: SpiritDuel) -> void:
	unbind()
	_duel = duel
	image_id = &""
	presence = 1.0
	target_presence = 1.0
	crack = 0.0
	swell = 0.0
	flash = 0.0
	recoil = 0.0
	_caption.text = ""
	duel.line_presented.connect(_on_line)
	duel.exchange_resolved.connect(_on_exchange)
	_push_uniforms()


func unbind() -> void:
	if _duel == null:
		return
	if _duel.line_presented.is_connected(_on_line):
		_duel.line_presented.disconnect(_on_line)
	if _duel.exchange_resolved.is_connected(_on_exchange):
		_duel.exchange_resolved.disconnect(_on_exchange)
	_duel = null


## Pin the form over a staged actor seen by `camera` (its own body is the actor, so the
## silhouette is hidden). Pass nulls to return to the untracked silhouette.
func track_3d(camera: Camera3D, target: Node3D) -> void:
	_track_camera = camera
	_track_target = target
	show_body = camera == null or target == null
	if show_body:
		focus = DEFAULT_FOCUS
		frame_height = DEFAULT_FRAME_HEIGHT
	_update_tracking()
	_push_uniforms()


func is_tracking() -> bool:
	return not show_body


func image_kind() -> int:
	return int(IMAGE_KINDS.get(image_id, 0))


func shader_material() -> ShaderMaterial:
	return _material


func _process(delta: float) -> void:
	advance(delta)


## Step the presentation by `delta` seconds (tests call this directly).
func advance(delta: float) -> void:
	if _duel != null:
		var max_pressure := maxf(1.0, _duel.opponent.max_health)
		target_presence = clampf(_duel.opponent.health / max_pressure, 0.0, 1.0)
		swell = _duel.telegraph_progress() if _duel.phase == SpiritDuel.PHASE_TELEGRAPH else 0.0
	presence = move_toward(presence, target_presence, PRESENCE_EASE_PER_SEC * delta)
	crack = 1.0 - presence
	flash = move_toward(flash, 0.0, IMPULSE_DECAY_PER_SEC * delta)
	recoil = move_toward(recoil, 0.0, IMPULSE_DECAY_PER_SEC * delta)
	_update_tracking()
	_push_uniforms()


func _on_line(speaker_id: StringName, _text: String, move: Dictionary) -> void:
	if _duel == null or speaker_id == _duel.hero_id:
		return
	var next_image := StringName(String(move.get("spirit_image_id", "")))
	# A line without an image keeps the last one: the spirit does not vanish between blows.
	if next_image.is_empty() or next_image == image_id:
		return
	image_id = next_image
	_caption.text = String(image_id).replace("_", " ")
	flash = maxf(flash, 0.5)
	_push_uniforms()


func _on_exchange(result: Dictionary) -> void:
	match String(result.get("kind", "")):
		"incoming":
			# The spirit lunges: a landed blow flares it, a parry knocks it back.
			var outcome := StringName(String(result.get("outcome", "")))
			if outcome == CombatHitResult.OUTCOME_PARRIED:
				flash = 1.0
				recoil = 1.0
			else:
				flash = maxf(flash, 0.6)
				recoil = -0.6
		"reply":
			if float(result.get("damage", 0.0)) > 0.0:
				flash = 1.0
				recoil = 1.0
		"spell":
			flash = 1.0
			recoil = 0.8
	_push_uniforms()


## Project the tracked actor's chest (and one metre above it) to screen UV.
func _update_tracking() -> void:
	if show_body:
		return
	if not is_instance_valid(_track_camera) or not is_instance_valid(_track_target):
		return
	if not _track_camera.is_inside_tree() or not _track_target.is_inside_tree():
		return
	var screen := _track_camera.get_viewport().get_visible_rect().size
	if screen.y <= 0.0:
		return
	var chest := _track_target.global_position + Vector3.UP * TRACK_CHEST_HEIGHT
	if _track_camera.is_position_behind(chest):
		return
	var chest_px := _track_camera.unproject_position(chest)
	var metre_px := chest_px.distance_to(_track_camera.unproject_position(chest + Vector3.UP))
	focus = chest_px / screen
	frame_height = metre_px / screen.y


func _push_uniforms() -> void:
	_material.set_shader_parameter(&"image_kind", image_kind())
	_material.set_shader_parameter(&"presence", presence)
	_material.set_shader_parameter(&"crack", crack)
	_material.set_shader_parameter(&"swell", swell)
	_material.set_shader_parameter(&"flash", flash)
	_material.set_shader_parameter(&"recoil", recoil)
	_material.set_shader_parameter(&"rect_size", size if size != Vector2.ZERO else Vector2(1280, 720))
	_material.set_shader_parameter(&"focus", focus)
	_material.set_shader_parameter(&"frame_height", frame_height)
	_material.set_shader_parameter(&"show_body", 1.0 if show_body else 0.0)
	# The image's name sits just over the looming shape.
	_caption.size = Vector2(CAPTION_WIDTH, 24.0)
	_caption.position = Vector2(
		focus.x * size.x - CAPTION_WIDTH * 0.5,
		maxf(0.0, (focus.y - 1.75 * frame_height) * size.y)
	)
	_material.set_shader_parameter(
		&"spirit_color", IMAGE_COLORS.get(image_id, DEFAULT_COLOR) as Color
	)
