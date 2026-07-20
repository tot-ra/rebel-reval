extends Node2D

class_name NightEncounterStub

## Optional night-encounter host for P1-025b / P1-026b / P1-027a / P2-009.
## Why: keep watchman/sergeant AI on CombatRoomEnemy outside the combat smoke
## room so night consequence can reuse the same machine without forking AI.
## Remains unreachable from release demo navigation (not in the transition
## manifest). Player death exposes the same EncounterCheckpoint Retry path as
## the combat room without dialogue replay or quest corruption. P1-026b adds
## mouse-reachable surrender/escape/bypass closes via ContentDB
## encounter.watch_checkpoint (same quest contract as the combat room).

const PLAYER_SCENE := preload("res://player.tscn")
const ENEMY_SCRIPT := preload("res://scripts/combat/combat_room_enemy.gd")
const FEEDBACK_HUD_SCRIPT := preload("res://scripts/combat/combat_feedback_hud.gd")

const PLAYER_SPAWN := Vector2(640.0, 360.0)
const WATCHMAN_POS := Vector2(420.0, 480.0)
const SERGEANT_POS := Vector2(860.0, 240.0)
## Stable scene path used by reachability assertions; keep out of the manifest.
const SCENE_PATH := "res://scenes/tests/night_encounter_stub.tscn"
const ENCOUNTER_ID := &"encounter.watch_checkpoint"

var player: Player
var watchman: CombatRoomEnemy
var sergeant: CombatRoomEnemy
var feedback: CombatFeedbackHud
var encounter_definition: EncounterOutcomeDefinition = EncounterOutcomeDefinition.new()
var encounter_resolver := EncounterOutcomeResolver.new()
var encounter_checkpoint := EncounterCheckpoint.new()
var _retry_button: Button
var _surrender_button: Button
var _escape_button: Button
var _bypass_button: Button
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
	reset_stub()


func reset_stub() -> void:
	ensure_built()
	_ensure_session()
	_reset_combat_actors()
	# Why: arm after actors are live so a later death restores this narrative
	# snapshot rather than a mid-fight corrupted quest/dialogue payload.
	arm_encounter_checkpoint()
	if feedback != null:
		feedback.clear_log()
		feedback.push_event("Night stub ready. Watchman + Sergeant online.")
		feedback.push_event("Non-lethal closes: Surrender / Escape / Bypass buttons.")
		feedback.push_event("Checkpoint armed. Death enables Retry without dialogue replay.")
		feedback.set_status("Night route host. Approach an enemy to start AI.")
	_set_retry_visible(false)


## P1-026b: resolve an authored outcome against live stub enemies and session
## quest state using the ContentDB encounter.watch_checkpoint package.
func resolve_encounter_outcome(kind: StringName) -> bool:
	ensure_built()
	_ensure_session()
	var enemies: Array = []
	if watchman != null:
		enemies.append(watchman)
	if sergeant != null:
		enemies.append(sergeant)
	var ok := encounter_resolver.resolve(
		SessionState.state, encounter_definition, kind, enemies
	)
	if ok:
		# Successful close ends the fight; drop the failure retry snapshot.
		encounter_checkpoint.clear()
		_set_retry_visible(false)
		if feedback != null:
			feedback.push_event(
				"Encounter %s -> %s=%s"
				% [
					EncounterOutcome.display_name(kind),
					String(encounter_definition.quest_id),
					String(encounter_resolver.last_quest_state),
				]
			)
			feedback.set_status(
				"Outcome %s. Quest %s."
				% [
					EncounterOutcome.display_name(kind),
					String(encounter_resolver.last_quest_state),
				]
			)
	elif feedback != null:
		feedback.push_event("Encounter outcome rejected: %s" % EncounterOutcome.display_name(kind))
	return ok


## P1-027a: snapshot session GameState so failure can restore quest/dialogue.
func arm_encounter_checkpoint() -> bool:
	ensure_built()
	_ensure_session()
	return encounter_checkpoint.arm(
		SessionState.state, encounter_definition.encounter_id
	)


## P1-027a: restore armed GameState and combat actors after player failure.
## Completed dialogue and prior quest progress from arm time are preserved;
## mid-fight quest writes are discarded.
func retry_from_checkpoint() -> bool:
	ensure_built()
	_ensure_session()
	if not encounter_checkpoint.is_armed:
		if feedback != null:
			feedback.push_event("Retry rejected: no armed checkpoint.")
		return false
	if not encounter_checkpoint.restore(SessionState.state):
		if feedback != null:
			feedback.push_event("Retry rejected: checkpoint restore failed.")
		return false
	_reset_combat_actors()
	# Re-arm from the restored narrative so a second failure still retries cleanly.
	arm_encounter_checkpoint()
	_set_retry_visible(false)
	if feedback != null:
		feedback.push_event(
			"Retry from checkpoint %s. Dialogue and quest restored."
			% String(encounter_definition.encounter_id)
		)
		feedback.set_status("Retried. Checkpoint restored.")
	return true


func get_player() -> Player:
	return player


func get_watchman() -> CombatRoomEnemy:
	return watchman


func get_sergeant() -> CombatRoomEnemy:
	return sergeant


func get_feedback() -> CombatFeedbackHud:
	return feedback


func get_retry_button() -> Button:
	return _retry_button


func get_surrender_button() -> Button:
	return _surrender_button


func get_escape_button() -> Button:
	return _escape_button


func get_bypass_button() -> Button:
	return _bypass_button


func get_encounter_resolver() -> EncounterOutcomeResolver:
	return encounter_resolver


func get_encounter_checkpoint() -> EncounterCheckpoint:
	return encounter_checkpoint


## Headless tick for enemy AI + HUD. Prefer this over relying on Node._process.
func advance_enemies(delta: float) -> void:
	ensure_built()
	for enemy in [watchman, sergeant]:
		if enemy != null:
			enemy.tick_ai(delta, player)


## Drive one wired archetype through detect → telegraph → attack → react →
## disengage → patrol using the stub actor + feedback path (P1-025b verify).
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
	# Why: P1-026b loads quest mappings from content so P2-009 can remap without
	# code edits (same package as the combat room).
	encounter_definition = EncounterOutcomeDefinition.from_content_db(
		SessionState.content_db, ENCOUNTER_ID
	)


func _build_environment() -> void:
	name = "NightEncounterStub"
	var floor_rect := ColorRect.new()
	floor_rect.name = "NightFloor"
	floor_rect.position = Vector2.ZERO
	floor_rect.size = Vector2(1280, 720)
	# Darker than the combat smoke room so the stub reads as a night host.
	floor_rect.color = Color(0.05, 0.06, 0.09, 1.0)
	add_child(floor_rect)

	var route := ColorRect.new()
	route.name = "WatchRoute"
	route.position = Vector2(360, 180)
	route.size = Vector2(560, 360)
	route.color = Color(0.08, 0.10, 0.14, 1.0)
	add_child(route)


func _spawn_actors() -> void:
	player = PLAYER_SCENE.instantiate() as Player
	player.name = "Player"
	player.position = PLAYER_SPAWN
	player._facing_direction = Vector2.RIGHT
	add_child(player)

	watchman = _make_enemy(
		"Watchman", WATCHMAN_POS, EnemyArchetype.watchman(), Color(0.62, 0.58, 0.34, 1.0)
	)
	sergeant = _make_enemy(
		"Sergeant", SERGEANT_POS, EnemyArchetype.sergeant(), Color(0.55, 0.28, 0.42, 1.0)
	)


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
	feedback.set_title("Night encounter stub (P1-025b / P1-026b / P1-027a)")
	feedback.set_controls_text(
		"Developer night host for watchman/sergeant AI.\n"
		+ "Not reachable from Start / release demo navigation.\n"
		+ "Approach Watchman (gold) or Sergeant (magenta).\n"
		+ "Non-lethal closes: Surrender / Escape / Bypass (ContentDB).\n"
		+ "Death enables mouse-reachable Retry (checkpoint restore)."
	)

	var actions := CanvasLayer.new()
	actions.name = "NightStubActions"
	actions.layer = 41
	add_child(actions)

	# Mouse-reachable non-lethal closes (discoverability policy; no hotkey required).
	_surrender_button = _make_outcome_button(
		"SurrenderButton", "Surrender", EncounterOutcome.KIND_SURRENDER, Vector2(170, 640)
	)
	_escape_button = _make_outcome_button(
		"EscapeButton", "Escape", EncounterOutcome.KIND_ESCAPE, Vector2(300, 640)
	)
	_bypass_button = _make_outcome_button(
		"BypassButton", "Bypass", EncounterOutcome.KIND_BYPASS, Vector2(430, 640)
	)
	actions.add_child(_surrender_button)
	actions.add_child(_escape_button)
	actions.add_child(_bypass_button)

	# Mouse-reachable failure retry (discoverability policy; no hotkey required).
	_retry_button = Button.new()
	_retry_button.name = "RetryCheckpointButton"
	_retry_button.text = "Retry"
	_retry_button.tooltip_text = (
		"Restore the armed encounter checkpoint: keep completed dialogue and prior quest state"
	)
	_retry_button.position = Vector2(560, 640)
	_retry_button.custom_minimum_size = Vector2(120, 36)
	_retry_button.visible = false
	_retry_button.pressed.connect(func() -> void: retry_from_checkpoint())
	actions.add_child(_retry_button)


func _make_outcome_button(
	node_name: String, label: String, kind: StringName, pos: Vector2
) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = label
	button.tooltip_text = (
		"Resolve encounter via %s without killing; updates quest.bitter_brew from ContentDB"
		% EncounterOutcome.display_name(kind)
	)
	button.position = pos
	button.custom_minimum_size = Vector2(120, 36)
	button.pressed.connect(func() -> void: resolve_encounter_outcome(kind))
	return button


func _wire_signals() -> void:
	if player != null and not player.died.is_connected(_on_player_died):
		player.died.connect(_on_player_died)
	for enemy in [watchman, sergeant]:
		if enemy == null:
			continue
		if not enemy.feedback_event.is_connected(_on_enemy_feedback):
			enemy.feedback_event.connect(_on_enemy_feedback)


func _reset_combat_actors() -> void:
	if player != null:
		player.global_position = PLAYER_SPAWN
		player._facing_direction = Vector2.RIGHT
		player.health = player.max_health
		player.stamina = player.max_stamina
		player.combat_vitals.configure(
			player.health, player.max_health, player.stamina, player.max_stamina
		)
		player.action_state_machine.reset()
	if watchman != null:
		watchman.global_position = WATCHMAN_POS
		watchman.reset_actor()
		watchman.set_ai_target(player)
	if sergeant != null:
		sergeant.global_position = SERGEANT_POS
		sergeant.reset_actor()
		sergeant.set_ai_target(player)


func _on_player_died() -> void:
	# Why: failure must not write an encounter outcome; Retry restores the arm
	# snapshot so completed dialogue and prior quest state stay intact.
	if encounter_checkpoint.mark_failed():
		_set_retry_visible(true)
		if feedback != null:
			feedback.push_event("Player down. Retry restores the armed checkpoint.")
			feedback.set_status("Failed. Use Retry to restore checkpoint.")


func _set_retry_visible(visible: bool) -> void:
	if _retry_button != null:
		_retry_button.visible = visible
		_retry_button.disabled = not visible


func _on_enemy_feedback(text: String) -> void:
	if feedback != null:
		feedback.push_event(text)


func _process(delta: float) -> void:
	if player == null:
		return
	advance_enemies(delta)
