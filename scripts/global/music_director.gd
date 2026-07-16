extends Node

const DEFAULT_VOLUME_DB := -8.0

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

var _player: AudioStreamPlayer
var _active_scene: Node
var _active_theme := &""
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
		return

	_active_scene = current_scene
	_sync_with_current_scene()


static func theme_for_scene(scene_path: String) -> StringName:
	return SCENE_THEME_ROUTES.get(scene_path, &"") as StringName


static func has_theme(theme_id: StringName) -> bool:
	return theme_id in [&"menu", &"forge", &"town"]


static func theme_track_paths(theme_id: StringName) -> PackedStringArray:
	match theme_id:
		&"menu":
			return PackedStringArray([MENU_TRACK])
		&"forge":
			return PackedStringArray(FORGE_TRACKS)
		&"town":
			return PackedStringArray(TOWN_TRACKS)
		_:
			return PackedStringArray()


func get_theme_stream(theme_id: StringName) -> AudioStream:
	if not has_theme(theme_id):
		return null
	if not _stream_cache.has(theme_id):
		_stream_cache[theme_id] = _build_theme_stream(theme_id)
	return _stream_cache[theme_id] as AudioStream


func _sync_with_current_scene() -> void:
	var current_scene := get_tree().current_scene
	_active_scene = current_scene
	var scene_path := current_scene.scene_file_path if current_scene != null else ""
	_apply_theme(theme_for_scene(scene_path))


func _apply_theme(theme_id: StringName) -> void:
	if theme_id == _active_theme and _player.playing:
		return

	_active_theme = theme_id
	if theme_id.is_empty():
		_player.stop()
		_player.stream = null
		return

	_player.stream = get_theme_stream(theme_id)
	_player.play()


func _build_theme_stream(theme_id: StringName) -> AudioStream:
	match theme_id:
		&"menu":
			return _load_looping_mp3(MENU_TRACK)
		&"forge":
			var randomizer := AudioStreamRandomizer.new()
			randomizer.streams_count = FORGE_TRACKS.size()
			for track_index in range(FORGE_TRACKS.size()):
				randomizer.set_stream(track_index, load(FORGE_TRACKS[track_index]) as AudioStream)
			return randomizer
		&"town":
			var playlist := AudioStreamPlaylist.new()
			playlist.shuffle = true
			playlist.stream_count = TOWN_TRACKS.size()
			for track_index in range(TOWN_TRACKS.size()):
				playlist.set_list_stream(track_index, load(TOWN_TRACKS[track_index]) as AudioStream)
			return playlist
		_:
			return null


func _load_looping_mp3(path: String) -> AudioStream:
	var stream := load(path) as AudioStream
	if stream is AudioStreamMP3:
		stream.loop = true
	return stream
