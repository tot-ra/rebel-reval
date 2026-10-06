class_name CombatRollClip
extends RefCounted

## Procedural forward/backward roll for the shared humanoid skeleton.
##
## WHY procedural: the CC0 KayKit library behind every body (ADR 0022) has no
## roll, only 0.38 s side-hops. Instead of a new external clip on a foreign
## skeleton, the roll is authored here as data on our own rig: start from the
## body's Idle pose, curl into a tuck (knees to chest, chin down, arms around
## the shins), rotate the whole body 360 degrees about its lateral axis and
## stand up. Every key re-solves the hips height so the lowest body point
## touches the ground, so the body rolls over the shoulders instead of sinking.
## Generated per body (bone lengths differ) and cached by body + direction.

const LIBRARY := &"combat"
const CLIP_FORWARD := &"Roll_Forward"
const CLIP_BACKWARD := &"Roll_Backward"
const LENGTH_SEC := 0.62
const KEY_COUNT := 32
const BASE_CLIP := &"Idle"
## Model space: +Y up, +Z forward, +X the character's left. A positive turn
## about +X carries the head forward and down (forward roll).
const LATERAL_AXIS := Vector3.RIGHT
const HIPS := &"hips"
## Degrees of extra sagittal flexion at full tuck (sign per the axis above).
const TUCK_DEG: Dictionary = {
	&"spine": 35.0,
	&"chest": 30.0,
	&"head": 30.0,
	&"upperleg.l": -120.0,
	&"upperleg.r": -120.0,
	&"lowerleg.l": 130.0,
	&"lowerleg.r": 130.0,
	&"upperarm.l": -70.0,
	&"upperarm.r": -70.0,
	&"lowerarm.l": -80.0,
	&"lowerarm.r": -80.0,
}
## Joint -> approximate flesh radius, for ground contact (metres, model space).
const CONTACT_RADIUS: Dictionary = {
	&"head": 0.11,
	&"chest": 0.13,
	&"spine": 0.12,
	&"hips": 0.12,
	&"upperarm.l": 0.06,
	&"upperarm.r": 0.06,
	&"hand.l": 0.04,
	&"hand.r": 0.04,
	&"lowerleg.l": 0.06,
	&"lowerleg.r": 0.06,
	&"foot.l": 0.04,
	&"foot.r": 0.04,
	&"toes.l": 0.02,
	&"toes.r": 0.02,
}

static var _cache: Dictionary = {}


## Adds the roll clips to the player's `combat` library if missing. Returns the
## AnimationPlayer name of the requested clip, or empty when the rig lacks the
## bones or the Idle base clip.
static func ensure_clip(
	player: AnimationPlayer, skeleton: Skeleton3D, cache_key: String, backward: bool
) -> StringName:
	var clip := CLIP_BACKWARD if backward else CLIP_FORWARD
	var full_name := StringName("%s/%s" % [LIBRARY, clip])
	if player == null or skeleton == null:
		return &""
	if player.has_animation(full_name):
		return full_name
	if not player.has_animation(BASE_CLIP) or skeleton.find_bone(String(HIPS)) < 0:
		return &""
	var key := "%s|%s" % [cache_key, clip]
	var animation: Animation = _cache.get(key)
	if animation == null:
		animation = build(player.get_animation(BASE_CLIP), skeleton, backward)
		_cache[key] = animation
	var library: AnimationLibrary
	if player.has_animation_library(LIBRARY):
		library = player.get_animation_library(LIBRARY)
	else:
		library = AnimationLibrary.new()
		player.add_animation_library(LIBRARY, library)
	library.add_animation(clip, animation)
	return full_name


static func build(base: Animation, skeleton: Skeleton3D, backward: bool) -> Animation:
	var tracks := _bone_tracks(base, skeleton)
	var bone_count := skeleton.get_bone_count()
	# Base (Idle frame 0) local pose per bone; untracked bones stay at rest.
	var base_pos: Array[Vector3] = []
	var base_rot: Array[Quaternion] = []
	var base_scale: Array[Vector3] = []
	for bone in bone_count:
		var rest := skeleton.get_bone_rest(bone)
		base_pos.append(rest.origin)
		base_rot.append(rest.basis.get_rotation_quaternion())
		base_scale.append(rest.basis.get_scale())
	for entry: Dictionary in tracks:
		var bone := int(entry["bone"])
		var track := int(entry["track"])
		match int(entry["type"]):
			Animation.TYPE_POSITION_3D:
				base_pos[bone] = base.position_track_interpolate(track, 0.0)
			Animation.TYPE_ROTATION_3D:
				base_rot[bone] = base.rotation_track_interpolate(track, 0.0)
			Animation.TYPE_SCALE_3D:
				base_scale[bone] = base.scale_track_interpolate(track, 0.0)
	var base_global := _globals(skeleton, base_pos, base_rot, base_scale)
	# Lateral axis expressed in each bone's own base frame (see header).
	var local_axis: Array[Vector3] = []
	for bone in bone_count:
		local_axis.append(
			(base_global[bone].basis.orthonormalized().inverse() * LATERAL_AXIS).normalized()
		)

	var animation := Animation.new()
	animation.length = LENGTH_SEC
	animation.loop_mode = Animation.LOOP_NONE
	var hips := skeleton.find_bone(String(HIPS))
	var track_of: Dictionary = {}
	for entry: Dictionary in tracks:
		var type := int(entry["type"])
		if type == Animation.TYPE_SCALE_3D:
			continue
		var new_track := animation.add_track(type)
		animation.track_set_path(new_track, entry["path"])
		animation.track_set_interpolation_type(new_track, Animation.INTERPOLATION_LINEAR)
		track_of["%d:%d" % [int(entry["bone"]), type]] = new_track
	var hips_position_track := int(track_of.get("%d:%d" % [hips, Animation.TYPE_POSITION_3D], -1))
	if hips_position_track < 0:
		hips_position_track = animation.add_track(Animation.TYPE_POSITION_3D)
		animation.track_set_path(hips_position_track, _path_for_bone(tracks, skeleton, hips))
		track_of["%d:%d" % [hips, Animation.TYPE_POSITION_3D]] = hips_position_track

	var direction := -1.0 if backward else 1.0
	# Lift is relative to the standing pose, so the first and last keys match
	# Idle exactly whatever height the feet are authored at.
	var standing_lowest := _lowest_point(skeleton, base_pos, base_rot, base_scale)
	for key in KEY_COUNT + 1:
		var u := float(key) / float(KEY_COUNT)
		var tuck := tuck_weight(u)
		var turn := direction * TAU * turn_fraction(u)
		var pose_rot := base_rot.duplicate()
		for bone_name: StringName in TUCK_DEG:
			var bone := skeleton.find_bone(String(bone_name))
			if bone < 0:
				continue
			var angle := deg_to_rad(float(TUCK_DEG[bone_name])) * tuck
			pose_rot[bone] = base_rot[bone] * Quaternion(local_axis[bone], angle)
		pose_rot[hips] = pose_rot[hips] * Quaternion(local_axis[hips], turn)
		var pose_pos := base_pos.duplicate()
		pose_pos[hips] = (
			base_pos[hips]
			+ _model_to_parent_offset(
				skeleton,
				base_global,
				hips,
				Vector3(
					0.0,
					standing_lowest - _lowest_point(skeleton, pose_pos, pose_rot, base_scale),
					0.0
				)
			)
		)
		var time := u * LENGTH_SEC
		for track_key: String in track_of:
			var parts := track_key.split(":")
			var bone := int(parts[0])
			var type := int(parts[1])
			var track := int(track_of[track_key])
			if type == Animation.TYPE_ROTATION_3D:
				animation.rotation_track_insert_key(track, time, pose_rot[bone])
			else:
				animation.position_track_insert_key(track, time, pose_pos[bone])
	return animation


## Curl in over the first 22 %, hold the tuck through the rotation, stand up
## over the last 20 %.
static func tuck_weight(u: float) -> float:
	if u < 0.22:
		return smoothstep(0.0, 0.22, u)
	if u > 0.80:
		return 1.0 - smoothstep(0.80, 1.0, u)
	return 1.0


## The body pitches from 12 % (after the crouch begins) to 80 % of the clip.
static func turn_fraction(u: float) -> float:
	return smoothstep(0.12, 0.80, u)


## Lowest flesh point (model metres) of a pose with the hips at their base.
static func _lowest_point(skeleton: Skeleton3D, pos: Array, rot: Array, scale: Array) -> float:
	var globals := _globals(skeleton, pos, rot, scale)
	var lowest := INF
	for bone_name: StringName in CONTACT_RADIUS:
		var bone := skeleton.find_bone(String(bone_name))
		if bone < 0:
			continue
		lowest = minf(lowest, globals[bone].origin.y - float(CONTACT_RADIUS[bone_name]))
	return 0.0 if lowest == INF else lowest


static func _globals(
	skeleton: Skeleton3D, pos: Array, rot: Array, scale: Array
) -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	result.resize(skeleton.get_bone_count())
	for bone in skeleton.get_bone_count():
		var local := Transform3D(
			Basis(rot[bone] as Quaternion).scaled(scale[bone] as Vector3), pos[bone] as Vector3
		)
		var parent := skeleton.get_bone_parent(bone)
		result[bone] = local if parent < 0 else result[parent] * local
	return result


## Converts a model-space displacement into the bone's parent space.
static func _model_to_parent_offset(
	skeleton: Skeleton3D, globals: Array[Transform3D], bone: int, offset: Vector3
) -> Vector3:
	var parent := skeleton.get_bone_parent(bone)
	if parent < 0:
		return offset
	return globals[parent].basis.inverse() * offset


static func _bone_tracks(base: Animation, skeleton: Skeleton3D) -> Array[Dictionary]:
	var tracks: Array[Dictionary] = []
	for track in base.get_track_count():
		var type := base.track_get_type(track)
		if (
			type
			not in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]
		):
			continue
		var path := base.track_get_path(track)
		var bone := skeleton.find_bone(String(path.get_concatenated_subnames()))
		if bone < 0:
			continue
		tracks.append({"track": track, "type": type, "bone": bone, "path": path})
	return tracks


static func _path_for_bone(tracks: Array[Dictionary], skeleton: Skeleton3D, bone: int) -> NodePath:
	var any_path: NodePath = (
		tracks[0]["path"] if not tracks.is_empty() else NodePath("Skeleton3D:hips")
	)
	return NodePath(
		"%s:%s" % [String(any_path.get_concatenated_names()), skeleton.get_bone_name(bone)]
	)
