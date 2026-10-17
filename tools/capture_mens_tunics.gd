extends SceneTree

## Twelve census men of mixed rank on a market cobble, dressed through CitizenGear exactly
## as in the city (task R-2023, docs/SYSTEMS/CITIZEN_WARDROBE.md#mens-tunics-r-2023): three
## poor men in homespun short tunics (p1), three middling in broadcloth (p2), three rich in
## the calf-length scarlet tunic (p3) and three rich young men in the buttoned cotehardie.
## Labels give the body outfit, the tunic's variant cell and the trade. Writes the market
## row, a close-up of sleeves and hems, and a back view (seat and slits).
## Requires a rendering run:
##   tools/godot_render.sh --script tools/capture_mens_tunics.gd [-- --output-dir=PATH]

const OUTPUT_DIR := "res://docs/reports/images/characters"
const PER_GROUP := 3
const SPACING := 0.95
const COBBLE := Color(0.36, 0.33, 0.29)
## Layers that hide the tunic; men wearing one are left out of the row.
const COVERING := [
	"gambeson", "mail_haubergeon", "coat_of_plates", "surcoat", "order_mantle", "smith_apron"
]
const EquipmentVariant := preload("res://scripts/city/equipment_variant.gd")


func _initialize() -> void:
	call_deferred("_run")


## Group of a record: poor, middling, rich (long tunic) or cote; "" for anyone else.
func _group(r: Dictionary) -> String:
	var body := String(r.get("body", ""))
	if r.get("sex") != "m" or not body.begins_with("citizen_m_adult") or r.get("duty") is Dictionary:
		return ""
	for entry: String in r.get("wear", []):
		if EquipmentVariant.split(entry)[0] in COVERING:
			return ""  # armour or a surcoat hides the tunic
	if body.ends_with("_c"):
		return "cote"
	return ["poor", "middling", "rich"][CitizenWardrobe.wealth_of(r)]


## PER_GROUP men of each group, spreading over tunic cells and trades.
func _pick() -> Array[Dictionary]:
	var groups := {"poor": [], "middling": [], "rich": [], "cote": []}
	for r: Dictionary in CitizenRoster.load_default().residents:
		var group := _group(r)
		if not group.is_empty():
			(groups[group] as Array).append(r)
	var picked: Array[Dictionary] = []
	for group: String in ["poor", "middling", "rich", "cote"]:
		var seen := {}
		var chosen: Array = []
		for sweep in 2:
			for r: Dictionary in groups[group]:
				if chosen.size() >= PER_GROUP or r in chosen:
					continue
				var key := "%s|%s" % [CitizenWardrobe.tunic_cell(r), String(r.get("body", ""))]
				if sweep == 0 and seen.has(key):
					continue
				seen[key] = true
				chosen.append(r)
		for r: Dictionary in chosen:
			picked.append(r)
	return picked


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(2400, 1000)
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.62, 0.66, 0.7)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.62, 0.66)
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	viewport.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -30, 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	viewport.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30, 30)
	ground.mesh = plane
	var cobble := StandardMaterial3D.new()
	cobble.albedo_color = COBBLE
	cobble.roughness = 0.95
	ground.material_override = cobble
	viewport.add_child(ground)

	var men := _pick()
	var times: Array[float] = []
	for i in men.size():
		var record: Dictionary = men[i].duplicate(true)
		var scene := load("res://assets/characters/variants/%s.tscn" % record["body"]) as PackedScene
		var rig := scene.instantiate() as SharedCharacterRig
		viewport.add_child(rig)
		rig.position = Vector3((i - (men.size() - 1) * 0.5) * SPACING, 0.0, 0.25 * float(i % 2))
		rig.rotation_degrees = Vector3(0, 20 - 40 * float(i % 3) / 2.0, 0)
		var started := Time.get_ticks_usec()
		CityCitizens.dye(rig, record)
		CitizenGear.arm(rig, record)
		times.append(float(Time.get_ticks_usec() - started) / 1000.0)
		var cell := CitizenWardrobe.tunic_cell(record)
		var label := Label3D.new()
		label.text = "%s\n%s\n%s" % [_group(record), cell, record.get("trade", "")]
		label.font_size = 30
		label.pixel_size = 0.004
		label.position = Vector3(0, -0.2, 0.45)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		rig.add_child(label)
		print("MAN ", record["id"], " ", record["body"], " ", cell, " ", record.get("status"), " ",
			record.get("trade"), " ", record.get("wear", []))
	var total := 0.0
	for t in times:
		total += t
	print("dress time per man: %.1f ms" % (total / maxf(1.0, times.size())))
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.6
	camera.position = Vector3(0.0, 1.2, 9.0)
	camera.rotation_degrees = Vector3(-4, 0, 0)
	viewport.add_child(camera)
	camera.current = true
	for _frame in 30:
		await process_frame
	var out := OUTPUT_DIR
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--output-dir="):
			out = a.trim_prefix("--output-dir=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	_save(viewport, out + "/mens_tunics_market.jpg")
	# Close-up of the poor and middling men: elbows, cuffs, hems, patches and buttons.
	camera.size = 2.1
	camera.position = Vector3(-(men.size() - 1) * 0.5 * SPACING + 2.4 * SPACING, 0.95, 9.0)
	for _frame in 4:
		await process_frame
	_save(viewport, out + "/mens_tunics_closeup.jpg")
	# The cotehardie men close up: buttons, low belt, shirt band.
	camera.position = Vector3((men.size() - 1) * 0.5 * SPACING - 1.0 * SPACING, 1.1, 9.0)
	for _frame in 4:
		await process_frame
	_save(viewport, out + "/mens_tunics_cotehardie.jpg")
	# Back view of the row: rubbed seats and side slits.
	camera.size = 4.6
	camera.position = Vector3(0.0, 1.2, -9.0)
	camera.rotation_degrees = Vector3(-4, 180, 0)
	for _frame in 4:
		await process_frame
	_save(viewport, out + "/mens_tunics_back.jpg")
	quit(0)


func _save(viewport: SubViewport, path: String) -> void:
	viewport.get_texture().get_image().save_jpg(ProjectSettings.globalize_path(path), 0.9)
	print("SAVED ", path)
