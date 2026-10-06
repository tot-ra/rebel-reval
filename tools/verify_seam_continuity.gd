extends SceneTree

## UF-08 / R-1117: fail-closed form-continuity gate for `reval_outdoor` seams.
##
##   godot --headless --path . --script tools/verify_seam_continuity.gd
##
## MapAlignmentMath / verify_world_layout.py prove a seam's span and origin. They say
## nothing about what is authored on either side of the aperture. This tool compiles
## every group member (the same MapBlueprintCompiler output the runtime streams) and
## compares the cells along each shared edge: ground height, street crossings, frontage
## line, town wall and ditch. It is a Godot script, not Python, because heights and
## semantic records only exist in compiled MapDefinitions.
##
## Streets: UF-03 / UF-05 have not landed a compiled StreetNetwork yet, so a "street"
## here is a run of road-surface cells on the seam edge (`street_terrains` in the
## budget). Width, lateral offset and surface are compared per run; a run with no
## counterpart is an orphan end. When street records exist, swap `_road_runs` for them.
##
## Exit 0 only when every violation is covered by a named `grace` entry and no grace
## entry is stale (a fixed seam must have its grace row removed).

const BUDGET_PATH := "res://docs/data/seam_continuity_budget.json"

const CODE_HEIGHT := "SEAM_HEIGHT_STEP"
const CODE_STREET_ORPHAN := "SEAM_STREET_ORPHAN"
const CODE_STREET_WIDTH := "SEAM_STREET_WIDTH_JUMP"
const CODE_STREET_OFFSET := "SEAM_STREET_OFFSET"
const CODE_STREET_SURFACE := "SEAM_STREET_SURFACE"
const CODE_FRONTAGE := "SEAM_FRONTAGE_STEP"
const CODE_WALL := "SEAM_WALL_BROKEN"
const CODE_DITCH := "SEAM_DITCH_BROKEN"
const CODE_BUDGET := "SEAM_BUDGET_INVALID"
const CODE_GRACE_STALE := "SEAM_GRACE_STALE"

const NON_FRONTAGE_KINDS: Array[StringName] = [
	MapTypes.BUILDING_KIND_WALL,
	MapTypes.BUILDING_KIND_INTERIOR_WALL,
	MapTypes.BUILDING_KIND_INTERIOR_BLOCK,
]


func _init() -> void:
	var budget := load_budget()
	var compiled := MapWorldLayout.compile_members()
	var failures: Array[String] = []
	for error in compiled["errors"]:
		failures.append(str(error))
	var definitions: Array[MapDefinition] = compiled["definitions"]
	var layout := MapWorldLayout.build(
		definitions, &"lower_town_slice", MapWorldLayout.DEFAULT_WORLD_GROUP_ID
	)
	var violations := verify_layout(definitions, layout, budget)
	var report := apply_grace(violations, layout["seams"], budget)
	print_table(layout["seams"], violations, report)
	failures.append_array(report["failures"])
	for failure in failures:
		printerr(failure)
	print(
		"seam continuity: %d seam(s), %d violation(s), %d graced, %d failure(s)"
		% [layout["seams"].size(), violations.size(), report["graced"].size(), failures.size()]
	)
	quit(0 if failures.is_empty() else 1)


static func load_budget(path: String = BUDGET_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Dictionary if parsed is Dictionary else {}


## Every physical seam in `layout`, compared on compiled definitions.
static func verify_layout(
	definitions: Array[MapDefinition], layout: Dictionary, budget: Dictionary
) -> Array[Dictionary]:
	var violations: Array[Dictionary] = []
	var by_id: Dictionary = {}
	for definition in definitions:
		by_id[definition.map_id] = definition
	var origins: Dictionary = {}
	for location in layout["locations"]:
		origins[location["location_id"]] = Vector2i(location["origin_cell"])
	for seam in layout["seams"]:
		var base_id: StringName = seam["base_map_id"]
		var neighbor_id: StringName = seam["neighbor_map_id"]
		if not by_id.has(base_id) or not by_id.has(neighbor_id):
			violations.append(_violation(String(seam["id"]), CODE_BUDGET, "member did not compile"))
			continue
		violations.append_array(
			evaluate_seam(
				String(seam["id"]),
				by_id[base_id], origins[base_id], StringName(seam["base_side"]),
				by_id[neighbor_id], origins[neighbor_id], StringName(seam["neighbor_side"]),
				budget
			)
		)
	return violations


## Pure comparison of two compiled maps across one seam. Origins are global cells.
static func evaluate_seam(
	seam_id: String,
	base: MapDefinition, base_origin: Vector2i, base_side: StringName,
	neighbor: MapDefinition, neighbor_origin: Vector2i, neighbor_side: StringName,
	budget: Dictionary
) -> Array[Dictionary]:
	var tolerances: Dictionary = budget.get("tolerances", {})
	var roads := _string_names(budget.get("street_terrains", []))
	var a := edge_samples(base, base_origin, base_side, roads, tolerances)
	var b := edge_samples(neighbor, neighbor_origin, neighbor_side, roads, tolerances)
	var lo := maxi(int(a["first"]), int(b["first"]))
	var hi := mini(int(a["last"]), int(b["last"]))
	var violations: Array[Dictionary] = []
	if hi < lo:
		return violations
	var rows_a: Dictionary = a["rows"]
	var rows_b: Dictionary = b["rows"]

	var height_tol := float(tolerances.get("height_delta", 0.5))
	var frontage_tol := float(tolerances.get("frontage_step_cells", 3.0))
	var worst_height := 0.0
	var worst_frontage := 0.0
	var height_at := -1
	var frontage_at := -1
	for t in range(lo, hi + 1):
		var row_a: Dictionary = rows_a[t]
		var row_b: Dictionary = rows_b[t]
		var delta := absf(float(row_a["height"]) - float(row_b["height"]))
		if delta > worst_height:
			worst_height = delta
			height_at = t
		if float(row_a["frontage"]) >= 0.0 and float(row_b["frontage"]) >= 0.0:
			var step := absf(float(row_a["frontage"]) - float(row_b["frontage"]))
			if step > worst_frontage:
				worst_frontage = step
				frontage_at = t
	if worst_height > height_tol:
		violations.append(_violation(
			seam_id, CODE_HEIGHT,
			"ground steps %.2f m at along-cell %d (budget %.2f)" % [worst_height, height_at, height_tol]
		))
	if worst_frontage > frontage_tol:
		violations.append(_violation(
			seam_id, CODE_FRONTAGE,
			"frontage line steps %.1f cells at along-cell %d (budget %.1f)"
			% [worst_frontage, frontage_at, frontage_tol]
		))
	violations.append_array(_compare_streets(seam_id, rows_a, rows_b, lo, hi, tolerances))
	violations.append_array(_compare_walls(seam_id, rows_a, rows_b, lo, hi))
	violations.append_array(_compare_runs(seam_id, "ditch", CODE_DITCH, rows_a, rows_b, lo, hi))
	return violations


## Per along-edge global cell: height, terrain, wall/ditch flags and frontage depth.
static func edge_samples(
	definition: MapDefinition, origin: Vector2i, side: StringName,
	road_terrains: Array[StringName], tolerances: Dictionary
) -> Dictionary:
	var grid := MapBuilder.build(definition)
	var size := definition.size_cells
	var horizontal := side == &"north" or side == &"south"
	var count := size.x if horizontal else size.y
	var band := int(tolerances.get("frontage_band_cells", 8))
	var rows: Dictionary = {}
	for i in count:
		var cell := _edge_cell(size, side, i)
		var along := (origin.x if horizontal else origin.y) + i
		var terrain := grid.get_terrain(cell)
		rows[along] = {
			"height": definition.height_at(cell),
			"terrain": terrain,
			"road": road_terrains.has(terrain),
			"wall": _wall_touches(definition, cell, false),
			"wall_end": _wall_touches(definition, cell, true, horizontal),
			"ditch": _ditch_touches(definition, cell),
			"frontage": _frontage_depth(definition, size, side, i, band),
		}
	var first := origin.x if horizontal else origin.y
	return {"rows": rows, "first": first, "last": first + count - 1}


static func _edge_cell(size: Vector2i, side: StringName, i: int) -> Vector2i:
	match side:
		&"north":
			return Vector2i(i, 0)
		&"south":
			return Vector2i(i, size.y - 1)
		&"west":
			return Vector2i(0, i)
	return Vector2i(size.x - 1, i)


## `ends_only` keeps just walls that run INTO the edge (longer across the seam than along
## it). A wall lying along its own map's boundary row (a garden wall, the city wall above a
## harbour) is that map's border, not a wall that stops at the seam, so it must not be
## reported as broken when the neighbour has no wall on the shared line.
static func _wall_touches(
	definition: MapDefinition, cell: Vector2i, ends_only: bool, horizontal_edge: bool = true
) -> bool:
	var pixel := float(definition.cell_size)
	var rect := Rect2(Vector2(cell) * pixel, Vector2(pixel, pixel))
	for building in definition.buildings:
		if StringName(building.get("kind", &"")) != MapTypes.BUILDING_KIND_WALL:
			continue
		var footprint: Rect2 = building["footprint"]
		if not rect.intersects(footprint):
			continue
		if not ends_only:
			return true
		var along := footprint.size.x if horizontal_edge else footprint.size.y
		var across := footprint.size.y if horizontal_edge else footprint.size.x
		if across > along:
			return true
	return false


static func _ditch_touches(definition: MapDefinition, cell: Vector2i) -> bool:
	var centre := Vector2(cell) + Vector2(0.5, 0.5)
	for feature in definition.relief_features:
		if StringName(feature.get("kind", &"")) != &"ditch":
			continue
		var start := Vector2(feature["start"])
		var end := Vector2(feature["end"])
		var closest := Geometry2D.get_closest_point_to_segment(centre, start, end)
		if centre.distance_to(closest) <= float(feature["width"]) * 0.5 + 0.5:
			return true
	return false


## Distance in cells from the seam inward to the nearest non-wall building face that
## covers this along-edge cell, or -1 when the band is open.
static func _frontage_depth(
	definition: MapDefinition, size: Vector2i, side: StringName, i: int, band: int
) -> float:
	var horizontal := side == &"north" or side == &"south"
	var pixel := float(definition.cell_size)
	var best := -1.0
	for building in definition.buildings:
		if NON_FRONTAGE_KINDS.has(StringName(building.get("kind", &""))):
			continue
		var rect: Rect2 = building["footprint"]
		var lo := (rect.position.x if horizontal else rect.position.y) / pixel
		var hi := (rect.end.x if horizontal else rect.end.y) / pixel
		if float(i) + 0.5 < lo or float(i) + 0.5 > hi:
			continue
		var depth := 0.0
		match side:
			&"north":
				depth = rect.position.y / pixel
			&"south":
				depth = float(size.y) - rect.end.y / pixel
			&"west":
				depth = rect.position.x / pixel
			_:
				depth = float(size.x) - rect.end.x / pixel
		if depth < 0.0 or depth > float(band):
			continue
		if best < 0.0 or depth < best:
			best = depth
	return best


## Contiguous runs of `true` for `key` between lo and hi: [{start, end, terrain}].
static func _runs(rows: Dictionary, key: String, lo: int, hi: int) -> Array[Dictionary]:
	var runs: Array[Dictionary] = []
	var open := -1
	for t in range(lo, hi + 2):
		var on := t <= hi and bool(rows[t][key])
		if on and open < 0:
			open = t
		elif not on and open >= 0:
			runs.append({"start": open, "end": t - 1, "terrain": rows[open]["terrain"]})
			open = -1
	return runs


## Road-surface runs narrow enough to be a street. A run wider than `max_width` is open
## ground (the map's `dirt` base fill, a paved yard or a forecourt) that merely touches the
## edge; treating it as a street produced 100-cell "streets" and false orphans/width jumps.
static func _street_runs(rows: Dictionary, lo: int, hi: int, max_width: int) -> Array[Dictionary]:
	var streets: Array[Dictionary] = []
	for run in _runs(rows, "road", lo, hi):
		if int(run["end"]) - int(run["start"]) + 1 <= max_width:
			streets.append(run)
	return streets


static func _overlap(x: Dictionary, y: Dictionary) -> int:
	return mini(int(x["end"]), int(y["end"])) - maxi(int(x["start"]), int(y["start"])) + 1


static func _match_runs(runs_a: Array[Dictionary], runs_b: Array[Dictionary]) -> Dictionary:
	var pairs: Array[Array] = []
	var used_b: Dictionary = {}
	var orphans_a: Array[Dictionary] = []
	for run_a in runs_a:
		var found := -1
		for j in runs_b.size():
			if not used_b.has(j) and _overlap(run_a, runs_b[j]) > 0:
				found = j
				break
		if found < 0:
			orphans_a.append(run_a)
		else:
			used_b[found] = true
			pairs.append([run_a, runs_b[found]])
	var orphans_b: Array[Dictionary] = []
	for j in runs_b.size():
		if not used_b.has(j):
			orphans_b.append(runs_b[j])
	return {"pairs": pairs, "orphans": orphans_a + orphans_b}


static func _compare_streets(
	seam_id: String, rows_a: Dictionary, rows_b: Dictionary, lo: int, hi: int, tolerances: Dictionary
) -> Array[Dictionary]:
	var width_tol := int(tolerances.get("street_width_delta_cells", 2))
	var offset_tol := float(tolerances.get("street_offset_cells", 2.0))
	var min_width := int(tolerances.get("street_min_width_cells", 2))
	var max_width := int(tolerances.get("street_max_width_cells", 16))
	var matched := _match_runs(
		_street_runs(rows_a, lo, hi, max_width), _street_runs(rows_b, lo, hi, max_width)
	)
	var violations: Array[Dictionary] = []
	for orphan in matched["orphans"]:
		var width := int(orphan["end"]) - int(orphan["start"]) + 1
		if width >= min_width:
			violations.append(_violation(
				seam_id, CODE_STREET_ORPHAN,
				"%d-cell %s street at along-cells %d..%d ends at the seam with no counterpart"
				% [width, orphan["terrain"], orphan["start"], orphan["end"]]
			))
	for pair in matched["pairs"]:
		var run_a: Dictionary = pair[0]
		var run_b: Dictionary = pair[1]
		var width_a := int(run_a["end"]) - int(run_a["start"]) + 1
		var width_b := int(run_b["end"]) - int(run_b["start"]) + 1
		if absi(width_a - width_b) > width_tol:
			violations.append(_violation(
				seam_id, CODE_STREET_WIDTH,
				"street width %d vs %d cells at along-cell %d" % [width_a, width_b, run_a["start"]]
			))
		var centre_a := (float(run_a["start"]) + float(run_a["end"])) * 0.5
		var centre_b := (float(run_b["start"]) + float(run_b["end"])) * 0.5
		if absf(centre_a - centre_b) > offset_tol:
			violations.append(_violation(
				seam_id, CODE_STREET_OFFSET,
				"street axis jumps %.1f cells at along-cell %d" % [absf(centre_a - centre_b), run_a["start"]]
			))
		if run_a["terrain"] != run_b["terrain"]:
			violations.append(_violation(
				seam_id, CODE_STREET_SURFACE,
				"street surface %s vs %s at along-cell %d"
				% [run_a["terrain"], run_b["terrain"], run_a["start"]]
			))
	return violations


## A wall that ends at the seam must meet a wall (end-on or along the neighbour's edge).
static func _compare_walls(
	seam_id: String, rows_a: Dictionary, rows_b: Dictionary, lo: int, hi: int
) -> Array[Dictionary]:
	var violations: Array[Dictionary] = []
	for sides in [[rows_a, rows_b], [rows_b, rows_a]]:
		var other_runs := _runs(sides[1], "wall", lo, hi)
		for run in _runs(sides[0], "wall_end", lo, hi):
			var met := false
			for other in other_runs:
				if _overlap(run, other) > 0:
					met = true
					break
			if not met:
				violations.append(_violation(
					seam_id, CODE_WALL,
					"wall run at along-cells %d..%d does not continue across the seam"
					% [run["start"], run["end"]]
				))
	return violations


static func _compare_runs(
	seam_id: String, key: String, code: String,
	rows_a: Dictionary, rows_b: Dictionary, lo: int, hi: int
) -> Array[Dictionary]:
	var matched := _match_runs(_runs(rows_a, key, lo, hi), _runs(rows_b, key, lo, hi))
	var violations: Array[Dictionary] = []
	for orphan in matched["orphans"]:
		violations.append(_violation(
			seam_id, code,
			"%s run at along-cells %d..%d does not continue across the seam"
			% [key, orphan["start"], orphan["end"]]
		))
	return violations


## Splits violations into graced and failing. Fail closed: an unexplained violation
## fails, and so does a grace entry that no longer matches one.
static func apply_grace(
	violations: Array[Dictionary], seams: Array, budget: Dictionary
) -> Dictionary:
	var failures: Array[String] = []
	var graced: Array[Dictionary] = []
	if budget.is_empty() or not budget.get("tolerances") is Dictionary:
		failures.append("%s: %s missing or has no tolerances" % [CODE_BUDGET, BUDGET_PATH])
		return {"failures": failures, "graced": graced}
	var grace: Dictionary = {}
	for entry in budget.get("grace", []):
		var key := "%s#%s" % [entry["seam"], entry["code"]]
		if String(entry.get("row", "")).is_empty():
			failures.append("%s: grace %s names no remediation row" % [CODE_BUDGET, key])
		grace[key] = false
	var seam_ids: Dictionary = {}
	for seam in seams:
		seam_ids[String(seam["id"])] = true
	for violation in violations:
		var key := "%s#%s" % [violation["seam"], violation["code"]]
		if grace.has(key):
			grace[key] = true
			graced.append(violation)
		else:
			failures.append("%s %s: %s" % [violation["code"], violation["seam"], violation["detail"]])
	for key in grace:
		var seam_id := String(key).split("#")[0]
		if not seam_ids.has(seam_id):
			failures.append("%s: grace %s names an unknown seam" % [CODE_GRACE_STALE, key])
		elif not grace[key]:
			failures.append("%s: grace %s no longer fires; remove it" % [CODE_GRACE_STALE, key])
	return {"failures": failures, "graced": graced}


static func print_table(seams: Array, violations: Array[Dictionary], report: Dictionary) -> void:
	var graced_keys: Dictionary = {}
	for violation in report["graced"]:
		graced_keys["%s#%s" % [violation["seam"], violation["code"]]] = true
	print("%-92s %s" % ["seam", "result"])
	for seam in seams:
		var codes: Array[String] = []
		for violation in violations:
			if violation["seam"] == seam["id"]:
				var key := "%s#%s" % [violation["seam"], violation["code"]]
				var tag := String(violation["code"]) + ("(grace)" if graced_keys.has(key) else "")
				if not codes.has(tag):
					codes.append(tag)
		print("%-92s %s" % [seam["id"], "ok" if codes.is_empty() else ", ".join(codes)])


static func _violation(seam_id: String, code: String, detail: String) -> Dictionary:
	return {"seam": seam_id, "code": code, "detail": detail}


static func _string_names(values: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for value in values:
		result.append(StringName(String(value)))
	return result
