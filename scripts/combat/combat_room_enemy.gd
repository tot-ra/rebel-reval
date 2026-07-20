extends Node2D

class_name CombatRoomEnemy

## Scene host for EnemyCombatStateMachine in the P1-024 combat room (P1-025a).
## Why: P1-025 proved the shared AI in isolation; this wires both archetypes into
## the smoke host with readable detect/telegraph/attack feedback without forking
## a second controller.

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
var _label: Label
var _target: Node2D
var _swing_counter := 9000
var _signals_wired := false


func _ready() -> void:
	add_to_group(&"combat_damageable")
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
	if _body == null:
		_body = ColorRect.new()
		_body.name = "Body"
		_body.offset_left = -16.0
		_body.offset_top = -40.0
		_body.offset_right = 16.0
		_body.offset_bottom = -4.0
		add_child(_body)
	_body.color = tint
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


func _on_state_changed(
	_previous: EnemyCombatState.State, current: EnemyCombatState.State
) -> void:
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
				"take_damage",
				profile.damage,
				self,
				profile.damage_type,
				_swing_counter,
				false
			)
		)
	feedback_event.emit(
		"%s: attack dmg=%.0f dealt=%.0f" % [display_name, profile.damage, dealt]
	)


func _on_disengaged() -> void:
	feedback_event.emit("%s: disengage" % display_name)


func _on_machine_died() -> void:
	feedback_event.emit("%s: dead" % display_name)


func _on_vitals_died() -> void:
	machine.mark_dead()
	died.emit()
	_refresh_label()
