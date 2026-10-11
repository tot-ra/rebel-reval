class_name PadiseMonkActor
extends StaticNpcActor

## Logic-only presentation actor for Padise's two monastic communities.
## The 3D runtime mirrors the selected rig, while this stable metadata keeps
## brotherhood identity available to phase and interaction systems.

const WHITE_BROTHER := &"white_brother_choir"
const GREY_BROTHER := &"grey_brother_lay"

var brotherhood_id: StringName = &""


func configure_brotherhood(
	player: Node2D,
	position: Vector2,
	community: StringName,
	rig: PackedScene
) -> void:
	brotherhood_id = community
	rig_scene = rig
	set_meta(&"brotherhood_id", community)
	set_meta(&"monastic_role", &"choir" if community == WHITE_BROTHER else &"lay")
	configure(player, position)
