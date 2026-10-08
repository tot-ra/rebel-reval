class_name GlobalMapCatalog
extends RefCounted

## Developer-traversable Estonia locations. They stay off the Reval district graph;
## this catalog owns their visible road/ferry graph while DoorNavigator owns travel.

const MAP_TEXTURE_PATH := "res://assets/UI/estonia_world_map.png"
const REVAL_HUB_ID := &"reval"

## Entries with "planned": true are charted but not yet built: they render as
## dim markers, carry no neighbors, and never enter travel planning.
## Positions are normalized against the Estonia basemap and were placed from real
## latitude/longitude fitted to its painted coastline (islands and the southern
## border are hand-drawn, so those markers follow the drawing, not the projection).
## A gate identifies a direct Reval connection; neighbors identify roads/ferries
## between mockups.
const LOCATIONS: Dictionary = {
	REVAL_HUB_ID:
	{
		"display_name": "Reval",
		"position": Vector2(0.456, 0.200),
		"is_hub": true,
		"neighbors": [&"world_sacred_grove", &"world_harju", &"world_padise", &"world_saaremaa"],
		"blurb": "Walled town and campaign hub",
	},
	&"world_sacred_grove":
	{
		"display_name": "Sacred Grove",
		"position": Vector2(0.449, 0.262),
		"gate_scene_id": &"reval_south",
		"gate_spawn_id": &"from_world_sacred_grove",
		"arrival_spawn_id": &"from_reval_south",
		"neighbors": [REVAL_HUB_ID, &"world_harju"],
		"blurb": "Harju hiis via Karja Gate and the village road",
	},
	&"world_harju":
	{
		"display_name": "Harju Village",
		"position": Vector2(0.501, 0.249),
		"gate_scene_id": &"viru_gate_foreland",
		"gate_spawn_id": &"from_world_harju",
		"arrival_spawn_id": &"from_reval_east",
		"neighbors":
		[
			REVAL_HUB_ID,
			&"world_sacred_grove",
			&"world_rebel_kings",
			&"world_kanavere",
			&"world_sojamae"
		],
		"blurb": "Harju farmstead and road junction east of Reval",
	},
	&"world_padise":
	{
		"display_name": "Padise Monastery",
		"position": Vector2(0.385, 0.271),
		"gate_scene_id": &"reval_toompea",
		"gate_spawn_id": &"from_world_padise",
		"arrival_spawn_id": &"from_reval_west",
		"neighbors": [REVAL_HUB_ID, &"world_parnu"],
		"blurb": "Western monastery road between Reval and Pärnu",
	},
	&"world_saaremaa":
	{
		"display_name": "Saaremaa",
		"position": Vector2(0.189, 0.532),
		"gate_scene_id": &"reval_harbor_north",
		"gate_spawn_id": &"from_world_saaremaa",
		"arrival_spawn_id": &"from_reval_harbor",
		"neighbors": [REVAL_HUB_ID, &"world_parnu", &"world_poide"],
		"blurb": "Kaali crater coast, rebel muster and ferries to Reval and Pärnu",
	},
	&"world_rebel_kings":
	{
		"display_name": "Rebel Kings' Camp",
		"position": Vector2(0.521, 0.293),
		"neighbors": [&"world_harju", &"world_kanavere"],
		"blurb": "Mobile Harju command camp on the uprising road",
	},
	&"world_kanavere":
	{
		"display_name": "Kanavere Bog",
		"position": Vector2(0.466, 0.342),
		"neighbors": [&"world_harju", &"world_rebel_kings", &"world_paide"],
		"blurb": "May 11 battlefield mockup and bog causeway",
	},
	&"world_sojamae":
	{
		"display_name": "Sõjamäe",
		"position": Vector2(0.477, 0.217),
		"neighbors": [&"world_harju", &"world_paide"],
		"blurb": "May 14 battlefield mockup near Ülemiste",
	},
	&"world_paide":
	{
		"display_name": "Paide Castle",
		"position": Vector2(0.532, 0.397),
		"neighbors": [&"world_kanavere", &"world_sojamae", &"world_parnu"],
		"blurb": "Order stronghold and Four Kings finale mockup",
	},
	&"world_parnu":
	{
		"display_name": "Pärnu",
		"position": Vector2(0.420, 0.562),
		"neighbors": [&"world_padise", &"world_paide", &"world_saaremaa"],
		"blurb": "Southern campaign town and coastal ferry junction",
	},
	&"world_poide":
	{
		"display_name": "Pöide Castle",
		"position": Vector2(0.257, 0.537),
		"neighbors": [&"world_saaremaa"],
		"blurb": "Saaremaa fortress campaign mockup",
	},
	&"world_rakvere":
	{
		"display_name": "Rakvere Castle",
		"position": Vector2(0.608, 0.226),
		"planned": true,
		"blurb": "Danish crown fortress in Virumaa",
	},
	&"world_haapsalu":
	{
		"display_name": "Haapsalu Castle",
		"position": Vector2(0.332, 0.376),
		"planned": true,
		"blurb": "Bishop of Ösel-Wiek seat, western siege front",
	},
	&"world_lihula":
	{
		"display_name": "Lihula Castle",
		"position": Vector2(0.365, 0.471),
		"planned": true,
		"blurb": "Leal, bishopric stronghold on the western coast",
	},
	&"world_tartu":
	{
		"display_name": "Dorpat Castle",
		"position": Vector2(0.651, 0.581),
		"planned": true,
		"blurb": "Bishopric of Dorpat, university-to-be town",
	},
	&"world_viljandi":
	{
		"display_name": "Viljandi Castle",
		"position": Vector2(0.538, 0.588),
		"planned": true,
		"blurb": "Fellin, Order castle and the rye-sack tale",
	},
	&"world_poltsamaa":
	{
		"display_name": "Põltsamaa Castle",
		"position": Vector2(0.575, 0.482),
		"planned": true,
		"blurb": "Order castle on the Põltsamaa river",
	},
	&"world_narva":
	{
		"display_name": "Narva Castle",
		"position": Vector2(0.796, 0.217),
		"planned": true,
		"blurb": "Hermann castle on the eastern frontier",
	},
	&"world_karksi":
	{
		"display_name": "Karksi-Nuia",
		"position": Vector2(0.516, 0.638),
		"planned": true,
		"blurb": "Order stronghold near the southern border",
	},
	&"world_helme":
	{
		"display_name": "Helme Castle",
		"position": Vector2(0.573, 0.676),
		"planned": true,
		"blurb": "Order castle in the southern hills",
	},
	&"world_maasilinna":
	{
		"display_name": "Maasilinna Castle",
		"position": Vector2(0.238, 0.493),
		"planned": true,
		"blurb": "Soneburg, Order castle on the Muhu strait",
	},
	&"world_karja":
	{
		"display_name": "Karja Fortress",
		"position": Vector2(0.195, 0.483),
		"planned": true,
		"blurb": "Saaremaa hillfort",
	},
}


## Built, travel-capable locations (hub plus active distant mockups).
static func location_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for scene_id in LOCATIONS.keys():
		if not is_planned(scene_id):
			ids.append(scene_id)
	ids.sort()
	return ids


## Every marker drawn on the map, including not-yet-created locations.
static func marker_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for scene_id in LOCATIONS.keys():
		ids.append(scene_id)
	ids.sort()
	return ids


static func is_planned(scene_id: StringName) -> bool:
	return bool(LOCATIONS.get(scene_id, {}).get("planned", false))


static func distant_scene_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for scene_id in location_ids():
		if not bool(LOCATIONS[scene_id].get("is_hub", false)):
			ids.append(scene_id)
	return ids


static func has_location(scene_id: StringName) -> bool:
	return LOCATIONS.has(scene_id)


static func is_distant_scene(scene_id: StringName) -> bool:
	return (
		LOCATIONS.has(scene_id)
		and not is_planned(scene_id)
		and not bool(LOCATIONS[scene_id].get("is_hub", false))
	)


static func get_location(scene_id: StringName) -> Dictionary:
	return LOCATIONS.get(scene_id, {}).duplicate(true)


static func display_name(scene_id: StringName) -> String:
	var authored := String(get_location(scene_id).get("display_name", ""))
	return authored if not authored.is_empty() else LocationHud.display_name_for_scene(scene_id)


static func layout_positions() -> Dictionary:
	var positions: Dictionary = {}
	for scene_id in LOCATIONS.keys():
		positions[scene_id] = LOCATIONS[scene_id]["position"]
	return positions


static func connections() -> Array[Dictionary]:
	var edges: Array[Dictionary] = []
	var seen: Dictionary = {}
	for from_id in location_ids():
		for to_id in _neighbors(from_id):
			if not LOCATIONS.has(to_id):
				continue
			var pair: Array[String] = [String(from_id), String(to_id)]
			pair.sort()
			var key := "%s|%s" % pair
			if seen.has(key):
				continue
			seen[key] = true
			edges.append({"from": from_id, "to": to_id})
	return edges


## Plans one authored edge. Long-distance travel deliberately follows the graph
## instead of teleporting between unrelated campaign sites.
static func plan_travel(from_scene_id: StringName, to_scene_id: StringName) -> Dictionary:
	if to_scene_id == REVAL_HUB_ID:
		return _plan_return_to_reval(from_scene_id)
	if not is_distant_scene(to_scene_id) or not DoorNavigator.has_active_scene(to_scene_id):
		return {}
	var from_marker := REVAL_HUB_ID if not is_distant_scene(from_scene_id) else from_scene_id
	if not _neighbors(from_marker).has(to_scene_id):
		return {}
	var spawn := _arrival_spawn(from_scene_id, to_scene_id)
	if spawn.is_empty() or not DoorNavigator.has_spawn(to_scene_id, spawn):
		return {}
	return {"scene_id": to_scene_id, "spawn_id": spawn}


static func _plan_return_to_reval(from_scene_id: StringName) -> Dictionary:
	if not is_distant_scene(from_scene_id) or not _neighbors(from_scene_id).has(REVAL_HUB_ID):
		return {}
	var row := get_location(from_scene_id)
	var gate := StringName(String(row.get("gate_scene_id", "")))
	var spawn := StringName(String(row.get("gate_spawn_id", "")))
	if gate.is_empty() or spawn.is_empty():
		return {}
	# ADR 0031: the legacy gate districts no longer exist in the manifest; plan
	# against the city destination DoorNavigator.go_to_scene will redirect to.
	var routed: Array = CityTravel.redirect(gate, spawn)
	gate = routed[0]
	spawn = routed[1]
	if not DoorNavigator.has_active_scene(gate) or not DoorNavigator.has_spawn(gate, spawn):
		return {}
	return {"scene_id": gate, "spawn_id": spawn}


static func _arrival_spawn(from_scene_id: StringName, to_scene_id: StringName) -> StringName:
	if is_distant_scene(from_scene_id):
		return StringName("from_%s" % String(from_scene_id))
	return StringName(String(get_location(to_scene_id).get("arrival_spawn_id", "")))


static func _neighbors(scene_id: StringName) -> Array:
	return get_location(scene_id).get("neighbors", [])


static func load_map_texture() -> Texture2D:
	if ResourceLoader.exists(MAP_TEXTURE_PATH):
		return load(MAP_TEXTURE_PATH) as Texture2D
	return null
