class_name CityFauna
extends Node3D

## Animals of the seamless city (ADR 0031): cats and dogs about the forum, quay
## and granary, rats in the granary, draught horses at the gates, smithy, brewery
## and castle, hens, geese, pigs and cattle in the Karja farmsteads, and grazing
## sheep, cattle and goats on fallow fields, with hares and foxes on the field
## margin. Placements derive from plan points of interest, gates and fields, so
## they follow the plan. Actors are the game's licensed storybook models (the
## same loader the district maps used), visual only: no collision, no GameState.
##
## Only the nearest groups exist: a group is built when Kalev is within
## SPAWN_RANGE of it and freed beyond DESPAWN_RANGE, never more than MAX_ACTORS
## at once, so the city pays for a handful of skinned rigs, not for 100.

const GroundWander := preload("res://scripts/map/view3d/map_view_ground_wander.gd")
const MammalSpecies := preload("res://scripts/map/view3d/map_view_mammal_species.gd")
const MedievalAnimalModels := preload("res://scripts/map/view3d/map_view_medieval_animal_models.gd")
const UrbanFauna := preload("res://scripts/map/view3d/map_view_urban_fauna.gd")

const SEED_KEY := &"reval_city_fauna"
## The storybook models are authored for a 2.0-unit person; Kalev is 1.83 m here.
const MODEL_SCALE := 1.83 / 2.0
const SPAWN_RANGE := 85.0
const DESPAWN_RANGE := 120.0
const MAX_ACTORS := 18
const STREAM_INTERVAL := 0.5
## A home must be dry land, off the foundations and off any landmark site.
const MIN_GROUND := 0.8
const MAX_SLOPE := 0.3
const NUDGE_STEP := 1.5
const NUDGE_RINGS := 24
const NUDGE_BEARINGS := 12
const BUILDING_CLEARANCE := 0.6

const BEHAVIOR_TETHER := &"tether"
const BEHAVIOR_WANDER := &"wander"
const BEHAVIOR_PEN := &"pen"
const BEHAVIOR_GRAZE := &"graze"
const BEHAVIOR_FLEE := &"flee"

const GOAT := &"goat"
const FLEE_RADIUS := 5.5
const FLEE_SPEED := 4.2
## Authored anchors: {anchor: POI id, or "gate.x" for a spot outside that gate;
## offset: metres from the anchor; species; behavior; radius: roaming yard;
## count: animals in the group, fanned around the offset}.
const ANCHORS: Array[Dictionary] = [
	{"anchor": "poi.forum", "offset": Vector2(12, 6), "species": &"dog", "behavior": BEHAVIOR_WANDER, "radius": 6.0, "count": 1},  # gdlint: ignore=max-line-length
	{"anchor": "poi.forum", "offset": Vector2(-9, 5), "species": &"cat", "behavior": BEHAVIOR_WANDER, "radius": 3.5, "count": 1},  # gdlint: ignore=max-line-length
	{"anchor": "poi.forum", "offset": Vector2(19, -5), "species": &"horse", "behavior": BEHAVIOR_TETHER, "radius": 2.4, "count": 1},  # gdlint: ignore=max-line-length
	{"anchor": "poi.forum", "offset": Vector2(-15, -7), "species": &"chicken", "behavior": BEHAVIOR_WANDER, "radius": 3.0, "count": 3},  # gdlint: ignore=max-line-length
	{"anchor": "poi.fish_landing", "offset": Vector2(-8, 14), "species": &"cat", "behavior": BEHAVIOR_WANDER, "radius": 5.0, "count": 2},  # gdlint: ignore=max-line-length
	{"anchor": "poi.fish_landing", "offset": Vector2(14, 16), "species": &"dog", "behavior": BEHAVIOR_WANDER, "radius": 6.0, "count": 1},  # gdlint: ignore=max-line-length
	{"anchor": "poi.granary.pikk", "offset": Vector2(5, 7), "species": &"rat", "behavior": BEHAVIOR_FLEE, "radius": 3.0, "count": 2},  # gdlint: ignore=max-line-length
	{"anchor": "poi.granary.pikk", "offset": Vector2(-6, 9), "species": &"cat", "behavior": BEHAVIOR_WANDER, "radius": 3.0, "count": 1},  # gdlint: ignore=max-line-length
	{"anchor": "poi.bakery.lai", "offset": Vector2(5, 5), "species": &"cat", "behavior": BEHAVIOR_WANDER, "radius": 3.0, "count": 1},  # gdlint: ignore=max-line-length
	{"anchor": "poi.brewery.vene", "offset": Vector2(8, 8), "species": &"horse", "behavior": BEHAVIOR_TETHER, "radius": 2.4, "count": 1},  # gdlint: ignore=max-line-length
	{"anchor": "poi.smithy.harju", "offset": Vector2(7, 6), "species": &"horse", "behavior": BEHAVIOR_TETHER, "radius": 2.4, "count": 1},  # gdlint: ignore=max-line-length
	{"anchor": "poi.smithy.harju", "offset": Vector2(-6, 8), "species": &"dog", "behavior": BEHAVIOR_WANDER, "radius": 4.0, "count": 1},  # gdlint: ignore=max-line-length
	{"anchor": "poi.barracks.castle", "offset": Vector2(9, 8), "species": &"horse", "behavior": BEHAVIOR_TETHER, "radius": 3.0, "count": 2},  # gdlint: ignore=max-line-length
	{"anchor": "poi.slaughter.karja", "offset": Vector2(8, 9), "species": &"pig", "behavior": BEHAVIOR_PEN, "radius": 4.0, "count": 2},  # gdlint: ignore=max-line-length
	{"anchor": "poi.slaughter.karja", "offset": Vector2(-9, 10), "species": &"cow", "behavior": BEHAVIOR_PEN, "radius": 4.0, "count": 1},  # gdlint: ignore=max-line-length
	{"anchor": "poi.slaughter.karja", "offset": Vector2(2, 16), "species": &"chicken", "behavior": BEHAVIOR_WANDER, "radius": 3.0, "count": 3},  # gdlint: ignore=max-line-length
	{"anchor": "poi.mill.karja", "offset": Vector2(9, 8), "species": &"goose", "behavior": BEHAVIOR_WANDER, "radius": 5.0, "count": 3},  # gdlint: ignore=max-line-length
	{"anchor": "poi.well.yard.viru", "offset": Vector2(6, 5), "species": &"chicken", "behavior": BEHAVIOR_WANDER, "radius": 3.0, "count": 2},  # gdlint: ignore=max-line-length
	{"anchor": "poi.well.yard.harju", "offset": Vector2(6, 5), "species": GOAT, "behavior": BEHAVIOR_PEN, "radius": 3.0, "count": 2},  # gdlint: ignore=max-line-length
	{"anchor": "poi.well.yard.pikk_north", "offset": Vector2(5, 6), "species": &"chicken", "behavior": BEHAVIOR_WANDER, "radius": 3.0, "count": 2},  # gdlint: ignore=max-line-length
	{"anchor": "gate.viru", "offset": Vector2(0, 14), "species": &"horse", "behavior": BEHAVIOR_TETHER, "radius": 2.4, "count": 1},  # gdlint: ignore=max-line-length
	{"anchor": "gate.karja", "offset": Vector2(0, 16), "species": &"cow", "behavior": BEHAVIOR_PEN, "radius": 5.0, "count": 2},  # gdlint: ignore=max-line-length
	{"anchor": "gate.karja", "offset": Vector2(8, 18), "species": &"sheep", "behavior": BEHAVIOR_PEN, "radius": 5.0, "count": 3},  # gdlint: ignore=max-line-length
	{"anchor": "gate.harju", "offset": Vector2(0, 14), "species": &"horse", "behavior": BEHAVIOR_TETHER, "radius": 2.4, "count": 1},  # gdlint: ignore=max-line-length
	{"anchor": "gate.coastal", "offset": Vector2(0, 14), "species": &"dog", "behavior": BEHAVIOR_WANDER, "radius": 5.0, "count": 1},  # gdlint: ignore=max-line-length
]
## Fallow fields graze a herd (cycled by field index); every third ploughed
## field has a hare, the southernmost ones a fox.
const FALLOW_HERDS: Array[Dictionary] = [
	{"species": &"sheep", "count": 3},
	{"species": &"cow", "count": 2},
	{"species": GOAT, "count": 2},
]
const FIELD_FOX_MIN_Z := 470.0
## Outbuilding type -> the animals kept at it.
const YARD_STOCK := {
	"hen_house": {"species": &"chicken", "behavior": BEHAVIOR_WANDER, "radius": 3.5, "count": 3},
	"pigsty": {"species": &"pig", "behavior": BEHAVIOR_PEN, "radius": 3.0, "count": 2},
	"byre": {"species": &"cow", "behavior": BEHAVIOR_PEN, "radius": 4.5, "count": 2},
	"sheep_shed": {"species": &"sheep", "behavior": BEHAVIOR_PEN, "radius": 4.0, "count": 3},
}

var plan: CityPlan
var player: Node2D
var _groups: Array[Dictionary] = []
var _live: Dictionary = {}
var _since := STREAM_INTERVAL


static func create(city_plan: CityPlan, kalev: Node2D) -> CityFauna:
	var node := CityFauna.new()
	node.name = "CityFauna"
	node.plan = city_plan
	node.player = kalev
	node._groups = groups_for(city_plan)
	return node


## Deterministic placement groups for a plan: {id, species, behavior, radius,
## members: Array[Vector2] world xz homes}. Pure data, so tests and tools can
## audit the layout without building any actors.
static func groups_for(city_plan: CityPlan) -> Array[Dictionary]:
	var groups: Array[Dictionary] = []
	for entry: Dictionary in ANCHORS:
		var at := _anchor_point(city_plan, String(entry["anchor"]))
		if at == Vector2.INF:
			continue
		var id := "%s/%s/%d" % [entry["anchor"], entry["species"], groups.size()]
		_add(groups, _group(city_plan, id, entry, at + (entry["offset"] as Vector2)))
	var fields: Array = city_plan.data.get("fields", [])
	for i in fields.size():
		var field: Dictionary = fields[i]
		var centre := _centroid(CityPlan.points(field["polygon"]))
		if not bool(field["ploughed"]):
			var herd: Dictionary = FALLOW_HERDS[i % FALLOW_HERDS.size()]
			var entry := {
				"species": herd["species"],
				"behavior": BEHAVIOR_GRAZE,
				"radius": 7.0,
				"count": herd["count"],
			}
			_add(groups, _group(city_plan, "%s/%s" % [field["id"], entry["species"]], entry, centre))
		elif centre.y > FIELD_FOX_MIN_Z and i % 2 == 0:
			var fox := {"species": &"red_fox", "behavior": BEHAVIOR_FLEE, "radius": 9.0, "count": 1}
			_add(groups, _group(city_plan, "%s/fox" % field["id"], fox, centre))
		elif i % 3 == 0:
			var hare := {"species": &"hare", "behavior": BEHAVIOR_FLEE, "radius": 8.0, "count": 1}
			_add(groups, _group(city_plan, "%s/hare" % field["id"], hare, centre))
	for pasture: Dictionary in city_plan.data.get("pastures", []):
		var poly := CityPlan.points(pasture["polygon"])
		var centre := _centroid(poly)
		var spread := 0.0
		for q in poly:
			spread = maxf(spread, q.distance_to(centre))
		var pen: bool = pasture["fence"]
		for stock: Dictionary in pasture["stock"]:
			var species := StringName(stock["species"])
			var entry := {
				"species": GOAT if species == &"goat" else species,
				"behavior": BEHAVIOR_WANDER if species == &"goose" else (BEHAVIOR_PEN if pen else BEHAVIOR_GRAZE),  # gdlint: ignore=max-line-length
				"radius": maxf(spread * 0.6, 4.0),
				"count": int(stock["count"]),
			}
			_add(groups, _group(city_plan, "%s/%s" % [pasture["id"], species], entry, centre))
	# Yard animals live at their own outbuildings (farm_outbuildings in the plan).
	for b: Dictionary in city_plan.data.get("buildings", []):
		if String(b.get("kind", "")) != "outbuilding" or not YARD_STOCK.has(String(b["type"])):
			continue
		var stock: Dictionary = YARD_STOCK[String(b["type"])]
		var yard := _centroid(CityPlan.points(b["footprint"])) + Vector2(3.5, 3.5)
		var entry := {
			"species": stock["species"],
			"behavior": stock["behavior"],
			"radius": stock["radius"],
			"count": stock["count"],
		}
		_add(groups, _group(city_plan, "%s/%s" % [b["id"], stock["species"]], entry, yard))
	return groups


static func _add(groups: Array[Dictionary], group: Dictionary) -> void:
	if not group.is_empty():
		groups.append(group)


static func _anchor_point(city_plan: CityPlan, anchor: String) -> Vector2:
	if anchor.begins_with("gate."):
		var gate := city_plan.gate(anchor)
		if gate.is_empty():
			return Vector2.INF
		# The gate's field side: away from the spawn point inside the walls.
		var at := Vector2(gate["at"][0], gate["at"][1])
		var inside := CityTravel.spawn_position(city_plan, anchor)
		return at + (at - inside).normalized() * 6.0
	var poi := city_plan.point_of_interest(anchor)
	if poi.is_empty():
		return Vector2.INF
	return Vector2(poi["at"][0], poi["at"][1])


static func _centroid(points: PackedVector2Array) -> Vector2:
	var sum := Vector2.ZERO
	for p in points:
		sum += p
	return sum / maxf(points.size(), 1)


static func _group(city_plan: CityPlan, id: String, entry: Dictionary, at: Vector2) -> Dictionary:
	var members: Array[Vector2] = []
	var count := int(entry["count"])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	var home := nudge_to_dry_land(city_plan, at)
	if home == Vector2.INF:
		return {}
	for k in count:
		var angle := rng.randf_range(0.0, TAU)
		var spread := 0.0 if count == 1 else rng.randf_range(0.8, 1.6) * sqrt(float(count))
		var candidate := home + Vector2(cos(angle), sin(angle)) * spread
		members.append(candidate if _is_dry(city_plan, candidate) else home)
	return {
		"id": id,
		"species": entry["species"],
		"behavior": entry["behavior"],
		"radius": float(entry["radius"]),
		"centre": home,
		"members": members,
	}


static func _is_dry(city_plan: CityPlan, xz: Vector2) -> bool:
	return (
		city_plan.ground_height(xz) > MIN_GROUND
		and not city_plan.in_moat(xz, 1.5)
		and city_plan.slope_at(xz) < MAX_SLOPE
		and city_plan.site_at(xz) == null
		and _clear_of_buildings(city_plan, xz)
	)


static func _clear_of_buildings(city_plan: CityPlan, xz: Vector2) -> bool:
	for index in city_plan.buildings_near(xz, BUILDING_CLEARANCE + 1.0):
		if _footprint_rect(city_plan, index).grow(BUILDING_CLEARANCE).has_point(xz):
			return false
	return true


static func _footprint_rect(city_plan: CityPlan, index: int) -> Rect2:
	var points := CityPlan.points(city_plan.buildings[index]["footprint"])
	var rect := Rect2(points[0], Vector2.ZERO)
	for p in points:
		rect = rect.expand(p)
	return rect


## Search outward in rings for the nearest point that is dry, gentle, off every
## foundation and off landmark sites; deterministic (fixed bearings per ring).
## Returns Vector2.INF when the neighbourhood is solid, so the group is dropped.
static func nudge_to_dry_land(city_plan: CityPlan, xz: Vector2) -> Vector2:
	if _is_dry(city_plan, xz):
		return xz
	for ring in range(1, NUDGE_RINGS + 1):
		for bearing in NUDGE_BEARINGS:
			var a := TAU * float(bearing) / NUDGE_BEARINGS
			var candidate := xz + Vector2(cos(a), sin(a)) * NUDGE_STEP * ring
			if _is_dry(city_plan, candidate):
				return candidate
	return Vector2.INF


func live_actor_count() -> int:
	var count := 0
	for actors: Array in _live.values():
		count += actors.size()
	return count


func group_count() -> int:
	return _groups.size()


func _process(delta: float) -> void:
	if player == null:
		return
	var me := CityPlan.to_world_xz(player.global_position)
	_since += delta
	if _since >= STREAM_INTERVAL:
		_since = 0.0
		_stream(me)
	var listener := Vector3(me.x, plan.ground_height(me), me.y)
	for actors: Array in _live.values():
		for actor: Node3D in actors:
			_advance(actor, listener, delta)


func _stream(me: Vector2) -> void:
	for id: String in _live.keys():
		var group := _group_by_id(id)
		if (group["centre"] as Vector2).distance_to(me) > DESPAWN_RANGE:
			for actor: Node3D in _live[id]:
				actor.queue_free()
			_live.erase(id)
	var wanted: Array[Dictionary] = []
	for group in _groups:
		if _live.has(group["id"]):
			continue
		if (group["centre"] as Vector2).distance_to(me) <= SPAWN_RANGE:
			wanted.append(group)
	wanted.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return (a["centre"] as Vector2).distance_to(me) < (b["centre"] as Vector2).distance_to(me)
	)
	for group in wanted:
		if live_actor_count() + (group["members"] as Array).size() > MAX_ACTORS:
			break
		_spawn(group)


func _group_by_id(id: String) -> Dictionary:
	for group in _groups:
		if group["id"] == id:
			return group
	return {}


func _spawn(group: Dictionary) -> void:
	var actors: Array[Node3D] = []
	var members: Array = group["members"]
	var species: StringName = group["species"]
	for k in members.size():
		var home_xz: Vector2 = members[k]
		var seed_value := hash([group["id"], k])
		var actor := Node3D.new()
		actor.name = "Fauna_%s_%d" % [String(group["id"]).replace("/", "_").replace(".", "_"), k]
		var ground := plan.ground_height(home_xz)
		actor.position = Vector3(home_xz.x, ground, home_xz.y)
		actor.rotation.y = float(seed_value % 628) / 100.0
		actor.scale = Vector3.ONE * MODEL_SCALE
		add_child(actor)
		var model := MedievalAnimalModels.add_model(actor, species, seed_value)
		if model == null:
			actor.queue_free()
			continue
		if model.has_method("apply_coat"):
			model.apply_coat(seed_value)
		UrbanFauna.snap_actor_visual_to_ground(actor, ground)
		actor.set_meta(&"lift", actor.position.y - ground)
		actor.set_meta(&"behavior", group["behavior"])
		var home := Vector3(home_xz.x, actor.position.y, home_xz.y)
		var config := _wander_config(group["behavior"], home, float(group["radius"]))
		config["blocked_rects"] = _blocked_rects(home_xz, float(group["radius"]))
		GroundWander.setup(actor, SEED_KEY, seed_value & 0xFFFFFF, config)
		actors.append(actor)
	_live[group["id"]] = actors


static func _wander_config(behavior: StringName, home: Vector3, radius: float) -> Dictionary:
	var config := {"home": home, "radius": radius}
	match behavior:
		BEHAVIOR_TETHER:
			config["speed"] = 0.24
			config["roam_scale"] = 0.42
			config["pause_range"] = Vector2(2.4, 6.0)
		BEHAVIOR_PEN:
			config["speed"] = 0.3
			config["roam_scale"] = 0.62
			config["pause_range"] = Vector2(1.6, 4.4)
		BEHAVIOR_GRAZE:
			config["speed"] = 0.18
			config["roam_scale"] = 0.7
			config["pause_range"] = Vector2(4.0, 9.0)
		BEHAVIOR_FLEE:
			config["speed"] = 0.9
			config["roam_scale"] = 0.78
			config["pause_range"] = Vector2(0.8, 2.6)
			config["flee_speed"] = FLEE_SPEED
			config["flee_radius"] = FLEE_RADIUS
		_:
			config["speed"] = 0.62
			config["roam_scale"] = 0.8
			config["pause_range"] = Vector2(0.9, 3.2)
	return config


## Foundations around a yard, as footprint rectangles grown by body clearance,
## in the shape GroundWander expects.
func _blocked_rects(home_xz: Vector2, radius: float) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for index in plan.buildings_near(home_xz, radius + 4.0):
		rects.append(_footprint_rect(plan, index).grow(BUILDING_CLEARANCE))
	return rects


func _advance(actor: Node3D, listener: Vector3, delta: float) -> void:
	var previous := actor.position
	GroundWander.advance(actor, SEED_KEY, listener, delta)
	actor.position.y = (
		plan.ground_height(Vector2(actor.position.x, actor.position.z))
		+ float(actor.get_meta(&"lift", 0.0))
	)
	MedievalAnimalModels.sync_animation(actor, previous, delta)
