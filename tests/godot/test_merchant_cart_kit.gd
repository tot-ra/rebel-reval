extends "res://tests/godot/test_case.gd"

const CartModels := preload("res://scripts/map/view3d/map_view_cart_models.gd")
const PropStyleVariants := preload("res://scripts/map/map_prop_style_variants.gd")


func test_merchant_vehicle_kit_keeps_three_non_war_silhouettes() -> void:
	var expected_classes: Array[StringName] = [
		PropStyleVariants.VEHICLE_CLASS_CART_2W,
		PropStyleVariants.VEHICLE_CLASS_WAGON_4W,
		PropStyleVariants.VEHICLE_CLASS_BARROW,
	]
	var expected_wheels := [2, 4, 1]
	for index in expected_classes.size():
		var host := Node3D.new()
		var model := CartModels.add_model(host, expected_classes[index], CartModels.LOAD_GRAIN_SACK)
		assert_true(model.get_meta(&"production_cart_model", false))
		assert_eq(model.get_meta(&"vehicle_class"), expected_classes[index])
		assert_eq(model.get_meta(&"wheel_count"), expected_wheels[index])
		assert_false(
			model.get_meta(&"war_wagon", true), "merchant kit must not expose war-wagon geometry"
		)
		assert_true(
			model.get_meta(&"silhouette_class", &"") != &"",
			"each class needs a readable silhouette label"
		)
		if expected_classes[index] == PropStyleVariants.VEHICLE_CLASS_CART_2W:
			assert_true(
				model.has_node("Load_grain_sack"), "cart_2w must accept an authored cargo load"
			)
			model.queue_free()
		else:
			model.queue_free()
		host.free()


func test_merchant_vehicle_kit_uses_legacy_model_when_class_is_unset() -> void:
	var host := Node3D.new()
	var model := CartModels.add_model(host)
	assert_eq(model.name, "WoodenCartModel")
	assert_eq(model.get_meta(&"vehicle_class"), &"legacy_wooden_cart")
	assert_eq(model.get_meta(&"wheel_count"), 2)
	model.queue_free()
	host.free()


func test_merchant_vehicle_kit_load_allowlist_is_closed() -> void:
	assert_eq(CartModels.LOAD_PROPS.size(), 7)
	assert_array_contains(CartModels.LOAD_PROPS, CartModels.LOAD_GRAIN_SACK)
	assert_array_contains(CartModels.LOAD_PROPS, CartModels.LOAD_BEER_BARREL)
	assert_array_contains(CartModels.LOAD_PROPS, CartModels.LOAD_SALT_KEG)
	assert_array_contains(CartModels.LOAD_PROPS, CartModels.LOAD_IRON_BAR_BUNDLE)
	assert_array_contains(CartModels.LOAD_PROPS, CartModels.LOAD_CHARCOAL_SACK)
	assert_array_contains(CartModels.LOAD_PROPS, CartModels.LOAD_HEMP_FLAX_BALE)
	assert_array_contains(CartModels.LOAD_PROPS, CartModels.LOAD_HIDE_BUNDLE)
	assert_false(CartModels.LOAD_PROPS.has(&"war_wagon_turret"))


func test_cart_prop_selects_vehicle_class_and_load() -> void:
	var wagon := (
		MapViewMeshBuilder
		. build_prop(
			{
				"id": &"harbour_wagon",
				"kind": MapTypes.PROP_KIND_CART,
				"position": Vector2.ZERO,
				"vehicle_class": PropStyleVariants.VEHICLE_CLASS_WAGON_4W,
				"load_prop": CartModels.LOAD_BEER_BARREL,
			},
			MapTypes.DEFAULT_CELL_SIZE
		)
	)
	assert_true(wagon.has_node("Wagon4WModel"))
	assert_true(wagon.get_node("Wagon4WModel").has_node("Load_beer_barrel"))
	assert_eq(
		wagon.get_node("Wagon4WModel").get_meta(&"vehicle_class"),
		PropStyleVariants.VEHICLE_CLASS_WAGON_4W
	)
	wagon.queue_free()

	var barrow := (
		MapViewMeshBuilder
		. build_prop(
			{
				"id": &"forum_barrow",
				"kind": MapTypes.PROP_KIND_CART,
				"position": Vector2.ZERO,
				"vehicle_class": PropStyleVariants.VEHICLE_CLASS_BARROW,
			},
			MapTypes.DEFAULT_CELL_SIZE
		)
	)
	assert_true(barrow.has_node("BarrowModel"))
	assert_eq(barrow.get_node("BarrowModel").get_meta(&"wheel_count"), 1)
	barrow.queue_free()
