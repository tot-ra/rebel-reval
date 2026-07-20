class_name MapBlueprintRegistry
extends RefCounted

## Explicit inventory of blueprint sources. Filesystem discovery is deliberately
## avoided so validation order and CI coverage cannot depend on import ordering.

const KalevSmithy := preload("res://scripts/map/definitions/lower_town/kalev_smithy_rrmap_factory.gd")
const LowerTownSlice := preload("res://scripts/map/definitions/lower_town/lower_town_slice_rrmap_factory.gd")
const NorthQuarter := preload("res://scripts/map/definitions/prototypes/north_quarter_rrmap_factory.gd")
const MonasteryQuarter := preload("res://scripts/map/definitions/prototypes/monastery_quarter_rrmap_factory.gd")
const MarketCivicQuarter := preload("res://scripts/map/definitions/prototypes/market_civic_quarter_rrmap_factory.gd")
const ToompeaQuarter := preload("res://scripts/map/definitions/prototypes/toompea_quarter_rrmap_factory.gd")
const SouthQuarter := preload("res://scripts/map/definitions/prototypes/south_quarter_rrmap_factory.gd")
const RevalHarborNorth := preload("res://scripts/map/definitions/outdoor/reval_harbor_north_rrmap_factory.gd")
const RevalHarborEast := preload("res://scripts/map/definitions/outdoor/reval_harbor_east_rrmap_factory.gd")


static func entries() -> Array[Dictionary]:
	return [
		{
			"id": &"kalev_smithy",
			"source": "res://content/maps/kalev_smithy.rrmap",
			"factory": KalevSmithy,
			"required_anchors": [
				&"anvil",
				&"ledger",
				&"bed_alcove",
			],
		},
		{
			"id": &"lower_town_slice",
			"source": "res://content/maps/lower_town_slice.rrmap",
			"factory": LowerTownSlice,
			"required_anchors": [
				&"street_start",
				&"smithy_door",
				&"brewery_door",
				&"checkpoint_west",
				&"checkpoint_east",
			],
		},
		{
			"id": &"market_civic_quarter",
			"source": "res://content/maps/market_civic_quarter.rrmap",
			"factory": MarketCivicQuarter,
			"required_anchors": [
				&"inspection_spawn",
				&"town_hall_edge",
				&"pikk_street_spine",
				&"vana_turg_neck",
				&"karja_lane",
			],
		},
		{
			"id": &"north_quarter",
			"source": "res://content/maps/north_quarter.rrmap",
			"factory": NorthQuarter,
			"required_anchors": [
				&"inspection_spawn",
				&"pikk_street_spine",
				&"merchant_court",
			],
		},
		{
			"id": &"monastery_quarter",
			"source": "res://content/maps/monastery_quarter.rrmap",
			"factory": MonasteryQuarter,
			"required_anchors": [
				&"inspection_spawn",
				&"monastery_close",
				&"st_olaf_frontage",
				&"guild_frontage",
			],
		},
		{
			"id": &"toompea_quarter",
			"source": "res://content/maps/toompea_quarter.rrmap",
			"factory": ToompeaQuarter,
			"required_anchors": [
				&"inspection_spawn",
				&"castle_courtyard",
				&"cathedral_frontage",
				&"luhike_jalg_gate",
			],
		},
		{
			"id": &"south_quarter",
			"source": "res://content/maps/south_quarter.rrmap",
			"factory": SouthQuarter,
			"required_anchors": [
				&"inspection_spawn",
				&"rataskaev_well",
				&"karja_approach",
			],
		},
		{
			"id": &"reval_harbor_north",
			"source": "res://content/maps/reval_harbor_north.rrmap",
			"factory": RevalHarborNorth,
			"required_anchors": [
				&"from_reval_north",
				&"from_harbor_east",
				&"quay_plaza",
				&"coast_gate",
			],
		},
		{
			"id": &"reval_harbor_east",
			"source": "res://content/maps/reval_harbor_east.rrmap",
			"factory": RevalHarborEast,
			"required_anchors": [
				&"from_reval_east",
				&"from_harbor_north",
				&"quay_plaza",
			],
		},
	]


static func create_blueprint(entry: Dictionary) -> MapBlueprint:
	var factory: Script = entry.get("factory")
	if factory == null or not factory.has_method("create"):
		return null
	var value: Variant = factory.call("create")
	return value as MapBlueprint if value is MapBlueprint else null
