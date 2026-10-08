class_name AlmshouseOpening
extends Node
## New-game opening (ADR 0033): the almshouse of the Holy Spirit. A short year card, then
## straight into the hero's first spirit duel against the porter, fought with spells (each
## reply is a cast, the spoken line only voices it), then Kalev takes him in and a closing
## cutscene walks him to the forge. `ui_cancel` on the year card skips straight to the forge.
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
## The hero's first magic. The duel needs these as replies, so the opening grants them
## itself instead of relying on the forge's later seeding.
const STARTER_GRANTS: Array[StringName] = [
	&"magic.grant.starter_fireball",
	&"magic.grant.starter_earth_tremor",
	&"magic.grant.starter_iron_skin",
]
const DUEL_WILLPOWER := 8

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


func _ready() -> void:
	_state = SessionState.state
	_db = SessionState.content_db
	_build_title_card()


func _process(delta: float) -> void:
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
	_host = SpiritArenaHost.new()
	_host.freeze_world = false
	add_child(_host)
	_host.closed.connect(_on_confrontation_closed)
	if _host.open(_db, _state, CONFRONTATION):
		return true
	_host.queue_free()
	_begin_kalev()
	return false


## Skip the whole opening (ui_cancel on the year card).
func skip() -> void:
	_skipped = true
	if _title_layer != null:
		_title_layer.visible = false
	_state.set_flag(&"flag.prologue.apprenticed", true)
	_finish()


func host() -> SpiritArenaHost:
	return _host


func dialogue_ui() -> Node:
	return _dialogue_ui


func dialogue_runner() -> Node:
	return _runner


func _on_confrontation_closed(_outcome: Dictionary) -> void:
	_host.queue_free()
	_begin_kalev()


func _begin_kalev() -> void:
	_set_stage(STAGE_KALEV)
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
	finished.emit()
	if not auto_continue:
		return
	# The closing cutscene walks the boy to the forge and owns the door transition through
	# its own `next` block; a skip or a missing record falls straight through to the door.
	if not _skipped:
		var closing := CutscenePlayer.new()
		add_child(closing)
		if closing.play_id(_db, CLOSING_CUTSCENE):
			return
		closing.queue_free()
	DoorNavigator.go_to_scene(NEXT_SCENE_ID, NEXT_SPAWN_ID)


func _set_stage(next: StringName) -> void:
	stage = next
	stage_changed.emit(next)


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
