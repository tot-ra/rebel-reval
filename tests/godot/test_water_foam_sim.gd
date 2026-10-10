extends "res://tests/godot/test_case.gd"

## WR-7 (R-1512, docs/SYSTEMS/CITY_SEA.md "Foam memory"): the city sea's foam buffer is
## sized per sea tier, follows the camera, drifts without resampling, survives the
## ocean_time wrap, reseeds on clock jumps and is read by the sea in vertex() only.

const WATER_SHADER := "res://scripts/map/view3d/map_view_water.gdshader"
const STEP_SHADER := "res://scripts/map/view3d/water_foam_sim.gdshader"
const WRAP := MapViewRuntimeEnvironment.OCEAN_TIME_WRAP_SECONDS


func test_tiers_size_the_window_and_minimum_has_no_sim() -> void:
	assert_eq(WaterFoamSim.sim_size_for_tier(&"minimum"), 0, "minimum keeps analytic foam")
	assert_eq(WaterFoamSim.sim_size_for_tier(&"recommended"), 256, "recommended texels")
	assert_eq(WaterFoamSim.sim_size_for_tier(&"high"), 512, "high texels")
	assert_almost_eq(WaterFoamSim.window_size_for_tier(&"recommended"), 128.0, 0.001, "window")
	assert_eq(WaterFoamSim.sim_size_for_tier(&"auto"), 256, "auto resolves to recommended")
	assert_false(WaterFoamSim.should_create(&"minimum", false, true), "off on minimum")
	assert_false(WaterFoamSim.should_create(&"high", true, true), "off indoors")
	assert_true(WaterFoamSim.should_create(&"high", false, true), "on outdoors, high")


func test_configure_builds_two_hdr_targets_and_minimum_builds_none() -> void:
	var sim := WaterFoamSim.new()
	assert_false(sim.configure(&"minimum"), "minimum builds nothing")
	assert_false(sim.is_active(), "inactive")
	assert_true(sim.configure(&"recommended"), "recommended builds")
	assert_eq(sim.viewports().size(), 2, "ping-pong pair")
	for viewport in sim.viewports():
		assert_true(viewport.use_hdr_2d, "float state")
		assert_eq(viewport.size, Vector2i(256, 256), "tier size")
		assert_eq(viewport.render_target_clear_mode, SubViewport.CLEAR_MODE_NEVER, "keeps state")
	assert_almost_eq(sim.texel_world_size(), 0.5, 0.0001, "0.5 m texels")
	sim.free()


func test_clock_delta_is_continuous_over_the_ocean_time_wrap() -> void:
	assert_almost_eq(WaterFoamSim.clock_delta(10.0, 10.05), 0.05, 0.0001, "plain step")
	assert_almost_eq(WaterFoamSim.clock_delta(WRAP - 0.02, 0.03), 0.05, 0.0001, "across the wrap")
	assert_almost_eq(WaterFoamSim.clock_delta(5.0, 5.0), 0.0, 0.0001, "paused clock")


func test_drift_folds_into_whole_texels_without_losing_distance() -> void:
	var texel := 0.5
	var offset := Vector2.ZERO
	var travelled := Vector2.ZERO
	var whole_total := Vector2i.ZERO
	var step := Vector2(0.37, -0.11)
	for i in 50:
		var folded := WaterFoamSim.fold_drift(offset, step, texel)
		offset = folded[0]
		whole_total += folded[1] as Vector2i
		travelled += step
		assert_true(offset.x >= 0.0 and offset.x < texel, "x offset stays sub-texel")
		assert_true(offset.y >= 0.0 and offset.y < texel, "y offset stays sub-texel")
	var restored := offset + Vector2(whole_total) * texel
	assert_true(
			restored.distance_to(travelled) < 1e-3,
			"no drift lost: %s vs %s" % [restored, travelled])


func test_drift_follows_the_wind_and_grows_with_the_sea() -> void:
	var calm := WaterFoamSim.drift_velocity(Vector2(0.0, 2.0), 0.0)
	var gale := WaterFoamSim.drift_velocity(Vector2(0.0, 2.0), 1.0)
	assert_true(calm.normalized().distance_to(Vector2(0.0, 1.0)) < 1e-4, "downwind")
	assert_true(gale.length() > calm.length() * 3.0, "a gale drifts foam faster")
	assert_true(gale.length() < 1.0, "drift stays a slow fraction of the wind")


## Stored content must stay where the water carried it: after a step, the world position
## of new texel i equals the old position of texel (i + shift) plus the drift.
func test_window_shift_tracks_camera_and_drift_exactly() -> void:
	var sim := WaterFoamSim.new()
	sim.configure(&"recommended")
	var sea := ShaderMaterial.new()
	sea.shader = load(WATER_SHADER)
	sea.set_shader_parameter(&"wind_direction", Vector2(0.6, 0.8))
	sea.set_shader_parameter(&"shore_sea_state", 1.0)
	sim.source_material = sea
	var texel := sim.texel_world_size()
	var focus := Vector2(10.0, -4.0)
	sim.step(focus, 0.0)
	var dt := 1.0 / WaterFoamSim.STEP_HZ
	var velocity := WaterFoamSim.drift_velocity(Vector2(0.6, 0.8), 1.0)
	for i in 120:
		var old_origin := sim.window_origin
		focus += Vector2(0.21, 0.07)
		sim.step(focus, dt)
		var old_position := old_origin + Vector2(sim.last_shift) * texel + velocity * dt
		assert_true(
			sim.window_origin.distance_to(old_position) < 1e-3,
			"step %d: content stays with the water (%s vs %s)" % [i, sim.window_origin, old_position]
		)
	var centre := sim.window_origin + Vector2.ONE * sim.window_size * 0.5
	assert_true(centre.distance_to(focus) <= texel * 1.5, "window follows the focus")
	sim.free()


func test_clock_jump_reseeds_but_the_wrap_does_not() -> void:
	var sim := WaterFoamSim.new()
	sim.configure(&"recommended")
	var now := [WRAP - 0.2]
	sim.clock = func() -> float: return now[0]
	sim._process(0.0)
	sim._process(0.0)
	sim._process(0.0)
	# Two seed steps after configure (the partner target was never drawn).
	now[0] = WRAP - 0.15
	sim._process(0.0)
	now[0] = WRAP - 0.1
	sim._process(0.0)
	assert_false(sim.last_reset, "seed steps are over")
	now[0] = 0.02
	sim._process(0.0)
	assert_false(sim.last_reset, "the wrap is an ordinary step")
	assert_almost_eq(sim.last_dt, minf(0.12, WaterFoamSim.MAX_STEP_DT), 0.0001, "dt across the wrap")
	now[0] = 30.0
	sim._process(0.0)
	assert_true(sim.last_reset, "a 30 s jump reseeds from the analytic foam")
	var frames := sim.frame_index
	sim._process(0.0)
	assert_eq(sim.frame_index, frames, "a paused clock does not step")
	sim.free()


func test_step_kernel_mirrors_the_sea_and_compiles() -> void:
	var shader: Shader = load(STEP_SHADER)
	assert_true(shader != null, "step shader loads")
	var names := {}
	for uniform: Dictionary in shader.get_shader_uniform_list():
		names[String(uniform["name"])] = true
	for required in ["prev_state", "fft_c0_deriv", "shore_field", "choppiness", "window_shift"]:
		assert_true(names.has(required), "kernel declares %s (compiled)" % required)
	var sim := WaterFoamSim.new()
	sim.configure(&"recommended")
	sim.source_material = MapViewMaterials.water_surface(MapTypes.TERRAIN_SHALLOW_WATER)
	sim.step(Vector2.ZERO, 0.0)
	var mirrored := sim.mirrored_uniforms()
	for shared in ["fft_c0_deriv", "fft_cascade", "shore_field", "shore_sea_state",
			"wind_direction", "storm_foam_coverage", "whitecap_onset", "ocean_amplitude"]:
		assert_true(mirrored.has(shared), "mirrors %s from the sea" % shared)
	for own in ["prev_state", "window_shift", "reset_state", "compat_srgb_alpha"]:
		assert_false(mirrored.has(own), "keeps its own %s" % own)
	sim.free()


func test_sea_reads_the_buffer_in_vertex_only_and_falls_back_outside() -> void:
	var source := FileAccess.get_file_as_string(WATER_SHADER)
	var vertex_start := source.find("void vertex()")
	var fragment_start := source.find("void fragment()")
	var read := source.find("textureLod(foam_state")
	assert_true(read > vertex_start and read < fragment_start, "foam_state read in vertex()")
	assert_eq(source.count("foam_state,"), 1, "one read: the fragment stage has no free sampler")
	assert_true(source.contains("mix(breaking * CITY_WHITECAP_GAIN, foam_memory.r, foam_memory.a)"),
		"whitecaps dissolve by the memory inside the window, analytic outside")
	var material := ShaderMaterial.new()
	material.shader = load(WATER_SHADER)
	WaterFoamSim.bind_materials([material], null, Vector4(1.0, 2.0, 128.0, 1.0))
	var window: Vector4 = material.get_shader_parameter(&"foam_window")
	assert_almost_eq(window.w, 0.0, 0.0001, "no texture: analytic foam")


func test_view_focus_lands_on_the_sea_ahead_of_the_camera() -> void:
	var basis := Basis.looking_at(Vector3(0.0, -1.0, -1.0), Vector3.UP)
	var camera := Transform3D(basis, Vector3(0.0, 10.0, 0.0))
	var focus := WaterFoamSim.view_focus(camera, 40.0)
	assert_true(
			focus.distance_to(Vector3(0.0, 0.0, -10.0)) < 0.01,
			"45 deg view hits 10 m ahead: %s" % focus)
	var level := Transform3D.IDENTITY
	level.origin = Vector3(5.0, 3.0, 0.0)
	assert_true(WaterFoamSim.view_focus(level, 40.0).distance_to(Vector3(5.0, 0.0, -40.0)) < 0.01,
		"a level view clamps to the share ahead")
