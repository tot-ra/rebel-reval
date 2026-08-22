extends "res://tests/godot/test_case.gd"

const MonasteryQuarterDefinition := preload(
	"res://scripts/map/definitions/prototypes/monastery_quarter_definition.gd"
)


func test_st_olaf_uses_compact_1343_exceptional_renderer() -> void:
	var definition: MapDefinition = MonasteryQuarterDefinition.create()
	var building := _building_by_id(definition, &"st_olaf_silhouette")
	assert_false(building.is_empty(), "St. Olaf must keep its stable exterior building record")
	assert_eq(
		MapViewMeshBuilder.exceptional_building_category(building),
		&"church",
		"St. Olaf must remain on the exceptional church boundary"
	)
	var node := MapViewMeshBuilder.build_building(building, definition.cell_size)
	assert_eq(node.name, "Building_st_olaf_silhouette")
	assert_eq(node.get_meta(&"church_renderer"), &"st_olaf_1343")
	assert_eq(node.get_meta(&"historical_phase"), &"compact_1343_mass")
	assert_eq(node.get_meta(&"renderer_boundary"), &"exceptional")
	assert_true(node.has_node("Walls"), "St. Olaf needs a limestone nave mass")
	assert_true(node.has_node("NaveRoof"), "St. Olaf needs a tile nave roof")
	assert_true(node.has_node("WestTower/Masonry"), "St. Olaf needs its massive west tower")
	assert_true(node.has_node("WestTower/TowerCoping"), "West tower needs a completed masonry coping")
	assert_true(node.has_node("VaultButtress_N_00"), "Completed vault work needs visible buttresses")
	assert_true(node.has_node("VaultLancet_N_00"), "St. Olaf needs dedicated church openings")
	assert_false(node.has_node("Roof"), "St. Olaf must not use the ordinary house roof")
	assert_false(node.has_node("Chimney"), "St. Olaf must not use an ordinary domestic chimney")
	assert_false(node.has_node("15thCenturyChancel"), "Later chancel geometry is excluded from 1343")
	assert_false(node.has_node("Basilica"), "Later basilica geometry is excluded from 1343")
	assert_false(node.has_node("GiantSpire"), "The giant later spire is excluded from 1343")

	var nave_walls := node.get_node("Walls") as MeshInstance3D
	var west_masonry := node.get_node("WestTower/Masonry") as MeshInstance3D
	assert_true(
		(west_masonry.mesh as BoxMesh).size.y > (nave_walls.mesh as BoxMesh).size.y,
		"West tower must rise above the compact nave without becoming a giant spire"
	)
	assert_eq(
		node.position,
		Vector3(
			building["footprint"].get_center().x * MapViewBridge.world_scale(definition.cell_size),
			0.0,
			building["footprint"].get_center().y * MapViewBridge.world_scale(definition.cell_size)
		),
		"View geometry must remain aligned to the authored footprint"
	)
	node.free()


func _building_by_id(definition: MapDefinition, building_id: StringName) -> Dictionary:
	for building in definition.buildings:
		if building.get("id", &"") == building_id:
			return building
	return {}
