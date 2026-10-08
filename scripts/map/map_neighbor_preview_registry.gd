class_name MapNeighborPreviewRegistry
extends RefCounted

## Resolves traversable scene IDs to their authored map definitions for view-only
## edge previews. The old Reval district maps are gone (the city is one seamless
## plan, docs/SYSTEMS/SEAMLESS_CITY.md), so no scene currently has a neighbour
## preview; the registry stays as the explicit seam for future map neighbours.

const DEFINITION_FACTORIES: Dictionary = {}


static func create_definition(scene_id: StringName) -> MapDefinition:
	var factory: Script = DEFINITION_FACTORIES.get(scene_id)
	if factory == null or not factory.has_method("create"):
		return null
	var value: Variant = factory.call("create")
	return value as MapDefinition if value is MapDefinition else null
