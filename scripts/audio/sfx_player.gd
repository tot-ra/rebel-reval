class_name SfxPlayer
extends Node

## Plays catalog sounds by ID (ADR 0035). Owns variation (anti-repeat pick,
## pitch and volume jitter), voice limits and cooldowns. Sound selection uses
## a private seeded RNG and never touches game state.

const AudioBusServiceScript := preload("res://scripts/settings/audio_bus_service.gd")

var _catalog: SfxCatalog
var _rng := RandomNumberGenerator.new()
## sound_id -> recent stream indices, newest last (anti-repeat window).
var _recent: Dictionary = {}
## sound_id -> msec of last accepted play (cooldown).
var _last_play_msec: Dictionary = {}
## sound_id -> number of players still playing (voice limit).
var _voices: Dictionary = {}


func setup(catalog: SfxCatalog, rng_seed: int = 0) -> void:
	_catalog = catalog
	if rng_seed == 0:
		_rng.randomize()
	else:
		_rng.seed = rng_seed
	_recent.clear()
	_last_play_msec.clear()
	_voices.clear()


## Picks the stream index for a pool, avoiding the last `no_repeat` picks while
## the pool is large enough to allow it. Public so tests can check variation.
func pick_stream_index(sound_id: StringName) -> int:
	var entry := _catalog.get_entry(sound_id)
	var count: int = entry.get("streams", []).size()
	if count <= 1:
		return 0 if count == 1 else -1
	var window: int = mini(int(entry.get("no_repeat", 1)), count - 1)
	var recent: Array = _recent.get(sound_id, [])
	var candidates: Array[int] = []
	for i in count:
		if not recent.has(i):
			candidates.append(i)
	var index: int = candidates[_rng.randi_range(0, candidates.size() - 1)]
	recent.append(index)
	while recent.size() > window:
		recent.pop_front()
	_recent[sound_id] = recent
	return index


## Plays `sound_id`. `position` is a Vector3 for 3d entries, Vector2 for 2d,
## ignored for "none". Returns the created player, or null when the sound is
## unknown, on cooldown, out of voices, or the stream cannot be loaded.
func play(sound_id: StringName, position: Variant = null) -> Node:
	if _catalog == null or not _catalog.has_entry(sound_id):
		push_warning("SfxPlayer: unknown sound id %s" % sound_id)
		return null
	var entry := _catalog.get_entry(sound_id)
	var now := _now_msec()
	var cooldown := int(entry.get("cooldown_ms", 0))
	if cooldown > 0 and now - int(_last_play_msec.get(sound_id, -cooldown)) < cooldown:
		return null
	if int(_voices.get(sound_id, 0)) >= int(entry.get("max_voices", 8)):
		return null
	var index := pick_stream_index(sound_id)
	var stream := load(String(entry["streams"][index])) as AudioStream
	if stream == null:
		return null

	var spatial := String(entry.get("spatial", "none"))
	var player: Node
	var volume_db := float(entry.get("volume_db", 0.0)) + _jitter(float(entry.get("volume_jitter_db", 0.0)))  # gdlint: ignore=max-line-length
	var pitch := 1.0 + _jitter(float(entry.get("pitch_jitter", 0.0)))
	if spatial == "3d":
		var p3 := AudioStreamPlayer3D.new()
		p3.stream = stream
		p3.volume_db = volume_db
		p3.pitch_scale = pitch
		p3.max_distance = float(entry.get("max_distance", 40.0))
		player = p3
	elif spatial == "2d":
		var p2 := AudioStreamPlayer.new()
		p2.stream = stream
		p2.volume_db = volume_db
		p2.pitch_scale = pitch
		player = p2
	else:
		var p := AudioStreamPlayer.new()
		p.stream = stream
		p.volume_db = volume_db
		p.pitch_scale = pitch
		player = p
	AudioBusServiceScript.assign_bus(player, StringName(entry["bus"]))
	add_child(player)
	if player is Node3D and position is Vector3:
		(player as Node3D).position = position
	_last_play_msec[sound_id] = now
	_voices[sound_id] = int(_voices.get(sound_id, 0)) + 1
	player.finished.connect(_on_finished.bind(sound_id, player), CONNECT_ONE_SHOT)
	player.call("play")
	return player


func _on_finished(sound_id: StringName, player: Node) -> void:
	_voices[sound_id] = maxi(int(_voices.get(sound_id, 1)) - 1, 0)
	if is_instance_valid(player):
		player.queue_free()


func _jitter(amount: float) -> float:
	return _rng.randf_range(-amount, amount) if amount > 0.0 else 0.0


func _now_msec() -> int:
	return Time.get_ticks_msec()
