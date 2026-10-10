class_name CityTravel
extends RefCounted

## Routes the game's scene transitions into the seamless city (ADR 0031).
## Every old Reval district (and the exits of interiors and distant regions
## that led back to one) now arrives in the city at a matching place, so the
## forge door, interior exits, district fast travel and returns from Padise,
## Harju or Saaremaa keep working without the district maps.

const Fort := preload("res://scripts/city/city_fortification_builder.gd")
const CITY_SCENE_ID := &"reval_city"
const DEFAULT_SPAWN := &"poi.forum"

## old scene id -> {old spawn id -> city spawn id, "*" -> default}
const REDIRECTS := {
	&"reval_east": {&"forge": &"kalev_smithy", &"*": &"gate.viru"},
	&"reval_center": {&"*": &"poi.forum"},
	&"reval_north": {&"*": &"poi.granary.pikk"},
	&"reval_monastery": {&"*": &"landmark.st_olaf"},
	&"reval_south":
	{&"from_world_sacred_grove": &"gate.harju.outside", &"*": &"landmark.st_nicholas"},
	&"reval_toompea": {&"from_world_padise": &"road.toompea_west", &"*": &"poi.barracks.castle"},
	&"reval_archbishops_garden": {&"*": &"poi.well.bishop_garden"},
	&"viru_gate_foreland": {&"*": &"gate.viru.outside"},
	&"reval_harbor_north": {&"*": &"poi.fish_landing"},
	&"reval_harbor_east": {&"*": &"suburb.kalarand"},
}

## Spawn ids the city scene accepts (registered in the transition manifest).
const SPAWNS: Array[StringName] = [
	&"poi.forum",
	&"kalev_smithy",
	&"gate.viru",
	&"gate.viru.outside",
	&"gate.harju.outside",
	&"gate.karja.outside",
	&"gate.coastal",
	&"poi.fish_landing",
	&"poi.granary.pikk",
	&"landmark.st_olaf",
	&"landmark.st_nicholas",
	&"road.toompea_west",
	&"poi.barracks.castle",
	&"poi.well.bishop_garden",
	&"suburb.kalarand",
]

static var pending_spawn: StringName = &""


## [scene_id, spawn_id] after redirecting old Reval districts into the city.
static func redirect(scene_id: StringName, spawn_id: StringName) -> Array:
	if not REDIRECTS.has(scene_id):
		return [scene_id, spawn_id]
	var table: Dictionary = REDIRECTS[scene_id]
	var city_spawn: StringName = table.get(spawn_id, table.get(&"*", DEFAULT_SPAWN))
	return [CITY_SCENE_ID, city_spawn]


## `scene_id` is the scene asking: the city, or a regional site scene such as
## `world_paide` (ADR 0042) whose arrival spawns come from the travel manifest.
static func consume_pending_spawn(scene_id: StringName = CITY_SCENE_ID) -> StringName:
	var spawn := pending_spawn
	if spawn.is_empty() and DoorNavigator.pending_spawn_scene_id == scene_id:
		spawn = DoorNavigator.pending_spawn_id
		DoorNavigator.clear_pending_spawn()
	pending_spawn = &""
	return spawn


## World XZ of a spawn id: a gate (just inside, or `.outside`), a point of
## interest, a landmark's door, a suburb, the head of an extramural road, or
## Kalev's smithy door.
static func spawn_position(plan: CityPlan, spawn_id: String) -> Vector2:
	# Regional sites (ADR 0042) list their travel arrivals (`from_world_*`) in the plan.
	var arrival := plan.arrival_spawn(spawn_id)
	if not arrival.is_empty():
		return Vector2(arrival["at"][0], arrival["at"][1])
	var outside := spawn_id.ends_with(".outside")
	var id := spawn_id.trim_suffix(".outside")
	var g := plan.gate(id)
	if not g.is_empty():
		var at := Vector2(g["at"][0], g["at"][1])
		var along := Vector2(cos(float(g["angle"])), sin(float(g["angle"])))
		var inward := Vector2(-along.y, along.x)
		var field := Fort._toward_field(plan, at, along, 1.0) - at
		inward = -field.normalized() if not field.is_zero_approx() else inward
		return at + inward * (-12.0 if outside else 7.0)
	var poi := plan.point_of_interest(id)
	if not poi.is_empty():
		return Vector2(poi["at"][0], poi["at"][1])
	var index := building_index(plan, id)
	if index >= 0:
		var b: Dictionary = plan.buildings[index]
		if b.get("door") != null:
			var door := Vector2(b["door"][0], b["door"][1])
			var out := Vector2(cos(float(b["door"][2])), sin(float(b["door"][2])))
			return door + out * 2.5
	for d: Dictionary in plan.data.get("districts", []):
		if String(d["id"]).trim_prefix("district.") == id.trim_prefix("suburb."):
			var c := Vector2.ZERO
			var pts := CityPlan.points(d["polygon"])
			for p in pts:
				c += p
			return c / maxf(pts.size(), 1)
	for s: Dictionary in plan.streets:
		if String(s["id"]) == id:
			return Vector2(s["points"][0][0], s["points"][0][1])
	var forum := plan.point_of_interest(String(DEFAULT_SPAWN))
	if not forum.is_empty():
		return Vector2(forum["at"][0], forum["at"][1])
	var fallback := plan.arrival_spawn(String(plan.site_info().get("default_spawn", "")))
	if not fallback.is_empty():
		return Vector2(fallback["at"][0], fallback["at"][1])
	return plan.bounds.get_center()


static func building_index(plan: CityPlan, landmark_or_id: String) -> int:
	for i in plan.buildings.size():
		var b: Dictionary = plan.buildings[i]
		if b["landmark_id"] == landmark_or_id or b["id"] == landmark_or_id:
			return i
		if landmark_or_id == "kalev_smithy" and b["landmark_id"] == "landmark.kalev_smithy":
			return i
	return -1
