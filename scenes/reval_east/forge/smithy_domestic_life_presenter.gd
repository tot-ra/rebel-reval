class_name SmithyDomesticLifePresenter
extends Node3D

## View-only presentation host for Kalev's optional smithy vignettes. It never
## drives the logic actor: movement remains player-owned and story controllers
## keep priority. The host owns one temporary held prop, one action-effect root,
## restrained station pose correction, and deterministic telemetry.

const HeldPropFactory := preload("res://scenes/reval_east/forge/smithy_held_prop_factory.gd")
const ContactPoseModifier := preload("res://scenes/reval_east/forge/smithy_contact_pose_modifier.gd")

const EFFECT_ROOT_NAME := &"SmithyActionEffects"
const HELD_SLOT := &"right_hand"
const MAX_ACTIVE_EFFECT_ROOTS := 1
const MAX_ACTIVE_AUDIO_VOICES := 2
const DEFAULT_HELD_PROPS: Dictionary = {
	&"ap.forge.anvil": &"forge_hammer",
	&"ap.forge.quench": &"forge_hammer",
}

const ACTIVITY_PROFILES: Dictionary = {
	&"ap.sleep.wake": {
		"animation": &"sit_up",
		"pose": {"hips_offset_y": -0.08},
		"sound": &"textile",
	},
	&"ap.sleep.rest": {
		"animation": &"sit_down",
		"pose": {"hips_offset_y": -0.08},
		"sound": &"textile",
	},
	&"ap.wash.basin": {
		"animation": &"pickup",
		"pose": {"shoulder_pitch_deg": 18.0, "elbow_bend_deg": 34.0},
		"sound": &"water",
		"effect": &"water",
	},
	&"ap.fetch.water": {
		"animation": &"pickup",
		"pose": {"shoulder_pitch_deg": 8.0, "elbow_bend_deg": 18.0},
		"sound": &"water",
	},
	&"ap.prepare.board": {
		"animation": &"pickup",
		"pose": {"shoulder_pitch_deg": 20.0, "elbow_bend_deg": 42.0},
		"sound": &"crockery",
	},
	&"ap.hearth.tend": {
		"animation": &"pickup",
		"pose": {"shoulder_pitch_deg": 28.0, "elbow_bend_deg": 38.0},
		"sound": &"fire",
		"effect": &"embers",
	},
	&"ap.hearth.cookpot": {
		"animation": &"talk_gesture",
		"pose": {"shoulder_pitch_deg": 24.0, "elbow_bend_deg": 46.0},
		"sound": &"cooking",
		"effect": &"steam",
	},
	&"ap.hearth.bank": {
		"animation": &"pickup",
		"pose": {"shoulder_pitch_deg": 24.0, "elbow_bend_deg": 35.0},
		"sound": &"fire",
		"effect": &"embers",
	},
	&"ap.eat.table": {
		"animation": &"sit_idle",
		"pose": {"hips_offset_y": -0.06, "elbow_bend_deg": 22.0},
		"sound": &"crockery",
	},
	&"ap.clear.table": {
		"animation": &"pickup",
		"pose": {"shoulder_pitch_deg": 16.0, "elbow_bend_deg": 30.0},
		"sound": &"crockery",
	},
	&"ap.sweep.floor": {
		"animation": &"talk_gesture",
		"pose": {"shoulder_pitch_deg": 18.0, "elbow_bend_deg": 24.0},
		"sound": &"broom",
	},
	&"ap.carry.fuel": {
		"animation": &"pickup",
		"pose": {"shoulder_pitch_deg": 10.0, "elbow_bend_deg": 32.0},
		"sound": &"wood",
	},
	&"ap.ledger.inspect": {
		"animation": &"talk_gesture",
		"pose": {"shoulder_pitch_deg": 8.0, "elbow_bend_deg": 18.0},
		"sound": &"textile",
	},
	&"ap.forge.bellows": {
		"animation": &"pickup",
		"pose": {"shoulder_pitch_deg": 25.0, "elbow_bend_deg": 38.0},
		"sound": &"bellows",
		"effect": &"embers",
	},
	&"ap.forge.anvil": {
		"animation": &"forge_strike",
		"pose": {"shoulder_pitch_deg": 10.0, "elbow_bend_deg": 12.0},
		"sound": &"metal",
		"effect": &"sparks",
	},
	&"ap.forge.quench": {
		"animation": &"pickup",
		"pose": {"shoulder_pitch_deg": 30.0, "elbow_bend_deg": 48.0},
		"sound": &"quench",
		"effect": &"steam",
	},
}

var _rig: SharedCharacterRig
var _equipment_state: GameState
var _content_db: ContentDB
var _pose_modifier: SmithyContactPoseModifier
var _active_activity: StringName = &""
var _active_held_prop: StringName = &""
var _previous_right_hand_scene: PackedScene
var _previous_right_hand_scene_path := ""
var _active_effect_root: Node3D
var _audio_players: Array[AudioStreamPlayer3D] = []
var _animation_time := 0.0
var _animation_duration := 0.0
var _began_count := 0
var _completed_count := 0
var _cancelled_count := 0
var _restore_count := 0
var _held_prop_peak := 0
var _effect_root_peak := 0
var _audio_voice_peak := 0


func _ready() -> void:
	process_priority = 200
	for index in MAX_ACTIVE_AUDIO_VOICES:
		var player := AudioStreamPlayer3D.new()
		player.name = "SmithyOneShot%d" % index
		player.max_distance = 8.0
		player.unit_size = 2.0
		player.volume_db = -13.0
		add_child(player)
		_audio_players.append(player)


func _process(delta: float) -> void:
	tick(delta)


func configure(
	rig: SharedCharacterRig,
	equipment_state: GameState,
	content_db: ContentDB
) -> void:
	_rig = rig
	_equipment_state = equipment_state
	_content_db = content_db
	_ensure_pose_modifier()


func begin_activity(
	activity_id: StringName,
	held_prop: StringName,
	duration_sec: float,
	restored: bool = false,
	animation_time_sec: float = 0.0
) -> bool:
	if _rig == null or activity_id.is_empty() or not ACTIVITY_PROFILES.has(activity_id):
		return false
	if not _active_activity.is_empty():
		clear_activity(false)
	_active_activity = activity_id
	_active_held_prop = held_prop
	if _active_held_prop.is_empty():
		_active_held_prop = DEFAULT_HELD_PROPS.get(activity_id, &"")
	_animation_duration = maxf(duration_sec, 0.05)
	_animation_time = clampf(animation_time_sec, 0.0, _animation_duration)
	var profile: Dictionary = ACTIVITY_PROFILES[activity_id]
	_pose_modifier.configure(profile.get("pose", {}) as Dictionary)
	_mount_held_prop(_active_held_prop)
	_install_effect(StringName(profile.get("effect", &"")))
	if not restored:
		_play_sound(StringName(profile.get("sound", &"")))
		_began_count += 1
	else:
		_restore_count += 1
	_apply_station_animation()
	_update_peaks()
	return true


func tick(delta: float) -> void:
	if _active_activity.is_empty():
		return
	_animation_time = minf(_animation_time + maxf(delta, 0.0), _animation_duration)
	_apply_station_animation()
	_update_peaks()


func clear_activity(completed: bool) -> void:
	if _active_activity.is_empty() and _active_effect_root == null and _active_held_prop.is_empty():
		return
	if completed:
		_completed_count += 1
	else:
		_cancelled_count += 1
	_remove_effect()
	_restore_right_hand_equipment()
	if _pose_modifier != null:
		_pose_modifier.clear_profile()
	_active_activity = &""
	_active_held_prop = &""
	_animation_time = 0.0
	_animation_duration = 0.0


func active_activity() -> StringName:
	return _active_activity


func active_held_prop_count() -> int:
	if _active_held_prop.is_empty() or _rig == null:
		return 0
	var equipped := _rig.equipped(HELD_SLOT)
	return 1 if equipped != null and equipped.has_meta(&"smithy_held_prop") else 0


func active_effect_root_count() -> int:
	return 1 if _active_effect_root != null and is_instance_valid(_active_effect_root) else 0


func active_audio_voice_count() -> int:
	var count := 0
	for player in _audio_players:
		if player.playing:
			count += 1
	return count


func snapshot() -> Dictionary:
	if _active_activity.is_empty():
		return {}
	return {
		"activity_id": String(_active_activity),
		"held_prop": String(_active_held_prop),
		"animation_time_sec": _animation_time,
		"duration_sec": _animation_duration,
	}


func restore_snapshot(snapshot: Dictionary) -> bool:
	var activity_id := StringName(String(snapshot.get("activity_id", "")))
	if activity_id.is_empty():
		clear_activity(false)
		return false
	return begin_activity(
		activity_id,
		StringName(String(snapshot.get("held_prop", ""))),
		float(snapshot.get("duration_sec", 0.05)),
		true,
		float(snapshot.get("animation_time_sec", 0.0))
	)


func invariant_errors() -> Array[String]:
	var errors: Array[String] = []
	if active_held_prop_count() > 1:
		errors.append("duplicate held props")
	if active_effect_root_count() > MAX_ACTIVE_EFFECT_ROOTS:
		errors.append("too many action effect roots")
	if active_audio_voice_count() > MAX_ACTIVE_AUDIO_VOICES:
		errors.append("too many smithy audio voices")
	if _active_activity.is_empty():
		if active_held_prop_count() > 0:
			errors.append("orphan held prop")
		if active_effect_root_count() > 0:
			errors.append("orphan action effect")
	return errors


func telemetry() -> Dictionary:
	return {
		"active_activity": String(_active_activity),
		"active_held_props": active_held_prop_count(),
		"active_effect_roots": active_effect_root_count(),
		"active_audio_voices": active_audio_voice_count(),
		"began_count": _began_count,
		"completed_count": _completed_count,
		"cancelled_count": _cancelled_count,
		"restore_count": _restore_count,
		"held_prop_peak": _held_prop_peak,
		"effect_root_peak": _effect_root_peak,
		"audio_voice_peak": _audio_voice_peak,
		"invariant_errors": invariant_errors(),
	}


func _apply_station_animation() -> void:
	if _rig == null or _active_activity.is_empty():
		return
	var profile: Dictionary = ACTIVITY_PROFILES[_active_activity]
	var animation: StringName = profile.get("animation", &"idle")
	if _rig.current_canonical_animation() != animation:
		_rig.play_animation(animation, 0.08)
	var player := _rig.animation_player()
	if player == null or player.current_animation.is_empty():
		return
	var source := player.get_animation(player.current_animation)
	if source == null or source.length <= 0.0:
		return
	var authored_time := fmod(_animation_time, source.length)
	player.seek(authored_time, true, true)
	player.pause()


func _ensure_pose_modifier() -> void:
	if _rig == null or _pose_modifier != null:
		return
	var skeleton := _rig.skeleton()
	if skeleton == null:
		return
	_pose_modifier = ContactPoseModifier.new()
	_pose_modifier.name = "SmithyContactPose"
	_pose_modifier.process_priority = 210
	skeleton.add_child(_pose_modifier)
	_pose_modifier.clear_profile()


func _mount_held_prop(prop_id: StringName) -> void:
	if _rig == null or prop_id.is_empty():
		return
	var existing := _rig.equipped(HELD_SLOT)
	if existing != null and not existing.has_meta(&"smithy_held_prop"):
		_previous_right_hand_scene = _pack_node(existing.duplicate() as Node3D)
	_previous_right_hand_scene_path = _equipped_scene_path()
	var temporary := HeldPropFactory.create(prop_id)
	if temporary == null:
		return
	var packed := _pack_node(temporary)
	if packed == null:
		return
	_rig.equip(HELD_SLOT, packed)


static func _pack_node(root: Node3D) -> PackedScene:
	if root == null:
		return null
	_set_owner_recursive(root, root)
	var packed := PackedScene.new()
	var result := packed.pack(root)
	root.free()
	return packed if result == OK else null


static func _set_owner_recursive(node: Node, scene_root: Node) -> void:
	for child: Node in node.get_children():
		child.owner = scene_root
		_set_owner_recursive(child, scene_root)


func _restore_right_hand_equipment() -> void:
	if _rig == null:
		return
	_rig.unequip(HELD_SLOT)
	if _previous_right_hand_scene != null:
		_rig.equip(HELD_SLOT, _previous_right_hand_scene)
	elif not _previous_right_hand_scene_path.is_empty():
		var scene := load(_previous_right_hand_scene_path) as PackedScene
		if scene != null:
			_rig.equip(HELD_SLOT, scene)
	_previous_right_hand_scene = null
	_previous_right_hand_scene_path = ""


func _equipped_scene_path() -> String:
	if _equipment_state == null or _content_db == null:
		return ""
	var item_id := _equipment_state.equipped_item(HELD_SLOT)
	if item_id.is_empty():
		return ""
	var record := _content_db.get_item(item_id)
	var gameplay: Dictionary = record.get("gameplay", {})
	var equip_info: Dictionary = gameplay.get("equip", {})
	return String(equip_info.get("scene", ""))


func _install_effect(effect_id: StringName) -> void:
	_remove_effect()
	if effect_id.is_empty():
		return
	_active_effect_root = Node3D.new()
	_active_effect_root.name = String(EFFECT_ROOT_NAME)
	_active_effect_root.set_meta(&"smithy_effect", effect_id)
	add_child(_active_effect_root)
	var particles := GPUParticles3D.new()
	particles.name = "Burst"
	particles.amount = 9 if effect_id in [&"sparks", &"embers"] else 6
	particles.lifetime = 0.75
	particles.one_shot = true
	particles.explosiveness = 0.82
	particles.randomness = 0.35
	particles.emitting = true
	particles.visibility_aabb = AABB(Vector3(-0.8, -0.2, -0.8), Vector3(1.6, 1.8, 1.6))
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = 24.0
	process.initial_velocity_min = 0.35
	process.initial_velocity_max = 1.1
	process.gravity = Vector3(0.0, -0.7 if effect_id in [&"sparks", &"embers"] else 0.18, 0.0)
	process.color = _effect_color(effect_id)
	particles.process_material = process
	var draw := SphereMesh.new()
	draw.radius = 0.025 if effect_id in [&"sparks", &"embers"] else 0.08
	draw.height = draw.radius * 2.0
	particles.draw_pass_1 = draw
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = _effect_color(effect_id)
	particles.material_override = material
	_active_effect_root.add_child(particles)


func _remove_effect() -> void:
	if _active_effect_root == null:
		return
	if is_instance_valid(_active_effect_root):
		_active_effect_root.free()
	_active_effect_root = null


func _play_sound(sound_id: StringName) -> void:
	if sound_id.is_empty():
		return
	var player: AudioStreamPlayer3D
	for candidate in _audio_players:
		if not candidate.playing:
			player = candidate
			break
	if player == null:
		player = _audio_players[0]
		player.stop()
	player.stream = _procedural_sound(sound_id)
	player.play()


static func _procedural_sound(sound_id: StringName) -> AudioStreamWAV:
	var sample_rate := 22050
	var duration := 0.16
	var frequency := 120.0
	match sound_id:
		&"water", &"quench":
			duration = 0.28
			frequency = 330.0
		&"crockery", &"metal":
			duration = 0.12
			frequency = 740.0
		&"fire", &"cooking", &"bellows":
			duration = 0.22
			frequency = 165.0
		&"broom", &"textile", &"wood":
			duration = 0.18
			frequency = 92.0
	var frame_count := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(frame_count * 2)
	for frame in frame_count:
		var t := float(frame) / float(sample_rate)
		var envelope := pow(1.0 - float(frame) / float(frame_count), 2.2)
		var tone := sin(TAU * frequency * t)
		var noise := sin(TAU * (frequency * 2.31) * t + 0.7) * 0.35
		var sample := int(clampf((tone + noise) * envelope * 0.22, -1.0, 1.0) * 32767.0)
		data.encode_s16(frame * 2, sample)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = data
	return stream


static func _effect_color(effect_id: StringName) -> Color:
	match effect_id:
		&"sparks", &"embers":
			return Color(1.0, 0.36, 0.07, 0.9)
		&"water":
			return Color(0.48, 0.72, 0.86, 0.42)
		_:
			return Color(0.86, 0.88, 0.84, 0.36)


func _update_peaks() -> void:
	_held_prop_peak = maxi(_held_prop_peak, active_held_prop_count())
	_effect_root_peak = maxi(_effect_root_peak, active_effect_root_count())
	_audio_voice_peak = maxi(_audio_voice_peak, active_audio_voice_count())
