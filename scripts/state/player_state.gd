class_name PlayerState
extends RefCounted

const DEFAULT_LOCATION_ID := &"forge"
const DEFAULT_SPAWN_ID := &"main"

var health: float = 100.0
var max_health: float = 100.0
var stamina: float = 100.0
var max_stamina: float = 100.0
var location_id: StringName = DEFAULT_LOCATION_ID
var spawn_id: StringName = DEFAULT_SPAWN_ID
