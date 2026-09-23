class_name MapViewBurgherHouseCraftBodaModels
extends RefCounted

## Production exterior models for the compact R-003 craft_boda tier.
## The authored GLB is visual-only; collision and navigation remain on the map plane.

const BurgherHouseModels := preload("res://scripts/map/view3d/map_view_burgher_house_models.gd")

## body = wall body in metres: (frontage width, eave height, plot depth);
## smoke = flue or smoke-vent outlet in model space. Both must match body_m /
## smoke_outlet_m in
## generated/blender/burgher_house_craft_boda_v1/report.json.
const CRAFT_BODA_VARIANTS: Array[Dictionary] = [
	{
		"id": &"log_thatch",
		"path": "res://assets/props/architecture/houses/craft_boda/craft_boda.glb",
		"body": Vector3(8.2, 2.7, 6.6),
		"smoke": Vector3(0.0, 5.2, 3.65),
	},
	{
		"id": &"log_shingle_pentice",
		"path": "res://assets/props/architecture/houses/craft_boda/craft_boda_pentice.glb",
		"body": Vector3(9.4, 2.8, 7.0),
		"smoke": Vector3(0.72, 8.9492, -1.54),
	},
]


static func is_production_tier(building: Dictionary) -> bool:
	return StringName(building.get("house_tier", &"")) == &"craft_boda"


static func add_model(
	root: Node3D, building: Dictionary, size: Vector2, _height: float
) -> Node3D:
	return BurgherHouseModels.add_variant_model(
		root, building, size, &"craft_boda", "ProductionCraftBoda", CRAFT_BODA_VARIANTS
	)
