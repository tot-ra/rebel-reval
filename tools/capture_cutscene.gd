extends SceneTree

## Review plates for the cutscene player (ADR 0034, R-1317). GPU run:
##   tools/godot_render.sh --resolution 1920x1080 --script tools/capture_cutscene.gd -- \
##     --out=res://docs/reports/images/cutscenes
##
## Captures the first shot of each prologue sequence plus one mid-shot frame, so the
## letterbox, caption, chapter card and speaker plate can be reviewed against the art.

const SEQUENCES: Array[StringName] = [
	&"cutscene.prologue.conquest",
	&"cutscene.prologue.almshouse_dawn",
	&"cutscene.prologue.taken_in",
]
const CONTENT_DIRS: Array[String] = [
	"res://content/cutscenes",
	"res://content/prologue",
	"res://content/examples/valid",
	"res://content/examples/support",
]


func _init() -> void:
	var out := "res://docs/reports/images/cutscenes"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))

	var db := ContentDB.new()
	db.load_from_directories(CONTENT_DIRS)

	for sequence_id: StringName in SEQUENCES:
		var player := CutscenePlayer.new()
		player.auto_continue = false
		root.add_child(player)
		if not player.play_id(db, sequence_id):
			push_error("cannot play %s" % String(sequence_id))
			player.queue_free()
			continue
		var slug := String(sequence_id).replace("cutscene.prologue.", "")
		# Opening frame: chapter card, caption and the first line.
		await _frames(4)
		await _save("%s/%s_open.png" % [out, slug])
		# Mid-sequence frame: a later shot, after the camera move has run.
		player.advance()
		player._process(2.0)
		await _frames(4)
		await _save("%s/%s_mid.png" % [out, slug])
		player.queue_free()
		await _frames(2)
	quit()


func _frames(count: int) -> void:
	for i in count:
		await process_frame
		await RenderingServer.frame_post_draw


func _save(path: String) -> void:
	var image := root.get_texture().get_image()
	image.save_png(path)
	print("wrote ", path)
