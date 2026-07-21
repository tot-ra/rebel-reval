class_name RevalFortificationRegistry
extends RefCounted

## Conservative 1343 fortification registry for the Lower Town map portfolio.
##
## Stable map IDs remain technical because saves and parity fixtures reference
## them. Historical identity lives here so a dated claim can be revised without
## silently renaming map objects.

const SNAPSHOT_YEAR := 1343

## The first-quarter-fourteenth-century reconstruction explicitly identifies the
## Nun's and Golden Leg towers; the mid-century reconstruction adds the Rent
## tower, while archaeology dates the first Great Coastal Gate tower to 1311-40.
## These four positions are therefore the defensible completed-tower baseline for
## 1343. This is not the later 1355 list of eleven defended works, the 1373 list,
## or the fifteenth/sixteenth-century maximum.
const COMPLETED_TOWERS_1343: Array[Dictionary] = [
	{
		"historical_id": &"nunnatorn",
		"name": "Nunnatorn / Nun's Tower",
		"map_id": &"monastery_quarter",
		"building_id": &"monastery_wall_tower_northwest",
		"evidence": &"first_half_14c",
	},
	{
		"historical_id": &"kuldjala",
		"name": "Kuldjala / Golden Leg Tower",
		"map_id": &"monastery_quarter",
		"building_id": &"monastery_wall_tower_west_mid",
		"evidence": &"circa_1310",
	},
	{
		"historical_id": &"rentenitorn",
		"name": "Rentenitorn / Rent Tower",
		"map_id": &"north_quarter",
		"building_id": &"merchant_wall_tower_northwest",
		"evidence": &"before_mid_14c",
	},
	{
		"historical_id": &"great_coastal_gate",
		"name": "Great Coastal Gate tower",
		"map_id": &"north_quarter",
		"building_id": &"coast_gate_west_tower",
		"evidence": &"probable_1311_1340",
	},
]

## The mid-fourteenth-century reconstruction places these works on the circuit,
## but the reviewed evidence cannot prove their exact completion state on the
## game's 1343 date. Maps may show reversible masonry/scaffolding at these stable
## positions, not finished later silhouettes.
const CONSTRUCTION_CANDIDATES_1343: Array[Dictionary] = [
	{
		"historical_id": &"sand_gate",
		"name": "Sand Gate",
		"map_id": &"lower_town_slice",
		"building_id": &"wall_tower_northeast",
	},
	{
		"historical_id": &"viru_gate",
		"name": "Viru Gate",
		"map_id": &"lower_town_slice",
		"building_id": &"viru_gate_north_tower",
	},
	{
		"historical_id": &"hinke",
		"name": "Hinke Tower",
		"map_id": &"lower_town_slice",
		"building_id": &"hinke_tower",
	},
	{
		"historical_id": &"cattle_gate",
		"name": "Cattle (Karja) Gate",
		"map_id": &"south_quarter",
		"building_id": &"karja_gate_west_tower",
	},
	{
		"historical_id": &"harju_gate",
		"name": "Harju Gate",
		"map_id": &"south_quarter",
		"building_id": &"south_wall_tower_midwest",
	},
]

## These familiar towers postdate the snapshot and must not be presented as
## completed 1343 fabric. Future construction-site art can reuse their later
## positions only after a source-backed placement pass.
const POST_1343_EXCLUSIONS: Array[Dictionary] = [
	{"historical_id": &"saunatorn", "name": "Saunatorn / Bath Tower", "earliest_state": "third quarter of the 14th century"},
	{"historical_id": &"nunnadetagune", "name": "Nunnadetagune / Behind the Nun's Tower", "earliest_state": "third quarter of the 14th century"},
	{"historical_id": &"loewenschede", "name": "Loewenschede Tower", "earliest_state": "third quarter of the 14th century"},
	{"historical_id": &"koismae", "name": "Köismäe / Ropemakers' Tower", "earliest_state": "third quarter of the 14th century"},
	{"historical_id": &"epping", "name": "Epping Tower", "earliest_state": "third quarter of the 14th century"},
	{"historical_id": &"neitsitorn", "name": "Neitsitorn / Maiden's Tower", "earliest_state": "1370-1373"},
	{"historical_id": &"kiek_in_de_kok", "name": "Kiek in de Kök", "earliest_state": "1470s"},
	{"historical_id": &"fat_margaret", "name": "Fat Margaret", "earliest_state": "1518-1531"},
]


static func completed_tower_count() -> int:
	return COMPLETED_TOWERS_1343.size()


static func completed_tower_by_map(map_id: StringName) -> Array[Dictionary]:
	var matches: Array[Dictionary] = []
	for record in COMPLETED_TOWERS_1343:
		if record["map_id"] == map_id:
			matches.append(record)
	return matches
