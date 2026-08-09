extends "res://tests/godot/test_case.gd"

const DEATH_SCREEN_SCENE := preload("res://scenes/death/death_screen.tscn")
const DEATH_SCREEN_SCRIPT := preload("res://scenes/death/death_screen.gd")
const PLAYER_SCENE := preload("res://player.tscn")


func test_death_screen_presents_epilogue_and_menu_return() -> void:
	var screen := DEATH_SCREEN_SCENE.instantiate() as Control
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(screen)
	assert_true(screen.get_node_or_null("Center/Panel/Content/Title") != null)
	assert_eq(
		screen.get_node("Center/Panel/Content/Title").text,
		"KALEV HAS FALLEN"
	)
	assert_eq(
		screen.get_node("Center/Panel/Content/ReturnButton").text,
		"Return to Main Menu"
	)
	assert_eq(DEATH_SCREEN_SCRIPT.MAIN_MENU_PATH, "res://scenes/menu/main_menu.tscn")
	screen.free()


func test_release_player_death_route_is_not_enabled_in_test_hosts() -> void:
	var player := PLAYER_SCENE.instantiate() as Player
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(player)
	assert_false(player._should_show_death_screen())
	player.free()
