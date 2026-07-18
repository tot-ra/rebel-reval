class_name MapBlueprintRegistry
extends RefCounted

## Explicit inventory of blueprint sources. Filesystem discovery is deliberately
## avoided so validation order and CI coverage cannot depend on import ordering.

const KalevSmithy := preload("res://scripts/map/definitions/lower_town/kalev_smithy_rrmap_factory.gd")
const LowerTownSlice := preload("res://scripts/map/definitions/lower_town/lower_town_slice_rrmap_factory.gd")
const RevalHarbor := preload("res://scripts/map/definitions/outdoor/reval_harbor_rrmap_factory.gd")


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
			"id": &"reval_harbor",
			"source": "res://content/maps/reval_harbor_surroundings.rrmap",
			"factory": RevalHarbor,
			"required_anchors": [
				&"from_reval_east",
				&"quay_plaza",
				&"coast_gate",
			],
		},
	]


static func create_blueprint(entry: Dictionary) -> MapBlueprint:
	var factory: Script = entry.get("factory")
	if factory == null or not factory.has_method("create"):
		return null
	var value: Variant = factory.call("create")
	return value as MapBlueprint if value is MapBlueprint else null
