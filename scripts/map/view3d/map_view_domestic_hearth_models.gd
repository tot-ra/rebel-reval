class_name MapViewDomesticHearthModels
extends RefCounted

## Runtime selector for the Reval 1343 hooded brick cooking-hearth kit. The GLB keeps
## lit, ember, and cold fuel states together while runtime flame, light, and smoke
## attach only to exported anchors - never as baked fire geometry.

const HEARTH_KIT_SCENE_PATH := "res://assets/props/domestic/hearth/medieval_hearth_kit.glb"
const FLAME_SCRIPT := preload("res://scripts/map/view3d/candle_flame_3d.gd")
const LIGHT_SCRIPT := preload("res://scripts/map/view3d/domestic_hearth_light_3d.gd")

const VARIANT_ROOT_NAMES: Dictionary = {
	MapTypes.HEARTH_STATE_LIT: &"HearthLit",
	MapTypes.HEARTH_STATE_EMBERS: &"HearthEmbers",
	MapTypes.HEARTH_STATE_COLD: &"HearthCold",
}

const STATE_PROFILES: Dictionary = {
	MapTypes.HEARTH_STATE_LIT: {
		"flame_size": 2.35,
		"flame_particles": 11,
		"day_energy": 0.42,
		"night_energy": 1.85,
		"range": 4.2,
		"smoke_amount": 18,
		"ember_energy": 3.2,
	},
	MapTypes.HEARTH_STATE_EMBERS: {
		"flame_size": 0.0,
		"flame_particles": 0,
		"day_energy": 0.08,
		"night_energy": 0.55,
		"range": 2.6,
		"smoke_amount": 8,
		"ember_energy": 1.6,
	},
	MapTypes.HEARTH_STATE_COLD: {
		"flame_size": 0.0,
		"flame_particles": 0,
		"day_energy": 0.0,
		"night_energy": 0.0,
		"range": 0.0,
		"smoke_amount": 0,
		"ember_energy": 0.0,
	},
}


static func add_model(parent: Node3D, prop: Dictionary) -> Node3D:
	var state := MapTypes.hearth_state_for_prop(prop)
	var scene := load(HEARTH_KIT_SCENE_PATH) as PackedScene
	assert(scene != null, "Medieval hearth GLB must be imported before map assembly")
	var model := scene.instantiate() as Node3D
	assert(model != null, "Medieval hearth GLB root must be Node3D")
	model.name = "DomesticHearthModel"
	parent.add_child(model)

	var selected_name: StringName = VARIANT_ROOT_NAMES[state]
	var selected := model.find_child(String(selected_name), true, false) as Node3D
	assert(selected != null, "Medieval hearth variant root is missing: %s" % String(selected_name))
	for root_name in VARIANT_ROOT_NAMES.values():
		if root_name == selected_name:
			continue
		var unused := model.find_child(String(root_name), true, false) as Node3D
		if unused != null:
			unused.get_parent().remove_child(unused)
			unused.free()

	model.set_meta(&"production_domestic_hearth_model", true)
	model.set_meta(&"hearth_state", state)
	selected.set_meta(&"hearth_state", state)

	var profile: Dictionary = STATE_PROFILES[state].duplicate()
	profile["flicker_phase"] = float(abs(String(prop.get("id", state)).hash()) % 628) * 0.01
	var flame_anchor := selected.find_child("FlameAnchor*", true, false) as Node3D
	var smoke_anchor := selected.find_child("SmokeAnchor*", true, false) as Node3D
	assert(flame_anchor != null, "Domestic hearth needs a FlameAnchor marker")
	assert(smoke_anchor != null, "Domestic hearth needs a SmokeAnchor marker at the hood throat")

	var flame: GPUParticles3D = null
	if float(profile.get("flame_size", 0.0)) > 0.0:
		flame = FLAME_SCRIPT.new() as GPUParticles3D
		flame.configure(profile)
		flame_anchor.add_child(flame)

	var light := OmniLight3D.new()
	light.name = "Omni"
	light.position.y = 0.08 * max(float(profile.get("flame_size", 1.0)), 1.0)
	flame_anchor.add_child(light)

	var smoke := _attach_hood_smoke(smoke_anchor, int(profile.get("smoke_amount", 0)))

	_apply_ember_glow(selected, float(profile.get("ember_energy", 0.0)))

	var controller = LIGHT_SCRIPT.new()
	controller.configure(light, flame, smoke, profile)
	parent.add_child(controller)
	return model


static func _apply_ember_glow(selected: Node3D, energy: float) -> void:
	for node_name in ["EmberBed*", "AshBed*"]:
		var bed := selected.find_child(node_name, true, false) as MeshInstance3D
		if bed == null or bed.mesh == null:
			continue
		var material := bed.get_active_material(0)
		if material == null:
			continue
		var emissive := material.duplicate() as StandardMaterial3D
		emissive.emission_enabled = energy > 0.0
		emissive.emission_energy_multiplier = energy
		if node_name == "AshBed*":
			emissive.emission_enabled = false
		bed.material_override = emissive


static func _attach_hood_smoke(anchor: Node3D, amount: int) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = "HearthSmoke"
	particles.amount = max(amount, 1)
	particles.lifetime = 2.1
	particles.preprocess = 1.2
	particles.explosiveness = 0.0
	particles.randomness = 0.45
	particles.local_coords = true
	particles.emitting = amount > 0
	particles.visibility_aabb = AABB(Vector3(-0.5, -0.2, -0.5), Vector3(1.0, 2.4, 1.0))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(0.12, 0.04, 0.08)
	process.direction = Vector3(0.0, 1.0, -0.12).normalized()
	process.spread = 8.0
	process.initial_velocity_min = 0.25
	process.initial_velocity_max = 0.55
	process.gravity = Vector3(0.0, 0.18, 0.0)
	var smoke_ramp := Gradient.new()
	smoke_ramp.set_color(0, Color(0.32, 0.28, 0.25, 0.0))
	smoke_ramp.set_color(1, Color(0.16, 0.15, 0.14, 0.0))
	smoke_ramp.add_point(0.25, Color(0.3, 0.27, 0.24, 0.28))
	smoke_ramp.add_point(0.65, Color(0.22, 0.2, 0.19, 0.18))
	var smoke_ramp_texture := GradientTexture1D.new()
	smoke_ramp_texture.gradient = smoke_ramp
	process.color_ramp = smoke_ramp_texture
	particles.process_material = process
	var draw := SphereMesh.new()
	draw.radius = 0.5
	draw.height = 1.0
	draw.radial_segments = 6
	draw.rings = 3
	particles.draw_pass_1 = draw
	var smoke_mat := StandardMaterial3D.new()
	smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke_mat.vertex_color_use_as_albedo = true
	smoke_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	smoke_mat.billboard_keep_scale = true
	particles.material_override = smoke_mat
	anchor.add_child(particles)
	return particles
