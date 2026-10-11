class_name EncounterOutcome
extends RefCounted

## Authored non-lethal and lethal encounter close kinds (P1-026).
## Why: night missions and P2-009 need one shared vocabulary so combat and
## non-combat routes update the same quest state without forked outcome code.

const KIND_SURRENDER := &"surrender"
const KIND_ESCAPE := &"escape"
const KIND_BYPASS := &"bypass"
## Lethal close still goes through EncounterOutcomeResolver so quest writes share one API.
const KIND_KILL := &"kill"

const ALL_KINDS: Array[StringName] = [
	KIND_SURRENDER,
	KIND_ESCAPE,
	KIND_BYPASS,
	KIND_KILL,
]

const NON_LETHAL_KINDS: Array[StringName] = [
	KIND_SURRENDER,
	KIND_ESCAPE,
	KIND_BYPASS,
]


static func is_known(kind: StringName) -> bool:
	return kind in ALL_KINDS


static func is_non_lethal(kind: StringName) -> bool:
	return kind in NON_LETHAL_KINDS


static func display_name(kind: StringName) -> String:
	match kind:
		KIND_SURRENDER:
			return "surrender"
		KIND_ESCAPE:
			return "escape"
		KIND_BYPASS:
			return "bypass"
		KIND_KILL:
			return "kill"
		_:
			return "unknown"
