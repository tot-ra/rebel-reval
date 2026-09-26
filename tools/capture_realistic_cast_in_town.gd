extends SceneTree

## ADR 0022 evidence: Kalev and part of the realistic cast in the production
## Lower Town, under the game's own day lighting, from a third-person camera.
## tools/godot_render.sh --resolution 1600x900 --script tools/capture_realistic_cast_in_town.gd

const LowerTownSlice := preload(
	"res://scripts/map/definitions/lower_town/lower_town_slice_definition.gd"
)
const MapBuilder := preload("res://scripts/map/map_builder.gd")
const MapView3D := preload("res://scripts/map/view3d/map_view_3d.gd")
const MapViewBridge := preload("res://scripts/map/view3d/map_view_bridge.gd")
const MapVerification := preload("res://scripts/map/map_verification.gd")

const OUTPUT_DIR := "res://build/realistic_captures/town"
const VIEWPORT_SIZE := Vector2i(1600, 900)
const CAST: Array[Array] = [
	["res://assets/characters/kalev/kalev.tscn", Vector2(0.0, 0.0), 0.0],
	["res://assets/characters/variants/mart.tscn", Vector2(-1.1, 0.5), 30.0],
	["res://assets/characters/variants/aita.tscn", Vector2(1.2, 0.8), -40.0],
	["res://assets/characters/variants/jurgen.tscn", Vector2(2.3, -0.3), -80.0],
	["res://assets/characters/variants/watchman.tscn", Vector2(-2.4, -0.6), 60.0],
	["res://assets/characters/variants/crowd_townswoman_01.tscn", Vector2(0.4, -1.6), 160.0],
]


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var definition := LowerTownSlice.create()
	var centre := (
		MapVerification.anchor_position(definition, &"checkpoint_west")
		+ MapVerification.anchor_position(definition, &"brewery_door")
	) * 0.5
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var view := MapView3D.create(definition, MapBuilder.build(definition), &"day")
	viewport.add_child(view)
	var origin := MapViewBridge.logic_to_world(centre, definition.cell_size, 0.03)
	for entry: Array in CAST:
		var rig := (load(entry[0]) as PackedScene).instantiate() as SharedCharacterRig
		view.add_child(rig)
		var offset: Vector2 = entry[1]
		rig.position = origin + Vector3(offset.x, 0.0, offset.y)
		rig.rotation_degrees.y = float(entry[2])
		rig.play_animation(&"idle", 0.0)
	var camera := view.view_camera()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 45.0
	for shot: Array in [["group", Vector3(1.2, 2.2, -6.5), Vector3(0.2, 1.1, 0.0)],
			["kalev_close", Vector3(0.9, 2.0, 2.6), Vector3(0.0, 1.75, 0.0)]]:
		camera.position = origin + (shot[1] as Vector3)
		camera.look_at(origin + (shot[2] as Vector3), Vector3.UP)
		for _i: int in 24:
			await process_frame
		await RenderingServer.frame_post_draw
		var path := "%s/%s.png" % [OUTPUT_DIR, shot[0]]
		viewport.get_texture().get_image().save_png(path)
		print("CAPTURED ", path)
	quit(0)
