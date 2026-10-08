class_name AlmshouseOpening
extends Node
## New-game opening (ADR 0033): the almshouse of the Holy Spirit. A short year card, then
## straight into the hero's first spirit duel against the porter, fought with spells (each
## reply is a cast, the spoken line only voices it), then Kalev takes him in and a closing
## cutscene walks him to the forge. `ui_cancel` on the year card skips straight to the forge;
## holding `ui_cancel` for HOLD_TO_SKIP_SEC skips from the duel or Kalev's dialogue too.
## The old observed quarrel and the dawn cutscene are no longer part of the flow (kept short
## on purpose); their records stay in content.

signal stage_changed(stage: StringName)
signal finished

const STAGE_TITLE := &"title"
const STAGE_CONFRONTATION := &"confrontation"
const STAGE_KALEV := &"kalev"
const STAGE_DONE := &"done"

const CONFRONTATION := &"dialogue.prologue.porter_confrontation"
const KALEV_ARRIVES := &"dialogue.prologue.kalev_arrives"
const CLOSING_CUTSCENE := &"cutscene.prologue.taken_in"
const NEXT_SCENE_ID := &"forge"
const NEXT_SPAWN_ID := &"smithy_start"
## The year card leaves on its own after this long; interact or a click leaves sooner.
const TITLE_CARD_SEC := 3.0
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

## Tests turn this off; the running game leaves the almshouse for the forge.
var auto_continue := true
var stage: StringName = STAGE_TITLE

var _state: GameState
var _db: ContentDB
var _host: SpiritArenaHost
var _runner: Node
var _dialogue_ui: Node
var _title_layer: CanvasLayer
var _title_left := TITLE_CARD_SEC
var _skipped := false
var _cancel_held := 0.0
var _hint_layer: CanvasLayer


func _ready() -> void:
	_state = SessionState.state
	_db = SessionState.content_db
	_build_title_card()


func _process(delta: float) -> void:
	if stage == STAGE_CONFRONTATION or stage == STAGE_KALEV:
		_cancel_held = _cancel_held + delta if Input.is_action_pressed(&"ui_cancel") else 0.0
		if _cancel_held >= HOLD_TO_SKIP_SEC:
			skip()
		return
	if stage != STAGE_TITLE:
		return
	_title_left -= delta
	if _title_left <= 0.0:
		begin_duel()


func _unhandled_input(event: InputEvent) -> void:
	if stage != STAGE_TITLE:
		return
	if event.is_action_pressed(&"ui_cancel"):
		skip()
		get_viewport().set_input_as_handled()
	elif (
		event.is_action_pressed(&"interact")
		or event.is_action_pressed(&"ui_accept")
		or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed)
	):
		begin_duel()
		get_viewport().set_input_as_handled()


## Leave the year card and fight the porter with the hero's first spells.
func begin_duel() -> bool:
	if stage != STAGE_TITLE:
		return false
	if _title_layer != null:
		_title_layer.visible = false
	for grant_id in STARTER_GRANTS:
		MagicResolver.apply_grant_operation(_state, _db, grant_id)
	_state.set_magic_resource(GameState.MAGIC_RESOURCE_WILLPOWER, DUEL_WILLPOWER)
	_set_stage(STAGE_CONFRONTATION)
	_show_skip_hint()
	_host = SpiritArenaHost.new()
	_host.freeze_world = false
	add_child(_host)
	_host.closed.connect(_on_confrontation_closed)
	if _host.open(_db, _state, CONFRONTATION):
		_pin_spirit_form()
		# R-1365: the staged actor an exchange hurts flinches (porter hit / hero hit).
		var staged := _stage()
		if staged != null:
			_host.duel.exchange_resolved.connect(staged.react_to_exchange)
		return true
	_host.queue_free()
	_begin_kalev()
	return false


## Skip the whole opening (ui_cancel on the year card, or held during the duel / dialogue).
func skip() -> void:
	if stage == STAGE_DONE:
		return
	_skipped = true
	if _title_layer != null:
		_title_layer.visible = false
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
	# Before the runner starts, so Kalev's rig is in the speaker group for his first line.
	var staged := _stage()
	if staged != null:
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
	# The closing cutscene walks the boy to the forge and owns the door transition through
	# its own `next` block; a skip or a missing record falls straight through to the door.
	if not _skipped:
		# Parsed with the session state so the lines conditioned on the duel's outcome
		# (`flag.prologue.*_porter`) echo the ending the player actually reached.
		var sequence := CutsceneSequence.from_record(_db.get_cutscene(CLOSING_CUTSCENE), _state)
		if sequence != null:
			var closing := CutscenePlayer.new()
			add_child(closing)
			closing.play(sequence)
			return
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


func _build_title_card() -> void:
	_title_layer = CanvasLayer.new()
	_title_layer.layer = 90
	add_child(_title_layer)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.04, 0.03, 0.06, 1.0)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title_layer.add_child(backdrop)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 18)
	_title_layer.add_child(column)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for entry: Array in [
		["REVAL, SPRING 1343", 40],
		["The almshouse of the Holy Spirit", 24],
		["", 18],
		["You see what others do not. Answer with what you can do.", 20],
		["", 18],
		["Press interact to begin  (Esc skips to the forge)", 16],
	]:
		var label := Label.new()
		label.text = String(entry[0])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", int(entry[1]))
		column.add_child(label)
