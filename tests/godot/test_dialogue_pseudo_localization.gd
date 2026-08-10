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


func test_expand_choice_matches_base_expansion() -> void:
	var source := "Choose the safer route."
	assert_eq(
		PseudoLocalizationScript.expand_choice(source),
		PseudoLocalizationScript.expand(source)
	)


func test_expand_speaker_name_matches_base_expansion_and_preserves_empty() -> void:
	var source := "Mart"
	assert_eq(
		PseudoLocalizationScript.expand_speaker_name(source),
		PseudoLocalizationScript.expand(source)
	)
	assert_eq(PseudoLocalizationScript.expand_speaker_name(""), "")
