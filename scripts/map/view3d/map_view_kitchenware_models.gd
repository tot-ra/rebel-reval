class_name MapViewKitchenwareModels
extends RefCounted

## Runtime selector for the Reval 1343 artisan kitchenware kit. One GLB keeps
## every individual item and grouped place-setting module as a separate root so
## maps can swap storage, preparation, eating, and cleanup states.

const KITCHENWARE_KIT_SCENE_PATH := (
	"res://assets/props/domestic/kitchenware/"
	+ "medieval_kitchenware_kit.glb"
)

const VARIANT_ROOT_NAMES: Dictionary = {
	MapTypes.KITCHENWARE_PREP_BOARD: &"KitchenwarePrepBoard",
	MapTypes.KITCHENWARE_KNIFE: &"KitchenwareKnife",
	MapTypes.KITCHENWARE_SPOON: &"KitchenwareSpoon",
	MapTypes.KITCHENWARE_BOWL_SMALL: &"KitchenwareBowlSmall",
	MapTypes.KITCHENWARE_BOWL_LARGE: &"KitchenwareBowlLarge",
	MapTypes.KITCHENWARE_TRENCHER: &"KitchenwareTrencher",
	MapTypes.KITCHENWARE_CUP: &"KitchenwareCup",
	MapTypes.KITCHENWARE_JAR_LIDDED: &"KitchenwareJarLidded",
	MapTypes.KITCHENWARE_JAR_OPEN: &"KitchenwareJarOpen",
	MapTypes.KITCHENWARE_COOKING_POT_LIDDED: &"KitchenwareCookingPotLidded",
	MapTypes.KITCHENWARE_JUG: &"KitchenwareJug",
	MapTypes.KITCHENWARE_BASIN_CLOTH: &"KitchenwareBasinCloth",
	MapTypes.KITCHENWARE_GROUP_STORAGE: &"KitchenwareGroupStorage",
	MapTypes.KITCHENWARE_GROUP_PREP: &"KitchenwareGroupPrep",
	MapTypes.KITCHENWARE_GROUP_EATING: &"KitchenwareGroupEating",
	MapTypes.KITCHENWARE_GROUP_CLEANUP: &"KitchenwareGroupCleanup",
}


static func add_model(parent: Node3D, prop: Dictionary) -> Node3D:
	var variant := MapTypes.kitchenware_variant_for_prop(prop)
	var scene := load(KITCHENWARE_KIT_SCENE_PATH) as PackedScene
	assert(scene != null, "Medieval kitchenware GLB must be imported before map assembly")
	var model := scene.instantiate() as Node3D
	assert(model != null, "Medieval kitchenware GLB root must be Node3D")
	model.name = "KitchenwareModel"
	parent.add_child(model)

	var selected_name: StringName = VARIANT_ROOT_NAMES[variant]
	var selected := model.find_child(String(selected_name), true, false) as Node3D
	assert(
		selected != null, "Medieval kitchenware variant root is missing: %s" % String(selected_name)
	)
	for root_name in VARIANT_ROOT_NAMES.values():
		if root_name == selected_name:
			continue
		var unused := model.find_child(String(root_name), true, false) as Node3D
		if unused != null:
			unused.get_parent().remove_child(unused)
			unused.free()

	model.set_meta(&"production_kitchenware_model", true)
	model.set_meta(&"kitchenware_style_variant", variant)
	selected.set_meta(&"kitchenware_style_variant", variant)
	return model
