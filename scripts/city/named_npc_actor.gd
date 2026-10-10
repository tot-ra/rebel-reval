class_name NamedNpcActor
extends CharacterBody2D

## One named NPC in the seamless city (docs/SYSTEMS/NAMED_NPCS.md). Logic body
## only: MapViewRuntime mirrors the rig. Like CitizenActor the position is not
## simulated: CityNamedNpcs.resolve reads it from the registry schedule every
## physics frame, so the NPC is always where the clock says.

const VARIANTS_DIR := "res://assets/characters/variants/%s.tscn"

var rig_scene: PackedScene
var npc: Dictionary = {}
## Styling record in the census shape (body, height_scale, head_scale, cloth, under):
## the replaced resident's own record, or one built from the registry body.
var record: Dictionary = {}
var spawner: CityNamedNpcs
var rig_styled := false
var visible_now := true

var _facing := Vector2.DOWN
var _moving := false
var _yield := Vector2.ZERO
var _player: CharacterBody2D


static func create(
	owner_spawner: CityNamedNpcs, row: Dictionary, style: Dictionary
) -> NamedNpcActor:
	var actor := NamedNpcActor.new()
	actor.spawner = owner_spawner
	actor.npc = row
	actor.record = style
	actor.name = "NamedNpc_%s" % String(row["id"]).replace(".", "_")
	# A custom model (NPC-7) when the registry has one, else the census blank body.
	var model: Variant = row.get("model_scene")
	actor.rig_scene = load(String(model) if model != null else VARIANTS_DIR % String(style["body"]))
	var state := owner_spawner.resolve(row, owner_spawner.hour())
	actor.global_position = CityPlan.to_logic(state["pos"])
	actor._facing = state["facing"]
	return actor


func npc_id() -> String:
	return String(npc["id"])


func _ready() -> void:
	CollisionLayers.apply_crowd(self)
	add_to_group(&"map_view_actor")
	add_to_group(&"city_named_npc")
	var shape := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = 8.0 * float(record["height_scale"])
	capsule.height = 18.0 * float(record["height_scale"])
	shape.shape = capsule
	add_child(shape)


func _physics_process(delta: float) -> void:
	var state := spawner.resolve(npc, spawner.hour())
	visible_now = state["visible"]
	var logic := CityPlan.to_logic(state["pos"])
	if _player == null or not is_instance_valid(_player):
		_player = CrowdYield.find_player(get_tree())
	if _player != null:
		_yield = CrowdYield.step_offset(_yield, logic, _player.global_position, _player.velocity, delta)
	logic += _yield
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
