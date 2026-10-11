extends "res://tests/godot/test_case.gd"

const Surroundings := preload(
	"res://scripts/map/view3d/map_view_mesh_builder_surroundings.gd"
)


func test_neighbor_preview_keeps_production_house_silhouette_without_detached_chimney() -> void:
	var building := {
		"id": &"preview_merchant_timber",
		"kind": MapTypes.BUILDING_KIND_HOUSE,
		"house_tier": &"merchant_timber",
		"footprint": Rect2(0.0, 0.0, 8.0 * 32.0, 8.0 * 32.0),
		"wall_height": 112.0,
		"door_side": &"south",
	}
	var house := MapViewMeshBuilder.build_building(building, MapTypes.DEFAULT_CELL_SIZE)
	Surroundings._simplify_neighbor_building(house)

	assert_true(
		house.has_node("ProductionMerchantTimber"),
		"backdrop simplification must preserve the active production house model"
	)
	assert_false(
		house.has_node("Chimney"),
		"backdrop house must not leave a procedural chimney detached from its silhouette"
	)
	assert_true(
		_has_visible_geometry(house.get_node("ProductionMerchantTimber")),
		"preserved production house must retain visible geometry"
	)
	house.free()


func _has_visible_geometry(node: Node) -> bool:
	if node is GeometryInstance3D and (node as GeometryInstance3D).visible:
		return true
	for child in node.get_children():
		if _has_visible_geometry(child):
			return true
	return false
