class_name MapViewBirdAmbientAudio
extends Node

## Positional ambient bird song playback for outdoor maps (P0-105). Species
## selection reuses P0-117 spawn weights and P0-123 processed clips.

const BirdSpecies := preload("res://scripts/map/view3d/map_view_bird_species.gd")
const DayNightCycle := preload("res://scripts/global/day_night_cycle.gd")

const MAX_CONCURRENT_VOICES := 3
const MIN_CALL_INTERVAL_S := 2.5
const MAX_CALL_INTERVAL_S := 9.0
const LISTENER_RADIUS_MIN := 14.0
const LISTENER_RADIUS_MAX := 36.0
const VOICE_HEIGHT_MIN := 3.0
const VOICE_HEIGHT_MAX := 9.0
const MAX_AUDIBLE_DISTANCE := 48.0
const BASE_LINEAR_VOLUME := 0.28

var _players: Array[AudioStreamPlayer3D] = []
var _rng := RandomNumberGenerator.new()
var _audio_enabled := true
var _context := &""
var _seed_key := &""
var _cycle_progress := DayNightCycle.DEFAULT_PROGRESS
var _listener_position := Vector3.ZERO
var _seconds_until_next_call := 0.0
var _schedule_tick := 0


func _ready() -> void:
	for index in MAX_CONCURRENT_VOICES:
		var player := AudioStreamPlayer3D.new()
		player.name = "BirdVoice%d" % index
		player.unit_size = 4.0
		player.max_distance = MAX_AUDIBLE_DISTANCE
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		player.bus = &"Master"
		add_child(player)
		_players.append(player)


func set_audio_enabled(enabled: bool) -> void:
	_audio_enabled = enabled
	if not enabled:
		_stop_all_voices()
		_seconds_until_next_call = 0.0


func configure(map_id: StringName, context: StringName) -> void:
	_context = context
	_seed_key = map_id
	_schedule_tick = 0
	_seconds_until_next_call = 0.0
	_stop_all_voices()


func sync(
	context: StringName,
	cycle_progress: float,
	listener_position: Vector3,
	delta: float,
	audio_enabled: bool = true
) -> void:
	_audio_enabled = audio_enabled
	_context = context
	_cycle_progress = wrapf(cycle_progress, 0.0, 1.0)
	_listener_position = listener_position
	if not _should_schedule():
		_stop_all_voices()
		return
	_prune_finished_voices()
	if delta <= 0.0:
		return
	_seconds_until_next_call -= delta
	if _seconds_until_next_call > 0.0:
		return
	if active_voice_count() >= MAX_CONCURRENT_VOICES:
		_seconds_until_next_call = MIN_CALL_INTERVAL_S
		return
	var species := pick_species(_seed_key, _context, _cycle_progress, _schedule_tick)
	_schedule_tick += 1
	_seconds_until_next_call = next_call_delay(_seed_key, _context, _schedule_tick)
	if species.is_empty():
		return
	_play_species(species, _seed_key, _schedule_tick)


func active_voice_count() -> int:
	var count := 0
	for player in _players:
		if player.playing:
			count += 1
	return count


static func matches_song_time(time_tag: StringName, cycle_progress: float) -> bool:
	var hour := DayNightCycle.progress_to_hour(cycle_progress)
	match time_tag:
		&"day":
			return hour >= 7.0 and hour <= 19.0
		&"night":
			return hour >= 21.0 or hour < 5.0
		&"dawn_dusk":
			return (hour >= 5.0 and hour < 8.0) or (hour >= 18.0 and hour < 21.0)
		&"dawn_day":
			return hour >= 5.0 and hour <= 14.0
		&"night_dawn":
			return hour >= 21.0 or hour < 8.0
		_:
			return true


static func pick_species(
	seed_key: StringName,
	context: StringName,
	cycle_progress: float,
	schedule_tick: int
) -> StringName:
	var candidates := weighted_candidates(context, cycle_progress)
	if candidates.is_empty():
		return &""
	var rng := RandomNumberGenerator.new()
	rng.seed = hash_seed(seed_key, context, schedule_tick)
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


static func weighted_candidates(context: StringName, cycle_progress: float) -> Array:
	var candidates: Array = []
	if context.is_empty():
		return candidates
	for species in BirdSpecies.ALL_SPECIES:
		var weight := BirdSpecies.spawn_weight(species, context)
		if weight <= 0.0:
			continue
		var song := BirdSpecies.song_profile_for(species)
		var time_tag := StringName(song.get("time", &"day"))
		if not matches_song_time(time_tag, cycle_progress):
			continue
		var stream_path := BirdSpecies.stream_path_for_cue(song.get("cue", &""))
		if stream_path.is_empty():
			continue
		candidates.append({"species": species, "weight": weight})
	return candidates


static func distinct_cues_for_context(
	seed_key: StringName,
	context: StringName,
	cycle_progress: float,
	sample_count: int
) -> Array[StringName]:
	var cues: Array[StringName] = []
	var seen: Dictionary = {}
	for tick in sample_count:
		var species := pick_species(seed_key, context, cycle_progress, tick)
		if species.is_empty():
			continue
		var cue: StringName = BirdSpecies.song_profile_for(species).get("cue", &"")
		if cue.is_empty() or seen.has(cue):
			continue
		seen[cue] = true
		cues.append(cue)
	return cues


static func next_call_delay(seed_key: StringName, context: StringName, schedule_tick: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash_seed(seed_key, context, schedule_tick) ^ 0x9E3779B9
	return rng.randf_range(MIN_CALL_INTERVAL_S, MAX_CALL_INTERVAL_S)


static func hash_seed(seed_key: StringName, context: StringName, schedule_tick: int) -> int:
	return hash([String(seed_key), String(context), schedule_tick])


func _should_schedule() -> bool:
	return _audio_enabled and not _context.is_empty()


func _play_species(species: StringName, seed_key: StringName, schedule_tick: int) -> void:
	var player := _first_idle_player()
	if player == null:
		return
	var song := BirdSpecies.song_profile_for(species)
	var stream_path := BirdSpecies.stream_path_for_cue(song.get("cue", &""))
	if stream_path.is_empty():
		return
	var stream := load(stream_path) as AudioStream
	if stream == null:
		return
	player.stream = stream
	player.global_position = _random_voice_position(seed_key, schedule_tick)
	player.volume_db = linear_to_db(_random_volume(seed_key, schedule_tick))
	player.play()


func _random_voice_position(seed_key: StringName, schedule_tick: int) -> Vector3:
	_rng.seed = hash_seed(seed_key, _context, schedule_tick) ^ 0x85EBCA6B
	var angle := _rng.randf() * TAU
	var radius := _rng.randf_range(LISTENER_RADIUS_MIN, LISTENER_RADIUS_MAX)
	var offset := Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
	offset.y = _rng.randf_range(VOICE_HEIGHT_MIN, VOICE_HEIGHT_MAX)
	return _listener_position + offset


func _random_volume(seed_key: StringName, schedule_tick: int) -> float:
	_rng.seed = hash_seed(seed_key, _context, schedule_tick) ^ 0xC2B2AE35
	return clampf(_rng.randf_range(BASE_LINEAR_VOLUME * 0.65, BASE_LINEAR_VOLUME), 0.05, 0.45)


func _first_idle_player() -> AudioStreamPlayer3D:
	for player in _players:
		if not player.playing:
			return player
	return null


func _prune_finished_voices() -> void:
	for player in _players:
		if not player.playing or player.stream == null:
			continue
		if player.get_playback_position() >= player.stream.get_length() - 0.05:
			player.stop()


func _stop_all_voices() -> void:
	for player in _players:
		player.stop()
