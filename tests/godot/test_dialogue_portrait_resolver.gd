extends "res://tests/godot/test_case.gd"

const ResolverScript := preload("res://scripts/dialogue/dialogue_portrait_resolver.gd")


func test_core_cast_keeps_known_portrait() -> void:
	var expected := "res://assets/characters/portraits/mart.png"
	assert_eq(ResolverScript.portrait_path(&"char.mart"), expected)
	assert_true(ResolverScript.resolve_texture(&"char.mart") != null, "core portrait loads")


func test_named_npc_resolves_registry_portrait_field() -> void:
	# Registry id char.order_squire intentionally maps to the shorter squire.png stem.
	var expected := "res://assets/characters/portraits/npc/squire.png"
	assert_eq(ResolverScript.portrait_path(&"char.order_squire"), expected)
	assert_true(
		ResolverScript.resolve_texture(&"char.order_squire") != null, "registry portrait loads"
	)


func test_registry_portrait_field_wins_over_slug_convention() -> void:
	# Registry id does not match the jpg stem: char.martin_cloaks -> martin.png.
	var expected := "res://assets/characters/portraits/npc/martin.png"
	assert_eq(ResolverScript.portrait_path(&"char.martin_cloaks"), expected)
	assert_true(
		ResolverScript.resolve_texture(&"char.martin_cloaks") != null, "registry portrait loads"
	)


func test_registry_npc_without_portrait_returns_null() -> void:
	# char.ironhand has portrait null and no file in the registry.
	assert_eq(ResolverScript.portrait_path(&"char.ironhand"), "")
	assert_true(ResolverScript.resolve_texture(&"char.ironhand") == null, "no portrait yet")


func test_unregistered_npc_does_not_fall_back_to_slug_convention() -> void:
	# The imported squire.png is not enough to grant a portrait to char.squire.
	assert_eq(ResolverScript.portrait_path(&"char.squire"), "")
	assert_true(
		ResolverScript.resolve_texture(&"char.squire") == null,
		"unregistered speakers have no portrait"
	)


func test_missing_ids_return_null() -> void:
	assert_true(ResolverScript.resolve_texture(&"") == null, "empty id")
	assert_true(ResolverScript.resolve_texture(&"char.no_such_person") == null, "unknown char")
	assert_true(ResolverScript.resolve_texture(&"quest.x") == null, "non-char id")
	assert_eq(ResolverScript.portrait_path(&"char."), "")
