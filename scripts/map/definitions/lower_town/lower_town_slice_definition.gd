class_name LowerTownSliceDefinition
extends RefCounted

## Thin compile adapter for the Lower Town slice blueprint (P2-019).
## Authoring lives in LowerTownSliceBlueprint; this preserves preload call sites.

const _BLUEPRINT := preload("res://scripts/map/definitions/lower_town/lower_town_slice_blueprint.gd")
const _COMPILER := preload("res://scripts/map/map_blueprint_compiler.gd")


static func create() -> MapDefinition:
	var result := _COMPILER.compile_with_diagnostics(_BLUEPRINT.create())
	if not result.is_ok():
		push_error("LowerTownSliceBlueprint failed to compile: %s" % str(result.errors))
		return null
	return result.definition
