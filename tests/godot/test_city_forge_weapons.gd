extends "res://tests/godot/test_case.gd"

const CITY_LOCATION := &"loc.reval_city"
const CITY_PLAN := preload("res://scripts/city/city_plan.gd")


func before_each() -> void:
	super.before_each()
	restore_demo_session()


func test_city_forge_weapon_group_seeds_around_the_city_anvil_and_keeps_picked_items_gone() -> void:
	var plan := CITY_PLAN.load_default()
	var definition := CityMapDefinition.from_plan(plan)
	var state := GameState.new()
	state.bag.set_content_db(SessionState.content_db)
	var previous: GameState = SessionState.state
	SessionState.state = state
	var root := Node2D.new()
	get_tree_root().add_child(root)
	var controller := WorldItemController.new()
	root.add_child(controller)
	controller.setup(root, definition, null, null, CITY_LOCATION)

	var weapons := state.get_world_items(CITY_LOCATION)
	assert_eq(weapons.size(), 6)
	var smithy: CitySite = null
	for candidate: CitySite in plan.sites:
		if candidate.id == &"site.kalev_smithy":
			smithy = candidate
			break
	assert_true(smithy != null, "the city plan contains Kalev's smithy")
	if smithy != null:
		var anvil := smithy.to_world(Vector2(9.33, 4.03))
		for weapon: Dictionary in weapons:
			var world_at := CityPlan.to_world_xz(weapon["position"])
			assert_true(
				world_at.distance_to(anvil) < 2.2,
				"weapon must be in the city forge bay near the anvil"
			)
	state.take_world_item(CITY_LOCATION, &"world.forge_arming_sword")
	root.free()
	SessionState.state = previous
	assert_false(
		state.is_world_item_placed(CITY_LOCATION, &"world.forge_arming_sword"),
		"taken sword stays gone"
	)


func get_tree_root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root
