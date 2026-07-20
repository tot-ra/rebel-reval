extends Node2D

class_name CombatRoom

## Playable combat integration room for P1-024 / P1-025a.
## Hammers light/charged attacks, guard/parry, dodge, Iron, readable feedback,
## plus wired watchman/sergeant AI hosts that share EnemyCombatStateMachine.

const PLAYER_SCENE := preload("res://player.tscn")
const DUMMY_SCRIPT := preload("res://scripts/combat/combat_training_dummy.gd")
const ENEMY_SCRIPT := preload("res://scripts/combat/combat_room_enemy.gd")
const FEEDBACK_HUD_SCRIPT := preload("res://scripts/combat/combat_feedback_hud.gd")
const ITEM_HAMMER := &"item.forge_hammer"

const PLAYER_SPAWN := Vector2(640.0, 400.0)
const OPEN_DUMMY_POS := Vector2(780.0, 400.0)
const GUARD_DUMMY_POS := Vector2(780.0, 280.0)
## Left of the attack lane so P1-024 dummy smokes stay clear.
const WATCHMAN_POS := Vector2(420.0, 520.0)
const SERGEANT_POS := Vector2(420.0, 200.0)

var player: Player
var open_dummy: CombatTestDummy
var guard_dummy: CombatTestDummy
var watchman: CombatRoomEnemy
var sergeant: CombatRoomEnemy
var feedback: CombatFeedbackHud
var _reset_button: Button
var _built := false


func _ready() -> void:
	ensure_built()


## Idempotent setup so headless tests can build without awaiting a frame.
func ensure_built() -> void:
	if _built:
		return
	_built = true
	_ensure_session()
	_build_environment()
	_spawn_actors()
	_build_hud()
	_wire_signals()
	reset_room()


func reset_room() -> void:
	ensure_built()
	_ensure_session()
	SessionState.state.set_equipped_forge_technique(&"")
	_equip_hammer()
	if player != null:
		player.global_position = PLAYER_SPAWN
		player._facing_direction = Vector2.RIGHT
		player.health = player.max_health
		player.stamina = player.max_stamina
		player.combat_vitals.configure(player.health, player.max_health, player.stamina, player.max_stamina)
		player.action_state_machine.reset()
	if open_dummy != null:
		open_dummy.global_position = OPEN_DUMMY_POS
		open_dummy.configure_resources(40.0, 40.0, 40.0, 40.0)
		open_dummy.set_guarding(false)
		open_dummy.display_name = "Open dummy"
	if guard_dummy != null:
		guard_dummy.global_position = GUARD_DUMMY_POS
		guard_dummy.configure_resources(40.0, 40.0, 40.0, 40.0)
		# Braced past the parry window so Iron jams are visible.
		guard_dummy.set_guarding(true, 1.0)
		guard_dummy.display_name = "Guard dummy"
	if watchman != null:
		watchman.global_position = WATCHMAN_POS
		watchman.reset_actor()
		watchman.set_ai_target(player)
	if sergeant != null:
		sergeant.global_position = SERGEANT_POS
		sergeant.reset_actor()
		sergeant.set_ai_target(player)
	if feedback != null:
		feedback.clear_log()
		feedback.push_event("Room reset. Hammer equipped. Watchman + Sergeant online.")
	_refresh_status("Ready. Face a dummy or approach an enemy.")


func get_player() -> Player:
	return player


func get_open_dummy() -> CombatTestDummy:
	return open_dummy


func get_guard_dummy() -> CombatTestDummy:
	return guard_dummy


func get_watchman() -> CombatRoomEnemy:
	return watchman


func get_sergeant() -> CombatRoomEnemy:
	return sergeant


func get_feedback() -> CombatFeedbackHud:
	return feedback


func get_reset_button() -> Button:
	return _reset_button


## Headless tick for enemy AI + HUD. Prefer this over relying on Node._process.
func advance_enemies(delta: float) -> void:
	ensure_built()
	for enemy in [watchman, sergeant]:
		if enemy != null:
			enemy.tick_ai(delta, player)


## Drive one wired archetype through detect → telegraph → attack → react →
## disengage → patrol using the room actor + feedback path (P1-025a verify).
func run_enemy_detect_to_disengage_loop(enemy: CombatRoomEnemy) -> Array:
	ensure_built()
	if enemy == null:
		return []
	var profile := enemy.get_machine().archetype
	var trail: Array = []
	var on_state := func(
		_previous: EnemyCombatState.State, current: EnemyCombatState.State
	) -> void:
		trail.append(EnemyCombatState.display_name(current))
	enemy.get_machine().state_changed.connect(on_state)
	enemy.reset_actor()
	enemy.set_ai_target(player)

	# Enter detect outside engage so the first finished swing can leave combat.
	var approach := minf(profile.detect_radius * 0.8, profile.engage_radius + 8.0)
	if approach <= profile.engage_radius:
		approach = profile.engage_radius + 4.0
	_place_relative(enemy, approach)
	_advance_enemy_until(enemy, EnemyCombatState.State.DETECT, 1.5)

	_place_relative(enemy, profile.engage_radius * 0.4)
	_advance_enemy_until(enemy, EnemyCombatState.State.TELEGRAPH, 2.0)
	_advance_enemy_until(enemy, EnemyCombatState.State.ATTACK, 2.0)

	enemy.get_machine().apply_hit()
	_advance_enemy_until(enemy, EnemyCombatState.State.TELEGRAPH, 2.0)
	_advance_enemy_until(enemy, EnemyCombatState.State.ATTACK, 2.0)

	enemy.tick_ai(profile.attack_impact_sec + 0.05, player)
	_place_relative(enemy, profile.lose_sight_radius + 20.0)
	_advance_enemy_until(enemy, EnemyCombatState.State.DISENGAGE, 2.0)
	_advance_enemy_until(enemy, EnemyCombatState.State.PATROL, 2.0)

	if enemy.get_machine().state_changed.is_connected(on_state):
		enemy.get_machine().state_changed.disconnect(on_state)
	return trail


func _place_relative(enemy: CombatRoomEnemy, distance: float) -> void:
	# Keep enemy east of the player so facing/readability stay consistent.
	enemy.global_position = player.global_position + Vector2(distance, 0.0)
	enemy.set_ai_target(player)


func _advance_enemy_until(
	enemy: CombatRoomEnemy, desired: EnemyCombatState.State, budget_sec: float
) -> void:
	var elapsed := 0.0
	const STEP := 0.05
	while enemy.get_machine().state != desired and elapsed < budget_sec:
		enemy.tick_ai(STEP, player)
		elapsed += STEP


func _ensure_session() -> void:
	if not SessionState.content_db.is_loaded():
		SessionState.content_db.load_from_directories(SessionState.DEMO_CONTENT_DIRS)
	if SessionState.state == null:
		SessionState.state = GameState.new()
	SessionState.state.bag.set_content_db(SessionState.content_db)


func _equip_hammer() -> void:
	var slot := &"right_hand"
	if SessionState.state.equipped_item(slot) == ITEM_HAMMER:
		return
	if not SessionState.state.equipped_item(slot).is_empty():
		SessionState.state.unequip_to_bag(slot)
	if SessionState.state.bag.find_placement(ITEM_HAMMER) == null:
		SessionState.state.bag.try_add(ITEM_HAMMER)
	SessionState.state.equip_from_bag(slot, ITEM_HAMMER)


func _build_environment() -> void:
	name = "CombatRoom"
	var floor_rect := ColorRect.new()
	floor_rect.name = "Floor"
	floor_rect.position = Vector2.ZERO
	floor_rect.size = Vector2(1280, 720)
	floor_rect.color = Color(0.11, 0.13, 0.15, 1.0)
	add_child(floor_rect)

	var lane := ColorRect.new()
	lane.name = "Lane"
	lane.position = Vector2(560, 240)
	lane.size = Vector2(280, 240)
	lane.color = Color(0.16, 0.19, 0.22, 1.0)
	add_child(lane)


func _spawn_actors() -> void:
	player = PLAYER_SCENE.instantiate() as Player
	player.name = "Player"
	player.position = PLAYER_SPAWN
	player._facing_direction = Vector2.RIGHT
	add_child(player)

	open_dummy = _make_dummy("OpenDummy", OPEN_DUMMY_POS, Color(0.78, 0.32, 0.28, 1.0))
	guard_dummy = _make_dummy("GuardDummy", GUARD_DUMMY_POS, Color(0.32, 0.55, 0.78, 1.0))
	watchman = _make_enemy(
		"Watchman", WATCHMAN_POS, EnemyArchetype.watchman(), Color(0.62, 0.58, 0.34, 1.0)
	)
	sergeant = _make_enemy(
		"Sergeant", SERGEANT_POS, EnemyArchetype.sergeant(), Color(0.55, 0.28, 0.42, 1.0)
	)


func _make_dummy(node_name: String, pos: Vector2, tint: Color) -> CombatTestDummy:
	var dummy: CombatTestDummy = DUMMY_SCRIPT.new()
	dummy.name = node_name
	dummy.position = pos
	var body := ColorRect.new()
	body.offset_left = -14.0
	body.offset_top = -36.0
	body.offset_right = 14.0
	body.offset_bottom = -4.0
	body.color = tint
	dummy.add_child(body)
	var label := Label.new()
	label.position = Vector2(-40, -58)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.92, 0.94, 0.96, 1.0))
	label.text = node_name
	dummy.add_child(label)
	add_child(dummy)
	return dummy


func _make_enemy(
	node_name: String, pos: Vector2, profile: EnemyArchetype, tint: Color
) -> CombatRoomEnemy:
	var enemy: CombatRoomEnemy = ENEMY_SCRIPT.new()
	enemy.name = node_name
	enemy.position = pos
	enemy.configure(profile, tint)
	add_child(enemy)
	return enemy


func _build_hud() -> void:
	feedback = FEEDBACK_HUD_SCRIPT.new()
	feedback.name = "CombatFeedbackHud"
	add_child(feedback)

	var actions := CanvasLayer.new()
	actions.name = "CombatRoomActions"
	actions.layer = 41
	add_child(actions)

	_reset_button = Button.new()
	_reset_button.name = "ResetRoomButton"
	_reset_button.text = "Reset room"
	_reset_button.tooltip_text = "Restore HP, stamina, postures, enemies, and clear Iron"
	_reset_button.position = Vector2(16, 640)
	_reset_button.custom_minimum_size = Vector2(140, 36)
	_reset_button.pressed.connect(reset_room)
	actions.add_child(_reset_button)


func _wire_signals() -> void:
	if player != null:
		if not player.melee_attack_resolved.is_connected(_on_player_melee_resolved):
			player.melee_attack_resolved.connect(_on_player_melee_resolved)
		if not player.health_changed.is_connected(_on_player_health_changed):
			player.health_changed.connect(_on_player_health_changed)
	for dummy in [open_dummy, guard_dummy]:
		if dummy != null and not dummy.hit_resolved.is_connected(_on_dummy_hit_resolved.bind(dummy)):
			dummy.hit_resolved.connect(_on_dummy_hit_resolved.bind(dummy))
	for enemy in [watchman, sergeant]:
		if enemy == null:
			continue
		if not enemy.feedback_event.is_connected(_on_enemy_feedback):
			enemy.feedback_event.connect(_on_enemy_feedback)
		if not enemy.hit_resolved.is_connected(_on_enemy_hit_resolved.bind(enemy)):
			enemy.hit_resolved.connect(_on_enemy_hit_resolved.bind(enemy))


func _on_player_melee_resolved(targets: Array[Node2D], profile: AttackProfile) -> void:
	var names: PackedStringArray = PackedStringArray()
	for target in targets:
		if target is CombatTestDummy:
			names.append((target as CombatTestDummy).display_name)
		elif target is CombatRoomEnemy:
			names.append((target as CombatRoomEnemy).display_name)
		elif target != null:
			names.append(target.name)
	var hit_text := "none" if names.is_empty() else ", ".join(names)
	var tech := String(profile.technique) if profile != null and not profile.technique.is_empty() else "none"
	feedback.push_event(
		"Strike %s dmg=%.0f sta=%.0f tech=%s -> %s"
		% [String(profile.animation), profile.damage, profile.stamina_cost, tech, hit_text]
	)
	_refresh_status("Attack resolved.")


func _on_player_health_changed(current: float, maximum: float) -> void:
	var result := player.last_hit_result()
	feedback.push_event(feedback.describe_hit_result("Player", result))
	_refresh_status("Player HP %.0f/%.0f" % [current, maximum])


func _on_dummy_hit_resolved(result: CombatHitResult, dummy: CombatTestDummy) -> void:
	feedback.push_event(feedback.describe_hit_result(dummy.display_name, result))
	_refresh_status("%s HP %.0f STA %.0f" % [dummy.display_name, dummy.health, dummy.stamina])


func _on_enemy_hit_resolved(result: CombatHitResult, enemy: CombatRoomEnemy) -> void:
	feedback.push_event(feedback.describe_hit_result(enemy.display_name, result))
	_refresh_status(
		"%s HP %.0f state=%s"
		% [enemy.display_name, enemy.health, EnemyCombatState.display_name(enemy.get_machine().state)]
	)


func _on_enemy_feedback(text: String) -> void:
	if feedback != null:
		feedback.push_event(text)


func _refresh_status(note: String) -> void:
	if feedback == null or player == null:
		return
	var technique := SessionState.state.equipped_forge_technique()
	var tech_label := "off" if technique.is_empty() else String(technique)
	var item := SessionState.state.equipped_item(&"right_hand")
	var watch_state := (
		EnemyCombatState.display_name(watchman.get_machine().state) if watchman else "-"
	)
	var sarge_state := (
		EnemyCombatState.display_name(sergeant.get_machine().state) if sergeant else "-"
	)
	feedback.set_status(
		(
			"%s | Player HP %.0f STA %.0f | state=%s | item=%s | Iron=%s | Open %.0f | Guard %.0f | Watch %s | Sarge %s"
			% [
				note,
				player.health,
				player.stamina,
				PlayerActionState.display_name(player.action_state_machine.state),
				String(item),
				tech_label,
				open_dummy.health if open_dummy else 0.0,
				guard_dummy.health if guard_dummy else 0.0,
				watch_state,
				sarge_state,
			]
		)
	)


func _process(delta: float) -> void:
	if player == null:
		return
	advance_enemies(delta)
	_refresh_status("Live")
