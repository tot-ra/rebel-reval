class_name SmithyOpening
extends Node
## New-game opening in the seamless city (R-1872, supersedes the almshouse hall as the New Game
## path): the boy has run from the almshouse into Kalev's smithy with the loaf and the key, and
## the porter Hanß bursts in after him. The spirit duel is fought right there, by the hearth,
## with the normal city Player: same camera, movement, roll and guard. The duel is a combat mode
## over normal play, not a separate scene. Kalev then walks in from the living room and takes
## the boy as his apprentice; play simply continues in the smithy. R-1877: Kalev's arrival is
## framed by a ConversationShot (eye-level camera in the same world, grade, depth blur,
## letterbox) instead of a staged scene; the porter is gone at the cut, as Kalev's lines say.
## The duel rules, guilt and dialogues are the prologue's (AlmshouseOpening constants); only the
## place changed. Holding `ui_cancel` skips (the press is eaten so the pause menu stays shut).

signal stage_changed(stage: StringName)
signal finished

const STAGE_WAITING := &"waiting"
const STAGE_CONFRONTATION := &"confrontation"
const STAGE_KALEV := &"kalev"
const STAGE_DONE := &"done"

const SPAWN_ID := "kalev_smithy"
const PORTER_SCENE := preload("res://assets/characters/variants/citizen_m_adult_heavy.tscn")
const KALEV_SCENE := preload("res://assets/characters/kalev/kalev.tscn")
const PORTER_SPEAKER_ID := &"char.almshouse_porter"
const SpiritSightScript := preload("res://scripts/combat/spirit_sight.gd")
const ConversationShotScript := preload("res://scripts/prologue/conversation_shot.gd")
## The porter stops this far in front of the boy (toward the yard door he came through).
const PORTER_STEP := 2.6
## The forge bay is about 7.7 x 8.2 m; the disc stays inside it, walls keep their collision.
const ARENA_RADIUS := 3.2
## The porter stands this far (radians) to the side of the camera's line through the boy.
const PORTER_ANGLE := 0.6
## Kalev comes in from the living room: this far behind and beside the boy (site-local metres).
const KALEV_OFFSET := Vector2(-2.4, -1.2)
## Frames to wait after the city is ready so the runtime has mirrored the player rig.
const SETTLE_FRAMES := 3
const HIT_RECOVER_SEC := 0.5

## Set by the main menu before it loads the city; the city consumes it once in _ready.
static var pending := false

var stage: StringName = STAGE_WAITING

var _state: GameState
var _db: ContentDB
var _city: Node
var _player: Node2D
var _host: SpiritArenaHost
var _porter: Node3D
var _kalev: Node3D
var _runner: Node
var _dialogue_ui: Node
var _cancel_held := 0.0
var _hint_layer: CanvasLayer
var _shot: Node
var _arena_center := Vector3.ZERO


## The menu's New Game: arm the opening and arrive in the smithy.
static func start_new_game(navigator: Node) -> void:
	pending = true
	navigator.call(&"go_to_scene", &"reval_city", StringName(SPAWN_ID))


## Called by the city level. Returns the opening when one was pending (and mounts it).
static func consume(city: Node) -> SmithyOpening:
	if not pending:
		return null
	pending = false
	var opening := SmithyOpening.new()
	opening.name = "SmithyOpening"
	city.add_child(opening)
	return opening


func _ready() -> void:
	_city = get_parent()
	_player = _city.get(&"player") as Node2D
	var session := get_node_or_null(^"/root/SessionState")
	if session != null:
		_state = session.state
		_db = session.content_db
	for _frame in SETTLE_FRAMES:
		await get_tree().process_frame
	if is_inside_tree():
		begin_duel()


func _process(delta: float) -> void:
	if stage == STAGE_CONFRONTATION or stage == STAGE_KALEV:
		_cancel_held = _cancel_held + delta if Input.is_action_pressed(&"ui_cancel") else 0.0
		if _cancel_held >= AlmshouseOpening.HOLD_TO_SKIP_SEC:
			skip()


## WHY _input: in the city Esc opens the pause menu from _unhandled_input; while the opening
## runs Esc means "hold to skip", so its press is consumed before the menu sees it.
func _input(event: InputEvent) -> void:
	if stage != STAGE_CONFRONTATION and stage != STAGE_KALEV:
		return
	if event.is_action(&"ui_cancel"):
		get_viewport().set_input_as_handled()


## Spawn the porter in front of the boy and open the duel on a disc in the forge bay.
func begin_duel() -> bool:
	if stage != STAGE_WAITING or _state == null or _db == null or _player == null:
		return false
	for grant_id in AlmshouseOpening.STARTER_GRANTS:
		MagicResolver.apply_grant_operation(_state, _db, grant_id)
	_state.set_magic_resource(GameState.MAGIC_RESOURCE_WILLPOWER, AlmshouseOpening.DUEL_WILLPOWER)
	_set_stage(STAGE_CONFRONTATION)
	_show_skip_hint()
	var world := _world()
	var hero_rig := get_tree().get_first_node_in_group(&"player_view_rig") as Node3D
	var floor_y := hero_rig.global_position.y if hero_rig != null else 0.0
	var hero_at := _hero_world(floor_y)
	# Off the camera axis so the boy's own rig and aura never hide the porter behind him.
	var facing := _camera_facing().rotated(PORTER_ANGLE)
	var porter_at := hero_at + Vector3(facing.x, 0.0, facing.y) * PORTER_STEP
	_porter = _place_actor(PORTER_SCENE, "Porter", world, porter_at, hero_at, PORTER_SPEAKER_ID)
	_host = SpiritArenaHost.new()
	_host.model_front_plus_z = true
	add_child(_host)
	_host.closed.connect(_on_confrontation_closed)
	var keep: Array[Node3D] = [_porter]
	if hero_rig != null:
		keep.append(hero_rig)
	var center := (hero_at + porter_at) * 0.5
	_arena_center = center
	# The city player is a logic-plane body: 32 logic px per world metre (CityPlan).
	if _host.attach_arena(
		world, center, keep, true, _player, _porter, int(CityPlan.LOGIC_PX_PER_UNIT), ARENA_RADIUS
	):
		# R-1764: the porter's visible soul lights are the ones the duel scores.
		if is_instance_valid(_host.opponent_aura_view) and _host.opponent_aura_view.profile != null:
			_host.opponent_aura = _host.opponent_aura_view.profile
	if _host.open_scripted(_db, _state, AlmshouseOpening.CONFRONTATION):
		var camera := get_viewport().get_camera_3d()
		if camera != null:
			_host.form_view().track_3d(camera, _porter)
		_host.duel.exchange_resolved.connect(_react_to_exchange)
		return true
	_host.detach_arena()
	_host.queue_free()
	_host = null
	_begin_kalev()
	return false


func skip() -> void:
	if stage == STAGE_DONE:
		return
	if _host != null and is_instance_valid(_host):
		_host.closed.disconnect(_on_confrontation_closed)
		_host.close()
		_host.queue_free()
		_host = null
	if _runner != null and is_instance_valid(_runner):
		_runner.finished.disconnect(_on_kalev_finished)
		_runner.queue_free()
		_runner = null
	if _dialogue_ui != null and is_instance_valid(_dialogue_ui):
		_dialogue_ui.queue_free()
		_dialogue_ui = null
	AlmshouseOpening.record_duel_guilt(_state)
	var sight := get_tree().get_first_node_in_group(SpiritSightScript.SIGHT_GROUP)
	if sight != null:
		sight.call(&"leave_immediately")
	_state.set_flag(&"flag.prologue.apprenticed", true)
	_finish()


func host() -> SpiritArenaHost:
	return _host


func porter() -> Node3D:
	return _porter


func kalev() -> Node3D:
	return _kalev


func dialogue_runner() -> Node:
	return _runner


func _on_confrontation_closed(_outcome: Dictionary) -> void:
	AlmshouseOpening.record_duel_guilt(_state)
	_host.queue_free()
	_host = null
	_begin_kalev()


func _begin_kalev() -> void:
	_set_stage(STAGE_KALEV)
	# Dialogue closes spirit sight (ADR 0041 section 2): the reverse ripple plays as he enters.
	var sight := get_tree().get_first_node_in_group(SpiritSightScript.SIGHT_GROUP)
	if sight != null and _state.spirit_sight:
		sight.call(&"set_enabled", false)
	_bring_in_kalev()
	# He "went out of my door": the porter leaves at the cut to Kalev.
	_free_porter()
	_frame_conversation()
	_dialogue_ui = DialogueUI.new()
	add_child(_dialogue_ui)
	_dialogue_ui.apply_settings(UserSettings.dialogue)
	# R-1888: Kalev's lines cut to him over the boy's shoulder; a reply cuts to the boy.
	_dialogue_ui.line_shown.connect(_on_line_shown)
	_dialogue_ui.choices_shown.connect(_on_choices_shown)
	_runner = DialogueRunner.new()
	add_child(_runner)
	var presenter := DialogueUiPresenter.new()
	presenter.configure(_dialogue_ui, _runner)
	_runner.configure(_db, _state, presenter)
	_runner.finished.connect(_on_kalev_finished)
	if not _runner.start(AlmshouseOpening.KALEV_ARRIVES):
		_state.set_flag(&"flag.prologue.apprenticed", true)
		_finish()


func _on_kalev_finished(_dialogue_id: StringName) -> void:
	_finish()


## The porter leaves; Kalev stays in his forge. Play continues where the boy stands.
func _finish() -> void:
	if stage == STAGE_DONE:
		return
	_set_stage(STAGE_DONE)
	if _hint_layer != null:
		_hint_layer.visible = false
	_free_porter()
	if _shot != null and is_instance_valid(_shot):
		_shot.call(&"release")
		_shot.queue_free()
		_shot = null
	if _dialogue_ui != null and is_instance_valid(_dialogue_ui):
		_dialogue_ui.queue_free()
		_dialogue_ui = null
	finished.emit()


func _bring_in_kalev() -> void:
	if is_instance_valid(_kalev) or not is_instance_valid(_porter):
		return
	var hero_at := _hero_world(_porter.global_position.y)
	var facing := _spawn_facing()
	# Site-local offset turned into the spawn's frame: back (-facing) and to the side.
	var side := Vector2(-facing.y, facing.x)
	var offset := facing * KALEV_OFFSET.x + side * KALEV_OFFSET.y
	var at := hero_at + Vector3(offset.x, 0.0, offset.y)
	_kalev = _place_actor(KALEV_SCENE, "Kalev", _world(), at, hero_at)


## Cuts to an eye-level shot of the boy and Kalev in the forge bay, kept inside the arena disc
## so the camera stays in the room.
func _frame_conversation() -> void:
	if not is_instance_valid(_kalev):
		return
	var hero_rig := get_tree().get_first_node_in_group(&"player_view_rig") as Node3D
	var hero_at := (
		hero_rig.global_position if hero_rig != null
		else _hero_world(_kalev.global_position.y)
	)
	# The boy turns to the man who is speaking to him (logic plane shares the world's x/z axes).
	var toward := Vector2(_kalev.global_position.x - hero_at.x, _kalev.global_position.z - hero_at.z)
	if _player.has_method(&"set_view_facing"):
		_player.call(&"set_view_facing", toward)
	_shot = ConversationShotScript.new()
	_shot.name = "ConversationShot"
	add_child(_shot)
	var subjects: Array[Node3D] = [_kalev]
	if hero_rig != null:
		subjects.push_front(hero_rig)
	_shot.call(&"frame_subjects", _world(), subjects, _arena_center, ARENA_RADIUS, self)


func _on_line_shown(speaker_id: StringName) -> void:
	if _shot == null or not is_instance_valid(_shot):
		return
	if speaker_id == &"char.kalev" and is_instance_valid(_kalev):
		_shot.call(&"cue_line", _kalev)


func _on_choices_shown() -> void:
	var hero_rig := get_tree().get_first_node_in_group(&"player_view_rig") as Node3D
	if _shot != null and is_instance_valid(_shot) and hero_rig != null:
		_shot.call(&"focus", hero_rig)


func shot() -> Node:
	return _shot


func _free_porter() -> void:
	if is_instance_valid(_porter):
		_porter.queue_free()
	_porter = null


func _react_to_exchange(result: Dictionary) -> void:
	# Words and spells that cost the porter pressure make him flinch (same rule as
	# AlmshouseStage.react_to_exchange); the boy's own rig belongs to the city runtime.
	if not is_instance_valid(_porter):
		return
	var kind := String(result.get("kind", ""))
	var hurt := (
		(kind in ["reply", "word"] and float(result.get("damage", 0.0)) > 0.0)
		or (kind == "spell" and String(result.get("arena_effect", "")) in ["pressure", "stagger"])
	)
	if not hurt:
		return
	if _porter.has_method(&"play_animation") and _porter.call(&"play_animation", &"hit"):
		get_tree().create_timer(HIT_RECOVER_SEC).timeout.connect(_recover_porter)


func _recover_porter() -> void:
	if is_instance_valid(_porter) and _porter.call(&"current_canonical_animation") == &"hit":
		_porter.call(&"play_animation", &"idle")


func _world() -> Node3D:
	var world := _city.get(&"world") as Node3D
	return world if world != null else _city.get_viewport().find_world_3d() as Node3D


func _hero_world(floor_y: float) -> Vector3:
	var xz := CityPlan.to_world_xz(_player.global_position)
	return Vector3(xz.x, floor_y, xz.y)


## Where the gameplay camera looks, flattened. The porter stands that way from the boy so the
## third-person camera sees the boy's back and the porter's face, never the porter's back.
func _camera_facing() -> Vector2:
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera != null:
		var forward := -camera.global_basis.z
		var flat := Vector2(forward.x, forward.z)
		if not flat.is_zero_approx():
			return flat.normalized()
	return _spawn_facing()


func _spawn_facing() -> Vector2:
	var plan: Variant = _city.get(&"plan")
	var site := CityTravel.site_spawn(plan, SPAWN_ID) if plan != null else {}
	var facing: Vector2 = site.get("facing", Vector2.ZERO)
	if facing.is_zero_approx() and _player.has_method(&"facing_direction"):
		facing = _player.call(&"facing_direction")
	return facing.normalized() if not facing.is_zero_approx() else Vector2.UP


func _place_actor(
	scene: PackedScene, actor_name: String, parent: Node3D, at: Vector3, look_at_point: Vector3,
	speaker_id: StringName = &""
) -> Node3D:
	var actor := scene.instantiate() as Node3D
	actor.name = actor_name
	# RealisticRig talks when the announced speaker equals its variant id; re-key a borrowed
	# crowd body on a copy so the shared variant resource stays untouched.
	if not speaker_id.is_empty() and actor.get(&"variant") is CharacterVariant:
		var keyed := (actor.get(&"variant") as CharacterVariant).duplicate() as CharacterVariant
		keyed.stable_id = speaker_id
		actor.set(&"variant", keyed)
	parent.add_child(actor)
	actor.global_position = at
	var direction := look_at_point - at
	# glTF rigs face +Z.
	actor.rotation.y = atan2(direction.x, direction.z)
	if actor.has_method(&"play_animation"):
		actor.call(&"play_animation", &"idle")
	return actor


func _set_stage(next: StringName) -> void:
	stage = next
	stage_changed.emit(next)


func _show_skip_hint() -> void:
	if _hint_layer != null:
		return
	_hint_layer = CanvasLayer.new()
	_hint_layer.layer = 91
	add_child(_hint_layer)
	var label := Label.new()
	label.text = "Hold Esc to skip the introduction"
	label.add_theme_font_size_override("font_size", 14)
	label.modulate = Color(1, 1, 1, 0.6)
	label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	label.position += Vector2(-16, 12)
	_hint_layer.add_child(label)
