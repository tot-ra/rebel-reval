extends SceneTree

const VARIANTS := [
	{
		"id": "diamond_isometric_8_direction",
		"scene": "res://scenes/comparison_room/diamond_isometric_8_direction.tscn",
		"directions": 8,
	},
	{
		"id": "orthogonal_4_direction",
		"scene": "res://scenes/comparison_room/orthogonal_4_direction.tscn",
		"directions": 4,
	},
]


func _init() -> void:
	var failures: Array[String] = []
	var expected_signature := ""

	for definition in VARIANTS:
		var scene_path: String = definition["scene"]
		var packed_scene := load(scene_path) as PackedScene
		if packed_scene == null:
			failures.append("could not load %s" % scene_path)
			continue

		var instance := packed_scene.instantiate()
		var variant_id: String = instance.call("_variant_id")
		var direction_count: int = instance.call("_verify_direction_model")
		var signature: String = instance.call("_content_signature")
		instance.free()

		if variant_id != definition["id"]:
			failures.append("%s reported id %s" % [scene_path, variant_id])
		if direction_count != definition["directions"]:
			failures.append("%s reported %d directions, expected %d" % [variant_id, direction_count, definition["directions"]])
		if expected_signature.is_empty():
			expected_signature = signature
		elif signature != expected_signature:
			failures.append("%s content signature differs" % variant_id)

	if failures.is_empty():
		print("P0-035 paired content equivalence: PASS")
		print(" - variants: 2")
		print(" - direction_models: 8 and 4")
		print(" - equivalent_navigation_content: ok")
		print(" - equivalent_interaction_content: ok")
		print(" - equivalent_combat_content: ok")
		print(" - content_signature: " + expected_signature)
		quit(0)
		return

	print("P0-035 paired content equivalence: FAIL")
	for failure in failures:
		print(" - " + failure)
	quit(1)
