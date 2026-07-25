class_name MapViewBirdFlight
extends Node3D

## Deterministic gliding bird silhouettes for outdoor maps (P0-105). Species
## selection reuses P0-117 spawn weights; song playback is MapViewBirdAmbientAudio.

const BirdAmbientAudio := preload("res://scripts/map/view3d/map_view_bird_ambient_audio.gd")
const BirdMeshes := preload("res://scripts/map/view3d/map_view_bird_meshes.gd")
const BirdSpecies := preload("res://scripts/map/view3d/map_view_bird_species.gd")

const MAX_CONCURRENT_BIRDS := 4
const MIN_SPAWN_INTERVAL_S := 4.0
const MAX_SPAWN_INTERVAL_S := 14.0
const FLIGHT_HEIGHT_MIN := 7.0
const FLIGHT_HEIGHT_MAX := 15.0
const FLIGHT_SPEED_MIN := 5.5
const FLIGHT_SPEED_MAX := 11.0
const EDGE_MARGIN := 5.0

## Wing flap timing: seconds between keyframe advances. 0.12s gives roughly
## 3-4 flaps/second which looks natural for most species at gameplay distance.
const FLAP_INTERVAL_S := 0.12
## Some species glide more than they flap; skip that many flaps between active
## stroke bursts so swallows flap often while eagles mostly soar.
const GLIDE_SKIP_DEFAULT := 3

var _birds: Array[Node3D] = []
var _rng := RandomNumberGenerator.new()
var _flight_enabled := true
var _context := &""
var _seed_key := &""
var _cycle_progress := 0.0
var _world_max := Vector2.ZERO
var _seconds_until_spawn := 0.0
var _spawn_tick := 0


func _ready() -> void:
	for index in MAX_CONCURRENT_BIRDS:
		var bird := _make_bird_actor(index)
		add_child(bird)
		bird.visible = false
		_birds.append(bird)


func set_flight_enabled(enabled: bool) -> void:
	_flight_enabled = enabled
	if not enabled:
		_hide_all_birds()
		_seconds_until_spawn = 0.0


func configure(map_id: StringName, context: StringName, size_cells: Vector2i) -> void:
	_context = context
	_seed_key = map_id
	_spawn_tick = 0
	_seconds_until_spawn = 0.0
	_world_max = Vector2(float(size_cells.x), float(size_cells.y))
	_hide_all_birds()


func sync(context: StringName, cycle_progress: float, delta: float, enabled: bool = true) -> void:
	_flight_enabled = enabled
	_context = context
	_cycle_progress = wrapf(cycle_progress, 0.0, 1.0)
	if not _should_spawn():
		_hide_all_birds()
		return
	_advance_active_birds(delta)
	if delta <= 0.0:
		return
	_seconds_until_spawn -= delta
	if _seconds_until_spawn > 0.0:
		return
	if active_bird_count() >= MAX_CONCURRENT_BIRDS:
		_seconds_until_spawn = MIN_SPAWN_INTERVAL_S
		return
	_spawn_bird()
	_spawn_tick += 1
	_seconds_until_spawn = _next_spawn_delay()


func active_bird_count() -> int:
	var count := 0
	for bird in _birds:
		if bird.visible:
			count += 1
	return count


static func pick_species(
	seed_key: StringName,
	context: StringName,
	cycle_progress: float,
	spawn_tick: int
) -> StringName:
	var candidates := weighted_flight_candidates(context, cycle_progress)
	if candidates.is_empty():
		return &""
	var rng := RandomNumberGenerator.new()
	rng.seed = BirdAmbientAudio.hash_seed(seed_key, context, spawn_tick) ^ 0x27D4EB2D
	var total_weight := 0.0
	for entry: Dictionary in candidates:
		total_weight += float(entry["weight"])
	if total_weight <= 0.0:
		return &""
	var roll := rng.randf() * total_weight
	var accumulated := 0.0
	for entry: Dictionary in candidates:
		accumulated += float(entry["weight"])
		if roll <= accumulated:
			return entry["species"] as StringName
	return candidates[candidates.size() - 1]["species"] as StringName


static func weighted_flight_candidates(context: StringName, cycle_progress: float) -> Array:
	var candidates: Array = []
	if context.is_empty():
		return candidates
	for species in BirdSpecies.ALL_SPECIES:
		var weight := BirdSpecies.spawn_weight(species, context)
		if weight <= 0.0:
			continue
		var song := BirdSpecies.song_profile_for(species)
		var time_tag := StringName(song.get("time", &"day"))
		if not BirdAmbientAudio.matches_song_time(time_tag, cycle_progress):
			continue
		if BirdMeshes.mesh_for(species, BirdSpecies.POSE_GLIDING) == null:
			continue
		candidates.append({"species": species, "weight": weight})
	return candidates


static func distinct_species_for_context(
	seed_key: StringName,
	context: StringName,
	cycle_progress: float,
	sample_count: int
) -> Array[StringName]:
	var species_list: Array[StringName] = []
	var seen: Dictionary = {}
	for tick in sample_count:
		var species := pick_species(seed_key, context, cycle_progress, tick)
		if species.is_empty() or seen.has(species):
			continue
		seen[species] = true
		species_list.append(species)
	return species_list


func _should_spawn() -> bool:
	return _flight_enabled and not _context.is_empty() and _world_max.x > EDGE_MARGIN * 2.0


func _advance_active_birds(delta: float) -> void:
	for bird in _birds:
		if not bird.visible:
			continue
		var traveled := float(bird.get_meta(&"traveled", 0.0)) + float(bird.get_meta(&"speed", 0.0)) * delta
		var path_length := float(bird.get_meta(&"path_length", 1.0))
		if traveled >= path_length:
			bird.visible = false
			continue
		var start: Vector3 = bird.get_meta(&"start")
		var end: Vector3 = bird.get_meta(&"end")
		var t := traveled / path_length
		var position := start.lerp(end, t)
		bird.position = position
		bird.look_at(position + (end - start).normalized(), Vector3.UP)
		bird.set_meta(&"traveled", traveled)
		# Advance wing flap animation
		_advance_flap(bird, delta)


func _spawn_bird() -> void:
	var species := pick_species(_seed_key, _context, _cycle_progress, _spawn_tick)
	if species.is_empty():
		return
	var bird := _first_idle_bird()
	if bird == null:
		return
	var path := _random_path(_seed_key, _spawn_tick)
	# Generate the flapping cycle meshes for this species
	var cycle := BirdMeshes.flap_cycle(species)
	if cycle.is_empty():
		return
	var model := bird.get_node_or_null("Model") as MeshInstance3D
	if model == null:
		return
	# Start with the neutral wing position (index 2 in FLAP_KEYFRAMES = 0.0)
	model.mesh = cycle[2]
	_apply_mesh_material(model)
	var start: Vector3 = path["start"]
	var end: Vector3 = path["end"]
	bird.position = start
	bird.look_at(start + (end - start).normalized(), Vector3.UP)
	bird.visible = true
	bird.set_meta(&"start", start)
	bird.set_meta(&"end", end)
	bird.set_meta(&"speed", path["speed"])
	bird.set_meta(&"path_length", start.distance_to(end))
	bird.set_meta(&"traveled", 0.0)
	# Flapping state: mesh cycle, current keyframe index, and timer
	bird.set_meta(&"flap_cycle", cycle)
	bird.set_meta(&"flap_index", 2)
	bird.set_meta(&"flap_timer", 0.0)
	# Species-dependent glide skip: larger birds flap less often
	bird.set_meta(&"glide_skip", _glide_skip_for_species(species))
	bird.set_meta(&"glide_counter", 0)


func _random_path(seed_key: StringName, spawn_tick: int) -> Dictionary:
	_rng.seed = BirdAmbientAudio.hash_seed(seed_key, _context, spawn_tick) ^ 0x165667B1
	var height := _rng.randf_range(FLIGHT_HEIGHT_MIN, FLIGHT_HEIGHT_MAX)
	var min_axis := EDGE_MARGIN
	var max_x := _world_max.x - EDGE_MARGIN
	var max_z := _world_max.y - EDGE_MARGIN
	var side := _rng.randi_range(0, 3)
	var start := Vector3.ZERO
	var end := Vector3.ZERO
	match side:
		0:
			start = Vector3(min_axis, height, _rng.randf_range(min_axis, max_z))
			end = Vector3(max_x, height * _rng.randf_range(0.92, 1.08), _rng.randf_range(min_axis, max_z))
		1:
			start = Vector3(max_x, height, _rng.randf_range(min_axis, max_z))
			end = Vector3(min_axis, height * _rng.randf_range(0.92, 1.08), _rng.randf_range(min_axis, max_z))
		2:
			start = Vector3(_rng.randf_range(min_axis, max_x), height, min_axis)
			end = Vector3(_rng.randf_range(min_axis, max_x), height * _rng.randf_range(0.92, 1.08), max_z)
		_:
			start = Vector3(_rng.randf_range(min_axis, max_x), height, max_z)
			end = Vector3(_rng.randf_range(min_axis, max_x), height * _rng.randf_range(0.92, 1.08), min_axis)
	return {
		"start": start,
		"end": end,
		"speed": _rng.randf_range(FLIGHT_SPEED_MIN, FLIGHT_SPEED_MAX),
	}


func _next_spawn_delay() -> float:
	_rng.seed = BirdAmbientAudio.hash_seed(_seed_key, _context, _spawn_tick) ^ 0x9E3779B9
	return _rng.randf_range(MIN_SPAWN_INTERVAL_S, MAX_SPAWN_INTERVAL_S)


func _first_idle_bird() -> Node3D:
	for bird in _birds:
		if not bird.visible:
			return bird
	return null


func _advance_flap(bird: Node3D, delta: float) -> void:
	var cycle: Array = bird.get_meta(&"flap_cycle", [])
	if cycle.is_empty():
		return
	var timer := float(bird.get_meta(&"flap_timer", 0.0)) + delta
	var glide_skip: int = bird.get_meta(&"glide_skip", GLIDE_SKIP_DEFAULT)
	var counter: int = bird.get_meta(&"glide_counter", 0)
	if timer < FLAP_INTERVAL_S:
		bird.set_meta(&"flap_timer", timer)
		return
	# Reset timer, carry over excess time for consistent frame pacing
	bird.set_meta(&"flap_timer", fmod(timer, FLAP_INTERVAL_S))
	# During glide skip frames the bird holds the neutral pose.
	if counter < glide_skip:
		bird.set_meta(&"glide_counter", counter + 1)
		return
	bird.set_meta(&"glide_counter", 0)
	var idx: int = bird.get_meta(&"flap_index", 2)
	idx = (idx + 1) % cycle.size()
	bird.set_meta(&"flap_index", idx)
	var model := bird.get_node_or_null("Model") as MeshInstance3D
	if model != null:
		model.mesh = cycle[idx]


## Larger soaring birds (raptors, gulls) hold the glide longer between flap
## bursts; small songbirds and swallows flap nearly continuously.
func _glide_skip_for_species(species: StringName) -> int:
	var group := BirdSpecies.group_for(species)
	match group:
		BirdSpecies.GROUP_RAPTOR:
			return 6
		BirdSpecies.GROUP_GULL, BirdSpecies.GROUP_WATERFOWL:
			return 4
		BirdSpecies.GROUP_OWL:
			return 5
		BirdSpecies.GROUP_SWALLOW:
			return 1
		BirdSpecies.GROUP_TERN:
			return 2
		_:
			return GLIDE_SKIP_DEFAULT


func _hide_all_birds() -> void:
	for bird in _birds:
		bird.visible = false


func _make_bird_actor(index: int) -> Node3D:
	var bird := Node3D.new()
	bird.name = "FlightBird%d" % index
	var model := MeshInstance3D.new()
	model.name = "Model"
	bird.add_child(model)
	_apply_mesh_material(model)
	return bird


func _apply_mesh_material(model: MeshInstance3D) -> void:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.metallic = 0.0
	material.roughness = 0.92
	model.material_override = material
