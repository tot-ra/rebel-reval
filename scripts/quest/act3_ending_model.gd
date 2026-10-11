class_name Act3EndingModel
extends RefCounted

## Deterministic Act 3 terminal envelope for the 1346 sale of Estonia.
## WHY: ending review needs a complete, testable matrix before P6-004 can wire
## the authored campaign state into runtime saves. The envelope deliberately
## stores explicit epilogues instead of deriving a universal morality score.

const MANIFEST_PATH := "res://docs/data/act3_ending_manifest.json"
const ENVELOPE_VERSION := 1
const SALE_YEAR := 1346
const SALE_EVENT_ID := &"event.sale_estonia_1346"

const CHAR_KALEV := &"char.kalev"
const CHAR_MART := &"char.mart"
const CHAR_AITA := &"char.aita"
const CHAR_KAJA := &"char.kaja"
const CHAR_HENNING := &"char.henning"
const CHAR_JURGEN := &"char.jurgen"
const CHAR_ELLEN := &"char.ellen"

const CORE_CHARACTERS: Array[StringName] = [
	CHAR_KALEV,
	CHAR_MART,
	CHAR_AITA,
	CHAR_KAJA,
	CHAR_HENNING,
	CHAR_JURGEN,
	CHAR_ELLEN,
]

const ACTIVE_FACTIONS: Array[StringName] = FactionLedger.ACTIVE_FACTIONS
const ACTIVE_DISTRICTS: Array[StringName] = [
	DistrictPressureModel.DISTRICT_LOWER_TOWN,
	DistrictPressureModel.DISTRICT_NORTH_MERCHANT,
]

const CHOICE_REBUILD := &"choice.rebuild_with_the_city"
const CHOICE_SERVE_ORDER := &"choice.serve_the_new_order"
const CHOICE_HIDE_HAMMER := &"choice.hide_the_hammer"
const FINAL_CHOICES: Array[StringName] = [
	CHOICE_REBUILD,
	CHOICE_SERVE_ORDER,
	CHOICE_HIDE_HAMMER,
]

const FORBIDDEN_AGGREGATE_KEYS: Array[String] = [
	"morality",
	"alignment",
	"karma",
	"virtue",
	"sin",
	"good_evil",
	"morality_score",
]

const _MATRIX: Dictionary = {
	CHOICE_REBUILD: {
		"family": "family.rebuild",
		"forge": {
			"epilogue_id": "epilogue.forge.reopened",
			"summary": "Kalev keeps the forge open as a guarded civic workshop.",
		},
		"characters": {
			CHAR_KALEV: "Kalev reopens the forge for neighbours before the sale is sealed.",
			CHAR_MART: "Mart carries the maker's mark openly and keeps its promises alive.",
			CHAR_AITA: "Aita finds work and protection in the workshop's shared stores.",
			CHAR_KAJA: "Kaja turns the forge's supply lines into a discreet relief network.",
			CHAR_HENNING: "Henning records the workshop as a useful exception to occupation orders.",
			CHAR_JURGEN: "Jürgen loses exclusive leverage but keeps a fair contract with the ward.",
			CHAR_ELLEN: "Ellen tends a household fire that survives by mutual care.",
		},
		"factions": {
			FactionLedger.DANISH_CROWN: "The Crown records a city that still bargains collectively.",
			FactionLedger.LIVONIAN_ORDER: "The Order takes its claim but cannot erase the guild's witness.",
			FactionLedger.HANSEATIC: "The guilds preserve a narrow channel for local trade.",
			FactionLedger.HARJU_KINGS: "The kings' cause survives in the ward's shared stores.",
			FactionLedger.BLACK_CLOAKS: "The Black Cloaks keep a disciplined relief route.",
			FactionLedger.CULT_METSIK: "Metsik's keepers protect the city's remembered places.",
			FactionLedger.PSKOV_NOVGOROD: "Pskov's emissaries leave with a truthful account of Reval.",
			FactionLedger.VITALIENBRUDER: "The sea raiders find no single purse to control.",
		},
		"districts": {
			DistrictPressureModel.DISTRICT_LOWER_TOWN:
				"Lower Town repairs its lanes around the still-burning hearths.",
			DistrictPressureModel.DISTRICT_NORTH_MERCHANT:
				"The merchant quarter reopens under negotiated watch.",
		},
	},
	CHOICE_SERVE_ORDER: {
		"family": "family.occupation",
		"forge": {
			"epilogue_id": "epilogue.forge.commandeered",
			"summary": "The forge is commandeered and its work is counted for the new order.",
		},
		"characters": {
			CHAR_KALEV: "Kalev survives by signing the forge over and remembering every order.",
			CHAR_MART: "Mart becomes the quiet keeper of names the occupation would discard.",
			CHAR_AITA: "Aita receives rations through the workshop, at the price of silence.",
			CHAR_KAJA: "Kaja retreats from the streets and turns caution into a longer resistance.",
			CHAR_HENNING: "Henning gains authority while learning which commands he cannot soften.",
			CHAR_JURGEN: "Jürgen secures the supply contract and pays for it with public trust.",
			CHAR_ELLEN: "Ellen shelters the frightened in a house where every visitor is watched.",
		},
		"factions": {
			FactionLedger.DANISH_CROWN: "The Crown's sale is entered as a transfer of authority.",
			FactionLedger.LIVONIAN_ORDER: "The Order takes the forge ledger and sets its quotas.",
			FactionLedger.HANSEATIC: "The guilds keep trade moving under stricter seals.",
			FactionLedger.HARJU_KINGS: "The kings lose public ground but preserve hidden witnesses.",
			FactionLedger.BLACK_CLOAKS: "The Black Cloaks split between open defiance and survival.",
			FactionLedger.CULT_METSIK: "Metsik's keepers move their rites beyond the occupied lanes.",
			FactionLedger.PSKOV_NOVGOROD: "Pskov's emissaries mark Reval as a closed Danish bargain.",
			FactionLedger.VITALIENBRUDER: "The sea raiders profit from the new checkpoints.",
		},
		"districts": {
			DistrictPressureModel.DISTRICT_LOWER_TOWN:
				"Lower Town works under quotas, patrols, and a guarded hearth.",
			DistrictPressureModel.DISTRICT_NORTH_MERCHANT:
				"The merchant quarter prospers unevenly beneath occupation seals.",
		},
	},
	CHOICE_HIDE_HAMMER: {
		"family": "family.survival",
		"forge": {
			"epilogue_id": "epilogue.forge.buried",
			"summary": "Kalev buries the hammer and leaves a trail only trusted hands can read.",
		},
		"characters": {
			CHAR_KALEV: "Kalev hides the hammer so the craft can outlive the sale.",
			CHAR_MART: "Mart keeps the last honest mark folded into a private ledger.",
			CHAR_AITA: "Aita carries food between households that no longer trust public roads.",
			CHAR_KAJA: "Kaja preserves the cell by making every message look like ordinary trade.",
			CHAR_HENNING: "Henning leaves the watch with a record that names no single culprit.",
			CHAR_JURGEN: "Jürgen retreats behind cautious barter and waits for the next opening.",
			CHAR_ELLEN: "Ellen keeps the old songs and teaches them only to the ready.",
		},
		"factions": {
			FactionLedger.DANISH_CROWN: "The Crown receives the sale, but not the city's whole memory.",
			FactionLedger.LIVONIAN_ORDER: "The Order claims the streets while the decisive tools disappear.",
			FactionLedger.HANSEATIC: "The guilds turn ordinary manifests into a quiet refuge for goods.",
			FactionLedger.HARJU_KINGS: "The kings keep a scattered chain of people who can still act.",
			FactionLedger.BLACK_CLOAKS: "The Black Cloaks survive as cells rather than a public banner.",
			FactionLedger.CULT_METSIK: "Metsik's keepers preserve names and rites outside the ledgers.",
			FactionLedger.PSKOV_NOVGOROD: "Pskov's emissaries carry rumours of a resistance not yet ended.",
			FactionLedger.VITALIENBRUDER:
				"The sea raiders find the harbour profitable but politically empty.",
		},
		"districts": {
			DistrictPressureModel.DISTRICT_LOWER_TOWN:
				"Lower Town survives in guarded households and hidden workshops.",
			DistrictPressureModel.DISTRICT_NORTH_MERCHANT:
				"The merchant quarter closes its shutters and routes trust by hand.",
		},
	},
}


static func load_manifest() -> Dictionary:
	var source := FileAccess.get_file_as_string(MANIFEST_PATH)
	if source.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(source)
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}


static func build_ending(campaign: Dictionary) -> Dictionary:
	if campaign.is_empty():
		return {}
	return build_ending_for_choice(StringName(String(campaign.get("final_choice", ""))))


static func build_ending_for_choice(choice: StringName) -> Dictionary:
	var row := _MATRIX.get(choice, {}) as Dictionary
	if row.is_empty():
		return {}
	return {
		"version": ENVELOPE_VERSION,
		"sale_year": SALE_YEAR,
		"sale_event": String(SALE_EVENT_ID),
		"final_choice": String(choice),
		"ending_family": String(row.get("family", "")),
		"characters": _component_rows(
			row.get("characters", {}) as Dictionary, true, String(choice).replace("choice.", "")
		),
		"factions": _component_rows(
			row.get("factions", {}) as Dictionary, false, String(choice).replace("choice.", "")
		),
		"forge": _single_component(row.get("forge", {}) as Dictionary),
		"districts": _component_rows(
			row.get("districts", {}) as Dictionary, false, String(choice).replace("choice.", "")
		),
	}


static func validate_ending(envelope: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	_collect_forbidden_keys(envelope, "", errors)
	if int(envelope.get("version", 0)) != ENVELOPE_VERSION:
		errors.append("unsupported envelope version")
	if int(envelope.get("sale_year", 0)) != SALE_YEAR:
		errors.append("sale_year must be 1346")
	if String(envelope.get("sale_event", "")) != String(SALE_EVENT_ID):
		errors.append("sale_event must record event.sale_estonia_1346")

	var choice := StringName(String(envelope.get("final_choice", "")))
	var row := _MATRIX.get(choice, {}) as Dictionary
	if row.is_empty():
		errors.append("final_choice is not an authored terminal choice")
	else:
		if String(envelope.get("ending_family", "")) != String(row.get("family", "")):
			errors.append("ending_family does not match final_choice")
		_validate_component_group(
			envelope.get("characters", {}), row.get("characters", {}) as Dictionary,
			CORE_CHARACTERS, "characters", errors, true, String(choice).replace("choice.", "")
		)
		_validate_component_group(
			envelope.get("factions", {}), row.get("factions", {}) as Dictionary,
			ACTIVE_FACTIONS, "factions", errors, false, String(choice).replace("choice.", "")
		)
		_validate_component_group(
			envelope.get("districts", {}), row.get("districts", {}) as Dictionary,
			ACTIVE_DISTRICTS, "districts", errors, false, String(choice).replace("choice.", "")
		)
		_validate_single_component(
			envelope.get("forge", {}), row.get("forge", {}) as Dictionary, "forge", errors
		)
	return {"valid": errors.is_empty(), "errors": errors}


static func validate_matrix() -> Dictionary:
	var errors: Array[String] = []
	var families: Dictionary = {}
	for choice in FINAL_CHOICES:
		var envelope := build_ending_for_choice(choice)
		var result := validate_ending(envelope)
		if not bool(result.get("valid", false)):
			errors.append_array(result.get("errors", []))
		var family := String(envelope.get("ending_family", ""))
		if families.has(family):
			errors.append("duplicate ending family %s" % family)
		families[family] = choice
	if families.size() != FINAL_CHOICES.size():
		errors.append("ending matrix must have one family per final choice")
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"choice_count": FINAL_CHOICES.size(),
		"character_count": CORE_CHARACTERS.size(),
		"faction_count": ACTIVE_FACTIONS.size(),
		"district_count": ACTIVE_DISTRICTS.size(),
	}


static func validate_manifest() -> Dictionary:
	var manifest := load_manifest()
	var errors: Array[String] = []
	if manifest.is_empty():
		errors.append("manifest missing or invalid")
	else:
		if String(manifest.get("godot_model", "")) != "scripts/quest/act3_ending_model.gd":
			errors.append("godot_model drift")
		if int(manifest.get("sale_year", 0)) != SALE_YEAR:
			errors.append("sale_year drift")
		if int(manifest.get("choice_count", 0)) != FINAL_CHOICES.size():
			errors.append("choice_count drift")
		if int(manifest.get("core_character_count", 0)) != CORE_CHARACTERS.size():
			errors.append("core_character_count drift")
		if int(manifest.get("active_faction_count", 0)) != ACTIVE_FACTIONS.size():
			errors.append("active_faction_count drift")
	return {"valid": errors.is_empty(), "errors": errors}


static func _component_rows(
	source: Dictionary, character_rows: bool, choice_slug: String
) -> Dictionary:
	var rows: Dictionary = {}
	for key in source:
		var value := String(source[key])
		var prefix := "epilogue." if character_rows else "ending."
		rows[String(key)] = {
			"epilogue_id": "%s%s.%s%s" % [
				prefix, choice_slug, String(key).replace("char.", ""), _slug_suffix()
			],
			"summary": value,
		}
	return rows


static func _single_component(source: Dictionary) -> Dictionary:
	return {
		"epilogue_id": String(source.get("epilogue_id", "")),
		"summary": String(source.get("summary", "")),
	}


static func _slug_suffix() -> String:
	# The summary remains authored copy; the branch slug and character key form the stable id.
	return ".authored"


static func _validate_component_group(
	actual: Variant,
	expected: Dictionary,
	keys: Array[StringName],
	label: String,
	errors: Array[String],
	character_rows: bool,
	choice_slug: String
) -> void:
	if not actual is Dictionary:
		errors.append("%s must be a dictionary" % label)
		return
	var actual_dict := actual as Dictionary
	if actual_dict.size() != keys.size():
		errors.append("%s must contain exactly %d rows" % [label, keys.size()])
	for key in keys:
		var key_string := String(key)
		if not actual_dict.has(key_string):
			errors.append("missing %s.%s" % [label, key_string])
			continue
		var row: Variant = actual_dict[key_string]
		if not row is Dictionary:
			errors.append("%s.%s must be a dictionary" % [label, key_string])
			continue
		var expected_summary := String(expected.get(key, ""))
		var expected_prefix := "epilogue." if character_rows else "ending."
		var expected_id := "%s%s.%s%s" % [
				expected_prefix, choice_slug, key_string.replace("char.", ""), _slug_suffix()
		]
		var row_dict := row as Dictionary
		if String(row_dict.get("epilogue_id", "")) != expected_id:
			errors.append("%s.%s has an impossible epilogue id" % [label, key_string])
		if String(row_dict.get("summary", "")) != expected_summary:
			errors.append("%s.%s has an impossible authored summary" % [label, key_string])


static func _validate_single_component(
	actual: Variant, expected: Dictionary, label: String, errors: Array[String]
) -> void:
	if not actual is Dictionary:
		errors.append("%s must be a dictionary" % label)
		return
	var actual_dict := actual as Dictionary
	if String(actual_dict.get("epilogue_id", "")) != String(expected.get("epilogue_id", "")):
		errors.append("%s has an impossible epilogue id" % label)
	if String(actual_dict.get("summary", "")) != String(expected.get("summary", "")):
		errors.append("%s has an impossible authored summary" % label)


static func _collect_forbidden_keys(value: Variant, path: String, errors: Array[String]) -> void:
	if value is Dictionary:
		for key in (value as Dictionary).keys():
			var key_string := String(key)
			var child_path := "%s.%s" % [path, key_string] if not path.is_empty() else key_string
			if key_string.to_lower() in FORBIDDEN_AGGREGATE_KEYS:
				errors.append("forbidden aggregate key at %s" % child_path)
			_collect_forbidden_keys((value as Dictionary)[key], child_path, errors)
	elif value is Array:
		for index in (value as Array).size():
			_collect_forbidden_keys((value as Array)[index], "%s[%d]" % [path, index], errors)
