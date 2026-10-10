extends SceneTree

## Review plates for named NPC dialogue portraits (R-1566). GPU run:
##   tools/godot_render.sh --resolution 1280x720 --script tools/capture_named_npc_dialogue.gd -- \
##     --out=res://docs/reports/images/dialogue
##
## Shows one line per speaker in DialogueUI over a plain backdrop, so the portrait
## resolved through NamedNpcRegistry can be checked against the speaker name.

const DialogueUiScript := preload("res://scripts/dialogue/dialogue_ui.gd")
const DialogueUiReveal := preload("res://scripts/dialogue/dialogue_ui_reveal.gd")
## Registry ids whose portrait file name differs from the id slug.
const LINES: Array[Dictionary] = [
	{"id": &"char.martin_cloaks", "text": "Mind the hem, smith's boy. That wool came from Ghent, and it cost more than your master's anvil."},
	{"id": &"char.burchard_dreileben", "text": "The Order keeps the peace of this town. Remember whose peace it is."},
]


func _init() -> void:
	var out := "res://docs/reports/images/dialogue"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.16, 0.14, 0.12)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(backdrop)
	var ui: CanvasLayer = DialogueUiScript.new()
	root.add_child(ui)
	await _frames(2)

	var registry := NamedNpcRegistry.load_default()
	for line: Dictionary in LINES:
		var id: StringName = line["id"]
		var display_name := String(registry.get_npc(String(id)).get("display_name", ""))
		ui.present_line(id, display_name, String(line["text"]), "capture")
		DialogueUiReveal.complete(ui)
		await _frames(4)
		await _save("%s/named_npc_%s.png" % [out, String(id).trim_prefix("char.")])
	quit()


func _frames(count: int) -> void:
	for i in count:
		await process_frame
		await RenderingServer.frame_post_draw


func _save(path: String) -> void:
	var image := root.get_texture().get_image()
	image.save_png(path)
	print("wrote ", path)
