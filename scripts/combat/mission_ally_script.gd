class_name MissionAllyScript
extends RefCounted

## Scripted allied NPC profile for mission encounters (P5-008).
## Allies apply authored support effects automatically; there is no party-control UI.

const ID_ALLY_HEALER := &"ally.healer"
const ID_ALLY_VANGUARD := &"ally.vanguard"

var id: StringName = ID_ALLY_HEALER
var display_label := "Allied Healer"
var support_radius: float = 160.0
var heal_interval_sec: float = 3.5
var heal_amount: float = 4.0


static func from_id(ally_id: StringName) -> MissionAllyScript:
	if ally_id == ID_ALLY_HEALER:
		return healer()
	if ally_id == ID_ALLY_VANGUARD:
		return vanguard()
	return healer()


static func healer() -> MissionAllyScript:
	var ally := MissionAllyScript.new()
	ally.id = ID_ALLY_HEALER
	ally.display_label = "Allied Healer"
	ally.support_radius = 160.0
	ally.heal_interval_sec = 3.5
	ally.heal_amount = 4.0
	return ally


static func vanguard() -> MissionAllyScript:
	var ally := MissionAllyScript.new()
	ally.id = ID_ALLY_VANGUARD
	ally.display_label = "Allied Vanguard"
	ally.support_radius = 120.0
	ally.heal_interval_sec = 5.0
	ally.heal_amount = 6.0
	return ally
