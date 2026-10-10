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
			"id": &"world.harju",
			"source": "res://content/maps/world_harju.rrmap",
			"required_anchors":
			[&"landmark_village_well", &"landmark_threshing_barn", &"landmark_split_fields"],
		},
		{
			"id": &"world.padise",
			"source": "res://content/maps/world_padise.rrmap",
			"required_anchors":
			[
				&"landmark_early_stone_house",
				&"landmark_timber_oratory",
				&"landmark_fire_damage",
				&"landmark_work_yard",
				&"landmark_monastery_well"
			],
		},
		{
			"id": &"world.saaremaa",
			"source": "res://content/maps/world_saaremaa.rrmap",
			"required_anchors":
			[&"landmark_island_coast", &"landmark_west_camp", &"landmark_east_camp"],
		},
		{
			"id": &"world.rebel_kings",
			"source": "res://content/maps/world_rebel_kings.rrmap",
			"required_anchors":
			[&"landmark_council_camp", &"landmark_west_camp", &"landmark_east_camp"],
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
			"id": &"world.paide",
			"source": "res://content/maps/world_paide.rrmap",
			"required_anchors":
			[&"landmark_gatehouse", &"landmark_central_keep", &"landmark_limestone_tower"],
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
