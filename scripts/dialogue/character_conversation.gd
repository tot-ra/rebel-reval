class_name CharacterConversation
extends Node
## Talk, or a spirit duel, with any person in the city (R-1887, R-1889, ADR 0047).
##
## Peaceful (weapon sheathed): a click or `interact` on a resident or named NPC within reach
## opens `dialogue.city.small_talk`. The person stops and turns to the hero, ConversationShot
## frames both, and each line cuts to its speaker; the generic speaker `char.interlocutor`
## shows the person's own name and portrait, and the `{interlocutor_*}` tokens carry who they
## are. The reply `inner_eye` turns the talk into a spirit duel: the camera cranes up to the
## gameplay view and `dialogue.city.spirit_duel` opens in place against that person. In spirit
## sight the click opens the duel directly. Nothing is saved: the person resumes the day after.

signal ended(outcome: StringName)

const ConversationShotScript := preload("res://scripts/prologue/conversation_shot.gd")
const SMALL_TALK := &"dialogue.city.small_talk"
const SPIRIT_DUEL := &"dialogue.city.spirit_duel"
const INTERLOCUTOR := &"char.interlocutor"
## The small-talk reply that looks at the person with the inner eye.
const INNER_EYE_CHOICE := "inner_eye"
## Present while a conversation or its duel runs (named-NPC markers hide on it).
const ACTIVE_GROUP := &"dialogue_active"
## Talk is offered this close (metres); further away a click only shows the person's card.
const TALK_REACH_M := 4.0
const DUEL_RADIUS := 4.0

const OUTCOME_TALK := &"talk"
const OUTCOME_DUEL := &"duel"
const OUTCOME_CANCELLED := &"cancelled"

const STAGE_IDLE := &"idle"
const STAGE_TALK := &"talk"
const STAGE_RISING := &"rising"
const STAGE_DUEL := &"duel"
const STAGE_DONE := &"done"

var stage := STAGE_IDLE
## The person's logic-plane body (CitizenActor or NamedNpcActor) and its mirrored rig.
var person: Node2D
var rig: Node3D
## `name`, `title`, `side` (spoken line), `portrait` (Texture2D or null).
var info: Dictionary = {}
var shot: Node
var ui: DialogueUI
var runner: DialogueRunner
var host: SpiritArenaHost

var _player: Node2D
var _world: Node3D
var _keep: Array = []
var _escalate := false


## The conversation running now, or null.
static func active(tree: SceneTree) -> CharacterConversation:
	for node in tree.get_nodes_in_group(ACTIVE_GROUP):
		if node is CharacterConversation and (node as CharacterConversation).stage != STAGE_DONE:
			return node
	return null


static func in_reach(player: Node2D, body: Node2D) -> bool:
	if player == null or body == null:
		return false
	var metres := player.global_position.distance_to(body.global_position) / CityPlan.LOGIC_PX_PER_UNIT
	return metres <= TALK_REACH_M


## What a click on a person does now, for the hover tag: talk, strike or spirit duel.
static func action_hint(player: Node) -> String:
	if player == null:
		return ""
	if player.has_method(&"is_spirit_sight_active") and bool(player.call(&"is_spirit_sight_active")):
		return "E  Spirit duel"
	if &"weapon_drawn" in player and bool(player.get(&"weapon_drawn")):
		return "LMB  Strike"
	return "E  Talk"


## Starts a conversation with `body` (rig `view`) under `parent`: the spirit duel when the hero
## is in spirit sight, else the small talk. Null when nothing could open.
static func open_with(
	parent: Node, player: Node2D, body: Node2D, view: Node3D, who: Dictionary, keep: Array = []
) -> CharacterConversation:
	if parent == null or not parent.is_inside_tree() or active(parent.get_tree()) != null:
		return null
	var city := parent.get_tree().get_first_node_in_group(&"seamless_city")
	var world: Node3D = city.get(&"world") as Node3D if city != null else null
	if world == null and view != null:
		world = view.get_parent_node_3d()
	var conversation := CharacterConversation.new()
	conversation.name = "CharacterConversation"
	parent.add_child(conversation)
	conversation.setup(player, world, body, view, who, keep)
	var in_sight := (
		player != null and player.has_method(&"is_spirit_sight_active")
		and bool(player.call(&"is_spirit_sight_active"))
	)
	var opened := conversation.begin_duel() if in_sight else conversation.begin_talk()
	return conversation if opened else null


## The spoken answer to "who do you stand with?" for a faction display name ("" = none).
static func side_line(faction_name: String) -> String:
	if faction_name.is_empty():
		return "I keep to my own household and my trade."
	return "I stand with %s." % faction_name


## The hover / selection name tag over a person (R-1885): a constant small size on screen
## rather than a world-sized sign, so it never covers the crowd around the person.
static func make_tag() -> Label3D:
	var tag := Label3D.new()
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.fixed_size = true
	tag.pixel_size = 0.0011
	tag.font_size = 26
	tag.outline_size = 8
	tag.line_spacing = -4.0
	tag.modulate = Color(1, 0.95, 0.8)
	tag.visible = false
	return tag


## Name, plus what a click does when the person is within reach.
static func tag_text(person_name: String, player: Node2D, body: Node2D) -> String:
	if not in_reach(player, body):
		return person_name
	return "%s\n%s" % [person_name, action_hint(player)]


## `keep`: canvas layers that stay up during the shot (the person's card).
func setup(
	player: Node2D, world: Node3D, body: Node2D, view: Node3D, who: Dictionary, keep: Array = []
) -> void:
	_player = player
	_world = world
	person = body
	rig = view
	info = who
	_keep = keep


## Opens the small talk. False (and the node frees itself) when the record is missing.
func begin_talk() -> bool:
	if stage != STAGE_IDLE:
		return false
	stage = STAGE_TALK
	_begin()
	ui = DialogueUI.new()
	add_child(ui)
	ui.apply_settings(UserSettings.dialogue)
	# The visible dialogue layer blocks walking (Player._movement_blocked).
	ui.add_to_group(&"modal_input_overlay")
	var portrait: Variant = info.get("portrait")
	if portrait is Texture2D:
		ui.portrait_overrides[INTERLOCUTOR] = portrait
	ui.line_shown.connect(_on_line_shown)
	ui.choices_shown.connect(_on_choices_shown)
	# Connected before the presenter, so the choice is seen before the runner moves on.
	ui.choice_selected.connect(_on_choice_selected)
	_frame()
	runner = DialogueRunner.new()
	add_child(runner)
	runner.speaker_names = _speaker_names()
	runner.text_tokens = tokens()
	var presenter := DialogueUiPresenter.new()
	presenter.configure(ui, runner)
	runner.configure(SessionState.content_db, SessionState.state, presenter)
	runner.finished.connect(_on_talk_finished)
	if not runner.start(SMALL_TALK):
		_end(OUTCOME_CANCELLED)
		return false
	return true


## Opens the spirit duel straight away (the hero clicked the person in spirit sight).
func begin_duel() -> bool:
	if stage != STAGE_IDLE:
		return false
	_begin()
	return _open_duel()


## `{interlocutor_*}` tokens for the generic records.
func tokens() -> Dictionary:
	var title := String(info.get("title", ""))
	if not title.is_empty():
		title = title.substr(0, 1).to_lower() + title.substr(1)
	return {
		"interlocutor_name": String(info.get("name", "")),
		"interlocutor_title": title,
		"interlocutor_side": String(info.get("side", "")),
	}


func _speaker_names() -> Dictionary:
	return {INTERLOCUTOR: String(info.get("name", "Townsperson"))}


func _begin() -> void:
	add_to_group(ACTIVE_GROUP)
	# Talking sheathes the weapon (the gamepad's way to put it away).
	if _player != null and _player.has_method(&"set_weapon_drawn"):
		_player.call(&"set_weapon_drawn", false)
	if is_instance_valid(person) and person.has_method(&"hold_for_talk"):
		person.call(&"hold_for_talk", _player)
	if _player != null and _player.has_method(&"set_view_facing") and is_instance_valid(person):
		_player.call(&"set_view_facing", person.global_position - _player.global_position)


func _hero_rig() -> Node3D:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group(&"player_view_rig") as Node3D


func _frame() -> void:
	if _world == null or not is_instance_valid(rig):
		return
	for layer in _keep:
		if is_instance_valid(layer) and layer.has_method(&"dock_right"):
			layer.call(&"dock_right", true)
	var subjects: Array[Node3D] = [rig]
	var hero := _hero_rig()
	if hero != null:
		subjects.push_front(hero)
	shot = ConversationShotScript.new()
	shot.name = "ConversationShot"
	add_child(shot)
	var keep: Array = _keep.duplicate()
	keep.append(self)
	shot.call(&"frame_subjects", _world, subjects, Vector3.ZERO, 0.0, keep)


func _on_line_shown(speaker_id: StringName) -> void:
	if shot == null or not is_instance_valid(shot):
		return
	var speaker: Node3D = rig if speaker_id == INTERLOCUTOR else _hero_rig()
	if speaker != null:
		shot.call(&"cue_line", speaker)


func _on_choices_shown() -> void:
	var hero := _hero_rig()
	if shot != null and is_instance_valid(shot) and hero != null:
		shot.call(&"focus", hero)


func _on_choice_selected(choice_id: String) -> void:
	if choice_id == INNER_EYE_CHOICE:
		_escalate = true


func _on_talk_finished(_dialogue_id: StringName) -> void:
	_free_dialogue()
	if not _escalate:
		_end(OUTCOME_TALK)
		return
	# The talk turns into a duel: rise to the play view, then open the arena there.
	stage = STAGE_RISING
	if shot != null and is_instance_valid(shot) and shot.camera != null:
		shot.released.connect(_on_risen, CONNECT_ONE_SHOT)
		shot.call(&"release", ConversationShotScript.CRANE_SEC)
	else:
		_on_risen()


func _on_risen() -> void:
	_free_shot()
	if not _open_duel():
		_end(OUTCOME_CANCELLED)


func _open_duel() -> bool:
	stage = STAGE_DUEL
	# The person's card would sit on top of the duel's captions.
	for layer in _keep:
		if is_instance_valid(layer) and layer.has_method(&"hide_panel"):
			layer.call(&"hide_panel")
	var hero := _hero_rig()
	if _world == null or not is_instance_valid(person) or not is_instance_valid(rig):
		_end(OUTCOME_CANCELLED)
		return false
	host = SpiritArenaHost.new()
	add_child(host)
	host.speaker_names = _speaker_names()
	var keep: Array[Node3D] = [rig]
	if hero != null:
		keep.append(hero)
	var center := rig.global_position
	if hero != null:
		center = (hero.global_position + rig.global_position) * 0.5
	if host.attach_arena(
		_world, center, keep, false, _player, person, int(CityPlan.LOGIC_PX_PER_UNIT), DUEL_RADIUS
	):
		host.present_opponent(rig)
		if is_instance_valid(host.opponent_aura_view) and host.opponent_aura_view.profile != null:
			host.opponent_aura = host.opponent_aura_view.profile
	if not host.open_scripted(SessionState.content_db, SessionState.state, SPIRIT_DUEL):
		host.detach_arena()
		_end(OUTCOME_CANCELLED)
		return false
	host.closed.connect(_on_duel_closed)
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		host.form_view().track_3d(camera, rig)
	return true


func _on_duel_closed(_outcome: Dictionary) -> void:
	_end(OUTCOME_DUEL)


func _free_dialogue() -> void:
	if ui != null and is_instance_valid(ui):
		ui.queue_free()
	ui = null
	if runner != null and is_instance_valid(runner):
		runner.queue_free()
	runner = null


func _free_shot() -> void:
	if shot != null and is_instance_valid(shot):
		if shot.camera != null and not shot.call(&"is_releasing"):
			shot.call(&"release")
		shot.queue_free()
	shot = null


func _end(outcome: StringName) -> void:
	if stage == STAGE_DONE:
		return
	stage = STAGE_DONE
	_free_dialogue()
	_free_shot()
	if host != null and is_instance_valid(host):
		host.queue_free()
	host = null
	if is_instance_valid(person) and person.has_method(&"release_talk"):
		person.call(&"release_talk")
	remove_from_group(ACTIVE_GROUP)
	ended.emit(outcome)
	queue_free()


func _exit_tree() -> void:
	if stage != STAGE_DONE and is_instance_valid(person) and person.has_method(&"release_talk"):
		person.call(&"release_talk")
