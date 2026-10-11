extends "res://tests/godot/test_case.gd"

const CartTransport := preload("res://scripts/world/cart_transport_model.gd")


func test_cart_transport_defaults_and_closed_route_classes() -> void:
	assert_eq(CartTransport.default_vehicle_class(), CartTransport.VEHICLE_CLASS_CART_2W)
	assert_true(CartTransport.is_single_horse_draught(CartTransport.VEHICLE_CLASS_CART_2W))
	assert_eq(CartTransport.draught_horse_count(CartTransport.VEHICLE_CLASS_BARROW), 0)
	assert_true(
		CartTransport.vehicle_class_allowed_on_route(
			CartTransport.VEHICLE_CLASS_WAGON_4W, CartTransport.ROUTE_WALL_YARD
		)
	)
	assert_true(
		CartTransport.vehicle_class_allowed_on_route(
			CartTransport.VEHICLE_CLASS_BARROW, CartTransport.ROUTE_FORUM_THROAT
		)
	)
	assert_false(
		CartTransport.vehicle_class_allowed_on_route(
			CartTransport.VEHICLE_CLASS_WAGON_4W, CartTransport.ROUTE_FORUM_THROAT
		)
	)
	assert_false(
		CartTransport.vehicle_class_allowed_on_route(
			CartTransport.VEHICLE_CLASS_BARROW, CartTransport.ROUTE_VIRU_GRAIN
		)
	)


func test_road_states_and_cart_economy_bands() -> void:
	assert_eq(CartTransport.ROAD_STATES.size(), 3)
	assert_eq(CartTransport.road_speed_modifier(CartTransport.ROAD_STATE_COBBLE), 1.0)
	assert_eq(CartTransport.road_speed_modifier(CartTransport.ROAD_STATE_MUD), 0.7)
	assert_eq(CartTransport.road_speed_modifier(CartTransport.ROAD_STATE_ICE), 0.5)
	assert_eq(CartTransport.effective_speed(40.0, CartTransport.ROAD_STATE_MUD), 28.0)
	assert_eq(CartTransport.road_speed_modifier(&"unknown"), 0.0)
	assert_true(CartTransport.cart_load_is_valid(250))
	assert_true(CartTransport.cart_load_is_valid(350))
	assert_false(CartTransport.cart_load_is_valid(249))
	assert_false(CartTransport.cart_load_is_valid(351))
	assert_true(CartTransport.carter_hire_is_valid(4))
	assert_true(CartTransport.carter_hire_is_valid(12))
	assert_false(CartTransport.carter_hire_is_valid(3))
	assert_false(CartTransport.carter_hire_is_valid(13))
	assert_true(CartTransport.cart_toll_pfennig() == null)


func test_inland_cutoff_stops_grain_but_harbour_lighter_route_continues() -> void:
	assert_true(CartTransport.siege_inland_cart_active_for_date("1343-04-23"))
	assert_false(CartTransport.siege_inland_cart_active_for_date("1343-04-24"))
	assert_false(CartTransport.route_available_for_date(CartTransport.ROUTE_VIRU_GRAIN, "1343-04-24"))
	assert_false(CartTransport.route_available_for_date(CartTransport.ROUTE_HARJU_GRAIN, "1343-04-24"))
	assert_true(
		CartTransport.route_available_for_date(
			CartTransport.ROUTE_HARBOUR_LIGHTER_TO_CART, "1343-04-24"
		)
	)
	var siege_routes := CartTransport.routes_for_siege(false)
	var route_ids: Array[StringName] = []
	for descriptor in siege_routes:
		route_ids.append(descriptor["route_id"])
	assert_false(route_ids.has(CartTransport.ROUTE_VIRU_GRAIN))
	assert_false(route_ids.has(CartTransport.ROUTE_HARJU_GRAIN))
	assert_true(route_ids.has(CartTransport.ROUTE_HARBOUR_LIGHTER_TO_CART))
	assert_true(route_ids.has(CartTransport.ROUTE_WALL_YARD))
	assert_true(route_ids.has(CartTransport.ROUTE_FORUM_THROAT))


func test_bark_vocabulary_is_closed_and_authored() -> void:
	for term in ["Karren", "Wagen", "Fuhrmann", "voorimees", "Macht Platz!"]:
		assert_array_contains(CartTransport.bark_vocabulary(), term)

