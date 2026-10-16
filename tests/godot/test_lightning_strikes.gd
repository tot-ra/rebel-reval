extends "res://tests/godot/test_case.gd"

## ADR 0057 (R-2152..R-2154): lightning strike targeting, the sky's strike event,
## and how often a storm overhead strikes close to Kalev.

const Resolver := preload("res://scripts/world/lightning_strike_resolver.gd")
const SkyWeather := preload("res://scripts/map/view3d/sky_weather_3d.gd")

## The seamless city's scale (CityPlan.metres_per_unit).
const MPU := 0.87


func _tree(at: Vector2, height_m: float, id: String = "tree") -> Dictionary:
	return {"kind": Resolver.KIND_TREE, "id": id, "position": at, "base_y": 0.0, "height": height_m}


func test_far_strokes_stay_presentation_only() -> void:
	var far := Vector2(700.0 / MPU, 0.0)
	assert_true(Resolver.resolve(far, Vector2.ZERO, 0.0, false, [], MPU, 0.5).is_empty())
	var near := Vector2(500.0 / MPU, 0.0)
	assert_false(Resolver.resolve(near, Vector2.ZERO, 0.0, false, [], MPU, 0.5).is_empty())


func test_sheltered_hero_is_never_struck() -> void:
	for i in 200:
		var strike := Resolver.resolve(Vector2.ZERO, Vector2.ZERO, 0.0, true, [], MPU, i / 200.0)
		assert_false(bool(strike["hits_hero"]), "indoors or under a roof Kalev is never struck")


func test_exposed_hero_on_the_stroke_can_be_struck() -> void:
	var hits := 0
	for i in 200:
		var strike := Resolver.resolve(Vector2.ZERO, Vector2.ZERO, 0.0, false, [], MPU, i / 200.0)
		hits += 1 if bool(strike["hits_hero"]) else 0
	assert_true(hits > 0 and hits < 200, "alone on a field he competes with the bare ground")


func test_tall_targets_win_over_short_ones() -> void:
	var candidates := [
		_tree(Vector2(5.0, 0.0), 12.0, "oak"),
		{"kind": Resolver.KIND_PERSON, "id": "p", "position": Vector2(-5.0, 0.0), "base_y": 0.0, "height": 1.7},
	]
	var tree_hits := 0
	for i in 1000:
		var strike := Resolver.resolve(Vector2.ZERO, Vector2(400.0, 0.0), 0.0, false, candidates, MPU, i / 1000.0)
		tree_hits += 1 if strike["id"] == "oak" else 0
	assert_true(tree_hits > 900, "a 12 m oak catches the stroke over a person beside it (%d)" % tree_hits)


func test_struck_target_top_is_the_reported_position() -> void:
	var strike := Resolver.resolve(
		Vector2.ZERO, Vector2(50.0, 0.0), 0.0, true, [_tree(Vector2(3.0, 0.0), 12.0)], MPU, 0.5
	)
	assert_eq(strike["kind"], Resolver.KIND_TREE)
	assert_almost_eq((strike["position"] as Vector3).y, 12.0 / MPU, 0.001)
	assert_eq(strike["ground"], Vector2(3.0, 0.0))


func test_out_of_reach_objects_do_not_attract() -> void:
	# A 1.7 m person reaches about 11 m; 30 m away the stroke stays on the ground.
	var person := {"kind": Resolver.KIND_PERSON, "id": "p", "position": Vector2(30.0 / MPU, 0.0), "base_y": 0.0, "height": 1.7}
	var strike := Resolver.resolve(Vector2.ZERO, Vector2(400.0, 0.0), 0.0, true, [person], MPU, 0.99)
	assert_eq(strike["kind"], Resolver.KIND_GROUND)


func test_near_hurt_fades_with_distance_and_shelter() -> void:
	assert_almost_eq(Resolver.near_hurt_fraction(0.0, false), 0.45, 0.001)
	assert_true(Resolver.near_hurt_fraction(9.0, false) < Resolver.near_hurt_fraction(2.0, false))
	assert_eq(Resolver.near_hurt_fraction(10.5, false), 0.0)
	assert_eq(Resolver.near_hurt_fraction(2.0, true), 0.0)


## A storm overhead drops its ground strokes anywhere under a ~1 km rain core.
## The approved bands (ADR 0057): a close stroke (< 150 m) in a few percent of
## them, which is 1-3 per storm at the sky's ~4 ground strokes a minute over a
## ~10 minute pass; a direct hit on an exposed Kalev well under one per storm.
func test_strike_frequency_bands_for_a_storm_overhead() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2151
	var strokes := 4000
	var close := 0
	var direct := 0
	var lone_oak := _tree(Vector2(40.0, 25.0), 12.0, "oak")
	for i in strokes:
		var angle := rng.randf() * TAU
		var reach := sqrt(rng.randf()) * 900.0 / MPU
		var ground := Vector2(cos(angle), sin(angle)) * reach
		var strike := Resolver.resolve(ground, Vector2.ZERO, 0.0, false, [lone_oak], MPU, rng.randf())
		if strike.is_empty():
			continue
		close += 1 if float(strike["distance_to_hero_m"]) < 150.0 else 0
		direct += 1 if bool(strike["hits_hero"]) else 0
	var close_share := float(close) / strokes
	var direct_share := float(direct) / strokes
	assert_true(close_share > 0.01 and close_share < 0.08, "close share %.4f" % close_share)
	assert_true(direct_share < 0.002, "direct share %.5f" % direct_share)


func test_strike_roll_is_deterministic_per_strike_and_person() -> void:
	var strike := {"position": Vector3(12.3, 4.0, -7.7)}
	assert_eq(Resolver.strike_roll(strike, "a"), Resolver.strike_roll(strike, "a"))
	assert_ne(Resolver.strike_roll(strike, "a"), Resolver.strike_roll(strike, "b"))
	var roll := Resolver.strike_roll(strike, "a")
	assert_true(roll >= 0.0 and roll < 1.0)


## The sky asks the world on ground strokes, moves the bolt onto the target and
## announces it; without a provider nothing changes.
func test_sky_announces_ground_strokes_to_the_provider() -> void:
	var sky = SkyWeather.new()
	sky.auto_weather = false
	var asked: Array = []
	var struck: Array = []
	sky.strike_target_provider = func(ground: Vector2) -> Dictionary:
		asked.append(ground)
		# Stand Kalev 20 m from every stroke with an oak right on it.
		return {
			"hero": ground + Vector2(20.0 / MPU, 0.0),
			"hero_base_y": 0.0,
			"hero_sheltered": false,
			"candidates": [_tree(ground, 12.0, "oak")],
			"metres_per_unit": MPU,
		}
	sky.lightning_struck.connect(func(strike: Dictionary) -> void: struck.append(strike))
	sky.set_weather(SkyWeather.WEATHER_STORM)
	sky.advance(SkyWeather.TRANSITION_SECONDS)
	for step in 2_000:
		sky.advance(0.05)
	assert_true(asked.size() > 0, "a storm must throw ground strokes")
	assert_eq(struck.size(), asked.size(), "every resolved stroke near Kalev is announced")
	var oak_hits := 0
	for strike: Dictionary in struck:
		oak_hits += 1 if strike["id"] == "oak" else 0
	assert_true(oak_hits > struck.size() / 2, "the oak on the stroke takes most of them")
	sky.free()


func test_lightning_rng_stream_does_not_depend_on_the_world() -> void:
	# Same storm with and without a provider: the strikes come at the same times.
	var flashes: Array = []
	for with_provider in [false, true]:
		var sky = SkyWeather.new()
		sky.auto_weather = false
		if with_provider:
			sky.strike_target_provider = func(ground: Vector2) -> Dictionary:
				return {"hero": ground, "candidates": [], "metres_per_unit": MPU}
		sky.set_weather(SkyWeather.WEATHER_STORM)
		sky.advance(SkyWeather.TRANSITION_SECONDS)
		var trace := PackedFloat32Array()
		for step in 600:
			sky.advance(0.05)
			trace.append(sky.lightning_flash())
		flashes.append(trace)
		sky.free()
	assert_eq(flashes[0], flashes[1])
