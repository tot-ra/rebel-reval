class_name MapViewServiceBuildingModels
extends RefCounted

## Production exteriors for special Lower Town plots that stay outside the
## closed R-003 house-tier allowlist (storehouse, brewhouse, public bath, barn,
## wall-side and gate huts). Keyed by stable building id, never by position, so
## moving or re-chunking a plot keeps its model. Collision, navigation and
## transitions stay authored on the map plane; only the view geometry changes.

const BurgherHouseModels := preload("res://scripts/map/view3d/map_view_burgher_house_models.gd")
const BodaModels := preload("res://scripts/map/view3d/map_view_burgher_house_craft_boda_models.gd")

const NODE_NAME := "ProductionServiceBuilding"
const MODEL_ROLE := &"service_building"

## body/smoke must match body_m / smoke_outlet_m in
## generated/blender/lower_town_service_buildings_v1/report.json.
const STONE_STOREHOUSE: Dictionary = {
	"id": &"stone_storehouse",
	"path": "res://assets/props/architecture/buildings/stone_storehouse/stone_storehouse.glb",
	"body": Vector3(11.0, 8.1, 8.0),
}
const BREWHOUSE: Dictionary = {
	"id": &"brewhouse",
	"path": "res://assets/props/architecture/buildings/brewhouse/brewhouse.glb",
	"body": Vector3(9.0, 5.6, 8.0),
	"smoke": Vector3(-0.68, 11.8771, -1.92),
}
const PUBLIC_BATH: Dictionary = {
	"id": &"public_bath",
	"path": "res://assets/props/architecture/buildings/public_bath/public_bath.glb",
	"body": Vector3(6.0, 2.75, 8.0),
	"smoke": Vector3(-3.3, 2.55, -1.25),
}
const LOG_BARN: Dictionary = {
	"id": &"log_barn",
	"path": "res://assets/props/architecture/buildings/log_barn/log_barn.glb",
	"body": Vector3(8.0, 3.15, 6.0),
}

## Stable Lower Town ids -> candidate variants. The small log huts reuse the
## craft_boda kit matching their authored roof cover (thatch vs shingle).
static func variants_for(building: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	match StringName(String(building.get("id", ""))):
		&"guild_storehouse":
			result.append(STONE_STOREHOUSE)
		&"foaming_mug_brewery":
			result.append(BREWHOUSE)
		&"public_bathhouse":
			result.append(PUBLIC_BATH)
		&"monastery_barn":
			result.append(LOG_BARN)
		&"karja_gate_house", &"south_apron_wall_walk_hut":
			result.append(BodaModels.CRAFT_BODA_VARIANTS[0])
		&"muurivahe_house_north":
			result.append(BodaModels.CRAFT_BODA_VARIANTS[1])
	return result


static func is_service_building(building: Dictionary) -> bool:
	return not variants_for(building).is_empty()


static func add_model(root: Node3D, building: Dictionary, size: Vector2) -> Node3D:
	var variants := variants_for(building)
	if variants.is_empty():
		return null
	return BurgherHouseModels.add_variant_model(root, building, size, MODEL_ROLE, NODE_NAME, variants)
