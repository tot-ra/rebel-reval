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
		&"panelled"
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
