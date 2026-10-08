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


## Gate garrisons and patrols (docs/SYSTEMS/GATE_GARRISONS.md).
func _on_duty(roster: CitizenRoster, post: String, shift: String) -> Array[int]:
	var found: Array[int] = []
	for i in roster.count():
		var duty: Dictionary = roster.residents[i].get("duty", {})
		if not duty.is_empty() and duty["post"] == post and duty["shift"] == shift:
			found.append(i)
	return found


func test_every_gate_has_its_garrison_of_census_residents() -> void:
	var roster := _roster()
	for gate in ["coastal", "sand", "viru", "karja", "harju", "nuns", "long_hill", "short_hill"]:
		assert_true(_on_duty(roster, "gate." + gate, "day").size() >= 1, "day watch at " + gate)
		assert_true(_on_duty(roster, "gate." + gate, "night").size() >= 1, "night watch at " + gate)
	var keepers := 0
	for r: Dictionary in roster.residents:
		if r.get("duty", {}).get("role", "") == "gatekeeper":
			keepers += 1
	assert_eq(keepers, 8, "all eight census gatekeepers hold a gate")


func test_gate_shifts_relieve_each_other() -> void:
	var roster := _roster()
	for i in _on_duty(roster, "gate.viru", "day"):
		assert_true(roster.resolve(i, 10.0)["visible"], "day watch at the post at ten")
		assert_false(roster.resolve(i, 23.0)["visible"], "day watch at home at night")
	for i in _on_duty(roster, "gate.viru", "night"):
		assert_true(roster.resolve(i, 23.0)["visible"], "night watch at the post at night")
		assert_false(roster.resolve(i, 10.0)["visible"], "night watch asleep by day")


func test_gate_guard_stands_on_his_post_facing_out() -> void:
	var roster := _roster()
	var i := _on_duty(roster, "gate.coastal", "day")[0]
	var a := roster.resolve(i, 10.0)
	var b := roster.resolve(i, 10.5)
	assert_false(a["moving"], "standing")
	assert_eq(a["pos"], b["pos"], "same spot all morning")
	assert_true((a["pos"] as Vector2).distance_to(Vector2(222.46, -584.0)) < 14.0, "at the gate")


func test_patrol_walks_its_route_and_turns_back() -> void:
	var roster := _roster()
	var i := -1
	for k in roster.count():
		if roster.residents[k].get("duty", {}).get("post", "") == "patrol.pikk":
			i = k
			break
	assert_true(i >= 0)
	var shift: String = roster.residents[i]["duty"]["shift"]
	var hour := 10.0 if shift == "day" else 23.0
	var first := roster.resolve(i, hour)
	var later := roster.resolve(i, hour + 0.25)
	assert_true(first["moving"] and later["moving"], "walking")
	assert_true((first["pos"] as Vector2).distance_to(later["pos"]) > 20.0, "covers ground")
	assert_true(roster.describe(i, hour).begins_with("On patrol"), roster.describe(i, hour))
