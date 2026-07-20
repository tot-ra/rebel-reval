@tool
extends EditorPlugin

var _loader: RrmapResourceFormatLoader
var _alignment_workspace: MapAlignmentWorkspace


func _enter_tree() -> void:
	_loader = RrmapResourceFormatLoader.new()
	ResourceLoader.add_resource_format_loader(_loader)
	_alignment_workspace = MapAlignmentWorkspace.new()
	_alignment_workspace.name = "RRMapAlignmentWorkspace"
	_alignment_workspace.hide()
	get_editor_interface().get_editor_main_screen().add_child(_alignment_workspace)


func _exit_tree() -> void:
	if is_instance_valid(_alignment_workspace):
		_alignment_workspace.queue_free()
	_alignment_workspace = null
	# Godot owns custom format loaders for the editor process lifetime. Explicit
	# removal races the 4.7 loader-registry teardown during headless editor quit.
	_loader = null


func _has_main_screen() -> bool:
	return true


func _make_visible(visible: bool) -> void:
	if is_instance_valid(_alignment_workspace):
		_alignment_workspace.visible = visible


func _get_plugin_name() -> String:
	return "Map Alignment"


func _get_plugin_icon() -> Texture2D:
	return get_editor_interface().get_base_control().get_theme_icon("TileMap", "EditorIcons")
