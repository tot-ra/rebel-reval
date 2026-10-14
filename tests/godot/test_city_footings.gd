extends "res://tests/godot/test_case.gd"

## R-1933: irregular footings under every city wall (CityFooting).
const Builder := preload("res://scripts/city/city_building_builder.gd")
const Footing := preload("res://scripts/city/city_footing.gd")
const RING := [Vector2(0, 0), Vector2(9, 0), Vector2(9, 7), Vector2(0, 7)]
const FLOOR := 0.12


func _ring() -> PackedVector2Array:
	return Builder.normalized_ring(PackedVector2Array(RING))


func _building(id: String, material: String, kind := "house", openings := true) -> Dictionary:
	return {
		"id": id, "kind": kind, "material": material, "roof": "shingle", "openings": openings,
		"base_h": 0.0, "wall_h": 3.5, "ridge_angle": 0.0, "roof_pitch_deg": 48.0,
		"door": [4.5, 0.0, -PI * 0.5],
	}


## Ground falling 0.5 m across the plot with a 4 cm ripple, as a lane would.
func _slope(p: Vector2) -> float:
	return -0.05 * p.x + 0.04 * sin(p.y * 2.3)


func _build(kind: int, seed_value: int, ground_at := Callable()) -> Builder.Shell:
	var shell := Builder.Shell.new()
	Footing.build(shell, _ring(), kind, FLOOR, -0.7, ground_at, 0.0, seed_value)
	return shell


func test_every_family_gets_stones_and_timber_families_a_sill() -> void:
	var kinds := [Footing.Kind.DRESSED, Footing.Kind.FIELDSTONE, Footing.Kind.PLANK, Footing.Kind.LOG]
	for kind: int in kinds:
		var shell := Builder.Shell.new()
		var made := Footing.build(shell, _ring(), kind, FLOOR, -0.7, Callable(), 0.0, 11)
		# 32 m of wall: roughly one stone per 0.3-0.85 m.
		assert_true(int(made["stones"]) > 30, "family %d lays stones (%d)" % [kind, made["stones"]])
		var timber := kind == Footing.Kind.PLANK or kind == Footing.Kind.LOG
		assert_eq(int(made["beams"]), 4 if timber else 0, "family %d sill pieces" % kind)
		assert_eq(shell.surfaces.has("timber"), timber, "family %d timber surface" % kind)


func test_stone_tops_and_feet_are_irregular() -> void:
	var verts := (_build(Footing.Kind.FIELDSTONE, 7, _slope).surface("stone")).verts
	var tops := {}
	var feet := {}
	for v: Vector3 in verts:
		# Front faces stand out of the wall; skip the bed (2 cm proud).
		var off := minf(minf(absf(v.x), absf(v.x - 9.0)), minf(absf(v.z), absf(v.z - 7.0)))
		if off < 0.03:
			continue
		if v.y > FLOOR + 0.1:
			tops[snappedf(v.y, 0.005)] = true
		elif v.y < _slope(Vector2(v.x, v.z)):
			feet[snappedf(v.y - _slope(Vector2(v.x, v.z)), 0.005)] = true
	assert_true(tops.size() > 20, "stone tops vary (%d distinct heights)" % tops.size())
	assert_true(feet.size() > 10, "sink depth varies (%d distinct depths)" % feet.size())


func test_stone_feet_are_sunk_5_to_15_cm() -> void:
	var shell := Builder.Shell.new()
	Footing.build(shell, _ring(), Footing.Kind.PLANK, FLOOR, -0.7, _slope, 0.0, 3)
	var lowest := INF
	var highest := -INF
	for v: Vector3 in shell.surface("stone").verts:
		var off := minf(minf(absf(v.x), absf(v.x - 9.0)), minf(absf(v.z), absf(v.z - 7.0)))
		var g := _slope(Vector2(v.x, v.z))
		if off < 0.03 or v.y > g:
			continue
		lowest = minf(lowest, v.y - g)
		highest = maxf(highest, v.y - g)
	# Nudges and sampling along a stone allow a little slack each way.
	assert_true(lowest > -Footing.SINK_MAX - 0.12, "no stone foot dives deep (%.3f)" % lowest)
	assert_true(highest < 0.0, "every foot is below the ground (%.3f)" % highest)


func test_deterministic_per_seed_and_varied_between_seeds() -> void:
	var a := _build(Footing.Kind.LOG, 42).surface("stone").verts
	var b := _build(Footing.Kind.LOG, 42).surface("stone").verts
	var c := _build(Footing.Kind.LOG, 43).surface("stone").verts
	assert_eq(a, b, "same building id, same stones")
	assert_true(a != c, "another building lays other stones")


func test_door_span_stays_open() -> void:
	var made := Footing.build(
		Builder.Shell.new(), _ring(), Footing.Kind.PLANK, FLOOR, -0.7, Callable(), 0.0, 5
	)
	var shell := Builder.Shell.new()
	var door := Footing.build(
		shell, _ring(), Footing.Kind.PLANK, FLOOR, -0.7, Callable(), 0.0, 5,
		Vector2(3.6, 0), Vector2(5.4, 0)
	)
	assert_eq(int(door["beams"]), int(made["beams"]) + 1, "the door edge splits the sill beam")
	for v: Vector3 in shell.surface("timber").verts:
		if absf(v.z) < 0.2:
			assert_false(v.x > 3.65 and v.x < 5.35, "no sill beam across the door at x=%.2f" % v.x)


func test_sill_log_ends_cross_past_outer_corners() -> void:
	var verts := _build(Footing.Kind.LOG, 9).surface("timber").verts
	var min_x := INF
	var max_x := -INF
	for v: Vector3 in verts:
		min_x = minf(min_x, v.x)
		max_x = maxf(max_x, v.x)
	assert_true(min_x < -Footing.LOG_LAP + 0.05, "log end past the west corner (%.2f)" % min_x)
	assert_true(max_x > 9.0 + Footing.LOG_LAP - 0.05, "log end past the east corner (%.2f)" % max_x)


func test_outbuildings_and_smoke_free_houses_now_have_footings() -> void:
	var record := _building("bldg.test.f1", "log", "outbuilding", false)
	var shed := Builder.build_building(record, _ring(), FLOOR, false)
	var shell: Builder.Shell = shed["shell"]
	assert_true(shell.surfaces.has("stone"), "an outbuilding stands on fieldstone pads")
	assert_true(shell.surfaces.has("timber"), "and a sill log")
	var plank := Builder.build_building(_building("bldg.test.f2", "plank"), _ring(), FLOOR, false)
	var plank_shell: Builder.Shell = plank["shell"]
	assert_true(plank_shell.surfaces.has("stone"), "a plank house stands on a sill")


func test_kind_for_wall_family() -> void:
	assert_eq(Footing.kind_for(&"limestone"), Footing.Kind.DRESSED)
	assert_eq(Footing.kind_for(&"plaster"), Footing.Kind.FIELDSTONE)
	assert_eq(Footing.kind_for(&"plank"), Footing.Kind.PLANK)
	assert_eq(Footing.kind_for(&"log"), Footing.Kind.LOG)
