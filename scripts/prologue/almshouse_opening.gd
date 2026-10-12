class_name AlmshouseOpening
extends Node
## New-game opening (ADR 0033): the player starts directly in the almshouse spirit duel,
## then Kalev takes him in and play continues at the forge. Holding `ui_cancel` for
## HOLD_TO_SKIP_SEC skips from the duel or Kalev's dialogue to the forge.
## R-1389 (ADR 0038): with the staged hall mounted the duel is fought on the 3D spirit disc:
## the hall is stripped to the floor disc, the boy walks (move keys), guards facing the porter
## (`player_guard`) and dashes out of red strike zones (`player_dodge`) while the porter moves
## by his lines. The duel's `topic` (the rusted key) makes on-topic replies land harder.
## R-1490 (ADR 0041): the duel is scripted, so the opening mounts a spirit-sight controller and
## opens the arena through `SpiritArenaHost.open_scripted` (sight and its ripple first); sight
## ends with the reverse ripple when Kalev walks in, since dialogue closes spirit sight.
## The old observed quarrel and the dawn cutscene are no longer part of the flow (kept short
## on purpose); their records stay in content.

signal stage_changed(stage: StringName)
signal finished

const STAGE_CONFRONTATION := &"confrontation"
const STAGE_KALEV := &"kalev"
const STAGE_DONE := &"done"

const CONFRONTATION := &"dialogue.prologue.porter_confrontation"
const KALEV_ARRIVES := &"dialogue.prologue.kalev_arrives"
## The new game opens in the seamless city, inside Kalev's smithy: the forge bay
## of the landmark site `site.kalev_smithy`, at the hearth.
const NEXT_SCENE_ID := &"reval_city"
const NEXT_SPAWN_ID := &"kalev_smithy"
## Holding `ui_cancel` this long during the duel or Kalev's dialogue skips the rest.
const HOLD_TO_SKIP_SEC := 0.8
## The hero's first magic. The duel needs these as replies, so the opening grants them
## itself instead of relying on the forge's later seeding.
const STARTER_GRANTS: Array[StringName] = [
	&"magic.grant.starter_fireball",
	&"magic.grant.starter_earth_tremor",
	&"magic.grant.starter_iron_skin",
]
const DUEL_WILLPOWER := 8
## The physical answer in the duel (`[Shove him away]`) only sets a dialogue flag; the
## opening turns it into guilt the same way a melee blow on an unarmed target would
## (PhysicalBlowGuilt's `act.<actor>.blow` id, so it records once per save).
const FLAG_STRUCK_PORTER := &"flag.prologue.struck_porter"
const PORTER_BLOW_ACT := &"act.almshouse_porter.blow"
const PORTER_BLOW_CIRCUMSTANCE := &"act.unarmed_victim"
const SpiritSightScript := preload("res://scripts/combat/spirit_sight.gd")

## Tests turn this off; the running game leaves the almshouse for the forge.
var auto_continue := true
var stage: StringName = STAGE_CONFRONTATION

var _state: GameState
var _db: ContentDB
var _host: SpiritArenaHost
var _sight: Node
var _runner: Node
var _dialogue_ui: Node
var _skipped := false
var _cancel_held := 0.0
var _hint_layer: CanvasLayer


func _ready() -> void:
	_state = SessionState.state
	_db = SessionState.content_db
	begin_duel()


func _process(delta: float) -> void:
	if stage == STAGE_CONFRONTATION:
		_drive_hero(delta)
	if stage == STAGE_CONFRONTATION or stage == STAGE_KALEV:
		_cancel_held = _cancel_held + delta if Input.is_action_pressed(&"ui_cancel") else 0.0
		if _cancel_held >= HOLD_TO_SKIP_SEC:
			skip()


## Fight the porter with the hero's first spells.
func begin_duel() -> bool:
	if stage != STAGE_CONFRONTATION:
		return false
	if _host != null:
		return true
	for grant_id in STARTER_GRANTS:
		MagicResolver.apply_grant_operation(_state, _db, grant_id)
	_state.set_magic_resource(GameState.MAGIC_RESOURCE_WILLPOWER, DUEL_WILLPOWER)
	_set_stage(STAGE_CONFRONTATION)
	_show_skip_hint()
	# Sight and its ripple come first, before the arena is mounted (ADR 0041 section 1).
	_mount_sight()
	_sight.call(&"enter_for_script")
	_host = SpiritArenaHost.new()
	_host.freeze_world = false
	add_child(_host)
	_host.closed.connect(_on_confrontation_closed)
	var staged := _stage()
	if staged != null:
		_mount_arena(staged)
	if _host.open_scripted(_db, _state, CONFRONTATION):
		_pin_spirit_form()
		# R-1365: the staged actor an exchange hurts flinches (porter hit / hero hit).
		if staged != null:
			_host.duel.exchange_resolved.connect(staged.react_to_exchange)
		return true
	_host.detach_arena()
	_host.queue_free()
	_begin_kalev()
	return false


## Skip the whole opening (held during the duel / dialogue).
func skip() -> void:
	if stage == STAGE_DONE:
		return
	_skipped = true
	if _hint_layer != null:
		_hint_layer.visible = false
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
	record_duel_guilt(_state)
	if _sight != null and is_instance_valid(_sight):
		_sight.call(&"leave_immediately")
	_state.set_flag(&"flag.prologue.apprenticed", true)
	_finish()


## Turn the duel's physical outcome into guilt. Returns the weights applied ({} when the
## porter was not struck or the blow was already recorded).
static func record_duel_guilt(state: GameState) -> Dictionary:
	if state == null or not state.get_flag(FLAG_STRUCK_PORTER):
		return {}
	return state.guilt.record_act(PORTER_BLOW_ACT, PORTER_BLOW_CIRCUMSTANCE)


func host() -> SpiritArenaHost:
	return _host


func dialogue_ui() -> Node:
	return _dialogue_ui


func dialogue_runner() -> Node:
	return _runner


## The staged hall (child `Stage`), or null when the scene is mounted without it.
func _stage() -> AlmshouseStage:
	return get_node_or_null(^"Stage") as AlmshouseStage


## Fight on the spirit disc in the hall: indoors, so walls, furniture and the hall floor are
## hidden while the stage lights stay; the two rigs are the fighters (glTF rigs face +Z).
func _mount_arena(staged: AlmshouseStage) -> void:
	_host.model_front_plus_z = true
	var keep: Array[Node3D] = [staged.hero(), staged.porter()]
	if _host.attach_arena(
		staged, Vector3.ZERO, keep, true, staged.hero(), staged.porter(), 1, AlmshouseStage.ARENA_RADIUS
	):
		staged.frame_arena()
		# R-1764: the porter's visible soul lights are the ones the duel scores, so a word into
		# a dim light really lands harder (SS-5); without this the duel used a neutral soul.
		if is_instance_valid(_host.opponent_aura_view) and _host.opponent_aura_view.profile != null:
			_host.opponent_aura = _host.opponent_aura_view.profile


## The hall has no Player (whose SpiritSight child the city uses), so the opening owns one for
## the scripted duel. The player cannot toggle it here: the prologue decides when sight opens.
func _mount_sight() -> void:
	if _sight != null and is_instance_valid(_sight):
		return
	_sight = SpiritSightScript.new()
	_sight.name = "SpiritSight"
	add_child(_sight)
	_sight.set_process_unhandled_input(false)


## The boy's footwork while the arena duel is open (SpiritArenaHost clamps him to the disc).
func _drive_hero(delta: float) -> void:
	var staged := _stage()
	if staged == null or _host == null or not is_instance_valid(_host) or _host.motion == null:
		return
	var direction := ScreenDirectionInput.read_axis()
	if Input.is_action_just_pressed(&"player_dodge"):
		staged.dash_hero(direction)
	staged.move_hero(direction, Input.is_action_pressed(&"player_guard"), delta)


## When the staged hall is mounted, the porter's spirit image looms over the staged actor
## instead of a drawn silhouette.
func _pin_spirit_form() -> void:
	var staged := _stage()
	if staged == null:
		return
	_host.form_view().track_3d(staged.camera(), staged.porter())


func _on_confrontation_closed(_outcome: Dictionary) -> void:
	record_duel_guilt(_state)
	_host.queue_free()
	_begin_kalev()


func _begin_kalev() -> void:
	_set_stage(STAGE_KALEV)
	# Dialogue closes spirit sight (ADR 0041 section 2): the reverse ripple plays as he enters.
	if _sight != null and is_instance_valid(_sight) and _state.spirit_sight:
		_sight.call(&"set_enabled", false)
	# Before the runner starts, so Kalev's rig is in the speaker group for his first line.
	var staged := _stage()
	if staged != null:
		staged.end_arena()
		staged.bring_in_kalev()
	_dialogue_ui = DialogueUI.new()
	add_child(_dialogue_ui)
	_dialogue_ui.apply_settings(UserSettings.dialogue)
	_runner = DialogueRunner.new()
	add_child(_runner)
	var presenter := DialogueUiPresenter.new()
	presenter.configure(_dialogue_ui, _runner)
	_runner.configure(_db, _state, presenter)
	_runner.finished.connect(_on_kalev_finished)
	if not _runner.start(KALEV_ARRIVES):
		_state.set_flag(&"flag.prologue.apprenticed", true)
		_finish()


func _on_kalev_finished(_dialogue_id: StringName) -> void:
	_finish()


func _finish() -> void:
	if stage == STAGE_DONE:
		return
	_set_stage(STAGE_DONE)
	if _hint_layer != null:
		_hint_layer.visible = false
	finished.emit()
	if not auto_continue:
		return
	# No still-image/text inserts: continue directly to the smithy after the dialogue.
	DoorNavigator.go_to_scene(NEXT_SCENE_ID, NEXT_SPAWN_ID)


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
