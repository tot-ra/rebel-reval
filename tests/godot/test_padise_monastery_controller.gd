extends "res://tests/godot/test_case.gd"

const Controller := preload("res://scripts/world/padise_monastery_controller.gd")
const MusicDirectorScript := preload("res://scripts/global/music_director.gd")
const MAP_PATH := "res://content/maps/world_padise.rrmap"


func test_padise_manifest_distinguishes_brother_communities_before_attack() -> void:
	var manifest := Controller.phase_manifest(Controller.PHASE_BEFORE_ATTACK)
	var monks: Array = manifest["monks"]
	assert_eq(monks.size(), 2, "before-attack Padise needs both monastic communities")
	assert_ne(monks[0]["community"], monks[1]["community"])
	assert_array_contains(
		monks.map(func(entry): return entry["anchor_id"]), &"landmark_timber_oratory"
	)
	assert_array_contains(monks.map(func(entry): return entry["anchor_id"]), &"room_lay_brothers")


func test_padise_after_attack_clears_monastic_population() -> void:
	var manifest := Controller.phase_manifest(Controller.PHASE_AFTER_ATTACK)
	assert_true(
		(manifest["monks"] as Array).is_empty(),
		"the burned phase must not repopulate the monastery"
	)
	assert_eq(
		Controller.phase_for_campaign_phase(&"phase.act1_climax"), Controller.PHASE_AFTER_ATTACK
	)
	assert_eq(
		Controller.phase_for_campaign_phase(&"phase.prologue_day"), Controller.PHASE_BEFORE_ATTACK
	)


func test_padise_contract_covers_navigable_rooms_and_landmarks() -> void:
	var parsed := MapRrmapParser.parse_file(MAP_PATH)
	assert_true(parsed.is_ok(), str(parsed.formatted_diagnostics()))
	if not parsed.is_ok():
		return
	var definition: MapDefinition = parsed.definition
	assert_true(Controller.validate_definition(definition).is_empty())
	for anchor_id in Controller.required_anchor_ids():
		assert_true(MapVerification.has_anchor(definition, anchor_id))
	for landmark_id in Controller.required_view_landmark_ids():
		assert_true(definition.view_landmarks.any(func(item): return item.get("id") == landmark_id))
	assert_true(
		definition.props.any(func(item): return item.get("kind") == MapTypes.PROP_KIND_WELL)
	)


func test_padise_soundscape_uses_loadable_existing_themes() -> void:
	for phase_id in [Controller.PHASE_BEFORE_ATTACK, Controller.PHASE_AFTER_ATTACK]:
		var theme_id := Controller.sound_theme_for_phase(phase_id)
		assert_true(MusicDirectorScript.has_theme(theme_id))
		var tracks := MusicDirectorScript.day_track_paths_for_theme(theme_id)
		assert_false(tracks.is_empty())
		for path: String in tracks:
			assert_true(
				ResourceLoader.exists(path), "Padise soundscape track should load: %s" % path
			)
