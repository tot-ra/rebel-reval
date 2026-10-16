extends "res://tests/godot/test_case.gd"

## ADR 0061 (R-2183..R-2185): hero wetness and body heat, cold damage, HUD stages, motion channels.

const HeroExposure := preload("res://scripts/player/hero_exposure.gd")
const Hazard := preload("res://scripts/world/hero_exposure_hazard.gd")
const StatusHud := preload("res://scripts/ui/exposure_status_hud.gd")
const Persistence := preload("res://scripts/state/game_state_persistence.gd")
const Presenter := preload("res://scripts/motion/motion_style_presenter.gd")
const PLAYER_SCENE := preload("res://player.tscn")


func _env(overrides: Dictionary = {}) -> Dictionary:
	var env := {
		"air_temp_c": 15.0,
		"rain": 0.0,
		"snow_share": 0.0,
		"wind": 0.0,
		"interior": false,
		"rain_shelter": false,
		"fire_m": INF,
		"immersion": 0.0,
		"puddle": 0.0,
		"stamina": 0.0,
	}
	env.merge(overrides, true)
	return env


## Steps a fresh state for `seconds` in 0.5 s ticks; returns the state and summed results.
func _run(state: PlayerState, seconds: float, env: Dictionary) -> Dictionary:
	var damage := 0.0
	var stamina := 0.0
	var t := 0.0
	while t < seconds:
		var r := HeroExposure.step(state, 0.5, env)
		damage += float(r["damage_share"])
		stamina += float(r["stamina_cost"])
		t += 0.5
	return {"damage_share": damage, "stamina_cost": stamina}


func test_rain_soaks_outdoors_but_not_under_a_roof() -> void:
	var out := PlayerState.new()
	_run(out, 60.0, _env({"rain": 1.0}))
	assert_true(out.wetness > 0.25, "a minute of heavy rain wets the hero: %f" % out.wetness)
	var roofed := PlayerState.new()
	_run(roofed, 60.0, _env({"rain": 1.0, "rain_shelter": true}))
	assert_eq(roofed.wetness, 0.0, "a roof keeps the rain off")


func test_snow_soaks_slower_than_rain() -> void:
	var rain := PlayerState.new()
	_run(rain, 60.0, _env({"rain": 1.0, "air_temp_c": 2.0}))
	var snow := PlayerState.new()
	_run(snow, 60.0, _env({"rain": 1.0, "snow_share": 1.0, "air_temp_c": 2.0}))
	assert_true(snow.wetness < rain.wetness * 0.5, "snow sticks less than rain")


func test_swimming_soaks_at_once_and_wading_partly() -> void:
	var swim := PlayerState.new()
	_run(swim, 2.0, _env({"immersion": 1.0}))
	assert_almost_eq(swim.wetness, 1.0, 0.001)
	var wade := PlayerState.new()
	_run(wade, 5.0, _env({"immersion": Hazard.immersion(PlayerSwimState.Medium.WADE, 0.6)}))
	assert_true(wade.wetness > 0.3 and wade.wetness < 0.7, "waist-deep: %f" % wade.wetness)
	assert_eq(Hazard.immersion(PlayerSwimState.Medium.WALK, 0.0), 0.0)


func test_puddles_only_wet_the_feet() -> void:
	var state := PlayerState.new()
	_run(state, 600.0, _env({"puddle": 1.0}))
	assert_almost_eq(state.wetness, HeroExposure.PUDDLE_CAP, 0.001)


func test_warm_dry_air_costs_nothing() -> void:
	var state := PlayerState.new()
	var r := _run(state, 600.0, _env({"air_temp_c": 18.0, "stamina": 100.0}))
	assert_eq(state.body_heat, 1.0)
	assert_eq(float(r["stamina_cost"]), 0.0)


func test_cold_drains_heat_and_wet_cold_drains_faster() -> void:
	var dry := PlayerState.new()
	_run(dry, 120.0, _env({"air_temp_c": -5.0}))
	assert_true(dry.body_heat < 1.0 and dry.body_heat > 0.7, "dry -5 C: %f" % dry.body_heat)
	var wet := PlayerState.new()
	wet.wetness = 1.0
	_run(wet, 120.0, _env({"air_temp_c": -5.0}))
	assert_true(wet.body_heat < dry.body_heat - 0.1, "wet loses heat faster")
	var windy := PlayerState.new()
	_run(windy, 120.0, _env({"air_temp_c": -5.0, "wind": 1.0}))
	assert_true(windy.body_heat < dry.body_heat, "wind adds to the loss")


func test_soaked_in_winter_wind_freezes_within_minutes() -> void:
	var state := PlayerState.new()
	state.wetness = 1.0
	var env := _env({"air_temp_c": -10.0, "wind": 1.0})
	var seconds := 0.0
	while state.body_heat > 0.0 and seconds < 900.0:
		HeroExposure.step(state, 0.5, env)
		seconds += 0.5
	assert_true(seconds > 120.0 and seconds < 300.0, "soaked at -10 C froze in %f s" % seconds)


func test_shivering_burns_stamina_and_holds_heat_back() -> void:
	var with_stamina := PlayerState.new()
	with_stamina.body_heat = 0.8
	var r := HeroExposure.step(with_stamina, 1.0, _env({"air_temp_c": -10.0, "stamina": 50.0}))
	assert_true(bool(r["shivering"]))
	assert_almost_eq(float(r["stamina_cost"]), HeroExposure.SHIVER_STAMINA_PER_SEC, 0.0001)
	var spent := PlayerState.new()
	spent.body_heat = 0.8
	HeroExposure.step(spent, 1.0, _env({"air_temp_c": -10.0, "stamina": 0.0}))
	assert_true(with_stamina.body_heat > spent.body_heat, "stamina slows the chill")


func test_fire_warms_and_dries_fast() -> void:
	var state := PlayerState.new()
	state.body_heat = 0.1
	state.wetness = 1.0
	_run(state, 60.0, _env({"air_temp_c": -10.0, "fire_m": 1.5}))
	assert_eq(state.body_heat, 1.0, "a minute at the fire warms through")
	assert_true(state.wetness < 0.45, "and dries: %f" % state.wetness)
	assert_eq(HeroExposure.fire_factor(6.0), 0.0)
	assert_eq(HeroExposure.fire_factor(1.0), 1.0)


func test_interior_is_warm_in_winter() -> void:
	var state := PlayerState.new()
	state.body_heat = 0.3
	_run(state, 120.0, _env({"air_temp_c": -15.0, "interior": true}))
	assert_true(state.body_heat > 0.6, "indoors warms slowly: %f" % state.body_heat)


func test_soaked_hero_recovers_in_an_unheated_room() -> void:
	var state := PlayerState.new()
	state.body_heat = 0.0
	state.wetness = 1.0
	var r := _run(state, 60.0, _env({"air_temp_c": -15.0, "interior": true}))
	assert_true(state.body_heat > 0.05, "indoors he warms even soaked: %f" % state.body_heat)
	assert_true(float(r["damage_share"]) <= HeroExposure.COLD_DAMAGE_SHARE_PER_SEC * 0.5)


func test_porch_roof_stops_rain_but_not_wind() -> void:
	var calm := PlayerState.new()
	_run(calm, 120.0, _env({"air_temp_c": -5.0, "rain_shelter": true}))
	var windy := PlayerState.new()
	_run(windy, 120.0, _env({"air_temp_c": -5.0, "rain_shelter": true, "wind": 1.0, "rain": 1.0}))
	assert_eq(windy.wetness, 0.0, "the roof keeps the rain off")
	assert_true(windy.body_heat < calm.body_heat, "but the wind still chills under it")


func test_cold_damage_only_at_zero_heat() -> void:
	var cold := _env({"air_temp_c": -10.0})
	var state := PlayerState.new()
	state.body_heat = 0.05
	var r := HeroExposure.step(state, 0.5, cold)
	assert_eq(float(r["damage_share"]), 0.0, "still some heat: no damage")
	state.body_heat = 0.0
	r = HeroExposure.step(state, 1.0, cold)
	assert_almost_eq(float(r["damage_share"]), HeroExposure.COLD_DAMAGE_SHARE_PER_SEC, 0.0001)
	r = HeroExposure.step(state, 1.0, _env({"air_temp_c": -10.0, "fire_m": 1.0}))
	assert_eq(float(r["damage_share"]), 0.0, "a fire stops the damage at once")


func test_speed_and_stages() -> void:
	assert_eq(HeroExposure.speed_multiplier(0.5), 1.0)
	assert_almost_eq(HeroExposure.speed_multiplier(0.0), HeroExposure.SLOW_FLOOR, 0.0001)
	assert_eq(HeroExposure.wet_stage(0.0), &"")
	assert_eq(HeroExposure.wet_stage(0.3), &"damp")
	assert_eq(HeroExposure.wet_stage(0.9), &"soaked")
	assert_eq(HeroExposure.cold_stage(1.0), &"")
	assert_eq(HeroExposure.cold_stage(0.5), &"chilled")
	assert_eq(HeroExposure.cold_stage(0.2), &"freezing")
	assert_eq(HeroExposure.cold_stage(0.0), &"dying")


func test_save_roundtrip_and_old_save_defaults() -> void:
	var state := GameState.new()
	state.player.wetness = 0.7
	state.player.body_heat = 0.25
	var payload := Persistence.save_payload(state)
	var loaded := GameState.new()
	var errors := Persistence.load_payload(loaded, payload)
	assert_eq(errors.size(), 0, str(errors))
	assert_almost_eq(loaded.player.wetness, 0.7, 0.0001)
	assert_almost_eq(loaded.player.body_heat, 0.25, 0.0001)
	var old: Dictionary = payload.duplicate(true)
	(old["player"] as Dictionary).erase("wetness")
	(old["player"] as Dictionary).erase("body_heat")
	var legacy := GameState.new()
	legacy.player.wetness = 0.5
	legacy.player.body_heat = 0.1
	Persistence.load_payload(legacy, old)
	assert_eq(legacy.player.wetness, 0.0, "old saves load dry")
	assert_eq(legacy.player.body_heat, 1.0, "and warm")


func test_cold_death_reports_cold_damage_type() -> void:
	var player: Player = PLAYER_SCENE.instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(player)
	player.health = 1.0
	player.take_cold(5.0)
	assert_true(player.health <= 0.0)
	assert_eq(SessionState.consume_fatal_hit_damage_type(), Player.DAMAGE_TYPE_COLD)
	var death: Script = load("res://scenes/death/death_screen.gd")
	assert_eq(death.illustration_key_for_damage_type(Player.DAMAGE_TYPE_COLD), &"neutral")
	player.free()


func test_hud_icons_messages_and_vignette() -> void:
	var hud: CanvasLayer = StatusHud.new()
	hud.follow_settings = false
	(Engine.get_main_loop() as SceneTree).root.add_child(hud)
	hud.show_exposure(0.0, 1.0)
	assert_eq(hud.message, "")
	assert_false(hud.get_node("ExposureRoot/WetIcon").visible)
	hud.show_exposure(0.8, 0.5)
	assert_true(hud.get_node("ExposureRoot/WetIcon").visible)
	assert_true(hud.get_node("ExposureRoot/ColdIcon").visible)
	assert_eq(hud.message, StatusHud.MESSAGES[&"chilled"], "the cold line is the latest")
	hud.message = ""
	hud.show_exposure(0.8, 0.5)
	assert_eq(hud.message, "", "a stage is announced once")
	hud.show_exposure(0.8, 0.2)
	assert_eq(hud.message, StatusHud.MESSAGES[&"freezing"])
	hud.show_exposure(0.8, 0.2, 1.0)
	assert_eq(hud.message, StatusHud.WARMING_MESSAGE)
	assert_eq(StatusHud.vignette_alpha(0.8), 0.0)
	assert_true(StatusHud.vignette_alpha(0.1) > 0.0)
	assert_eq(StatusHud.vignette_alpha(0.0), StatusHud.VIGNETTE_DYING)
	hud.free()


func test_hero_motion_channels_follow_exposure() -> void:
	var player: Player = PLAYER_SCENE.instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(player)
	SessionState.state.player.wetness = 0.62
	SessionState.state.player.body_heat = 0.3
	var conditions := Presenter.vitals_conditions(player)
	assert_eq(conditions.size(), 1)
	var ch: Dictionary = conditions[0]
	assert_almost_eq(float(ch["wet"]), 0.6, 0.0001)
	assert_almost_eq(float(ch["core_cold"]), 0.7, 0.0001)
	SessionState.state.player.wetness = 0.0
	SessionState.state.player.body_heat = 1.0
	player.free()
