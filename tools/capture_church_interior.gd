extends SceneTree

## Interior studio capture of the city churches (glazing, walls, furnishings):
## hand-picked Holy Spirit shots, then St Olaf, St Nicholas and St Mary built
## at their compiled plan placement, with shots aimed from the glass bounds.
## tools/godot_render.sh --script tools/capture_church_interior.gd -- [out_dir]

const OUT := "res://docs/reports/images/church_interiors"
const SHOTS := [
	["nave_west", Vector3(4.0, 1.7, -2.0), Vector3(44.0, 3.2, -2.0)],
	["south_windows", Vector3(24.0, 1.6, -6.0), Vector3(24.0, 4.2, 8.0)],
	["choir_east", Vector3(30.0, 1.7, 0.0), Vector3(48.0, 3.0, -3.0)],
]
const CHURCHES := [
	[&"site.st_olaf", "st_olaf", "res://scripts/city/sites/st_olaf_builder.gd"],
	[&"site.st_nicholas", "st_nicholas", "res://scripts/city/sites/st_nicholas_builder.gd"],
	[&"site.st_mary", "st_mary", "res://scripts/city/sites/st_mary_builder.gd"],
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var out := OS.get_cmdline_user_args()
	var dir: String = out[0] if out.size() > 0 else OUT
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var text := FileAccess.get_file_as_string("res://content/world/reval_city/sites/holy_spirit.json")
	var manifest: Dictionary = JSON.parse_string(text)
	var site := CitySite.from_manifest(manifest, {"at": [0, 0], "level": 0.0, "rotation_deg": 0.0})
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.65, 0.8)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.5, 0.5, 0.55)
	env.environment.ambient_light_energy = 0.6
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -30, 0)
	vp.add_child(sun)
	var church: Node3D = load("res://scripts/city/sites/holy_spirit_builder.gd").build(site, null)
	vp.add_child(church)
	var cam := Camera3D.new()
	cam.fov = 65.0
	cam.far = 200.0
	vp.add_child(cam)
	for shot: Array in SHOTS:
		await _shot(vp, cam, shot[1], shot[2], "%s/glazing_%s.png" % [dir, shot[0]])
	church.queue_free()
	var plan := CityPlan.load_default()
	for entry: Array in CHURCHES:
		var placed: CitySite = null
		for s: CitySite in plan.sites:
			if s.id == entry[0]:
				placed = s
		church = load(entry[2]).build(placed, plan)
		vp.add_child(church)
		var box := _glass_bounds(placed)
		var c := box.get_center()
		var size := box.size
		# Stand in the nave, a third back from one long wall, and look at the
		# opposite wall's windows, the other wall's, and down the long axis.
		var across := Vector3(0, 0, 1) if size.x >= size.z else Vector3(1, 0, 0)
		var along := Vector3(1, 0, 0) if size.x >= size.z else Vector3(0, 0, 1)
		var half := (size.z if size.x >= size.z else size.x) * 0.5
		var eye := Vector3(c.x, 1.7, c.z)
		# Aim at the mean window height; step off the bay centre to clear piers.
		var up := Vector3(0, c.y - 1.7, 0)
		var step := along * 1.3
		var shots := [
			["side_a", eye - across * half * 0.1 + step, eye + across * half + up + step],
			["side_b", eye + across * half * 0.1 + step, eye - across * half + up + step],
			["axis", eye - along * maxf(size.x, size.z) * 0.3, eye + along * 40.0 + Vector3(0, 2.0, 0)],
		]
		for shot: Array in shots:
			await _shot(vp, cam, shot[1], shot[2], "%s/glazing_%s_%s.png" % [dir, entry[1], shot[0]])
		church.queue_free()
	quit(0)


func _shot(vp: SubViewport, cam: Camera3D, at: Vector3, target: Vector3, path: String) -> void:
	cam.position = at
	cam.look_at(target, Vector3.UP)
	for _f in 8:
		await process_frame
	vp.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))


## Site-local bounds of the glazed windows, read from the manifest fabric
## (the builder output is in site-local space, floor near y = 0).
func _glass_bounds(site: CitySite) -> AABB:
	var box := AABB()
	var found := false
	for w: Dictionary in site.data["fabric"]:
		var a := Vector2(w["a"][0], w["a"][1])
		var dir := (Vector2(w["b"][0], w["b"][1]) - a).normalized()
		for op: Dictionary in w.get("openings", []):
			if not bool(op.get("glass", false)):
				continue
			var p := a + dir * float(op["s"])
			var sill := float(op.get("sill", 0.12))
			var top := maxf(float(op.get("apex", 0.0)), float(op.get("spring", sill + 2.0)))
			var at := AABB(Vector3(p.x, sill, p.y), Vector3(0.01, top - sill, 0.01))
			box = at if not found else box.merge(at)
			found = true
	return box
