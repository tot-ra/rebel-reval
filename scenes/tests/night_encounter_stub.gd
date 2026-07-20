extends Node2D

class_name NightEncounterStub

## Optional night-encounter host for P1-025b / P2-009.
## Why: keep watchman/sergeant AI on CombatRoomEnemy outside the combat smoke
## room so night consequence can reuse the same machine without forking AI.
## Remains unreachable from release demo navigation (not in the transition
## manifest). Checkpoint retry wiring stays P1-027a.

const PLAYER_SCENE := preload("res://player.tscn")
const ENEMY_SCRIPT := preload("res://scripts/combat/combat_room_enemy.gd")
const FEEDBACK_HUD_SCRIPT := preload("res://scripts/combat/combat_feedback_hud.gd")

const PLAYER_SPAWN := Vector2(640.0, 360.0)
const WATCHMAN_POS := Vector2(420.0, 480.0)
const SERGEANT_POS := Vector2(860.0, 240.0)
## Stable scene path used by reachability assertions; keep out of the manifest.
const SCENE_PATH := "res://scenes/tests/night_encounter_stub.tscn"

var player: Player
var watchman: CombatRoomEnemy
var sergeant: CombatRoomEnemy
var feedback: CombatFeedbackHud
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
	if feedback != null:
		feedback.clear_log()
		feedback.push_event("Night stub ready. Watchman + Sergeant online.")
		feedback.set_status("Night route host. Approach an enemy to start AI.")


func get_player() -> Player:
	return player


func get_watchman() -> CombatRoomEnemy:
	return watchman


func get_sergeant() -> CombatRoomEnemy:
	return sergeant


func get_feedback() -> CombatFeedbackHud:
	return feedback


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
	feedback.set_title("Night encounter stub (P1-025b)")
	feedback.set_controls_text(
		"Developer night host for watchman/sergeant AI.\n"
		+ "Not reachable from Start / release demo navigation.\n"
		+ "Approach Watchman (gold) or Sergeant (magenta).\n"
		+ "Checkpoint retry wiring: P1-027a."
	)


func _wire_signals() -> void:
	for enemy in [watchman, sergeant]:
		if enemy == null:
			continue
		if not enemy.feedback_event.is_connected(_on_enemy_feedback):
			enemy.feedback_event.connect(_on_enemy_feedback)


func _on_enemy_feedback(text: String) -> void:
	if feedback != null:
		feedback.push_event(text)
