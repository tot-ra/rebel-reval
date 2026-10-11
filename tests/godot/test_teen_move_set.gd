extends "res://tests/godot/test_case.gd"

## ADR 0033 / SD-11: the teen hero reuses the shared clips with a quicker, lighter,
## shorter move set; the adult baseline stays untouched.

const CONTENT_DIRS: Array[String] = [
	"res://content/demo",
	"res://content/examples/valid",
	"res://content/examples/support",
]
const APPRENTICE := preload("res://assets/characters/variants/apprentice.tscn")
const KALEV := preload("res://assets/characters/kalev/kalev.tscn")


func test_build_follows_the_character() -> void:
	assert_eq(CombatMoveCatalog.build_for_character(&"char.apprentice"), CombatMoveCatalog.BUILD_TEEN)
	assert_eq(CombatMoveCatalog.build_for_character(&"char.kalev"), CombatMoveCatalog.BUILD_ADULT)
	assert_eq(CombatMoveCatalog.build_for_character(&""), CombatMoveCatalog.BUILD_ADULT)


func test_adult_moves_are_unchanged_and_teen_moves_keep_the_same_clip() -> void:
	for step in 3:
		var adult := CombatMoveCatalog.light_move(CombatMoveCatalog.CLASS_HAMMER, step)
		var teen := CombatMoveCatalog.light_move(
			CombatMoveCatalog.CLASS_HAMMER, step, CombatMoveCatalog.BUILD_TEEN
		)
		assert_eq(teen.id, adult.id, "same clip, no new import")
		assert_almost_eq(teen.impact_sec, adult.impact_sec * 0.92, 0.0001)
		assert_almost_eq(teen.duration_sec, adult.duration_sec * 0.92, 0.0001)
		assert_almost_eq(teen.cancel_sec, adult.cancel_sec * 0.92, 0.0001)
		assert_almost_eq(teen.lunge_px, adult.lunge_px * 0.85, 0.0001)
		assert_eq(teen.source_contact_sec, adult.source_contact_sec)
	assert_almost_eq(
		CombatMoveCatalog.light_move(CombatMoveCatalog.CLASS_HAMMER, 0).impact_sec, 0.34, 0.0001
	)


func test_every_teen_move_still_lands_its_contact_frame_on_impact() -> void:
	for weapon_class in CombatMoveCatalog.WEAPON_CLASSES:
		var moves: Array[CombatMove] = [
			CombatMoveCatalog.heavy_move(weapon_class, CombatMoveCatalog.BUILD_TEEN)
		]
		for step in CombatMoveCatalog.combo_length(weapon_class):
			moves.append(
				CombatMoveCatalog.light_move(weapon_class, step, CombatMoveCatalog.BUILD_TEEN)
			)
		for move in moves:
			var contact := minf(move.source_contact_sec, 3.0)
			assert_almost_eq(move.source_time(move.impact_sec, 3.0), contact, 0.0001, String(move.id))
			var presented := CombatMoveCatalog.presentation_move(move.id, CombatMoveCatalog.BUILD_TEEN)
			assert_almost_eq(presented.impact_sec, move.impact_sec, 0.0001, String(move.id))


func test_resolved_profile_is_lighter_shorter_and_dearer_for_the_teen() -> void:
	var db := ContentDB.new()
	assert_true(db.load_from_directories(CONTENT_DIRS))
	var state := GameState.new()
	assert_eq(state.bag.try_add(&"item.forge_hammer"), InventoryBag.AddResult.OK)
	assert_true(state.equip_from_bag(&"right_hand", &"item.forge_hammer"))
	var adult := AttackProfileResolver.resolve_move(state, db, false, 0)
	var teen := AttackProfileResolver.resolve_move(
		state, db, false, 0, CombatMoveCatalog.BUILD_TEEN
	)
	assert_eq(teen.animation, adult.animation)
	assert_almost_eq(teen.damage, adult.damage * 0.8, 0.001)
	assert_almost_eq(teen.reach_px, adult.reach_px * 0.93, 0.001)
	assert_almost_eq(teen.stamina_cost, adult.stamina_cost * 1.15, 0.001)
	assert_almost_eq(teen.impact_timing_sec, adult.impact_timing_sec * 0.92, 0.0001)
	var adult_heavy := AttackProfileResolver.resolve_move(state, db, true, 0)
	var teen_heavy := AttackProfileResolver.resolve_move(
		state, db, true, 0, CombatMoveCatalog.BUILD_TEEN
	)
	assert_almost_eq(teen_heavy.damage, adult_heavy.damage * 0.8, 0.001, "authored charged damage scales too")


func test_rigs_report_their_build_and_the_hero_defaults_to_teen() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var apprentice := APPRENTICE.instantiate() as SharedCharacterRig
	tree.root.add_child(apprentice)
	var kalev := KALEV.instantiate() as SharedCharacterRig
	tree.root.add_child(kalev)
	assert_eq(apprentice.combat_build(), CombatMoveCatalog.BUILD_TEEN)
	assert_eq(kalev.combat_build(), CombatMoveCatalog.BUILD_ADULT)
	for rig: SharedCharacterRig in [apprentice, kalev]:
		SharedCharacterRig._detach_render_geometry(rig)
		rig.free()
	var script: GDScript = load("res://scripts/player.gd")
	var found := false
	for property in script.get_script_property_list():
		if property["name"] == "combat_build":
			found = true
	assert_true(found, "Player exposes combat_build")
