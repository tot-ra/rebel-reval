extends "res://tests/godot/test_case.gd"

const ResolverScript := preload("res://scripts/dialogue/dialogue_portrait_resolver.gd")


func test_core_cast_keeps_known_portrait() -> void:
	var expected := "res://assets/characters/portraits/mart.png"
	assert_eq(ResolverScript.portrait_path(&"char.mart"), expected)
	assert_true(ResolverScript.resolve_texture(&"char.mart") != null, "core portrait loads")


func test_named_npc_falls_back_to_npc_dir() -> void:
	var expected := "res://assets/characters/portraits/npc/squire.png"
	assert_eq(ResolverScript.portrait_path(&"char.squire"), expected)
	assert_true(ResolverScript.resolve_texture(&"char.squire") != null, "npc portrait loads")


func test_registry_portrait_field_wins_over_slug_convention() -> void:
	# Registry id does not match the jpg stem: char.martin_cloaks -> martin.png.
	var expected := "res://assets/characters/portraits/npc/martin.png"
	assert_eq(ResolverScript.portrait_path(&"char.martin_cloaks"), expected)
	assert_true(ResolverScript.resolve_texture(&"char.martin_cloaks") != null, "registry portrait loads")


func test_registry_npc_without_portrait_returns_null() -> void:
	# Registry row with portrait null and no matching png (Old Toomas).
	assert_true(ResolverScript.resolve_texture(&"char.old_toomas") == null, "no portrait yet")


func test_missing_ids_return_null() -> void:
	assert_true(ResolverScript.resolve_texture(&"") == null, "empty id")
	assert_true(ResolverScript.resolve_texture(&"char.no_such_person") == null, "unknown char")
	assert_true(ResolverScript.resolve_texture(&"quest.x") == null, "non-char id")
	assert_eq(ResolverScript.portrait_path(&"char."), "")
