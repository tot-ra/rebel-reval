extends Node
## SS-1. Mounted once on Player; the weather continues to own the physical recipe.
## Restore before process callbacks and compose after them: never multiply yesterday's
## grade or freeze the clock. Exiting restores the latest ungraded weather exactly.

const Ripple := preload("res://scripts/combat/spirit_sight_ripple.gdshader")
const AuraManager := preload("res://scripts/combat/spirit_aura_manager.gd")
const DURATION := 0.6
const REDUCED_DURATION := 0.2
const TINT := Color(0.66, 0.68, 1.0)
## Duel grade (ADR 0041 section 5): stronger than sight. Nearly monochrome deep indigo; the
## arena key and fill are the only lights left (SpiritArena3D switches the rest off) and the
## sun is cut to a sliver. One recipe for every map, never per-map code.
const DUEL_SATURATION := 0.1
const DUEL_AMBIENT_ENERGY := 0.55
const DUEL_AMBIENT_COLOR := Color(0.1, 0.14, 0.62)
const DUEL_SUN_SCALE := 0.15
const SIGHT_GROUP := &"spirit_sight_controller"
const FIELDS: Array[StringName] = [
	&"adjustment_enabled", &"adjustment_saturation", &"ambient_light_energy",
	&"ambient_light_color",
]

var state: GameState
var actor: Node2D
var reduced_motion := false
var intensity := 1.0
var blend := 0.0
## Explicit environment/sun support deterministic fixtures without a gameplay camera.
var environment_override: Environment
var sun_override: DirectionalLight3D
var follow_session := true
## 0..1, owned by an open SpiritArena3D; layers the duel grade over the sight grade and
## keeps sight on through the duel (the host's modal flags would otherwise cancel it).
var duel_amount := 0.0

var _environment: Environment
var _sun: DirectionalLight3D
var _snapshot: Dictionary = {}
var _sun_energy := 0.0
var _tween: Tween
var _overlay: CanvasLayer
var _rect: ColorRect
var _material: ShaderMaterial


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 1000
	add_to_group(SIGHT_GROUP)
	actor = get_parent() as Node2D if actor == null else actor
	if follow_session:
		state = get_node("/root/SessionState").state
		get_node("/root/SessionState").state_replaced.connect(_on_state_replaced)
	get_tree().process_frame.connect(_restore_grade)
	_overlay = CanvasLayer.new()
	_overlay.layer = 1
	add_child(_overlay)
	_rect = ColorRect.new()
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_material = ShaderMaterial.new()
	_material.shader = Ripple
	_rect.material = _material
	_overlay.add_child(_rect)
	_rect.visible = false
	# SS-3: auras fade in with `blend`; the manager reads it from its parent.
	var auras := AuraManager.new()
	auras.name = "SpiritAuras"
	auras.follow_session = follow_session
	auras.state = state
	add_child(auras)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"player_spirit_sight") and not event.is_echo():
		if toggle():
			get_viewport().set_input_as_handled()


func toggle() -> bool:
	if not available():
		return false
	set_enabled(not state.spirit_sight)
	return true


func available() -> bool:
	if state == null or state.spirit_encounter_active or get_tree().paused:
		return false
	for group: StringName in [&"demo_dialogue_active", &"cutscene_active"]:
		if not get_tree().get_nodes_in_group(group).is_empty():
			return false
	for node in get_tree().get_nodes_in_group(&"modal_input_overlay"):
		if node is CanvasLayer and node.visible or node is CanvasItem and node.is_visible_in_tree():
			return false
	if is_instance_valid(actor) and actor.has_method("spirit_sight_blocked"):
		if actor.call("spirit_sight_blocked"):
			return false
	return _active_environment() != null


func enforce_availability() -> void:
	if state != null and state.spirit_sight and duel_amount <= 0.0 and not available():
		leave_immediately()


func transition_duration() -> float:
	return REDUCED_DURATION if reduced_motion else DURATION


func set_enabled(enabled: bool) -> void:
	_restore_grade()
	_read_settings()
	state.spirit_sight = enabled
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "blend", 1.0 if enabled else 0.0, transition_duration())
	_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func leave_immediately() -> void:
	if _tween != null:
		_tween.kill()
	if state != null:
		state.spirit_sight = false
	blend = 0.0
	_restore_grade()
	if _rect != null:
		_rect.visible = false


func _process(_delta: float) -> void:
	enforce_availability()
	# load_payload may reset the same state object without a replacement signal.
	if state != null and not state.spirit_sight and (_tween == null or not _tween.is_running()):
		blend = 0.0
	_read_settings()
	compose_grade()


func compose_grade() -> void:
	_restore_grade()
	_environment = _active_environment()
	_resolve_sun()
	var amount := clampf(blend * intensity, 0.0, 1.0)
	_rect.visible = amount > 0.0
	_material.set_shader_parameter("amount", amount)
	_material.set_shader_parameter("phase", blend)
	_material.set_shader_parameter("reduced_motion", reduced_motion)
	_update_origin()
	var duel := clampf(duel_amount, 0.0, 1.0)
	if _environment == null or (amount <= 0.0 and duel <= 0.0):
		return
	for field in FIELDS:
		_snapshot[field] = _environment.get(field)
	grade_environment(_environment, _snapshot, amount, duel)
	if is_instance_valid(_sun):
		_sun_energy = _sun.light_energy
		_sun.light_energy = sun_energy_for(_sun_energy, amount, duel)


## The environment recipe from the physical `base` snapshot: sight first, then the duel grade
## lerped over it. Shared with SpiritArena3D, which grades stages that have no sight node.
static func grade_environment(
	env: Environment, base: Dictionary, sight_amount: float, duel: float
) -> void:
	env.adjustment_enabled = true
	var saturation := lerpf(float(base[&"adjustment_saturation"]), 0.25, sight_amount)
	var energy := float(base[&"ambient_light_energy"]) * (1.0 - 0.4 * sight_amount)
	var tint := (base[&"ambient_light_color"] as Color).lerp(TINT, 0.35 * sight_amount)
	env.adjustment_saturation = lerpf(saturation, DUEL_SATURATION, duel)
	var duel_energy := float(base[&"ambient_light_energy"]) * DUEL_AMBIENT_ENERGY
	env.ambient_light_energy = lerpf(energy, duel_energy, duel)
	env.ambient_light_color = tint.lerp(DUEL_AMBIENT_COLOR, duel)


static func sun_energy_for(base: float, sight_amount: float, duel: float) -> float:
	return lerpf(base * (1.0 - 0.4 * sight_amount), base * DUEL_SUN_SCALE, duel)


func _active_environment() -> Environment:
	if environment_override != null:
		return environment_override
	var world := get_viewport().find_world_3d()
	var camera := get_viewport().get_camera_3d()
	var env := camera.environment if camera != null else null
	if env == null:
		env = world.environment
	return env


func _resolve_sun() -> void:
	if environment_override != null:
		_sun = sun_override
		return
	var world := get_viewport().find_world_3d()
	if is_instance_valid(_sun) and _sun.is_inside_tree() and _sun.get_world_3d() == world:
		return
	_sun = null
	for node in get_tree().root.find_children("Sun", "DirectionalLight3D", true, false):
		if node.get_world_3d() == world:
			_sun = node as DirectionalLight3D
			break


func _restore_grade() -> void:
	if _snapshot.is_empty():
		return
	if is_instance_valid(_environment):
		for field in FIELDS:
			_environment.set(field, _snapshot[field])
	if is_instance_valid(_sun):
		_sun.light_energy = _sun_energy
	_snapshot.clear()


func _update_origin() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or not is_instance_valid(actor):
		return
	# The common logic-to-world bridge is 32px/cell, XZ with positive logic Y = Z.
	var point := Vector3(actor.global_position.x / 32.0, 0.8, actor.global_position.y / 32.0)
	if not camera.is_position_behind(point):
		_material.set_shader_parameter(
			"origin", camera.unproject_position(point) / get_viewport().get_visible_rect().size
		)


func _read_settings() -> void:
	if not follow_session:
		return
	var settings := get_node_or_null("/root/UserSettings")
	if settings != null:
		reduced_motion = settings.dialogue.reduced_motion
		intensity = settings.gameplay.spirit_sight_intensity


func _on_state_replaced(_previous: GameState, current: GameState, _reason: StringName) -> void:
	leave_immediately()
	state = current
	state.spirit_sight = false


func _exit_tree() -> void:
	leave_immediately()
	if get_tree().process_frame.is_connected(_restore_grade):
		get_tree().process_frame.disconnect(_restore_grade)
