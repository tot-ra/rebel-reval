class_name MapNeighborPreviewRegistry
extends RefCounted

## Resolves traversable scene IDs to their authored map definitions for view-only
## edge previews. Keeping this registry explicit preserves deterministic loading,
## while reading the real definitions means edits to either district immediately
## update the reciprocal backdrop without copied facade data.

const LowerTownSlice := preload("res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd")
const MarketCivicQuarter := preload("res://scripts/map/definitions/prototypes/market_civic_quarter_definition.gd")
const NorthQuarter := preload("res://scripts/map/definitions/prototypes/north_quarter_definition.gd")
const RevalHarbor := preload("res://scripts/map/definitions/outdoor/reval_harbor_definition.gd")

const DEFINITION_FACTORIES: Dictionary = {
	&"reval_east": LowerTownSlice,
	&"reval_center": MarketCivicQuarter,
	&"reval_north": NorthQuarter,
	&"reval_harbor": RevalHarbor,
}


static func create_definition(scene_id: StringName) -> MapDefinition:
	var factory: Script = DEFINITION_FACTORIES.get(scene_id)
	if factory == null or not factory.has_method("create"):
		return null
	var value: Variant = factory.call("create")
	return value as MapDefinition if value is MapDefinition else null
