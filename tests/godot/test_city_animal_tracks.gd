extends "res://tests/godot/test_case.gd"

## Animal prints on the city ground trail (docs/SYSTEMS/SEAMLESS_CITY.md,
## "Ground relief, roads and prints"): every city animal species leaves its own
## kind of print, fish leave none, settled snow takes them deeper than dry earth.

const FLAT := 0.5
const CITY_ANIMALS: Array[StringName] = [
	&"horse", &"cow", &"pig", &"goat", &"sheep", &"dog", &"red_fox", &"cat", &"hare",
	&"rat", &"chicken", &"goose",
]


func _soft_trail() -> CityGroundTrail:
	var plan := CityPlan.load_default()
	# Every spot counts as bare packed earth, so prints always bite.
	var trail := CityGroundTrail.create(plan, func(_p: Vector2) -> Color: return Color(0, 1, 0, 0))
	trail.update_for(Vector2(0, -400), 0.016)
	return trail


func _walk(trail: CityGroundTrail, key: int, species: StringName, from: Vector2) -> void:
	var pos := from
	for i in 60:
		pos += Vector2(0.1, 0.0)
		trail.update_for(Vector2(0, -400), 0.016)
		CityAnimalTracks.track(trail, key, pos, species)


func _pressed_cells(trail: CityGroundTrail, rect: Rect2) -> int:
	var n := 0
	var x := rect.position.x
	while x < rect.end.x:
		var y := rect.position.y
		while y < rect.end.y:
			if trail.value_at(Vector2(x, y)) < FLAT - 0.05:
				n += 1
			y += CityGroundTrail.CELL
		x += CityGroundTrail.CELL
	return n


func _deepest(trail: CityGroundTrail, rect: Rect2) -> float:
	var low := FLAT
	var x := rect.position.x
	while x < rect.end.x:
		var y := rect.position.y
		while y < rect.end.y:
			low = minf(low, trail.value_at(Vector2(x, y)))
			y += CityGroundTrail.CELL
		x += CityGroundTrail.CELL
	return low


func test_every_city_animal_leaves_prints_in_mud() -> void:
	for species in CITY_ANIMALS:
		assert_true(CityAnimalTracks.leaves_tracks(species), "%s has a print" % species)
		var trail := _soft_trail()
		# Soaked mud: even a rat's light paws bite (dry earth barely takes them).
		trail.wetness = 1.0
		_walk(trail, 1, species, Vector2(2, -398))
		var cells := _pressed_cells(trail, Rect2(2, -398.5, 6, 1))
		assert_true(cells > 3, "%s pressed %d cells" % [species, cells])
		trail.free()


func test_fish_leave_nothing() -> void:
	assert_false(CityAnimalTracks.leaves_tracks(&"perch"))
	var trail := _soft_trail()
	_walk(trail, 2, &"perch", Vector2(2, -398))
	assert_eq(_pressed_cells(trail, Rect2(2, -398.5, 6, 1)), 0)
	trail.free()


func test_paw_shows_separate_toes() -> void:
	var trail := _soft_trail()
	var at := Vector2(0, -400)
	CityAnimalTracks.stamp_paw(trail, at, Vector2.RIGHT, CityAnimalTracks.PAWS[&"dog"], 1.0)
	assert_true(trail.value_at(at) < FLAT - 0.1, "heel pad pressed")
	var reach := float(CityAnimalTracks.PAWS[&"dog"]["reach"])
	var toe := at + Vector2(reach, 0.0).rotated(float(CityAnimalTracks.PAWS[&"dog"]["fan"]) * 0.33)
	assert_true(trail.value_at(toe) < FLAT - 0.1, "toe pressed")
	# Between the pad and the toes the ground is not pressed: the toes read as toes.
	var gap := at + Vector2(float(CityAnimalTracks.PAWS[&"dog"]["pad"].x) + 0.012, 0.0)
	assert_true(trail.value_at(gap) > trail.value_at(toe) + 0.05, "gap between pad and toes")
	trail.free()


func test_snow_takes_deeper_prints_than_dry_earth() -> void:
	var dry := _soft_trail()
	_walk(dry, 3, &"dog", Vector2(2, -398))
	var dry_depth := _deepest(dry, Rect2(2, -398.5, 6, 1))
	dry.free()
	var snowy := _soft_trail()
	snowy.snow_cover = 1.0
	_walk(snowy, 3, &"dog", Vector2(2, -398))
	var snow_depth := _deepest(snowy, Rect2(2, -398.5, 6, 1))
	snowy.free()
	assert_true(CitySnow.patch(Vector2(5, -398), 1.0) > 0.5, "test spot lies under snow")
	assert_true(snow_depth < dry_depth - 0.02, "snow %.3f vs dry %.3f" % [snow_depth, dry_depth])
