class_name CityNpcs
extends Node2D

## Posted and working people of the seamless city (ADR 0031): watchmen at every
## town gate and Danish men-at-arms at the Toompea gates, the town watch walking
## Pikk, Lai and Vene, and the people at work on landmark sites. The residents
## themselves (townsfolk, market folk) are the census citizens of CityCitizens.
## Bodies are logic actors; MapViewRuntime mirrors their rigs.

const WATCHMAN := preload("res://assets/characters/variants/watchman.tscn")
const MAN_AT_ARMS := preload("res://assets/characters/variants/danish_warrior.tscn")
const SERGEANT := preload("res://assets/characters/variants/sergeant.tscn")
const CASTLE_GATES: Array[String] = ["gate.long_hill", "gate.short_hill"]
const PATROL_STREETS: Array[String] = ["Pikk", "Lai", "Vene"]
const PATROL_SPEED := 1.3
const SITE_PEOPLE_RANGE := 45.0


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
var _since := 0.0
var citizens: CityCitizens
## Site id -> the CitySiteActors present while Kalev is near that site.
var _site_people: Dictionary = {}


static func create(city_plan: CityPlan, kalev: Node2D) -> CityNpcs:
	var node := CityNpcs.new()
	node.name = "CityNpcs"
	node.plan = city_plan
	node.player = kalev
	return node


func _ready() -> void:
	_place_guards()
	_place_patrols()
	if player != null:
		_stream_site_people(CityPlan.to_world_xz(player.global_position))
	citizens = CityCitizens.create(plan, player)
	add_child(citizens)


func _process(delta: float) -> void:
	_since += delta
	if _since < 1.0 or player == null:
		return
	_since = 0.0
	_stream_site_people(CityPlan.to_world_xz(player.global_position))


func _walker(rig: PackedScene, speed: float) -> Walker:
	var w := Walker.new()
	w.rig_scene = rig
	w.speed = speed
	add_child(w)
	return w


## Two guards flank the town side of every gate passage.
func _place_guards() -> void:
	for g: Dictionary in plan.data.get("gates", []):
		var id := String(g["id"])
		var inside := CityTravel.spawn_position(plan, id)
		var at := Vector2(g["at"][0], g["at"][1])
		var inward := (inside - at).normalized()
		var across := Vector2(-inward.y, inward.x)
		var rig := MAN_AT_ARMS if id in CASTLE_GATES else WATCHMAN
		for side: float in [-1.0, 1.0]:
			var post := StaticNpcActor.new()
			post.rig_scene = SERGEANT if side > 0 and id == "gate.viru" else rig
			post.name = "Guard_%s_%d" % [id.replace(".", "_"), int(side)]
			add_child(post)
			post.configure(
				player, CityPlan.to_logic(at + inward * 8.5 + across * side * 2.8), -inward
			)


func _place_patrols() -> void:
	for name in PATROL_STREETS:
		var best := PackedVector2Array()
		for s: Dictionary in plan.data.get("streets", []):
			var pts := CityPlan.points(s["points"])
			if String(s.get("name", "")) == name and pts.size() > best.size():
				best = pts
		if best.size() < 2:
			continue
		var w := _walker(WATCHMAN, PATROL_SPEED)
		w.name = "Watch_%s" % name.to_lower()
		w.seat(best, 0, true)


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
