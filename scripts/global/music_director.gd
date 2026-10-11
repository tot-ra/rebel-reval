extends Node

signal cycle_progress_changed(progress: float)
signal calendar_date_changed(date: Dictionary)

const AudioBusService := preload("res://scripts/settings/audio_bus_service.gd")
const DayNightCycle := preload("res://scripts/global/day_night_cycle.gd")
const GameCalendarScript := preload("res://scripts/global/game_calendar.gd")
const DEFAULT_VOLUME_DB := -8.0
## At full night the theme plays at 50% linear amplitude (about -6 dB).
const NIGHT_VOLUME_LINEAR := 0.5
const SCENE_THEME_ROUTES: Dictionary = {
	"res://scenes/menu/main_menu.tscn": &"menu",
	"res://scenes/menu/assets_library.tscn": &"menu",
	"res://scenes/reval_east/forge/forge.tscn": &"forge",
	# Seamless city: no scene theme. CityMusicZones picks one from Kalev's position.
	"res://scenes/world/reval_city/reval_city.tscn": &"",
}
## Seconds the old theme takes to fade out while the new one fades in.
const CROSSFADE_SECONDS := 3.0
const MENU_TRACK := "res://music/menu/Menu.mp3"
const FORGE_TRACKS: Array[String] = [
	"res://music/forge/Fireside Tale.mp3",
]
const TOWN_TRACKS: Array[String] = [
	"res://music/revel_east/Apothecary (8).mp3",
	"res://music/revel_east/Apothecary.mp3",
]
const THEME_DAY_DIRS: Dictionary = {
	&"center": "res://music/revel_center/",
	&"raekoda": "res://music/revel_center/raekoda/",
	&"holy_spirit": "res://music/revel_center/holy spirit church/",
	&"north": "res://music/revel_north/",
	&"oleviste": "res://music/revel_north/oleviste/",
	&"monastery": "res://music/revel_east/monastery/",
	&"harbor": "res://music/harbor/",
	&"toompea": "res://music/domberg/day/",
	&"garden": "res://music/garden/day/",
	&"south": "res://music/revel_south/",
	# R-1576: themes restored from archive/music/. `viru` scans the whole
	# revel_east folder for the seamless city, while `town` keeps the two
	# hard-coded slice tracks that the P2-014 soundtrack budget counts.
	&"viru": "res://music/revel_east/",
	&"tavern": "res://music/revel_east/tavern/",
	&"st_mary": "res://music/cathedral_of_saint_mary/day/",
	&"dome_school": "res://music/dome_school/day/",
	# No 1343 city zone: the council apothecary is first recorded in 1422, so
	# this theme waits for an interior fade volume that asks for it.
	&"apothecary": "res://music/revel_center/apotheca/",
}
const THEME_NIGHT_DIRS: Dictionary = {
	# Night at the smithy adds The Smith's Song takes to Fireside Tale.
	&"forge": "res://music/forge/",
	&"toompea": "res://music/domberg/night/",
	&"garden": "res://music/garden/night/",
	&"st_mary": "res://music/cathedral_of_saint_mary/night/",
	&"dome_school": "res://music/dome_school/night/",
}

var _player: AudioStreamPlayer
var _outgoing_player: AudioStreamPlayer
var _fade_in := 1.0
var _fade_out := 0.0
var _active_scene: Node
var _scene_theme := &""
var _zone_theme_override := &""
var _active_theme := &""
var _playing_night := false
var _cycle_active := false
var _cycle_progress := DayNightCycle.DEFAULT_PROGRESS
var _cycle_elapsed_days := 0
var _stream_cache: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.name = "ThemePlayer"
	_player.volume_db = DEFAULT_VOLUME_DB
	AudioBusService.assign_bus(_player, AudioBusService.BUS_MUSIC)
	add_child(_player)
	_outgoing_player = AudioStreamPlayer.new()
	_outgoing_player.name = "OutgoingThemePlayer"
	AudioBusService.assign_bus(_outgoing_player, AudioBusService.BUS_MUSIC)
	add_child(_outgoing_player)
	call_deferred("_sync_with_current_scene")


func _process(delta: float) -> void:
	_step_crossfade(delta)
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


func active_theme_id() -> StringName:
	return _active_theme


func zone_theme_override() -> StringName:
	return _zone_theme_override


func set_zone_theme_override(theme_id: StringName) -> void:
	if theme_id == _zone_theme_override:
		return
	if theme_id.is_empty() or not has_theme(theme_id):
		clear_zone_theme_override()
		return
	_zone_theme_override = theme_id
	_apply_theme(_resolved_theme_id())


func clear_zone_theme_override() -> void:
	if _zone_theme_override.is_empty():
		return
	_zone_theme_override = &""
	_apply_theme(_resolved_theme_id())


func is_theme_playing() -> bool:
	return _player != null and _player.playing


static func has_theme(theme_id: StringName) -> bool:
	return theme_id in [&"menu", &"forge", &"town"] or THEME_DAY_DIRS.has(theme_id)


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
			var day_dir: String = THEME_DAY_DIRS.get(theme_id, "")
			if day_dir.is_empty():
				return PackedStringArray()
			return _discover_tracks_in_dir(day_dir)


static func night_track_paths_for_theme(theme_id: StringName) -> PackedStringArray:
	var night_dir: String = THEME_NIGHT_DIRS.get(theme_id, "")
	if night_dir.is_empty():
		return PackedStringArray()
	return _discover_tracks_in_dir(night_dir)


static func volume_linear_for_day_blend(day_blend: float) -> float:
	return lerpf(NIGHT_VOLUME_LINEAR, 1.0, clampf(day_blend, 0.0, 1.0))


static func volume_db_for_cycle_progress(progress: float) -> float:
	return (
		DEFAULT_VOLUME_DB
		+ linear_to_db(volume_linear_for_day_blend(DayNightCycle.day_blend(progress)))
	)


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


func set_cycle_elapsed_days(elapsed_days: int) -> void:
	var next_days := maxi(elapsed_days, 0)
	if next_days == _cycle_elapsed_days:
		return
	_cycle_elapsed_days = next_days
	calendar_date_changed.emit(current_calendar_date())


func get_cycle_elapsed_days() -> int:
	return _cycle_elapsed_days


## True while a gameplay map is driving the shared day/night clock. Menu
## clears this so a later Start does not inherit a leftover sun angle.
func is_cycle_active() -> bool:
	return _cycle_active


func current_calendar_date() -> Dictionary:
	var session_state := get_node_or_null("/root/SessionState")
	var state: Variant = session_state.get("state") if session_state != null else null
	var base_date: Dictionary = GameCalendarScript.DEFAULT_DATE.duplicate()
	if state != null:
		base_date = GameCalendarScript.date_for_phase(state.get_phase())
	return GameCalendarScript.add_days(base_date, _cycle_elapsed_days)


func announce_calendar_date() -> void:
	calendar_date_changed.emit(current_calendar_date())


func clear_cycle_progress() -> void:
	_cycle_active = false
	_cycle_progress = DayNightCycle.DEFAULT_PROGRESS
	_cycle_elapsed_days = 0
	_refresh_volume()
	_maybe_switch_night_tracks()


func _sync_with_current_scene() -> void:
	var current_scene := get_tree().current_scene
	_active_scene = current_scene
	var scene_path := current_scene.scene_file_path if current_scene != null else ""
	var theme_id := theme_for_scene(scene_path)
	_zone_theme_override = &""
	_scene_theme = theme_id
	if theme_id == &"menu":
		clear_cycle_progress()
	_apply_theme(_resolved_theme_id())


func _resolved_theme_id() -> StringName:
	if not _zone_theme_override.is_empty():
		return _zone_theme_override
	return _scene_theme


func _apply_theme(theme_id: StringName) -> void:
	var use_night := _wants_night_tracks(theme_id)
	if theme_id == _active_theme and use_night == _playing_night and _player.playing:
		return

	_active_theme = theme_id
	_playing_night = use_night
	if theme_id.is_empty():
		_begin_crossfade()
		_player.stop()
		_player.stream = null
		_refresh_volume()
		return

	_begin_crossfade()
	_player.stream = get_theme_stream(theme_id, use_night)
	_player.play()
	_refresh_volume()


func _maybe_switch_night_tracks() -> void:
	if _active_theme.is_empty():
		return
	var want_night := _wants_night_tracks(_active_theme)
	if want_night == _playing_night:
		return
	_apply_theme(_active_theme)


func _wants_night_tracks(theme_id: StringName) -> bool:
	return (
		_cycle_active
		and is_night_period(_cycle_progress)
		and not night_track_paths_for_theme(theme_id).is_empty()
	)


func _update_volume_from_cycle() -> void:
	_refresh_volume()


func _base_volume_db() -> float:
	if _cycle_active:
		return volume_db_for_cycle_progress(_cycle_progress)
	return DEFAULT_VOLUME_DB


func _refresh_volume() -> void:
	var base_db := _base_volume_db()
	_player.volume_db = base_db + linear_to_db(maxf(_fade_in, 0.0001))
	_outgoing_player.volume_db = base_db + linear_to_db(maxf(_fade_out, 0.0001))


func _step_crossfade(delta: float) -> void:
	if _fade_in >= 1.0 and _fade_out <= 0.0:
		return
	var step := delta / CROSSFADE_SECONDS
	_fade_in = minf(_fade_in + step, 1.0)
	_fade_out = maxf(_fade_out - step, 0.0)
	if _fade_out <= 0.0:
		_outgoing_player.stop()
		_outgoing_player.stream = null
	_refresh_volume()


## Hands the running track to the outgoing player so it keeps playing (no seek)
## while it fades out under the incoming theme.
func _begin_crossfade() -> void:
	if not _player.playing:
		_fade_in = 1.0
		return
	var finished := _outgoing_player
	finished.stop()
	_outgoing_player = _player
	_player = finished
	_fade_out = 1.0
	_fade_in = 0.0


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
		_:
			var playlist := AudioStreamPlaylist.new()
			playlist.shuffle = true
			playlist.stream_count = track_paths.size()
			for track_index in range(track_paths.size()):
				playlist.set_list_stream(track_index, load(track_paths[track_index]) as AudioStream)
			return playlist


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
