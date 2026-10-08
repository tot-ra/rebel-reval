class_name CityNpcs
extends Node2D

## Posted and working people of the seamless city (ADR 0031): the people at work
## on landmark sites and the farm hands in the fields. The residents themselves
## (townsfolk, market folk) and the gate garrisons and watch patrols are census
## citizens on duty (CityCitizens, docs/SYSTEMS/GATE_GARRISONS.md).
## Bodies are logic actors; MapViewRuntime mirrors their rigs.

const SITE_PEOPLE_RANGE := 45.0
## Farm hands on spring-sown fields and garden beds, present only near Kalev.
const FIELD_WORKER_RANGE := 75.0
const MAX_FIELD_WORKERS := 6
const FIELD_WORKER_SPEED := 0.55
const FIELD_RIGS: Array[String] = [
	"citizen_m_adult_sturdy", "citizen_m_adult_average", "citizen_m_elder_thin",
	"citizen_f_adult_average", "citizen_f_adult_sturdy",
]


## A logic body walking a street centreline back and forth (metres, world xz).
class Walker:
	extends CharacterBody2D

	var rig_scene: PackedScene
	var path: PackedVector2Array
	var speed := 1.2
	var index := 0
	var step := 1
	var at := Vector2.ZERO
	var _facing := Vector2.DOWN

	func _ready() -> void:
		add_to_group(&"map_view_actor")

	func seat(points: PackedVector2Array, start: int, forward: bool) -> void:
		path = points
		index = clampi(start, 0, points.size() - 1)
		step = 1 if forward else -1
		at = points[index]
		global_position = CityPlan.to_logic(at)

	func _physics_process(delta: float) -> void:
		if path.size() < 2:
			velocity = Vector2.ZERO
			return
		var target := path[index]
		var to := target - at
		var move := speed * delta
		if to.length() <= move:
			at = target
			if index + step < 0 or index + step >= path.size():
				step = -step
			index += step
		else:
			at += to.normalized() * move
			_facing = to.normalized()
		var logic := CityPlan.to_logic(at)
		velocity = (logic - global_position) / maxf(delta, 0.0001)
		global_position = logic

	func view_facing() -> Vector2:
		return _facing

	func view_animation() -> StringName:
		return &"walk" if velocity.length_squared() > 4.0 else &"idle"


var plan: CityPlan
var player: Node2D
var citizens: CityCitizens
var _since := 0.0
## Site id -> the CitySiteActors present while Kalev is near that site.
var _site_people: Dictionary = {}
var _field_sites: Array[Dictionary] = []
## Field id -> the Walker working it.
var _field_workers: Dictionary = {}


static func create(city_plan: CityPlan, kalev: Node2D) -> CityNpcs:
	var node := CityNpcs.new()
	node.name = "CityNpcs"
	node.plan = city_plan
	node.player = kalev
	return node


func _ready() -> void:
	if player != null:
		_stream_site_people(CityPlan.to_world_xz(player.global_position))
	_collect_field_sites()
	citizens = CityCitizens.create(plan, player)
	add_child(citizens)


func _process(delta: float) -> void:
	_since += delta
	if _since < 1.0 or player == null:
		return
	_since = 0.0
	var me := CityPlan.to_world_xz(player.global_position)
	_stream_site_people(me)
	_stream_field_workers(me)


func _walker(rig: PackedScene, speed: float) -> Walker:
	var w := Walker.new()
	w.rig_scene = rig
	w.speed = speed
	add_child(w)
	return w


## People at work in landmark sites (ADR 0032) are only present while Kalev is
## within SITE_PEOPLE_RANGE of the site, so their rigs cost nothing elsewhere.
func _stream_site_people(me: Vector2) -> void:
	for site in plan.sites:
		var near := site.bounds().grow(SITE_PEOPLE_RANGE).has_point(me)
		if near and not _site_people.has(site.id):
			var actors: Array[CitySiteActor] = []
			for person: Dictionary in site.people:
				var actor := CitySiteActor.create(person)
				add_child(actor)
				actors.append(actor)
			_site_people[site.id] = actors
		elif not near and _site_people.has(site.id):
			for actor: CitySiteActor in _site_people[site.id]:
				actor.queue_free()
			_site_people.erase(site.id)


## Spring-sown fields and garden beds, each with the furrow line a worker walks.
func _collect_field_sites() -> void:
	for f in CityFarmland.features_for(plan):
		if f["kind"] != &"field" or not (f["sowing"] == &"spring" or f["sowing"] == &"garden"):
			continue
		if hash(f["id"]) % 2 != 0:
			continue
		var poly: PackedVector2Array = f["polygon"]
		var u := (poly[1] - poly[0]).normalized()
		var v := (poly[3] - poly[0]).normalized()
		var length := poly[0].distance_to(poly[1])
		var width := poly[0].distance_to(poly[3])
		var lane := hash([f["id"], "lane"]) % 5
		var origin := poly[0] + v * (width * (0.25 + 0.1 * lane))
		(
			_field_sites
			. append(
				{
					"id": f["id"],
					"centre": f["centre"],
					"path": PackedVector2Array([origin + u * 3.0, origin + u * (length - 3.0)]),
					"rig": FIELD_RIGS[hash(f["id"]) % FIELD_RIGS.size()],
				}
			)
		)


## Farm hands walk their furrow back and forth while Kalev is near the field.
func _stream_field_workers(me: Vector2) -> void:
	for site in _field_sites:
		var id: String = site["id"]
		var near := (site["centre"] as Vector2).distance_to(me) <= FIELD_WORKER_RANGE
		if near and not _field_workers.has(id) and _field_workers.size() < MAX_FIELD_WORKERS:
			var w := _walker(load("res://assets/characters/variants/%s.tscn" % site["rig"]), FIELD_WORKER_SPEED)  # gdlint: ignore=max-line-length
			w.name = "Farmhand_%s" % id.replace(".", "_")
			w.seat(site["path"], hash(id) % 2, hash(id) % 3 != 0)
			_field_workers[id] = w
		elif not near and _field_workers.has(id):
			(_field_workers[id] as Node).queue_free()
			_field_workers.erase(id)
