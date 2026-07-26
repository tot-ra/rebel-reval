class_name FactionLedger
extends RefCounted

## Eight active campaign factions from README / ADR 0008. Standing is derived only
## from explicit recorded ledger events, never from an aggregate morality meter.

const STANDING_MIN := -3
const STANDING_MAX := 3

const DANISH_CROWN := &"danish_crown"
const LIVONIAN_ORDER := &"livonian_order"
const HANSEATIC := &"hanseatic"
const HARJU_KINGS := &"harju_kings"
const BLACK_CLOAKS := &"black_cloaks"
const CULT_METSIK := &"cult_metsik"
const PSKOV_NOVGOROD := &"pskov_novgorod"
const VITALIENBRUDER := &"vitalienbruder"

const ACTIVE_FACTIONS: Array[StringName] = [
	DANISH_CROWN,
	LIVONIAN_ORDER,
	HANSEATIC,
	HARJU_KINGS,
	BLACK_CLOAKS,
	CULT_METSIK,
	PSKOV_NOVGOROD,
	VITALIENBRUDER,
]

const DISPLAY_NAMES: Dictionary = {
	DANISH_CROWN: "Danish Crown",
	LIVONIAN_ORDER: "Livonian Order",
	HANSEATIC: "Hanseatic guilds",
	HARJU_KINGS: "Harju Kings",
	BLACK_CLOAKS: "Black Cloaks",
	CULT_METSIK: "Cult of Metsik",
	PSKOV_NOVGOROD: "Pskov and Novgorod",
	VITALIENBRUDER: "Vitalienbrüder",
}

const STANDING_LABELS: Dictionary = {
	-3: "Hostile",
	-2: "Wary",
	-1: "Cool",
	0: "Neutral",
	1: "Cordial",
	2: "Trusted",
	3: "Ally",
}


static func is_active_faction(faction_id: StringName) -> bool:
	return ACTIVE_FACTIONS.has(faction_id)


static func faction_id_from_key(key: StringName) -> StringName:
	var raw := String(key)
	if not raw.begins_with("faction."):
		return &""
	return StringName(raw.substr("faction.".length()))


static func standing_label(value: int) -> String:
	return String(STANDING_LABELS.get(clampi(value, STANDING_MIN, STANDING_MAX), "Neutral"))


static func display_name(faction_id: StringName) -> String:
	return String(DISPLAY_NAMES.get(faction_id, faction_id))
