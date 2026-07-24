extends "res://tests/godot/test_case.gd"

const BirdAmbientAudio := preload("res://scripts/map/view3d/map_view_bird_ambient_audio.gd")
const BirdContext := preload("res://scripts/map/view3d/map_view_bird_context.gd")
const BirdSpecies := preload("res://scripts/map/view3d/map_view_bird_species.gd")
const LowerTownSlice := preload("res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd")
const KalevSmithy := preload("res://scripts/map/definitions/lower_town/kalev_smithy_definition.gd")
const HarborNorth := preload("res://scripts/map/definitions/outdoor/reval_harbor_north_definition.gd")
const Foreland := preload("res://scripts/map/definitions/outdoor/viru_gate_foreland_definition.gd")


func test_foreland_context_schedules_distinct_daytime_song_cues() -> void:
	var cues := BirdAmbientAudio.distinct_cues_for_context(
		&"viru_gate_foreland",
		BirdContext.context_for_map(&"viru_gate_foreland"),
		0.35,
		48
	)
	assert_true(cues.size() >= 3, "Viru Gate foreland day cycle should surface at least three song cues")


func test_lower_town_context_schedules_distinct_daytime_song_cues() -> void:
	var cues := BirdAmbientAudio.distinct_cues_for_context(
		&"lower_town_slice",
		BirdContext.context_for_map(&"lower_town_slice"),
		0.35,
		48
	)
	assert_true(cues.size() >= 3, "Lower Town day cycle should surface at least three song cues")


func test_harbor_context_schedules_distinct_daytime_song_cues() -> void:
	var cues := BirdAmbientAudio.distinct_cues_for_context(
		&"reval_harbor_north",
		BirdContext.context_for_map(&"reval_harbor_north"),
		0.35,
		48
	)
	assert_true(cues.size() >= 3, "Harbour day cycle should surface at least three song cues")


func test_species_selection_is_deterministic_for_seed_and_tick() -> void:
	var first := BirdAmbientAudio.pick_species(&"lower_town_slice", BirdSpecies.CONTEXT_LOWER_TOWN, 0.35, 7)
	var second := BirdAmbientAudio.pick_species(&"lower_town_slice", BirdSpecies.CONTEXT_LOWER_TOWN, 0.35, 7)
	assert_false(first.is_empty())
	assert_eq(first, second)


func test_concurrent_voice_cap_is_enforced() -> void:
	var audio := BirdAmbientAudio.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(audio)
	audio.configure(&"lower_town_slice", BirdSpecies.CONTEXT_LOWER_TOWN)
	for _attempt in 8:
		audio.sync(BirdSpecies.CONTEXT_LOWER_TOWN, 0.35, Vector3.ZERO, 10.0)
	assert_true(audio.active_voice_count() <= 3)
	audio.queue_free()


func test_disabling_bird_audio_leaves_game_state_unchanged() -> void:
	var state := GameState.new()
	var before := state.save_payload()
	var audio := BirdAmbientAudio.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(audio)
	audio.configure(&"lower_town_slice", BirdSpecies.CONTEXT_LOWER_TOWN)
	audio.set_audio_enabled(false)
	audio.sync(BirdSpecies.CONTEXT_LOWER_TOWN, 0.35, Vector3(4.0, 2.0, 6.0), 1.0, false)
	assert_eq(audio.active_voice_count(), 0)
	assert_eq(state.save_payload(), before)
	audio.queue_free()


func test_interior_maps_suppress_bird_audio_via_runtime() -> void:
	var smithy: MapDefinition = KalevSmithy.create()
	assert_true(smithy.suppresses_exterior_surroundings())

	var lower_town: MapDefinition = LowerTownSlice.create()
	assert_false(lower_town.suppresses_exterior_surroundings())
	assert_eq(BirdContext.context_for_map(lower_town.map_id), BirdSpecies.CONTEXT_LOWER_TOWN)

	var harbor: MapDefinition = HarborNorth.create()
	assert_eq(BirdContext.context_for_map(harbor.map_id), BirdSpecies.CONTEXT_HARBOR)

	var foreland: MapDefinition = Foreland.create()
	assert_eq(BirdContext.context_for_map(foreland.map_id), BirdSpecies.CONTEXT_FORELAND)
