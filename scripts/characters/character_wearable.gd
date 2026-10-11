class_name CharacterWearable
extends Resource

## Presentation data only. Inventory owns item identity and gameplay effects.
@export var stable_id: StringName
@export_enum("torso", "outerwear", "legs", "feet", "hands", "head", "back")
var slot: String = "torso"
## Geometry must be fitted to this body, not merely share its bone names.
@export var fitted_body: String
@export var scene: PackedScene
## Exact authored mesh-name prefixes; applied to all three body LODs.
@export var covered_meshes: Array[StringName] = []
