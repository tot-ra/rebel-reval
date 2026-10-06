extends "res://tests/godot/test_case.gd"

const MonasteryQuarterDefinition := preload(
	"res://scripts/map/definitions/prototypes/monastery_quarter_definition.gd"
)
const StOlafModel := preload("res://scripts/map/view3d/map_view_st_olaf_model.gd")


func test_st_olaf_uses_the_1343_exceptional_renderer() -> void:
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
	assert_eq(node.get_meta(&"historical_phase"), &"vaulted_hall_unfinished_tower_1343")
	assert_eq(node.get_meta(&"renderer_boundary"), &"exceptional")
	for path: String in [
		"Walls",
		"NaveRoof",
		"NaveGableE",
		"EastGableNiche2",
		"SouthPortal/Frontispiece",
		"ChancelWalls",
		"ChancelRoof",
		"SacristyWalls",
		"WestTower/Masonry",
		"WestTower/RaggedTop",
		"WestTower/PutlogHoles",
		"WestTower/Scaffold",
		"WestTower/ProvisionalBelfry/Bell0",
		"WestTower/WestPortal",
		"VaultButtress_N_00",
		"VaultButtress_S_03",
		"VaultLancet_N_00",
		"Window0",
	]:
		assert_true(node.has_node(path), "St. Olaf 1343 is missing %s" % path)
	assert_false(node.has_node("Roof"), "St. Olaf must not use the ordinary house roof")
	assert_false(node.has_node("Chimney"), "St. Olaf must not use an ordinary domestic chimney")
	assert_false(
		node.has_node("WestTower/TowerCoping"), "The 1343 tower is unfinished: no completed coping"
	)
	for later: String in ["Spire", "GiantSpire", "Basilica", "Clerestory", "HighChoir"]:
		assert_false(node.has_node(later), "%s is post-1343 and must stay excluded" % later)
	node.free()


func test_st_olaf_massing_reads_as_tower_hall_and_lower_chancel() -> void:
	var definition: MapDefinition = MonasteryQuarterDefinition.create()
	var building := _building_by_id(definition, &"st_olaf_silhouette")
	var node := MapViewMeshBuilder.build_building(building, definition.cell_size)
	var nave := (node.get_node("Walls") as MeshInstance3D).mesh as BoxMesh
	var chancel := (node.get_node("ChancelWalls") as MeshInstance3D).mesh as BoxMesh
	var tower := (node.get_node("WestTower/Masonry") as MeshInstance3D).mesh as BoxMesh
	var nave_ridge := StOlafModel.nave_roof_y(nave.size.y, 0.0)
	assert_true(tower.size.y > nave_ridge, "The west tower must clear the hall roof ridge")
	assert_true(
		tower.size.y < nave_ridge * 1.6, "The 1343 tower stays a lower stage, not a later spire"
	)
	assert_true(chancel.size.y < nave.size.y, "The chancel is lower than the hall")
	assert_true(chancel.size.z < nave.size.z, "The chancel is narrower than the hall")
	var tower_x := (node.get_node("WestTower/Masonry") as Node3D).position.x
	var chancel_x := (node.get_node("ChancelWalls") as Node3D).position.x
	assert_true(tower_x < 0.0 and chancel_x > 0.0, "Tower stands west, chancel east")
	node.free()


func test_st_olaf_stays_inside_its_footprint_and_door_axis() -> void:
	var definition: MapDefinition = MonasteryQuarterDefinition.create()
	var building := _building_by_id(definition, &"st_olaf_silhouette")
	var scale := MapViewBridge.world_scale(definition.cell_size)
	var footprint: Rect2 = building["footprint"]
	var half := footprint.size * scale * 0.5
	var node := MapViewMeshBuilder.build_building(building, definition.cell_size)
	assert_eq(
		node.position,
		Vector3(footprint.get_center().x * scale, 0.0, footprint.get_center().y * scale),
		"View geometry must remain aligned to the authored footprint"
	)
	# The Pikk-spine bypass lane runs alongside: nothing may overhang the plot.
	for mesh in _meshes(node):
		var bounds := _local_transform(mesh, node) * mesh.get_aabb()
		var name_path := String(node.get_path_to(mesh))
		assert_true(
			bounds.position.x >= -half.x - 0.05 and bounds.end.x <= half.x + 0.05,
			"%s leaves the footprint along X: %s" % [name_path, bounds]
		)
		assert_true(
			bounds.position.z >= -half.y - 0.05 and bounds.end.z <= half.y + 0.05,
			"%s leaves the footprint along Z: %s" % [name_path, bounds]
		)
	var door := _transition(definition, &"to_oleviste_church")
	var door_x := (door["rect"] as Rect2).get_center().x * scale - node.position.x
	var portal := node.get_node("SouthPortal") as Node3D
	assert_true(
		absf(portal.position.x - door_x) < 0.05, "The south portal must frame the transition door"
	)
	var outer_order := portal.get_node("PortalOrder0") as MeshInstance3D
	var front_z := (_local_transform(outer_order, node) * outer_order.get_aabb()).end.z
	assert_true(absf(front_z - half.y) < 0.05, "The portal face meets the door on the plot edge")
	node.free()


func test_st_olaf_build_is_deterministic() -> void:
	var definition: MapDefinition = MonasteryQuarterDefinition.create()
	var building := _building_by_id(definition, &"st_olaf_silhouette")
	var first := MapViewMeshBuilder.build_building(building, definition.cell_size)
	var second := MapViewMeshBuilder.build_building(building, definition.cell_size)
	var first_meshes := _meshes(first)
	var second_meshes := _meshes(second)
	assert_eq(first_meshes.size(), second_meshes.size())
	for index in first_meshes.size():
		assert_eq(
			_local_transform(first_meshes[index], first),
			_local_transform(second_meshes[index], second)
		)
	first.free()
	second.free()


func _meshes(root: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	for child in root.get_children():
		if child is MeshInstance3D:
			found.append(child)
		found.append_array(_meshes(child))
	return found


## Transform of `node` relative to `root` without entering the scene tree.
func _local_transform(node: Node3D, root: Node3D) -> Transform3D:
	var result := Transform3D.IDENTITY
	var current: Node = node
	while current != root and current is Node3D:
		result = (current as Node3D).transform * result
		current = current.get_parent()
	return result


func _transition(definition: MapDefinition, transition_id: StringName) -> Dictionary:
	for transition in definition.transitions:
		if transition.get("id", &"") == transition_id:
			return transition
	fail("missing transition %s" % transition_id)
	return {}


func _building_by_id(definition: MapDefinition, building_id: StringName) -> Dictionary:
	for building in definition.buildings:
		if building.get("id", &"") == building_id:
			return building
	return {}
