class_name MapViewHouseholdClutterModels
extends RefCounted

## Runtime selector for the Reval 1343 smithy household clutter kit. One GLB keeps
## every provision item, household tool, and grouped routine-state module as a
## separate root so maps can swap closed, in-use, depleted, and cleared layouts.

const HOUSEHOLD_CLUTTER_KIT_SCENE_PATH := "res://assets/props/domestic/household/smithy_household_clutter_kit.glb"

const VARIANT_ROOT_NAMES: Dictionary = {
	MapTypes.PROVISION_RYE_BREAD_LOAF: &"ProvisionRyeBreadLoaf",
	MapTypes.PROVISION_RYE_BREAD_CUT: &"ProvisionRyeBreadCut",
	MapTypes.PROVISION_DRIED_PEAS_BIN: &"ProvisionDriedPeasBin",
	MapTypes.PROVISION_ONION_BRAID: &"ProvisionOnionBraid",
	MapTypes.PROVISION_HERRING_FILLETED: &"ProvisionHerringFilleted",
	MapTypes.PROVISION_BEER_JUG: &"ProvisionBeerJug",
	MapTypes.PROVISION_SALT_CROCK: &"ProvisionSaltCrock",
	MapTypes.HOUSEHOLD_WATER_BUCKET: &"HouseholdWaterBucket",
	MapTypes.HOUSEHOLD_KINDLING_BUNDLE: &"HouseholdKindlingBundle",
	MapTypes.HOUSEHOLD_ASH_SCOOP: &"HouseholdAshScoop",
	MapTypes.HOUSEHOLD_BROOM: &"HouseholdBroom",
	MapTypes.HOUSEHOLD_LINEN_FOLDED: &"HouseholdLinenFolded",
	MapTypes.HOUSEHOLD_APRON: &"HouseholdApron",
	MapTypes.HOUSEHOLD_GROUP_CLOSED: &"HouseholdGroupClosed",
	MapTypes.HOUSEHOLD_GROUP_IN_USE: &"HouseholdGroupInUse",
	MapTypes.HOUSEHOLD_GROUP_DEPLETED: &"HouseholdGroupDepleted",
	MapTypes.HOUSEHOLD_GROUP_CLEARED: &"HouseholdGroupCleared",
}


static func add_model(parent: Node3D, prop: Dictionary) -> Node3D:
	var variant := MapTypes.household_clutter_variant_for_prop(prop)
	var scene := load(HOUSEHOLD_CLUTTER_KIT_SCENE_PATH) as PackedScene
	assert(scene != null, "Smithy household clutter GLB must be imported before map assembly")
	var model := scene.instantiate() as Node3D
	assert(model != null, "Smithy household clutter GLB root must be Node3D")
	model.name = "HouseholdClutterModel"
	parent.add_child(model)

	var selected_name: StringName = VARIANT_ROOT_NAMES[variant]
	var selected := model.find_child(String(selected_name), true, false) as Node3D
	assert(selected != null, "Smithy household clutter variant root is missing: %s" % String(selected_name))
	for root_name in VARIANT_ROOT_NAMES.values():
		if root_name == selected_name:
			continue
		var unused := model.find_child(String(root_name), true, false) as Node3D
		if unused != null:
			unused.get_parent().remove_child(unused)
			unused.free()

	model.set_meta(&"production_household_clutter_model", true)
	model.set_meta(&"household_clutter_style_variant", variant)
	selected.set_meta(&"household_clutter_style_variant", variant)
	return model
