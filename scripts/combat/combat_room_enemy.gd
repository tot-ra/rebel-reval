class_name CombatRoomEnemy
extends Node2D

## Scene host for EnemyCombatStateMachine in the P1-024 combat room (P1-025a)
## and the P1-025b night-encounter stub. Why: P1-025 proved the shared AI in
## isolation; these hosts wire both archetypes with readable detect/telegraph/
## attack feedback without forking a second controller.

signal feedback_event(text: String)
signal died
signal health_changed(current: float, maximum: float)
signal hit_resolved(result: CombatHitResult)

const DEFAULT_HEALTH := 30.0
const DEFAULT_STAMINA := 40.0

var machine := EnemyCombatStateMachine.new()
var combat_vitals := CombatVitals.new()
var defense_pose := CombatDefensePose.open()
var health := DEFAULT_HEALTH
var max_health := DEFAULT_HEALTH
var stamina := DEFAULT_STAMINA
var max_stamina := DEFAULT_STAMINA
var hit_count := 0
var last_result: CombatHitResult
var display_name := "Enemy"

var _body: ColorRect
var _pauldron_left: ColorRect
var _pauldron_right: ColorRect
var _spear: ColorRect
var _label: Label
var _target: Node2D
var _swing_counter := 9000
var _signals_wired := false

## MapViewRuntime mirrors combat actors through the same shared rigs as the player.
## The scene is selected from the archetype so watchmen and sergeants retain their
## authored silhouette, equipment, and animation overrides in the 3D map.


func _ready() -> void:
	add_to_group(&"combat_damageable")
	add_to_group(&"map_view_actor")
	combat_vitals.configure(health, max_health, stamina, max_stamina)
	if not combat_vitals.died.is_connected(_on_vitals_died):
		combat_vitals.died.connect(_on_vitals_died)
	_ensure_machine_signals()


func configure(profile: EnemyArchetype, tint: Color) -> void:
	machine.configure(profile if profile != null else EnemyArchetype.watchman())
	display_name = machine.archetype.display_label
	_ensure_visuals(tint)
	_ensure_machine_signals()
	reset_actor()


func reset_actor() -> void:
	health = DEFAULT_HEALTH
	max_health = DEFAULT_HEALTH
	stamina = DEFAULT_STAMINA
	max_stamina = DEFAULT_STAMINA
	hit_count = 0
	last_result = null
	defense_pose = CombatDefensePose.open()
	combat_vitals.configure(health, max_health, stamina, max_stamina)
	machine.reset()
	_target = null
	_refresh_label()


func get_machine() -> EnemyCombatStateMachine:
	return machine


func view_facing() -> Vector2:
	if _target != null and is_instance_valid(_target):
		var toward_target := _target.global_position - global_position
		if toward_target.length_squared() > 1.0:
			return toward_target.normalized()
	return Vector2.DOWN


func view_rig_scene() -> PackedScene:
	return machine.archetype.character_scene


func view_animation() -> StringName:
	if machine.is_dead():
		return &"fall"
	match machine.state:
		EnemyCombatState.State.ATTACK:
			return machine.archetype.attack_animation
		EnemyCombatState.State.REACT:
			return &"hit"
		EnemyCombatState.State.PATROL, EnemyCombatState.State.DISENGAGE:
			return &"walk"
		EnemyCombatState.State.TELEGRAPH:
			return &"guard"
		_:
			return &"idle"


func is_combat_dead() -> bool:
	return machine.is_dead()


func set_ai_target(target: Node2D) -> void:
	_target = target


## Advance perception + AI one step. Tests call this directly because the
## headless harness does not always pump Node._process.
func tick_ai(delta: float, target: Node2D = null) -> void:
	if delta <= 0.0:
		return
	combat_vitals.tick(delta)
	if target != null:
		_target = target
	if machine.is_dead():
		_refresh_label()
		return
	if _target != null and is_instance_valid(_target):
		var distance := global_position.distance_to(_target.global_position)
		machine.set_perception(true, distance)
	else:
		machine.clear_target()
	machine.tick(delta)
	_refresh_label()


func take_damage(
	amount: float,
	_source: Node = null,
	_damage_type: StringName = &"",
	swing_id: int = 0,
	pierces_guard: bool = false
) -> float:
	if machine.is_dead():
		return 0.0
	combat_vitals.health = health
	combat_vitals.max_health = max_health
	combat_vitals.stamina = stamina
	combat_vitals.max_stamina = max_stamina
	var result := combat_vitals.resolve_hit(amount, defense_pose, swing_id, pierces_guard)
	last_result = result
	health = combat_vitals.health
	stamina = combat_vitals.stamina
	hit_resolved.emit(result)
	if result.died:
		machine.mark_dead()
		_refresh_label()
		return result.health_damage
	if result.health_damage > 0.0:
		hit_count += 1
		health_changed.emit(health, max_health)
		machine.apply_hit()
		feedback_event.emit(
			"%s: hit -> %s" % [display_name, EnemyCombatState.display_name(machine.state)]
		)
	_refresh_label()
	return result.health_damage


func _ensure_machine_signals() -> void:
	if _signals_wired:
		return
	_signals_wired = true
	machine.state_changed.connect(_on_state_changed)
	machine.detected.connect(_on_detected)
	machine.telegraphed.connect(_on_telegraphed)
	machine.attack_impact.connect(_on_attack_impact)
	machine.disengaged.connect(_on_disengaged)
	machine.died.connect(_on_machine_died)


func _ensure_visuals(tint: Color) -> void:
	var profile := machine.archetype
	var body_color := Color(0.72, 0.72, 0.74, 1.0)
	if profile == null or (not profile.shows_spear and not profile.shows_pauldrons):
		body_color = tint
	if _body == null:
		_body = ColorRect.new()
		_body.name = "Body"
		add_child(_body)
		_pauldron_left = ColorRect.new()
		_pauldron_left.name = "PauldronLeft"
		add_child(_pauldron_left)
		_pauldron_right = ColorRect.new()
		_pauldron_right.name = "PauldronRight"
		add_child(_pauldron_right)
		_spear = ColorRect.new()
		_spear.name = "Spear"
		add_child(_spear)
	var half_width := profile.body_half_width if profile != null else 16.0
	var top := profile.body_top if profile != null else -40.0
	var bottom := profile.body_bottom if profile != null else -4.0
	_body.offset_left = -half_width
	_body.offset_top = top
	_body.offset_right = half_width
	_body.offset_bottom = bottom
	_body.color = body_color
	var show_pauldrons := profile != null and profile.shows_pauldrons
	_pauldron_left.visible = show_pauldrons
	_pauldron_right.visible = show_pauldrons
	if show_pauldrons:
		_pauldron_left.offset_left = -half_width - 6.0
		_pauldron_left.offset_top = top + 4.0
		_pauldron_left.offset_right = -half_width + 2.0
		_pauldron_left.offset_bottom = top + 16.0
		_pauldron_left.color = body_color.darkened(0.12)
		_pauldron_right.offset_left = half_width - 2.0
		_pauldron_right.offset_top = top + 4.0
		_pauldron_right.offset_right = half_width + 6.0
		_pauldron_right.offset_bottom = top + 16.0
		_pauldron_right.color = body_color.darkened(0.12)
	var show_spear := profile != null and profile.shows_spear
	_spear.visible = show_spear
	if show_spear:
		_spear.offset_left = half_width - 2.0
		_spear.offset_top = top + 6.0
		_spear.offset_right = half_width + 4.0
		_spear.offset_bottom = bottom - 8.0
		_spear.color = body_color.darkened(0.18)
	if _label == null:
		_label = Label.new()
		_label.name = "StateLabel"
		_label.position = Vector2(-52, -62)
		_label.add_theme_font_size_override("font_size", 12)
		_label.add_theme_color_override("font_color", Color(0.95, 0.93, 0.78, 1.0))
		add_child(_label)
	_refresh_label()


func _refresh_label() -> void:
	if _label == null:
		return
	_label.text = "%s [%s]" % [display_name, EnemyCombatState.display_name(machine.state)]


func _on_state_changed(_previous: EnemyCombatState.State, current: EnemyCombatState.State) -> void:
	_refresh_label()
	# Dedicated phase signals cover detect/telegraph/disengage; react has none.
	if current == EnemyCombatState.State.REACT:
		feedback_event.emit("%s: react" % display_name)
	elif current == EnemyCombatState.State.ATTACK:
		feedback_event.emit("%s: attack" % display_name)


func _on_detected() -> void:
	feedback_event.emit("%s: detect" % display_name)


func _on_telegraphed() -> void:
	feedback_event.emit("%s: telegraph" % display_name)


func _on_attack_impact() -> void:
	var profile := machine.current_attack_profile()
	var dealt := 0.0
	if (
		_target != null
		and is_instance_valid(_target)
		and _target.has_method("take_damage")
		and global_position.distance_to(_target.global_position) <= profile.reach_px
	):
		_swing_counter += 1
		dealt = float(
			_target.call(
				"take_damage", profile.damage, self, profile.damage_type, _swing_counter, false
			)
		)
	feedback_event.emit("%s: attack dmg=%.0f dealt=%.0f" % [display_name, profile.damage, dealt])


func _on_disengaged() -> void:
	feedback_event.emit("%s: disengage" % display_name)


func _on_machine_died() -> void:
	feedback_event.emit("%s: dead" % display_name)


func _on_vitals_died() -> void:
	machine.mark_dead()
	died.emit()
	_refresh_label()
