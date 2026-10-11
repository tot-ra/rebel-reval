extends "res://tests/godot/test_case.gd"

## WR-5 (R-1510, docs/SYSTEMS/CITY_SEA.md "Waves around rocks"): the obstacle mask is
## rasterised from bathymetry plus rocks of every size, the obstacle sim is sized per tier
## and off on minimum, re-rasterises only when its window walks out of the mask, and its
## update scheme stays bounded over 2000 steps (a CPU mirror of the step kernel: headless
## runs have no GPU; tools/water_sandbox/capture.gd --stability=N checks the GPU kernel).

const STEP_SHADER := "res://scripts/map/view3d/water_ripple_sim.gdshader"
const WATER_SHADER := "res://scripts/map/view3d/map_view_water.gdshader"
const SANDBOX := "res://tools/water_sandbox/water_sandbox.gd"


## Sea at y = 0 over a 4 m deep basin; land (a quay) at x >= 20.
static func _basin(xz: Vector2) -> float:
	return 1.6 if xz.x >= 20.0 else -4.0


func test_mask_rasterises_bathymetry_and_rocks_of_all_sizes() -> void:
	var mask := CityObstacleMask.new(_basin, 0.0)
	mask.set_rocks(PackedVector4Array([
		Vector4(5.0, 5.0, 1.5, 0.8),     # emergent boulder: solid core
		Vector4(12.0, 5.0, 0.3, 0.25),   # 0.6 m rock, far below the 2 m heightfield
		Vector4(5.0, 14.0, 1.0, -1.5),   # submerged rock: shallows, not a wall
		Vector4(14.0, 14.0, 0.05, 0.2),  # pebble: below MIN_ROCK_RADIUS, ignored
		Vector4(500.0, 500.0, 2.0, 1.0), # outside the window
	]))
	assert_eq(mask.rocks.size(), 4, "pebbles are not obstacles")
	var texel := 0.25
	var image := mask.rasterise(Vector2i(0, 0), 96, texel)
	assert_eq(image.get_width(), 96, "one texel per sim texel")
	assert_eq(image.get_format(), Image.FORMAT_RF, "float depth")
	var at := func(x: float, z: float) -> float:
		return image.get_pixel(int(x / texel), int(z / texel)).r
	assert_almost_eq(at.call(2.0, 20.0), 4.0, 0.05, "open basin depth")
	assert_true(at.call(21.0, 10.0) <= CityObstacleMask.SOLID_DEPTH, "quay land is solid")
	assert_true(at.call(5.0, 5.0) <= CityObstacleMask.SOLID_DEPTH, "boulder core is solid")
	assert_true(at.call(12.0, 5.0) <= CityObstacleMask.SOLID_DEPTH, "small rock is solid")
	assert_true(at.call(12.5, 5.0) > 3.9, "small rock ends at its radius")
	var shoal: float = at.call(5.0, 14.0)
	assert_true(shoal > 0.0 and shoal < 2.0, "submerged rock makes shallows: %f" % shoal)
	assert_almost_eq(at.call(14.0, 14.0), 4.0, 0.05, "pebble leaves the depth alone")
	# Boulder footprint: emergent where the dome stands above the water, q < 0.884 for a
	# 0.8 m top on a 1.5 m radius (5.5 m2, ~88 texels); the small rock adds ~4.
	var boulder := 0
	var pebble_rock := 0
	for j in image.get_height():
		for i in image.get_width():
			var x := (float(i) + 0.5) * texel
			var z := (float(j) + 0.5) * texel
			if image.get_pixel(i, j).r > CityObstacleMask.SOLID_DEPTH:
				continue
			if Vector2(x - 5.0, z - 5.0).length() < 2.0:
				boulder += 1
			elif Vector2(x - 12.0, z - 5.0).length() < 0.5:
				pebble_rock += 1
	assert_true(boulder > 75 and boulder < 100, "boulder solid texels: %d" % boulder)
	assert_true(pebble_rock >= 2 and pebble_rock <= 6, "small rock solid texels: %d" % pebble_rock)
	assert_true(mask.last_build_usec > 0, "raster is timed")


## A wall's depth profile must not depend on where the window sits: the sim's reflection
## and breaking read it, and a window-phased bathymetry made the quay reflect 8x weaker
## from one camera pose than from another.
func test_raster_is_the_same_from_any_window() -> void:
	var ramp := func(xz: Vector2) -> float:
		return lerpf(-4.0, 1.6, smoothstep(-1.0, 1.0, xz.y)) + 0.1 * sin(xz.x * 0.7)
	var mask := CityObstacleMask.new(ramp, 0.0)
	mask.set_rocks(PackedVector4Array([Vector4(3.3, -6.1, 0.9, 0.4)]))
	var texel := 0.5
	var a := mask.rasterise(Vector2i(-40, -40), 64, texel)
	var b := mask.rasterise(Vector2i(-37, -29), 64, texel)
	var worst := 0.0
	for j in range(11, 64):
		for i in range(3, 64):
			var da := a.get_pixel(i, j).r
			var db := b.get_pixel(i - 3, j - 11).r
			worst = maxf(worst, absf(da - db))
	assert_true(worst < 0.001, "overlapping windows agree texel for texel: %f" % worst)


func test_rock_from_instance_uses_the_scaled_footprint() -> void:
	var box := AABB(Vector3(-0.5, -0.2, -0.5), Vector3(1.0, 0.8, 1.0))
	var xform := Transform3D(Basis().scaled(Vector3(2.0, 3.0, 2.0)), Vector3(10.0, -0.5, 4.0))
	var rock := CityObstacleMask.rock_from_instance(box, xform)
	assert_almost_eq(rock.x, 10.0, 0.001, "centre x")
	assert_almost_eq(rock.y, 4.0, 0.001, "centre z")
	assert_almost_eq(rock.z, 1.0, 0.001, "radius from scaled footprint")
	assert_almost_eq(rock.w, -0.5 + 0.6 * 3.0, 0.001, "top from scaled AABB")
	assert_true(CityObstacleMask.is_rock_kind("boulder_large"), "boulders")
	assert_true(CityObstacleMask.is_rock_kind("stone_cluster_a"), "stone clusters")
	assert_false(CityObstacleMask.is_rock_kind("pebble_patch_a"), "pebbles")
	assert_false(CityObstacleMask.is_rock_kind("algae_skirt"), "weed")


func test_rocks_come_from_built_shore_multimeshes() -> void:
	var root := Node3D.new()
	root.position = Vector3(100.0, 0.0, 0.0)
	var shore := Node3D.new()
	root.add_child(shore)
	var box := BoxMesh.new()
	box.size = Vector3(1.0, 1.0, 1.0)
	for kind in ["boulder_large", "pebble_patch_a"]:
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = box
		multi.instance_count = 2
		multi.set_instance_transform(0, Transform3D(Basis(), Vector3(1.0, 0.0, 2.0)))
		var doubled := Transform3D(Basis().scaled(Vector3.ONE * 2.0), Vector3(5.0, 0.0, 6.0))
		multi.set_instance_transform(1, doubled)
		var inst := MultiMeshInstance3D.new()
		inst.name = "Shore_%s_0_0" % kind
		inst.multimesh = multi
		shore.add_child(inst)
	var rocks := CityObstacleMask.rocks_from_multimeshes(root)
	assert_eq(rocks.size(), 2, "boulders only, pebble patches skipped")
	var probe := (shore.get_child(0) as MultiMeshInstance3D).multimesh
	if probe.get_instance_transform(1).origin == Vector3.ZERO:
		# The headless dummy RenderingServer drops instance buffers; real renderers keep
		# them (checked by tools/water_sandbox/city_obstacle_probe.gd).
		root.free()
		skip("headless RenderingServer keeps no MultiMesh transforms")
		return
	assert_almost_eq(rocks[0].x, 101.0, 0.001, "parent transforms applied outside the tree")
	assert_almost_eq(rocks[1].z, 1.0, 0.001, "scaled instance radius")
	assert_almost_eq(rocks[1].w, 1.0, 0.001, "scaled instance top")
	root.free()


func test_sandbox_mask_holds_boulders_stack_and_quay() -> void:
	var sandbox: Node3D = load(SANDBOX).create()
	var mask: CityObstacleMask = sandbox.obstacle_mask()
	assert_true(mask.rocks.size() > 100, "every sandbox rock is an obstacle: %d" % mask.rocks.size())
	var stack: float = sandbox.bay_centres["stack"]
	assert_true(mask.depth_at(Vector2(stack - 15.0, -30.0)) < 0.0, "the sea stack stands out")
	var quay: float = sandbox.bay_centres["quay"]
	assert_true(mask.depth_at(Vector2(quay, -6.0)) > 3.0, "quay berth is deep")
	assert_true(mask.depth_at(Vector2(quay, 2.0)) < 0.0, "quay deck is solid")
	var boulders := 0
	for rock in sandbox.obstacle_rocks:
		if rock.z < 1.0:
			boulders += 1
	assert_true(boulders > 10, "sub-heightfield rocks are kept: %d" % boulders)
	sandbox.free()


func test_tiers_fix_the_resolution_and_minimum_is_off() -> void:
	assert_eq(WaterRippleSim.obstacle_sim_size_for_tier(&"minimum"), 0, "off on minimum")
	assert_eq(WaterRippleSim.obstacle_sim_size_for_tier(&"recommended"), 128, "recommended")
	assert_eq(WaterRippleSim.obstacle_sim_size_for_tier(&"high"), 256, "high")
	assert_eq(WaterRippleSim.obstacle_sim_size_for_tier(&"auto"), 128, "auto = recommended")
	var sim := WaterRippleSim.new()
	assert_false(sim.configure_obstacles(0, null, null), "size 0 builds nothing")
	assert_false(sim.is_active(), "inactive")
	sim.free()


func test_configure_and_mask_rebuilds_only_outside_the_margin() -> void:
	var sim := WaterRippleSim.new()
	var mask := CityObstacleMask.new(_basin, 0.0)
	assert_true(sim.configure_obstacles(128, mask, null), "builds")
	assert_true(sim.obstacle_mode, "obstacle mode")
	assert_eq(sim.viewports().size(), 2, "ping-pong pair")
	for viewport in sim.viewports():
		assert_true(viewport.use_hdr_2d, "float state")
		var material := (viewport.get_child(0) as ColorRect).material as ShaderMaterial
		assert_true(bool(material.get_shader_parameter(&"obstacle_mode")), "kernel in obstacle mode")
	sim.step_obstacles(Vector2(0.0, 0.0), 0.05)
	assert_eq(sim.mask_builds, 1, "first step rasterises")
	assert_true(sim.mask_texture() != null, "mask uploaded")
	assert_eq(sim.mask_texture().get_width(), 128 + WaterRippleSim.OBSTACLE_MASK_MARGIN * 2, "margin")
	# A few metres of walking stays inside the margin (32 texels of 0.5 m = 16 m).
	sim.step_obstacles(Vector2(6.0, -4.0), 0.05)
	assert_eq(sim.mask_builds, 1, "no raster while inside the margin")
	sim.step_obstacles(Vector2(40.0, 0.0), 0.05)
	assert_eq(sim.mask_builds, 2, "raster again once the window leaves it")
	assert_true(sim.step_usec_mean > 0.0, "CPU cost is measured")
	var window := sim.window_uniform()
	assert_almost_eq(window.z, WaterRippleSim.WINDOW_WORLD_SIZE, 0.001, "64 m window")
	assert_almost_eq(window.w, 1.0, 0.001, "valid")
	sim.free()


func test_ocean_clock_jump_restarts_flat() -> void:
	var sim := WaterRippleSim.new()
	sim.configure_obstacles(128, CityObstacleMask.new(_basin, 0.0), null)
	MapViewRuntimeEnvironment.set_ocean_time(10.0)
	assert_almost_eq(sim._ocean_dt(), 0.0, 0.0001, "first read has no delta")
	MapViewRuntimeEnvironment.set_ocean_time(10.04)
	assert_almost_eq(sim._ocean_dt(), 0.04, 0.0001, "frame delta")
	sim._reset_steps_left = 0
	MapViewRuntimeEnvironment.set_ocean_time(4.0)
	assert_almost_eq(sim._ocean_dt(), 0.0, 0.0001, "a jump is no step")
	assert_eq(sim._reset_steps_left, WaterRippleSim.RESET_STEPS, "a jump restarts flat")
	MapViewRuntimeEnvironment.set_ocean_time(WaterRippleSim.OBSTACLE_DT_MAX * 0.5)
	sim._last_ocean_time = MapViewRuntimeEnvironment.OCEAN_TIME_WRAP_SECONDS - 0.01
	assert_almost_eq(sim._ocean_dt(), 0.01 + WaterRippleSim.OBSTACLE_DT_MAX * 0.5, 0.0001, "wrap-safe")
	sim.free()


## CPU mirror of _obstacle_step (water_ripple_sim.gdshader) on a small grid: a quay wall,
## an emergent rock, a submerged shoal and a beach ramp under a gale swell. 2000 steps at
## the longest step (DT_MAX) and at 60 Hz must stay finite and bounded, and the wall must
## reflect (the scattered field is not zero) and collect foam.
func test_scheme_is_stable_for_2000_steps() -> void:
	for dt: float in [WaterRippleSim.OBSTACLE_DT_MAX, 1.0 / 60.0]:
		var result := _run_reference(2000, dt, 0.5)
		assert_true(result["finite"], "finite at dt %.4f" % dt)
		assert_true(result["max_s"] < 2.0, "bounded height at dt %.4f: %f" % [dt, result["max_s"]])
		var scattered: float = result["max_s"]
		assert_true(scattered > 0.05, "walls scatter the swell at dt %.4f: %f" % [dt, scattered])
		assert_true(result["max_foam"] > 0.05, "impact foam at the wall: %f" % result["max_foam"])
		assert_true(result["late_max_s"] < result["max_s"] * 1.5 + 0.01, "no late growth")


func test_kernel_contract() -> void:
	var step := FileAccess.get_file_as_string(STEP_SHADER)
	assert_true(step.contains("uniform bool obstacle_mode"), "one kernel, two modes")
	assert_true(step.contains("courant * courant / dt * lap"), "velocity update mirrored by the test")
	var expected := {
		"_incident(_obstacle_world(back)) - inc_c": "Neumann ghost from the water side",
		"uniform float obstacle_max_courant = 0.5;": "CFL cap mirrored by the test",
		"uniform float obstacle_smoothing = 0.05;": "smoothing mirrored by the test",
		"uniform vec2 obstacle_steep_slope = vec2(0.15, 0.5);": "breaking slope mirrored",
		"shore_state(xz, ocean_time, shore_sea())": "impact foam sees the shore breakers too",
	}
	for needle: String in expected:
		assert_true(step.contains(needle), expected[needle])
	var sea := FileAccess.get_file_as_string(WATER_SHADER)
	assert_true(sea.contains("uniform vec4 obstacle_window"), "sea reads the obstacle window")
	var foam_call := "_foam_dissolve(city_foam.x, clamp(obstacle_foam"
	assert_true(sea.contains(foam_call), "impact foam attached")
	for uniform_name in WaterRippleSim.OBSTACLE_SEA_UNIFORMS:
		assert_true(
			sea.contains(" %s" % uniform_name) or _includes_declare(uniform_name),
			"sea declares %s" % uniform_name
		)


static func _includes_declare(uniform_name: StringName) -> bool:
	for path in [
		"res://scripts/map/view3d/ocean_fft_common.gdshaderinc",
		"res://scripts/map/view3d/shore_swash.gdshaderinc",
	]:
		if FileAccess.get_file_as_string(path).contains(" %s" % uniform_name):
			return true
	return false


func _run_reference(steps: int, dt: float, texel: float) -> Dictionary:
	var n := 24
	var depth := PackedFloat32Array()
	depth.resize(n * n)
	for j in n:
		for i in n:
			var d := 3.0
			if i >= 20:
				d = -1.6  # quay
			if Vector2(i - 9, j - 13).length() < 2.5:
				d = -0.5  # emergent rock
			if Vector2(i - 14, j - 5).length() < 2.0:
				d = 0.3  # shoal
			if j < 2:
				d = 0.2 + float(j) * 0.3  # beach ramp
			depth[j * n + i] = d
	var s := PackedFloat32Array()
	var v := PackedFloat32Array()
	var foam := PackedFloat32Array()
	s.resize(n * n)
	v.resize(n * n)
	foam.resize(n * n)
	var k := TAU / WaterRippleSim.OBSTACLE_WAVELENGTH
	var omega := sqrt(WaterRippleSim.OBSTACLE_GRAVITY * k)
	var amplitude := 0.6
	var max_s := 0.0
	var late_max := 0.0
	var max_foam := 0.0
	var finite := true
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for step in steps:
		var t := float(step) * dt
		var s2 := s.duplicate()
		var v2 := v.duplicate()
		var f2 := foam.duplicate()
		for j in n:
			for i in n:
				var idx := j * n + i
				var d := depth[idx]
				if d <= 0.0:
					s2[idx] = 0.0
					v2[idx] = 0.0
					f2[idx] = 0.0
					continue
				var lap := 0.0
				var lap_v := 0.0
				var walls := 0.0
				var inc_c := amplitude * sin(k * (float(i) + 0.5) * texel - omega * t)
				for dir: Vector2i in dirs:
					var q := Vector2i(i, j) + dir
					var inside := q.x >= 0 and q.y >= 0 and q.x < n and q.y < n
					var dq := depth[q.y * n + q.x] if inside else 100.0
					if dq <= 0.0:
						var b := Vector2i(i, j) - dir
						var back_ok := b.x >= 0 and b.y >= 0 and b.x < n and b.y < n and depth[b.y * n + b.x] > 0.0
						var inc_b := amplitude * sin(k * (float(b.x) + 0.5) * texel - omega * t)
						lap += (inc_b - inc_c) if back_ok else 0.0
						walls += 1.0
					elif inside:
						lap += s[q.y * n + q.x] - s[idx]
						lap_v += v[q.y * n + q.x] - v[idx]
					else:
						lap += -s[idx]
						lap_v += -v[idx]
				var speed := sqrt(WaterRippleSim.OBSTACLE_GRAVITY / k * tanh(k * maxf(d, 0.02)))
				var courant := minf(speed * dt / texel, 0.5)
				var vel := v[idx] + courant * courant / dt * lap + 0.05 * lap_v
				var edge := float(mini(mini(i, j), mini(n - 1 - i, n - 1 - j))) + 0.5
				var grad := Vector2(
					_clamped_depth(depth, n, i + 2, j) - _clamped_depth(depth, n, i - 2, j),
					_clamped_depth(depth, n, i, j + 2) - _clamped_depth(depth, n, i, j - 2)
				)
				var bed_slope := grad.length() / (4.0 * texel)
				var breaking := (1.0 - smoothstep(0.0, 0.6, d)) \
					* (1.0 - smoothstep(0.15, 0.5, bed_slope))
				var rate := 0.05 + 6.0 * breaking + 8.0 * (1.0 - smoothstep(0.0, 8.0, edge))
				vel *= exp(-rate * dt)
				var h := (s[idx] + vel * dt) * exp(-(rate * 0.5 + 0.05) * dt)
				s2[idx] = clampf(h, -3.0, 3.0)
				v2[idx] = clampf(vel, -20.0, 20.0)
				var fo := foam[idx] * exp(-0.35 * dt)
				if walls > 0.0:
					# Steep faces only (the near-wall band of the kernel is left out here).
					fo += 2.5 * dt * smoothstep(0.0, 0.12, h + inc_c) * minf(walls, 2.0) \
						* smoothstep(0.08, 0.25, d)
				f2[idx] = clampf(fo, 0.0, 1.0)
		s = s2
		v = v2
		foam = f2
		for idx in n * n:
			var a := absf(s[idx])
			if is_nan(a) or is_inf(a):
				finite = false
			max_s = maxf(max_s, a)
			if step >= steps - 200:
				late_max = maxf(late_max, a)
			max_foam = maxf(max_foam, foam[idx])
	return {"finite": finite, "max_s": max_s, "late_max_s": late_max, "max_foam": max_foam}


static func _clamped_depth(depth: PackedFloat32Array, n: int, i: int, j: int) -> float:
	if i < 0 or j < 0 or i >= n or j >= n:
		return 2.0
	return clampf(depth[j * n + i], -0.5, 2.0)
