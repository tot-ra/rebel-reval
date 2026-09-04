class_name MapViewBurgherHouseStoneModels
extends RefCounted

## Production exterior model for the R-003 merchant_stone ordinary-house tier.
## This module is intentionally separate from the existing timber WIP so a
## stone-house task cannot overwrite another worker's shared model registry.

const BurgherHouseModels := preload("res://scripts/map/view3d/map_view_burgher_house_models.gd")

const MERCHANT_STONE_SCENE_PATH := (
	"res://assets/props/architecture/houses/merchant_stone/merchant_stone.glb"
)
const MERCHANT_STONE_SOURCE_EXTENTS := Vector3(10.5649, 15.2199, 22.36)


static func is_production_tier(building: Dictionary) -> bool:
	return StringName(building.get("house_tier", &"")) == &"merchant_stone"


static func add_model(
	root: Node3D, building: Dictionary, size: Vector2, height: float
) -> Node3D:
	var scene := load(MERCHANT_STONE_SCENE_PATH) as PackedScene
	assert(scene != null, "merchant_stone GLB must be imported before map assembly")
	if scene == null:
		return null
	var model := scene.instantiate() as Node3D
	assert(model != null, "merchant_stone GLB root must be Node3D")
	if model == null:
		return null
	model.name = "ProductionMerchantStone"
	model.set_meta(&"production_house_model", true)
	model.set_meta(&"house_tier", &"merchant_stone")
	model.set_meta(&"source_scene", MERCHANT_STONE_SCENE_PATH)
	model.scale = Vector3(
		size.x / MERCHANT_STONE_SOURCE_EXTENTS.x,
		height / MERCHANT_STONE_SOURCE_EXTENTS.y,
		size.y / MERCHANT_STONE_SOURCE_EXTENTS.z
	)
	model.rotation.y = _frontage_rotation(building.get("door_side", &"south"))
	root.add_child(model)
	BurgherHouseModels.prune_placeholder_geometry(root, model)
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
