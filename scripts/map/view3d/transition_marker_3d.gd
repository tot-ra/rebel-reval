class_name TransitionMarker3D
extends Node3D

## Keeps exit markers subtly visible and brightens them when the player nears.
## The player rig is a stable runtime group, so this view-only cue stays
## independent from navigation, collisions, and transition activation.

const HIGHLIGHT_DISTANCE_WORLD := 4.5
const IDLE_ALPHA := 0.3
const FOCUS_ALPHA := 0.62


func _process(_delta: float) -> void:
	var player_rig := get_tree().get_first_node_in_group(&"player_view_rig") as Node3D
	set_focused(player_rig != null and global_position.distance_to(player_rig.global_position) <= HIGHLIGHT_DISTANCE_WORLD)


func set_focused(focused: bool) -> void:
	var surface := get_node_or_null("Surface") as MeshInstance3D
	if surface == null:
		return
	var material := surface.material_override as StandardMaterial3D
	if material == null:
		return
	var color := material.albedo_color
	color.a = FOCUS_ALPHA if focused else IDLE_ALPHA
	material.albedo_color = color
