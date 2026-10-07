class_name CityChimneySmoke
extends Node3D

## Smoke over the city's chimneys (ADR 0031). Hundreds of stacks cannot all
## carry a particle plume, so plumes are streamed: only chimneys whose hearth is
## lit (ChimneySmoke3D's per-building day/night schedule, and about one house
## in three at all) within RANGE of Kalev get a ChimneySmoke3D, at most MAX_PLUMES.

const RANGE := 180.0
const MAX_PLUMES := 28
## Fraction of chimneys with a fire at all; the rest stay cold.
const LIT_SHARE := 0.35
const REFRESH_SEC := 0.5

## [Vector3 top, StringName id] of lit chimneys.
var lit: Array = []
var _plumes: Dictionary = {}
var _time_of_day: StringName = MapView3D.TIME_DAY
var _since := INF


static func create(chimneys: Array) -> CityChimneySmoke:
	var node := CityChimneySmoke.new()
	node.name = "ChimneySmoke"
	for c: Array in chimneys:
		if float(posmod(String(c[1]).hash() >> 9, 1000)) / 1000.0 < LIT_SHARE:
			node.lit.append(c)
	return node


func set_time_of_day(time_of_day: StringName) -> void:
	if time_of_day == _time_of_day:
		return
	_time_of_day = time_of_day
	for plume: ChimneySmoke3D in _plumes.values():
		plume.apply_time_of_day(time_of_day)


## Keeps plumes on the lit chimneys nearest `world_xz`; call each frame.
func update_for(world_xz: Vector2, delta: float) -> void:
	_since += delta
	if _since < REFRESH_SEC:
		return
	_since = 0.0
	var near: Array = []
	for c: Array in lit:
		var top: Vector3 = c[0]
		var d := world_xz.distance_squared_to(Vector2(top.x, top.z))
		if d < RANGE * RANGE:
			near.append([d, c])
	near.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var keep := {}
	for k in mini(near.size(), MAX_PLUMES):
		var c: Array = near[k][1]
		var id: StringName = c[1]
		keep[id] = true
		if not _plumes.has(id):
			var plume := ChimneySmoke3D.new()
			plume.position = (c[0] as Vector3) + Vector3(0, 0.1, 0)
			add_child(plume)
			plume.configure(id)
			plume.apply_time_of_day(_time_of_day)
			_plumes[id] = plume
	for id: StringName in _plumes.keys():
		if not keep.has(id):
			(_plumes[id] as Node).queue_free()
			_plumes.erase(id)


func plume_count() -> int:
	return _plumes.size()
