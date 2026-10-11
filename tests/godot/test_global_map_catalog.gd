extends "res://tests/godot/test_case.gd"

## Estonia map catalog: unbuilt places would be charted but never travelable;
## today every charted place is a debug greybox.


func test_planned_locations_are_charted_but_not_travelable() -> void:
	var planned := 0
	for scene_id in GlobalMapCatalog.marker_ids():
		if not GlobalMapCatalog.is_planned(scene_id):
			continue
		planned += 1
		assert_false(GlobalMapCatalog.location_ids().has(scene_id), "%s must not be built" % scene_id)
		assert_false(GlobalMapCatalog.is_distant_scene(scene_id), "%s must not be distant" % scene_id)
		assert_true(
			GlobalMapCatalog.plan_travel(&"world_harju", scene_id).is_empty(),
			"%s must not plan travel" % scene_id
		)
	# Every charted place now has a debug greybox, so nothing is left unbuilt;
	# the loop above still guards any future "planned" entry.
	assert_eq(planned, 0, "all charted locations are travelable debug nodes")


func test_debug_greybox_nodes_are_reachable_from_reval_and_back() -> void:
	for scene_id in [&"world_rakvere", &"world_klint", &"world_soomaa", &"world_frontier_ugandi"]:
		assert_true(GlobalMapCatalog.is_distant_scene(scene_id), "%s must be travelable" % scene_id)
		var there := GlobalMapCatalog.plan_travel(GlobalMapCatalog.REVAL_HUB_ID, scene_id)
		assert_false(there.is_empty(), "Reval -> %s needs a plan" % scene_id)
		assert_true(DoorNavigator.has_spawn(scene_id, there.get("spawn_id", &"")))
		assert_false(GlobalMapCatalog.plan_travel(scene_id, GlobalMapCatalog.REVAL_HUB_ID).is_empty())


func test_every_marker_has_a_position_inside_the_basemap() -> void:
	var positions := GlobalMapCatalog.layout_positions()
	for scene_id in GlobalMapCatalog.marker_ids():
		var at: Vector2 = positions[scene_id]
		assert_true(at.x > 0.0 and at.x < 1.0 and at.y > 0.0 and at.y < 1.0, "%s off map" % scene_id)
