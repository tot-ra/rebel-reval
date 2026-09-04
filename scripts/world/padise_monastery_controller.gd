class_name PadiseMonasteryController
extends Node

## Runtime composition boundary for the two Padise phases.
## The RRMap owns collision, anchors, landmarks, and route geometry; this node
## owns only phase-specific people and the location soundscape.

const MonkActor := preload("res://scripts/world/padise_monk_actor.gd")
const MusicDirectorScript := preload("res://scripts/global/music_director.gd")

const PHASE_BEFORE_ATTACK := &"before_attack"
const PHASE_AFTER_ATTACK := &"after_attack"
const WHITE_BROTHER := &"white_brother_choir"
const GREY_BROTHER := &"grey_brother_lay"

const REQUIRED_ANCHORS: Array[StringName] = [
	&"room_infirmary",
	&"room_brewhouse",
	&"landmark_monastery_well",
	&"room_cloister_garth",
]
const REQUIRED_VIEW_LANDMARKS: Array[StringName] = [
	&"cloister_walk_north",
	&"cloister_walk_south",
	&"cloister_walk_west",
	&"cloister_walk_east",
]

const PHASE_MANIFEST: Dictionary = {
	PHASE_BEFORE_ATTACK:
	{
		"sound_theme": &"holy_spirit",
		"monks":
		[
			{
				"id": &"white_brother_choir",
				"community": WHITE_BROTHER,
				"anchor_id": &"landmark_timber_oratory",
				"rig": "res://assets/characters/variants/townswoman.tscn",
			},
			{
				"id": &"grey_brother_lay",
				"community": GREY_BROTHER,
				"anchor_id": &"room_lay_brothers",
				"rig": "res://assets/characters/variants/watchman.tscn",
			},
		],
	},
	PHASE_AFTER_ATTACK:
	{
		"sound_theme": &"monastery",
		"monks": [],
	},
}

var _definition: MapDefinition
var _actors_root: Node2D
var _player: Node2D
var _spawned: Array[Node2D] = []
var _phase := PHASE_BEFORE_ATTACK
var _owns_music_override := false


static func phase_for_campaign_phase(campaign_phase: StringName) -> StringName:
	return PHASE_AFTER_ATTACK if campaign_phase == &"phase.act1_climax" else PHASE_BEFORE_ATTACK


static func phase_manifest(phase_id: StringName) -> Dictionary:
	return (
		(PHASE_MANIFEST.get(phase_id, PHASE_MANIFEST[PHASE_BEFORE_ATTACK]) as Dictionary)
		. duplicate(true)
	)


static func sound_theme_for_phase(phase_id: StringName) -> StringName:
	return StringName(String(phase_manifest(phase_id).get("sound_theme", &"")))


static func required_anchor_ids() -> Array[StringName]:
	return REQUIRED_ANCHORS.duplicate()


static func required_view_landmark_ids() -> Array[StringName]:
	return REQUIRED_VIEW_LANDMARKS.duplicate()


static func validate_definition(definition: MapDefinition) -> Array[String]:
	var errors: Array[String] = []
	if definition == null:
		return ["Padise definition is required"]
	for anchor_id in REQUIRED_ANCHORS:
		if not MapVerification.has_anchor(definition, anchor_id):
			errors.append("missing Padise anchor: %s" % String(anchor_id))
	var landmark_ids: Dictionary = {}
	for landmark in definition.view_landmarks:
		landmark_ids[landmark.get("id", &"")] = true
	for landmark_id in REQUIRED_VIEW_LANDMARKS:
		if not landmark_ids.has(landmark_id):
			errors.append("missing Padise view landmark: %s" % String(landmark_id))
	return errors


func configure(definition: MapDefinition, actors_root: Node2D, player: Node2D) -> void:
	_definition = definition
	_actors_root = actors_root
	_player = player
	if (
		SessionState.state != null
		and not SessionState.state.phase_changed.is_connected(_on_campaign_phase_changed)
	):
		SessionState.state.phase_changed.connect(_on_campaign_phase_changed)
	set_monastery_phase(phase_for_campaign_phase(SessionState.state.get_phase()))


func _exit_tree() -> void:
	if (
		SessionState.state != null
		and SessionState.state.phase_changed.is_connected(_on_campaign_phase_changed)
	):
		SessionState.state.phase_changed.disconnect(_on_campaign_phase_changed)
	_clear_music_override()


func set_monastery_phase(phase_id: StringName) -> void:
	if not PHASE_MANIFEST.has(phase_id):
		phase_id = PHASE_BEFORE_ATTACK
	_phase = phase_id
	_clear_spawned()
	_apply_soundscape()
	if _definition == null or _actors_root == null:
		return
	for monk in phase_manifest(_phase).get("monks", []) as Array:
		var anchor_id := StringName(String(monk.get("anchor_id", "")))
		if not MapVerification.has_anchor(_definition, anchor_id):
			continue
		var actor := MonkActor.new()
		actor.name = String(monk.get("id", "PadiseMonk"))
		_actors_root.add_child(actor)
		var rig := load(String(monk.get("rig", ""))) as PackedScene
		actor.configure_brotherhood(
			_player,
			MapVerification.anchor_position(_definition, anchor_id),
			StringName(String(monk.get("community", ""))),
			rig
		)
		_spawned.append(actor)


func current_phase() -> StringName:
	return _phase


func spawned_monks() -> Array[Node2D]:
	return _spawned.duplicate()


func _on_campaign_phase_changed(_previous: StringName, next: StringName) -> void:
	set_monastery_phase(phase_for_campaign_phase(next))


func _apply_soundscape() -> void:
	var music_director := get_node_or_null("/root/MusicDirector")
	var theme_id := sound_theme_for_phase(_phase)
	if music_director == null or not MusicDirectorScript.has_theme(theme_id):
		return
	music_director.set_zone_theme_override(theme_id)
	_owns_music_override = true


func _clear_music_override() -> void:
	if not _owns_music_override:
		return
	var music_director := get_node_or_null("/root/MusicDirector")
	if music_director != null:
		music_director.clear_zone_theme_override()
	_owns_music_override = false


func _clear_spawned() -> void:
	for actor in _spawned:
		if is_instance_valid(actor):
			actor.queue_free()
	_spawned.clear()
