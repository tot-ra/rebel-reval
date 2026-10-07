class_name CutsceneSceneHost
extends Node
## Standalone scene wrapper around CutscenePlayer (ADR 0034), so a cutscene can be a
## `change_scene_to_file` target (New Game, menu replay) without each sequence needing
## its own script. Set `sequence_id` in the scene; the record's `next` block decides
## what runs afterwards.

## Content ID of the cutscene to play, e.g. cutscene.prologue.conquest.
@export var sequence_id: StringName = &""
## Scene to fall back to when the record is missing, so a content error never strands
## the player on an empty screen.
@export_file("*.tscn") var fallback_scene_path: String = ""

var player: CutscenePlayer


func _ready() -> void:
	player = CutscenePlayer.new()
	add_child(player)
	if player.play_id(SessionState.content_db, sequence_id):
		return
	push_warning("Cutscene %s could not be played; using the fallback scene" % String(sequence_id))
	if not fallback_scene_path.is_empty():
		get_tree().change_scene_to_file(fallback_scene_path)
