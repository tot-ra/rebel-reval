extends SceneTree
## Spike for ADR 0037 (proposed): can layer 0/1 NPC state scale to a whole city?
##
## Not runtime code. Measures a packed struct-of-arrays store with a minute
## timing wheel (the "abstract" tier), utility scoring, a spatial grid query,
## dormant fast-forward, promotion/demotion and override save size, against a
## naive object-per-citizen baseline. Also self-checks two invariants.
##
##   godot --headless --path . --script tools/benchmarks/npc_mind_scale_benchmark.gd \
##       -- [--sizes=4247,20000,100000] [--out=build/benchmarks/npc_mind_scale.json]
##
## Numbers are host-specific (GDScript, headless, one thread). Compare ratios
## and budgets, not absolute values, and re-run on the target hardware profile.

const MINUTES_PER_DAY := 1440
const GOALS := 16
const CONSIDERATIONS := 5
const NEEDS := 8
const CELL := 128.0
const CITY_SIZE := 2000.0
const STEP_DT := 1.0 / 60.0
const SEED := 1343

## Day pattern: (state, minutes). Durations sum to 1440.
const PATTERNS := [
	[[0, 420], [1, 60], [2, 480], [3, 30], [2, 180], [4, 120], [0, 150]],
	[[0, 360], [5, 90], [1, 45], [2, 420], [6, 60], [2, 120], [4, 90], [0, 255]],
	[[0, 480], [1, 30], [7, 300], [3, 45], [7, 240], [4, 150], [0, 195]],
	[[0, 400], [8, 120], [2, 360], [9, 90], [2, 140], [4, 100], [0, 230]],
]

var _rng := RandomNumberGenerator.new()
var _curve_input := PackedInt32Array()
var _curve_kind := PackedInt32Array()
var _curve_k := PackedFloat32Array()


func _initialize() -> void:
	var sizes := PackedInt32Array([4247, 20000, 100000])
	var out_path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--sizes="):
			sizes = PackedInt32Array()
			for part in arg.trim_prefix("--sizes=").split(",", false):
				sizes.append(int(part))
		elif arg.begins_with("--out="):
			out_path = arg.trim_prefix("--out=")
	_build_curves()
	var report := {
		"spike": "ADR 0037 NPC mind scale",
		"engine": Engine.get_version_info().string,
		"cpu_threads": OS.get_processor_count(),
		"checks": _run_checks(),
		"utility": _bench_utility(),
		"naive_object_per_citizen": _bench_naive(4247),
		"sizes": [],
	}
	for n in sizes:
		report["sizes"].append(_bench_size(n))
	var text := JSON.stringify(report, "  ")
	print(text)
	if out_path != "":
		DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
		var file := FileAccess.open(out_path, FileAccess.WRITE)
		if file:
			file.store_string(text)
	var failed := false
	for key in report["checks"]:
		if not report["checks"][key]:
			failed = true
	quit(1 if failed else 0)


# --- utility scoring -------------------------------------------------------

func _build_curves() -> void:
	_rng.seed = SEED
	for _i in GOALS * CONSIDERATIONS:
		_curve_input.append(_rng.randi() % NEEDS)
		_curve_kind.append(_rng.randi() % 3)
		_curve_k.append(_rng.randf_range(0.5, 3.0))


func _curve(kind: int, x: float, k: float) -> float:
	match kind:
		0:
			return clampf(x, 0.0, 1.0)
		1:
			return pow(clampf(x, 0.0, 1.0), k)
		_:
			return 1.0 - pow(clampf(x, 0.0, 1.0), k)


func _score_best(needs: PackedFloat32Array) -> int:
	var best := 0
	var best_score := -1.0
	for g in GOALS:
		var score := 1.0
		for c in CONSIDERATIONS:
			var idx := g * CONSIDERATIONS + c
			score *= _curve(_curve_kind[idx], needs[_curve_input[idx]], _curve_k[idx])
		if score > best_score:
			best_score = score
			best = g
	return best


func _bench_utility() -> Dictionary:
	var needs := PackedFloat32Array()
	needs.resize(NEEDS)
	var runs := 100000
	var t0 := Time.get_ticks_usec()
	var acc := 0
	for i in runs:
		for j in NEEDS:
			needs[j] = float((i * 31 + j * 17) % 100) / 100.0
		acc += _score_best(needs)
	var us := float(Time.get_ticks_usec() - t0) / float(runs)
	return {
		"goals": GOALS,
		"considerations_per_goal": CONSIDERATIONS,
		"us_per_decision": snappedf(us, 0.01),
		"live_tier_cost_ms_per_second_for_30_npcs_at_1hz": snappedf(us * 30.0 / 1000.0, 0.001),
		"checksum": acc,
	}


# --- naive baseline: one object per citizen, updated every frame -----------

class NaiveCitizen:
	extends RefCounted
	var state := 0
	var timer := 0.0
	var pos := Vector2.ZERO
	var target := Vector2.ZERO

	func update(dt: float) -> void:
		timer -= dt
		if timer <= 0.0:
			state = (state + 1) % 8
			timer = 5.0 + float(state)
			target = Vector2(float(state) * 10.0, float(state) * 7.0)
		pos = pos.move_toward(target, 1.2 * dt)


func _bench_naive(n: int) -> Dictionary:
	var citizens: Array[NaiveCitizen] = []
	for i in n:
		var c := NaiveCitizen.new()
		c.timer = float(i % 7)
		citizens.append(c)
	var frames := 300
	var t0 := Time.get_ticks_usec()
	for _f in frames:
		for c in citizens:
			c.update(STEP_DT)
	var ms := float(Time.get_ticks_usec() - t0) / 1000.0 / float(frames)
	return {"residents": n, "ms_per_frame_every_frame_update": snappedf(ms, 0.001)}


# --- abstract-tier store ----------------------------------------------------

class Store:
	var n := 0
	var state := PackedInt32Array()
	var pattern := PackedInt32Array()
	var leg := PackedInt32Array()
	var due := PackedInt32Array()  # absolute game minute of next event
	var pos := PackedVector2Array()
	var cell := PackedInt32Array()
	var override_goal := PackedInt32Array()  # -1 none
	var wheel: Array = []  # 1440 PackedInt32Array buckets
	var grid := {}  # cell -> PackedInt32Array
	var decisions := 0
	var events := 0


func _cell_of(p: Vector2) -> int:
	return int(p.x / CELL) * 1000 + int(p.y / CELL)


func _make_store(n: int) -> Store:
	_rng.seed = SEED
	var s := Store.new()
	s.n = n
	s.state.resize(n)
	s.pattern.resize(n)
	s.leg.resize(n)
	s.due.resize(n)
	s.pos.resize(n)
	s.cell.resize(n)
	s.override_goal.resize(n)
	s.wheel.resize(MINUTES_PER_DAY)
	for m in MINUTES_PER_DAY:
		s.wheel[m] = PackedInt32Array()
	for i in n:
		s.pattern[i] = _rng.randi() % PATTERNS.size()
		s.leg[i] = 0
		s.state[i] = PATTERNS[s.pattern[i]][0][0]
		s.due[i] = _rng.randi() % 400 + 1
		s.pos[i] = Vector2(_rng.randf() * CITY_SIZE, _rng.randf() * CITY_SIZE)
		s.cell[i] = _cell_of(s.pos[i])
		s.override_goal[i] = -1
		s.wheel[s.due[i] % MINUTES_PER_DAY].append(i)
		_grid_add(s, s.cell[i], i)
	return s


func _grid_add(s: Store, c: int, id: int) -> void:
	if not s.grid.has(c):
		s.grid[c] = PackedInt32Array()
	s.grid[c].append(id)


func _grid_remove(s: Store, c: int, id: int) -> void:
	var bucket: PackedInt32Array = s.grid[c]
	var at := bucket.find(id)
	if at >= 0:
		bucket[at] = bucket[bucket.size() - 1]
		bucket.resize(bucket.size() - 1)
		s.grid[c] = bucket


## Advance one resident by one event. Pure function of (store row, minute).
func _fire(s: Store, i: int, minute: int) -> void:
	var pat: Array = PATTERNS[s.pattern[i]]
	s.leg[i] = (s.leg[i] + 1) % pat.size()
	s.state[i] = pat[s.leg[i]][0]
	var jitter := int(hash([i, s.leg[i]]) % 21) - 10
	var minutes: int = maxi(5, pat[s.leg[i]][1] + jitter)
	s.due[i] = minute + minutes
	# Rare deviation: layer 1 picks a goal and the resident detours.
	if (hash([i, minute]) & 15) == 0:
		var needs := PackedFloat32Array()
		needs.resize(NEEDS)
		for j in NEEDS:
			needs[j] = float(hash([i, minute, j]) % 100) / 100.0
		s.override_goal[i] = _score_best(needs)
		s.decisions += 1
		s.due[i] = minute + 20
	else:
		s.override_goal[i] = -1
	# Teleport to the leg's place (stands in for "interpolate along route").
	var np := Vector2(
		float(hash([i, s.leg[i], 1]) % 2000), float(hash([i, s.leg[i], 2]) % 2000)
	)
	var nc := _cell_of(np)
	if nc != s.cell[i]:
		_grid_remove(s, s.cell[i], i)
		_grid_add(s, nc, i)
		s.cell[i] = nc
	s.pos[i] = np
	s.events += 1


func _process_minute(s: Store, minute: int) -> int:
	var slot := minute % MINUTES_PER_DAY
	var bucket: PackedInt32Array = s.wheel[slot]
	if bucket.is_empty():
		return 0
	s.wheel[slot] = PackedInt32Array()
	var fired := 0
	for i in bucket:
		if s.due[i] != minute:
			continue
		_fire(s, i, minute)
		s.wheel[s.due[i] % MINUTES_PER_DAY].append(i)
		fired += 1
	return fired


func _percentile(sorted_values: PackedFloat64Array, p: float) -> float:
	if sorted_values.is_empty():
		return 0.0
	return sorted_values[mini(sorted_values.size() - 1, int(p * sorted_values.size()))]


## Steps one game day at 60 Hz with `game_seconds_per_step` of game time per
## step. Returns per-step cost distribution of the whole manager tick.
func _run_day(s: Store, game_seconds_per_step: float) -> Dictionary:
	var clock := 0.0
	var minute := 0
	var costs := PackedFloat64Array()
	var max_bucket := 0
	var total_fired := 0
	var end := float(MINUTES_PER_DAY) * 60.0
	while clock < end:
		clock += game_seconds_per_step
		var t0 := Time.get_ticks_usec()
		var target := int(clock / 60.0)
		while minute < target:
			minute += 1
			var fired := _process_minute(s, minute)
			total_fired += fired
			max_bucket = maxi(max_bucket, fired)
		costs.append(float(Time.get_ticks_usec() - t0) / 1000.0)
	costs.sort()
	var sum := 0.0
	for c in costs:
		sum += c
	return {
		"steps": costs.size(),
		"mean_ms": snappedf(sum / float(costs.size()), 0.0001),
		"p95_ms": snappedf(_percentile(costs, 0.95), 0.0001),
		"p99_ms": snappedf(_percentile(costs, 0.99), 0.0001),
		"max_ms": snappedf(costs[costs.size() - 1], 0.0001),
		"events_fired": total_fired,
		"max_events_in_one_minute": max_bucket,
	}


func _bench_size(n: int) -> Dictionary:
	var result := {"residents": n}
	var t0 := Time.get_ticks_usec()
	var s := _make_store(n)
	result["build_ms"] = snappedf(float(Time.get_ticks_usec() - t0) / 1000.0, 0.1)
	# 24-minute game day: 60 game seconds per real second, so 1 game s per step.
	var realtime_store := _make_store(n)
	result["day_24min_realtime"] = _run_day(realtime_store, 60.0 * STEP_DT)
	# Fast forward / sleep: one game hour per real second.
	var fast_store := _make_store(n)
	result["day_fast_forward_1h_per_s"] = _run_day(fast_store, 3600.0 * STEP_DT)

	# Dormant fast-forward: replay 8 game hours for 1000 residents in one call.
	var dormant := _make_store(n)
	var t1 := Time.get_ticks_usec()
	for m in range(1, 8 * 60 + 1):
		_process_minute(dormant, m)
	result["catch_up_8h_all_residents_ms"] = snappedf(
		float(Time.get_ticks_usec() - t1) / 1000.0, 0.1
	)

	# Perception: alarm radius query through the grid.
	var queries := 2000
	var t2 := Time.get_ticks_usec()
	var hits := 0
	for q in queries:
		var centre := Vector2(float(hash([q, 7]) % 2000), float(hash([q, 8]) % 2000))
		var cx := int(centre.x / CELL)
		var cy := int(centre.y / CELL)
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var key := (cx + dx) * 1000 + (cy + dy)
				if not dormant.grid.has(key):
					continue
				for id in dormant.grid[key]:
					if dormant.pos[id].distance_squared_to(centre) < 60.0 * 60.0:
						hits += 1
	result["alarm_query_us"] = snappedf(float(Time.get_ticks_usec() - t2) / float(queries), 0.1)
	result["alarm_query_avg_hits"] = snappedf(float(hits) / float(queries), 0.1)

	# Promotion / demotion: copy a row into a live actor record and back.
	var promos := 20000
	var t3 := Time.get_ticks_usec()
	for k in promos:
		var id := k % n
		var actor := {
			"state": dormant.state[id],
			"pos": dormant.pos[id],
			"leg": dormant.leg[id],
			"due": dormant.due[id],
		}
		dormant.state[id] = actor["state"]
		dormant.pos[id] = actor["pos"]
	result["promote_demote_us"] = snappedf(float(Time.get_ticks_usec() - t3) / float(promos), 0.3)

	# Save size: overrides only (about 10 percent deviate) versus full rows.
	var overrides := {}
	for i in range(0, n, 10):
		overrides[i] = [int(dormant.override_goal[i]), int(dormant.due[i]), 3]
	var full := {
		"state": dormant.state, "leg": dormant.leg, "due": dormant.due, "pos": dormant.pos
	}
	result["save_overrides_bytes"] = var_to_bytes(overrides).size()
	result["save_full_rows_bytes"] = var_to_bytes(full).size()
	result["memory_rows_mb"] = snappedf(float(n * (4 * 5 + 8)) / 1048576.0, 0.01)
	return result


# --- invariants -------------------------------------------------------------

func _run_checks() -> Dictionary:
	var a := _make_store(500)
	var b := _make_store(500)
	# A: stepping minute by minute equals batch catch-up (same code path, split
	# at arbitrary points).
	for m in range(1, 601):
		_process_minute(a, m)
	for m in range(1, 301):
		_process_minute(b, m)
	for m in range(301, 601):
		_process_minute(b, m)
	var equal := a.state == b.state and a.due == b.due and a.leg == b.leg
	# B: every resident sits in exactly one wheel bucket and one grid cell.
	var wheel_ok := true
	var seen := PackedInt32Array()
	seen.resize(a.n)
	for slot in a.wheel:
		for id in slot:
			seen[id] += 1
	for i in a.n:
		if seen[i] != 1:
			wheel_ok = false
	var grid_total := 0
	for key in a.grid:
		grid_total += a.grid[key].size()
	return {
		"catch_up_equals_stepping": equal,
		"each_resident_in_one_wheel_bucket": wheel_ok,
		"each_resident_in_one_grid_cell": grid_total == a.n,
	}
