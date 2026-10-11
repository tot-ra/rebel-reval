extends "res://tests/godot/test_case.gd"

## Forge weapon set (R-1754) and its combat classes (R-1755): items, equip and world
## scenes, move sets, the bow's arrow, the shield's guard, and forge seeding.

const LOC_SMITHY := &"loc.kalev_smithy"
const SMITHY_DEFINITION := preload(
	"res://scripts/map/definitions/lower_town/kalev_smithy_definition.gd"
)
## item id -> expected weapon class (&"" = not an attack item).
const WEAPONS := {
	&"item.forge_arming_sword": &"sword",
	&"item.forge_longbow": &"bow",
	&"item.forge_spear": &"spear",
	&"item.forge_heater_shield": &"",
	&"item.forge_bearded_axe": &"axe",
	&"item.forge_war_hammer": &"hammer",
}


## Minimal damageable: counts hits.
var _dummy_target: GDScript = _make_dummy_script()


func before_each() -> void:
	super.before_each()
	restore_demo_session()


func test_every_weapon_item_has_held_and_world_scenes() -> void:
	var db: ContentDB = SessionState.content_db
	for item_id: StringName in WEAPONS:
		var record := db.get_item(item_id)
		assert_false(record.is_empty(), "%s must load from content/demo" % item_id)
		var equip: Dictionary = record.get("gameplay", {}).get("equip", {})
		for key: String in ["scene", "world_scene"]:
			var path := String(equip.get(key, ""))
			assert_true(ResourceLoader.exists(path), "%s %s missing: %s" % [item_id, key, path])
			var scene := load(path) as PackedScene
			var node := scene.instantiate() if scene != null else null
			assert_true(node is Node3D, "%s %s must instantiate a Node3D" % [item_id, key])
			if node != null:
				node.free()


func test_weapon_classes_resolve_from_items() -> void:
	var db: ContentDB = SessionState.content_db
	for item_id: StringName in WEAPONS:
		var expected: StringName = WEAPONS[item_id]
		if expected.is_empty():
			assert_false(AttackProfileResolver.item_has_attack_profile(item_id, db))
			continue
		assert_eq(AttackProfileResolver.weapon_class_for_item(item_id, db), expected, String(item_id))


func test_axe_chain_and_charged_cleave_use_item_numbers() -> void:
	var state := _state_holding(&"item.forge_bearded_axe", &"right_hand")
	var db: ContentDB = SessionState.content_db
	var first := AttackProfileResolver.resolve_move(state, db, false, 0)
	assert_eq(first.animation, &"axe_attack")
	assert_eq(first.weapon_class, &"axe")
	assert_almost_eq(first.damage, 16.0, 0.001)
	assert_eq(CombatMoveCatalog.combo_length(&"axe"), 3)
	var heavy := AttackProfileResolver.resolve_move(state, db, true, 0)
	assert_eq(heavy.animation, &"axe_heavy_attack")
	# Authored charged profile carries the heavy numbers unscaled.
	assert_almost_eq(heavy.damage, 27.0, 0.001)
	assert_false(first.is_ranged(), "an axe swing is melee")


func test_bow_profile_is_ranged_and_full_draw_flies_further() -> void:
	var state := _state_holding(&"item.forge_longbow", &"left_hand")
	var db: ContentDB = SessionState.content_db
	var shot := AttackProfileResolver.resolve_move(state, db, false, 0)
	assert_eq(shot.weapon_class, &"bow")
	assert_true(shot.is_ranged())
	assert_almost_eq(shot.ranged_range_px, 640.0, 0.001)
	assert_almost_eq(shot.ranged_speed_px_per_sec, 900.0, 0.001)
	var drawn := AttackProfileResolver.resolve_move(state, db, true, 0)
	assert_almost_eq(drawn.ranged_range_px, 640.0 * 1.3, 0.001)
	assert_true(drawn.damage > shot.damage)
	assert_true(drawn.pierces_guard)


func test_arrow_hits_the_first_actor_on_its_line() -> void:
	var root := Node2D.new()
	get_tree_root().add_child(root)
	var archer := Node2D.new()
	root.add_child(archer)
	archer.global_position = Vector2.ZERO
	var near := _dummy(root, Vector2(120.0, 4.0), MeleeAttackResolver.DAMAGEABLE_GROUP)
	var far := _dummy(root, Vector2(220.0, 0.0), MeleeAttackResolver.DAMAGEABLE_GROUP)
	var arrow := ArrowProjectile.loose(archer, Vector2.RIGHT, _bow_profile(), root)
	assert_true(arrow != null)
	for _step in 30:
		if not is_instance_valid(arrow) or not arrow.active:
			break
		arrow.advance(1.0 / 60.0)
	assert_eq(near.get_meta(&"hits", 0), 1, "the nearer actor takes the arrow")
	assert_eq(far.get_meta(&"hits", 0), 0, "an arrow stops in its first target")
	root.free()


func test_arrow_hits_bystanders_and_expires_at_range() -> void:
	var root := Node2D.new()
	get_tree_root().add_child(root)
	var archer := Node2D.new()
	root.add_child(archer)
	var bystander := _dummy(root, Vector2(0.0, 200.0), MeleeAttackResolver.BYSTANDER_GROUP)
	var aside := _dummy(root, Vector2(200.0, 200.0), MeleeAttackResolver.DAMAGEABLE_GROUP)
	var hit := ArrowProjectile.loose(archer, Vector2.DOWN, _bow_profile(), root)
	var expired := [false]
	var miss := ArrowProjectile.loose(archer, Vector2.LEFT, _bow_profile(), root)
	miss.expired.connect(func() -> void: expired[0] = true)
	for _step in 60:
		for arrow: ArrowProjectile in [hit, miss]:
			if is_instance_valid(arrow) and arrow.active:
				arrow.advance(1.0 / 60.0)
	assert_eq(bystander.get_meta(&"hits", 0), 1, "a peaceful bystander can be shot")
	assert_eq(aside.get_meta(&"hits", 0), 0)
	assert_true(expired[0], "an arrow with no target expires at its range")
	root.free()


func test_melee_swing_hits_bystanders_but_clicks_ignore_them() -> void:
	var root := Node2D.new()
	get_tree_root().add_child(root)
	var attacker := Node2D.new()
	root.add_child(attacker)
	var bystander := _dummy(root, Vector2(30.0, 0.0), MeleeAttackResolver.BYSTANDER_GROUP)
	assert_true(
		PlayerPrimaryAction.find_hostile_in_front(attacker, Vector2.RIGHT) == null,
		"a bystander never claims a click or soft-lock"
	)
	var hits := MeleeAttackResolver.strike(attacker, Vector2.RIGHT, 48.0, 0.35, 10.0)
	assert_eq(hits.size(), 1, "a real swing still lands on a bystander in reach")
	assert_eq(bystander.get_meta(&"hits", 0), 1)
	root.free()


func test_shield_in_off_hand_replaces_guard_numbers() -> void:
	var db: ContentDB = SessionState.content_db
	var vitals := CombatVitals.new()
	var bare := _state_holding(&"item.forge_arming_sword", &"right_hand")
	ShieldGuard.apply(vitals, bare, db)
	assert_almost_eq(
		vitals.guard_stamina_per_damage, CombatVitals.DEFAULT_GUARD_STAMINA_PER_DAMAGE, 0.001
	)
	assert_almost_eq(vitals.parry_window_sec, CombatVitals.DEFAULT_PARRY_WINDOW_SEC, 0.001)
	var shielded := _state_holding(&"item.forge_heater_shield", &"left_hand")
	ShieldGuard.apply(vitals, shielded, db)
	assert_almost_eq(vitals.guard_stamina_per_damage, 0.45, 0.001)
	assert_almost_eq(vitals.parry_window_sec, 0.26, 0.001)
	# A guarded 20-point blow costs less than half the stamina with the shield.
	vitals.configure(100.0, 100.0, 100.0, 100.0)
	ShieldGuard.apply(vitals, shielded, db)
	var pose := CombatDefensePose.open()
	pose.is_guarding = true
	pose.guard_elapsed_sec = 1.0
	var result := vitals.resolve_hit(20.0, pose, 1)
	assert_eq(result.outcome, CombatHitResult.OUTCOME_GUARDED)
	assert_almost_eq(result.stamina_damage, 9.0, 0.001)


func test_two_handed_bow_frees_the_right_hand_and_back() -> void:
	var state := _state_holding(&"item.forge_arming_sword", &"right_hand")
	assert_eq(state.bag.try_add(&"item.forge_longbow"), InventoryBag.AddResult.OK)
	assert_true(state.equip_from_bag(&"left_hand", &"item.forge_longbow"))
	assert_true(state.equipped_item(&"right_hand").is_empty(), "the bow takes both hands")
	assert_true(
		state.bag.find_placement(&"item.forge_arming_sword") != null, "the sword is back in the bag"
	)
	assert_eq(AttackProfileResolver.weapon_class_for_state(state, SessionState.content_db), &"bow")
	assert_true(state.equip_from_bag(&"right_hand", &"item.forge_arming_sword"))
	assert_true(state.equipped_item(&"left_hand").is_empty(), "a sword in hand puts the bow away")
	# One-handed pairs stay together.
	assert_eq(state.bag.try_add(&"item.forge_heater_shield"), InventoryBag.AddResult.OK)
	assert_true(state.equip_from_bag(&"left_hand", &"item.forge_heater_shield"))
	assert_eq(state.equipped_item(&"right_hand"), &"item.forge_arming_sword")


func test_new_game_seeds_spearhead_and_weapon_rack() -> void:
	var state := _fresh_state()
	var forge := _seed_smithy(state)
	assert_true(state.is_world_item_placed(LOC_SMITHY, &"world.spearhead_anvil"), "spearhead first")
	for object_id: StringName in _weapon_object_ids():
		assert_true(state.is_world_item_placed(LOC_SMITHY, object_id), String(object_id))
	assert_eq(state.get_world_items(LOC_SMITHY).size(), 7)
	forge.free()


func test_old_save_without_weapons_gets_them_once() -> void:
	var state := _fresh_state()
	# An older save: the original defaults were seeded and the spearhead taken.
	state.mark_world_defaults_seeded(LOC_SMITHY)
	var forge := _seed_smithy(state)
	assert_false(state.is_world_item_placed(LOC_SMITHY, &"world.spearhead_anvil"))
	assert_eq(state.get_world_items(LOC_SMITHY).size(), 6, "the weapon group is added")
	forge.free()
	state.take_world_item(LOC_SMITHY, &"world.forge_spear")
	forge = _seed_smithy(state)
	assert_false(
		state.is_world_item_placed(LOC_SMITHY, &"world.forge_spear"), "a taken weapon never respawns"
	)
	assert_true(
		state.are_world_defaults_seeded(
			WorldItemController.seed_group_key(LOC_SMITHY, &"forge_weapons")
		)
	)
	forge.free()


## --- helpers -----------------------------------------------------------------


func _state_holding(item_id: StringName, slot: StringName) -> GameState:
	var state := _fresh_state()
	assert_eq(state.bag.try_add(item_id), InventoryBag.AddResult.OK, "%s fits the bag" % item_id)
	assert_true(state.equip_from_bag(slot, item_id), "%s equips to %s" % [item_id, slot])
	return state


func _fresh_state() -> GameState:
	var state := GameState.new()
	state.bag.set_content_db(SessionState.content_db)
	return state


func _bow_profile() -> AttackProfile:
	var state := _state_holding(&"item.forge_longbow", &"left_hand")
	return AttackProfileResolver.resolve_move(state, SessionState.content_db, false, 0)


## Runs WorldItemController seeding for the smithy against `state` (no view).
func _seed_smithy(state: GameState) -> Node2D:
	var previous: GameState = SessionState.state
	SessionState.state = state
	var root := Node2D.new()
	get_tree_root().add_child(root)
	var controller := WorldItemController.new()
	root.add_child(controller)
	controller.setup(root, SMITHY_DEFINITION.create(), null, null, LOC_SMITHY)
	SessionState.state = previous
	return root


func _weapon_object_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for entry: Dictionary in WorldItemController.SEED_GROUPS[LOC_SMITHY][&"forge_weapons"]:
		ids.append(entry["object_id"])
	return ids


func _dummy(parent: Node, at: Vector2, group: StringName) -> Node2D:
	var dummy := Node2D.new()
	dummy.set_script(_dummy_target)
	parent.add_child(dummy)
	dummy.global_position = at
	dummy.add_to_group(group)
	return dummy


func get_tree_root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


static func _make_dummy_script() -> GDScript:
	var script := GDScript.new()
	script.source_code = """extends Node2D
func take_damage(
	amount: float, _s: Node = null, _t: StringName = &"", _w: int = 0, _p := false
) -> float:
	set_meta(&"hits", int(get_meta(&"hits", 0)) + 1)
	return amount
"""
	script.reload()
	return script
