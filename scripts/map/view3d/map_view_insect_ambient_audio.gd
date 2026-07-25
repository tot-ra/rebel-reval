class_name MapViewInsectAmbientAudio
extends Node

## Continuous positional insect (Orthoptera) stridulation bed for outdoor green
## maps. Unlike MapViewBirdAmbientAudio (discrete calls with silence between),
## insects form a near-continuous carpet: a few looping voices are anchored at
## ground level around the listener and slowly cross-faded and rotated so the
## meadow "hum" never sounds like a single repeating loop. Species and diel
## activity come from MapViewInsectSpecies; habitat gating from map context.
##
## Selection is deterministic (seed + tick) for reproducible tests. This node
## never touches game state - it is presentation only.

const AudioBusService := preload("res://scripts/settings/audio_bus_service.gd")
const InsectSpecies := preload("res://scripts/map/view3d/map_view_insect_species.gd")
const DayNightCycle := preload("res://scripts/global/day_night_cycle.gd")

const MAX_CONCURRENT_VOICES := 3
const BASE_LINEAR_VOLUME := 0.20
## Gain units crossed per second while fading a voice in or out.
const FADE_PER_SECOND := 0.5
const MIN_REFRESH_INTERVAL_S := 8.0
const MAX_REFRESH_INTERVAL_S := 18.0
const LISTENER_RADIUS_MIN := 6.0
const LISTENER_RADIUS_MAX := 20.0
const VOICE_HEIGHT_MIN := 0.3
const VOICE_HEIGHT_MAX := 0.9
const MAX_AUDIBLE_DISTANCE := 40.0

var _players: Array[AudioStreamPlayer3D] = []
var _rng := RandomNumberGenerator.new()
var _audio_enabled := true
var _context := &""
var _seed_key := &""
var _cycle_progress := DayNightCycle.DEFAULT_PROGRESS
var _listener_position := Vector3.ZERO
var _seconds_until_refresh := 0.0
var _refresh_tick := 0


func _ready() -> void:
	for index in MAX_CONCURRENT_VOICES:
		var player := AudioStreamPlayer3D.new()
		player.name = "InsectVoice%d" % index
		player.unit_size = 3.0
		player.max_distance = MAX_AUDIBLE_DISTANCE
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		player.bus = String(AudioBusService.BUS_SFX)
		player.set_meta(&"gain", 0.0)
		player.set_meta(&"target", 0.0)
		player.set_meta(&"age", 0)
		add_child(player)
		_players.append(player)


func set_audio_enabled(enabled: bool) -> void:
	_audio_enabled = enabled
	if not enabled:
		_stop_all_voices()
		_seconds_until_refresh = 0.0


func configure(map_id: StringName, context: StringName) -> void:
	_context = context
	_seed_key = map_id
	_refresh_tick = 0
	_seconds_until_refresh = 0.0
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
	# Fade first so a disabling/context change still resolves smoothly to silence.
	_advance_fades(delta)
	if not _should_schedule():
		for player in _players:
			player.set_meta(&"target", 0.0)
		return
	if delta <= 0.0:
		return
	_seconds_until_refresh -= delta
	if _seconds_until_refresh > 0.0:
		return
	_refresh_one_voice()
	_refresh_tick += 1
	_seconds_until_refresh = next_refresh_delay(_seed_key, _context, _refresh_tick)


func active_voice_count() -> int:
	var count := 0
	for player in _players:
		if player.playing:
			count += 1
	return count


static func matches_stridulation_time(time_tag: StringName, cycle_progress: float) -> bool:
	var hour := DayNightCycle.progress_to_hour(cycle_progress)
	match time_tag:
		InsectSpecies.TIME_WARM_DAY:
			return hour >= 9.0 and hour < 19.0
		InsectSpecies.TIME_DAY_DUSK_NIGHT:
			return hour >= 9.0 or hour < 3.0
		InsectSpecies.TIME_DUSK_NIGHT:
			return hour >= 18.0 or hour < 5.0
		_:
			return true


static func weighted_candidates(context: StringName, cycle_progress: float) -> Array:
	var candidates: Array = []
	if context.is_empty():
		return candidates
	for species in InsectSpecies.ALL_SPECIES:
		var weight := InsectSpecies.spawn_weight(species, context)
		if weight <= 0.0:
			continue
		if not matches_stridulation_time(InsectSpecies.time_tag_for(species), cycle_progress):
			continue
		candidates.append({"species": species, "weight": weight})
	return candidates


static func pick_species(
	seed_key: StringName,
	context: StringName,
	cycle_progress: float,
	refresh_tick: int
) -> StringName:
	var candidates := weighted_candidates(context, cycle_progress)
	if candidates.is_empty():
		return &""
	var rng := RandomNumberGenerator.new()
	rng.seed = hash_seed(seed_key, context, refresh_tick)
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


static func next_refresh_delay(seed_key: StringName, context: StringName, refresh_tick: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash_seed(seed_key, context, refresh_tick) ^ 0x9E3779B9
	return rng.randf_range(MIN_REFRESH_INTERVAL_S, MAX_REFRESH_INTERVAL_S)


static func hash_seed(seed_key: StringName, context: StringName, refresh_tick: int) -> int:
	return hash([String(seed_key), String(context), refresh_tick])


func _should_schedule() -> bool:
	return _audio_enabled and not _context.is_empty()


## Moves every voice's gain toward its target and stops fully faded, retired voices.
func _advance_fades(delta: float) -> void:
	if delta <= 0.0:
		delta = 0.0
	for player in _players:
		var gain := float(player.get_meta(&"gain", 0.0))
		var target := float(player.get_meta(&"target", 0.0))
		if gain < target:
			gain = minf(gain + FADE_PER_SECOND * delta, target)
		elif gain > target:
			gain = maxf(gain - FADE_PER_SECOND * delta, target)
		player.set_meta(&"gain", gain)
		if gain <= 0.001 and target <= 0.0:
			if player.playing:
				player.stop()
			continue
		if not player.playing and player.stream != null:
			player.play()
		player.volume_db = linear_to_db(maxf(gain, 0.0001))


## Rotates the bed by one voice: fill an idle slot, or retire the oldest so the
## next refresh can swap in a different species. Keeps the carpet alive.
func _refresh_one_voice() -> void:
	var species := pick_species(_seed_key, _context, _cycle_progress, _refresh_tick)
	if species.is_empty():
		# Out of season/time: fade the loudest voice out; silence arrives gradually.
		var loudest := _loudest_active_slot()
		if loudest != null:
			loudest.set_meta(&"target", 0.0)
		return
	var slot := _idle_slot()
	if slot == null:
		# All voices busy: retire the oldest, next refresh fills the freed slot.
		var oldest := _oldest_active_slot()
		if oldest != null:
			oldest.set_meta(&"target", 0.0)
		return
	_assign_voice(slot, species)


func _assign_voice(player: AudioStreamPlayer3D, species: StringName) -> void:
	var stream := _looped_stream_for(species)
	if stream == null:
		return
	player.stream = stream
	player.global_position = _random_voice_position()
	player.set_meta(&"species", species)
	player.set_meta(&"gain", 0.0)
	player.set_meta(&"target", _voice_target_gain())
	player.set_meta(&"age", _refresh_tick)
	player.volume_db = linear_to_db(0.0001)
	player.play()


func _looped_stream_for(species: StringName) -> AudioStream:
	var path := InsectSpecies.stream_path_for(species)
	if path.is_empty():
		return null
	var stream := load(path) as AudioStream
	if stream == null:
		return null
	# Duplicate so enabling looping does not mutate the shared cached resource.
	stream = stream.duplicate() as AudioStream
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	return stream


func _voice_target_gain() -> float:
	_rng.seed = hash_seed(_seed_key, _context, _refresh_tick) ^ 0xC2B2AE35
	return clampf(_rng.randf_range(BASE_LINEAR_VOLUME * 0.6, BASE_LINEAR_VOLUME), 0.05, 0.35)


func _random_voice_position() -> Vector3:
	_rng.seed = hash_seed(_seed_key, _context, _refresh_tick) ^ 0x85EBCA6B
	var angle := _rng.randf() * TAU
	var radius := _rng.randf_range(LISTENER_RADIUS_MIN, LISTENER_RADIUS_MAX)
	var offset := Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
	offset.y = _rng.randf_range(VOICE_HEIGHT_MIN, VOICE_HEIGHT_MAX)
	return _listener_position + offset


func _idle_slot() -> AudioStreamPlayer3D:
	for player in _players:
		if not player.playing and float(player.get_meta(&"target", 0.0)) <= 0.0:
			return player
	return null


func _oldest_active_slot() -> AudioStreamPlayer3D:
	var oldest: AudioStreamPlayer3D = null
	var oldest_age := 0x7FFFFFFF
	for player in _players:
		if float(player.get_meta(&"target", 0.0)) <= 0.0:
			continue
		var age := int(player.get_meta(&"age", 0))
		if age < oldest_age:
			oldest_age = age
			oldest = player
	return oldest


func _loudest_active_slot() -> AudioStreamPlayer3D:
	var loudest: AudioStreamPlayer3D = null
	var best := 0.0
	for player in _players:
		var target := float(player.get_meta(&"target", 0.0))
		if target > best:
			best = target
			loudest = player
	return loudest


func _stop_all_voices() -> void:
	for player in _players:
		player.stop()
		player.set_meta(&"gain", 0.0)
		player.set_meta(&"target", 0.0)
