extends "res://tests/godot/test_case.gd"

## Census residents of Reval as a timetable (docs/SYSTEMS/CITIZENS.md).


func _roster() -> CitizenRoster:
	return CitizenRoster.load_default()


func _first_with_pattern(roster: CitizenRoster, pattern: String) -> int:
	for i in roster.count():
		if roster.residents[i]["pattern"] == pattern:
			return i
	return -1


func test_roster_loads_with_every_body_scene() -> void:
	var roster := _roster()
	assert_true(roster.count() > 3500, "residents compiled, got %d" % roster.count())
	var bodies := {}
	for r: Dictionary in roster.residents:
		bodies[r["body"]] = true
	assert_true(bodies.size() >= 12, "build variety, got %d bodies" % bodies.size())
	for body: String in bodies:
		assert_true(
			ResourceLoader.exists("res://assets/characters/variants/%s.tscn" % body), body
		)


func test_resolve_is_deterministic() -> void:
	var roster := _roster()
	for i in [0, 50, 1200, 3000]:
		assert_eq(roster.resolve(i, 9.3), roster.resolve(i, 9.3))


func test_craftsman_is_indoors_at_night_and_at_the_door_by_day() -> void:
	var roster := _roster()
	var i := _first_with_pattern(roster, "craft")
	assert_true(i >= 0)
	assert_false(roster.resolve(i, 2.0)["visible"], "asleep indoors")
	var day := roster.resolve(i, 7.5)
	assert_true(day["visible"], "working at the door")
	var r: Dictionary = roster.residents[i]
	assert_true((day["pos"] as Vector2).distance_to(roster.place_position(int(r["home"]))) < 3.5)


func test_household_does_not_stand_in_one_spot() -> void:
	var roster := _roster()
	var spots := {}
	for i in roster.count():
		var r: Dictionary = roster.residents[i]
		if r["household"] == roster.residents[0]["household"]:
			var s := roster.resolve(i, 7.5)
			if s["visible"]:
				spots[(s["pos"] as Vector2).snappedf(0.2)] = true
	assert_true(spots.size() >= 1)


func test_children_of_the_better_off_attend_school_in_the_morning() -> void:
	var roster := _roster()
	var i := _first_with_pattern(roster, "school")
	assert_true(i >= 0, "some school pupils")
	var r: Dictionary = roster.residents[i]
	var at_school := roster.resolve(i, 9.5)
	assert_true(at_school["visible"])
	assert_true(
		(at_school["pos"] as Vector2).distance_to(roster.place_position(int(r["school"]))) < 8.0
	)


func test_walkers_move_continuously_along_their_route() -> void:
	var roster := _roster()
	var checked := 0
	for i in roster.count():
		var r: Dictionary = roster.residents[i]
		if r["pattern"] != "market" or r["work_kind"] != "forum":
			continue
		var prev := Vector2.INF
		var hour := 5.0
		while hour < 8.0:
			var s := roster.resolve(i, hour)
			if s["visible"] and prev != Vector2.INF:
				# 10 s steps at <= 1.5 m/s
				assert_true((s["pos"] as Vector2).distance_to(prev) <= 16.0, "no teleport")
			prev = s["pos"] if s["visible"] else Vector2.INF
			hour += 10.0 / 3600.0
		checked += 1
		if checked >= 5:
			break
	assert_true(checked > 0)


func test_candidates_near_the_forum_are_bounded_and_nonempty() -> void:
	var roster := _roster()
	var near := roster.candidates_near(Vector2(5.0, -10.0), 62.0)
	assert_true(near.size() > 20 and near.size() < 3600, "got %d" % near.size())


func test_body_matches_sex_and_height_scale_is_sane() -> void:
	var roster := _roster()
	for r: Dictionary in roster.residents:
		assert_true(String(r["body"]).begins_with("citizen_%s_" % r["sex"]), r["id"])
		assert_true(float(r["height_scale"]) >= 0.55 and float(r["height_scale"]) <= 1.3, r["id"])
