extends SceneTree

## Review plates for the real-time 3D spirit arena (ADR 0038, SA3D-2): a stand-in room is
## stripped to the disc, the opponent's attack arc is drawn on the floor, then the hero steps
## out of it before impact. GPU run:
##   tools/godot_render.sh --resolution 1280x720 --script tools/capture_spirit_arena_3d.gd -- \
##     --out=res://build/spirit_arena_3d

const DUEL_ID := &"dialogue.test_duel"
## Loaded at run time, not named as classes: the host reaches the SessionState autoload, which
## a --script tool cannot resolve at compile time.
const HOST_PATH := "res://scripts/combat/spirit_arena_host.gd"
const TELEGRAPH_SEC := 1.2


func _initialize() -> void:
	var out := "res://build/spirit_arena_3d"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	# The root enters the tree after _initialize; global transforms need it in.
	await process_frame
	var world := Node3D.new()
	root.add_child(world)
	_build_room(world)
	var camera := Camera3D.new()
	world.add_child(camera)
	# Plain transforms: global_* setters complain while the root is still entering the tree.
	camera.transform = Transform3D.IDENTITY.looking_at(Vector3(0.0, -11.0, -13.0), Vector3.UP)
	camera.position = Vector3(0.0, 11.0, 12.0)
	camera.current = true
	var sun := DirectionalLight3D.new()
	world.add_child(sun)
	sun.rotation_degrees = Vector3(-55.0, 30.0, 0.0)
	var hero := _fighter(world, "Hero", Color(0.85, 0.75, 0.55), Vector3(0.0, 0.0, 1.0))
	var opponent := _fighter(world, "Porter", Color(0.55, 0.25, 0.25), Vector3(0.0, 0.0, -4.0))
	var db: Object = load("res://scripts/content/content_db.gd").new()
	var dirs: Array[String] = ["res://content/examples/valid", "res://content/examples/support"]
	db.call(&"load_from_directories", dirs)
	var host: Node = load(HOST_PATH).new()
	host.get(&"duel").set(&"hero_id", &"char.mart")
	root.add_child(host)
	var keep: Array[Node3D] = [hero, opponent]
	host.call(&"attach_arena", world, Vector3.ZERO, keep, true, hero, opponent)
	host.call(&"open", db, load("res://scripts/state/game_state.gd").new(), DUEL_ID)
	# As callers with a staged actor do: the spirit image looms over the 3D opponent.
	host.call(&"form_view").call(&"track_3d", camera, opponent)
	host.get(&"duel").call(&"tick", TELEGRAPH_SEC * 0.5)
	await _frames(4)
	await _save(out + "/telegraph_arc.png")
	# Step sideways out of the arc; the blow then lands on empty floor.
	hero.position = Vector3(5.0, 0.0, 0.5)
	await _frames(3)
	await _save(out + "/sidestep.png")
	host.call(&"close")
	quit()


## A stand-in hall: walls and a table that the arena must hide indoors.
func _build_room(world: Node3D) -> void:
	var room := Node3D.new()
	room.name = "Room"
	world.add_child(room)
	for spec: Array in [
		[Vector3(0, 1.5, -11), Vector3(24, 3, 0.4)],
		[Vector3(-11, 1.5, 0), Vector3(0.4, 3, 24)],
		[Vector3(3, 0.45, -2), Vector3(2.0, 0.9, 1.0)],
	]:
		var box := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = spec[1]
		box.mesh = mesh
		box.position = spec[0]
		room.add_child(box)


func _fighter(world: Node3D, label: String, color: Color, at: Vector3) -> Node3D:
	var body := Node3D.new()
	body.name = label
	world.add_child(body)
	body.position = at
	var capsule := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.35
	mesh.height = 1.7
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material = mat
	capsule.mesh = mesh
	capsule.position = Vector3(0, 0.85, 0)
	body.add_child(capsule)
	return body


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	print("CAPTURED ", path)
