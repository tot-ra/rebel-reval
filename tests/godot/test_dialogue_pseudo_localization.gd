extends "res://tests/godot/test_case.gd"

const PseudoLocalizationScript := preload("res://scripts/dialogue/dialogue_pseudo_localization.gd")


func test_expand_wraps_and_lengthens_text() -> void:
	var source := "Mart saw the ledger."
	var expanded := PseudoLocalizationScript.expand(source)
	assert_true(expanded.begins_with("["))
	assert_true(expanded.ends_with("]"))
	assert_true(expanded.length() > source.length())


func test_expand_accents_vowels() -> void:
	var expanded := PseudoLocalizationScript.expand("aeiou AEIOU")
	assert_true(expanded.contains("ä"))
	assert_true(expanded.contains("ë"))
	assert_true(expanded.contains("ï"))
	assert_true(expanded.contains("ö"))
	assert_true(expanded.contains("ü"))


func test_expand_empty_string_is_unchanged() -> void:
	assert_eq(PseudoLocalizationScript.expand(""), "")
