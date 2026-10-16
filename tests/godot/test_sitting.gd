extends "res://tests/godot/test_case.gd"

## Kalev sits on benches, stools and chairs (docs/SYSTEMS/SITTING.md): seats come from data (church
## benches, catalogue seats in site dressing, household sit slots), a seat with a resident on it is
## not offered, the prompt follows the nearest free seat, and sitting down, staying seated and
## standing up move and pose him like a seated resident.

const CitySeats := preload("res://scripts/world/city_seats.gd")
const SeatPrompt := preload("res://scripts/world/seat_prompt.gd")
const PlayerSeat := preload("res://scripts/player/player_seat.gd")
const PLAYER_SCENE := preload("res://player.tscn")
const PX := 32.0

var _nodes: Array[Node] = []


func after_each() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	super.after_each()


func test_city_sites_offer_church_bench_and_catalogue_seats() -> void:
	var seats: RefCounted = CitySeats.create(CityPlan.load_default(), null)
	assert_true(
		seats.site_seat_count() > 40,
		"nave benches and refectory benches: %d" % seats.site_seat_count()
	)
	var bench: Dictionary = CitySeats._seat_piece("obj.bench_plank")
	assert_almost_eq(float(bench["seat_h"]), 0.46, 1e-4, "bench seat height from the layout pieces")
	assert_true(
		CitySeats._seat_piece("obj.table_common_household").is_empty(), "tables are not seats"
	)


func test_nearest_free_seat_skips_taken_and_turns_a_bench_to_the_sitter() -> void:
	var seats: RefCounted = CitySeats.create(null, null)
	seats.add_seat(Vector2(1.0, 0.0), Vector2.DOWN, 0.45)
	seats.add_seat(Vector2(2.0, 0.0), Vector2.DOWN, 0.45, true)
	var s: Dictionary = seats.nearest_free(Vector2(0.9, 0.5), 2.0)
	assert_eq(s["pos"], Vector2(1.0, 0.0), "the nearest")
	# A resident seated on it: his body stands SIT_BACK in front of the seat.
	seats.occupied_fn = func() -> Array: return [Vector2(1.0, 0.44)]
	s = seats.nearest_free(Vector2(0.9, 0.5), 2.0)
	assert_eq(s["pos"], Vector2(2.0, 0.0), "the taken seat is skipped")
	s = seats.nearest_free(Vector2(2.0, -1.0), 2.0)
	assert_eq(s["facing"], Vector2.UP, "a backless bench faces the side he comes from")
	assert_true(seats.nearest_free(Vector2(9.0, 9.0), 1.0).is_empty(), "nothing in reach")


func _player() -> Node2D:
	var player := PLAYER_SCENE.instantiate() as Node2D
	(Engine.get_main_loop() as SceneTree).root.add_child(player)
	_nodes.append(player)
	player.global_position = Vector2(10.0, 10.0) * PX
	return player


func _tick(player: Node2D, seconds: float) -> void:
	for i in int(seconds * 60.0):
		player.call("_physics_process", 1.0 / 60.0)


func test_sit_down_stay_seated_and_stand_up() -> void:
	var player := _player()
	var seat := {"pos": Vector2(10.0, 11.0), "facing": Vector2.UP, "h": 0.46, "two_sided": false}
	var mask := (player as CollisionObject2D).collision_mask
	assert_true(player.call("sit_on", seat), "sits")
	assert_eq(player.call("view_animation"), &"sit_down")
	assert_eq((player as CollisionObject2D).collision_mask, 0, "a seated body does not collide")
	assert_eq(player.call("view_facing"), Vector2.UP, "faces the way the seat faces")
	var origin := (Vector2(10.0, 11.0) + Vector2.UP * PlayerSeat.SIT_BACK) * PX
	assert_true(player.global_position.distance_to(origin) < 0.5, "body where residents sit")
	assert_almost_eq(float(player.call("seat_height_offset")), 0.46 - PlayerSeat.SIT_SURFACE, 1e-4)
	_tick(player, PlayerSeat.DOWN_SEC + 0.1)
	assert_eq(player.call("view_animation"), &"sit_idle", "seated")
	assert_false(player.call("try_jump"), "no jump from a seat")
	_tick(player, 2.0)
	assert_true(player.call("is_seated"), "stays seated")
	player.call("stand_up")
	assert_eq(player.call("view_animation"), &"sit_up")
	_tick(player, PlayerSeat.UP_SEC + 0.1)
	assert_false(player.call("is_sitting"), "standing")
	assert_eq((player as CollisionObject2D).collision_mask, mask, "collision back")
	var stand := (Vector2(10.0, 11.0) + Vector2.UP * PlayerSeat.STAND_FRONT) * PX
	assert_true(player.global_position.distance_to(stand) < 0.5, "steps off in front of the seat")


func test_prompt_follows_the_nearest_seat_and_sits_on_interact() -> void:
	var player := _player()
	var seats: RefCounted = CitySeats.create(null, null)
	seats.add_seat(Vector2(10.5, 10.6), Vector2.UP, 0.44)
	var prompt := SeatPrompt.install((Engine.get_main_loop() as SceneTree).root, player, seats)
	_nodes.append(prompt)
	await (Engine.get_main_loop() as SceneTree).process_frame
	prompt.refresh()
	var area: Interactable = prompt._interactable
	assert_true(area.is_enabled(), "a seat in reach is offered")
	assert_eq(area.get_prompt(), SeatPrompt.SIT_PROMPT)
	assert_true(area.global_position.distance_to(Vector2(10.5, 10.6) * PX) < 0.1, "at the seat")
	prompt._on_interact(player)
	assert_true(player.call("is_sitting"), "interact sits him down")
	prompt.refresh()
	assert_eq(area.get_prompt(), SeatPrompt.STAND_PROMPT, "then offers to stand")
	player.global_position = Vector2(30.0, 30.0) * PX
	player.call("stand_up")
	_tick(player, PlayerSeat.UP_SEC + 0.1)
	player.global_position = Vector2(30.0, 30.0) * PX
	prompt.refresh()
	assert_false(area.is_enabled(), "no seat in reach, no prompt")
