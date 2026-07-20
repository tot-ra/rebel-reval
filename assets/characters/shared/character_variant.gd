extends Resource

class_name CharacterVariant

@export var stable_id: StringName = &"char.variant"
@export var material_tint: Color = Color.WHITE
@export var equipment: PackedScene
@export var show_cape: bool = false
@export var show_hat: bool = false
## Canonical animation name -> alternate source clip carried by every
## generated body (e.g. &"walk": &"Walking_C"), so characters move with
## their own gait without new animation assets.
@export var animation_overrides: Dictionary = {}

