class_name CityNpcs
extends Node2D

## People of the seamless city (ADR 0031), placed the way the district maps
## had them: watchmen at every town gate and Danish men-at-arms at the Toompea
## gates, the town watch walking Pikk, Lai and Vene, market folk on the forum,
## and townsfolk walking the streets around Kalev (a small pool re-seated on
## nearby streets as he moves, so the town is never empty and never costs more
## than POOL rigs). Bodies are logic actors; MapViewRuntime mirrors their rigs.

const WATCHMAN := preload("res://assets/characters/variants/watchman.tscn")
const MAN_AT_ARMS := preload("res://assets/characters/variants/danish_warrior.tscn")
const SERGEANT := preload("res://assets/characters/variants/sergeant.tscn")
const CROWD: Array[PackedScene] = [
	preload("res://assets/characters/variants/crowd_townsman_01.tscn"),
	preload("res://assets/characters/variants/crowd_townsman_02.tscn"),
	preload("res://assets/characters/variants/crowd_townswoman_01.tscn"),
	preload("res://assets/characters/variants/crowd_townswoman_02.tscn"),
	preload("res://assets/characters/variants/townswoman.tscn"),
]
const CASTLE_GATES: Array[String] = ["gate.long_hill", "gate.short_hill"]
const PATROL_STREETS: Array[String] = ["Pikk", "Lai", "Vene"]
const MARKET_FOLK := 7
const POOL := 14
const POOL_NEAR := 45.0
const POOL_FAR := 130.0
const PATROL_SPEED := 1.3
const WALK_SPEED := 1.15


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
var _streets: Array[PackedVector2Array] = []
var _pool: Array[Walker] = []
var _rng := RandomNumberGenerator.new()
var _since := 0.0


static func create(city_plan: CityPlan, kalev: Node2D) -> CityNpcs:
	var node := CityNpcs.new()
	node.name = "CityNpcs"
	node.plan = city_plan
	node.player = kalev
	node._rng.seed = 1343
	return node


func _ready() -> void:
	for s: Dictionary in plan.data.get("streets", []):
		var pts := CityPlan.points(s["points"])
		if pts.size() >= 2:
			_streets.append(pts)
	_place_guards()
	_place_patrols()
	_place_market()
	for i in POOL:
		var w := _walker(CROWD[i % CROWD.size()], WALK_SPEED * _rng.randf_range(0.8, 1.15))
		w.name = "Townsfolk_%d" % i
		_reseat(w)


func _process(delta: float) -> void:
	_since += delta
	if _since < 1.0 or player == null:
		return
	_since = 0.0
	var me := CityPlan.to_world_xz(player.global_position)
	for w in _pool:
		if w.at.distance_to(me) > POOL_FAR * 1.3:
			_reseat(w)


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


func _place_market() -> void:
	var forum := plan.point_of_interest("poi.forum")
	if forum.is_empty():
		return
	var c := Vector2(forum["at"][0], forum["at"][1])
	for i in MARKET_FOLK:
		var a := TAU * float(i) / MARKET_FOLK + _rng.randf_range(-0.3, 0.3)
		var p := c + Vector2(cos(a), sin(a)) * _rng.randf_range(6.0, 16.0)
		var npc := StaticNpcActor.new()
		npc.rig_scene = CROWD[(i + 2) % CROWD.size()]
		npc.name = "Market_%d" % i
		add_child(npc)
		npc.configure(player, CityPlan.to_logic(p), (c - p).normalized())


## Seat a pooled walker on a street point POOL_NEAR..POOL_FAR from Kalev.
func _reseat(w: Walker) -> void:
	var me := CityPlan.to_world_xz(player.global_position) if player != null else Vector2.ZERO
	for attempt in 40:
		var pts: PackedVector2Array = _streets[_rng.randi() % _streets.size()]
		var k := _rng.randi() % pts.size()
		var d := pts[k].distance_to(me)
		if d >= POOL_NEAR and d <= POOL_FAR or attempt == 39:
			w.seat(pts, k, _rng.randf() < 0.5)
			break
	if not _pool.has(w):
		_pool.append(w)
