extends "res://tests/godot/test_case.gd"

## ADR 0038 / SA3D-1 + ADR 0041 SS-6: arena disc, radius clamp, group-list hiding that keeps
## the building, the duel grade, fighters-only auras and exact restore.

var _root: Node3D
var _arena: SpiritArena3D
var _hero: Node3D
var _wall: Node3D
var _hidden_already: Node3D
var _lamp: OmniLight3D
var _table: Node3D
var _cart: Node3D
var _bystander: Node3D
var _env: Environment


func before_each() -> void:
	super.before_each()
	_root = Node3D.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(_root)
	var actors := Node3D.new()
	_root.add_child(actors)
	_hero = Node3D.new()
	actors.add_child(_hero)
	_wall = Node3D.new()
	_root.add_child(_wall)
	_hidden_already = Node3D.new()
	_hidden_already.visible = false
	_root.add_child(_hidden_already)
	_lamp = OmniLight3D.new()
	_root.add_child(_lamp)
	_table = Node3D.new()
	_table.add_to_group(SpiritArena3D.GROUP_FURNITURE)
	_root.add_child(_table)
	_cart = Node3D.new()
	_cart.add_to_group(SpiritArena3D.GROUP_PROP)
	_root.add_child(_cart)
	_bystander = Node3D.new()
	_bystander.add_to_group(SharedCharacterRig.SPIRIT_AURA_GROUP)
	_root.add_child(_bystander)
	_env = Environment.new()
	_env.adjustment_saturation = 0.9
	_env.ambient_light_energy = 0.8
	_env.ambient_light_color = Color(0.9, 0.8, 0.6)
	var world_env := WorldEnvironment.new()
	world_env.environment = _env
	_root.add_child(world_env)
	_arena = SpiritArena3D.new()


func after_each() -> void:
	if _arena != null and _arena.is_open():
		_arena.close()
	_root.free()
	super.after_each()


func test_clamp_keeps_fighters_on_the_disc() -> void:
	assert_true(_arena.open(_root, Vector3(10, 2, 10), [_hero], false, 5.0))
	var inside := Vector3(12, 2, 10)
	assert_eq(_arena.clamp_position(inside), inside)
	var pulled := _arena.clamp_position(Vector3(30, 7, 10))
	assert_almost_eq(pulled.x, 15.0, 0.001)
	assert_almost_eq(pulled.z, 10.0, 0.001)
	assert_almost_eq(pulled.y, 7.0, 0.001)
	assert_true(_arena.contains(pulled))
	assert_false(_arena.contains(Vector3(30, 0, 10)))


func test_walls_stay_and_hide_groups_vanish_indoors_and_outdoors() -> void:
	for is_indoors in [true, false]:
		var arena := SpiritArena3D.new()
		arena.open(_root, Vector3.ZERO, [_hero], is_indoors)
		assert_true(_wall.visible, "walls, floor and shells have no hide group")
		assert_false(_table.visible, "furniture hides")
		assert_false(_cart.visible, "props hide")
		assert_true(_hero.visible and _hero.get_parent().visible, "fighter and ancestor stay")
		arena.close()
		assert_true(_table.visible and _cart.visible)


func test_every_hide_group_is_in_the_one_list() -> void:
	assert_eq(SpiritArena3D.HIDE_GROUPS.size(), 4)
	for group: StringName in [&"spirit_hide_furniture", &"spirit_hide_prop", &"spirit_hide_item", &"spirit_hide_clutter"]:  # gdlint: ignore=max-line-length
		assert_true(SpiritArena3D.HIDE_GROUPS.has(group))


func test_a_group_node_holding_a_fighter_is_not_hidden() -> void:
	_hero.get_parent().add_to_group(SpiritArena3D.GROUP_CLUTTER)
	_arena.open(_root, Vector3.ZERO, [_hero])
	assert_true(_hero.get_parent().visible)


func test_other_beings_and_other_lights_go_but_arena_lights_stay() -> void:
	_arena.open(_root, Vector3.ZERO, [_hero])
	assert_false(_bystander.visible, "a being outside the duel is hidden")
	assert_false(_lamp.visible, "the room lamp is switched off")
	assert_true(_arena.get_node("SpiritKey").visible)
	assert_true(_arena.get_node("SpiritFill").visible)
	_arena.close()
	assert_true(_bystander.visible and _lamp.visible)


func test_duel_grade_is_indigo_and_restores_exactly() -> void:
	_arena.open(_root, Vector3.ZERO, [_hero])
	assert_almost_eq(_env.adjustment_saturation, 0.1, 0.001)
	assert_true(_env.ambient_light_energy < 0.8 * 0.6)
	assert_true(_env.ambient_light_color.b > _env.ambient_light_color.r)
	_arena.close()
	assert_almost_eq(_env.adjustment_saturation, 0.9, 0.001)
	assert_almost_eq(_env.ambient_light_energy, 0.8, 0.001)
	assert_eq(_env.ambient_light_color, Color(0.9, 0.8, 0.6))


func test_only_fighters_show_an_aura_and_the_private_manager_goes_on_close() -> void:
	_hero.add_to_group(SharedCharacterRig.SPIRIT_AURA_GROUP)
	var porter := Node3D.new()
	porter.add_to_group(SharedCharacterRig.SPIRIT_AURA_GROUP)
	_root.add_child(porter)
	var keep: Array[Node3D] = [_hero, porter]
	_arena.open(_root, Vector3.ZERO, keep)
	for fighter in keep:
		var view := _arena.aura_view_for(fighter)
		assert_true(view != null and view.tier == SpiritAuraView.Tier.FULL)
	assert_true(_arena.aura_view_for(_bystander) == null, "no aura for people outside the duel")
	var hero_view := _arena.aura_view_for(_hero)
	_arena.close()
	assert_true(hero_view.is_queued_for_deletion(), "the private manager's views are freed")


func test_with_a_sight_controller_the_duel_layers_on_sight_and_returns_to_it() -> void:
	var sight: Node = load("res://scripts/combat/spirit_sight.gd").new()
	sight.follow_session = false
	sight.state = GameState.new()
	sight.environment_override = _env
	_root.add_child(sight)
	sight.state.spirit_sight = true
	sight.blend = 1.0
	_arena.open(_root, Vector3.ZERO, [_hero])
	assert_almost_eq(float(sight.duel_amount), 1.0, 0.001)
	sight.enforce_availability()
	assert_true(sight.state.spirit_sight, "the duel does not cancel sight")
	sight.compose_grade()
	assert_almost_eq(_env.adjustment_saturation, 0.1, 0.001)
	_arena.close()
	assert_almost_eq(float(sight.duel_amount), 0.0, 0.001)
	assert_true(sight.state.spirit_sight, "closing returns to spirit sight")
	sight.compose_grade()
	assert_almost_eq(_env.adjustment_saturation, 0.25, 0.001, "back to the sight grade")
	sight.leave_immediately()
	assert_almost_eq(_env.adjustment_saturation, 0.9, 0.001)


func test_close_restores_exact_visibility() -> void:
	_arena.open(_root, Vector3.ZERO, [_hero], true)
	_arena.close()
	assert_true(_wall.visible)
	assert_true(_table.visible and _lamp.visible)
	assert_false(_hidden_already.visible, "already-hidden nodes stay hidden")
	assert_false(_arena.is_open())


func test_prehidden_group_node_stays_hidden_after_close() -> void:
	_cart.visible = false
	_arena.open(_root, Vector3.ZERO, [_hero])
	_arena.close()
	assert_false(_cart.visible)


func test_open_twice_and_bad_radius_refuse() -> void:
	assert_false(_arena.open(_root, Vector3.ZERO, [], false, 0.0))
	assert_true(_arena.open(_root, Vector3.ZERO))
	assert_false(_arena.open(_root, Vector3.ZERO))
