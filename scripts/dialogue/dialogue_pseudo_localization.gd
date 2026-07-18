class_name DialoguePseudoLocalization
extends RefCounted

## Expands authored strings for layout stress testing before real translations (P1-014).
## Accents vowels, pads length, and wraps in brackets so clipped or untranslated UI is obvious.

const EXPANSION_RATIO := 1.35

const VOWEL_REPLACEMENTS := {
	"a": "ä",
	"A": "Ä",
	"e": "ë",
	"E": "Ë",
	"i": "ï",
	"I": "Ï",
	"o": "ö",
	"O": "Ö",
	"u": "ü",
	"U": "Ü",
}


static func expand(source: String) -> String:
	if source.is_empty():
		return source

	var accented := _accent_vowels(source)
	var expanded := "[%s]" % accented
	var target_length := maxi(
		expanded.length(),
		int(ceil(float(source.length()) * EXPANSION_RATIO)) + 2
	)
	while expanded.length() < target_length:
		expanded = expanded.insert(expanded.length() - 1, "~")
	return expanded


static func expand_choice(source: String) -> String:
	return expand(source)


static func expand_speaker_name(source: String) -> String:
	if source.is_empty():
		return source
	return expand(source)


static func _accent_vowels(source: String) -> String:
	var output := ""
	for index in range(source.length()):
		var character := source[index]
		output += String(VOWEL_REPLACEMENTS.get(character, character))
	return output
