extends SceneTree

const LowerTownSlice := preload(
	"res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd"
)
const MapBuilder := preload("res://scripts/map/map_builder.gd")
const MapViewRuntime := preload("res://scripts/map/view3d/map_view_runtime.gd")
const PLAYER_SCENE := preload("res://player.tscn")


func _init() -> void:
	var scene_root := Node2D.new()
	var map_root := Node2D.new()
	var actors := Node2D.new()
	var player := PLAYER_SCENE.instantiate() as CharacterBody2D
	scene_root.add_child(map_root)
	scene_root.add_child(actors)
	actors.add_child(player)
	root.add_child(scene_root)
	var definition := LowerTownSlice.create()
	var bootstrap := {
		"definition": definition,
		"grid": MapBuilder.build(definition),
		"assembled": {"buildings": [], "props": []},
	}
	var runtime := MapViewRuntime.install(scene_root, bootstrap, map_root, player)
	var controller := runtime._camera_controller
	var camera := runtime.view.view_camera()
	var rig := runtime.get_node("PlayerRig")
	print(
		"rig=", rig.position, " camera=", camera.position, " target=", controller._follow_target()
	)
	print(
		"occluders=",
		runtime.view._occluder_bounds.size,
		" player_inside=",
		runtime.view.is_point_inside_occluder(rig.position)
	)
	var buildings := runtime.view.get_node_or_null("Buildings") as Node3D
	if buildings != null and buildings.get_child_count() > 0:
		var first_building := buildings.get_child(0) as Node3D
		var first_aabb := first_building.global_transform * first_building.get_aabb()
		print(
			"first=",
			first_building.name,
			" pos=",
			first_building.global_position,
			" aabb=",
			first_aabb
		)
		camera.position = first_building.global_position + Vector3.UP
		print(
			"manual_inside=",
			runtime.view.is_point_inside_occluder(camera.position),
			" shared=",
			controller._camera_and_player_share_occluder()
		)
		print("pre_target=", controller._follow_target(), " pre_camera=", camera.position)
		controller.follow_player(true, 0.0)
		print(
			"post_camera=",
			camera.position,
			" post_inside=",
			runtime.view.is_point_inside_occluder(camera.position),
			" shared=",
			controller._camera_and_player_share_occluder()
		)
	quit()
