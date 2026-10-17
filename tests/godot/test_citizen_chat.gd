extends "res://tests/godot/test_case.gd"

## Neighbours chat (docs/SYSTEMS/CITIZENS.md): residents waiting outdoors near each
## other pair up nearest first, face each other and take turns gesturing.

const CitizenChat := preload("res://scripts/city/citizen_chat.gd")


func test_pairs_nearest_first_and_each_resident_once() -> void:
	var points := PackedVector2Array([
		Vector2(0, 0), Vector2(2.0, 0), Vector2(2.5, 0), Vector2(40, 0), Vector2(41, 0),
	])
	var found := CitizenChat.pairs(points)
	# 1-2 (0.5 m) beats 0-1 (2 m); 0 is then left alone; 3-4 pair far away.
	assert_eq(Array(found), [1, 2, 3, 4])


func test_nobody_chats_across_the_street() -> void:
	var points := PackedVector2Array([Vector2(0, 0), Vector2(CitizenChat.CHAT_RADIUS + 0.5, 0)])
	assert_eq(CitizenChat.pairs(points).size(), 0)


func test_turns_alternate_between_the_two() -> void:
	var t := CitizenChat.TURN_SECONDS
	assert_true(CitizenChat.first_speaks(0.1, 0))
	assert_false(CitizenChat.first_speaks(t + 0.1, 0))
	assert_true(CitizenChat.first_speaks(2.0 * t + 0.1, 0))
	assert_false(CitizenChat.first_speaks(0.1, 1))


func test_only_some_residents_are_talkative() -> void:
	var talkative := 0
	for resident in 1000:
		talkative += 1 if CitizenChat.is_talkative(resident) else 0
	assert_true(talkative > 450 and talkative < 750, "talkative share %d/1000" % talkative)
	assert_eq(CitizenChat.is_talkative(42), CitizenChat.is_talkative(42))


func test_waiting_resident_faces_and_gestures() -> void:
	var actor := CitizenActor.new()
	actor.global_position = CityPlan.to_logic(Vector2(10, 10))
	actor.outdoors = true
	assert_true(actor.is_waiting())
	assert_eq(actor.view_animation(), &"idle")
	actor.chatting = true
	actor.chat_toward = Vector2(10, 12)
	actor.chat_speaking = true
	assert_eq(actor.view_animation(), &"talk_gesture")
	assert_true(actor.view_facing().is_equal_approx(Vector2(0, 1)))
	actor.chat_speaking = false
	assert_eq(actor.view_animation(), &"idle")
	# Held by the hero: the conversation with him wins.
	actor.held_for_talk = true
	assert_false(actor.is_waiting())
	actor.free()
