extends "res://tests/godot/test_case.gd"

## WS-13: logic side of the underwater view (no rendering). Camera medium classification
## with hysteresis, the quad hidden in AIR, the SFX low-pass only under water, the wet lens
## after surfacing, and the pass only on outdoor maps with water.

const UnderwaterPassScript := preload("res://scripts/map/view3d/underwater_pass.gd")
const MapBuilder := preload("res://scripts/map/map_builder.gd")
const MapView3D := preload("res://scripts/map/view3d/map_view_3d.gd")
const MeshConfig := preload("res://scripts/map/view3d/map_view_mesh_builder_config.gd")
const HarborNorthDefinition := preload(
	"res://scripts/map/definitions/outdoor/reval_harbor_north_definition.gd"
)
const KalevSmithyDefinition := preload(
	"res://scripts/map/definitions/lower_town/kalev_smithy_definition.gd"
)
const PASS_SHADER_PATH := "res://scripts/map/view3d/underwater_pass.gdshader"
const FFT_INCLUDE_PATH := "res://scripts/map/view3d/ocean_fft_common.gdshaderinc"
const CAUSTICS_INCLUDE_PATH := "res://scripts/map/view3d/caustics_common.gdshaderinc"

# gdlint: disable=max-line-length

const AIR := UnderwaterPassScript.STATE_AIR
const STRADDLE := UnderwaterPassScript.STATE_STRADDLE
const UNDER := UnderwaterPassScript.STATE_UNDER
const FRAME := 1.0 / 60.0


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _make_pass(projection: Camera3D.ProjectionType = Camera3D.PROJECTION_PERSPECTIVE) -> UnderwaterPass:
	var camera := Camera3D.new()
	camera.projection = projection
	camera.near = 0.05
	camera.fov = 70.0
	var pass_node: UnderwaterPass = UnderwaterPassScript.new()
	pass_node.configure(camera, Callable(), &"recommended")
	pass_node.add_child(camera)
	_root().add_child(pass_node)
	return pass_node


func _drop(pass_node: UnderwaterPass) -> void:
	# _exit_tree re-opens the global SFX bus, so a failed test cannot leave it muffled.
	_root().remove_child(pass_node)
	pass_node.free()


func test_classification_uses_the_near_plane_band_with_hysteresis() -> void:
	var band := 0.1
	var hyst := 0.025
	assert_eq(UnderwaterPassScript.classify(-1.0, band, AIR, hyst), AIR, "well above the surface is AIR")
	assert_eq(UnderwaterPassScript.classify(0.0, band, AIR, hyst), STRADDLE, "the near plane cutting the surface is STRADDLE")
	assert_eq(UnderwaterPassScript.classify(1.0, band, AIR, hyst), UNDER, "well below the surface is UNDER")
	assert_eq(UnderwaterPassScript.classify(-0.09, band, AIR, hyst), AIR, "AIR needs to cross the band by the hysteresis to leave")
	assert_eq(UnderwaterPassScript.classify(-0.07, band, AIR, hyst), STRADDLE, "past the hysteresis AIR becomes STRADDLE")
	assert_eq(UnderwaterPassScript.classify(-0.11, band, STRADDLE, hyst), STRADDLE, "STRADDLE holds just outside the band")
	assert_eq(UnderwaterPassScript.classify(-0.13, band, STRADDLE, hyst), AIR, "STRADDLE returns to AIR past the hysteresis")
	assert_eq(UnderwaterPassScript.classify(0.11, band, STRADDLE, hyst), STRADDLE, "STRADDLE holds just below the band")
	assert_eq(UnderwaterPassScript.classify(0.13, band, STRADDLE, hyst), UNDER, "deep enough becomes UNDER")
	assert_eq(UnderwaterPassScript.classify(0.09, band, UNDER, hyst), UNDER, "UNDER holds just inside the band")
	assert_eq(UnderwaterPassScript.classify(0.07, band, UNDER, hyst), STRADDLE, "UNDER rises to STRADDLE past the hysteresis")
	# A camera bobbing on the UNDER threshold keeps one state instead of flickering.
	var state := UNDER
	var changes := 0
	for index in 40:
		var depth := band + (0.01 if index % 2 == 0 else -0.01)
		var next := UnderwaterPassScript.classify(depth, band, state, hyst)
		if next != state:
			changes += 1
		state = next
	assert_eq(changes, 0, "a +/-0.01 bob inside the hysteresis never flips the state")


func test_wave_crests_widen_the_straddle_band() -> void:
	var pass_node := _make_pass()
	pass_node.advance(FRAME, -0.02, {"surface_y": 0.0, "wave_margin": 0.03})
	assert_eq(pass_node.state, STRADDLE, "a crest can reach a lens 0.02 above the rest plane")
	pass_node.advance(FRAME, -0.2, {"surface_y": 0.0, "wave_margin": 0.03})
	assert_eq(pass_node.state, AIR, "well above the crests is AIR")
	pass_node.advance(FRAME, 0.5, {"surface_y": 0.0, "wave_margin": 0.03})
	assert_eq(pass_node.state, UNDER, "troughs are floored, so crests never delay UNDER")
	_drop(pass_node)


func test_straddle_band_is_two_near_half_heights() -> void:
	var camera := Camera3D.new()
	camera.near = 0.05
	camera.fov = 90.0
	assert_almost_eq(UnderwaterPassScript.straddle_band(camera), 0.1, 0.0001, "near 0.05 at 90 deg has half-height 0.05")
	camera.free()


func test_node_is_hidden_in_air_and_shown_under_water() -> void:
	var pass_node := _make_pass()
	assert_false(pass_node.is_pass_visible(), "a fresh pass starts hidden")
	pass_node.advance(FRAME, -1.0)
	assert_eq(pass_node.state, AIR, "a camera 1 unit above the surface is in AIR")
	assert_false(pass_node.is_pass_visible(), "AIR hides the quad so it costs nothing")
	pass_node.advance(FRAME, NAN)
	assert_false(pass_node.is_pass_visible(), "no water under the camera is AIR")
	pass_node.advance(FRAME, 0.0)
	assert_eq(pass_node.state, STRADDLE, "the lens on the surface straddles it")
	assert_true(pass_node.is_pass_visible(), "STRADDLE draws the waterline")
	assert_eq(int(pass_node.pass_material().get_shader_parameter(&"medium_state")), STRADDLE, "the shader draws the per-pixel waterline")
	pass_node.advance(FRAME, 1.0)
	assert_eq(pass_node.state, UNDER, "a camera 1 unit down is UNDER")
	assert_true(pass_node.is_pass_visible(), "UNDER draws the medium")
	assert_eq(int(pass_node.pass_material().get_shader_parameter(&"medium_state")), UNDER, "the shader treats every pixel as under water")
	assert_eq(pass_node.pass_material().render_priority, UnderwaterPassScript.RENDER_PRIORITY, "the pass draws after the water surface")
	_drop(pass_node)


func test_sfx_lowpass_is_enabled_only_under_water() -> void:
	assert_true(UnderwaterPassScript.lowpass_effect_index() >= 0, "the SFX bus carries the underwater low-pass")
	assert_false(UnderwaterPassScript.is_lowpass_enabled(), "the low-pass is off by default")
	var pass_node := _make_pass()
	pass_node.advance(FRAME, 0.0)
	pass_node.advance(0.5, 0.0)
	assert_false(UnderwaterPassScript.is_lowpass_enabled(), "STRADDLE keeps the world audible")
	pass_node.advance(FRAME, 1.0)
	assert_true(UnderwaterPassScript.is_lowpass_enabled(), "UNDER muffles the world SFX")
	pass_node.advance(UnderwaterPassScript.LOWPASS_FADE_SECONDS, 1.0)
	var bus := AudioServer.get_bus_index(UnderwaterPassScript.SFX_BUS)
	var effect := AudioServer.get_bus_effect(bus, UnderwaterPassScript.lowpass_effect_index()) as AudioEffectLowPassFilter
	assert_almost_eq(effect.cutoff_hz, UnderwaterPassScript.LOWPASS_CUTOFF_HZ, 1.0, "the fade settles on the 700 Hz cutoff")
	pass_node.advance(FRAME, -1.0)
	pass_node.advance(UnderwaterPassScript.LOWPASS_FADE_SECONDS, -1.0)
	assert_false(UnderwaterPassScript.is_lowpass_enabled(), "surfacing fades the low-pass out and disables it")
	pass_node.advance(FRAME, 1.0)
	assert_true(UnderwaterPassScript.is_lowpass_enabled(), "diving again re-enables it")
	_drop(pass_node)
	assert_false(UnderwaterPassScript.is_lowpass_enabled(), "freeing the pass never leaves the bus muffled")
	var music := AudioServer.get_bus_index(&"Music")
	assert_eq(AudioServer.get_bus_effect_count(music), 0, "music is unaffected")


func test_wet_lens_runs_after_surfacing() -> void:
	var pass_node := _make_pass()
	pass_node.advance(FRAME, -1.0)
	pass_node.advance(FRAME, 0.0)
	pass_node.advance(FRAME, -1.0)
	assert_eq(pass_node.wet_lens_remaining, 0.0, "touching the surface without diving leaves the lens dry")
	pass_node.advance(FRAME, 1.0)
	pass_node.advance(FRAME, 0.0)
	assert_eq(pass_node.wet_lens_remaining, 0.0, "no drops while still in the water")
	pass_node.advance(FRAME, -1.0)
	assert_almost_eq(pass_node.wet_lens_remaining, UnderwaterPassScript.WET_LENS_SECONDS, 0.0001, "surfacing starts the 2.5 s wet lens")
	assert_true(pass_node.is_pass_visible(), "the pass stays visible for the drops")
	assert_almost_eq(float(pass_node.pass_material().get_shader_parameter(&"wet_lens")), 1.0, 0.0001, "the shader starts at full wetness")
	pass_node.advance(1.0, -1.0)
	assert_almost_eq(pass_node.wet_lens_remaining, 1.5, 0.0001, "the timer counts down")
	assert_true(float(pass_node.pass_material().get_shader_parameter(&"lens_age")) > 0.9, "drops slide with the lens age")
	pass_node.advance(2.0, -1.0)
	assert_eq(pass_node.wet_lens_remaining, 0.0, "the drops are gone after 2.5 s")
	assert_false(pass_node.is_pass_visible(), "the quad hides again once the lens is dry")
	_drop(pass_node)


func test_top_down_camera_never_submerges_or_gets_a_wet_lens() -> void:
	var pass_node := _make_pass(Camera3D.PROJECTION_ORTHOGONAL)
	pass_node.advance(FRAME, 5.0)
	assert_eq(pass_node.state, AIR, "the orthographic overview stays in AIR")
	pass_node.advance(FRAME, -5.0)
	assert_eq(pass_node.wet_lens_remaining, 0.0, "top-down never shows drops")
	assert_false(pass_node.is_pass_visible(), "top-down never draws the pass")
	_drop(pass_node)


func test_pass_exists_outdoors_over_water_and_not_in_interiors() -> void:
	assert_true(UnderwaterPassScript.should_create(false, true), "outdoor water gets the pass")
	assert_false(UnderwaterPassScript.should_create(true, true), "interiors never get the pass")
	assert_false(UnderwaterPassScript.should_create(false, false), "dry maps never get the pass")
	var harbor: MapDefinition = HarborNorthDefinition.create()
	var grid := MapBuilder.build(harbor)
	var harbor_view := MapView3D.create(harbor, grid)
	var pass_node = harbor_view.underwater_pass()
	assert_true(pass_node != null, "the harbour builds the underwater pass")
	assert_true(pass_node.camera == harbor_view.view_camera(), "the pass follows the view camera")
	var water_cell := Vector2i(-1, -1)
	var dry_cell := Vector2i(-1, -1)
	for y in harbor.size_cells.y:
		for x in harbor.size_cells.x:
			var terrain := grid.get_terrain(Vector2i(x, y))
			if water_cell.x < 0 and MapTypes.WATER_TERRAINS.has(terrain):
				water_cell = Vector2i(x, y)
			elif dry_cell.x < 0 and not MapTypes.WATER_TERRAINS.has(terrain) and terrain != &"":
				dry_cell = Vector2i(x, y)
	assert_true(water_cell.x >= 0 and dry_cell.x >= 0, "the harbour has water and dry cells")
	var water_xz := Vector2(water_cell) + Vector2(0.5, 0.5)
	var probe: Dictionary = harbor_view._underwater_probe(water_xz)
	assert_false(probe.is_empty(), "a water cell reports its surface")
	var rest_y := -MeshConfig.WATER_RECESS + MeshConfig.WATER_SURFACE_LIFT
	assert_almost_eq(float(probe["surface_y"]), rest_y, 0.01, "the surface is the recessed water plane plus tide")
	assert_true(probe["material"] is ShaderMaterial, "the probe hands over the water material to mirror")
	assert_true(float(probe["wave_margin"]) > 0.0, "the probe reports the crest height budget")
	assert_true(harbor_view._underwater_probe(Vector2(dry_cell) + Vector2(0.5, 0.5)).is_empty(), "dry land has no surface")
	harbor_view.free()
	var smithy: MapDefinition = KalevSmithyDefinition.create()
	var smithy_view := MapView3D.create(smithy, MapBuilder.build(smithy))
	assert_true(smithy_view.underwater_pass() == null, "the roofed smithy has no underwater pass")
	smithy_view.free()


func test_submerge_and_emerge_cues_fire_once_per_crossing() -> void:
	var pass_node := _make_pass()
	pass_node.advance(FRAME, -1.0)
	pass_node.advance(FRAME, 0.0)
	assert_eq(pass_node.played_cues.size(), 0, "STRADDLE without UNDER is not a crossing")
	pass_node.advance(FRAME, 1.0)
	assert_eq(pass_node.played_cues, [UnderwaterPassScript.CUE_SUBMERGE], "AIR->UNDER plays submerge once")
	# A camera bobbing on the UNDER threshold must not fire a second splash.
	var band := UnderwaterPassScript.straddle_band(pass_node.camera)
	var hyst := UnderwaterPassScript.hysteresis_for_band(band)
	pass_node.advance(FRAME, band + hyst * 0.25)
	pass_node.advance(FRAME, band - hyst * 0.25)
	assert_eq(pass_node.played_cues.size(), 1, "hysteresis bobbing must not retrigger submerge")
	assert_eq(pass_node.state, UNDER, "the bob stays UNDER")
	pass_node.advance(FRAME, -1.0)
	assert_eq(pass_node.played_cues.size(), 1, "emerge waits until the SFX low-pass has opened")
	assert_true(UnderwaterPassScript.is_lowpass_enabled(), "the fade is still closing when AIR starts")
	pass_node.advance(UnderwaterPassScript.LOWPASS_FADE_SECONDS, -1.0)
	assert_eq(
		pass_node.played_cues,
		[UnderwaterPassScript.CUE_SUBMERGE, UnderwaterPassScript.CUE_EMERGE],
		"UNDER->AIR plays emerge once after the low-pass opens"
	)
	assert_false(UnderwaterPassScript.is_lowpass_enabled(), "emerge is unfiltered")
	var emerge_player := pass_node.get_node("EmergeSfx") as AudioStreamPlayer
	assert_eq(emerge_player.bus, "SFX", "emerge still uses the SFX bus")
	pass_node.advance(FRAME, 1.0)
	assert_eq(pass_node.played_cues.size(), 3, "a second dive plays submerge again")
	assert_eq(pass_node.played_cues[2], UnderwaterPassScript.CUE_SUBMERGE, "the third cue is the second dive")
	_drop(pass_node)


func test_ortho_and_cancelled_emerge_never_play_water_cues() -> void:
	var ortho := _make_pass(Camera3D.PROJECTION_ORTHOGONAL)
	ortho.advance(FRAME, 5.0)
	ortho.advance(UnderwaterPassScript.LOWPASS_FADE_SECONDS, 5.0)
	assert_eq(ortho.played_cues.size(), 0, "the orthographic overview never plays water cues")
	_drop(ortho)
	var pass_node := _make_pass()
	pass_node.advance(FRAME, 1.0)
	pass_node.advance(UnderwaterPassScript.LOWPASS_FADE_SECONDS, 1.0)
	assert_true(UnderwaterPassScript.is_lowpass_enabled(), "a held dive muffles the SFX bus")
	pass_node.advance(FRAME, -1.0)
	assert_eq(pass_node.played_cues, [UnderwaterPassScript.CUE_SUBMERGE], "emerge is still pending during the fade")
	assert_true(pass_node.lowpass_mix > UnderwaterPassScript.EMERGE_UNFILTERED_MIX, "one AIR frame does not finish the fade")
	pass_node.advance(FRAME, 1.0)
	assert_eq(pass_node.played_cues.size(), 2, "diving again cancels the pending emerge")
	assert_eq(pass_node.played_cues[1], UnderwaterPassScript.CUE_SUBMERGE, "the second cue is another submerge")
	pass_node.advance(UnderwaterPassScript.LOWPASS_FADE_SECONDS, 1.0)
	assert_eq(pass_node.played_cues.size(), 2, "staying UNDER after a cancelled emerge plays nothing")
	_drop(pass_node)


func test_shaders_share_the_fft_include_and_draw_the_medium() -> void:
	var code := (load(PASS_SHADER_PATH) as Shader).code
	assert_true(code.contains('#include "res://scripts/map/view3d/ocean_fft_common.gdshaderinc"'), "the pass samples the same FFT waterline as the surface")
	assert_true(code.contains("depth_test_disabled"), "the screen quad ignores scene depth")
	assert_true(code.contains("scene * transmittance + inscatter * (vec3(1.0) - transmittance)"), "Beer-Lambert medium with in-scatter")
	assert_true(code.contains("MENISCUS_BAND_PX = 9.0"), "Tidewater 9 px meniscus band")
	assert_true(code.contains("_uw_below_color("), "surface pixels seen from below share the water back-face shading")
	assert_true(code.contains("CURRENT_RENDERER == RENDERER_COMPATIBILITY"), "depth reconstruction covers Compatibility and Metal")
	var include := FileAccess.get_file_as_string(FFT_INCLUDE_PATH)
	assert_true(include.contains("const float WATER_IOR = 1.333;"), "one IOR for WS-01 and WS-13")
	assert_true(include.contains("const vec3 WATER_SIGMA_T_PER_M"), "one per-channel extinction")
	assert_true(include.contains("float _uw_hg(float cos_theta, float g)"), "Henyey-Greenstein sun lobe")


func test_ws13f_underwater_pass_binds_ws07_caustic_tiles() -> void:
	var code := (load(PASS_SHADER_PATH) as Shader).code
	assert_true(
		code.contains('#include "res://scripts/map/view3d/caustics_common.gdshaderinc"'),
		"the pass samples the same WS-07 tiles as the water shader",
	)
	assert_false(code.contains("_uw_caustic("), "the procedural WS-07 stand-in is gone")
	assert_false(code.contains("sin(a.x + sin(a.y"), "the sine-lattice body is gone")
	assert_true(code.contains("caustics_fine_tex"), "fine tile uniform is declared")
	assert_true(code.contains("_caustic_at(x, false, false)"), "shafts stay on one tile")
	var tiles := FileAccess.get_file_as_string(CAUSTICS_INCLUDE_PATH)
	assert_true(tiles.contains("vec3 _caustic_tile("), "tile helper lives in the shared include")
	assert_true(tiles.contains("vec2 _caustic_stretch("), "stretch helper lives in the shared include")
	var pass_node := _make_pass()
	var material := pass_node.pass_material()
	assert_true(material.get_shader_parameter(&"caustics_fine_tex") is Texture2D, "fine tile is bound")
	assert_true(material.get_shader_parameter(&"caustics_broad_tex") is Texture2D, "broad tile is bound")
	assert_true(bool(material.get_shader_parameter(&"caustic_full_quality")), "recommended uses both tiles")
	_drop(pass_node)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	var minimum: UnderwaterPass = UnderwaterPassScript.new()
	minimum.configure(camera, Callable(), &"minimum")
	minimum.add_child(camera)
	_root().add_child(minimum)
	assert_false(
		bool(minimum.pass_material().get_shader_parameter(&"caustic_full_quality")),
		"minimum drops to one tile",
	)
	_drop(minimum)
