class_name MapMusicZoneBinder
extends Node

## Switches MusicDirector to authored sub-location themes while the player
## stands inside map fade volumes tagged with `music_theme`.

const MusicDirectorScript := preload("res://scripts/global/music_director.gd")

var _definition: MapDefinition
var _player: CharacterBody2D
var _active_zone_theme := &""


func configure(definition: MapDefinition, player: CharacterBody2D) -> void:
	_definition = definition
	_player = player
	_active_zone_theme = &""
	set_process(true)


func _process(_delta: float) -> void:
	if _definition == null or _player == null:
		return
	var music_director := get_node_or_null("/root/MusicDirector")
	if music_director == null:
		return

	var next_theme := _theme_at_player_position()
	if next_theme == _active_zone_theme:
		return
	_active_zone_theme = next_theme
	if next_theme.is_empty():
		music_director.clear_zone_theme_override()
	else:
		music_director.set_zone_theme_override(next_theme)


func _theme_at_player_position() -> StringName:
	if _definition.fade_volumes.is_empty():
		return &""

	var player_position := _player.global_position
	for volume in _definition.fade_volumes:
		var theme_id: Variant = volume.get("music_theme", &"")
		if theme_id is StringName and theme_id.is_empty():
			continue
		if not theme_id is StringName:
			continue
		if not MusicDirectorScript.has_theme(theme_id):
			continue
		var rect: Variant = volume.get("rect")
		if rect is Rect2 and rect.has_point(player_position):
			return theme_id
	return &""
