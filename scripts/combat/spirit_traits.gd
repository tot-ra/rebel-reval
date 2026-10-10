class_name SpiritTraits
extends RefCounted
## Double-edged hero traits and opponent temperaments for the spirit duel (ADR 0033, SD-15).
## Every hero trait comes in two variants by how it was gained, `gift` or `scar`, and each
## variant carries both a boon and a cost. Opponent temperaments are authored tags on a
## duel record that make some move kinds hit harder and others softer. Fixed tables, no
## randomness, no morality score.

const ORIGIN_GIFT := &"gift"
const ORIGIN_SCAR := &"scar"
const ORIGINS: Array[StringName] = [ORIGIN_GIFT, ORIGIN_SCAR]

## trait id -> origin -> modifiers:
##   reply {element: multiplier on the hero's reply damage},
##   incoming {kind: multiplier on blows taken},
##   dodge_cost_delta, parry_window_delta (seconds), composure_delta.
const TRAITS: Dictionary = {
	&"trait.hears_fear":
	{
		&"gift": {"reply": {"fear": 1.25}, "incoming": {"pressure": 1.15}},
		&"scar":
		{"reply": {"fear": 1.1}, "incoming": {"pressure": 1.3}, "composure_delta": -10.0},
	},
	&"trait.watchful":
	{
		&"gift": {"parry_window_delta": 0.07, "dodge_cost_delta": 5.0},
		&"scar": {"parry_window_delta": 0.04, "dodge_cost_delta": 10.0},
	},
	&"trait.stubborn":
	{
		&"gift": {"composure_delta": 15.0, "reply": {"shame": 0.8}},
		&"scar": {"composure_delta": 5.0, "reply": {"love": 0.75}},
	},
}

## Opponent temperament tag -> reply move kind -> damage multiplier.
const TEMPERAMENTS: Dictionary = {
	&"impulsive": {"defense": 1.3, "evade": 1.2, "appeal": 0.7},
	&"procrastinator": {"pressure": 1.4, "attack": 0.8},
	&"creative": {"feint": 0.6, "appeal": 1.3},
	&"proud": {"appeal": 0.6, "feint": 1.3},
	&"anxious": {"attack": 1.3, "pressure": 1.2, "defense": 0.8},
}
const TEMPERAMENT_MULTIPLIER_MIN := 0.5
const TEMPERAMENT_MULTIPLIER_MAX := 2.0


static func is_trait(trait_id: StringName) -> bool:
	return TRAITS.has(trait_id)


static func is_origin(origin: StringName) -> bool:
	return ORIGINS.has(origin)


## Combined modifiers of the traits the hero holds:
## {reply: {element: mult}, incoming: {kind: mult},
## dodge_cost_delta, parry_window_delta, composure_delta}.
static func modifiers_for(state: GameState) -> Dictionary:
	var combined := {
		"reply": {},
		"incoming": {},
		"dodge_cost_delta": 0.0,
		"parry_window_delta": 0.0,
		"composure_delta": 0.0,
	}
	if state == null:
		return combined
	for trait_id: StringName in state.get_traits():
		var origin := state.get_trait_origin(trait_id)
		var variant: Dictionary = (TRAITS.get(trait_id, {}) as Dictionary).get(origin, {})
		for table_name: String in ["reply", "incoming"]:
			var target: Dictionary = combined[table_name]
			for key: Variant in (variant.get(table_name, {}) as Dictionary):
				target[key] = float(target.get(key, 1.0)) * float((variant[table_name] as Dictionary)[key])
		for scalar: String in ["dodge_cost_delta", "parry_window_delta", "composure_delta"]:
			combined[scalar] = float(combined[scalar]) + float(variant.get(scalar, 0.0))
	return combined


static func reply_multiplier(modifiers: Dictionary, element: StringName) -> float:
	return float((modifiers.get("reply", {}) as Dictionary).get(String(element), 1.0))


static func incoming_multiplier(modifiers: Dictionary, kind: StringName) -> float:
	return float((modifiers.get("incoming", {}) as Dictionary).get(String(kind), 1.0))


## Product of the opponent's temperament tags for a reply of `kind`, clamped.
static func temperament_multiplier(tags: Array, kind: StringName) -> float:
	var product := 1.0
	for tag_value: Variant in tags:
		var table: Dictionary = TEMPERAMENTS.get(StringName(String(tag_value)), {})
		product *= float(table.get(String(kind), 1.0))
	return clampf(product, TEMPERAMENT_MULTIPLIER_MIN, TEMPERAMENT_MULTIPLIER_MAX)


## True when a variant has at least one boon and at least one cost (the double edge).
static func is_double_edged(variant: Dictionary) -> bool:
	var boon := false
	var cost := false
	for element_mult: Variant in (variant.get("reply", {}) as Dictionary).values():
		boon = boon or float(element_mult) > 1.0
		cost = cost or float(element_mult) < 1.0
	for kind_mult: Variant in (variant.get("incoming", {}) as Dictionary).values():
		boon = boon or float(kind_mult) < 1.0
		cost = cost or float(kind_mult) > 1.0
	var dodge := float(variant.get("dodge_cost_delta", 0.0))
	boon = boon or dodge < 0.0
	cost = cost or dodge > 0.0
	var parry := float(variant.get("parry_window_delta", 0.0))
	boon = boon or parry > 0.0
	cost = cost or parry < 0.0
	var composure := float(variant.get("composure_delta", 0.0))
	boon = boon or composure > 0.0
	cost = cost or composure < 0.0
	return boon and cost
