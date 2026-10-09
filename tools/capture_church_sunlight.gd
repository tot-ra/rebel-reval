extends SceneTree

## Studio capture of sunlight through church stained glass (R-1451): St Olaf
## and Holy Spirit built at their plan placement with the roof hidden as the
## cutaway does, a shadowed sun at morning, noon and afternoon azimuths, shot
## from inside. Writes sunlight_<church>_<time>.jpg and, with the overlay and
## shafts disabled, sunlight_<church>_noon_off.jpg for comparison.
## tools/godot_render.sh --script tools/capture_church_sunlight.gd -- [out_dir]

const OUT := "res://docs/reports/images/church_interiors"
# Site id, file stem, builder, building node.
const CHURCHES := [
	[&"site.st_olaf", "st_olaf", "res://scripts/city/sites/st_olaf_builder.gd", "Church"],
	[
		&"site.holy_spirit",
		"holy_spirit",
		"res://scripts/city/sites/holy_spirit_builder.gd",
		"Church"
	],
]
# Name, sun elevation and azimuth (degrees; azimuth 0 = towards -z, i.e. north).
const SUNS := [["morning", 24.0, 105.0], ["noon", 46.0, 180.0], ["afternoon", 30.0, 240.0]]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var dir: String = args[0] if args.size() > 0 else OUT
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
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
	env.environment.ambient_light_color = Color(0.5, 0.52, 0.58)
	env.environment.ambient_light_energy = 0.35
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment.glow_enabled = true
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.light_energy = MapViewLighting.SUN_DAY_ENERGY
	sun.light_color = Color(1.0, 0.95, 0.86)
	sun.directional_shadow_max_distance = 120.0
	vp.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 70.0
	cam.far = 300.0
	vp.add_child(cam)
	var plan := CityPlan.load_default()
	for entry: Array in CHURCHES:
		var placed: CitySite = null
		for s: CitySite in plan.sites:
			if s.id == entry[0]:
				placed = s
		var site_node: Node3D = load(entry[2]).build(placed, plan)
		vp.add_child(site_node)
		var building := site_node.get_node(String(entry[3])) as Node3D
		# The cutaway: roof and upper walls hidden, their shadow proxies stay.
		building.get_node("Roof").visible = false
		building.get_node("Upper").visible = false
		var box := _glass_bounds(placed)
		var c := box.get_center()
		var long_x := box.size.x >= box.size.z
		var along := Vector3(1, 0, 0) if long_x else Vector3(0, 0, 1)
		var span := maxf(box.size.x, box.size.z)
		# High in the west end, looking east and down over the nave floor.
		var eye := Vector3(c.x, 7.5, c.z) - along * span * 0.42
		var target := Vector3(c.x, 0.0, c.z) + along * span * 0.12
		for s: Array in SUNS:
			_aim_sun(sun, s[1], s[2])
			await _shot(vp, cam, eye, target, "%s/sunlight_%s_%s.jpg" % [dir, entry[1], s[0]])
		_aim_sun(sun, 46.0, 180.0)
		RenderingServer.global_shader_parameter_set(ChurchSunlight.GLOBAL, Vector4.ZERO)
		building.get_node("SunShafts").visible = false
		await _shot(vp, cam, eye, target, "%s/sunlight_%s_noon_off.jpg" % [dir, entry[1]])
		site_node.queue_free()
		await process_frame
	quit(0)


func _aim_sun(sun: DirectionalLight3D, elevation: float, azimuth: float) -> void:
	var el := deg_to_rad(elevation)
	var az := deg_to_rad(azimuth)
	var toward := Vector3(sin(az) * cos(el), sin(el), -cos(az) * cos(el))
	sun.basis = Basis.looking_at(-toward, Vector3.UP)
	ChurchSunlight.push_light(sun)


func _shot(vp: SubViewport, cam: Camera3D, at: Vector3, target: Vector3, path: String) -> void:
	cam.global_position = at
	cam.look_at(target, Vector3.UP)
	for _f in 10:
		await process_frame
	vp.get_texture().get_image().save_jpg(ProjectSettings.globalize_path(path), 0.88)


## Site-local bounds of the glazed windows (see capture_church_interior.gd).
func _glass_bounds(site: CitySite) -> AABB:
	var box := AABB()
	var found := false
	for w: Dictionary in site.data["fabric"]:
		var a := Vector2(w["a"][0], w["a"][1])
		var d := (Vector2(w["b"][0], w["b"][1]) - a).normalized()
		for op: Dictionary in w.get("openings", []):
			if not bool(op.get("glass", false)):
				continue
			var p := a + d * float(op["s"])
			var sill := float(op.get("sill", 0.12))
			var at := AABB(Vector3(p.x, sill, p.y), Vector3(0.01, 2.0, 0.01))
			box = at if not found else box.merge(at)
			found = true
	return box
