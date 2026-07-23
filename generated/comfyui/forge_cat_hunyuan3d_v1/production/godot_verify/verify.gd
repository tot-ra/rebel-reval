extends Node3D

# In-engine verification of the production GLB. Loads the file with GLTFDocument
# (tests the raw asset, not a pre-baked .import), inspects scale/origin/axes/
# materials/skeleton/idle/ground contact/bounds, renders a forge-lit screenshot,
# writes a JSON report and quits. Does NOT touch the shipping cat rig.

# Load the sibling production GLB directly (no duplicated copy in the repo).
var _glb := ProjectSettings.globalize_path("res://").path_join("../forge_cat_production_v1.glb").simplify_path()
var _shot := ProjectSettings.globalize_path("res://").path_join("../previews/godot_preview.png").simplify_path()
const REPORT := "res://godot_verify.json"

var _report := {}

func _ready() -> void:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file(_glb, state)
	_report["import_error_code"] = err
	if err != OK:
		_finish()
		return
	var scene := doc.generate_scene(state)
	if scene == null:
		_report["generate_scene"] = "null"
		_finish()
		return
	add_child(scene)

	# Walk the imported tree.
	var meshes: Array[MeshInstance3D] = []
	var skels: Array[Skeleton3D] = []
	var anims: Array[AnimationPlayer] = []
	_collect(scene, meshes, skels, anims)

	# World AABB across all mesh instances.
	var aabb := AABB()
	var have := false
	var surfaces := 0
	var materials := {}
	for mi in meshes:
		var a := mi.get_aabb()
		var gt := mi.global_transform
		var corners := _aabb_corners(a)
		for c in corners:
			var w: Vector3 = gt * (c as Vector3)
			if not have:
				aabb = AABB(w, Vector3.ZERO); have = true
			else:
				aabb = aabb.expand(w)
		surfaces += mi.mesh.get_surface_count()
		for si in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(si)
			if m == null and mi.get_surface_override_material(si):
				m = mi.get_surface_override_material(si)
			if m:
				materials[m.resource_name if m.resource_name != "" else str(m)] = m.get_class()

	_report["mesh_count"] = meshes.size()
	_report["surfaces"] = surfaces
	_report["materials"] = materials
	_report["skeleton_count"] = skels.size()
	_report["bone_count"] = (skels[0].get_bone_count() if skels.size() > 0 else 0)
	_report["aabb_position"] = _v(aabb.position)
	_report["aabb_size"] = _v(aabb.size)
	_report["aabb_end"] = _v(aabb.end)
	_report["ground_min_y"] = snappedf(aabb.position.y, 0.0001)
	_report["ground_contact_ok"] = absf(aabb.position.y) <= 0.01
	_report["metric_scale_ok"] = aabb.size.x < 1.0 and aabb.size.y < 1.0 and aabb.size.z < 1.0
	_report["longest_axis"] = _longest_axis(aabb.size)

	# Animation checks.
	var anim_info := {}
	if anims.size() > 0:
		var ap := anims[0]
		var list := ap.get_animation_list()
		anim_info["names"] = list
		for n in list:
			var an := ap.get_animation(n)
			anim_info[n] = {"length": snappedf(an.length, 0.001), "loop": an.loop_mode}
		# play idle if present
		var idle_name := ""
		for n in list:
			if String(n).to_lower().ends_with("idle"):
				idle_name = n
		if idle_name != "":
			ap.play(idle_name)
			_report["idle_playing"] = idle_name
	_report["animations"] = anim_info

	_setup_stage(aabb)
	# advance the idle a little then capture
	await get_tree().create_timer(0.6).timeout
	await _capture()
	_finish()

func _collect(n: Node, meshes, skels, anims) -> void:
	if n is MeshInstance3D: meshes.append(n)
	if n is Skeleton3D: skels.append(n)
	if n is AnimationPlayer: anims.append(n)
	for c in n.get_children():
		_collect(c, meshes, skels, anims)

func _aabb_corners(a: AABB) -> Array:
	var p := a.position; var s := a.size
	var r := []
	for x in [0.0, 1.0]:
		for y in [0.0, 1.0]:
			for z in [0.0, 1.0]:
				r.append(p + Vector3(s.x * x, s.y * y, s.z * z))
	return r

func _longest_axis(s: Vector3) -> String:
	if s.x >= s.y and s.x >= s.z: return "x"
	if s.z >= s.x and s.z >= s.y: return "z"
	return "y"

func _v(v: Vector3) -> Array:
	return [snappedf(v.x, 0.0001), snappedf(v.y, 0.0001), snappedf(v.z, 0.0001)]

func _setup_stage(aabb: AABB) -> void:
	var center := aabb.position + aabb.size * 0.5
	# ground plane
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(3, 3)
	ground.mesh = pm
	var gmat := StandardMaterial3D.new(); gmat.albedo_color = Color(0.10, 0.09, 0.085)
	gmat.roughness = 0.95
	ground.material_override = gmat
	add_child(ground)

	# forge-like warm key + dim cool ambient via WorldEnvironment
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.06, 0.05, 0.045)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.28, 0.24, 0.22)
	e.ambient_light_energy = 0.5
	env.environment = e
	add_child(env)

	var key := OmniLight3D.new()
	key.light_color = Color(1.0, 0.72, 0.42)
	key.light_energy = 4.0
	key.omni_range = 6.0
	key.position = center + Vector3(0.5, 0.6, 0.5)
	add_child(key)

	var rim := DirectionalLight3D.new()
	rim.light_color = Color(0.6, 0.68, 0.85)
	rim.light_energy = 0.6
	rim.rotation_degrees = Vector3(-40, 150, 0)
	add_child(rim)

	var cam := Camera3D.new()
	var dist := maxf(aabb.size.x, aabb.size.z) * 2.4 + 0.2
	cam.position = center + Vector3(dist * 0.8, aabb.size.y * 0.9 + 0.12, dist)
	cam.look_at_from_position(cam.position, center, Vector3.UP)
	cam.fov = 40.0
	add_child(cam)
	get_viewport().size = Vector2i(900, 900)

func _capture() -> void:
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(_shot)
	_report["screenshot"] = "previews/godot_preview.png"

func _finish() -> void:
	var f := FileAccess.open(REPORT, FileAccess.WRITE)
	f.store_string(JSON.stringify(_report, "  "))
	f.close()
	print("GODOT_VERIFY=" + JSON.stringify(_report))
	get_tree().quit()
