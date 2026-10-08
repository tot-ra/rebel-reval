extends "res://tests/godot/test_case.gd"


func _pool_catalog(no_repeat: int, streams: int) -> SfxCatalog:
	var paths: Array = []
	for i in streams:
		paths.append("res://sounds/door.mp3")
	var catalog := SfxCatalog.new()
	catalog.load_dictionary({"entries": [{
		"id": "sfx.test.pool", "bus": "SFX", "streams": paths, "no_repeat": no_repeat,
	}]})
	return catalog


func test_pick_avoids_recent_streams() -> void:
	var player := SfxPlayer.new()
	player.setup(_pool_catalog(2, 5), 42)
	var history: Array[int] = []
	for i in 200:
		var pick := player.pick_stream_index(&"sfx.test.pool")
		assert_true(pick >= 0 and pick < 5)
		assert_false(history.slice(maxi(history.size() - 2, 0)).has(pick), "repeat at %d" % i)
		history.append(pick)
	player.free()


func test_window_is_clamped_for_small_pools() -> void:
	var player := SfxPlayer.new()
	player.setup(_pool_catalog(10, 2), 7)
	var last := player.pick_stream_index(&"sfx.test.pool")
	for i in 20:
		var pick := player.pick_stream_index(&"sfx.test.pool")
		assert_true(pick != last)
		last = pick
	player.free()


func test_same_seed_gives_same_sequence() -> void:
	var a := SfxPlayer.new()
	var b := SfxPlayer.new()
	a.setup(_pool_catalog(1, 6), 99)
	b.setup(_pool_catalog(1, 6), 99)
	for i in 30:
		assert_eq(a.pick_stream_index(&"sfx.test.pool"), b.pick_stream_index(&"sfx.test.pool"))
	a.free()
	b.free()
