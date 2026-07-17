class_name RrmapResource
extends Resource

## Editor-loadable wrapper. Runtime consumers still receive MapDefinition output
## from MapBlueprintCompiler rather than a second map contract.

var source_path: String
var source_text: String
var blueprint: MapBlueprint
var definition: MapDefinition
var diagnostics: Array[MapRrmapDiagnostic] = []


func is_valid() -> bool:
	return blueprint != null and definition != null and diagnostics.is_empty()
