class_name SupplyChainModel
extends RefCounted

## Authored iron convoy route from the north quarter into Lower Town market.
## WHY: P4-033 makes district supply visible and lets players disrupt one route.

const PATROL_ID := &"iron_convoy"
const FLAG_DISRUPTED := &"flag.supply.iron_convoy_disrupted"
const FACT_OBSERVED := &"fact.supply.iron_convoy_observed"
const FACT_ARRIVED := &"fact.supply.iron_convoy_arrived"

const QUEST_ID := &"quest.iron_shipment"
const TRANSITION_DELIVERED := &"convoy_delivered"
const TRANSITION_DISRUPTED := &"supply_disrupted"

const CONVOY_INTERACTABLE_ID := &"interact.supply.iron_convoy"
const MERCHANT_INTERACTABLE_ID := &"interact.supply.iron_merchant"
const MERCHANT_ANCHOR_ID := &"mart_street"
const MERCHANT_DIALOGUE_ID := &"dialogue.merchant.iron_shipment"
const CONVOY_DIALOGUE_ID := &"dialogue.supply.iron_convoy"

const CONVOY_SPEED := 40.0
const OBSERVE_RADIUS_SQ := 72.0 * 72.0


static func convoy_active_for_phase(phase_id: StringName) -> bool:
	return phase_id == GameState.PHASE_INVESTIGATION_MORNING


static func is_route_disrupted(state: GameState) -> bool:
	return state != null and state.get_flag(FLAG_DISRUPTED)


static func resolve_patrol_points(definition: MapDefinition) -> PackedVector2Array:
	return MapPatrolController._resolve_points(definition, PATROL_ID)
