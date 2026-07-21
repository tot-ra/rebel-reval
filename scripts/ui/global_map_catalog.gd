class_name GlobalMapCatalog
extends RefCounted

## Distant Estonia locations for the global map tab. These stay off the Reval
## district graph; DoorNavigator still owns travel once a plan is emitted.

const MAP_TEXTURE_PATH := "res://assets/UI/estonia_world_map.png"

## Hub marker for Reval on the Estonia basemap. Not a DoorNavigator destination.
const REVAL_HUB_ID := &"reval"

## scene_id -> catalog row. Positions are normalized against the Estonia basemap.
const LOCATIONS: Dictionary = {
	REVAL_HUB_ID: {
		"display_name": "Reval",
		"position": Vector2(0.30, 0.16),
		"gate_scene_id": &"reval_east",
		"gate_spawn_id": &"street_start",
		"arrival_spawn_id": &"",
		"is_hub": true,
		"blurb": "Walled town and campaign hub",
	},
	&"world_sacred_grove": {
		"display_name": "Sacred Grove",
		"position": Vector2(0.34, 0.38),
		"gate_scene_id": &"reval_south",
		"gate_spawn_id": &"from_world_sacred_grove",
		"arrival_spawn_id": &"from_reval_south",
		"is_hub": false,
		"blurb": "Placeholder hiis south of Reval via Karja Gate",
	},
	&"world_harju": {
		"display_name": "Harju Village",
		"position": Vector2(0.38, 0.28),
		"gate_scene_id": &"viru_gate_foreland",
		"gate_spawn_id": &"from_world_harju",
		"arrival_spawn_id": &"from_reval_east",
		"is_hub": false,
		"blurb": "Placeholder Harju farmstead via the eastern Viru road",
	},
	&"world_padise": {
		"display_name": "Padise Monastery",
		"position": Vector2(0.18, 0.24),
		"gate_scene_id": &"reval_toompea",
		"gate_spawn_id": &"from_world_padise",
		"arrival_spawn_id": &"from_reval_west",
		"is_hub": false,
		"blurb": "Placeholder western road beyond Toompea",
	},
	&"world_saaremaa": {
		"display_name": "Saaremaa",
		"position": Vector2(0.08, 0.46),
		"gate_scene_id": &"reval_harbor_north",
		"gate_spawn_id": &"from_world_saaremaa",
		"arrival_spawn_id": &"from_reval_harbor",
		"is_hub": false,
		"blurb": "Placeholder island voyage from the Trade Harbour",
	},
}


static func location_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for scene_id in LOCATIONS.keys():
		ids.append(scene_id)
	ids.sort()
	return ids


static func distant_scene_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for scene_id in LOCATIONS.keys():
		if bool(LOCATIONS[scene_id].get("is_hub", false)):
			continue
		ids.append(scene_id)
	ids.sort()
	return ids


static func has_location(scene_id: StringName) -> bool:
	return LOCATIONS.has(scene_id)


static func is_distant_scene(scene_id: StringName) -> bool:
	if not LOCATIONS.has(scene_id):
		return false
	return not bool(LOCATIONS[scene_id].get("is_hub", false))


static func get_location(scene_id: StringName) -> Dictionary:
	return LOCATIONS.get(scene_id, {}).duplicate(true)


static func display_name(scene_id: StringName) -> String:
	var row := get_location(scene_id)
	var authored := String(row.get("display_name", ""))
	if authored.is_empty():
		return LocationHud.display_name_for_scene(scene_id)
	return authored


static func layout_positions() -> Dictionary:
	var positions: Dictionary = {}
	for scene_id in LOCATIONS.keys():
		positions[scene_id] = LOCATIONS[scene_id]["position"]
	return positions


## Plan travel onto a distant placeholder, or back into Reval from one.
static func plan_travel(from_scene_id: StringName, to_scene_id: StringName) -> Dictionary:
	if to_scene_id == REVAL_HUB_ID:
		return _plan_return_to_reval(from_scene_id)
	if not is_distant_scene(to_scene_id):
		return {}
	if not DoorNavigator.has_active_scene(to_scene_id):
		return {}
	var row := get_location(to_scene_id)
	var spawn := StringName(String(row.get("arrival_spawn_id", "")))
	if spawn.is_empty() or not DoorNavigator.has_spawn(to_scene_id, spawn):
		return {}
	# From inside Reval any district may open a distant road; from another
	# distant placeholder, require an explicit return through Reval first.
	if is_distant_scene(from_scene_id) and from_scene_id != to_scene_id:
		return {}
	return {
		"scene_id": to_scene_id,
		"spawn_id": spawn,
	}


static func _plan_return_to_reval(from_scene_id: StringName) -> Dictionary:
	# Hub marker is only a return target from distant placeholders.
	if not is_distant_scene(from_scene_id):
		return {}
	var row := get_location(from_scene_id)
	var gate := StringName(String(row.get("gate_scene_id", "")))
	var spawn := StringName(String(row.get("gate_spawn_id", "")))
	if gate.is_empty() or spawn.is_empty():
		return {}
	if not DoorNavigator.has_active_scene(gate) or not DoorNavigator.has_spawn(gate, spawn):
		return {}
	return {
		"scene_id": gate,
		"spawn_id": spawn,
	}


static func load_map_texture() -> Texture2D:
	if ResourceLoader.exists(MAP_TEXTURE_PATH):
		return load(MAP_TEXTURE_PATH) as Texture2D
	return null
