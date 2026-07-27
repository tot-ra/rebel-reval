class_name Act1AftermathModel
extends RefCounted

## Aggregates Act 1 character, forge, and district aftermath into one save envelope
## when `flag.act_transition.act1_recorded` is written at St. George's Night (P4-009).
## WHY: Act 2 opening state must read a validated snapshot instead of re-deriving
## every quest flag at migration time.

const MANIFEST_PATH := "res://docs/data/act1_aftermath_manifest.json"
const FLAG_RECORDED := &"flag.act_transition.act1_recorded"
const ENVELOPE_VERSION := 1

const BitterBrewModel := preload("res://scripts/investigation/bitter_brew_aftermath_model.gd")
const PriceOfANameModel := preload(
	"res://scripts/investigation/price_of_a_name_aftermath_model.gd"
)
const BreadAndIronModel := preload("res://scripts/investigation/bread_and_iron_aftermath_model.gd")
const BellAndChainModel := preload("res://scripts/investigation/bell_and_chain_aftermath_model.gd")
const RootAndEmberModel := preload("res://scripts/investigation/root_and_ember_aftermath_model.gd")
const ReflectionModel := preload("res://scripts/reflection/reflection_model.gd")
const DistrictPressureModel := preload("res://scripts/faction/district_pressure_model.gd")

const FLAG_BOUNDARY_SEAL := &"flag.act_boundary.viru_seal"
const FLAG_BOUNDARY_BREAK := &"flag.act_boundary.viru_break"
const FLAG_BOUNDARY_OPEN := &"flag.act_boundary.viru_open"

const CHAR_MART := "mart"
const CHAR_AITA := "aita"
const CHAR_KAJA := "kaja"
const CHAR_HENNING := "henning"
const CHAR_JURGEN := "jurgen"
const CHAR_ELLEN := "ellen"

const FLAG_LEDGER_PRESERVED := &"flag.forge_ledger_preserved"
const FLAG_LEDGER_ALTERED := &"flag.forge_ledger_altered"
const FLAG_LEDGER_DESTROYED := &"flag.forge_ledger_destroyed"

const CORE_CHARACTERS: Array[String] = [
	CHAR_MART,
	CHAR_AITA,
	CHAR_KAJA,
	CHAR_HENNING,
	CHAR_JURGEN,
	CHAR_ELLEN,
]

const ACTIVE_DISTRICTS: Array[StringName] = [
	DistrictPressureModel.DISTRICT_LOWER_TOWN,
	DistrictPressureModel.DISTRICT_NORTH_MERCHANT,
]

const FORBIDDEN_ENVELOPE_KEYS: Array[String] = [
	"morality",
	"alignment",
	"karma",
	"virtue",
	"sin",
	"good_evil",
]

const MART_STATES: Array[String] = [
	"respectful",
	"emboldened_escape",
	"emboldened_contract",
	"name_protected",
	"name_cleared",
	"name_redirected",
	"watchful",
]

const AITA_STATES: Array[String] = [
	"at_brewery",
	"at_contract_brewery",
	"absent_confiscated",
	"unknown",
]

const KAJA_STATES: Array[String] = [
	"clerk_ally",
	"plate_conspirator",
	"merchant_neutral",
]

const HENNING_STATES: Array[String] = [
	"trusting_officer",
	"pragmatic_officer",
	"suspicious_officer",
	"neutral_officer",
]

const JURGEN_STATES: Array[String] = [
	"contract_broker",
	"marginal_trader",
]

const ELLEN_STATES: Array[String] = [
	"belief_honored",
	"remedy_trusted",
	"skepticism_respected",
	"unmet",
]

const ACT_BOUNDARY_STATES: Array[String] = ["seal", "break", "open"]

const LEDGER_STATES: Array[String] = ["preserved", "altered", "destroyed", "unset"]
const CONVICTION_STATES: Array[String] = ["duty", "fury", "mercy", "unset"]


static func load_manifest() -> Dictionary:
	var source := FileAccess.get_file_as_string(MANIFEST_PATH)
	if source.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(source)
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}


static func build_envelope(state: GameState) -> Dictionary:
	return {
		"version": ENVELOPE_VERSION,
		"recorded_at_phase": String(state.get_phase()),
		"act_boundary": String(_resolve_act_boundary(state)),
		"characters": {
			CHAR_MART: _resolve_mart(state),
			CHAR_AITA: _resolve_aita(state),
			CHAR_KAJA: _resolve_kaja(state),
			CHAR_HENNING: _resolve_henning(state),
			CHAR_JURGEN: _resolve_jurgen(state),
			CHAR_ELLEN: _resolve_ellen(state),
		},
		"forge": _resolve_forge(state),
		"districts": _resolve_districts(state),
	}


static func record_transition(state: GameState) -> bool:
	if state == null or not state.get_flag(FLAG_RECORDED):
		return false
	var envelope := build_envelope(state)
	var validation := validate_envelope(envelope)
	if not validation["valid"]:
		return false
	state.set_act1_transition(envelope)
	return true


static func validate_envelope(envelope: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	if envelope.is_empty():
		errors.append("envelope is empty")
		return {"valid": false, "errors": errors}

	for forbidden_key in FORBIDDEN_ENVELOPE_KEYS:
		if envelope.has(forbidden_key):
			errors.append("forbidden aggregate key %s" % forbidden_key)
		_collect_forbidden_keys(envelope, forbidden_key, "", errors)

	if int(envelope.get("version", 0)) != ENVELOPE_VERSION:
		errors.append("unsupported envelope version")

	var boundary := String(envelope.get("act_boundary", ""))
	if boundary.is_empty() or not boundary in ACT_BOUNDARY_STATES:
		errors.append("missing or invalid act_boundary")

	var characters: Variant = envelope.get("characters", {})
	if not characters is Dictionary:
		errors.append("characters must be a dictionary")
	else:
		for character_id in CORE_CHARACTERS:
			if not (characters as Dictionary).has(character_id):
				errors.append("missing character %s" % character_id)
				continue
			_assert_allowed(
				String((characters as Dictionary)[character_id]),
				_allowed_states_for_character(character_id),
				"characters.%s" % character_id,
				errors
			)

	var forge: Variant = envelope.get("forge", {})
	if not forge is Dictionary:
		errors.append("forge must be a dictionary")
	else:
		_assert_allowed(
			String((forge as Dictionary).get("ledger", "")),
			LEDGER_STATES,
			"forge.ledger",
			errors
		)
		_assert_allowed(
			String((forge as Dictionary).get("conviction", "")),
			CONVICTION_STATES,
			"forge.conviction",
			errors
		)

	var districts: Variant = envelope.get("districts", {})
	if not districts is Dictionary:
		errors.append("districts must be a dictionary")
	else:
		for district_id in ACTIVE_DISTRICTS:
			var key := String(district_id)
			if not (districts as Dictionary).has(key):
				errors.append("missing district %s" % key)
				continue
			var district_row: Variant = (districts as Dictionary)[key]
			if not district_row is Dictionary:
				errors.append("district %s must be a dictionary" % key)
				continue
			if String((district_row as Dictionary).get("price_tier", "")).is_empty():
				errors.append("district %s missing price_tier" % key)

	errors.append_array(_validate_mutual_exclusion(envelope))
	return {
		"valid": errors.is_empty(),
		"errors": errors,
	}


static func validate_manifest() -> Dictionary:
	var manifest := load_manifest()
	var errors: Array[String] = []
	if manifest.is_empty():
		errors.append("manifest missing or invalid")
		return {"valid": false, "errors": errors}
	if String(manifest.get("task_id", "")) != "P4-009":
		errors.append("unexpected task_id")
	if String(manifest.get("godot_model", "")) != "scripts/quest/act1_aftermath_model.gd":
		errors.append("godot_model drift")
	var characters: Variant = manifest.get("core_characters", [])
	if not characters is Array or (characters as Array).size() != CORE_CHARACTERS.size():
		errors.append("core_characters drift")
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"scenario_count": int(manifest.get("scenario_count", 0)),
	}


static func _resolve_act_boundary(state: GameState) -> StringName:
	if state.get_flag(FLAG_BOUNDARY_SEAL):
		return &"seal"
	if state.get_flag(FLAG_BOUNDARY_BREAK):
		return &"break"
	if state.get_flag(FLAG_BOUNDARY_OPEN):
		return &"open"
	return &""


static func _resolve_mart(state: GameState) -> String:
	var bitter := BitterBrewModel.resolve_outcome(state)
	if bitter == BitterBrewModel.OUTCOME_MONOPOLIZED:
		return "emboldened_contract"
	if bitter == BitterBrewModel.OUTCOME_ESCAPED:
		return "emboldened_escape"
	if bitter == BitterBrewModel.OUTCOME_EXONERATED:
		return "respectful"
	match String(PriceOfANameModel.resolve_outcome(state)):
		PriceOfANameModel.OUTCOME_CONCEALED:
			return "name_protected"
		PriceOfANameModel.OUTCOME_CLEARED:
			return "name_cleared"
		PriceOfANameModel.OUTCOME_REDIRECTED:
			return "name_redirected"
		_:
			return "watchful"


static func _resolve_aita(state: GameState) -> String:
	match String(BitterBrewModel.resolve_outcome(state)):
		BitterBrewModel.OUTCOME_EXONERATED:
			return "at_brewery"
		BitterBrewModel.OUTCOME_MONOPOLIZED:
			return "at_contract_brewery"
		BitterBrewModel.OUTCOME_ESCAPED:
			return "absent_confiscated"
		_:
			return "unknown"


static func _resolve_kaja(state: GameState) -> String:
	match String(PriceOfANameModel.resolve_outcome(state)):
		PriceOfANameModel.OUTCOME_REDIRECTED:
			return "clerk_ally"
		PriceOfANameModel.OUTCOME_CONCEALED:
			return "plate_conspirator"
		_:
			return "merchant_neutral"


static func _resolve_henning(state: GameState) -> String:
	if state.get_flag(FLAG_LEDGER_DESTROYED):
		return "suspicious_officer"
	if state.get_flag(FLAG_LEDGER_ALTERED):
		return "pragmatic_officer"
	if state.get_flag(FLAG_LEDGER_PRESERVED):
		return "trusting_officer"
	return "neutral_officer"


static func _resolve_jurgen(state: GameState) -> String:
	if BitterBrewModel.resolve_outcome(state) == BitterBrewModel.OUTCOME_MONOPOLIZED:
		return "contract_broker"
	if BreadAndIronModel.resolve_outcome(state) == BreadAndIronModel.OUTCOME_DEBT:
		return "contract_broker"
	return "marginal_trader"


static func _resolve_ellen(state: GameState) -> String:
	match String(RootAndEmberModel.resolve_outcome(state)):
		RootAndEmberModel.OUTCOME_EMBER:
			return "belief_honored"
		RootAndEmberModel.OUTCOME_ROOT:
			return "remedy_trusted"
		RootAndEmberModel.OUTCOME_IRON:
			return "skepticism_respected"
		_:
			return "unmet"


static func _resolve_forge(state: GameState) -> Dictionary:
	var ledger := "unset"
	if state.get_flag(FLAG_LEDGER_PRESERVED):
		ledger = "preserved"
	elif state.get_flag(FLAG_LEDGER_ALTERED):
		ledger = "altered"
	elif state.get_flag(FLAG_LEDGER_DESTROYED):
		ledger = "destroyed"

	var conviction := "unset"
	if state.get_flag(ReflectionModel.FLAG_DUTY):
		conviction = "duty"
	elif state.get_flag(ReflectionModel.FLAG_FURY):
		conviction = "fury"
	elif state.get_flag(ReflectionModel.FLAG_MERCY):
		conviction = "mercy"

	return {
		"ledger": ledger,
		"conviction": conviction,
		"technique": String(state.equipped_forge_technique()),
		"suspicion": state.get_pressure(GameState.PRESSURE_SUSPICION),
		"solidarity": state.get_pressure(GameState.PRESSURE_SOLIDARITY),
		"scarcity": state.get_pressure(GameState.PRESSURE_SCARCITY),
		"bell_and_chain": String(BellAndChainModel.resolve_outcome(state)),
		"bread_and_iron": String(BreadAndIronModel.resolve_outcome(state)),
	}


static func _resolve_districts(state: GameState) -> Dictionary:
	var out: Dictionary = {}
	for district_id in ACTIVE_DISTRICTS:
		var snapshot := DistrictPressureModel.resolve(district_id, state)
		out[String(district_id)] = {
			"price_tier": String(snapshot.get("tier_name", "")),
			"patrol_speed_scale": float(snapshot.get("patrol_speed_scale", 1.0)),
		}
	return out


static func _allowed_states_for_character(character_id: String) -> Array:
	match character_id:
		CHAR_MART:
			return MART_STATES
		CHAR_AITA:
			return AITA_STATES
		CHAR_KAJA:
			return KAJA_STATES
		CHAR_HENNING:
			return HENNING_STATES
		CHAR_JURGEN:
			return JURGEN_STATES
		CHAR_ELLEN:
			return ELLEN_STATES
		_:
			return []


static func _validate_mutual_exclusion(envelope: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var boundary_flags := 0
	for boundary in ACT_BOUNDARY_STATES:
		if String(envelope.get("act_boundary", "")) == boundary:
			boundary_flags += 1
	if boundary_flags != 1:
		errors.append("act_boundary must resolve to exactly one family")

	var characters: Dictionary = envelope.get("characters", {}) as Dictionary
	var mart := String(characters.get(CHAR_MART, ""))
	if mart == "name_protected" and String(characters.get(CHAR_KAJA, "")) != "plate_conspirator":
		errors.append("mart.name_protected requires kaja.plate_conspirator")
	if mart == "name_redirected" and String(characters.get(CHAR_KAJA, "")) != "clerk_ally":
		errors.append("mart.name_redirected requires kaja.clerk_ally")
	return errors


static func _assert_allowed(
	value: String,
	allowed: Array,
	label: String,
	errors: Array[String]
) -> void:
	if value.is_empty() or not value in allowed:
		errors.append("%s has invalid value %s" % [label, value])


static func _collect_forbidden_keys(
	value: Variant,
	forbidden_key: String,
	path: String,
	errors: Array[String]
) -> void:
	if value is Dictionary:
		for key in (value as Dictionary).keys():
			var child_path := "%s.%s" % [path, String(key)] if not path.is_empty() else String(key)
			if String(key) == forbidden_key:
				errors.append("forbidden aggregate key at %s" % child_path)
			_collect_forbidden_keys((value as Dictionary)[key], forbidden_key, child_path, errors)
