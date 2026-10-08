extends "res://tests/godot/test_case.gd"

## Estonia map catalog: unbuilt places are charted but never travelable.


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
	assert_true(planned > 0, "catalog should chart unbuilt locations")


func test_every_marker_has_a_position_inside_the_basemap() -> void:
	var positions := GlobalMapCatalog.layout_positions()
	for scene_id in GlobalMapCatalog.marker_ids():
		var at: Vector2 = positions[scene_id]
		assert_true(at.x > 0.0 and at.x < 1.0 and at.y > 0.0 and at.y < 1.0, "%s off map" % scene_id)
