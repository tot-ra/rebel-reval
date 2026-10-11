extends "res://tests/godot/test_case.gd"

## Village window variants: every style builds real relief geometry (not one
## flat quad), looks are deterministic per building and rural looks vary.


func _build(style: StringName) -> CityBuildingBuilder.Shell:
	var shell := CityBuildingBuilder.Shell.new()
	var look := {
		"rural": true,
		"trim": CityWindows.TRIM_PAINTS[0],
		"shutter": CityWindows.SHUTTER_PAINTS[0],
		"style": style,
		"panes": 2,
	}
	CityWindows.add_window(
		shell, Vector2.ZERO, Vector2(1, 0), Vector2(0, 1), 1.0, 0.6, style, look, 0.5
	)
	return shell


func test_every_style_has_depth_beyond_the_wall() -> void:
	for style: StringName in [
		&"plain",
		&"platband",
		&"gable_cap",
		&"shutters_open",
		&"shutters_closed",
		&"slit",
		&"surround",
		&"leaded",
		&"panelled",
		&"hood",
		&"notched",
		&"carved",
		&"carved_shutters"
	]:
		var shell := _build(style)
		assert_false(shell.surfaces.has("opening"), "%s has no opaque fake pane" % style)
		if style != &"slit":
			assert_true(shell.surfaces.has("glass:forest"), "%s has glazing" % style)
		var depth := 0.0
		for key: String in shell.surfaces:
			for v in (shell.surfaces[key] as CityBuildingBuilder.Surf).verts:
				depth = maxf(depth, v.z)
		assert_true(depth >= 0.07, "%s stands off the wall (%.3f m)" % [style, depth])


func test_platband_is_richer_than_plain() -> void:
	assert_true(
		(
			_build(&"platband").surface("paint").verts.size()
			> _build(&"plain").surface("paint").verts.size()
		),
		"carved platband adds geometry"
	)


func test_look_is_deterministic_and_rural_looks_vary() -> void:
	var seen := {}
	for i in 40:
		var r1 := RandomNumberGenerator.new()
		r1.seed = i
		var r2 := RandomNumberGenerator.new()
		r2.seed = i
		var l1 := CityWindows.look(r1, &"log")
		assert_eq(l1, CityWindows.look(r2, &"log"), "same seed, same look")
		seen[l1["style"]] = true
	assert_true(seen.size() >= 4, "rural styles vary across houses (%d)" % seen.size())
	var town_seen := {}
	for i in 40:
		var rng := RandomNumberGenerator.new()
		rng.seed = i
		var town := CityWindows.look(rng, &"limestone")
		town_seen[town["style"]] = true
		assert_false(town["style"] in [&"platband", &"gable_cap"], "no late carving")
	assert_true(town_seen.size() >= 4, "town houses also vary")


func test_carving_adds_relief_by_wealth() -> void:
	var plain := _build(&"plain").surface("paint").verts.size()
	var notched := _build(&"notched").surface("paint").verts.size()
	var carved := _build(&"carved").surface("paint").verts.size()
	assert_true(notched > plain, "notched lintel adds teeth (%d > %d)" % [notched, plain])
	assert_true(carved > notched * 2, "carved surround is the richest (%d)" % carved)
	assert_true(
		_build(&"carved_shutters").surface("paint").verts.size()
		> _build(&"shutters_open").surface("paint").verts.size(),
		"carved shutters add a frieze"
	)


func test_wealth_selects_the_window_repertoire() -> void:
	var rich_styles := {}
	for i in 60:
		var poor_rng := RandomNumberGenerator.new()
		poor_rng.seed = i
		var poor := CityWindows.look(poor_rng, &"log", 0)
		assert_false(
			poor["style"] in [&"carved", &"carved_shutters", &"leaded", &"panelled", &"notched"],
			"poor cottage has no carving (%s)" % poor["style"]
		)
		assert_true(poor["glazing"] in [&"open", &"horn"], "poor glazing is open or horn")
		var rich_rng := RandomNumberGenerator.new()
		rich_rng.seed = i
		var rich := CityWindows.look(rich_rng, &"log", 2)
		assert_true(
			rich["style"] in CityWindows.TIMBER_POOLS[2], "rich timber style from its pool"
		)
		rich_styles[rich["style"]] = true
		for wealth in 3:
			for family: StringName in [&"log", &"limestone"]:
				var rng := RandomNumberGenerator.new()
				rng.seed = i
				var any := CityWindows.look(rng, family, wealth)
				assert_false(any["style"] in [&"platband", &"gable_cap"], "no late carving")
	assert_true(rich_styles.has(&"carved"), "rich timber houses get carved boards")
	assert_true(rich_styles.size() >= 3, "rich houses still vary (%d)" % rich_styles.size())


func test_low_eave_drops_the_carved_head() -> void:
	var look := CityWindows.look(RandomNumberGenerator.new(), &"log", 2)
	look["style"] = &"carved"
	look["pool"] = [&"carved"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for w in CityWindows.placements(
		Vector2.ZERO, Vector2(12, 0), 0.0, 2.35, Vector2(-1, -1), rng, look
	):
		assert_true(w["style"] != &"carved", "no carved head board above a 2.35 m eave")


func test_one_house_has_one_window_style_and_size() -> void:
	var styles := {}
	for i in 40:
		var look_rng := RandomNumberGenerator.new()
		look_rng.seed = i
		var look := CityWindows.look(look_rng, &"log", i % 3)
		var rng := RandomNumberGenerator.new()
		rng.seed = i
		var windows: Array[Dictionary] = []
		for wall in [[Vector2.ZERO, Vector2(14, 0)], [Vector2(14, 0), Vector2(14, 9)]]:
			windows.append_array(
				CityWindows.placements(wall[0], wall[1], 0.0, 6.4, Vector2(-1, -1), rng, look)
			)
		assert_true(windows.size() > 2, "house %d has windows" % i)
		for w in windows:
			assert_eq(w["style"], windows[0]["style"], "house %d: one window style" % i)
			assert_eq(w["h"], windows[0]["h"], "house %d: one window size" % i)
		styles[windows[0]["style"]] = true
	assert_true(styles.size() >= 4, "different houses still differ (%d)" % styles.size())
