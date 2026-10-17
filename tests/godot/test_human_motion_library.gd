extends "res://tests/godot/test_case.gd"

## R-2211: realistic body GLBs carry no clips; one library per body shape is mounted at
## spawn (scripts/characters/human_motion_library.gd, docs/SYSTEMS/HUMAN_MOTION_LIBRARY.md).

const LIBRARY := preload("res://scripts/characters/human_motion_library.gd")
const BODY_DIR := "res://assets/characters/realistic/"
const CLIP_COUNT := 76
const RIG_PATH := "HumanMotionRig/Skeleton3D"


func _bodies() -> Array[String]:
	var found: Array[String] = []
	for dir_name in DirAccess.get_directories_at(BODY_DIR):
		if ResourceLoader.exists("%s%s/%s.glb" % [BODY_DIR, dir_name, dir_name]):
			found.append(dir_name)
	return found


func test_every_body_has_a_shape_and_no_embedded_clips() -> void:
	var bodies := _bodies()
	assert_true(bodies.size() >= 40, "found %d realistic bodies" % bodies.size())
	for body in bodies:
		assert_false(LIBRARY.shape_of(body).is_empty(), "%s has no motion shape in shapes.json" % body)
		var scene := (load("%s%s/%s.glb" % [BODY_DIR, body, body]) as PackedScene).instantiate()
		assert_true(scene.find_children("*", "AnimationPlayer", true, false).is_empty(),
			"%s embeds an AnimationPlayer again" % body)
		scene.free()


func test_every_clip_track_resolves_to_a_bone_of_every_body() -> void:
	for body in _bodies():
		var root := (load("%s%s/%s.glb" % [BODY_DIR, body, body]) as PackedScene).instantiate()
		var model := Node3D.new()
		model.add_child(root)
		var skeleton := root.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player: AnimationPlayer = LIBRARY.attach(model, skeleton)
		assert_true(player != null, "%s got no player" % body)
		if player != null:
			var names := player.get_animation_list()
			assert_eq(names.size(), CLIP_COUNT, "%s clip count" % body)
			var clip := player.get_animation(&"Walking_B")
			assert_true(clip.length > 0.1, "%s Walking_B has no length" % body)
			for track in clip.get_track_count():
				var path := clip.track_get_path(track)
				var bone := String(path.get_concatenated_subnames())
				var target := root.get_node_or_null(NodePath(path.get_concatenated_names()))
				assert_true(target == skeleton and skeleton.find_bone(bone) >= 0,
					"%s: %s does not resolve" % [body, path])
		model.free()


func test_outfit_variants_share_one_library_and_builds_do_not() -> void:
	var average := "citizen_f_adult_average"
	var a: AnimationLibrary = LIBRARY.library_for(average, RIG_PATH)
	var b: AnimationLibrary = LIBRARY.library_for(average + "_b", RIG_PATH)
	var child: AnimationLibrary = LIBRARY.library_for("citizen_f_child_average", RIG_PATH)
	assert_true(a != null and a == b, "outfit variants must share Animation resources")
	assert_true(child != null and child != a, "a child needs its own stature-fitted clips")


func test_hips_height_follows_each_bodys_own_rest() -> void:
	# The reason clips are per shape: hips travel is fitted to each rest pose, so a child's
	# idle hips must sit near the child's rest height, not an adult's.
	for body in ["citizen_f_child_average", "citizen_m_adult_average", "kalev"]:
		var root := (load("%s%s/%s.glb" % [BODY_DIR, body, body]) as PackedScene).instantiate()
		var model := Node3D.new()
		model.add_child(root)
		var skeleton := root.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player: AnimationPlayer = LIBRARY.attach(model, skeleton)
		var clip := player.get_animation(&"Idle")
		var hips_path := NodePath("%s:hips" % root.get_path_to(skeleton))
		var track := clip.find_track(hips_path, Animation.TYPE_POSITION_3D)
		assert_true(track >= 0, "%s Idle animates the hips position" % body)
		var hips_y := (clip.track_get_key_value(track, 0) as Vector3).y
		var rest_y := skeleton.get_bone_rest(skeleton.find_bone(&"hips")).origin.y
		assert_true(absf(hips_y - rest_y) < 0.08,
			"%s idle hips %.3f vs rest %.3f" % [body, hips_y, rest_y])
		model.free()
