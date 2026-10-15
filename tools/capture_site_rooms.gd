extends SceneTree

## Review capture of furnished landmark-site rooms (ADR 0052): the Holy Spirit
## almshouse sick-room and St Catherine's infirmary, each built by its site
## builder at the compiled plan placement (site-local coordinates). Per room an
## eye-level shot with the ceiling on, and a cutaway with the room's `hide`
## nodes lifted as the runtime does while Kalev is inside (plus the cloister
## walk roof, which would hide the infirmary from the garth side).
## tools/godot_render.sh --script tools/capture_site_rooms.gd -- [out_dir]

const OUT := "res://docs/reports/images/sites"
## Extra nodes lifted for cutaway shots only.
const CUTAWAY_EXTRA := ["Cloister/Roof"]
## [site id, builder, room id, [[name, eye, look, cutaway], ...]]
const ROOMS := [
	[
		&"site.holy_spirit",
		"res://scripts/city/sites/holy_spirit_builder.gd",
		&"room.almshouse",
		[
			["holy_spirit_almshouse_door", Vector3(47.7, 1.65, 5.1), Vector3(38.0, 0.9, 4.4), false],
			["holy_spirit_almshouse_sickbed", Vector3(46.9, 1.7, 3.6), Vector3(43.6, 0.4, 6.9), false],
			["holy_spirit_almshouse_cutaway", Vector3(51.0, 9.5, 13.0), Vector3(43.0, 0.0, 4.6), true],
		],
	],
	[
		&"site.st_catherine",
		"res://scripts/city/sites/st_catherine_builder.gd",
		&"room.infirmary",
		[
			["st_catherine_infirmary_door", Vector3(47.0, 1.65, -44.2), Vector3(50.5, 0.7, -50.6), false],
			["st_catherine_infirmary_cutaway", Vector3(44.5, 11.5, -37.5), Vector3(49.0, 0.0, -48.0), true],
			["st_catherine_infirmary_garth", Vector3(43.2, 3.0, -30.0), Vector3(47.3, 0.9, -43.0), false],
			["st_catherine_infirmary_beds", Vector3(49.5, 1.6, -46.0), Vector3(52.0, 1.0, -51.2), false],
		],
	],
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var out := OS.get_cmdline_user_args()
	var dir: String = out[0] if out.size() > 0 else OUT
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var plan := CityPlan.load_default()
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
	env.environment.ambient_light_color = Color(0.55, 0.53, 0.5)
	env.environment.ambient_light_energy = 0.7
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -40, 0)
	sun.shadow_enabled = true
	vp.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 70.0
	cam.near = 0.05
	cam.far = 250.0
	vp.add_child(cam)
	for entry: Array in ROOMS:
		var site: CitySite = null
		for s: CitySite in plan.sites:
			if s.id == entry[0]:
				site = s
		if site == null:
			push_error("capture_site_rooms: %s not in the plan" % entry[0])
			continue
		var model: Node3D = load(String(entry[1])).call("build", site, plan)
		vp.add_child(model)
		var hide: Array = []
		for r: Dictionary in site.data.get("rooms", []):
			if StringName(r["id"]) == entry[2]:
				hide = r.get("hide", []).duplicate()
		hide.append_array(CUTAWAY_EXTRA)
		for shot: Array in entry[3]:
			_set_hidden(model, hide, bool(shot[3]))
			cam.fov = 55.0 if bool(shot[3]) else 70.0
			await _shot(vp, cam, shot[1], shot[2], "%s/%s.jpg" % [dir, shot[0]])
		model.queue_free()
		await process_frame
	quit(0)


func _set_hidden(model: Node3D, paths: Array, hidden: bool) -> void:
	for p: String in paths:
		var node := model.get_node_or_null(NodePath(p)) as Node3D
		if node != null:
			node.visible = not hidden


func _shot(vp: SubViewport, cam: Camera3D, at: Vector3, target: Vector3, path: String) -> void:
	cam.position = at
	cam.look_at(target, Vector3.UP)
	for _f in 10:
		await process_frame
	vp.get_texture().get_image().save_jpg(ProjectSettings.globalize_path(path), 0.85)
	print("capture_site_rooms: wrote %s" % path)
