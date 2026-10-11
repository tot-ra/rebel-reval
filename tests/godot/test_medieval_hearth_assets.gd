extends "res://tests/godot/test_case.gd"

const HearthModels := preload("res://scripts/map/view3d/map_view_domestic_hearth_models.gd")


func test_each_hearth_state_uses_production_model_without_baked_flame() -> void:
	for state in MapTypes.HEARTH_STATES:
		var host := Node3D.new()
		var model := HearthModels.add_model(host, {
			"kind": MapTypes.PROP_KIND_HEARTH,
			"id": &"domestic_hearth",
			"style_variant": state,
		})
		assert_true(model.get_meta(&"production_domestic_hearth_model", false), "%s must use the production GLB" % state)
		assert_eq(model.get_meta(&"hearth_state"), state)

		var selected_roots := 0
		for root_name in HearthModels.VARIANT_ROOT_NAMES.values():
			if model.find_child(String(root_name), true, false) != null:
				selected_roots += 1
		assert_eq(selected_roots, 1, "%s must hide the other hearth states" % state)

		assert_true(_find_static_flame(model) == null, "%s must not retain baked flame geometry" % state)
		var flame_anchor := model.find_child("FlameAnchor*", true, false) as Node3D
		var smoke_anchor := model.find_child("SmokeAnchor*", true, false) as Node3D
		assert_true(flame_anchor != null, "%s needs a FlameAnchor marker" % state)
		assert_true(smoke_anchor != null, "%s needs a SmokeAnchor marker" % state)

		var cauldron := model.find_child("CauldronBody*", true, false) as MeshInstance3D
		assert_true(cauldron != null, "%s needs a suspended cauldron body" % state)
		assert_true(cauldron.position.y >= 0.7, "%s cauldron must hang above the grate" % state)

		var flame := flame_anchor.get_node_or_null("CandleFlame") as GPUParticles3D
		var light := flame_anchor.get_node_or_null("Omni") as OmniLight3D
		var smoke := smoke_anchor.get_node_or_null("HearthSmoke") as GPUParticles3D
		var controller := host.get_node_or_null("DomesticHearthLight") as DomesticHearthLight3D
		assert_true(controller != null, "%s needs a hearth light controller" % state)

		match state:
			MapTypes.HEARTH_STATE_LIT:
				assert_true(flame != null and flame.emitting, "lit hearth needs runtime flame particles")
				assert_true(light != null and light.light_energy > 0.0, "lit hearth needs local light")
				assert_true(smoke != null and smoke.emitting, "lit hearth vents smoke through the hood")
			MapTypes.HEARTH_STATE_EMBERS:
				assert_true(flame == null, "ember hearth must not spawn flame particles")
				assert_true(light != null and light.light_energy > 0.0, "ember hearth keeps a dim glow")
				assert_true(smoke != null and smoke.emitting, "ember hearth keeps a thin smoke wisp")
			MapTypes.HEARTH_STATE_COLD:
				assert_true(flame == null, "cold hearth must not spawn flame particles")
				assert_true(light != null and light.light_energy == 0.0, "cold hearth stays unlit")
				assert_true(smoke != null and not smoke.emitting, "cold hearth must not vent smoke")

		host.free()


func test_unknown_hearth_state_falls_back_to_lit() -> void:
	var prop := {
		"kind": MapTypes.PROP_KIND_HEARTH,
		"style_variant": &"hearth.steam",
	}
	assert_eq(MapTypes.hearth_state_for_prop(prop), MapTypes.HEARTH_STATE_LIT)
	assert_eq(MapTypes.invalid_hearth_state(prop), &"hearth.steam")
	assert_false(MapPropStyleVariants.is_known(MapTypes.PROP_KIND_HEARTH, &"hearth.steam"))


func _find_static_flame(root: Node) -> MeshInstance3D:
	for child in root.find_children("*", "MeshInstance3D", true, false):
		if String(child.name).begins_with("Flame"):
			return child as MeshInstance3D
	return null
