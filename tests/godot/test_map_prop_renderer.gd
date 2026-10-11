extends "res://tests/godot/test_case.gd"

## Guards the public 2D prop facade while visual families live in focused files.


func test_every_registered_prop_kind_builds_through_the_public_facade() -> void:
	for kind in MapTypes.ALL_PROP_KINDS:
		var prop := {
			"id": StringName("facade.%s" % kind),
			"kind": kind,
			"position": Vector2(96, 128),
		}
		if kind == MapTypes.PROP_KIND_BANNER:
			prop["faction"] = FactionHeraldry.HANSEATIC
		var node := MapPropRenderer.create_prop(prop)
		assert_eq(node.name, "Prop_facade_%s" % kind)
		assert_eq(node.get_meta("y_sort_anchor"), prop["position"])
		assert_true(node.has_node("Shadow"), "%s needs the shared shadow node" % kind)
		assert_true(node.get_child_count() > 1, "%s must add a visual body" % kind)
		node.free()


func test_facade_preserves_offsets_and_rotates_tall_boats() -> void:
	var position := Vector2(96, 128)
	var offset := Vector2(7, -11)
	var node := MapPropRenderer.create_prop({
		"id": &"facade.tall_boat",
		"kind": MapTypes.PROP_KIND_FISHING_BOAT,
		"position": position,
		"visual_offset_px": offset,
		"footprint": Rect2(position, Vector2(32, 96)),
	})
	assert_eq(node.position, position + offset)
	assert_eq(node.get_meta("y_sort_anchor"), position)
	assert_true(is_equal_approx(node.rotation, PI * 0.5), "tall boats rotate by a quarter turn")
	assert_false((node.get_node("Shadow") as Polygon2D).visible, "boat shadows remain hidden")
	node.free()
