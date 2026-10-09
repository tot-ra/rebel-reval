extends "res://tests/godot/test_case.gd"

const RIG_SCENE := preload("res://assets/characters/shared/shared_character_rig.tscn")
const AuraView := preload("res://scripts/combat/spirit_aura_view.gd")
const AuraManager := preload("res://scripts/combat/spirit_aura_manager.gd")

var _host: Node3D


func before_each() -> void:
	super.before_each()
	_host = Node3D.new()
	_tree().root.add_child(_host)


func after_each() -> void:
	_host.free()
	super.after_each()


func test_anchors_follow_bones_and_rig_moves() -> void:
	var rig := _rig("MartRig", Vector3.ZERO)
	await _tree().process_frame
	var view := AuraView.new()
	rig.add_child(view)
	view.bind(rig, _profile([2, 2, 2, 2, 2, 2, 2], 1.0))
	var skeleton := rig.skeleton()
	var hips := skeleton.global_transform * skeleton.get_bone_global_pose(
		skeleton.find_bone("hips")).origin
	var spine := skeleton.global_transform * skeleton.get_bone_global_pose(
		skeleton.find_bone("spine")).origin
	assert_true(view.anchors[0].distance_to(hips.lerp(spine, 0.1)) < 0.001, "root on hips")
	for i in range(1, 7):
		assert_true(view.anchors[i].y > view.anchors[i - 1].y, "lights climb pelvis to crown")
	# The head bone sits at the skull base; the skull crown is about 0.33 m up.
	# The violet light rests just on the crown, not far above it.
	var crown_rise := view.anchors[6].y - _head_y(rig)
	assert_true(crown_rise > 0.33 and crown_rise < 0.5, "crown on the skull: %s" % crown_rise)
	var brow_rise := view.anchors[5].y - _head_y(rig)
	assert_true(brow_rise > 0.15 and brow_rise < 0.3, "brow light on the forehead: %s" % brow_rise)
	var before := view.anchors[3]
	rig.global_position = Vector3(5.0, 0.0, -3.0)
	view.update_anchors()
	assert_true(view.anchors[3].distance_to(before + Vector3(5.0, 0.0, -3.0)) < 0.001)
	assert_true(view.global_position.distance_to(view.anchors[0]) < 0.001)
	# Uniforms are relative to the root light so far-away maps keep precision.
	var relative: PackedVector3Array = view.shader_value(&"anchors")
	assert_true(relative[0].length() < 0.001)


func test_fixed_meshes_are_shared_and_never_rebuilt() -> void:
	var rig := _rig("ARig", Vector3.ZERO)
	await _tree().process_frame
	var a := AuraView.new()
	var b := AuraView.new()
	rig.add_child(a)
	rig.add_child(b)
	a.bind(rig, _profile([1, 1, 1, 1, 1, 1, 1], 1.0))
	b.bind(rig, _profile([5, 5, 5, 5, 5, 5, 5], 0.0))
	var ribbons := (a.get_node("FieldLines") as MeshInstance3D).mesh
	assert_eq((b.get_node("FieldLines") as MeshInstance3D).mesh, ribbons)
	a.set_tier(AuraView.Tier.FULL)
	a.update_anchors()
	a.update_anchors()
	assert_eq((a.get_node("FieldLines") as MeshInstance3D).mesh, ribbons)
	var ribbon_vertices := AuraView.RIBBON_LINES * (AuraView.RIBBON_SEGMENTS + 1) * 2
	assert_eq(ribbons.surface_get_array_len(0), ribbon_vertices)
	assert_eq(AuraView.light_mesh().surface_get_array_len(0), 32, "seven lights + sky beam")


func test_level_drives_intensity_and_clarity_drives_turbulence() -> void:
	var view := AuraView.new()
	_host.add_child(view)
	view.set_profile(_profile([0, 1, 2, 3, 4, 5, 5], 1.0))
	for i in 5:
		assert_true(view.intensity_at(i + 1) > view.intensity_at(i), "brighter with level %d" % i)
	assert_almost_eq(float(view.shader_value(&"turbulence")), 0.0, 0.0001)
	var bright_speed := float(view.shader_value(&"flow_speed"))
	view.set_profile(_profile([1, 1, 1, 1, 1, 1, 1], 0.2))
	assert_almost_eq(float(view.shader_value(&"turbulence")), 0.8, 0.0001)
	assert_true(float(view.shader_value(&"flow_speed")) < bright_speed, "weak souls flow slower")
	var levels: PackedFloat32Array = view.shader_value(&"levels")
	assert_eq(levels.size(), 7)


func test_sky_beam_grows_with_all_lights_and_needs_the_crown() -> void:
	var view := AuraView.new()
	_host.add_child(view)
	view.set_profile(_profile([5, 5, 5, 5, 5, 5, 0], 1.0))
	assert_almost_eq(view.sky_beam_strength(), 0.0, 0.0001, "closed crown: no tie to the sky")
	view.set_profile(_profile([5, 5, 5, 5, 5, 5, 5], 1.0))
	assert_almost_eq(view.sky_beam_strength(), 1.0, 0.0001, "whole soul at 5: full beam")
	assert_almost_eq(float(view.shader_value(&"beam_strength")), 1.0, 0.0001)
	view.set_profile(_profile([1, 1, 1, 1, 1, 1, 3], 1.0))
	var weak_body := view.sky_beam_strength()
	view.set_profile(_profile([4, 4, 4, 4, 4, 4, 3], 1.0))
	var strong_body := view.sky_beam_strength()
	assert_true(weak_body > 0.0 and strong_body > weak_body, "stronger lights, stronger beam")
	view.set_profile(_profile([4, 4, 4, 4, 4, 4, 1], 1.0))
	assert_true(view.sky_beam_strength() < strong_body, "a dim crown narrows the beam")


func test_reduced_flashing_calms_shimmer_and_pulse() -> void:
	var view := AuraView.new()
	_host.add_child(view)
	view.set_profile(_profile([4, 4, 4, 4, 4, 4, 4], 1.0))
	var shimmer := float(view.shader_value(&"shimmer"))
	assert_almost_eq(float(view.shader_value(&"calm")), 0.0, 0.0001)
	view.set_reduced_flashing(true)
	assert_true(float(view.shader_value(&"shimmer")) < shimmer * 0.2)
	assert_true(float(view.shader_value(&"calm")) > 0.8)


func test_budget_twelve_full_nearest_glow_to_forty_none_beyond() -> void:
	var bodies: Array = []
	for i in 20:
		var body := Node3D.new()
		_host.add_child(body)
		# Reverse order so ranking, not insertion, decides.
		body.global_position = Vector3(float(19 - i) * 0.5, 0.0, 0.0)
		bodies.append(body)
	var near_glow := Node3D.new()
	_host.add_child(near_glow)
	near_glow.global_position = Vector3(30.0, 0.0, 0.0)
	var far := Node3D.new()
	_host.add_child(far)
	far.global_position = Vector3(0.0, 0.0, 41.0)
	bodies.append_array([near_glow, far])
	var tiers := AuraManager.assign_tiers(Vector3.ZERO, bodies, 12.0)
	var full := 0
	for body: Node3D in bodies:
		if tiers[body] == AuraView.Tier.FULL:
			full += 1
			assert_true(body.global_position.length() <= 5.5, "full auras are the nearest")
	assert_eq(full, AuraManager.MAX_FULL)
	assert_eq(tiers[bodies[0]], AuraView.Tier.GLOW, "13th nearest within radius falls back to glow")
	assert_eq(tiers[near_glow], AuraView.Tier.GLOW)
	assert_eq(tiers[far], AuraView.Tier.NONE)
	var outside_radius := AuraManager.assign_tiers(Vector3(-20.0, 0.0, 0.0), bodies, 12.0)
	assert_eq(outside_radius[bodies[19]], AuraView.Tier.GLOW, "beyond sight radius only glows")


func test_hidden_outside_spirit_sight_and_shown_inside() -> void:
	var hero := _rig("PlayerRig", Vector3.ZERO)
	var npc := _rig("BerendRig", Vector3(2.0, 0.0, 0.0))
	var dog := Node3D.new()
	var dog_mesh := MeshInstance3D.new()
	dog_mesh.mesh = BoxMesh.new()
	dog.add_child(dog_mesh)
	_host.add_child(dog)
	dog.global_position = Vector3(0.0, 0.0, 3.0)
	var manager := AuraManager.new()
	manager.follow_session = false
	manager.state = GameState.new()
	_host.add_child(manager)
	manager.register(dog, SpiritAuraProfile.for_species("dog"))
	await _tree().process_frame
	await _tree().process_frame
	assert_eq(manager.view_for(npc), null, "no aura is built outside spirit sight")
	manager.fade = 1.0
	manager.refresh()
	for body: Node3D in [hero, npc, dog]:
		var view := manager.view_for(body)
		assert_true(view != null and view.visible, "%s glows in sight" % body.name)
		assert_eq(view.tier, AuraView.Tier.FULL)
	assert_eq(manager.view_for(dog).level_at(3), 3, "species profile kept for the dog")
	var dog_levels: PackedFloat32Array = manager.view_for(dog).shader_value(&"levels")
	assert_eq(dog_levels[1], -1.0, "an animal lacks lights its species has none of")
	var npc_levels: PackedFloat32Array = manager.view_for(npc).shader_value(&"levels")
	assert_false(npc_levels.has(-1.0), "a person's closed light stays a knot")
	manager.fade = 0.0
	await _tree().process_frame
	for body: Node3D in [hero, npc, dog]:
		assert_false(manager.view_for(body).visible, "%s hidden after sight closes" % body.name)


func test_fallback_layout_runs_tail_to_head_with_crown_above() -> void:
	var points := AuraView.fallback_layout(AABB(Vector3(-0.2, 0.0, -0.5), Vector3(0.4, 0.6, 1.0)))
	assert_eq(points.size(), 7)
	for i in range(1, 6):
		assert_true(points[i].z < points[i - 1].z, "lights run toward the head at -Z")
	assert_true(points[6].y > 0.6, "seventh light above the head")


func _rig(rig_name: String, at: Vector3) -> SharedCharacterRig:
	var rig := RIG_SCENE.instantiate() as SharedCharacterRig
	rig.name = rig_name
	_host.add_child(rig)
	rig.global_position = at
	return rig


func _profile(values: Array, clarity: float) -> SpiritAuraProfile:
	var profile := SpiritAuraProfile.new()
	for i in values.size():
		profile.levels[SpiritAuraProfile.LIGHT_IDS[i]] = int(values[i])
	profile.clarity = clarity
	return profile


func _head_y(rig: SharedCharacterRig) -> float:
	var skeleton := rig.skeleton()
	var head := skeleton.global_transform * skeleton.get_bone_global_pose(
		skeleton.find_bone("head")).origin
	return head.y


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree
