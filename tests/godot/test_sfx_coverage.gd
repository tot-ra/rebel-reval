extends "res://tests/godot/test_case.gd"

## Catalog coverage for the ADR 0035 phase-2 pilot: every surface the pilot maps
## use must produce an audible footstep, and every ambience profile ID must
## exist. A typo in a profile or a surface with no pool anywhere would otherwise
## ship as silence.

const AmbienceProfilesScript := preload("res://scripts/audio/ambience_profiles.gd")
## Mirrors ONE_SHOT_MAX_SECONDS in tools/validate_sfx_catalog.py.
const ONE_SHOT_MAX_SECONDS := 1.5
## Terrains authored in content/maps/kalev_smithy.rrmap and
## content/maps/lower_town_slice.rrmap, which together cover all six surfaces.
const PILOT_TERRAINS: Array[StringName] = [
	MapTypes.TERRAIN_TIMBER_FLOOR,
	MapTypes.TERRAIN_PLASTER,
	MapTypes.TERRAIN_STONE,
	MapTypes.TERRAIN_COBBLESTONE,
	MapTypes.TERRAIN_DIRT,
	MapTypes.TERRAIN_MUD,
	MapTypes.TERRAIN_GRASS,
	MapTypes.TERRAIN_MEADOW,
	MapTypes.TERRAIN_HAY,
	MapTypes.TERRAIN_STRAW,
	MapTypes.TERRAIN_SAND,
	MapTypes.TERRAIN_ASH,
	MapTypes.TERRAIN_WATER,
]


## Coverage only: this passes as long as *something* plays, so it cannot catch a
## stand-in from the wrong material. That guard is
## test_sfx_surface_resolver.gd::test_stand_ins_never_name_another_material
## (R-1383); do not treat this test as proof that a surface sounds right.
func test_every_surface_and_gait_resolves_to_a_catalog_entry() -> void:
	var catalog := SfxCatalog.load_default()
	for surface: StringName in SurfaceResolver.SURFACES:
		for gait: StringName in SurfaceResolver.GAITS:
			var sound_id := SurfaceResolver.resolve_footstep_sound_id(catalog, surface, gait)
			assert_ne(sound_id, &"", "no footstep sound for %s %s" % [surface, gait])
			assert_true(catalog.has_entry(sound_id), "catalog lost %s" % sound_id)


func test_pilot_map_terrains_all_sound() -> void:
	var catalog := SfxCatalog.load_default()
	for terrain: StringName in PILOT_TERRAINS:
		var surface := SurfaceResolver.surface_for_terrain(terrain)
		assert_ne(surface, &"", "pilot terrain %s has no surface" % terrain)
		assert_ne(
			SurfaceResolver.resolve_footstep_sound_id(catalog, surface),
			&"",
			"pilot terrain %s resolves to a silent surface" % terrain
		)


func test_ambience_profiles_only_name_existing_catalog_ids() -> void:
	var catalog := SfxCatalog.load_default()
	var ids := AmbienceProfilesScript.referenced_sound_ids()
	assert_true(ids.size() >= 3, "the pilot profiles must declare their layers")
	for sound_id: StringName in ids:
		assert_true(catalog.has_entry(sound_id), "profile references missing %s" % sound_id)


func test_pilot_maps_have_profiles_with_a_bed() -> void:
	for map_id: StringName in [&"kalev_smithy", &"lower_town_slice"]:
		assert_true(AmbienceProfilesScript.has_profile(map_id), "no profile for %s" % map_id)
		var profile := AmbienceProfilesScript.profile_for_map(map_id)
		assert_true((profile.get("bed", []) as Array).size() >= 1, "%s needs a bed" % map_id)


## R-1382: a multi-second walk cycle in a one-shot pool makes every foot plant
## start a whole cycle, and they overlap. tools/validate_sfx_catalog.py checks
## the files on disk; this checks what Godot actually imported and will play.
func test_one_shot_pools_hold_one_shots() -> void:
	var catalog := SfxCatalog.load_default()
	for sound_id: StringName in [
		&"sfx.footstep.wood.walk", &"sfx.footstep.mud.walk", &"sfx.door.wood.use"
	]:
		var entry := catalog.get_entry(sound_id)
		assert_true(entry.has("streams"), "missing one-shot entry %s" % sound_id)
		for path: Variant in entry["streams"]:
			# CACHE_MODE_IGNORE: a cached stream would still be held at exit and
			# the engine reports that as an error line in the test output.
			var stream := (
				ResourceLoader
				. load(String(path), "AudioStream", ResourceLoader.CACHE_MODE_IGNORE) as AudioStream
			)
			assert_ne(stream, null, "%s: cannot load %s" % [sound_id, path])
			assert_true(
				stream.get_length() <= ONE_SHOT_MAX_SECONDS,
				(
					"%s: %s is %.2f s, too long to play per event"
					% [sound_id, path, stream.get_length()]
				)
			)


func test_interactable_sound_ids_exist() -> void:
	var catalog := SfxCatalog.load_default()
	for sound_id: StringName in [&"sfx.door.wood.use", &"amb.weather.rain_roof"]:
		assert_true(catalog.has_entry(sound_id), "missing wired sound %s" % sound_id)
