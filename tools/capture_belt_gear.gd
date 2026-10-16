extends SceneTree

## Belt gear plate (task R-2033, docs/SYSTEMS/EQUIPMENT_VARIANTS.md "Belt gear"): census
## residents of each prestige, dressed exactly as in the city (CityCitizens.dye +
## CitizenGear.arm): a p1 labourer and servant, p2 burghers (a wife with her keys), p3 patricians
## (a man with the mounted belt, a wife with amber or coral beads). Writes a full-figure
## row and a sheet of close-ups of each belt from the front and from the purse side.
## Requires a rendering run:
##   tools/godot_render.sh --script tools/capture_belt_gear.gd [-- --output-dir=PATH]

const BeltGear := preload("res://scripts/city/belt_gear.gd")
const CENSUS := "res://content/world/reval_city/citizens.json"
const OUTPUT_DIR := "res://docs/reports/images/equipment"
const SPACING := 1.1
const TILE := 480
## [label, sex, prestige, layer the pick must wear ("" = none needed)]
const PICKS := [
	["p1 labourer", "m", 1, ""],
	["p1 servant", "f", 1, ""],
	["p2 master", "m", 2, ""],
	["p2 wife, keys", "f", 2, "keys"],
	["p3 patrician", "m", 3, ""],
	["p3 wife, beads", "f", 3, "paternoster"],
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var records := _pick(_census())
	var viewport := SubViewport.new()
	viewport.size = Vector2i(2200, 1000)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.57, 0.6)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.74)
	viewport.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -25, 0)
	viewport.add_child(sun)
	var rigs: Array[SharedCharacterRig] = []
	for i in records.size():
		var record: Dictionary = records[i]
		var scene := load("res://assets/characters/variants/%s.tscn" % record["body"]) as PackedScene
		var rig := scene.instantiate() as SharedCharacterRig
		viewport.add_child(rig)
		rig.position = Vector3((i - (records.size() - 1) * 0.5) * SPACING, 0.0, 0.0)
		rigs.append(rig)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.6
	camera.position = Vector3(0.0, 1.0, 6.0)
	viewport.add_child(camera)
	camera.current = true
	for _frame in 4:
		await process_frame
	for i in records.size():
		var record: Dictionary = records[i]
		CityCitizens.dye(rigs[i], record)
		CitizenGear.arm(rigs[i], record)
		var label := Label3D.new()
		label.text = String(PICKS[i][0]).replace(", ", "\n")
		label.font_size = 30
		label.pixel_size = 0.004
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = Vector3(0, -0.14, 0.3)
		rigs[i].add_child(label)
		var gear := rigs[i].skeleton().get_node_or_null(NodePath(BeltGear.NODE_NAME))
		var parts: Array[String] = []
		if gear != null:
			for node: Node in gear.find_children("*", "Node3D", true, false):
				if node.has_meta(&"variant"):
					parts.append(String(node.get_meta(&"variant")))
		print("belt pick: %s %s %s cell=%s parts=%s" % [
			PICKS[i][0], record["id"], record["wear"], BeltGear.cell_of(record), parts
		])
	for _frame in 8:
		await process_frame
	var out := OUTPUT_DIR
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--output-dir="):
			out = a.trim_prefix("--output-dir=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	for rig in rigs:
		rig.rotation_degrees = Vector3(0, -20, 0)
	for _frame in 3:
		await process_frame
	_save(viewport.get_texture().get_image(), out + "/belt_gear_row.png")
	# Close-ups: front three-quarter (buckle, strap-end, keys) over the purse side, per pick.
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 30.0
	viewport.size = Vector2i(TILE, TILE)
	var sheet := Image.create(TILE * rigs.size(), TILE * 2, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.55, 0.57, 0.6))
	for i in rigs.size():
		for row in 2:
			rigs[i].rotation_degrees = Vector3(0, 20.0 if row == 0 else -75.0, 0)
			var focus := rigs[i].global_transform * Vector3(0.0, 0.88, 0.0)
			camera.position = focus + Vector3(0.0, 0.1, 0.95)
			camera.look_at(focus)
			for _frame in 3:
				await process_frame
			var tile := viewport.get_texture().get_image()
			tile.convert(Image.FORMAT_RGBA8)
			sheet.blit_rect(tile, Rect2i(Vector2i.ZERO, tile.get_size()), Vector2i(i * TILE, row * TILE))
	_save(sheet, out + "/belt_gear_closeup.png")
	quit(0)


func _census() -> Array:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(CENSUS))
	return (data as Dictionary).get("residents", []) if data is Dictionary else []


## First adult per PICKS row by sex, prestige and layer, with no apron or armour over the belt.
func _pick(residents: Array) -> Array:
	var picked: Array = []
	for pick: Array in PICKS:
		for record: Dictionary in residents:
			if record in picked or String(record.get("sex", "")) != pick[1]:
				continue
			if int(record.get("age", 0)) < 20 or BeltGear.prestige_of(record) != int(pick[2]):
				continue
			var layers := BeltGear._layers(record)
			if BeltGear._covered(layers) or BeltGear._aproned(layers):
				continue
			if not String(pick[3]).is_empty() and String(pick[3]) not in layers:
				continue
			if not ResourceLoader.exists("res://assets/characters/variants/%s.tscn" % record["body"]):
				continue
			# The `_c` gowns wear a sideless surcoat over the belt (BeltGear.BODY_COVERS).
			if String(record["body"]).ends_with("_c"):
				continue
			picked.append(record)
			break
	if picked.size() != PICKS.size():
		push_error("capture_belt_gear: only %d of %d picks found" % [picked.size(), PICKS.size()])
		quit(1)
	return picked


func _save(image: Image, path: String) -> void:
	image.save_png(ProjectSettings.globalize_path(path))
	print("plate: ", path)
