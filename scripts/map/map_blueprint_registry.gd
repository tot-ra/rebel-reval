class_name MapBlueprintRegistry
extends RefCounted

## Explicit inventory of blueprint sources. Filesystem discovery is deliberately
## avoided so validation order and CI coverage cannot depend on import ordering.

const KalevSmithy := preload("res://scripts/map/definitions/lower_town/kalev_smithy_rrmap_factory.gd")
const LowerTownSlice := preload("res://scripts/map/definitions/lower_town/lower_town_slice_rrmap_factory.gd")
const NorthQuarter := preload("res://scripts/map/definitions/prototypes/north_quarter_rrmap_factory.gd")
const MonasteryQuarter := preload("res://scripts/map/definitions/prototypes/monastery_quarter_rrmap_factory.gd")
const ArchbishopsGarden := preload("res://scripts/map/definitions/prototypes/archbishops_garden_rrmap_factory.gd")
const MarketCivicQuarter := preload("res://scripts/map/definitions/prototypes/market_civic_quarter_rrmap_factory.gd")
const ToompeaQuarter := preload("res://scripts/map/definitions/prototypes/toompea_quarter_rrmap_factory.gd")
const SouthQuarter := preload("res://scripts/map/definitions/prototypes/south_quarter_rrmap_factory.gd")
const ViruGateForeland := preload("res://scripts/map/definitions/outdoor/viru_gate_foreland_rrmap_factory.gd")
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
			"id": &"archbishops_garden",
			"source": "res://content/maps/archbishops_garden.rrmap",
			"factory": ArchbishopsGarden,
			"required_anchors": [&"inspection_spawn", &"archbishops_garden", &"medieval_well", &"western_view"],
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
			"id": &"viru_gate_foreland",
			"source": "res://content/maps/viru_gate_foreland.rrmap",
			"factory": ViruGateForeland,
			"required_anchors": [
				&"from_reval_east",
				&"pirita_bridge",
				&"river_meadow",
				&"farmstead",
				&"eastern_road",
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
				&"from_harbor_north",
				&"quay_plaza",
				&"kalamaja_shore",
			],
		},
		{
			"id": &"st_olafs_guild_hall",
			"source": "res://content/maps/st_olafs_guild_hall.rrmap",
			"required_anchors": [&"inspection_spawn", &"dais"],
		},
		{
			"id": &"world.sacred_grove",
			"source": "res://content/maps/world_sacred_grove.rrmap",
			"required_anchors": [&"landmark_ancient_oak", &"landmark_offering_stone", &"landmark_bog_spring"],
		},
		{
			"id": &"world.harju",
			"source": "res://content/maps/world_harju.rrmap",
			"required_anchors": [&"landmark_village_well", &"landmark_threshing_barn", &"landmark_split_fields"],
		},
		{
			"id": &"world.padise",
			"source": "res://content/maps/world_padise.rrmap",
			"required_anchors": [&"landmark_church", &"landmark_cloister", &"landmark_gatehouse", &"landmark_work_yard"],
		},
		{
			"id": &"world.saaremaa",
			"source": "res://content/maps/world_saaremaa.rrmap",
			"required_anchors": [&"landmark_island_coast", &"landmark_west_camp", &"landmark_east_camp"],
		},
		{
			"id": &"world.rebel_kings",
			"source": "res://content/maps/world_rebel_kings.rrmap",
			"required_anchors": [&"landmark_council_camp", &"landmark_west_camp", &"landmark_east_camp"],
		},
		{
			"id": &"world.kanavere",
			"source": "res://content/maps/world_kanavere.rrmap",
			"required_anchors": [&"landmark_bog_causeway", &"landmark_west_fieldworks", &"landmark_east_fieldworks"],
		},
		{
			"id": &"world.sojamae",
			"source": "res://content/maps/world_sojamae.rrmap",
			"required_anchors": [&"landmark_battle_ridge", &"landmark_west_fieldworks", &"landmark_east_fieldworks"],
		},
		{
			"id": &"world.paide",
			"source": "res://content/maps/world_paide.rrmap",
			"required_anchors": [&"landmark_gatehouse", &"landmark_central_keep", &"landmark_limestone_tower"],
		},
		{
			"id": &"world.parnu",
			"source": "res://content/maps/world_parnu.rrmap",
			"required_anchors": [&"landmark_town_barricade", &"landmark_west_quarter", &"landmark_east_quarter"],
		},
		{
			"id": &"world.poide",
			"source": "res://content/maps/world_poide.rrmap",
			"required_anchors": [&"landmark_gatehouse", &"landmark_central_keep", &"landmark_island_chapel"],
		},
	]


static func create_blueprint(entry: Dictionary) -> MapBlueprint:
	var factory: Script = entry.get("factory")
	if factory != null and factory.has_method("create"):
		var value: Variant = factory.call("create")
		return value as MapBlueprint if value is MapBlueprint else null
	# RRMap-only entries do not need one wrapper script per source. The explicit
	# registry still owns discovery order and semantic anchor requirements.
	var source := String(entry.get("source", ""))
	if source.ends_with(".rrmap"):
		var parsed := MapRrmapParser.parse_file(source)
		return parsed.blueprint if parsed.is_ok() else null
	return null
