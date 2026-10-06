extends "res://tests/godot/test_case.gd"

## UF-08 / R-1117: negative fixtures for the seam form-continuity gate. Two 20x20 maps
## meet on an east/west seam; each fixture breaks exactly one form property.

const Verifier := preload("res://tools/verify_seam_continuity.gd")

const BUDGET := {
	"street_terrains": ["cobblestone"],
	"tolerances": {
		"height_delta": 0.5,
		"frontage_band_cells": 8,
		"frontage_step_cells": 3.0,
		"street_min_width_cells": 2,
		"street_width_delta_cells": 2,
		"street_offset_cells": 2.0,
	},
}


func test_matching_maps_report_nothing() -> void:
	assert_eq(_codes(_map(), _map()), [])


func test_height_step_is_reported() -> void:
	var raised := _map()
	# Relief, not ground_elevation: the datum tapers to zero at the map border.
	raised.relief_heights = PackedFloat32Array()
	raised.relief_heights.resize(400)
	raised.relief_heights.fill(3.0)
	assert_array_contains(_codes(_map(), raised), Verifier.CODE_HEIGHT)


func test_street_width_jump_is_reported() -> void:
	var wide := _map()
	wide.zones = [_road(Rect2i(0, 6, 20, 8))]
	assert_array_contains(_codes(_map(), wide), Verifier.CODE_STREET_WIDTH)


func test_orphan_street_end_is_reported() -> void:
	var no_street := _map()
	no_street.zones = []
	assert_array_contains(_codes(_map(), no_street), Verifier.CODE_STREET_ORPHAN)


func test_street_axis_offset_is_reported() -> void:
	var shifted := _map()
	shifted.zones = [_road(Rect2i(0, 11, 20, 4))]
	var codes := _codes(_map(), shifted)
	assert_array_contains(codes, Verifier.CODE_STREET_OFFSET)


func test_broken_wall_run_is_reported() -> void:
	var walled := _map()
	walled.buildings = [_wall(Rect2i(18, 2, 2, 4))]
	assert_array_contains(_codes(walled, _map()), Verifier.CODE_WALL)
	var continued := _map()
	continued.buildings = [_wall(Rect2i(0, 2, 2, 4))]
	assert_false(Verifier.CODE_WALL in _codes(walled, continued))


func test_frontage_step_is_reported() -> void:
	var near := _map()
	near.buildings = [_house(Rect2i(16, 0, 4, 20))]
	var far := _map()
	far.buildings = [_house(Rect2i(7, 0, 4, 20))]
	assert_array_contains(_codes(near, far), Verifier.CODE_FRONTAGE)


func test_grace_covers_known_violation_and_flags_stale_entries() -> void:
	var seams := [{"id": "a|b"}]
	var violations: Array[Dictionary] = [
		{"seam": "a|b", "code": Verifier.CODE_HEIGHT, "detail": "x"}
	]
	var budget := BUDGET.duplicate(true)
	budget["grace"] = []
	assert_eq(Verifier.apply_grace(violations, seams, budget)["failures"].size(), 1)
	budget["grace"] = [{"seam": "a|b", "code": Verifier.CODE_HEIGHT, "row": "R-1166"}]
	assert_eq(Verifier.apply_grace(violations, seams, budget)["failures"], [])
	var none: Array[Dictionary] = []
	assert_eq(Verifier.apply_grace(none, seams, budget)["failures"].size(), 1)
	budget["grace"] = [{"seam": "a|b", "code": Verifier.CODE_HEIGHT, "row": ""}]
	assert_true(Verifier.apply_grace(violations, seams, budget)["failures"].size() >= 1)
	assert_eq(Verifier.apply_grace(violations, seams, {})["failures"].size(), 1)


func test_checked_in_budget_is_fail_closed_on_the_real_world() -> void:
	var budget: Dictionary = Verifier.load_budget()
	assert_true(budget.get("tolerances") is Dictionary)
	for entry in budget.get("grace", []):
		assert_false(String(entry.get("row", "")).is_empty(), "grace needs a remediation row")


func _codes(base: MapDefinition, neighbor: MapDefinition) -> Array:
	var codes: Array = []
	for violation in Verifier.evaluate_seam(
		"fixture", base, Vector2i.ZERO, &"east", neighbor, Vector2i(20, 0), &"west", BUDGET
	):
		codes.append(violation["code"])
	return codes


func _map() -> MapDefinition:
	var definition := MapDefinition.new()
	definition.map_id = &"fixture"
	definition.location = &"loc.fixture"
	definition.size_cells = Vector2i(20, 20)
	definition.player_spawn = Vector2(64, 64)
	definition.scope = &"production"
	definition.active = true
	definition.palette = &"clean_painted"
	definition.fingerprint = "fixture-fingerprint"
	definition.base_terrain = MapTypes.TERRAIN_GRASS
	definition.zones = [_road(Rect2i(0, 8, 20, 4))]
	return definition


func _road(rect: Rect2i) -> Dictionary:
	return {"rect": rect, "terrain": MapTypes.TERRAIN_COBBLESTONE}


func _wall(cells: Rect2i) -> Dictionary:
	return _building(&"wall", MapTypes.BUILDING_KIND_WALL, cells)


func _house(cells: Rect2i) -> Dictionary:
	return _building(&"house", MapTypes.BUILDING_KIND_HOUSE, cells)


func _building(id: StringName, kind: StringName, cells: Rect2i) -> Dictionary:
	return {"id": id, "kind": kind, "footprint": Rect2(cells.position * 32, cells.size * 32)}
