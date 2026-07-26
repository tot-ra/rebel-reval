class_name FactionLedgerModel
extends RefCounted

## Builds player-facing faction ledger rows from explicit recorded events only.


static func build_snapshot(state: GameState) -> Dictionary:
	var factions: Array[Dictionary] = []
	if state == null:
		return {"factions": factions}

	for faction_id in FactionLedger.ACTIVE_FACTIONS:
		var standing := state.get_faction_standing(faction_id)
		var events := state.get_faction_events_for(faction_id)
		factions.append({
			"faction_id": faction_id,
			"display_name": FactionLedger.display_name(faction_id),
			"flag_emoji": FactionHeraldry.flag_emoji(faction_id),
			"standing": standing,
			"standing_label": FactionLedger.standing_label(standing),
			"events": events,
		})
	return {"factions": factions}
