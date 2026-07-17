class_name MapBlueprintRegistry
extends RefCounted

## Explicit inventory of blueprint sources. Filesystem discovery is deliberately
## avoided so validation order and CI coverage cannot depend on import ordering.

const LowerTownSlice := preload("res://scripts/map/definitions/lower_town/lower_town_slice_blueprint.gd")


static func entries() -> Array[Dictionary]:
	return [
		{
			"id": &"lower_town_slice",
			"source": "res://scripts/map/definitions/lower_town/lower_town_slice_blueprint.gd",
			"factory": LowerTownSlice,
			"required_anchors": [
				&"street_start",
				&"smithy_door",
				&"brewery_door",
				&"checkpoint_west",
				&"checkpoint_east",
			],
		},
	]


static func create_blueprint(entry: Dictionary) -> MapBlueprint:
	var factory: Script = entry.get("factory")
	if factory == null or not factory.has_method("create"):
		return null
	var value: Variant = factory.call("create")
	return value as MapBlueprint if value is MapBlueprint else null
