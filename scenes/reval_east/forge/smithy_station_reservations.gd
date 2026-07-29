class_name SmithyStationReservations
extends Node

## Shared smithy station lock keyed by the authored prop ID. Routine controllers
## still own actor sequencing; this host prevents separate Kalev, Mart, Henning,
## and cat controllers from claiming the same physical workstation.

var _actor_by_station: Dictionary = {}
var _station_by_actor: Dictionary = {}
var _activity_by_actor: Dictionary = {}
var _reservation_count := 0
var _release_count := 0
var _prevented_contention_count := 0
var _max_simultaneous_reservations := 0


func can_reserve(
	actor_id: StringName,
	activity_id: StringName,
	point: SmithyActivityPoint
) -> bool:
	if point == null or not point.exclusive:
		return true
	var station_id := station_id_for(activity_id, point)
	var occupant: StringName = _actor_by_station.get(station_id, &"")
	var allowed := occupant.is_empty() or occupant == actor_id
	# can_begin short-circuits before try_reserve; count blocked probes so soak
	# and acceptance telemetry still see station contention.
	if not allowed:
		_prevented_contention_count += 1
	return allowed


func try_reserve(
	actor_id: StringName,
	activity_id: StringName,
	point: SmithyActivityPoint
) -> bool:
	if actor_id.is_empty() or activity_id.is_empty() or point == null:
		return false
	if not point.exclusive:
		return true
	var station_id := station_id_for(activity_id, point)
	var occupant: StringName = _actor_by_station.get(station_id, &"")
	if not occupant.is_empty() and occupant != actor_id:
		_prevented_contention_count += 1
		return false
	var previous_station: StringName = _station_by_actor.get(actor_id, &"")
	if not previous_station.is_empty() and previous_station != station_id:
		release_actor(actor_id)
	if _actor_by_station.get(station_id, &"") == actor_id:
		_activity_by_actor[actor_id] = activity_id
		return true
	_actor_by_station[station_id] = actor_id
	_station_by_actor[actor_id] = station_id
	_activity_by_actor[actor_id] = activity_id
	_reservation_count += 1
	_max_simultaneous_reservations = maxi(
		_max_simultaneous_reservations,
		_actor_by_station.size()
	)
	return true


func release_actor(actor_id: StringName) -> void:
	var station_id: StringName = _station_by_actor.get(actor_id, &"")
	if station_id.is_empty():
		_activity_by_actor.erase(actor_id)
		return
	if _actor_by_station.get(station_id, &"") == actor_id:
		_actor_by_station.erase(station_id)
		_release_count += 1
	_station_by_actor.erase(actor_id)
	_activity_by_actor.erase(actor_id)


func clear() -> void:
	_actor_by_station.clear()
	_station_by_actor.clear()
	_activity_by_actor.clear()


func reservation_count() -> int:
	return _actor_by_station.size()


func station_for_actor(actor_id: StringName) -> StringName:
	return _station_by_actor.get(actor_id, &"")


func activity_for_actor(actor_id: StringName) -> StringName:
	return _activity_by_actor.get(actor_id, &"")


func occupant_of_station(station_id: StringName) -> StringName:
	return _actor_by_station.get(station_id, &"")


func invariant_errors() -> Array[String]:
	var errors: Array[String] = []
	for station_id: StringName in _actor_by_station:
		var actor_id: StringName = _actor_by_station[station_id]
		if actor_id.is_empty():
			errors.append("station %s has an empty occupant" % String(station_id))
		elif _station_by_actor.get(actor_id, &"") != station_id:
			errors.append("station %s and actor %s disagree" % [station_id, actor_id])
	for actor_id: StringName in _station_by_actor:
		var station_id: StringName = _station_by_actor[actor_id]
		if _actor_by_station.get(station_id, &"") != actor_id:
			errors.append("actor %s has an orphan reservation" % String(actor_id))
		if not _activity_by_actor.has(actor_id):
			errors.append("actor %s reservation has no activity" % String(actor_id))
	return errors


func telemetry() -> Dictionary:
	return {
		"active_reservations": reservation_count(),
		"reservation_count": _reservation_count,
		"release_count": _release_count,
		"prevented_contention_count": _prevented_contention_count,
		"max_simultaneous_reservations": _max_simultaneous_reservations,
		"invariant_errors": invariant_errors(),
	}


static func station_id_for(
	activity_id: StringName,
	point: SmithyActivityPoint
) -> StringName:
	if point != null and not point.prop_id.is_empty():
		return point.prop_id
	return activity_id
