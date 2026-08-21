class_name JurisdictionModel
extends RefCounted

## Stable jurisdiction vocabulary for the 1343 Domberg / All-linn boundary.
## WHY: the inactive Toompea prototype still needs one deterministic contract for
## editor/runtime inspection without activating the map or duplicating map data.

const MapTypesScript := preload("res://scripts/map/map_types.gd")

const JURISDICTION_TOOMPEA_DANISH := MapTypesScript.JURISDICTION_TOOMPEA_DANISH
const JURISDICTION_ALL_LINN_LUBECK := MapTypesScript.JURISDICTION_ALL_LINN_LUBECK
const JURISDICTIONS: Array[StringName] = [
	JURISDICTION_TOOMPEA_DANISH,
	JURISDICTION_ALL_LINN_LUBECK,
]

const TOOMPEA_MAP_ID := &"toompea_quarter"
const TOOMPEA_LOCATION_ID := &"loc.toompea.quarter"

const TRANSITION_LUHIKE_JALG := &"to_reval_center"
const TRANSITION_PIKK_JALG := &"to_reval_north"
const TOOMPEA_TRANSITION_IDS: Array[StringName] = [
	TRANSITION_LUHIKE_JALG,
	TRANSITION_PIKK_JALG,
]


static func is_known(value: StringName) -> bool:
	return value in JURISDICTIONS


static func jurisdiction_for_map(map_id: StringName) -> StringName:
	if map_id == TOOMPEA_MAP_ID:
		return JURISDICTION_TOOMPEA_DANISH
	return &""


static func transition_contracts() -> Array[Dictionary]:
	return [
		{
			"transition_id": TRANSITION_LUHIKE_JALG,
			"gate_id": &"luhike_jalg",
			"from_jurisdiction": JURISDICTION_TOOMPEA_DANISH,
			"to_jurisdiction": JURISDICTION_ALL_LINN_LUBECK,
		},
		{
			"transition_id": TRANSITION_PIKK_JALG,
			"gate_id": &"pikk_jalg",
			"from_jurisdiction": JURISDICTION_TOOMPEA_DANISH,
			"to_jurisdiction": JURISDICTION_ALL_LINN_LUBECK,
		},
	]


static func contract_for_transition(transition_id: StringName) -> Dictionary:
	for contract in transition_contracts():
		if contract["transition_id"] == transition_id:
			return contract.duplicate(true)
	return {}


## This snapshot is intentionally developer-facing. It lets inactive-map tools
## show the jurisdiction boundary without making a prototype transition usable.
static func developer_snapshot(map_id: StringName, active: bool = false) -> Dictionary:
	return {
		"map_id": map_id,
		"active": active,
		"jurisdiction": jurisdiction_for_map(map_id),
		"transitions": transition_contracts() if map_id == TOOMPEA_MAP_ID else [],
	}
