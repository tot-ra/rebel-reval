extends Control

## Start screen in the R-1698 Escape-menu language (R-1799): a left-aligned column of entries over
## the intro video. Each entry hides itself when unavailable (Continue and Load without saves); this
## script then stacks the visible ones and wires their up/down focus ring, so keyboard and gamepad
## never land on a hidden entry. Entries stay direct children with stable names because the
## packaged walkthrough, platform smoke, capture hosts and tests address them as "Start label" etc.

## Top to bottom. Continue (latest save) leads when a save exists.
const ENTRY_NAMES: Array[String] = [
	"Continue label",
	"Start label",
	"Load label",
	"Credits label",
	"Assets library label",
	"Exit label",
]
## 1920x1080 design space (canvas_items stretch); matches the Escape menu's 300 px column.
const COLUMN_LEFT := 120.0
const COLUMN_WIDTH := 320.0
const LIST_TOP := 440.0
const ENTRY_HEIGHT := 44.0
const ENTRY_SEPARATION := 6.0


func _ready() -> void:
	var entries := visible_entries()
	_stack(entries)
	_wire_focus_ring(entries)
	if not entries.is_empty():
		entries[0].call_deferred("grab_focus")


func visible_entries() -> Array[Control]:
	var entries: Array[Control] = []
	for entry_name in ENTRY_NAMES:
		var entry := get_node_or_null(entry_name) as Control
		if entry != null and entry.visible:
			entries.append(entry)
	return entries


func _stack(entries: Array[Control]) -> void:
	var y := LIST_TOP
	for entry in entries:
		entry.position = Vector2(COLUMN_LEFT, y)
		entry.size = Vector2(COLUMN_WIDTH, ENTRY_HEIGHT)
		y += ENTRY_HEIGHT + ENTRY_SEPARATION


func _wire_focus_ring(entries: Array[Control]) -> void:
	var count := entries.size()
	for index in count:
		var entry := entries[index]
		var above := entries[(index - 1 + count) % count]
		var below := entries[(index + 1) % count]
		entry.focus_neighbor_top = entry.get_path_to(above)
		entry.focus_neighbor_bottom = entry.get_path_to(below)
		entry.focus_previous = entry.focus_neighbor_top
		entry.focus_next = entry.focus_neighbor_bottom
