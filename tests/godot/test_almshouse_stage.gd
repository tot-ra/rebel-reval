extends "res://tests/godot/test_case.gd"

## R-1334: the almshouse spell duel plays over a staged hall, not an opaque curtain.

const OPENING_SCENE := preload("res://scenes/prologue/almshouse_opening.tscn")


func test_the_opening_stages_hero_and_porter_facing_each_other() -> void:
	var opening := OPENING_SCENE.instantiate() as AlmshouseOpening
	opening.auto_continue = false
	(Engine.get_main_loop() as SceneTree).root.add_child(opening)
	var stage := opening.get_node(^"Stage") as AlmshouseStage
	assert_true(stage != null, "the opening mounts the almshouse stage")
	assert_true(stage.hero() != null and stage.porter() != null)
	assert_true(stage.camera().current, "the stage camera frames the duel")
	# Each faces the other: hero on the left looks toward +x, porter on the right toward -x.
	var hero_forward := stage.hero().global_basis.z
	var porter_forward := stage.porter().global_basis.z
	assert_true(stage.hero().position.x < 0.0 and hero_forward.x > 0.5)
	assert_true(stage.porter().position.x > 0.0 and porter_forward.x < -0.5)
	opening.free()


func test_the_arena_tint_leaves_the_scene_visible() -> void:
	assert_true(SpiritArenaHost.DIM_ALPHA < 0.5, "the arena dims the scene, it does not hide it")


func _opening() -> AlmshouseOpening:
	SessionState.state.set_flag(&"flag.prologue.apprenticed", false)
	var opening := OPENING_SCENE.instantiate() as AlmshouseOpening
	opening.auto_continue = false
	(Engine.get_main_loop() as SceneTree).root.add_child(opening)
	return opening


## R-1365: the porter's lines move the porter's jaw, not the boy's.
func test_the_porter_talks_while_his_duel_line_is_read() -> void:
	var opening := _opening()
	var stage := opening.get_node(^"Stage") as AlmshouseStage
	assert_true(opening.begin_duel())
	assert_eq(stage.porter().call(&"variant_id"), AlmshouseStage.PORTER_SPEAKER_ID)
	assert_true(stage.porter().call(&"is_talking"), "the porter speaks the opening line")
	assert_false(stage.hero().call(&"is_talking"), "the boy is silent while the porter speaks")
	assert_true(stage.kalev() == null, "Kalev is not in the hall during the duel")
	opening.host().close()
	opening.free()


## R-1365: Kalev's scene puts his rig in the doorway, reframes the camera and he talks.
func test_kalev_enters_the_hall_for_his_scene() -> void:
	var opening := _opening()
	var stage := opening.get_node(^"Stage") as AlmshouseStage
	var duel_camera := stage.camera().global_position
	assert_true(opening.begin_duel())
	opening.host().close()
	assert_eq(opening.stage, AlmshouseOpening.STAGE_KALEV)
	var kalev := stage.kalev()
	assert_true(kalev != null and kalev.is_inside_tree(), "Kalev's rig is in the hall")
	assert_eq(kalev.call(&"variant_id"), &"char.kalev")
	assert_true(kalev.position.z < -1.5, "he stands back by the doorway")
	var to_hero := (stage.hero().position - kalev.position).normalized()
	assert_true(kalev.global_basis.z.dot(to_hero) > 0.9, "he faces the boy")
	assert_true(stage.camera().current)
	assert_true(stage.camera().global_position.distance_to(duel_camera) > 0.5, "camera reframed")
	assert_true(kalev.call(&"is_talking"), "Kalev's jaw moves on his first line")
	assert_false(stage.porter().call(&"is_talking"))
	assert_true(stage.bring_in_kalev() == kalev, "bringing him in again is a no-op")
	opening.free()


## R-1365: an exchange that costs someone flinches them; buffs and clean defences do not.
func test_duel_exchanges_play_a_hit_on_whoever_they_hurt() -> void:
	var opening := _opening()
	var stage := opening.get_node(^"Stage") as AlmshouseStage
	assert_true(stage.react_to_exchange({"kind": "reply", "damage": 12.0}) == stage.porter())
	assert_eq(stage.porter().call(&"current_canonical_animation"), &"hit")
	assert_true(stage.react_to_exchange({"kind": "incoming", "composure_lost": 8.0}) == stage.hero())
	assert_eq(stage.hero().call(&"current_canonical_animation"), &"hit")
	assert_true(stage.react_to_exchange({"kind": "spell", "arena_effect": "pressure"}) != null)
	assert_true(stage.react_to_exchange({"kind": "spell", "arena_effect": "buff"}) == null)
	assert_true(stage.react_to_exchange({"kind": "incoming", "composure_lost": 0.0}) == null)
	assert_true(stage.react_to_exchange({"kind": "hesitation", "composure_lost": 3.0}) == null)
	opening.free()


## R-1365: a real cast in the duel reaches the stage through SpiritDuel.exchange_resolved.
func test_a_cast_in_the_duel_makes_the_porter_flinch() -> void:
	var opening := _opening()
	var stage := opening.get_node(^"Stage") as AlmshouseStage
	assert_true(opening.begin_duel())
	var duel := opening.host().duel
	duel.tick(SpiritDuel.TELEGRAPH_SEC + 0.01)
	assert_true(duel.answer("fire_hands"))
	assert_eq(stage.porter().call(&"current_canonical_animation"), &"hit")
	opening.host().close()
	opening.free()


## R-1389 (ADR 0038): the duel strips the hall to the spirit disc; Kalev's scene gets it back.
func test_the_duel_is_fought_on_the_spirit_disc_in_the_stripped_hall() -> void:
	var opening := _opening()
	var stage := opening.get_node(^"Stage") as AlmshouseStage
	var back_wall := stage.get_node(^"BackWall") as Node3D
	assert_true(opening.begin_duel())
	var host := opening.host()
	assert_true(host.arena_3d != null and host.arena_3d.indoors, "an indoor arena is mounted")
	assert_eq(host.arena_3d.radius, AlmshouseStage.ARENA_RADIUS)
	assert_true(host.motion != null and not host.freeze_world, "the duel runs in real time")
	assert_false(back_wall.visible, "walls are stripped")
	assert_false((stage.get_node(^"Table") as Node3D).visible, "furniture is stripped")
	assert_true(stage.hero().visible and stage.porter().visible, "the duellists stay")
	assert_true((stage.get_node(^"HearthLight") as Node3D).visible, "the stage lights stay")
	stage.move_hero(Vector2(1.0, 0.0), false, 0.5)
	host.close()
	assert_true(back_wall.visible, "the hall is back for Kalev")
	assert_true(stage.hero().position.is_equal_approx(Vector3(-AlmshouseStage.DUEL_HALF_GAP, 0, 0)))
	assert_true(stage.kalev() != null)
	opening.free()


## R-1389: the porter's rig turns to face the boy (glTF rigs face +Z), not away from him.
func test_the_porter_faces_the_boy_while_he_moves_in_the_arena() -> void:
	var opening := _opening()
	var stage := opening.get_node(^"Stage") as AlmshouseStage
	assert_true(opening.begin_duel())
	var host := opening.host()
	host.duel.tick(SpiritDuel.TELEGRAPH_SEC + 0.01)
	stage.move_hero(Vector2(0.0, 1.0), false, 0.5)
	host._process(0.2)
	var to_hero := stage.hero().global_position - stage.porter().global_position
	to_hero.y = 0.0
	assert_true(stage.porter().global_basis.z.dot(to_hero.normalized()) > 0.9, "porter faces the boy")
	host.close()
	opening.free()


## R-1389: the boy walks, squares up to the porter when still, dashes sideways and never leaves
## the disc.
func test_the_boy_walks_dashes_and_stays_on_the_disc() -> void:
	var opening := _opening()
	var stage := opening.get_node(^"Stage") as AlmshouseStage
	assert_true(opening.begin_duel())
	var host := opening.host()
	var start := stage.hero().position
	stage.move_hero(Vector2(0.0, -1.0), false, 0.5)
	assert_true(stage.hero().position.z < start.z - 1.0, "up on screen walks into the hall")
	stage.move_hero(Vector2.ZERO, false, 0.1)
	var to_porter := (stage.porter().position - stage.hero().position)
	to_porter.y = 0.0
	assert_true(stage.hero().global_basis.z.dot(to_porter.normalized()) > 0.9, "squares up")
	host._process(0.0)
	assert_true(host.motion.guard_facing(), "a raised guard now faces the porter")
	var before := stage.hero().position
	stage.dash_hero(Vector2.ZERO)
	stage.move_hero(Vector2.ZERO, false, AlmshouseStage.HERO_DASH_SEC)
	assert_true(stage.hero().position.distance_to(before) > 1.5, "the dash covers ground")
	stage.move_hero(Vector2(-1.0, 0.0), false, 20.0)
	host._process(0.0)
	assert_true(host.arena_3d.contains(stage.hero().position), "clamped to the disc")
	host.close()
	opening.free()
