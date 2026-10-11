extends "res://scenes/menu/main_menu_entry.gd"

## Main-menu entry that opens the save list overlay so the player can pick
## a save slot to resume. The label is hidden entirely when no saves exist.

const SaveListOverlay := preload("res://scenes/menu/save_list_overlay.gd")


func _ready() -> void:
	super._ready()
	set_available(not SessionState.list_saves().is_empty())


func activate() -> void:
	# Guard against double-clicks while the overlay is already open.
	if get_tree().get_nodes_in_group("save_list_overlay").size() > 0:
		return

	var overlay: Control = SaveListOverlay.new()
	overlay.add_to_group("save_list_overlay")
	overlay.save_selected.connect(resume_save)
	get_tree().current_scene.add_child(overlay)
