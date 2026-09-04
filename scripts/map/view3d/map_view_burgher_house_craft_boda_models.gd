class_name MapViewBurgherHouseCraftBodaModels
extends RefCounted

## Production exterior model for the compact R-003 craft_boda tier.
## The authored GLB is visual-only; collision and navigation remain on the map plane.

const BurgherHouseModels := preload("res://scripts/map/view3d/map_view_burgher_house_models.gd")

const CRAFT_BODA_SCENE_PATH := (
	"res://assets/props/architecture/houses/craft_boda/craft_boda.glb"
)
const CRAFT_BODA_SOURCE_EXTENTS := Vector3(7.4849, 7.615, 12.26)


static func is_production_tier(building: Dictionary) -> bool:
	return StringName(building.get("house_tier", &"")) == &"craft_boda"


static func add_model(
	root: Node3D, building: Dictionary, size: Vector2, height: float
) -> Node3D:
	var scene := load(CRAFT_BODA_SCENE_PATH) as PackedScene
	assert(scene != null, "craft_boda GLB must be imported before map assembly")
	if scene == null:
		return null
	var model := scene.instantiate() as Node3D
	assert(model != null, "craft_boda GLB root must be Node3D")
	if model == null:
		return null
	model.name = "ProductionCraftBoda"
	model.set_meta(&"production_house_model", true)
	model.set_meta(&"house_tier", &"craft_boda")
	model.set_meta(&"source_scene", CRAFT_BODA_SCENE_PATH)
	model.scale = Vector3(
		size.x / CRAFT_BODA_SOURCE_EXTENTS.x,
		height / CRAFT_BODA_SOURCE_EXTENTS.y,
		size.y / CRAFT_BODA_SOURCE_EXTENTS.z
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
