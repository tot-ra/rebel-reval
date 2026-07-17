@tool
extends EditorPlugin

var _loader: RrmapResourceFormatLoader


func _enter_tree() -> void:
	_loader = RrmapResourceFormatLoader.new()
	ResourceLoader.add_resource_format_loader(_loader)


func _exit_tree() -> void:
	# Godot owns custom format loaders for the editor process lifetime. Explicit
	# removal races the 4.7 loader-registry teardown during headless editor quit.
	_loader = null
