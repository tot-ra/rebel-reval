extends "res://tests/godot/test_case.gd"

## Shared fixtures for MapView3D headless tests split across multiple files.

const SmithyCourtyard := preload("res://scripts/map/smithy_courtyard_definition.gd")
const KalevSmithyDefinition := preload("res://scripts/map/definitions/lower_town/kalev_smithy_definition.gd")
const LowerTownSlice := preload("res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd")
const MapBuilder := preload("res://scripts/map/map_builder.gd")
const PLAYER_SCENE := preload("res://player.tscn")
const DayNightCycle := preload("res://scripts/global/day_night_cycle.gd")
const BuildingWindowLights3D := preload("res://scripts/map/view3d/building_window_lights_3d.gd")


func _view_definitions() -> Array[MapDefinition]:
	return [SmithyCourtyard.create(), LowerTownSlice.create()]


## Free a runtime-backed scene after detaching MultiMesh/ShaderMaterial RIDs.
## WHY: Godot's headless dummy renderer emits ERROR on MultiMesh teardown when
## children leave the tree before a parent can clear materials (DEF-006).
func _free_map_scene(scene_root: Node) -> void:
	if scene_root == null or not is_instance_valid(scene_root):
		return
	MapView3D._strip_geometry_materials(scene_root)
	scene_root.free()
