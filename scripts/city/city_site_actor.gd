class_name CitySiteActor
extends CharacterBody2D

## A person at work on a landmark site (ADR 0032 manifest `people`): seated
## at a bench or table, standing at a post, or talking with a gesture. Logic
## body only; MapViewRuntime mirrors the rig. Seated people have no collision
## (the bench or table under them is the site's solid); standing ones block
## like any townsperson.

const VARIANTS_DIR := "res://assets/characters/variants/%s.tscn"
const POSE_ANIMATION := {&"sit": &"sit_idle", &"stand": &"idle", &"talk": &"talk_gesture"}
## Sit_Chair_Idle, measured on the shared rig: the hips sit SIT_BACK behind the
## character origin and the sitting surface is SIT_SURFACE above it (the feet
## hang ~0.47 m up). A seated person's manifest `at` is the seat point; the
## origin goes SIT_BACK in front of it and the rig is lowered so the thighs
## rest on a seat `seat_h` high.
const SIT_BACK := 0.44
const SIT_SURFACE := 0.95

var rig_scene: PackedScene
var role := ""
var pose: StringName = &"stand"
var seat_h := 0.48
var _facing := Vector2.DOWN
var _home := Vector2.ZERO
var _yield := Vector2.ZERO
var _player: CharacterBody2D


static func create(person: Dictionary) -> CitySiteActor:
	var actor := CitySiteActor.new()
	actor.name = "Site_%s" % String(person["id"]).replace(".", "_")
	actor.rig_scene = load(VARIANTS_DIR % person["rig"])
	actor.role = String(person["role"])
	actor.pose = person["pose"]
	actor._facing = person["facing"]
	actor.seat_h = float(person.get("seat_h", 0.48))
	var at: Vector2 = person["at"]
	if actor.pose == &"sit":
		at += (person["facing"] as Vector2) * SIT_BACK
	actor.global_position = CityPlan.to_logic(at)
	return actor


func _ready() -> void:
	add_to_group(&"map_view_actor")
	_home = global_position
	if pose != &"sit":
		CollisionLayers.apply_crowd(self)
		var shape := CollisionShape2D.new()
		var capsule := CapsuleShape2D.new()
		capsule.radius = 9.0
		capsule.height = 18.0
		shape.shape = capsule
		add_child(shape)


## Standing people step aside for the player (CrowdYield) and return after.
func _physics_process(delta: float) -> void:
	if pose == &"sit":
		return
	if _player == null or not is_instance_valid(_player):
		_player = CrowdYield.find_player(get_tree())
		if _player == null:
			return
	var far := 2.0 * CrowdYield.YIELD_RADIUS
	if _yield.is_zero_approx() and global_position.distance_to(_player.global_position) > far:
		return
	_yield = CrowdYield.step_offset(_yield, _home, _player.global_position, _player.velocity, delta)
	global_position = _home + _yield


## Vertical offset of the rig (MapViewRuntimeActors): seats the sit pose on
## its bench, chair or bed.
func view_height_offset() -> float:
	return seat_h - SIT_SURFACE if pose == &"sit" else 0.0


func view_facing() -> Vector2:
	return _facing


func view_animation() -> StringName:
	return POSE_ANIMATION.get(pose, &"idle")
