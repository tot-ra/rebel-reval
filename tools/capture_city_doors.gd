extends SceneTree

## Isolated actual landmark assemblies, not mock portals. Run minimized via
## tools/godot_render.sh --script tools/capture_city_doors.gd [-- --site=st_olaf]
const OUTPUT := "res://docs/reports/images/city/doors/"
const Details := preload("res://scripts/city/city_door_details.gd")
const SHOTS := {
	"raekoja_plats": &"door.council_hall.north",
	"holy_spirit": &"door.holy_spirit.north",
	"st_olaf": &"door.st_olaf.west",
	"st_nicholas": &"door.st_nicholas.north",
	"st_mary": &"door.st_mary.south",
}
var viewport: SubViewport
var camera: Camera3D
var stage: Node3D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	viewport = SubViewport.new()
	viewport.size = Vector2i(1600, 1200)
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.22, 0.25, 0.28)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.9, 1.0)
	env.ambient_light_energy = 0.7
	var world := WorldEnvironment.new()
	world.environment = env
	viewport.add_child(world)
	camera = Camera3D.new()
	camera.fov = 48
	viewport.add_child(camera)
	camera.current = true
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -25, 0)
	sun.light_energy = 1.3
	viewport.add_child(sun)
	stage = Node3D.new()
	viewport.add_child(stage)
	var site_name := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--site="):
			site_name = arg.trim_prefix("--site=")
	if site_name.is_empty():
		_repertoire()
		camera.look_at_from_position(Vector3(5.65, 2.8, 11.4), Vector3(5.65, 1.35, 0))
		await _save("repertoire")
	else:
		await _site(site_name)
	quit()


func _repertoire() -> void:
	var node := CityDoors.new()
	stage.add_child(node)
	var styles: Array[StringName] = [
		&"rough", &"ledged", &"braced", &"merchant", &"civic", &"ecclesiastical"
	]
	var labels := ["OUTBUILDING", "POOR HOUSE", "MASTER", "MERCHANT", "COUNCIL", "CHURCH"]
	for i in styles.size():
		var x := i * 2.05
		node._hang(
			"sample%d" % i,
			Vector2(x, 0),
			Vector2(x + 1.3, 0),
			0,
			Vector2(0, -1),
			styles[i],
			Details.PAINTS[mini(i / 2, 2)],
			2.4,
			false,
			i % 3
		)
		var label := Label3D.new()
		label.text = labels[i]
		label.position = Vector3(x + 0.65, 2.7, 0)
		label.font_size = 36
		label.pixel_size = 0.007
		stage.add_child(label)


func _site(site_name: String) -> void:
	var plan := CityPlan.load_default()
	for site in plan.sites:
		if String(site.id) != "site." + site_name:
			continue
		var script: Script = load(site.data["visual"]["script"])
		var model: Node3D = script.call("build", site, plan)
		model.transform = site.transform3d()
		stage.add_child(model)
		var doors := CityDoors.new()
		stage.add_child(doors)
		for d: Dictionary in site.doors:
			var floor_y := site.level
			for floor_data: Dictionary in site.floors:
				if floor_data["id"] == d["floor"]:
					floor_y = floor_data["height"]
			var width: float = d["a"].distance_to(d["b"])
			var record := doors._hang(
				String(d["id"]).replace(".", "_"),
				d["a"],
				d["b"],
				floor_y,
				d["inward"],
				Details.site_style(d),
				d["paint"],
				d["height"] - 0.05,
				width > 2.2
			)
			if d["id"] != SHOTS[site_name]:
				continue
			var center: Vector2 = record["center"]
			var outward: Vector2 = -d["inward"]
			var target := Vector3(center.x, floor_y + d["height"] * 0.55, center.y)
			var eye := target + Vector3(outward.x, 0.05, outward.y) * maxf(5.5, width * 2.1)
			camera.look_at_from_position(eye, target)
			var fill := OmniLight3D.new()
			fill.position = eye + Vector3(1.3, 1.5, 0.5)
			fill.light_energy = 1.5
			fill.omni_range = 12
			viewport.add_child(fill)
		await _save(site_name)
		return
	push_error("Unknown door capture site: " + site_name)
	quit(1)


func _save(filename: String) -> void:
	for frame in 14:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := OUTPUT + filename + ".png"
	var error := viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	if error != OK:
		push_error("Cannot write " + path)
		quit(1)
	print("DOOR_CAPTURE=" + path)
