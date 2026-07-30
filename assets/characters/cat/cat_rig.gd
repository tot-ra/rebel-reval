class_name CatRig
extends SharedCharacterRig

## Runtime adapter for the game-ready forge cat GLB.
##
## The imported model provides an organic manifold mesh, one PBR fur material,
## a quadruped skeleton, and all canonical ambient clips. Keeping this adapter
## small makes the Blender build the single source of truth for geometry and
## animation while preserving the SharedCharacterRig API used by map actors.

const REQUIRED_ANIMATIONS: Array[StringName] = [
	&"idle",
	&"walk",
	&"sleep",
	&"lick",
	&"stretch",
]
const LOOPING_CAT_ANIMATIONS: Array[StringName] = [
	&"idle",
	&"walk",
	&"sleep",
	&"lick",
]
## Ground speed the authored walk cycle covers: 0.134 m of stance travel per
## 0.66 duty factor over the 0.633 s clip Godot imports. Driving the clip near
## this speed is what keeps the paws planted instead of skating.
const WALK_REFERENCE_SPEED_WORLD := 0.32
const CAT_PROMPT_GLYPH_PADDING := 0.22
## The production report guarantees a standing AABB top near 0.40 m.
const STANDING_MODEL_HEIGHT := 0.401
## glTF Yup round-trips leave the skinned soles a few millimetres under y=0
## even when the Blender audit is green. Snap the imported model so idle soles
## sit on the actor origin; without this the loaf/sleep clips read as missing.
const GROUND_SNAP_EPSILON := 0.001


static func standing_glyph_height() -> float:
	return STANDING_MODEL_HEIGHT + CAT_PROMPT_GLYPH_PADDING


func view_glyph_height() -> float:
	return standing_glyph_height()


func _ready() -> void:
	# CatRig intentionally bypasses SharedCharacterRig's humanoid variant,
	# equipment, and head-scale setup while retaining its orientation helpers.
	var model := get_node_or_null("Model") as Node3D
	if model == null:
		push_error("Cat rig has no production model")
		return
	_animation_player = _find_animation_player(model)
	_skeleton = _find_skeleton(model)
	play_animation(start_animation)
	# Defer until the AnimationPlayer applies the bind/idle pose so the AABB
	# reflects skinned soles rather than the raw rest mesh.
	call_deferred("_snap_model_to_ground")


func _snap_model_to_ground() -> void:
	var model := get_node_or_null("Model") as Node3D
	if model == null or _animation_player == null:
		return
	if has_animation(&"idle"):
		_animation_player.play("idle")
		_animation_player.seek(0.0, true)
	var min_y := _measure_mesh_min_y()
	if min_y == INF:
		return
	# WHY: lift (or lower) the imported GLB so the lowest skinned vertex sits on
	# the actor origin. Ambient and forge placements both assume y=0 is the
	# floor, and a negative sole AABB is what made sleep/stretch disappear.
	model.position.y -= min_y - GROUND_SNAP_EPSILON


func _measure_mesh_min_y() -> float:
	var min_y := INF
	var model := get_node_or_null("Model") as Node3D
	var search_root: Node = model if model != null else self
	for found: Node in search_root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := found as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var local_xf := global_transform.affine_inverse() * mesh_instance.global_transform
		var aabb := mesh_instance.get_aabb()
		for endpoint_index: int in 8:
			min_y = minf(min_y, (local_xf * aabb.get_endpoint(endpoint_index)).y)
	return min_y


## Lowest skinned mesh Y in this rig's local space (for ground-contact tests).
func mesh_min_y() -> float:
	return _measure_mesh_min_y()


func has_animation(canonical_name: StringName) -> bool:
	if _animation_player == null:
		return false
	return _animation_player.has_animation(String(canonical_name))


func play_animation(canonical_name: StringName, blend_seconds: float = 0.12) -> bool:
	if not has_animation(canonical_name):
		push_warning("Unknown cat animation: %s" % canonical_name)
		return false
	var animation_name := String(canonical_name)
	if _animation_player.current_animation == animation_name:
		return true
	var animation := _animation_player.get_animation(animation_name)
	animation.loop_mode = (
		Animation.LOOP_LINEAR
		if canonical_name in LOOPING_CAT_ANIMATIONS
		else Animation.LOOP_NONE
	)
	_animation_player.play(animation_name, blend_seconds)
	return true


func current_canonical_animation() -> StringName:
	if _animation_player == null or _animation_player.current_animation.is_empty():
		return &"idle"
	return StringName(_animation_player.current_animation)


func set_locomotion_speed(world_speed: float) -> void:
	if _animation_player == null:
		return
	if current_canonical_animation() == &"walk":
		_animation_player.speed_scale = clampf(
			world_speed / WALK_REFERENCE_SPEED_WORLD,
			LOCOMOTION_SPEED_SCALE_MIN,
			LOCOMOTION_SPEED_SCALE_MAX
		)
	else:
		_animation_player.speed_scale = 1.0


func validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if _animation_player == null:
		errors.append("Cat rig has no AnimationPlayer")
	if _skeleton == null:
		errors.append("Cat rig has no Skeleton3D")
	for animation_name: StringName in REQUIRED_ANIMATIONS:
		if not has_animation(animation_name):
			errors.append("Missing cat animation: %s" % animation_name)
	return errors
