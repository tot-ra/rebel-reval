extends "res://tests/godot/test_case.gd"

const InsectAmbientAudio := preload("res://scripts/map/view3d/map_view_insect_ambient_audio.gd")
const InsectContext := preload("res://scripts/map/view3d/map_view_insect_context.gd")
const InsectSpecies := preload("res://scripts/map/view3d/map_view_insect_species.gd")
const KalevSmithy := preload("res://scripts/map/definitions/lower_town/kalev_smithy_definition.gd")
const Foreland := preload("res://scripts/map/definitions/outdoor/viru_gate_foreland_definition.gd")

const NOON := 0.5
const NIGHT := 0.92


func test_meadow_daytime_schedules_distinct_species() -> void:
	var species := InsectAmbientAudio.distinct_species_for_context(
		&"viru_gate_foreland",
		InsectContext.context_for_map(&"viru_gate_foreland"),
		NOON,
		48
	)
	assert_true(species.size() >= 3, "Meadow midday should surface at least three distinct stridulating species")


func test_garden_daytime_schedules_species() -> void:
	var species := InsectAmbientAudio.distinct_species_for_context(
		&"archbishops_garden",
		InsectContext.context_for_map(&"archbishops_garden"),
		NOON,
		48
	)
	assert_true(species.size() >= 1, "Garden midday should surface at least one stridulating species")


func test_stone_city_maps_have_no_insect_context() -> void:
	# Insects must stay silent on paved town maps: no context => no candidates.
	assert_eq(InsectContext.context_for_map(&"reval_harbor_north"), &"")
	assert_eq(InsectContext.context_for_map(&"lower_town_slice"), &"")
	var species := InsectAmbientAudio.distinct_species_for_context(
		&"lower_town_slice",
		InsectContext.context_for_map(&"lower_town_slice"),
		NOON,
		48
	)
	assert_eq(species.size(), 0, "Stone city core should schedule no insect voices")


func test_night_meadow_excludes_daytime_grasshoppers() -> void:
	var species := InsectAmbientAudio.distinct_species_for_context(
		&"viru_gate_foreland",
		InsectContext.context_for_map(&"viru_gate_foreland"),
		NIGHT,
		64
	)
	assert_true(species.size() >= 1, "Summer night meadow should still surface bush-crickets")
	for entry in species:
		assert_false(
			InsectSpecies.group_for(entry) == InsectSpecies.GROUP_GRASSHOPPER,
			"Warm-day grasshoppers must not stridulate at night: %s" % entry
		)


func test_species_selection_is_deterministic_for_seed_and_tick() -> void:
	var first := InsectAmbientAudio.pick_species(&"viru_gate_foreland", InsectSpecies.CONTEXT_MEADOW, NOON, 5)
	var second := InsectAmbientAudio.pick_species(&"viru_gate_foreland", InsectSpecies.CONTEXT_MEADOW, NOON, 5)
	assert_false(first.is_empty())
	assert_eq(first, second)


func test_concurrent_voice_cap_is_enforced() -> void:
	var audio := InsectAmbientAudio.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(audio)
	audio.configure(&"viru_gate_foreland", InsectSpecies.CONTEXT_MEADOW)
	for _attempt in 8:
		audio.sync(InsectSpecies.CONTEXT_MEADOW, NOON, Vector3.ZERO, 10.0)
	assert_true(audio.active_voice_count() <= InsectAmbientAudio.MAX_CONCURRENT_VOICES)
	audio.queue_free()


func test_disabling_insect_audio_leaves_game_state_unchanged() -> void:
	var state := GameState.new()
	var before := state.save_payload()
	var audio := InsectAmbientAudio.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(audio)
	audio.configure(&"viru_gate_foreland", InsectSpecies.CONTEXT_MEADOW)
	audio.set_audio_enabled(false)
	audio.sync(InsectSpecies.CONTEXT_MEADOW, NOON, Vector3(4.0, 1.0, 6.0), 1.0, false)
	assert_eq(audio.active_voice_count(), 0)
	assert_eq(state.save_payload(), before)
	audio.queue_free()


func test_interior_maps_suppress_insect_audio_and_meadow_maps_map_context() -> void:
	var smithy: MapDefinition = KalevSmithy.create()
	assert_true(smithy.suppresses_exterior_surroundings())

	var foreland: MapDefinition = Foreland.create()
	assert_false(foreland.suppresses_exterior_surroundings())
	assert_eq(InsectContext.context_for_map(foreland.map_id), InsectSpecies.CONTEXT_MEADOW)
