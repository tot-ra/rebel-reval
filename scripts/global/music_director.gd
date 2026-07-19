extends Node

const DayNightCycle := preload("res://scripts/global/day_night_cycle.gd")
const GameCalendarScript := preload("res://scripts/global/game_calendar.gd")

const DEFAULT_VOLUME_DB := -8.0
## At full night the theme plays at 50% linear amplitude (about -6 dB).
const NIGHT_VOLUME_LINEAR := 0.5

const SCENE_THEME_ROUTES: Dictionary = {
	"res://scenes/menu/main_menu.tscn": &"menu",
	"res://scenes/reval_east/forge/forge.tscn": &"forge",
	"res://scenes/reval_east/reval_east.tscn": &"town",
}

const MENU_TRACK := "res://music/menu/Menu.mp3"

const FORGE_TRACKS: Array[String] = [
	"res://music/forge/Fireside Tale.mp3",
	"res://music/forge/The Smith's Song2.mp3",
	"res://music/forge/The Smith's Song.mp3",
]

const TOWN_TRACKS: Array[String] = [
	"res://music/revel_east/Apothecary (1).mp3",
	"res://music/revel_east/Apothecary (2).mp3",
	"res://music/revel_east/Apothecary (3).mp3",
	"res://music/revel_east/Apothecary (6).mp3",
	"res://music/revel_east/Apothecary (7).mp3",
	"res://music/revel_east/Apothecary (8).mp3",
	"res://music/revel_east/Apothecary (9).mp3",
	"res://music/revel_east/Apothecary.mp3",
	"res://music/revel_east/streets2.mp3",
	"res://music/revel_east/streets.mp3",
	"res://music/revel_east/The Shaman's Trance.mp3",
	"res://music/revel_east/The Shaman's Trance (1).mp3",
]

const THEME_NIGHT_DIRS: Dictionary = {
	&"forge": "res://music/forge/night/",
	&"town": "res://music/revel_east/night/",
}

signal cycle_progress_changed(progress: float)
signal calendar_date_changed(date: Dictionary)

var _player: AudioStreamPlayer
var _active_scene: Node
var _active_theme := &""
var _playing_night := false
var _cycle_active := false
var _cycle_progress := DayNightCycle.DEFAULT_PROGRESS
var _stream_cache: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.name = "ThemePlayer"
	_player.volume_db = DEFAULT_VOLUME_DB
	add_child(_player)
	call_deferred("_sync_with_current_scene")


func _process(_delta: float) -> void:
	var current_scene := get_tree().current_scene
	# SceneTree can briefly expose no current scene during a deferred transition.
	# Keep the previous track alive so navigation does not create audible gaps.
	if current_scene == null or current_scene == _active_scene:
		_update_volume_from_cycle()
		return

	_active_scene = current_scene
	_sync_with_current_scene()


static func theme_for_scene(scene_path: String) -> StringName:
	return SCENE_THEME_ROUTES.get(scene_path, &"") as StringName


static func has_theme(theme_id: StringName) -> bool:
	return theme_id in [&"menu", &"forge", &"town"]


static func theme_track_paths(theme_id: StringName, use_night: bool = false) -> PackedStringArray:
	if use_night:
		var night_paths := night_track_paths_for_theme(theme_id)
		if not night_paths.is_empty():
			return night_paths
	return day_track_paths_for_theme(theme_id)


static func day_track_paths_for_theme(theme_id: StringName) -> PackedStringArray:
	match theme_id:
		&"menu":
			return PackedStringArray([MENU_TRACK])
		&"forge":
			return PackedStringArray(FORGE_TRACKS)
		&"town":
			return PackedStringArray(TOWN_TRACKS)
		_:
			return PackedStringArray()


static func night_track_paths_for_theme(theme_id: StringName) -> PackedStringArray:
	var night_dir: String = THEME_NIGHT_DIRS.get(theme_id, "")
	if night_dir.is_empty():
		return PackedStringArray()
	return _discover_tracks_in_dir(night_dir)


static func volume_linear_for_day_blend(day_blend: float) -> float:
	return lerpf(NIGHT_VOLUME_LINEAR, 1.0, clampf(day_blend, 0.0, 1.0))


static func volume_db_for_cycle_progress(progress: float) -> float:
	return DEFAULT_VOLUME_DB + linear_to_db(volume_linear_for_day_blend(DayNightCycle.day_blend(progress)))


static func is_night_period(progress: float) -> bool:
	return DayNightCycle.day_blend(progress) < 0.5


func get_theme_stream(theme_id: StringName, use_night: bool = false) -> AudioStream:
	if not has_theme(theme_id):
		return null
	var cache_key := _stream_cache_key(theme_id, use_night)
	if not _stream_cache.has(cache_key):
		_stream_cache[cache_key] = _build_theme_stream(theme_id, use_night)
	return _stream_cache[cache_key] as AudioStream


func set_cycle_progress(progress: float) -> void:
	_cycle_active = true
	_cycle_progress = wrapf(progress, 0.0, 1.0)
	cycle_progress_changed.emit(_cycle_progress)
	_update_volume_from_cycle()
	_maybe_switch_night_tracks()


func get_cycle_progress() -> float:
	return _cycle_progress


func current_calendar_date() -> Dictionary:
	if SessionState.state == null:
		return GameCalendarScript.DEFAULT_DATE.duplicate()
	return GameCalendarScript.date_for_phase(SessionState.state.get_phase())


func announce_calendar_date() -> void:
	calendar_date_changed.emit(current_calendar_date())


func clear_cycle_progress() -> void:
	_cycle_active = false
	_cycle_progress = DayNightCycle.DEFAULT_PROGRESS
	_player.volume_db = DEFAULT_VOLUME_DB
	_maybe_switch_night_tracks()


func _sync_with_current_scene() -> void:
	var current_scene := get_tree().current_scene
	_active_scene = current_scene
	var scene_path := current_scene.scene_file_path if current_scene != null else ""
	var theme_id := theme_for_scene(scene_path)
	if theme_id == &"menu":
		clear_cycle_progress()
	_apply_theme(theme_id)


func _apply_theme(theme_id: StringName) -> void:
	var use_night := _wants_night_tracks(theme_id)
	if theme_id == _active_theme and use_night == _playing_night and _player.playing:
		return

	_active_theme = theme_id
	_playing_night = use_night
	if theme_id.is_empty():
		_player.stop()
		_player.stream = null
		return

	_player.stream = get_theme_stream(theme_id, use_night)
	_player.play()


func _maybe_switch_night_tracks() -> void:
	if _active_theme.is_empty():
		return
	var want_night := _wants_night_tracks(_active_theme)
	if want_night == _playing_night:
		return
	_apply_theme(_active_theme)


func _wants_night_tracks(theme_id: StringName) -> bool:
	return _cycle_active and is_night_period(_cycle_progress) and not night_track_paths_for_theme(theme_id).is_empty()


func _update_volume_from_cycle() -> void:
	if not _cycle_active:
		return
	_player.volume_db = volume_db_for_cycle_progress(_cycle_progress)


func _build_theme_stream(theme_id: StringName, use_night: bool) -> AudioStream:
	var track_paths := theme_track_paths(theme_id, use_night)
	match theme_id:
		&"menu":
			return _load_looping_mp3(MENU_TRACK)
		&"forge":
			var randomizer := AudioStreamRandomizer.new()
			randomizer.streams_count = track_paths.size()
			for track_index in range(track_paths.size()):
				randomizer.set_stream(track_index, load(track_paths[track_index]) as AudioStream)
			return randomizer
		&"town":
			var playlist := AudioStreamPlaylist.new()
			playlist.shuffle = true
			playlist.stream_count = track_paths.size()
			for track_index in range(track_paths.size()):
				playlist.set_list_stream(track_index, load(track_paths[track_index]) as AudioStream)
			return playlist
		_:
			return null


func _load_looping_mp3(path: String) -> AudioStream:
	var stream := load(path) as AudioStream
	if stream is AudioStreamMP3:
		stream.loop = true
	return stream


static func _discover_tracks_in_dir(path: String) -> PackedStringArray:
	var tracks: Array[String] = []
	var dir := DirAccess.open(path)
	if dir == null:
		return PackedStringArray()
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".mp3"):
			tracks.append(path.path_join(file_name))
		file_name = dir.get_next()
	dir.list_dir_end()
	tracks.sort()
	return PackedStringArray(tracks)


static func _stream_cache_key(theme_id: StringName, use_night: bool) -> String:
	return "%s:%s" % [theme_id, "night" if use_night else "day"]
