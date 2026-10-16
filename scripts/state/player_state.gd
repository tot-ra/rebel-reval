class_name PlayerState
extends RefCounted

const DEFAULT_LOCATION_ID := &"forge"
const DEFAULT_SPAWN_ID := &"main"

var health: float = 100.0
var max_health: float = 100.0
var stamina: float = 100.0
var max_stamina: float = 100.0
## ADR 0061: 0 dry .. 1 soaked through, and 1 comfortable .. 0 freezing (HeroExposure).
var wetness: float = 0.0
var body_heat: float = 1.0
var location_id: StringName = DEFAULT_LOCATION_ID
var spawn_id: StringName = DEFAULT_SPAWN_ID
