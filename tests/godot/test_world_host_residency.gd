extends "res://tests/godot/test_case.gd"

## WB-06c / R-1039: real baked location regions are inset by agent_radius, so
## the host must bridge each active seam with a deterministic NavigationLink2D.

const CELL := 32


func test_seam_link_points_sit_inside_each_inset_region() -> void:
	var layout := MapWorldLayout.build([_map_a(), _map_b()], &"map_a", &"test_outdoor")
	assert_true(layout["valid"], "fixture maps share a physical east-west seam")
	assert_eq((layout["seams"] as Array).size(), 1)
	var points := MapWorldLayout.seam_navigation_link_points(
		layout, layout["seams"][0], MapNavBuilder.AGENT_RADIUS
	)
	assert_eq(points.size(), 2)
	var radius := MapNavBuilder.AGENT_RADIUS
	var start: Vector2 = points[0]
	var end: Vector2 = points[1]
	assert_true(
		start.x >= radius and start.x <= 4.0 * CELL - radius,
		"start stays inside map_a walkable: %s" % start
	)
	assert_true(
		end.x >= 4.0 * CELL + radius and end.x <= 8.0 * CELL - radius,
		"end stays inside map_b walkable: %s" % end
	)
	assert_true(absf(end.x - start.x) > radius, "link spans the 32 px inset gap")


func test_baked_packages_have_no_path_until_the_host_adds_seam_links() -> void:
	var host := _hosted()
	assert_true(host.mount_location(&"map_a", _baked_package(_map_a())))
	assert_true(host.mount_location(&"map_b", _baked_package(_map_b())))
	var map_rid := host.navigation_map()
	for location_id in [&"map_a", &"map_b"]:
		var region := _region_of(host, location_id)
		assert_true(region != null, "%s package carries a baked region" % location_id)
		assert_eq(region.get_navigation_map(), map_rid)
	await _sync_navigation()

	var start := Vector2(2.0 * CELL, 2.0 * CELL)
	var goal := Vector2(6.0 * CELL, 2.0 * CELL)
	assert_eq(host.observe_global_logic_position(start), &"map_a")
	assert_eq(host.observe_global_logic_position(goal), &"map_b")

	var links := host.get_node(WorldHost.SEAM_LINKS_NAME).get_children()
	assert_true(links.size() >= 1, "host installs a link on the active seam")
	var path := NavigationServer2D.map_get_path(map_rid, start, goal, true)
	assert_true(path.size() >= 2, "a path exists across the baked inset gap")
	assert_true(path[path.size() - 1].distance_to(goal) < CELL, "path reaches map_b")

	for link_node in links:
		(link_node as NavigationLink2D).enabled = false
	await _sync_navigation()
	var blocked := NavigationServer2D.map_get_path(map_rid, start, goal, true)
	assert_true(
		blocked.is_empty() or blocked[blocked.size() - 1].distance_to(goal) > CELL,
		"without the link the 32 px inset gap blocks click navigation"
	)
	_dispose(host)


func test_flag_off_bake_bytes_stay_identical() -> void:
	var definition := _map_a()
	var grid := MapBuilder.build(definition)
	var first := MapNavBuilder.bake_navigation_polygon(definition, grid)
	var second := MapNavBuilder.bake_navigation_polygon(definition, grid)
	assert_eq(first.get_polygon_count(), second.get_polygon_count())
	assert_eq(first.vertices, second.vertices)
	assert_eq(first.agent_radius, MapNavBuilder.AGENT_RADIUS)


func _hosted() -> WorldHost:
	var host := WorldHost.new()
	host.name = "WorldHostSeamNav"
	host.additive_residency_enabled = true
	(Engine.get_main_loop() as SceneTree).root.add_child(host)
	var player := Node2D.new()
	var camera := Camera3D.new()
	var session := Node.new()
	host.add_child(player)
	host.add_child(camera)
	host.add_child(session)
	var layout := MapWorldLayout.build([_map_a(), _map_b()], &"map_a", &"test_outdoor")
	assert_true(host.configure(layout, player, camera, session))
	return host


func _dispose(host: WorldHost) -> void:
	host.unmount_all()
	if host.get_parent() != null:
		host.get_parent().remove_child(host)
	host.free()


func _region_of(host: WorldHost, location_id: StringName) -> NavigationRegion2D:
	var root := host.mounted_location_root(location_id, false)
	if root == null:
		return null
	var found := root.find_children("*", "NavigationRegion2D", true, false)
	return found.front() as NavigationRegion2D if not found.is_empty() else null


## Same bake assemble_location_package() uses (R-978). The package is only a
## region so this row does not depend on that uncommitted helper.
func _baked_package(definition: MapDefinition) -> Node2D:
	var package := Node2D.new()
	package.name = "BakedPackage_%s" % String(definition.map_id)
	var region := MapNavBuilder.create_navigation_region(
		definition, MapBuilder.build(definition)
	)
	region.name = "Navigation"
	package.add_child(region)
	return package


func _sync_navigation() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	for _frame in 4:
		await tree.physics_frame


func _map_a() -> MapDefinition:
	var definition := _base_map(&"map_a")
	definition.transitions = [
		{
			"id": &"to_map_b",
			"rect": Rect2(96, 32, 32, 64),
			"spawn_id": &"from_map_b",
			"destination_spawn_id": &"from_map_a",
		}
	]
	return definition


func _map_b() -> MapDefinition:
	var definition := _base_map(&"map_b")
	definition.transitions = [
		{
			"id": &"to_map_a",
			"rect": Rect2(0, 32, 32, 64),
			"spawn_id": &"from_map_a",
			"destination_spawn_id": &"from_map_b",
		}
	]
	return definition


func _base_map(map_id: StringName) -> MapDefinition:
	var definition := MapDefinition.new()
	definition.map_id = map_id
	definition.location = StringName("loc.%s" % map_id)
	definition.cell_size = MapTypes.DEFAULT_CELL_SIZE
	definition.size_cells = Vector2i(4, 4)
	definition.base_terrain = MapTypes.TERRAIN_GRASS
	definition.player_spawn = Vector2(32, 32)
	definition.scope = &"production"
	definition.active = true
	definition.palette = &"clean_painted"
	definition.fingerprint = "%s-fingerprint" % map_id
	return definition
