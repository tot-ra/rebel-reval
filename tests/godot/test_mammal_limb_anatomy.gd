extends "res://tests/godot/test_case.gd"

const SPECIES: Array[String] = ["forge_cat", "sheep", "dog", "pig", "goat", "boar", "fox", "hare"]
const LIMBS: Array[String] = ["LF", "RF", "LB", "RB"]

func test_imported_fore_and_hind_limb_landmarks() -> void:
	for species in SPECIES:
		var model := (load("res://assets/storybook/%s/%s.glb" % [species, species]) as PackedScene).instantiate()
		Engine.get_main_loop().root.add_child(model)
		var skeleton := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		for suffix in LIMBS:
			var proximal := skeleton.find_bone("Leg." + suffix)
			var middle := skeleton.find_bone("Shin." + suffix)
			var distal := skeleton.find_bone("Ankle." + suffix)
			var foot := skeleton.find_bone("Foot." + suffix)
			assert_true(distal >= 0, "%s/%s has a distinct carpal/tarsal-to-digit segment" % [species, suffix])
			if distal < 0:
				continue
			assert_eq(skeleton.get_bone_parent(foot), distal)
			var hip := skeleton.get_bone_global_rest(proximal).origin
			var knee := skeleton.get_bone_global_rest(middle).origin
			var hock := skeleton.get_bone_global_rest(distal).origin
			var ball := skeleton.get_bone_global_rest(foot).origin
			assert_true(hock.y > ball.y, "%s/%s ankle stays above the digit-bearing foot" % [species, suffix])
			if suffix.ends_with("B"):
				assert_true(knee.z > hip.z, "%s stifle points toward the nose" % species)
				assert_true(hock.z < knee.z, "%s hock points backward below the stifle" % species)
			else:
				assert_true(knee.z < hip.z, "%s elbow tucks behind shoulder" % species)
				assert_true(hock.z > knee.z, "%s forearm returns toward the support line" % species)
		model.free()

func test_imported_feet_keep_ground_support_through_complete_clips() -> void:
	for species in SPECIES:
		var model := (load("res://assets/storybook/%s/%s.glb" % [species, species]) as PackedScene).instantiate()
		Engine.get_main_loop().root.add_child(model)
		var skeleton := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		var body_height := skeleton.get_bone_global_rest(skeleton.find_bone("Body")).origin.y
		var tolerance := maxf(0.00035, body_height * 0.002)
		for clip: String in ["Idle", "Walk", "Run"]:
			player.play(clip)
			var duration := player.get_animation(clip).length
			for sample in 81:
				player.seek(duration * float(sample) / 80.0, true)
				skeleton.force_update_all_bone_transforms()
				var grounded := 0
				for suffix in LIMBS:
					var index := skeleton.find_bone("Foot." + suffix)
					var rest := skeleton.get_bone_global_rest(index)
					var rest_contact := Vector3(rest.origin.x, 0.0, rest.origin.z)
					var posed_contact := skeleton.get_bone_global_pose(index) * rest.affine_inverse() * rest_contact
					assert_true(posed_contact.y >= -tolerance, "%s/%s/%s sample %d sole penetrates ground: %f" % [species, clip, suffix, sample, posed_contact.y])
					if absf(posed_contact.y) <= tolerance:
						grounded += 1
				assert_true(grounded >= (4 if clip == "Idle" else 2), "%s/%s sample %d loses support (%d feet)" % [species, clip, sample, grounded])
		model.free()

func test_runtime_stride_rate_matches_exported_support_velocity() -> void:
	var models := preload("res://scripts/map/view3d/map_view_medieval_animal_models.gd")
	var aliases := {"forge_cat": &"cat", "fox": &"red_fox", "boar": &"wild_boar"}
	for species in SPECIES:
		var host := Node3D.new()
		Engine.get_main_loop().root.add_child(host)
		var model := models.add_model(host, aliases.get(species, StringName(species)))
		var skeleton := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := host.get_meta(models.ANIMATION_PLAYER_META) as AnimationPlayer
		for clip: String in ["Walk", "Run"]:
			var index := skeleton.find_bone("Foot.LB" if clip == "Walk" or species == "hare" else "Foot.LF")
			var rest := skeleton.get_bone_global_rest(index)
			var contact := rest.affine_inverse() * Vector3(rest.origin.x, 0.0, rest.origin.z)
			var duration := player.get_animation(clip).length
			player.play(clip)
			player.seek(duration * 0.10, true)
			skeleton.force_update_all_bone_transforms()
			var start := skeleton.get_bone_global_pose(index) * contact
			player.seek(duration * 0.20, true)
			skeleton.force_update_all_bone_transforms()
			var end := skeleton.get_bone_global_pose(index) * contact
			var relative := host.transform * host.global_transform.affine_inverse() * skeleton.global_transform
			var actual_speed := (relative.basis * (end - start)).length() / (duration * 0.10)
			var meta := models.WALK_REFERENCE_SPEED_META if clip == "Walk" else models.RUN_REFERENCE_SPEED_META
			assert_true(host.has_meta(meta), "%s carries its authored stride rate" % species)
			var reference := models._gait_reference_speed(host, meta)
			assert_true(absf(actual_speed - reference) < reference * 0.025, "%s/%s playback rate matches imported sole velocity (actual %f reference %f)" % [species, clip, actual_speed, reference])
		if species == "forge_cat":
			var original := models._gait_reference_speed(host, models.WALK_REFERENCE_SPEED_META)
			model.call("apply_coat", 81)
			assert_true(is_equal_approx(models._gait_reference_speed(host, models.WALK_REFERENCE_SPEED_META), original * model.scale.x), "Cat coat scale updates stride rate after loading")
		for speed: float in [0.03, 0.5, 1.4]:
			models.sync_animation(host, Vector3(-speed * 0.2, 0.0, 0.0), 0.2)
			var meta := models.RUN_REFERENCE_SPEED_META if speed > 1.2 else models.WALK_REFERENCE_SPEED_META
			var rate := models._gait_reference_speed(host, meta)
			assert_true(absf(player.speed_scale * rate - speed) < 0.0001, "%s does not clamp moving feet into skating at speed %f" % [species, speed])
		host.free()


func test_rat_retains_authored_rig_clips_and_world_scale_gait_metadata() -> void:
	var models := preload("res://scripts/map/view3d/map_view_medieval_animal_models.gd")
	var host := Node3D.new()
	Engine.get_main_loop().root.add_child(host)
	var model := models.add_model(host, &"rat")
	var skeleton := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	assert_true(skeleton.get_bone_count() > 100, "Rat retains its authored articulated toes and tail")
	var player := host.get_meta(models.ANIMATION_PLAYER_META) as AnimationPlayer
	assert_true(absf(player.get_animation("Walk").length - 0.466667) < .002, "Authored walk duration preserved")
	assert_true(host.has_meta(models.WALK_REFERENCE_SPEED_META), "Measured rat gait is exported")
	for speed: float in [.03, .5, 1.4]:
		models.sync_animation(host, Vector3(-speed * .2, 0, 0), .2)
		var meta := models.RUN_REFERENCE_SPEED_META if speed > 1.2 else models.WALK_REFERENCE_SPEED_META
		var reference := models._gait_reference_speed(host, meta)
		assert_true(reference > .01 and reference < 2.0, "Rat speed metadata is in metres after source scale")
		assert_true(absf(player.speed_scale * reference - speed) < .0001, "Rat playback follows measured displacement")
	host.free()
