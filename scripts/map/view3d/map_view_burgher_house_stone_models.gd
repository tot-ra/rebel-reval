class_name MapViewBurgherHouseStoneModels
extends RefCounted

## Production exterior models for the R-003 merchant_stone ordinary-house tier.
## This module is intentionally separate from the existing timber WIP so a
## stone-house task cannot overwrite another worker's shared model registry.

const BurgherHouseModels := preload("res://scripts/map/view3d/map_view_burgher_house_models.gd")

## body = wall body in metres: (frontage width, eave height, plot depth);
## smoke = flue or smoke-vent outlet in model space. Both must match body_m /
## smoke_outlet_m in
## generated/blender/burgher_house_merchant_stone_v1/report.json.
const MERCHANT_STONE_VARIANTS: Array[Dictionary] = [
	{
		"id": &"coursed_rubble",
		"path": "res://assets/props/architecture/houses/merchant_stone/merchant_stone.glb",
		"body": Vector3(9.0, 8.55, 9.6),
		"smoke": Vector3(0.57, 15.0967, -1.152),
	},
	{
		"id": &"lime_rendered_wide",
		"path": "res://assets/props/architecture/houses/merchant_stone/merchant_stone_rendered.glb",
		"body": Vector3(11.0, 6.1, 9.6),
		"smoke": Vector3(0.57, 13.7573, -1.152),
	},
]


static func is_production_tier(building: Dictionary) -> bool:
	return StringName(building.get("house_tier", &"")) == &"merchant_stone"


static func add_model(
	root: Node3D, building: Dictionary, size: Vector2, _height: float
) -> Node3D:
	return BurgherHouseModels.add_variant_model(
		root, building, size, &"merchant_stone", "ProductionMerchantStone", MERCHANT_STONE_VARIANTS
	)
