extends "res://tests/godot/test_case.gd"

## WS-15: logic side of the interactive ripple sim (no rendering). The impulse queue caps and
## clears, rain droplets are deterministic per frame and scale with intensity, the window
## scrolls in whole texels, hulls emit paired bow/stern impulses, and the sim only exists
## outdoors on maps with water at a tier that enables it.

const WaterRippleSimScript := preload("res://scripts/map/view3d/water_ripple_sim.gd")
const SkyWeather := preload("res://scripts/map/view3d/sky_weather_3d.gd")
const MapBuilder := preload("res://scripts/map/map_builder.gd")
const MapView3D := preload("res://scripts/map/view3d/map_view_3d.gd")
const HarborNorthDefinition := preload(
	"res://scripts/map/definitions/outdoor/reval_harbor_north_definition.gd"
)
const KalevSmithyDefinition := preload(
	"res://scripts/map/definitions/lower_town/kalev_smithy_definition.gd"
)
const STEP_SHADER_PATH := "res://scripts/map/view3d/water_ripple_sim.gdshader"
const WATER_SHADER_PATH := "res://scripts/map/view3d/map_view_water.gdshader"

# gdlint: disable=max-line-length


func test_impulse_queue_caps_at_32_and_clears_after_dispatch() -> void:
	var sim = WaterRippleSimScript.new()
	assert_true(sim.configure(256), "a 256 sim builds its viewports")
	for index in 40:
		sim.add_impulse(Vector2(float(index), 0.0), 1.0, 0.03)
	assert_eq(sim.queued_impulse_count(), WaterRippleSimScript.MAX_IMPULSES, "the queue caps at 32 per step")
	assert_false(sim.add_impulse(Vector2.ZERO, 1.0, 0.03), "a full queue rejects more impulses")
	sim.step(Vector2.ZERO)
	assert_eq(sim.last_impulses.size(), 32, "the step dispatches every queued impulse")
	assert_eq(sim.queued_impulse_count(), 0, "the queue clears after dispatch")
	sim.step(Vector2.ZERO)
	assert_eq(sim.last_impulses.size(), 0, "a dispatched impulse is not replayed")
	sim.free()


func test_impulses_convert_to_window_texels() -> void:
	var sim = WaterRippleSimScript.new()
	sim.configure(256)
	sim.add_impulse(Vector2(10.0, -4.0), 1.0, 0.04)
	sim.step(Vector2(10.0, -4.0))
	var impulse: Vector4 = sim.last_impulses[0]
	# The window is centred on the focus, so an impulse at the focus lands mid-window.
	assert_almost_eq(impulse.x, 128.0, 1.0, "impulse x sits at the window centre")
	assert_almost_eq(impulse.y, 128.0, 1.0, "impulse z sits at the window centre")
	assert_almost_eq(impulse.z, 4.0, 0.001, "a 1-unit radius spans 4 texels at 0.25 u/texel")
	assert_almost_eq(impulse.w, 0.04, 0.0001, "strength passes through")
	var window: Vector4 = sim.window_uniform()
	assert_eq(window.w, 1.0, "an active sim marks the window valid")
	assert_almost_eq(window.z, 64.0, 0.001, "the window spans 64 world units")
	sim.free()


func test_rain_rng_is_deterministic_and_scales_with_intensity() -> void:
	var first := WaterRippleSimScript.rain_drops_for_frame(17, 1.0, 256)
	var again := WaterRippleSimScript.rain_drops_for_frame(17, 1.0, 256)
	var other := WaterRippleSimScript.rain_drops_for_frame(18, 1.0, 256)
	assert_eq(first, again, "the same frame index yields the same droplets")
	assert_ne(first, other, "the next frame yields different droplets")
	assert_eq(first.size(), 40, "full rain emits 40 droplets per step")
	assert_eq(WaterRippleSimScript.rain_drops_for_frame(17, 0.5, 256).size(), 20, "half rain emits 20")
	assert_eq(WaterRippleSimScript.rain_drops_for_frame(17, 0.0, 256).size(), 0, "dry weather emits none")
	for drop in first:
		assert_true(drop.z >= 1.0 and drop.z <= 2.0, "droplet radius stays 1-2 texels")
		assert_true(drop.w >= 0.02 and drop.w <= 0.05, "droplet strength stays 0.02-0.05")
		assert_true(drop.x >= 8.0 and drop.x <= 248.0 and drop.y >= 8.0 and drop.y <= 248.0, "droplets land inside the absorbing border")
	# The sim draws its rain from the frame counter, so a replay matches.
	var sim = WaterRippleSimScript.new()
	sim.configure(256)
	sim.set_rain(1.0)
	sim.step(Vector2.ZERO)
	assert_eq(sim.last_rain_drops, WaterRippleSimScript.rain_drops_for_frame(0, 1.0, 256), "step 0 uses frame 0 droplets")
	sim.set_rain(0.0)
	sim.step(Vector2.ZERO)
	assert_eq(sim.last_rain_drops.size(), 0, "stopping the rain stops the droplets")
	sim.free()


func test_window_shift_is_integer_and_follows_all_four_directions() -> void:
	var texel := WaterRippleSimScript.texel_world_size(256)
	assert_almost_eq(texel, 0.25, 0.00001, "recommended resolves 0.25 units per texel")
	var cases := {
		Vector2(1.0, 0.0): Vector2i(4, 0),
		Vector2(-1.0, 0.0): Vector2i(-4, 0),
		Vector2(0.0, 1.0): Vector2i(0, 4),
		Vector2(0.0, -1.0): Vector2i(0, -4),
	}
	for move: Vector2 in cases:
		var sim = WaterRippleSimScript.new()
		sim.configure(256)
		sim.step(Vector2(3.1, -7.3))
		assert_eq(sim.last_shift, Vector2i.ZERO, "the first step has no history to shift")
		var before: Vector2 = sim.window_origin
		sim.step(Vector2(3.1, -7.3) + move)
		assert_eq(sim.last_shift, cases[move], "a %s move shifts by %s texels" % [str(move), str(cases[move])])
		var moved: Vector2 = sim.window_origin - before
		assert_almost_eq(moved.x, float(sim.last_shift.x) * texel, 0.00001, "origin x moves by whole texels")
		assert_almost_eq(moved.y, float(sim.last_shift.y) * texel, 0.00001, "origin z moves by whole texels")
		sim.free()
	# A sub-texel wobble never shifts the window.
	var origin := WaterRippleSimScript.snap_origin_texel(Vector2(0.01, 0.01), 256)
	assert_eq(WaterRippleSimScript.snap_origin_texel(Vector2(0.02, 0.02), 256), origin, "sub-texel moves keep the origin")
	assert_eq(WaterRippleSimScript.window_shift(Vector2i(5, 5), Vector2i(3, 9)), Vector2i(-2, 4), "shift is next minus previous")


func test_moving_body_emits_paired_bow_and_stern_impulses() -> void:
	var impulses := WaterRippleSimScript.moving_body_impulses(Vector2(10.0, 5.0), Vector2(3.0, 0.0), 2.0, 0.6)
	assert_eq(impulses.size(), 2, "a moving hull emits a bow and a stern impulse")
	var bow: Vector4 = impulses[0]
	var stern: Vector4 = impulses[1]
	assert_almost_eq(bow.x, 12.0, 0.0001, "the bow sits half a length ahead along the velocity")
	assert_almost_eq(stern.x, 8.0, 0.0001, "the stern sits half a length behind")
	assert_almost_eq(bow.y, 5.0, 0.0001, "bow stays on the course line")
	assert_true(bow.w > 0.0, "the bow pushes water up")
	assert_true(stern.w < 0.0, "the stern leaves a hollow")
	assert_almost_eq(bow.z, 0.6, 0.0001, "the impulse radius is the half beam")
	var diagonal := WaterRippleSimScript.moving_body_impulses(Vector2.ZERO, Vector2(0.0, -2.0), 1.0, 0.5)
	assert_almost_eq(diagonal[0].y, -1.0, 0.0001, "the bow follows the heading in z")
	assert_eq(WaterRippleSimScript.moving_body_impulses(Vector2.ZERO, Vector2.ZERO, 1.0, 0.5).size(), 0, "a hull at rest makes no wake")
	var sim = WaterRippleSimScript.new()
	sim.configure(256)
	sim.add_moving_body(Vector2(1.0, 1.0), Vector2(2.0, 2.0), 1.5, 0.5)
	assert_eq(sim.queued_impulse_count(), 2, "add_moving_body queues both impulses")
	sim.free()


func test_sim_is_off_indoors_on_minimum_and_without_water() -> void:
	assert_eq(SkyWeather.quality_settings(SkyWeather.QUALITY_RECOMMENDED)["ripple_sim_size"], 256, "recommended runs 256^2")
	assert_eq(SkyWeather.quality_settings(SkyWeather.QUALITY_MINIMUM)["ripple_sim_size"], 0, "minimum turns the sim off")
	assert_true(WaterRippleSimScript.should_create(SkyWeather.QUALITY_RECOMMENDED, false, true), "outdoor water on recommended simulates")
	assert_false(WaterRippleSimScript.should_create(SkyWeather.QUALITY_MINIMUM, false, true), "minimum never simulates")
	assert_false(WaterRippleSimScript.should_create(SkyWeather.QUALITY_RECOMMENDED, true, true), "interiors never simulate")
	assert_false(WaterRippleSimScript.should_create(SkyWeather.QUALITY_RECOMMENDED, false, false), "dry maps never simulate")
	var sim = WaterRippleSimScript.new()
	assert_false(sim.configure(0), "size 0 builds nothing")
	assert_false(sim.is_active(), "an unconfigured sim is inactive")
	assert_eq(sim.window_uniform().w, 0.0, "an inactive sim marks the window invalid")
	sim.free()


func test_harbor_view_builds_sim_and_smithy_does_not() -> void:
	var harbor: MapDefinition = HarborNorthDefinition.create()
	var harbor_view := MapView3D.create(harbor, MapBuilder.build(harbor))
	var root := (Engine.get_main_loop() as SceneTree).root
	root.add_child(harbor_view)
	var sim = harbor_view.water_ripple_sim()
	assert_true(sim != null, "the outdoor harbour builds a ripple sim")
	assert_eq(sim.viewports().size(), 2, "the sim ping-pongs two viewports")
	for viewport: SubViewport in sim.viewports():
		assert_true(viewport.use_hdr_2d, "ripple state needs a float target")
		assert_eq(viewport.size, Vector2i(256, 256), "recommended state is 256^2")
	assert_true(harbor_view.sky_weather().ripple_sim == sim, "the sky feeds its rain to the sim")
	harbor_view.sky_weather().set_weather(SkyWeather.WEATHER_STORM)
	harbor_view.sky_weather().advance(SkyWeather.TRANSITION_SECONDS)
	var storm_rain: float = harbor_view.sky_weather().rain_intensity()
	assert_true(storm_rain > 0.0, "a storm rains")
	assert_almost_eq(sim.rain_intensity, storm_rain, 0.0001, "storm rain reaches the ripple sim")
	root.remove_child(harbor_view)
	harbor_view.free()
	var smithy: MapDefinition = KalevSmithyDefinition.create()
	var smithy_view := MapView3D.create(smithy, MapBuilder.build(smithy))
	assert_true(smithy_view.water_ripple_sim() == null, "the roofed smithy has no ripple sim")
	smithy_view.free()


func test_shaders_carry_the_wave_equation_and_window_fade() -> void:
	var step_code := (load(STEP_SHADER_PATH) as Shader).code
	assert_true(step_code.contains("2.0 * h - h_prev + wave_c2 * lap"), "the step integrates the damped wave equation")
	assert_true(step_code.contains("uniform vec4 impulses[32]"), "gameplay impulses use a 32-slot array")
	assert_true(step_code.contains("window_shift"), "the step scrolls with the window")
	assert_true(step_code.contains("FRAGCOORD"), "texels are indexed in memory order")
	var water_code := (load(WATER_SHADER_PATH) as Shader).code
	assert_true(water_code.contains("uniform sampler2D ripple_state"), "water samples the ripple state")
	assert_true(water_code.contains("_ripple_weight"), "ripples fade toward the window edge")
	assert_true(water_code.contains("ripple_window.w > 0.5"), "an invalid window disables the ripple path")
