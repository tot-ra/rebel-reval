class_name FactionCandidateSeats
extends RefCounted

## Candidate faction seats that may receive ledger events/IDs without joining
## the README / ADR 0008 launch-eight ACTIVE_FACTIONS table.
## WHY: P4-045 ships Blackheads as events-only so quest content can name
## `faction.blackheads` without promoting a ninth launch faction by accident.
## Lizard Union stays intrigue-cell-only and must never appear here.

const BLACKHEADS := &"blackheads"

const CANDIDATE_FACTIONS: Array[StringName] = [
	BLACKHEADS,
]

const DISPLAY_NAMES: Dictionary = {
	BLACKHEADS: "Brotherhood of Blackheads",
}

## Faces that may write Blackheads candidate ledger events (content-ID stubs).
const BLACKHEADS_FACE_IDS: Array[StringName] = [
	&"char.johann_von_minden",
	&"char.hinrik_cartographer",
	&"char.mart_weaver",
]

## Explicitly rejected ledger IDs - intrigue cells, not candidate seats.
const REJECTED_LEDGER_IDS: Array[StringName] = [
	&"lizard_union",
	&"lizard",
]


static func is_candidate_faction(faction_id: StringName) -> bool:
	return CANDIDATE_FACTIONS.has(faction_id)


static func is_rejected_ledger_id(faction_id: StringName) -> bool:
	return REJECTED_LEDGER_IDS.has(faction_id)


## Launch-eight active seats plus approved candidate seats may record events.
static func is_recordable_faction(faction_id: StringName) -> bool:
	if is_rejected_ledger_id(faction_id):
		return false
	return FactionLedger.is_active_faction(faction_id) or is_candidate_faction(faction_id)


static func display_name(faction_id: StringName) -> String:
	if DISPLAY_NAMES.has(faction_id):
		return String(DISPLAY_NAMES[faction_id])
	return FactionLedger.display_name(faction_id)
