extends "res://tests/godot/test_case.gd"

const BirdSpecies := preload("res://scripts/map/view3d/map_view_bird_species.gd")


func test_every_catalog_cue_resolves_to_processed_audio_stream() -> void:
	for species in BirdSpecies.ALL_SPECIES:
		var song := BirdSpecies.song_profile_for(species)
		var cue: StringName = song.get("cue", &"")
		assert_false(String(cue).is_empty(), "%s needs a catalog cue" % species)
		var path := BirdSpecies.stream_path_for_cue(cue)
		assert_false(path.is_empty(), "%s cue must map to a processed clip path" % cue)
		assert_true(ResourceLoader.exists(path), "%s must exist at %s" % [cue, path])
		var stream := load(path)
		assert_true(stream is AudioStream, "%s must import as AudioStream" % path)
		assert_true((stream as AudioStream).get_length() >= 15.0, "%s must be at least 15 seconds" % path)
		assert_true((stream as AudioStream).get_length() <= 90.5, "%s must stay within the 90 second cap" % path)
