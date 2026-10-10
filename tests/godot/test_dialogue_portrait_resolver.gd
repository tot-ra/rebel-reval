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


func test_missing_ids_return_null() -> void:
	assert_true(ResolverScript.resolve_texture(&"") == null, "empty id")
	assert_true(ResolverScript.resolve_texture(&"char.no_such_person") == null, "unknown char")
	assert_true(ResolverScript.resolve_texture(&"quest.x") == null, "non-char id")
	assert_eq(ResolverScript.portrait_path(&"char."), "")
