class_name MapViewPlayerRange
extends RefCounted
## Makes camera-distance visibility ranges behave as player-distance ranges.
##
## Godot measures GeometryInstance3D.visibility_range_end from the camera. Painted
## iso sits ~42 m from the player, so a 14 m or 45 m grass range culled the grass
## round the feet entirely. A node tagged here keeps its authored radius around
## the player: widening the camera range by the camera-to-player distance
## guarantees (triangle inequality) that everything within `base` of the player
## stays visible in every camera mode. Third person adds only a few metres.

const GROUP := &"player_range_cull"
const BASE_META := &"player_range_base"
## Retarget only after the camera drifts this far, so orbiting does not touch
## every MultiMesh each frame.
const RETARGET_STEP := 0.75

static var _applied_extra := -1.0


## Marks `node` so retarget() keeps `base_range` around the player.
static func tag(node: GeometryInstance3D, base_range: float) -> void:
	node.set_meta(BASE_META, base_range)
	node.add_to_group(GROUP)
	# Nodes built after the last retarget (rebuilt detail chunks) start widened.
	node.visibility_range_end = base_range + maxf(_applied_extra, 0.0)


## Widens every tagged node by `camera_to_player` metres. Returns true if applied.
static func retarget(tree: SceneTree, camera_to_player: float) -> bool:
	if tree == null:
		return false
	if absf(camera_to_player - _applied_extra) < RETARGET_STEP and _applied_extra >= 0.0:
		return false
	_applied_extra = camera_to_player
	for node in tree.get_nodes_in_group(GROUP):
		var geometry := node as GeometryInstance3D
		if geometry != null and geometry.has_meta(BASE_META):
			geometry.visibility_range_end = float(geometry.get_meta(BASE_META)) + camera_to_player
	return true


## Test hook: forget the last applied distance.
static func reset() -> void:
	_applied_extra = -1.0
