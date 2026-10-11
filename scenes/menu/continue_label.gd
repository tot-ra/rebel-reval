extends "res://scenes/menu/main_menu_entry.gd"

## Main-menu entry that resumes the most recent save (R-1799). SessionState.list_saves() is sorted
## newest first. Hidden when no save exists, so a first launch opens on Start.

var _slot := -1


func _ready() -> void:
	super._ready()
	var saves := SessionState.list_saves()
	_slot = int(saves[0]["slot"]) if not saves.is_empty() else -1
	set_available(_slot >= 0)


func latest_slot() -> int:
	return _slot


func activate() -> void:
	if _slot >= 0:
		resume_save(_slot)
