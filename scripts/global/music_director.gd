extends Node

const SAMPLE_RATE := 11025
const LOOP_SECONDS := 8.0
const DEFAULT_VOLUME_DB := -8.0

const SCENE_THEME_ROUTES: Dictionary = {
	"res://scenes/menu/main_menu.tscn": &"menu",
	"res://scenes/reval_east/forge/forge.tscn": &"forge",
	"res://scenes/reval_east/reval_east.tscn": &"town",
	"res://scenes/reval_center/reval_center.tscn": &"town",
	"res://scenes/reval_north/reval_north.tscn": &"town",
}

const THEME_NOTES: Dictionary = {
	&"menu": [293.66, 349.23, 392.00, 440.00, 392.00, 349.23, 293.66, 261.63],
	&"forge": [220.00, 261.63, 293.66, 261.63, 220.00, 196.00, 220.00, 174.61],
	&"town": [261.63, 293.66, 329.63, 392.00, 349.23, 329.63, 293.66, 246.94],
}

const THEME_ROOTS: Dictionary = {
	&"menu": 73.42,
	&"forge": 55.00,
	&"town": 65.41,
}

const THEME_TEMPOS: Dictionary = {
	&"menu": 60.0,
	&"forge": 80.0,
	&"town": 70.0,
}

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
	return THEME_NOTES.has(theme_id)


func get_theme_stream(theme_id: StringName) -> AudioStreamWAV:
	if not has_theme(theme_id):
		return null
	if not _stream_cache.has(theme_id):
		_stream_cache[theme_id] = _synthesize_theme(theme_id)
	return _stream_cache[theme_id] as AudioStreamWAV


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


func _synthesize_theme(theme_id: StringName) -> AudioStreamWAV:
	var notes: Array = THEME_NOTES[theme_id]
	var root_frequency: float = THEME_ROOTS[theme_id]
	var tempo: float = THEME_TEMPOS[theme_id]
	var sample_count := int(SAMPLE_RATE * LOOP_SECONDS)
	var pcm := PackedByteArray()
	pcm.resize(sample_count * 2)

	for sample_index in sample_count:
		var time := float(sample_index) / SAMPLE_RATE
		var sample := _sample_theme(theme_id, notes, root_frequency, tempo, time)
		# A short edge fade prevents clicks even when a generated oscillator does not
		# complete an exact number of periods at the loop boundary.
		var edge_gain := minf(1.0, minf(time / 0.04, (LOOP_SECONDS - time) / 0.04))
		sample = clampf(sample * edge_gain, -0.92, 0.92)
		pcm.encode_s16(sample_index * 2, int(round(sample * 32767.0)))

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = pcm
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = sample_count
	return stream


func _sample_theme(
	theme_id: StringName,
	notes: Array,
	root_frequency: float,
	tempo: float,
	time: float
) -> float:
	var tau := TAU
	var beat := time * tempo / 60.0
	var note_duration := LOOP_SECONDS / notes.size()
	var note_index := mini(int(time / note_duration), notes.size() - 1)
	var note_time := fmod(time, note_duration)
	var note_frequency: float = notes[note_index]
	var pluck_envelope := exp(-note_time * 2.8)

	var drone := sin(tau * root_frequency * time) * 0.16
	drone += sin(tau * root_frequency * 0.5 * time) * 0.09
	drone += sin(tau * root_frequency * 1.5 * time) * 0.035

	var pluck := sin(tau * note_frequency * note_time)
	pluck += sin(tau * note_frequency * 2.0 * note_time) * 0.28
	pluck += sin(tau * note_frequency * 3.0 * note_time) * 0.10
	pluck *= pluck_envelope * 0.16

	var pulse_time := fmod(beat, 1.0) * 60.0 / tempo
	var pulse := 0.0
	match theme_id:
		&"menu":
			var drum_time := fmod(beat, 4.0) * 60.0 / tempo
			pulse = sin(tau * (72.0 - drum_time * 18.0) * drum_time) * exp(-drum_time * 9.0) * 0.12
		&"forge":
			var hammer_tone := sin(tau * (920.0 - pulse_time * 420.0) * pulse_time)
			pulse = hammer_tone * exp(-pulse_time * 22.0) * 0.14
			pluck *= 0.82
		&"town":
			pulse = sin(tau * 110.0 * pulse_time) * exp(-pulse_time * 13.0) * 0.035

	return drone + pluck + pulse
