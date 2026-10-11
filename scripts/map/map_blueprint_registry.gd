class_name MapBlueprintRegistry
extends RefCounted

## Explicit inventory of blueprint sources. Filesystem discovery is deliberately
## avoided so validation order and CI coverage cannot depend on import ordering.

const KalevSmithy := preload(
	"res://scripts/map/definitions/lower_town/kalev_smithy_rrmap_factory.gd"
)


static func entries() -> Array[Dictionary]:
	return [
		{
			"id": &"kalev_smithy",
			"source": "res://content/maps/kalev_smithy.rrmap",
			"factory": KalevSmithy,
			"required_anchors":
			[
				&"anvil",
				&"ledger",
				&"bed_alcove",
			],
		},
		{
			"id": &"world.kanavere",
			"source": "res://content/maps/world_kanavere.rrmap",
			"required_anchors":
			[&"landmark_bog_causeway", &"landmark_west_fieldworks", &"landmark_east_fieldworks"],
		},
		{
			"id": &"world.sojamae",
			"source": "res://content/maps/world_sojamae.rrmap",
			"required_anchors":
			[&"landmark_battle_ridge", &"landmark_west_fieldworks", &"landmark_east_fieldworks"],
		},
		{
			"id": &"world.parnu",
			"source": "res://content/maps/world_parnu.rrmap",
			"required_anchors":
			[&"landmark_town_barricade", &"landmark_west_quarter", &"landmark_east_quarter"],
		},
		{
			"id": &"world.poide",
			"source": "res://content/maps/world_poide.rrmap",
			"required_anchors":
			[&"landmark_gatehouse", &"landmark_central_keep", &"landmark_island_chapel"],
		},
		{
			"id": &"world.rakvere",
			"source": "res://content/maps/world_rakvere.rrmap",
			"required_anchors": [&"landmark_gatehouse", &"landmark_central_keep", &"landmark_yard_well"],
		},
		{
			"id": &"world.haapsalu",
			"source": "res://content/maps/world_haapsalu.rrmap",
			"required_anchors": [&"landmark_gatehouse", &"landmark_central_keep", &"landmark_yard_well"],
		},
		{
			"id": &"world.lihula",
			"source": "res://content/maps/world_lihula.rrmap",
			"required_anchors": [&"landmark_gatehouse", &"landmark_central_keep", &"landmark_yard_well"],
		},
		{
			"id": &"world.tartu",
			"source": "res://content/maps/world_tartu.rrmap",
			"required_anchors":
			[&"landmark_market_square", &"landmark_town_hall", &"landmark_warehouse_row"],
		},
		{
			"id": &"world.viljandi",
			"source": "res://content/maps/world_viljandi.rrmap",
			"required_anchors": [&"landmark_gatehouse", &"landmark_central_keep", &"landmark_yard_well"],
		},
		{
			"id": &"world.poltsamaa",
			"source": "res://content/maps/world_poltsamaa.rrmap",
			"required_anchors": [&"landmark_gatehouse", &"landmark_central_keep", &"landmark_yard_well"],
		},
		{
			"id": &"world.narva",
			"source": "res://content/maps/world_narva.rrmap",
			"required_anchors": [&"landmark_gatehouse", &"landmark_central_keep", &"landmark_yard_well"],
		},
		{
			"id": &"world.karksi",
			"source": "res://content/maps/world_karksi.rrmap",
			"required_anchors": [&"landmark_gatehouse", &"landmark_central_keep", &"landmark_yard_well"],
		},
		{
			"id": &"world.helme",
			"source": "res://content/maps/world_helme.rrmap",
			"required_anchors": [&"landmark_gatehouse", &"landmark_central_keep", &"landmark_yard_well"],
		},
		{
			"id": &"world.maasilinna",
			"source": "res://content/maps/world_maasilinna.rrmap",
			"required_anchors": [&"landmark_gatehouse", &"landmark_central_keep", &"landmark_yard_well"],
		},
		{
			"id": &"world.karja",
			"source": "res://content/maps/world_karja.rrmap",
			"required_anchors": [&"landmark_gatehouse", &"landmark_central_keep", &"landmark_yard_well"],
		},
		{
			"id": &"world.klint",
			"source": "res://content/maps/world_klint.rrmap",
			"required_anchors": [&"landmark_cliff_edge", &"landmark_lime_kiln", &"landmark_quarry"],
		},
		{
			"id": &"world.soomaa",
			"source": "res://content/maps/world_soomaa.rrmap",
			"required_anchors": [&"landmark_causeway", &"landmark_pile_hut", &"landmark_boat_shed"],
		},
		{
			"id": &"world.frontier_ugandi",
			"source": "res://content/maps/world_frontier_ugandi.rrmap",
			"required_anchors": [&"landmark_crossing", &"landmark_clearing_fire", &"landmark_watch_hut"],
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
