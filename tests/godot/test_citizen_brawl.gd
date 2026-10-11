extends "res://tests/godot/test_case.gd"

## Brawls with citizens (R-1756): every resident has health and stamina, men fight
## back through the shared enemy AI, others flee, the fallen stay down.

const MAN := {
	"id": "cit.test.man", "name": "Test Man", "sex": "m", "age": 34, "trade": "brickmaker",
	"appearance": {"build": "average"}, "height_scale": 1.0,
}
const CHILD := {
	"id": "cit.test.child", "name": "Test Child", "sex": "f", "age": 9, "trade": "",
	"appearance": {"build": "thin"}, "height_scale": 0.7,
}
const ELDER := {
	"id": "cit.test.elder", "name": "Test Elder", "sex": "m", "age": 71, "trade": "",
	"appearance": {"build": "average"}, "height_scale": 0.95,
}
const WATCHMAN := {
	"id": "cit.test.watch", "name": "Test Watch", "sex": "m", "age": 58, "trade": "weaver",
	"appearance": {"build": "average"}, "height_scale": 1.0, "duty": {"kit": "watch"},
}


func test_stats_follow_age_sex_trade_and_duty() -> void:
	var man := CitizenBrawler.stats_for(MAN)
	assert_true(man["fights"], "an able-bodied man fights back")
	assert_true(man["strong"], "a brickmaker is strong")
	assert_almost_eq(float(man["health"]), 70.0, 0.001)
	assert_false(CitizenBrawler.stats_for(CHILD)["fights"], "a child runs")
	assert_false(CitizenBrawler.stats_for(ELDER)["fights"], "an old man runs")
	var watch := CitizenBrawler.stats_for(WATCHMAN)
	assert_true(watch["fights"] and watch["armed"], "the watch fights at any age, armed")
	assert_eq(CitizenBrawler.archetype_for(watch).attack_animation, &"spear_attack")
	assert_true(float(CitizenBrawler.stats_for(CHILD)["health"]) < float(man["health"]))


func test_struck_man_turns_and_hits_back() -> void:
	var root := Node2D.new()
	_tree_root().add_child(root)
	var hero := _hero(root, Vector2(30.0, 0.0))
	var brawler := CitizenBrawler.create(0, MAN)
	brawler.position = Vector2.ZERO
	var dealt := brawler.take_hit(10.0, hero, Vector2.ZERO, 1, false)
	assert_almost_eq(dealt, 10.0, 0.001)
	assert_eq(brawler.mode, CitizenBrawler.Mode.FIGHT)
	assert_true(brawler.shows_bars())
	for _step in 180:
		brawler.step(1.0 / 60.0, hero, Vector2.ZERO)
	assert_true(int(hero.get_meta(&"hits", 0)) >= 1, "within 3 s the man lands a blow")
	assert_true(brawler.vitals.stamina < brawler.vitals.max_stamina + 0.001)
	root.free()


func test_struck_child_runs_away_then_heads_home() -> void:
	var root := Node2D.new()
	_tree_root().add_child(root)
	var hero := _hero(root, Vector2(20.0, 0.0))
	var brawler := CitizenBrawler.create(1, CHILD)
	brawler.take_hit(5.0, hero, Vector2.ZERO, 1, false)
	assert_eq(brawler.mode, CitizenBrawler.Mode.FLEE)
	var velocity := brawler.step(1.0 / 60.0, hero, Vector2.ZERO)
	assert_true(velocity.dot(Vector2.LEFT) > 0.9, "she runs directly away from the hero")
	var home := Vector2(-600.0, 0.0)
	for _step in int(CitizenBrawler.FLEE_SEC * 60.0) + 2:
		brawler.step(1.0 / 60.0, hero, home)
	assert_eq(brawler.mode, CitizenBrawler.Mode.RETURN, "after the scare she walks home")
	assert_true(brawler.step(1.0 / 60.0, hero, home).dot(Vector2.LEFT) > 0.9)
	root.free()


func test_zero_health_falls_and_stays_down() -> void:
	var brawler := CitizenBrawler.create(2, ELDER)
	var swing := 1
	while not brawler.is_down() and swing < 50:
		brawler.take_hit(15.0, null, Vector2.ZERO, swing, false)
		# Let the post-hit invulnerability (CombatVitals) run out between blows.
		brawler.vitals.tick(0.5)
		swing += 1
	assert_true(brawler.is_down())
	assert_eq(brawler.view_animation(), &"fall")
	assert_almost_eq(brawler.take_hit(15.0, null, Vector2.ZERO, swing, false), 0.0, 0.001)
	assert_eq(
		brawler.step(1.0, null, Vector2(500.0, 500.0)), Vector2.ZERO, "the fallen do not walk home"
	)
	assert_false(brawler.shows_bars())


func test_actor_is_a_bystander_until_it_fights() -> void:
	var root := Node2D.new()
	_tree_root().add_child(root)
	var actor := _actor(root, MAN)
	assert_true(actor.brawler == null, "a peaceful resident allocates no vitals")
	assert_true(actor.is_in_group(MeleeAttackResolver.BYSTANDER_GROUP))
	assert_false(actor.is_in_group(MeleeAttackResolver.DAMAGEABLE_GROUP))
	var attacker := Node2D.new()
	root.add_child(attacker)
	attacker.global_position = actor.global_position - Vector2(30.0, 0.0)
	var hits := MeleeAttackResolver.strike(attacker, Vector2.RIGHT, 48.0, 0.35, 10.0)
	assert_eq(hits.size(), 1, "a swing lands on the resident")
	assert_true(actor.brawler != null)
	assert_true(actor.is_in_group(MeleeAttackResolver.DAMAGEABLE_GROUP), "a fighter is hostile")
	assert_false(actor.is_in_group(MeleeAttackResolver.BYSTANDER_GROUP))
	assert_almost_eq(actor.health, actor.max_health - 10.0, 0.001)
	assert_true(actor.max_stamina > 0.0)
	var context := actor.guilt_context()
	assert_false(context["aggressor"], "the first blow on a peaceful man is provoked")
	assert_eq(PhysicalBlowGuilt.classify(context), &"act.unarmed_victim")
	root.free()


func test_fleeing_actor_stays_a_bystander() -> void:
	var root := Node2D.new()
	_tree_root().add_child(root)
	var actor := _actor(root, CHILD)
	actor.take_damage(5.0, null, &"blunt", 1, false)
	assert_eq(actor.brawler.mode, CitizenBrawler.Mode.FLEE)
	assert_true(actor.is_in_group(MeleeAttackResolver.BYSTANDER_GROUP))
	assert_false(actor.is_in_group(MeleeAttackResolver.DAMAGEABLE_GROUP))
	assert_eq(actor.view_animation(), &"run")
	root.free()


func test_health_ring_shows_stamina_strip() -> void:
	var ring := CharacterHealthRing3D.new()
	_tree_root().add_child(ring)
	ring.set_health(30.0, 60.0)
	ring.set_stamina(25.0, 50.0)
	assert_almost_eq(ring.get_health_ratio(), 0.5, 0.001)
	assert_almost_eq(ring.get_stamina_ratio(), 0.5, 0.001)
	assert_true(ring.get_node_or_null(^"StaminaFill") != null)
	ring.free()


## --- helpers -----------------------------------------------------------------


func _tree_root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


## A CitizenActor wired like CityCitizens wires it, without a roster or physics.
func _actor(parent: Node, record: Dictionary) -> CitizenActor:
	var actor := CitizenActor.new()
	actor.record = record
	actor.index = 7
	var brawlers := {}
	actor.hit_handler = func(
		who: CitizenActor, amount: float, attacker: Node2D, swing_id: int, pierce: bool
	) -> float:
		if who.brawler == null:
			who.brawler = CitizenBrawler.create(who.index, who.record)
			brawlers[who.index] = who.brawler
		return who.brawler.take_hit(amount, attacker, who.global_position, swing_id, pierce)
	actor.set_physics_process(false)
	parent.add_child(actor)
	actor.global_position = Vector2(200.0, 200.0)
	return actor


func _hero(parent: Node, at: Vector2) -> Node2D:
	var script := GDScript.new()
	script.source_code = """extends Node2D
func take_damage(
	amount: float, _s: Node = null, _t: StringName = &"", _w: int = 0, _p := false
) -> float:
	set_meta(&"hits", int(get_meta(&"hits", 0)) + 1)
	return amount
"""
	script.reload()
	var hero := Node2D.new()
	hero.set_script(script)
	parent.add_child(hero)
	hero.global_position = at
	return hero
