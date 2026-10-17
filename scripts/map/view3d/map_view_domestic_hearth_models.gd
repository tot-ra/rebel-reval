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
	MapTypes.HEARTH_STATE_LIT:
	{
		"flame_size": 2.35,
		"flame_particles": 11,
		"day_energy": 0.42,
		"night_energy": 1.85,
		"range": 4.2,
		"smoke_amount": 18,
		"ember_energy": 3.2,
	},
	MapTypes.HEARTH_STATE_EMBERS:
	{
		"flame_size": 0.0,
		"flame_particles": 0,
		"day_energy": 0.08,
		"night_energy": 0.55,
		"range": 2.6,
		"smoke_amount": 8,
		"ember_energy": 1.6,
	},
	MapTypes.HEARTH_STATE_COLD:
	{
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
	var scene := MapViewPackedScenes.load_scene(HEARTH_KIT_SCENE_PATH)
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


## Fire in the mouth of a smoke dwelling's stone heap oven (R-1929). The oven
## itself is masonry in the building shell (rural_dwelling_plan.gd), so only the
## flame, its light and an ember bed are added here, at the mouth on the holder's
## front (-Z, HouseholdLayout hearth front); `prop.depth` is the oven's size.
## No hood and no flue: there is no chimney in a 1343 smoke room, so the smoke
## stays in the room (R-2281): a column out of the mouth and a layer pooled under
## the roof. `prop.room` (optional) is the house centre on the logic plane, in
## the parent's parent space, so the layer spreads into the room, not the wall.
static func add_oven_fire(parent: Node3D, prop: Dictionary) -> Node3D:
	var state := MapTypes.hearth_state_for_prop(prop)
	var profile: Dictionary = STATE_PROFILES[state].duplicate()
	# Flames stay low in the oven mouth; the heap has no open fire on top.
	profile["flame_size"] = float(profile.get("flame_size", 0.0)) * 0.3
	profile["flicker_phase"] = float(abs(String(prop.get("id", state)).hash()) % 628) * 0.01
	var anchor := Node3D.new()
	anchor.name = "OvenMouth"
	anchor.position = Vector3(0.0, 0.2, -(float(prop.get("depth", 1.6)) * 0.5 - 0.12))
	parent.add_child(anchor)
	var flame: GPUParticles3D = null
	if float(profile.get("flame_size", 0.0)) > 0.0:
		flame = FLAME_SCRIPT.new() as GPUParticles3D
		flame.configure(profile)
		anchor.add_child(flame)
	var ember_energy := float(profile.get("ember_energy", 0.0))
	if ember_energy > 0.0:
		var bed := MeshInstance3D.new()
		bed.name = "EmberBed"
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.42, 0.05, 0.3)
		bed.mesh = mesh
		var glow := StandardMaterial3D.new()
		glow.albedo_color = Color(0.3, 0.08, 0.02)
		glow.emission_enabled = true
		glow.emission = Color(1.0, 0.36, 0.08)
		glow.emission_energy_multiplier = ember_energy
		bed.material_override = glow
		anchor.add_child(bed)
	var light := OmniLight3D.new()
	light.name = "Omni"
	light.position = Vector3(0.0, 0.25, -0.35)
	anchor.add_child(light)
	var smoke_amount := int(profile.get("smoke_amount", 0))
	var column: GPUParticles3D = null
	if smoke_amount > 0:
		column = _smoke_room_column(anchor, smoke_amount, state == MapTypes.HEARTH_STATE_LIT)
		_smoke_room_layer(parent, prop, state == MapTypes.HEARTH_STATE_LIT)
	var controller = LIGHT_SCRIPT.new()
	controller.configure(light, flame, column, profile)
	parent.add_child(controller)
	return anchor


## Smoke leaving a chimneyless oven's mouth: it rolls out and up the oven's
## front into the room (no draught pulls it into a flue). Lit puffs from the
## chimney plume shader, so the fire's own light colours them.
static func _smoke_room_column(anchor: Node3D, amount: int, lit: bool) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = "OvenSmoke"
	particles.amount = amount * (2 if lit else 1)
	particles.lifetime = 3.2
	particles.preprocess = 3.2
	particles.randomness = 0.3
	particles.local_coords = true
	particles.draw_order = GPUParticles3D.DRAW_ORDER_VIEW_DEPTH
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.visibility_aabb = AABB(Vector3(-1.5, -0.5, -2.0), Vector3(3.0, 3.0, 3.0))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(0.22, 0.12, 0.05)
	# Out of the mouth (-Z) and up; slow, warm and lazy without a draught.
	process.direction = Vector3(0.0, 0.8, -0.6)
	process.spread = 18.0
	process.initial_velocity_min = 0.25 if lit else 0.12
	process.initial_velocity_max = 0.5 if lit else 0.22
	process.gravity = Vector3(0.0, 0.35 if lit else 0.15, 0.0)
	process.damping_min = 0.2
	process.damping_max = 0.4
	process.angle_min = -180.0
	process.angle_max = 180.0
	process.turbulence_enabled = true
	process.turbulence_noise_strength = 0.8
	process.turbulence_noise_scale = 1.6
	process.turbulence_influence_min = 0.03
	process.turbulence_influence_max = 0.08
	process.scale_min = 0.35
	process.scale_max = 0.6
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.4))
	grow.add_point(Vector2(1.0, 1.6))
	var grow_texture := CurveTexture.new()
	grow_texture.curve = grow
	process.scale_curve = grow_texture
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.34, 0.31, 0.28, 0.0))
	ramp.set_color(1, Color(0.5, 0.48, 0.46, 0.0))
	ramp.add_point(0.12, Color(0.36, 0.33, 0.3, 0.42 if lit else 0.22))
	ramp.add_point(0.7, Color(0.46, 0.44, 0.42, 0.26 if lit else 0.12))
	var ramp_texture := GradientTexture1D.new()
	ramp_texture.gradient = ramp
	process.color_ramp = ramp_texture
	particles.process_material = process
	var puff := QuadMesh.new()
	puff.size = Vector2.ONE
	puff.material = ChimneySmoke3D.smoke_material()
	particles.draw_pass_1 = puff
	anchor.add_child(particles)
	return particles


## The smoke ceiling of a smoke room: a slow, thin layer from about 1.5 m up to
## the roof, where the household's smoke hung until it seeped out through the
## vents and the door. Thinner while the fire is only banked.
static func _smoke_room_layer(parent: Node3D, prop: Dictionary, lit: bool) -> GPUParticles3D:
	# Spread between the oven and the house centre: the oven stands in a back
	# corner, so the layer reaches into the room and stays clear of the walls.
	var toward := Vector3(0.0, 0.0, -1.5)
	if prop.has("room"):
		var room: Vector2 = prop["room"]
		var rel := Vector3(room.x - parent.position.x, 0.0, room.y - parent.position.z)
		toward = rel.rotated(Vector3.UP, -parent.rotation.y)
	toward = toward.limit_length(3.2)
	var particles := GPUParticles3D.new()
	particles.name = "SmokeCeiling"
	particles.amount = 28 if lit else 12
	particles.lifetime = 9.0
	particles.preprocess = 9.0
	particles.randomness = 0.4
	particles.local_coords = true
	particles.draw_order = GPUParticles3D.DRAW_ORDER_VIEW_DEPTH
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.visibility_aabb = AABB(Vector3(-5.0, 0.0, -5.0), Vector3(10.0, 3.0, 10.0))
	particles.position = toward * 0.5 + Vector3(0.0, 1.8, 0.0)
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(
		absf(toward.x) * 0.45 + 0.45, 0.18, absf(toward.z) * 0.45 + 0.45
	)
	process.direction = Vector3(1.0, 0.0, 0.0)
	process.spread = 180.0
	process.flatness = 1.0
	process.initial_velocity_min = 0.02
	process.initial_velocity_max = 0.08
	process.gravity = Vector3.ZERO
	process.angle_min = -180.0
	process.angle_max = 180.0
	process.angular_velocity_min = -4.0
	process.angular_velocity_max = 4.0
	process.scale_min = 1.1
	process.scale_max = 1.8
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.42, 0.4, 0.38, 0.0))
	ramp.set_color(1, Color(0.42, 0.4, 0.38, 0.0))
	# Thin enough that the room still reads through it from the cutaway camera.
	ramp.add_point(0.3, Color(0.42, 0.4, 0.38, 0.16 if lit else 0.08))
	ramp.add_point(0.7, Color(0.44, 0.42, 0.4, 0.14 if lit else 0.07))
	var ramp_texture := GradientTexture1D.new()
	ramp_texture.gradient = ramp
	process.color_ramp = ramp_texture
	particles.process_material = process
	var puff := QuadMesh.new()
	puff.size = Vector2.ONE
	puff.material = ChimneySmoke3D.smoke_material()
	particles.draw_pass_1 = puff
	# The parent's child, not the mouth anchor's: the layer is the room's, at
	# floor-relative height.
	parent.add_child(particles)
	return particles


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


## Smoke drawn up the hood into the flue: it fades within about 0.3 m of
## the throat, inside the brick flue and the house's chimney breast above it
## (city_chimney_builder.gd), instead of filling the room. The plume over
## the roof is the chimney's own (CityChimneySmoke).
static func _attach_hood_smoke(anchor: Node3D, amount: int) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = "HearthSmoke"
	particles.amount = max(amount, 1)
	particles.lifetime = 0.6
	particles.preprocess = 0.4
	particles.explosiveness = 0.0
	particles.randomness = 0.45
	particles.local_coords = true
	particles.emitting = amount > 0
	particles.visibility_aabb = AABB(Vector3(-0.5, -0.2, -0.5), Vector3(1.0, 1.0, 1.0))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(0.06, 0.03, 0.04)
	process.direction = Vector3.UP
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
	# Puffs no wider than the flue (0.34 x 0.24 m), or they show through its sides.
	var draw := SphereMesh.new()
	draw.radius = 0.09
	draw.height = 0.18
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
