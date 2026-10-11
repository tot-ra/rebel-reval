extends "res://tests/godot/test_case.gd"

const DEATH_SCREEN_SCENE := preload("res://scenes/death/death_screen.tscn")
const DEATH_SCREEN_SCRIPT := preload("res://scenes/death/death_screen.gd")
const PLAYER_SCENE := preload("res://player.tscn")
const ILLUSTRATION_ROOT := "Center/Panel/Content/FatalHitIllustrations"


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


func test_death_screen_uses_ten_second_return_delay() -> void:
	assert_eq(DEATH_SCREEN_SCRIPT.RETURN_DELAY_SEC, 10.0)
	var screen := DEATH_SCREEN_SCENE.instantiate() as Control
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(screen)
	assert_eq(screen._remaining_sec, 10.0)
	screen.free()


func test_player_records_fatal_damage_type_as_transient_context() -> void:
	SessionState.consume_fatal_hit_damage_type()
	var player := PLAYER_SCENE.instantiate() as Player
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(player)
	assert_eq(player.take_damage(100.0, null, &"pierce"), 100.0)
	assert_eq(SessionState.consume_fatal_hit_damage_type(), &"pierce")
	player.free()


func test_death_screen_selects_supported_illustrations_and_clears_context() -> void:
	for damage_type in [&"slash", &"blunt", &"pierce"]:
		var screen := _spawn_death_screen(damage_type)
		_assert_only_illustration_visible(screen, damage_type)
		assert_eq(SessionState.consume_fatal_hit_damage_type(), &"")
		screen.free()


func test_death_screen_uses_neutral_for_missing_or_unknown_context() -> void:
	for damage_type in [&"", &"magic"]:
		var screen := _spawn_death_screen(damage_type)
		_assert_only_illustration_visible(screen, &"neutral")
		assert_eq(SessionState.consume_fatal_hit_damage_type(), &"")
		screen.free()


func test_release_player_death_route_is_not_enabled_in_test_hosts() -> void:
	var player := PLAYER_SCENE.instantiate() as Player
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(player)
	assert_false(player._should_show_death_screen())
	player.free()


func _spawn_death_screen(damage_type: StringName) -> Control:
	SessionState.set_fatal_hit_damage_type(damage_type)
	var screen := DEATH_SCREEN_SCENE.instantiate() as Control
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(screen)
	return screen


func _assert_only_illustration_visible(screen: Control, selected: StringName) -> void:
	for illustration_key in [&"slash", &"blunt", &"pierce", &"neutral"]:
		var illustration_name := String(illustration_key).capitalize()
		var illustration := screen.get_node(
			"%s/%s" % [ILLUSTRATION_ROOT, illustration_name]
		) as TextureRect
		assert_eq(illustration.visible, illustration_key == selected, "Unexpected death illustration")
