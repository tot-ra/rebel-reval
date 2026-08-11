class_name MapViewMedievalLightingModels
extends RefCounted

## Runtime selector for the Reval 1343 lighting kit. The GLB keeps historically
## distinct fuels and holders together for shared materials, while the map owns
## which one belongs in each household or workspace.

const LIGHTING_KIT_SCENE_PATH := "res://assets/props/lighting/medieval_lighting_kit.glb"
const FLAME_SCRIPT := preload("res://scripts/map/view3d/candle_flame_3d.gd")
const VARIANT_ROOT_NAMES: Dictionary = {
	MapTypes.LIGHTING_VARIANT_POOR_TALLOW: &"PoorTallow",
	MapTypes.LIGHTING_VARIANT_ARTISAN_TALLOW: &"ArtisanTallow",
	MapTypes.LIGHTING_VARIANT_RICH_BEESWAX: &"RichBeeswax",
	MapTypes.LIGHTING_VARIANT_GREASE_LAMP: &"GreaseLamp",
	MapTypes.LIGHTING_VARIANT_PINE_SPLINT: &"PineSplint",
}
const LIGHT_PROFILES: Dictionary = {
	MapTypes.LIGHTING_VARIANT_POOR_TALLOW:
	{
		"color": Color8(255, 176, 88),
		"day_energy": 0.12,
		"night_energy": 0.90,
		"range": 2.4,
		"flame_size": 0.82,
	},
	MapTypes.LIGHTING_VARIANT_ARTISAN_TALLOW:
	{
		"color": Color8(255, 188, 98),
		"day_energy": 0.16,
		"night_energy": 1.18,
		"range": 3.0,
		"flame_size": 0.90,
	},
	MapTypes.LIGHTING_VARIANT_RICH_BEESWAX:
	{
		"color": Color8(255, 205, 122),
		"day_energy": 0.18,
		"night_energy": 1.35,
		"range": 3.2,
		"flame_size": 1.0,
	},
	MapTypes.LIGHTING_VARIANT_GREASE_LAMP:
	{
		"color": Color8(255, 166, 76),
		"day_energy": 0.11,
		"night_energy": 0.82,
		"range": 2.3,
		"flame_size": 0.78,
	},
	MapTypes.LIGHTING_VARIANT_PINE_SPLINT:
	{
		"color": Color8(255, 156, 62),
		"day_energy": 0.14,
		"night_energy": 1.05,
		"range": 2.7,
		"flame_size": 0.88,
		"flame_particles": 8,
	},
}


static func add_model(parent: Node3D, prop: Dictionary) -> Node3D:
	var variant := MapTypes.lighting_variant_for_prop(prop)
	var scene := load(LIGHTING_KIT_SCENE_PATH) as PackedScene
	assert(scene != null, "Medieval lighting GLB must be imported before map assembly")
	var model := scene.instantiate() as Node3D
	assert(model != null, "Medieval lighting GLB root must be Node3D")
	model.name = "LightingModel"
	parent.add_child(model)

	var selected_name: StringName = VARIANT_ROOT_NAMES[variant]
	var selected := model.find_child(String(selected_name), true, false) as Node3D
	assert(
		selected != null, "Medieval lighting variant root is missing: %s" % String(selected_name)
	)
	for root_name in VARIANT_ROOT_NAMES.values():
		if root_name == selected_name:
			continue
		var unused := model.find_child(String(root_name), true, false) as Node3D
		if unused != null:
			unused.get_parent().remove_child(unused)
			unused.free()

	model.set_meta(&"production_lighting_model", true)
	model.set_meta(&"lighting_variant", variant)
	selected.set_meta(&"lighting_variant", variant)

	# The generated model contains fuel and a charred wick but no fire geometry.
	# Anchoring a runtime effect to the marker keeps every holder reusable unlit.
	var flame_anchor := selected.find_child("FlameAnchor*", true, false) as Node3D
	assert(flame_anchor != null, "Medieval lighting variant needs a separate FlameAnchor marker")
	var light_profile: Dictionary = LIGHT_PROFILES[variant].duplicate()
	# Stable authored IDs de-synchronize nearby flames without random state.
	light_profile["flicker_phase"] = float(abs(String(prop.get("id", variant)).hash()) % 628) * 0.01
	var flame := FLAME_SCRIPT.new() as GPUParticles3D
	flame.configure(light_profile)
	flame_anchor.add_child(flame)

	var light := OmniLight3D.new()
	light.name = "Omni"
	light.position.y = 0.06 * float(light_profile.get("flame_size", 1.0))
	flame_anchor.add_child(light)
	var controller = MapViewMeshBuilderConfig.CANDLE_LIGHT_SCRIPT.new()
	controller.configure(light, flame, light_profile)
	parent.add_child(controller)
	return model
