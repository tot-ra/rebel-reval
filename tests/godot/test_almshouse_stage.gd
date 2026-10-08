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
