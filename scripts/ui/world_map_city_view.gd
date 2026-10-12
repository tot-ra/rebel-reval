class_name WorldMapCityView
extends "res://scripts/ui/world_map_global_view.gd"

## Reval fast-travel map owned by WorldMapOverlay. It is the Estonia map's
## presentation (full-bleed painted basemap, round markers, names on hover or
## focus, a traveler who walks the road before the jump) laid over the painted
## town, with the key places of the seamless city (ADR 0031) as markers.
## The parent class owns all behavior; this one only supplies the Reval data.

var _origin_place_id: StringName = &""


## `origin_place_id` is the place nearest to the player ("you are here"); empty
## when the player is outside the city or its position is unknown.
func configure_city(
	current_scene_id: StringName, travelable: Dictionary, origin_place_id: StringName
) -> void:
	_origin_place_id = origin_place_id
	configure(current_scene_id, travelable)


func help_text() -> String:
	return ""


func _map_node_name() -> String:
	return "RevalMap"


func _close_button_name() -> String:
	return "CityCloseButton"


# Same prefix the retired button graph used, so Node_<place id> lookups still work.
func _node_prefix() -> String:
	return "Node_"


func _map_texture() -> Texture2D:
	return load("res://assets/UI/reval_city_map.jpg") as Texture2D


func _marker_ids() -> Array:
	var ids: Array = []
	for place in WorldMapGraph.CITY_PLACES:
		if WorldMapGraph.city_place_discovered(place):
			ids.append(place["id"])
	return ids


func _marker_row(scene_id: StringName) -> Dictionary:
	return {"display_name": LocationHud.display_name_for_scene(scene_id), "blurb": ""}


func _is_planned_marker(_scene_id: StringName) -> bool:
	return false


func _has_marker_position(scene_id: StringName) -> bool:
	return WorldMapGraph.is_city_place(scene_id)


func _marker_normalized(scene_id: StringName) -> Vector2:
	return WorldMapGraph.city_place_map_position(scene_id)


func _origin_marker_id() -> StringName:
	return _origin_place_id


func _is_current_marker(scene_id: StringName) -> bool:
	return not _origin_place_id.is_empty() and scene_id == _origin_place_id
