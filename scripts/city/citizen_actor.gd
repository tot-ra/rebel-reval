class_name CitizenActor
extends CharacterBody2D

## One census resident in the seamless city (docs/SYSTEMS/CITIZENS.md). Logic
## body only: MapViewRuntime mirrors the rig. The position is not simulated, it is
## read from the roster's timetable every physics frame, so the resident is
## always where the hour says (door, workplace, mid-street). At home in a
## furnished house (CityInteriors) the resident is shown inside: walking in
## from the door, then asleep in bed, seated at the table, at the hearth, at the
## workbench or standing about (docs/SYSTEMS/HOUSEHOLDS.md).

const VARIANTS_DIR := "res://assets/characters/variants/%s.tscn"
## Sit_Chair_Idle on the shared rig (see CitySiteActor): the hips sit SIT_BACK
## behind the origin and the thighs SIT_SURFACE above it.
const SIT_BACK := 0.44
const SIT_SURFACE := 0.95
## A lying body's back rests this far above the bed's top.
const LIE_LIFT := 0.12
const POSE_ANIMATION := {
	&"walk": &"walk", &"sit": &"sit_idle", &"sleep": &"idle", &"stand": &"idle",
	&"hearth": &"idle", &"work": &"idle",
}

var rig_scene: PackedScene
var roster: CitizenRoster
var index := -1
var record: Dictionary = {}
## Callable returning the current hour 0..24.
var hour_source: Callable
## False once the resident has gone indoors; CityCitizens then frees the body
## unless their house is furnished and they are shown at home.
var outdoors := true
## Shown inside their furnished house (CityInteriors.indoor_state).
var at_home := false
## Indoor pose: walk, sleep, sit, stand, hearth, work.
var pose: StringName = &"walk"
var pose_h := 0.0
## On the way home from the woodyard with an armful of firewood.
var carrying_wood := false
var rig_styled := false
## CityInteriors of the scene, or null (then residents vanish at their door).
var interiors: CityInteriors

var _facing := Vector2.DOWN
var _moving := false
## Sideways give-way from the player (CrowdYield), on top of the scheduled spot.
var _yield := Vector2.ZERO
var _player: CharacterBody2D


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
	CollisionLayers.apply_crowd(self)
	add_to_group(&"map_view_actor")
	add_to_group(&"city_citizen")
	var shape := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = 8.0 * float(record["height_scale"])
	capsule.height = 18.0 * float(record["height_scale"])
	shape.shape = capsule
	add_child(shape)


func _physics_process(delta: float) -> void:
	var h := float(hour_source.call())
	var state := roster.resolve(index, h)
	outdoors = state["visible"]
	carrying_wood = state["moving"] and state["dest"] == "home" and state["from"] == "fuel"
	var moving: bool = state["moving"]
	var pos: Vector2 = state["pos"]
	var facing: Vector2 = state["facing"]
	at_home = false
	pose = &"walk"
	pose_h = 0.0
	if not outdoors and interiors != null:
		var inside := interiors.indoor_state(index, h, float(state["arrived"]))
		if not inside.is_empty():
			at_home = true
			pose = inside["pose"]
			pose_h = float(inside["h"])
			moving = inside["moving"]
			facing = inside["facing"]
			pos = inside["pos"]
			if pose == &"sit":
				pos += facing * SIT_BACK
	_set_solid(outdoors)
	var logic := CityPlan.to_logic(pos)
	# Only people in the open make way; residents shown at home keep their bed/bench.
	if _player == null or not is_instance_valid(_player):
		_player = CrowdYield.find_player(get_tree())
	if _player != null and outdoors and not at_home:
		_yield = CrowdYield.step_offset(_yield, logic, _player.global_position, _player.velocity, delta)
	else:
		_yield = _yield.move_toward(Vector2.ZERO, CrowdYield.EASE_SPEED * delta)
	logic += _yield
	velocity = (logic - global_position) / maxf(delta, 0.0001)
	global_position = logic
	_moving = moving and velocity.length_squared() > 4.0
	if moving or velocity.length_squared() < 4.0:
		_facing = facing


func world_xz() -> Vector2:
	return CityPlan.to_world_xz(global_position)


func view_facing() -> Vector2:
	return _facing


func view_animation() -> StringName:
	if at_home and not _moving:
		return POSE_ANIMATION.get(pose, &"idle")
	return &"walk" if _moving else &"idle"


## Seats the sit pose on its bench and lays a sleeper on the bed (MapViewRuntimeActors).
func view_height_offset() -> float:
	if not at_home:
		return 0.0
	match pose:
		&"sit":
			return pose_h - SIT_SURFACE
		&"sleep":
			return pose_h + LIE_LIFT
	return 0.0


func is_lying() -> bool:
	return at_home and pose == &"sleep"


## People at home do not block Kalev (they sit on benches and lie in beds).
func _set_solid(solid: bool) -> void:
	var shape := get_child(0) as CollisionShape2D if get_child_count() > 0 else null
	if shape != null and shape.disabled == solid:
		shape.set_deferred(&"disabled", not solid)
