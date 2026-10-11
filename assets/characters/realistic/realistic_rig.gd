extends SharedCharacterRig
## Realistic MPFB-based human (ADR 0022). Proportions, skin and grooming are
## baked into the imported body; clothes are CharacterWearable layers.

## Mirrors tools/assets/realistic_humans/run_cycle.py: the stance ankle slides
## (CONTACT_REACH + TOE_OFF_REACH) leg lengths while loaded for STANCE of a
## FRAMES-long 24 fps cycle, which fixes the run's true ground speed per body.
const RUN_STANCE_SWEEP_LEGS := 0.30 + 0.46
const RUN_STANCE_SEC := 0.27 * 16.0 / 24.0

## Facial blend shapes baked by tools/assets/realistic_humans (ADR 0022).
const FACE_SHAPES: Array[StringName] = [
	&"blink", &"jaw_open", &"smile", &"brow_up", &"frown", &"pucker"
]
## Finger bones (tools/assets/realistic_humans build_human.add_finger_bones):
## the rest pose is the weapon grip; local +X curls, -X opens.
const FINGERS: Array[String] = ["thumb", "index", "middle", "ring", "pinky"]
const FINGER_RELAXED_OPEN := deg_to_rad(-40.0)
const THUMB_RELAXED_OPEN := deg_to_rad(-15.0)
const FINGER_BLEND_PER_SECOND := 6.0
const BLINK_SECONDS := 0.14
const TALK_SECONDS_PER_CHAR := 0.055

## Wearables equipped on spawn, before any variant wearables.
@export var default_outfit: Array[CharacterWearable] = []

var _face_targets: Dictionary = {}  # shape -> Array of [MeshInstance3D, blend shape index]
var _expression: Dictionary = {}
var _blink_wait := 3.0
var _blink_left := 0.0
var _talk_left := 0.0
var _talk_phase := 0.0
var _rng := RandomNumberGenerator.new()
var _finger_bones: Dictionary = {}  # side -> Array of [bone index, is_thumb, rest rotation]
var _finger_open: Dictionary = {"l": 0.0, "r": 0.0}  # 0 = grip (rest), 1 = relaxed open


func _ready() -> void:
	super._ready()
	for wearable: CharacterWearable in default_outfit:
		if not equip_wearable(wearable):
			push_error("%s could not equip default wearable %s" % [name, wearable.stable_id])
	# Default outfit can add skinned meshes after the shared _ready walk.
	enable_authored_vertex_color_albedo($Model)
	_collect_face_targets()
	_collect_finger_bones()
	add_to_group(&"dialogue_speakers")
	_rng.seed = hash(String(name))
	_blink_wait = _rng.randf_range(1.0, 4.0)
	set_process(not _face_targets.is_empty() or not _finger_bones.is_empty())


## Hold a facial expression (smile, frown, brow_up, pucker) at weight 0..1.
func set_expression(shape: StringName, weight: float) -> void:
	_expression[shape] = clampf(weight, 0.0, 1.0)


## Animate the jaw for `seconds` of speech (0 stops).
func talk_for(seconds: float) -> void:
	_talk_left = maxf(seconds, 0.0)


func is_talking() -> bool:
	return _talk_left > 0.0


## DialogueRunner group callback: talk while this character's line is read.
func on_dialogue_speaker(speaker_id: StringName, text_length: int) -> void:
	if speaker_id == variant_id():
		talk_for(clampf(text_length * TALK_SECONDS_PER_CHAR, 0.8, 8.0))
	else:
		talk_for(0.0)


func face_shape_value(shape: StringName) -> float:
	for target: Array in _face_targets.get(shape, []):
		return (target[0] as MeshInstance3D).get_blend_shape_value(target[1])
	return 0.0


func _collect_face_targets() -> void:
	_face_targets.clear()
	for found: Node in $Model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := found as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for shape: StringName in FACE_SHAPES:
			var index := mesh_instance.find_blend_shape_by_name(shape)
			if index >= 0:
				if not _face_targets.has(shape):
					_face_targets[shape] = []
				_face_targets[shape].append([mesh_instance, index])


## 0 = closed around a held prop (rest), 1 = relaxed open hand.
func finger_openness(side: String) -> float:
	return float(_finger_open.get(side, 0.0))


func _collect_finger_bones() -> void:
	_finger_bones.clear()
	var skeleton_node := skeleton()
	if skeleton_node == null:
		return
	for side: String in ["l", "r"]:
		var bones: Array = []
		for finger: String in FINGERS:
			for joint: int in [1, 2, 3]:
				var index := skeleton_node.find_bone("%s_0%d.%s" % [finger, joint, side])
				if index >= 0:
					var rest := skeleton_node.get_bone_rest(index).basis.get_rotation_quaternion()
					bones.append([index, finger == "thumb", rest])
		if not bones.is_empty():
			_finger_bones[side] = bones
		_finger_open[side] = 1.0 if equipped(_hand_slot(side)) == null else 0.0


static func _hand_slot(side: String) -> StringName:
	return &"left_hand" if side == "l" else &"right_hand"


func _pose_fingers(delta: float) -> void:
	var skeleton_node := skeleton()
	for side: String in _finger_bones:
		var target := 1.0 if equipped(_hand_slot(side)) == null else 0.0
		_finger_open[side] = move_toward(_finger_open[side], target, delta * FINGER_BLEND_PER_SECOND)
		for bone: Array in _finger_bones[side]:
			var open := THUMB_RELAXED_OPEN if bone[1] else FINGER_RELAXED_OPEN
			var curl := Quaternion(Vector3.RIGHT, open * float(_finger_open[side]))
			skeleton_node.set_bone_pose_rotation(bone[0], (bone[2] as Quaternion) * curl)


func _process(delta: float) -> void:
	if not _finger_bones.is_empty():
		_pose_fingers(delta)
	if _face_targets.is_empty():
		return
	_blink_wait -= delta
	if _blink_wait <= 0.0:
		_blink_left = BLINK_SECONDS
		# Occasional double blink, otherwise every 2-6 s.
		var double := _rng.randf() < 0.15
		_blink_wait = _rng.randf_range(0.25, 0.4) if double else _rng.randf_range(2.0, 6.0)
	var blink := 0.0
	if _blink_left > 0.0:
		_blink_left -= delta
		blink = sin(clampf(1.0 - _blink_left / BLINK_SECONDS, 0.0, 1.0) * PI)
	var jaw := 0.0
	var pucker := float(_expression.get(&"pucker", 0.0))
	if _talk_left > 0.0:
		_talk_left -= delta
		_talk_phase += delta
		# Syllable rhythm: ~5 Hz open/close under an irregular envelope.
		var syllable := absf(sin(_talk_phase * 15.0)) * (0.55 + 0.45 * sin(_talk_phase * 3.7))
		jaw = 0.06 + 0.22 * syllable
		pucker = maxf(pucker, 0.25 * maxf(sin(_talk_phase * 6.3), 0.0))
	_set_shape(&"blink", blink)
	_set_shape(&"jaw_open", jaw)
	_set_shape(&"pucker", pucker)
	for shape: StringName in [&"smile", &"brow_up", &"frown"]:
		_set_shape(shape, float(_expression.get(shape, 0.0)))


func _set_shape(shape: StringName, value: float) -> void:
	for target: Array in _face_targets.get(shape, []):
		(target[0] as MeshInstance3D).set_blend_shape_value(target[1], value)


func equip_garment(garment_id: StringName, scene: PackedScene) -> bool:
	if not super.equip_garment(garment_id, scene):
		return false
	for mesh_instance: MeshInstance3D in _garments.get(garment_id, []):
		enable_authored_vertex_color_albedo(mesh_instance)
	return true


## Legacy show_cape/show_hat flags mount garments fitted to the retired
## procedural hero; realistic bodies dress only through fitted wearables.
func _apply_variant() -> void:
	if variant == null:
		return
	_apply_material_stack($Model, variant.material_tint)
	if skeleton() == null:
		return
	if variant.equipment != null:
		equip(&"right_hand", variant.equipment)
	for wearable: CharacterWearable in variant.wearables:
		equip_wearable(wearable)


func _install_proportion_modifiers() -> void:
	pass


func _configure_lod0_visibility() -> void:
	pass


func _install_distance_lods() -> void:
	pass


## The authored run (run_cycle.py) is much faster than the inherited clip the
## shared constant was tuned for, and scales with each body's leg length.
func locomotion_reference_speed(canonical_name: StringName) -> float:
	var skeleton := skeleton()
	if canonical_name != &"run" or skeleton == null:
		return super.locomotion_reference_speed(canonical_name)
	var hip := skeleton.get_bone_global_rest(skeleton.find_bone("upperleg.r")).origin
	var knee := skeleton.get_bone_global_rest(skeleton.find_bone("lowerleg.r")).origin
	var ankle := skeleton.get_bone_global_rest(skeleton.find_bone("foot.r")).origin
	var leg := (knee - hip).length() + (ankle - knee).length()
	return RUN_STANCE_SWEEP_LEGS * leg * model_scale.x / RUN_STANCE_SEC


func consume_foot_plant() -> StringName:
	if not LOCOMOTION_REFERENCE_SPEED.has(current_canonical_animation()):
		_planted_foot = &""
		return &""
	var player := animation_player()
	if player == null or player.current_animation_length <= 0.0:
		return &""
	# The walk keeps both foot bones at nearly the same height while the legs
	# exchange load, so the half-cycle is the contact authority (same contract
	# as the retired kalev_fresh body); the authored run lands the right foot at
	# phase 0 and the left at 0.5.
	var phase := fposmod(player.current_animation_position / player.current_animation_length, 1.0)
	var planted := RIGHT_FOOT_BONE if phase < 0.5 else LEFT_FOOT_BONE
	if planted == _planted_foot:
		return &""
	_planted_foot = planted
	return planted
