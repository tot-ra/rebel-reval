class_name CartTransportModel
extends RefCounted

## Runtime contract for authored 1343 supply transport.
## WHY: map props already own vehicle-class validation; this model keeps route,
## road, load, and siege rules in one deterministic system-facing boundary.

const PropStyleVariants := preload("res://scripts/map/map_prop_style_variants.gd")

const VEHICLE_CLASS_CART_2W := PropStyleVariants.VEHICLE_CLASS_CART_2W
const VEHICLE_CLASS_WAGON_4W := PropStyleVariants.VEHICLE_CLASS_WAGON_4W
const VEHICLE_CLASS_BARROW := PropStyleVariants.VEHICLE_CLASS_BARROW
const VEHICLE_CLASS_SLEDGE := PropStyleVariants.VEHICLE_CLASS_SLEDGE

const ROAD_STATE_COBBLE := &"cobble"
const ROAD_STATE_MUD := &"mud"
const ROAD_STATE_ICE := &"ice"
const ROAD_STATES: Array[StringName] = [
	ROAD_STATE_COBBLE,
	ROAD_STATE_MUD,
	ROAD_STATE_ICE,
]
const ROAD_SPEED_MODIFIERS: Dictionary = {
	ROAD_STATE_COBBLE: 1.0,
	ROAD_STATE_MUD: 0.7,
	ROAD_STATE_ICE: 0.5,
}

const CART_LOAD_KG_MIN := 250
const CART_LOAD_KG_MAX := 350
const CARTER_HIRE_SCHILLING_MIN := 4
const CARTER_HIRE_SCHILLING_MAX := 12
const CART_TOLL_PFENNIG: Variant = null
const SINGLE_HORSE_DRAUGHT_COUNT := 1
const SIEGE_CUTOFF_DATE := "1343-04-23"

const ROUTE_VIRU_GRAIN := &"viru_harju_grain"
const ROUTE_HARJU_GRAIN := &"harju_road_grain"
const ROUTE_HARBOUR_LIGHTER_TO_CART := &"harbour_lighter_to_cart"
const ROUTE_WALL_YARD := &"wall_yard_freight"
const ROUTE_FORUM_THROAT := &"forum_throat_barrow"
const ROUTE_IDS: Array[StringName] = [
	ROUTE_VIRU_GRAIN,
	ROUTE_HARJU_GRAIN,
	ROUTE_HARBOUR_LIGHTER_TO_CART,
	ROUTE_WALL_YARD,
	ROUTE_FORUM_THROAT,
]

## Vocabulary is intentionally authored rather than generated at runtime.
const BARK_VOCABULARY: Array[String] = [
	"Karren",
	"Wagen",
	"Fuhrmann",
	"voorimees",
	"Macht Platz!",
]

const _ROUTE_DESCRIPTORS: Array[Dictionary] = [
	{
		"route_id": ROUTE_VIRU_GRAIN,
		"vehicle_class": VEHICLE_CLASS_CART_2W,
		"inland": true,
		"harbour_lighter_to_cart": false,
	},
	{
		"route_id": ROUTE_HARJU_GRAIN,
		"vehicle_class": VEHICLE_CLASS_CART_2W,
		"inland": true,
		"harbour_lighter_to_cart": false,
	},
	{
		"route_id": ROUTE_HARBOUR_LIGHTER_TO_CART,
		"vehicle_class": VEHICLE_CLASS_CART_2W,
		"inland": false,
		"harbour_lighter_to_cart": true,
	},
	{
		"route_id": ROUTE_WALL_YARD,
		"vehicle_class": VEHICLE_CLASS_WAGON_4W,
		"inland": false,
		"harbour_lighter_to_cart": false,
	},
	{
		"route_id": ROUTE_FORUM_THROAT,
		"vehicle_class": VEHICLE_CLASS_BARROW,
		"inland": false,
		"harbour_lighter_to_cart": false,
	},
]


static func default_vehicle_class() -> StringName:
	return VEHICLE_CLASS_CART_2W


static func is_known_vehicle_class(vehicle_class: StringName) -> bool:
	return PropStyleVariants.is_known_vehicle_class(vehicle_class)


static func is_known_road_state(road_state: StringName) -> bool:
	return road_state in ROAD_STATES


static func road_speed_modifier(road_state: StringName) -> float:
	if not is_known_road_state(road_state):
		return 0.0
	return float(ROAD_SPEED_MODIFIERS[road_state])


static func effective_speed(base_speed: float, road_state: StringName) -> float:
	return maxf(base_speed, 0.0) * road_speed_modifier(road_state)


static func cart_load_is_valid(load_kg: int) -> bool:
	return load_kg >= CART_LOAD_KG_MIN and load_kg <= CART_LOAD_KG_MAX


static func carter_hire_is_valid(schilling: int) -> bool:
	return schilling >= CARTER_HIRE_SCHILLING_MIN and schilling <= CARTER_HIRE_SCHILLING_MAX


static func cart_toll_pfennig() -> Variant:
	## R-069 is an attested gap: do not invent a per-wheel or per-axle levy.
	return CART_TOLL_PFENNIG


static func draught_horse_count(vehicle_class: StringName) -> int:
	match vehicle_class:
		VEHICLE_CLASS_CART_2W, VEHICLE_CLASS_SLEDGE:
			return SINGLE_HORSE_DRAUGHT_COUNT
		VEHICLE_CLASS_WAGON_4W:
			return 2
		_:
			return 0


static func is_single_horse_draught(vehicle_class: StringName) -> bool:
	return draught_horse_count(vehicle_class) == SINGLE_HORSE_DRAUGHT_COUNT


static func vehicle_class_allowed_on_route(
	vehicle_class: StringName, route_id: StringName
) -> bool:
	if not is_known_vehicle_class(vehicle_class) or not route_id in ROUTE_IDS:
		return false
	if vehicle_class == VEHICLE_CLASS_WAGON_4W:
		return route_id in [ROUTE_HARBOUR_LIGHTER_TO_CART, ROUTE_WALL_YARD]
	if vehicle_class == VEHICLE_CLASS_BARROW:
		return route_id == ROUTE_FORUM_THROAT
	return vehicle_class == VEHICLE_CLASS_CART_2W and route_id in [
		ROUTE_VIRU_GRAIN,
		ROUTE_HARJU_GRAIN,
		ROUTE_HARBOUR_LIGHTER_TO_CART,
		ROUTE_FORUM_THROAT,
	]


static func siege_inland_cart_active_for_phase(phase_id: StringName) -> bool:
	return phase_id != &"phase.act1_climax"


static func siege_inland_cart_active_for_date(game_date: String) -> bool:
	var date_key := _date_key(game_date)
	if date_key < 0:
		return false
	return date_key <= _date_key(SIEGE_CUTOFF_DATE)


static func route_available_for_date(route_id: StringName, game_date: String) -> bool:
	if not route_id in ROUTE_IDS:
		return false
	if route_id in [ROUTE_VIRU_GRAIN, ROUTE_HARJU_GRAIN]:
		return siege_inland_cart_active_for_date(game_date)
	return route_id == ROUTE_HARBOUR_LIGHTER_TO_CART


static func routes_for_siege(inland_cart_active: bool) -> Array[Dictionary]:
	var routes: Array[Dictionary] = []
	for descriptor in _ROUTE_DESCRIPTORS:
		if bool(descriptor["inland"]) and not inland_cart_active:
			continue
		routes.append(descriptor.duplicate(true))
	return routes


static func bark_vocabulary() -> Array[String]:
	return BARK_VOCABULARY.duplicate()


static func _date_key(game_date: String) -> int:
	var parts := game_date.split("-")
	if parts.size() != 3:
		return -1
	if parts[0].length() != 4 or parts[1].length() != 2 or parts[2].length() != 2:
		return -1
	return parts[0].to_int() * 10000 + parts[1].to_int() * 100 + parts[2].to_int()
