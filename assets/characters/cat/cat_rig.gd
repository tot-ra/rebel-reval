class_name CatRig
extends SharedCharacterRig

## Procedural low-poly cat rig for the forge (placeholder/demo asset).
## Built from Godot primitives so it adds no new raster art or external meshes.

const FUR_COLOR := Color(0.82, 0.52, 0.22, 1.0)
const EAR_COLOR := Color(0.78, 0.45, 0.20, 1.0)
const EYE_COLOR := Color(0.12, 0.10, 0.08, 1.0)
const NOSE_COLOR := Color(0.90, 0.60, 0.65, 1.0)
const TAIL_TIP_COLOR := Color(0.90, 0.62, 0.30, 1.0)

const BODY_SIZE := Vector3(0.24, 0.18, 0.42)
const HEAD_SIZE := Vector3(0.18, 0.16, 0.18)
const LEG_SIZE := Vector3(0.06, 0.14, 0.06)
const TAIL_SIZE := Vector3(0.06, 0.06, 0.34)
const EAR_SIZE := Vector3(0.05, 0.08, 0.05)

const WALK_REFERENCE_SPEED_WORLD := 1.5


func _ready() -> void:
	# Override the shared rig setup: the cat has no imported skeleton.
	var model := Node3D.new()
	model.name = &"Model"
	add_child(model)

	_build_body(model)
	_build_animations()
	play_animation(start_animation)


func _build_body(model: Node3D) -> void:
	var body := _add_box(model, &"Body", BODY_SIZE, Vector3(0.0, 0.23, 0.0), FUR_COLOR)

	var head := _add_box(body, &"Head", HEAD_SIZE, Vector3(0.0, 0.10, 0.22), FUR_COLOR)
	_add_box(head, &"EarLeft", EAR_SIZE, Vector3(-0.06, 0.10, 0.0), EAR_COLOR)
	_add_box(head, &"EarRight", EAR_SIZE, Vector3(0.06, 0.10, 0.0), EAR_COLOR)
	_add_box(head, &"EyeLeft", Vector3(0.03, 0.03, 0.01), Vector3(-0.05, 0.02, 0.09), EYE_COLOR)
	_add_box(head, &"EyeRight", Vector3(0.03, 0.03, 0.01), Vector3(0.05, 0.02, 0.09), EYE_COLOR)
	_add_box(head, &"Nose", Vector3(0.03, 0.02, 0.01), Vector3(0.0, -0.02, 0.09), NOSE_COLOR)

	var tail_pivot := _add_pivot(body, &"TailPivot", Vector3(0.0, 0.04, -0.21))
	_add_box(tail_pivot, &"Tail", TAIL_SIZE, Vector3(0.0, 0.0, -0.17), FUR_COLOR)
	_add_box(tail_pivot, &"TailTip", Vector3(0.065, 0.065, 0.08), Vector3(0.0, 0.0, -0.33), TAIL_TIP_COLOR)

	var fl := _add_pivot(body, &"LegPivotFL", Vector3(-0.09, -0.09, 0.12))
	var fr := _add_pivot(body, &"LegPivotFR", Vector3(0.09, -0.09, 0.12))
	var bl := _add_pivot(body, &"LegPivotBL", Vector3(-0.09, -0.09, -0.12))
	var br := _add_pivot(body, &"LegPivotBR", Vector3(0.09, -0.09, -0.12))
	_add_box(fl, &"LegFL", LEG_SIZE, Vector3(0.0, -0.07, 0.0), FUR_COLOR)
	_add_box(fr, &"LegFR", LEG_SIZE, Vector3(0.0, -0.07, 0.0), FUR_COLOR)
	_add_box(bl, &"LegBL", LEG_SIZE, Vector3(0.0, -0.07, 0.0), FUR_COLOR)
	_add_box(br, &"LegBR", LEG_SIZE, Vector3(0.0, -0.07, 0.0), FUR_COLOR)


func _add_box(parent: Node3D, name: StringName, size: Vector3, position: Vector3, color: Color) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = name
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh_instance.set_surface_override_material(0, material)
	mesh_instance.position = position
	parent.add_child(mesh_instance)
	return mesh_instance


func _add_pivot(parent: Node3D, name: StringName, position: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = name
	pivot.position = position
	parent.add_child(pivot)
	return pivot


func _build_animations() -> void:
	_animation_player = AnimationPlayer.new()
	_animation_player.name = &"AnimationPlayer"
	add_child(_animation_player)

	var library := AnimationLibrary.new()
	library.add_animation(&"idle", _make_idle_animation())
	library.add_animation(&"walk", _make_walk_animation())
	library.add_animation(&"sleep", _make_sleep_animation())
	library.add_animation(&"lick", _make_lick_animation())
	library.add_animation(&"stretch", _make_stretch_animation())
	_animation_player.add_animation_library(&"", library)


func _make_idle_animation() -> Animation:
	var anim := Animation.new()
	anim.length = 2.0
	anim.loop_mode = Animation.LOOP_LINEAR

	_add_value_track(anim, "Model/Body:position", [
		[0.0, Vector3(0.0, 0.23, 0.0)],
		[1.0, Vector3(0.0, 0.235, 0.0)],
		[2.0, Vector3(0.0, 0.23, 0.0)],
	])
	_add_value_track(anim, "Model/Body:rotation", [[0.0, Vector3.ZERO]])
	_add_value_track(anim, "Model/Body/Head:position", [[0.0, Vector3(0.0, 0.1, 0.22)]])
	_add_value_track(anim, "Model/Body/Head:rotation", [
		[0.0, Vector3(0.0, 0.0, 0.0)],
		[0.7, Vector3(0.05, 0.0, 0.0)],
		[1.4, Vector3(-0.05, 0.0, 0.0)],
		[2.0, Vector3(0.0, 0.0, 0.0)],
	])
	_add_value_track(anim, "Model/Body/TailPivot:rotation", [
		[0.0, Vector3(0.0, 0.0, 0.0)],
		[0.5, Vector3(0.0, 0.18, 0.0)],
		[1.5, Vector3(0.0, -0.18, 0.0)],
		[2.0, Vector3(0.0, 0.0, 0.0)],
	])
	for leg in ["FL", "FR", "BL", "BR"]:
		_add_value_track(anim, "Model/Body/LegPivot%s:rotation" % leg, [[0.0, Vector3.ZERO]])
	return anim


func _make_walk_animation() -> Animation:
	var anim := Animation.new()
	anim.length = 0.6
	anim.loop_mode = Animation.LOOP_LINEAR

	var leg_swing := 0.35
	_add_value_track(anim, "Model/Body/LegPivotFL:rotation", [
		[0.0, Vector3(0.0, 0.0, 0.0)],
		[0.15, Vector3(-leg_swing, 0.0, 0.0)],
		[0.3, Vector3(0.0, 0.0, 0.0)],
		[0.45, Vector3(leg_swing, 0.0, 0.0)],
		[0.6, Vector3(0.0, 0.0, 0.0)],
	])
	_add_value_track(anim, "Model/Body/LegPivotBR:rotation", [
		[0.0, Vector3(0.0, 0.0, 0.0)],
		[0.15, Vector3(-leg_swing, 0.0, 0.0)],
		[0.3, Vector3(0.0, 0.0, 0.0)],
		[0.45, Vector3(leg_swing, 0.0, 0.0)],
		[0.6, Vector3(0.0, 0.0, 0.0)],
	])
	_add_value_track(anim, "Model/Body/LegPivotFR:rotation", [
		[0.0, Vector3(0.0, 0.0, 0.0)],
		[0.15, Vector3(leg_swing, 0.0, 0.0)],
		[0.3, Vector3(0.0, 0.0, 0.0)],
		[0.45, Vector3(-leg_swing, 0.0, 0.0)],
		[0.6, Vector3(0.0, 0.0, 0.0)],
	])
	_add_value_track(anim, "Model/Body/LegPivotBL:rotation", [
		[0.0, Vector3(0.0, 0.0, 0.0)],
		[0.15, Vector3(leg_swing, 0.0, 0.0)],
		[0.3, Vector3(0.0, 0.0, 0.0)],
		[0.45, Vector3(-leg_swing, 0.0, 0.0)],
		[0.6, Vector3(0.0, 0.0, 0.0)],
	])
	_add_value_track(anim, "Model/Body:position", [
		[0.0, Vector3(0.0, 0.23, 0.0)],
		[0.15, Vector3(0.0, 0.245, 0.0)],
		[0.3, Vector3(0.0, 0.23, 0.0)],
		[0.45, Vector3(0.0, 0.245, 0.0)],
		[0.6, Vector3(0.0, 0.23, 0.0)],
	])
	_add_value_track(anim, "Model/Body:rotation", [[0.0, Vector3.ZERO]])
	_add_value_track(anim, "Model/Body/Head:position", [[0.0, Vector3(0.0, 0.1, 0.22)]])
	_add_value_track(anim, "Model/Body/Head:rotation", [[0.0, Vector3.ZERO]])
	_add_value_track(anim, "Model/Body/TailPivot:rotation", [
		[0.0, Vector3(0.0, 0.0, 0.0)],
		[0.2, Vector3(0.0, 0.15, 0.0)],
		[0.4, Vector3(0.0, -0.15, 0.0)],
		[0.6, Vector3(0.0, 0.0, 0.0)],
	])
	return anim


func _make_sleep_animation() -> Animation:
	var anim := Animation.new()
	anim.length = 2.0
	anim.loop_mode = Animation.LOOP_LINEAR

	_add_value_track(anim, "Model/Body:position", [
		[0.0, Vector3(0.0, 0.16, 0.0)],
		[1.0, Vector3(0.0, 0.165, 0.0)],
		[2.0, Vector3(0.0, 0.16, 0.0)],
	])
	_add_value_track(anim, "Model/Body:rotation", [
		[0.0, Vector3(0.0, 0.0, 0.0)],
		[2.0, Vector3(0.0, 0.0, 0.0)],
	])
	_add_value_track(anim, "Model/Body/Head:position", [
		[0.0, Vector3(0.0, 0.01, 0.18)],
	])
	_add_value_track(anim, "Model/Body/Head:rotation", [
		[0.0, Vector3(0.35, 0.0, 0.0)],
	])
	_add_value_track(anim, "Model/Body/TailPivot:rotation", [
		[0.0, Vector3(0.55, 0.0, 0.0)],
	])
	_add_value_track(anim, "Model/Body/LegPivotFL:rotation", [
		[0.0, Vector3(0.3, 0.0, 0.0)],
	])
	_add_value_track(anim, "Model/Body/LegPivotFR:rotation", [
		[0.0, Vector3(0.3, 0.0, 0.0)],
	])
	_add_value_track(anim, "Model/Body/LegPivotBL:rotation", [
		[0.0, Vector3(-0.2, 0.0, 0.0)],
	])
	_add_value_track(anim, "Model/Body/LegPivotBR:rotation", [
		[0.0, Vector3(-0.2, 0.0, 0.0)],
	])
	return anim


func _make_lick_animation() -> Animation:
	var anim := Animation.new()
	anim.length = 1.2
	anim.loop_mode = Animation.LOOP_LINEAR

	_add_value_track(anim, "Model/Body:position", [
		[0.0, Vector3(0.0, 0.19, 0.0)],
	])
	_add_value_track(anim, "Model/Body:rotation", [[0.0, Vector3.ZERO]])
	_add_value_track(anim, "Model/Body/Head:position", [[0.0, Vector3(0.0, 0.1, 0.22)]])
	_add_value_track(anim, "Model/Body/Head:rotation", [
		[0.0, Vector3(0.55, 0.0, 0.0)],
		[0.2, Vector3(0.65, 0.1, 0.0)],
		[0.4, Vector3(0.55, -0.1, 0.0)],
		[0.6, Vector3(0.65, 0.1, 0.0)],
		[0.8, Vector3(0.55, -0.1, 0.0)],
		[1.0, Vector3(0.65, 0.0, 0.0)],
		[1.2, Vector3(0.55, 0.0, 0.0)],
	])
	_add_value_track(anim, "Model/Body/TailPivot:rotation", [
		[0.0, Vector3(0.0, 0.0, 0.0)],
	])
	for leg in ["FL", "FR", "BL", "BR"]:
		_add_value_track(anim, "Model/Body/LegPivot%s:rotation" % leg, [[0.0, Vector3.ZERO]])
	return anim


func _make_stretch_animation() -> Animation:
	var anim := Animation.new()
	anim.length = 1.5
	anim.loop_mode = Animation.LOOP_LINEAR

	_add_value_track(anim, "Model/Body:position", [
		[0.0, Vector3(0.0, 0.17, 0.05)],
		[0.75, Vector3(0.0, 0.18, 0.05)],
		[1.5, Vector3(0.0, 0.17, 0.05)],
	])
	_add_value_track(anim, "Model/Body:rotation", [
		[0.0, Vector3(-0.25, 0.0, 0.0)],
	])
	_add_value_track(anim, "Model/Body/Head:position", [
		[0.0, Vector3(0.0, 0.12, 0.30)],
	])
	_add_value_track(anim, "Model/Body/Head:rotation", [
		[0.0, Vector3(-0.25, 0.0, 0.0)],
	])
	_add_value_track(anim, "Model/Body/TailPivot:rotation", [
		[0.0, Vector3(-0.55, 0.0, 0.0)],
		[0.5, Vector3(-0.65, 0.1, 0.0)],
		[1.0, Vector3(-0.55, -0.1, 0.0)],
		[1.5, Vector3(-0.55, 0.0, 0.0)],
	])
	for leg in ["FL", "FR", "BL", "BR"]:
		_add_value_track(anim, "Model/Body/LegPivot%s:rotation" % leg, [[0.0, Vector3.ZERO]])
	return anim


func _add_value_track(anim: Animation, path: NodePath, keys: Array) -> void:
	var track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track, path)
	anim.value_track_set_update_mode(track, Animation.UPDATE_CONTINUOUS)
	for key in keys:
		anim.track_insert_key(track, float(key[0]), key[1])


func has_animation(canonical_name: StringName) -> bool:
	if _animation_player == null:
		return false
	return _animation_player.has_animation(String(canonical_name))


func play_animation(canonical_name: StringName, _blend_seconds: float = 0.12) -> bool:
	if not has_animation(canonical_name):
		push_warning("Unknown cat animation: %s" % canonical_name)
		return false
	var anim_name := String(canonical_name)
	if _animation_player.current_animation == anim_name:
		return true
	_animation_player.play(anim_name)
	return true


func current_canonical_animation() -> StringName:
	if _animation_player == null:
		return &"idle"
	return StringName(_animation_player.current_animation)


func set_locomotion_speed(world_speed: float) -> void:
	if _animation_player == null:
		return
	if current_canonical_animation() == &"walk":
		_animation_player.speed_scale = clampf(
			world_speed / WALK_REFERENCE_SPEED_WORLD,
			0.7,
			1.5
		)
	else:
		_animation_player.speed_scale = 1.0


func set_facing(logic_direction: Vector2) -> void:
	if logic_direction.is_zero_approx():
		return
	rotation.y = atan2(logic_direction.x, logic_direction.y)


func face_toward(logic_direction: Vector2, delta: float) -> void:
	if logic_direction.is_zero_approx():
		return
	var target := atan2(logic_direction.x, logic_direction.y)
	var weight := 1.0 - exp(-TURN_SMOOTHING * delta)
	rotation.y = lerp_angle(rotation.y, target, weight)


func validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if _animation_player == null:
		errors.append("Cat rig has no AnimationPlayer")
	for name in [&"idle", &"walk", &"sleep", &"lick", &"stretch"]:
		if not has_animation(name):
			errors.append("Missing cat animation: %s" % name)
	return errors
