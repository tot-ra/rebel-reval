extends "res://tests/godot/test_case.gd"

const BUSES: Array[String] = ["Ambience", "Weather", "Footsteps", "Combat", "UI"]


func test_default_catalog_loads_and_every_stream_resolves() -> void:
	var catalog := SfxCatalog.load_default()
	assert_true(catalog.ids().size() >= 6)
	for sound_id in catalog.ids():
		var entry := catalog.get_entry(sound_id)
		assert_true(AudioServer.get_bus_index(String(entry["bus"])) >= 0, "bus exists for %s" % sound_id)
		for path in entry["streams"]:
			assert_true(load(String(path)) is AudioStream, "loads %s" % path)


func test_new_buses_route_through_sfx() -> void:
	var sfx := String(AudioServer.get_bus_name(AudioServer.get_bus_index("SFX")))
	for bus in BUSES:
		var index := AudioServer.get_bus_index(bus)
		assert_true(index >= 0, "bus %s" % bus)
		assert_eq(String(AudioServer.get_bus_send(index)), sfx)


func test_unknown_id_returns_null() -> void:
	var player := SfxPlayer.new()
	player.setup(SfxCatalog.load_default(), 1)
	assert_true(player.play(&"sfx.nope.nothing") == null)
	player.free()
