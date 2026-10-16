extends Node

## One "Sit" interaction that follows the nearest free seat around Kalev (docs/SYSTEMS/SITTING.md),
## so every bench, stool and chair in the city works with the ordinary `interact` key and prompt
## without an Interactable per seat. While he sits it offers "Stand up" where he is.

const CitySeatsScript := preload("res://scripts/world/city_seats.gd")
const INTERACTABLE := preload("res://scenes/interaction/interactable.tscn")
const SIT_PROMPT := "Sit"
const STAND_PROMPT := "Stand up"
## Seats this close to Kalev (m) are offered.
const REACH := 1.3
const REFRESH_SEC := 0.15
const RADIUS_PX := 44.0

var player: Node2D
var seats: RefCounted
var px_per_m := 32.0

var _interactable: Interactable
var _seat: Dictionary = {}
var _since := 0.0


static func install(parent: Node, city_player: Node2D, city_seats: RefCounted) -> Node:
	var prompt := new()
	prompt.name = "SeatPrompt"
	prompt.player = city_player
	prompt.seats = city_seats
	parent.add_child(prompt)
	return prompt


func _ready() -> void:
	_interactable = INTERACTABLE.instantiate() as Interactable
	_interactable.interactable_id = &"seat"
	_interactable.prompt = SIT_PROMPT
	_interactable.interaction_kind = InteractionKinds.USE
	_interactable.interaction_radius = RADIUS_PX
	_interactable.enabled = false
	add_child(_interactable)
	_interactable.top_level = true
	_interactable.suppress_flat_markers(true)
	_interactable.set_interact_callback(_on_interact)


func _physics_process(delta: float) -> void:
	_since += delta
	if _since < REFRESH_SEC or player == null or seats == null:
		return
	_since = 0.0
	refresh()


## Moves the prompt to the nearest free seat (or onto Kalev while he sits).
func refresh() -> void:
	if player.has_method("is_sitting") and bool(player.call("is_sitting")):
		_interactable.prompt = STAND_PROMPT
		_interactable.global_position = player.global_position
		_interactable.enabled = bool(player.call("is_seated"))
		return
	_interactable.prompt = SIT_PROMPT
	_seat = seats.nearest_free(player.global_position / px_per_m, REACH)
	_interactable.enabled = not _seat.is_empty()
	if not _seat.is_empty():
		_interactable.global_position = (_seat["pos"] as Vector2) * px_per_m


func current_seat() -> Dictionary:
	return _seat


func _on_interact(_actor: Node) -> void:
	if bool(player.call("is_sitting")):
		player.call("stand_up")
	elif not _seat.is_empty():
		player.call("sit_on", _seat)
	refresh()
