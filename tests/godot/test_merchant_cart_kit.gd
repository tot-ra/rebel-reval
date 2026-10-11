extends "res://tests/godot/test_case.gd"

const CartModels := preload("res://scripts/map/view3d/map_view_cart_models.gd")


func test_merchant_cart_exposes_production_wooden_cart_model() -> void:
	var host := Node3D.new()
	var model := CartModels.add_model(host)
	assert_true(model.get_meta(&"production_cart_model", false))
	assert_eq(model.name, "WoodenCartModel")
	model.queue_free()
	host.free()


func test_street_cart_prop_uses_shared_wooden_cart_model() -> void:
	var prop := MapViewMeshBuilder.build_prop(
		{"id": &"harbour_cart", "kind": MapTypes.PROP_KIND_CART, "position": Vector2.ZERO},
		MapTypes.DEFAULT_CELL_SIZE
	)
	assert_true(prop.has_node("WoodenCartModel"))
	assert_true(prop.get_node("WoodenCartModel").get_meta(&"production_cart_model", false))
	prop.free()
