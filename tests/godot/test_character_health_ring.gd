extends "res://tests/godot/test_case.gd"


func test_health_ring_color_thresholds() -> void:
	assert_eq(
		CharacterHealthRing.color_for_ratio(1.0),
		CharacterHealthRing.COLOR_HEALTHY,
		"Full health should stay green"
	)
	assert_eq(
		CharacterHealthRing.color_for_ratio(0.6),
		CharacterHealthRing.COLOR_HEALTHY,
		"Above half health should stay green"
	)
	assert_eq(
		CharacterHealthRing.color_for_ratio(0.4),
		CharacterHealthRing.COLOR_HEALTHY,
		"Mid health should stay green (no yellow warn band)"
	)
	assert_eq(
		CharacterHealthRing.color_for_ratio(0.1),
		CharacterHealthRing.COLOR_CRITICAL,
		"Low health should turn red"
	)


func test_health_ring_ratio_tracks_damage() -> void:
	var ring := CharacterHealthRing.new()
	ring.set_health(35.0, 100.0)
	assert_eq(ring.get_health_ratio(), 0.35, "Ring ratio should mirror current health")
	ring.set_health(0.0, 100.0)
	assert_eq(ring.get_health_ratio(), 0.0, "Zero health should empty the ring")
	ring.free()
