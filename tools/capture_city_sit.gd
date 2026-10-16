extends Node

## Sitting in the real seamless city (docs/SYSTEMS/SITTING.md): Kalev on a nave bench of St Olaf,
## through the city's own SeatPrompt (the same path as pressing interact next to a seat). Saves
## church_*.png and prints the seat used. (Household rooms and the refectory keep their walls in
## front of a teleported camera; the nave is cut away.)
##   tools/godot_render.sh --resolution 1600x900 res://tools/capture_city_sit.tscn
## The docs keep 1280 px JPEGs (`sips -s format jpeg --resampleWidth 1280`).

const SCENE := preload("res://scenes/world/reval_city/reval_city.tscn")
const OUTPUT_DIR := "res://docs/reports/images/sitting"
const PX := 32.0

var _city: Node
var _player: Player
var _failed := false


func _ready() -> void:
	call_deferred("_run")


func _shot(name: String) -> void:
	for i in 2:
		await get_tree().process_frame
	var image := get_tree().root.get_viewport().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path("%s/%s.png" % [OUTPUT_DIR, name]))
	print("shot %s" % name)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_city = SCENE.instantiate()
	get_tree().root.add_child(_city)
	for i in 6:
		await get_tree().process_frame
	_player = _city.player
	await _church_bench()
	print("RESULT %s" % ("FAIL" if _failed else "OK"))
	get_tree().quit(1 if _failed else 0)


## Walks Kalev next to `seat`, lets the prompt find it and interacts; shoots before, sitting
## down and seated.
func _sit(name: String, seat: Dictionary) -> void:
	var facing: Vector2 = seat["facing"]
	_player.global_position = ((seat["pos"] as Vector2) + facing * 0.7) * PX
	_player.velocity = Vector2.ZERO
	for i in 20:
		await get_tree().physics_frame
	var prompt: Node = _city.get_node("SeatPrompt")
	# Furniture collision may have nudged him while settling: stand him by the seat again.
	_player.global_position = ((seat["pos"] as Vector2) + facing * 0.7) * PX
	print("  seat %s, Kalev at %s" % [seat["pos"], _player.global_position / PX])
	prompt.refresh()
	print(
		(
			"%s: prompt %s at %s"
			% [name, prompt.current_seat(), prompt._interactable.global_position / PX]
		)
	)
	await _shot("%s_0_before" % name)
	prompt._on_interact(_player)
	if not _player.is_sitting():
		print(
			(
				"  medium %s airborne %s blocked %s moves %s leaping %s"
				% [
					_player.water_medium(),
					_player.is_airborne(),
					_player._movement_blocked(),
					_player.action_state_machine.allows_movement(),
					_player.is_leaping(),
				]
			)
		)
		print("FAIL %s: did not sit" % name)
		_failed = true
		return
	for i in 40:
		await get_tree().physics_frame
	await _shot("%s_1_sitting_down" % name)
	for i in 90:
		await get_tree().physics_frame
	await _shot("%s_2_seated" % name)
	_player.stand_up()
	for i in 80:
		await get_tree().physics_frame


func _church_bench() -> void:
	var plan: CityPlan = _city.plan
	for site: CitySite in plan.sites:
		if String(site.id).find("olaf") < 0:
			continue
		var benches: Array = site.data.get("benches", [])
		if benches.is_empty():
			continue
		var at := Vector2(benches[0]["at"][0], benches[0]["at"][1])
		var seat: Dictionary = _city.seats.nearest_free(site.to_world(at), 1.5)
		if not seat.is_empty():
			await _sit("church", seat)
			return
	print("FAIL no nave bench")
	_failed = true
