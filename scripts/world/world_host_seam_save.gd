class_name WorldHostSeamSave
extends RefCounted

## WB-08c (R-1044): save and resume on either side of a streamed seam.
##
## Save identity stays MapStableStateStore's {location_id, object_id} plus a global
## cell / sub-cell (ADR 0019): the player is one entity record under the owning
## location. The owner is always a mounted location, never an in-flight one, and
## no pending mount, chunk id or node path enters the payload, so a save taken
## while a neighbour is mid-mount equals one taken after it finished.
##
## `resume` marks the record the live host mirrors every streaming tick. A host
## launched from a loaded save consumes it once, after DoorNavigator placed the
## player at the saved spawn. A host that loses ownership of a location (seam
## crossing, scene swap) clears it, so a later door entry uses the door's spawn
## instead of a stale position.

const PLAYER_OBJECT_ID := &"char.kalev"
const PLAYER_ARCHETYPE := "player"


## Mirrors the owner and the player's global position into `state`.
static func capture(host: WorldHost, state: GameState) -> bool:
	var owner := host.owning_location_id() if host != null else &""
	var player := host.player_owner as Node2D if host != null else null
	var cell_size := _cell_size(host, owner)
	if state == null or player == null or cell_size <= 0:
		return false
	if not host.mounted_location_ids().has(owner):
		return false
	var record := MapStableStateStore.persistent_position(player.global_position, cell_size)
	record["archetype"] = PLAYER_ARCHETYPE
	record["resume"] = true
	state.player.location_id = StringName(host.location_entry(owner).get("scene_id", owner))
	return state.map_world_state.record_entity(owner, PLAYER_OBJECT_ID, record)


## The saved global logic position for the host's owner, or null when the record
## is absent or was already released. Does not write the player.
static func resume_position(host: WorldHost, state: GameState) -> Variant:
	if host == null or state == null:
		return null
	var owner := host.owning_location_id()
	var cell_size := _cell_size(host, owner)
	var record := state.map_world_state.entity_state(owner, PLAYER_OBJECT_ID)
	if cell_size <= 0 or not bool(record.get("resume", false)):
		return null
	return MapStableStateStore.restore_persistent_position(record, cell_size)


## Clears `resume` on `location_id`'s record; the last position stays for tools.
static func release(state: GameState, location_id: StringName) -> void:
	if state == null or location_id.is_empty():
		return
	var record := state.map_world_state.entity_state(location_id, PLAYER_OBJECT_ID)
	if bool(record.get("resume", false)):
		record["resume"] = false
		state.map_world_state.record_entity(location_id, PLAYER_OBJECT_ID, record)


## The layout location whose launch scene is `scene_id` (a save stores scene ids).
static func location_for_scene(host: WorldHost, scene_id: StringName) -> StringName:
	for entry_value in host.world_layout.get("locations", []):
		var entry: Dictionary = entry_value as Dictionary
		if StringName(entry.get("scene_id", &"")) == scene_id:
			return StringName(entry.get("location_id", &""))
	return &""


static func _cell_size(host: WorldHost, location_id: StringName) -> int:
	if host == null or location_id.is_empty():
		return 0
	return int(host.location_entry(location_id).get("cell_size", 0))
