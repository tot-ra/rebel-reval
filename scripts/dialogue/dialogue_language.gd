class_name DialogueLanguage
extends RefCounted
## Language comprehension for dialogue (ADR 0033, SD-08). A node spoken in a language the
## hero barely knows reaches him as imagery, then fragments, then the real text. Estonian
## (the hero's own) is always understood. Readable text is never lost for good: the
## `always_translate` dialogue setting shows every line in full.

const GENERIC_IMAGERY := "[Words you cannot follow. A tone like a closing door.]"
const GISTLESS_FRAGMENTS := "[You catch a few words, but not the sense.]"
## Minimum tier at which a line is shown in full and its move stakes are readable.
const FULL_TIER := 2


static func is_foreign(node: Dictionary) -> bool:
	var language := StringName(String(node.get("language", "")))
	return language != &"" and language != GameState.LANGUAGE_NATIVE


## Tier the hero has in the node's language (3 when the node has no foreign language).
static func node_tier(node: Dictionary, state: GameState) -> int:
	if not is_foreign(node) or state == null:
		return 3
	return state.language_tier(StringName(String(node.get("language", ""))))


## Text the hero perceives for `text` of `node`.
static func render(node: Dictionary, text: String, state: GameState, always_translate: bool) -> String:
	if always_translate or node_tier(node, state) >= FULL_TIER:
		return text
	if node_tier(node, state) == 1:
		return String(node.get("gist", node.get("imagery", GISTLESS_FRAGMENTS)))
	return String(node.get("imagery", GENERIC_IMAGERY))


## Whether the stakes of the node's move can be read.
static func stakes_readable(node: Dictionary, state: GameState, always_translate: bool) -> bool:
	return always_translate or node_tier(node, state) >= FULL_TIER


## Choice gate: `comprehension: {language, min_tier}`. Returns "" when allowed, else a reason.
static func choice_block_reason(choice: Dictionary, state: GameState) -> String:
	var gate: Variant = choice.get("comprehension", {})
	if typeof(gate) != TYPE_DICTIONARY or (gate as Dictionary).is_empty() or state == null:
		return ""
	var language := StringName(String((gate as Dictionary).get("language", "")))
	if state.language_tier(language) >= int((gate as Dictionary).get("min_tier", 1)):
		return ""
	return "You do not understand enough of the language."
