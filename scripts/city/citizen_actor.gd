class_name CitizenActor
extends CharacterBody2D

## One census resident in the seamless city (docs/SYSTEMS/CITIZENS.md). Logic
## body only: MapViewRuntime mirrors the rig. The position is not simulated, it is
## read from the roster's timetable every physics frame, so the resident is
## always where the hour says (door, workplace, mid-street).

const VARIANTS_DIR := "res://assets/characters/variants/%s.tscn"

var rig_scene: PackedScene
var roster: CitizenRoster
var index := -1
var record: Dictionary = {}
## Callable returning the current hour 0..24.
var hour_source: Callable
## False once the resident has gone indoors; CityCitizens then frees the body.
var outdoors := true
var rig_styled := false

var _facing := Vector2.DOWN
var _moving := false


static func create(citizen_roster: CitizenRoster, resident: int, hours: Callable) -> CitizenActor:
	var actor := CitizenActor.new()
	actor.roster = citizen_roster
	actor.index = resident
	actor.record = citizen_roster.residents[resident]
	actor.hour_source = hours
	actor.name = "Citizen_%s" % String(actor.record["id"]).replace(".", "_")
	actor.rig_scene = load(VARIANTS_DIR % String(actor.record["body"]))
	var state := citizen_roster.resolve(resident, float(hours.call()))
	actor.global_position = CityPlan.to_logic(state["pos"])
	actor._facing = state["facing"]
	return actor


func _ready() -> void:
	CollisionLayers.apply_npc(self)
	add_to_group(&"map_view_actor")
	add_to_group(&"city_citizen")
	var shape := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = 8.0 * float(record["height_scale"])
	capsule.height = 18.0 * float(record["height_scale"])
	shape.shape = capsule
	add_child(shape)


func _physics_process(delta: float) -> void:
	var state := roster.resolve(index, float(hour_source.call()))
	outdoors = state["visible"]
	var logic := CityPlan.to_logic(state["pos"])
	velocity = (logic - global_position) / maxf(delta, 0.0001)
	global_position = logic
	_moving = state["moving"] and velocity.length_squared() > 4.0
	if state["moving"] or velocity.length_squared() < 4.0:
		_facing = state["facing"]


func world_xz() -> Vector2:
	return CityPlan.to_world_xz(global_position)


func view_facing() -> Vector2:
	return _facing


func view_animation() -> StringName:
	return &"walk" if _moving else &"idle"
