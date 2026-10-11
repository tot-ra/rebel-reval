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
		elif arg == "--budget":
			_budget()
			quit()
			return
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
			{"variant": i % 3}
		)
		var label := Label3D.new()
		label.text = labels[i]
		label.position = Vector3(x + 0.65, 2.7, 0)
		label.font_size = 36
		label.pixel_size = 0.007
		stage.add_child(label)


## `--door=<id>` picks another entrance; `--view=outside|inside|open` (R-1693).
func _site(site_name: String) -> void:
	var door_id := String(SHOTS.get(site_name, ""))
	var view := "outside"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--door="):
			door_id = arg.trim_prefix("--door=")
		elif arg.begins_with("--view="):
			view = arg.trim_prefix("--view=")
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
			# Same placement as the runtime (portal depth, overlap, shaped head).
			var hang := CityDoors.portal_hang(site, d, floor_y)
			var record := doors._hang(
				String(d["id"]).replace(".", "_"),
				hang["a"],
				hang["b"],
				floor_y,
				d["inward"],
				Details.site_style(d),
				d["paint"],
				hang["height"],
				width > 2.2,
				{"head": hang["head"]}
			)
			if d["id"] != StringName(door_id):
				continue
			if view == "open":
				# Fully open, with the runtime's inward sign and portal angle.
				for hinge: Node3D in record["hinges"]:
					var leaf := hinge.get_child(0) as Node3D
					leaf.rotation.y = CityDoors._inward_sign(hinge, d["inward"]) * hang["angle"]
			var center: Vector2 = (d["a"] + d["b"]) * 0.5
			var side: Vector2 = d["inward"] if view != "outside" else -d["inward"]
			var height := float(hang["head"].y) if hang["head"].y > 0.0 else float(d["height"])
			var target := Vector3(center.x, floor_y + height * 0.5, center.y)
			var eye := target + Vector3(side.x, 0.05, side.y) * maxf(5.5, width * 2.1)
			if view == "open":
				# Three-quarter view from inside shows the leaf against the rear arch.
				var along: Vector2 = (d["b"] - d["a"]).normalized()
				eye = target + Vector3(side.x + along.x * 0.8, 0.1, side.y + along.y * 0.8) * 4.5
			camera.look_at_from_position(eye, target)
			var fill := OmniLight3D.new()
			fill.position = eye + Vector3(1.3, 1.5, 0.5)
			fill.light_energy = 1.5
			fill.omni_range = 12
			viewport.add_child(fill)
		var suffix := ""
		if door_id != String(SHOTS.get(site_name, "")):
			suffix = "_" + door_id.get_slice(".", 2)
		await _save(site_name + suffix + ("" if view == "outside" else "_" + view))
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


## R-1693 full-city budget, headless: every door leaf in the city plus the five
## landmark models built with and without portal masonry (A/B in one run).
## Surfaces approximate draw calls; times are single-run CPU build times.
func _budget() -> void:
	var plan := CityPlan.load_default()
	var t0 := Time.get_ticks_usec()
	var doors := CityDoors.create(plan)
	var doors_ms := (Time.get_ticks_usec() - t0) / 1000.0
	var unique := {}
	var leaves := 0
	var drawn := 0
	for record: Dictionary in doors.doors.values():
		for hinge: Node3D in record["hinges"]:
			var mesh := (hinge.get_child(0) as MeshInstance3D).mesh
			leaves += 1
			drawn += _triangles(mesh)
			unique[mesh] = true
	var cached := 0
	for mesh: Mesh in unique:
		cached += _triangles(mesh)
	var report := {
		"doors": doors.doors.size(),
		"leaves": leaves,
		"leaf_triangles_drawn": drawn,
		"unique_leaf_meshes": unique.size(),
		"unique_leaf_triangles": cached,
		"doors_build_ms": snappedf(doors_ms, 0.1),
		"sites": {},
	}
	doors.free()
	# Portal leaves against flat leaves of the same style cut at the springing.
	var shaped := 0
	var flat := 0
	for site in plan.sites:
		for d: Dictionary in site.doors:
			if not CitySitePortals.PROFILES.has(d["id"]):
				continue
			var hang := CityDoors.portal_hang(site, d, 0.0)
			var w: float = (hang["a"] as Vector2).distance_to(hang["b"])
			w /= 2.0 if (d["a"] as Vector2).distance_to(d["b"]) > 2.2 else 1.0
			var style := Details.site_style(d)
			shaped += _triangles(Details.mesh(style, w, hang["height"], 0, hang["head"]))
			flat += _triangles(Details.mesh(style, w, hang["height"]))
	report["portal_leaf_triangles"] = {"shaped": shaped, "flat": flat}
	# Alternate modes over three rounds; the minimum time drops warm-up cost.
	for site in plan.sites:
		var stats := {}
		for round_index in 3:
			for mode: String in ["without_portals", "with_portals"]:
				if mode == "without_portals":
					for w: Dictionary in site.data.get("fabric", []):
						for op: Dictionary in w.get("openings", []):
							op.erase("portal")
				else:
					CitySitePortals.annotate(site.data)
				var t1 := Time.get_ticks_usec()
				var model: Node3D = load(site.data["visual"]["script"]).call("build", site, plan)
				var ms := (Time.get_ticks_usec() - t1) / 1000.0
				var tris := 0
				var surfaces := 0
				for node in model.find_children("*", "MeshInstance3D", true, false):
					var mesh := (node as MeshInstance3D).mesh
					if mesh != null:
						tris += _triangles(mesh)
						surfaces += mesh.get_surface_count()
				var best: float = stats.get(mode, {}).get("build_ms", INF)
				stats[mode] = {
					"triangles": tris,
					"surfaces": surfaces,
					"build_ms": snappedf(minf(best, ms), 0.1)
				}
				model.free()
		report["sites"][String(site.id)] = stats
	print("DOOR_BUDGET=" + JSON.stringify(report))


func _triangles(mesh: Mesh) -> int:
	# Works for ArrayMesh and primitive meshes alike.
	return mesh.get_faces().size() / 3
