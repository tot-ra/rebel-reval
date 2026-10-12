extends SceneTree

## R-1760 review plates: roof courses, verge boards, quoins and plinths round
## Kalev's smithy, with fixed cameras so before/after runs line up.
##   tools/godot_render.sh --script tools/capture_roof_courses.gd [-- --tag=after --out=res://build/x --moss=0]
## Output: <out>/roof_courses_<shot>_<tag>.png (default build/roof_courses).

const VIEWPORT_SIZE := Vector2i(1600, 900)
const DAY_PROGRESS := 0.42
const SITE_ID := "site.kalev_smithy"

var _tag := "after"
var _output_dir := "res://build/roof_courses"
var _moss := -1.0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tag="):
			_tag = arg.substr(6)
		if arg.begins_with("--out="):
			_output_dir = arg.substr(6)
		if arg.begins_with("--moss="):
			_moss = float(arg.substr(7))
	call_deferred("_run")


func _shots(plan: CityPlan) -> Array[Dictionary]:
	var shots: Array[Dictionary] = []
	for site in plan.sites:
		if String(site.id) != SITE_ID:
			continue
		var c := site.bounds().get_center()
		var y := site.level
		# The forge street as the manifest's review shot frames it.
		for v: Dictionary in site.data.get("review_shots", []):
			if String(v["id"]) != "street":
				continue
			var e := site.to_world(Vector2(v["eye"][0], v["eye"][2]))
			var l := site.to_world(Vector2(v["look"][0], v["look"][2]))
			shots.append({
				"name": "forge_street",
				"eye": Vector3(e.x, y + float(v["eye"][1]), e.y),
				"look": Vector3(l.x, y + float(v["look"][1]), l.y), "fov": 62.0,
			})
		# Oblique aerials over the Lower Town roofs round the smithy (painted-iso
		# pitch, and a closer one where single courses must read).
		shots.append({
			"name": "aerial", "eye": Vector3(c.x + 34.0, y + 40.0, c.y + 40.0),
			"look": Vector3(c.x, y + 3.0, c.y), "fov": 50.0,
		})
		shots.append({
			"name": "roofs_close", "eye": Vector3(c.x - 16.0, y + 17.0, c.y + 18.0),
			"look": Vector3(c.x - 4.0, y + 6.0, c.y + 2.0), "fov": 55.0,
		})
	return shots


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output_dir))
	var plan := CityPlan.load_default()
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world := CityWorld3D.create(plan)
	viewport.add_child(world)
	var camera := Camera3D.new()
	camera.far = 6000.0
	camera.near = 0.15
	viewport.add_child(camera)
	camera.current = true
	world.setup_lighting(camera)
	world.apply_time(DAY_PROGRESS)
	if _moss >= 0.0:
		# Review aid: override roof moss on the shared shingle and thatch materials.
		for family: StringName in [&"shingle", &"thatch"]:
			(CityBuildingBuilder.roof_material(family) as ShaderMaterial).set_shader_parameter("moss", _moss)
	var shots := _shots(plan)
	if shots.is_empty():
		push_error("%s not in the plan" % SITE_ID)
		quit(1)
		return
	for shot in shots:
		camera.fov = shot["fov"]
		camera.look_at_from_position(shot["eye"], shot["look"], Vector3.UP)
		world.apply_time(DAY_PROGRESS)
		# Enough frames for chunk streaming round the new eye to settle.
		for i in 40:
			await process_frame
		var path := "%s/roof_courses_%s_%s.png" % [_output_dir, shot["name"], _tag]
		viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
		print("captured %s" % path)
	quit(0)
