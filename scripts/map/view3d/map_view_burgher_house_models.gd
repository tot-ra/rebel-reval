class_name MapViewBurgherHouseModels
extends RefCounted

## Production exterior models for the R-003 ordinary-house tiers.
## Gameplay collision/navigation remain authored on the 2D map plane; this module
## only swaps view geometry after the contract nodes have been created.

const MERCHANT_TIMBER_SCENE_PATH := (
	"res://assets/props/architecture/houses/merchant_timber/merchant_timber.glb"
)
const MERCHANT_TIMBER_SOURCE_EXTENTS := Vector3(9.6449, 11.7756, 19.12)


static func is_production_tier(building: Dictionary) -> bool:
	return StringName(building.get("house_tier", &"")) == &"merchant_timber"


static func add_model(
	root: Node3D, building: Dictionary, size: Vector2, height: float
) -> Node3D:
	var scene := load(MERCHANT_TIMBER_SCENE_PATH) as PackedScene
	assert(scene != null, "merchant_timber GLB must be imported before map assembly")
	if scene == null:
		return null
	var model := scene.instantiate() as Node3D
	assert(model != null, "merchant_timber GLB root must be Node3D")
	if model == null:
		return null
	model.name = "ProductionMerchantTimber"
	model.set_meta(&"production_house_model", true)
	model.set_meta(&"house_tier", &"merchant_timber")
	model.set_meta(&"source_scene", MERCHANT_TIMBER_SCENE_PATH)
	model.scale = Vector3(
		size.x / MERCHANT_TIMBER_SOURCE_EXTENTS.x,
		height / MERCHANT_TIMBER_SOURCE_EXTENTS.y,
		size.y / MERCHANT_TIMBER_SOURCE_EXTENTS.z
	)
	model.rotation.y = _frontage_rotation(building.get("door_side", &"south"))
	root.add_child(model)
	# Keep the ordinary renderer's Walls/Roof contract nodes for diagnostics and
	# tests, but hide their placeholder geometry when the authored GLB is active.
	for child in root.get_children():
		if child != model:
			child.visible = false
	return model


static func _frontage_rotation(door_side: StringName) -> float:
	match door_side:
		&"north":
			return PI
		&"east":
			return -PI * 0.5
		&"west":
			return PI * 0.5
	return 0.0
