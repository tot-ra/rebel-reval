extends SceneTree

## Bag variants plate (task R-2034, docs/SYSTEMS/CITIZEN_WARDROBE.md): census residents
## who carry a scrip or a back sack, dressed exactly as in the city (CityCitizens.dye +
## CitizenGear.arm): porters with sacks (used, battered), a merchant's and a clerk's
## tooled scrip, pedlars' rawhide and linen scrips, a pilgrim's scrip with its scallop.
## Writes a full-figure row and a sheet of close-ups of each bag.
## Requires a rendering run:
##   tools/godot_render.sh --script tools/capture_bag_variants.gd [-- --output-dir=PATH]

const CitizenBags := preload("res://scripts/city/citizen_bags.gd")
const EquipmentVariant := preload("res://scripts/city/equipment_variant.gd")
const CENSUS := "res://content/world/reval_city/citizens.json"
const OUTPUT_DIR := "res://docs/reports/images/equipment"
const SPACING := 1.2
const TILE := 520
## [label, trade, layer, cell prefix, p1 pouch grade ("" = any)]
const PICKS := [
	["porter, sack p1_w1", "porter", "back_sack", "p1_w1", ""],
	["porter, sack p1_w2", "porter", "back_sack", "p1_w2", ""],
	["merchant, tooled p3_w0", "merchant", "satchel", "p3_w0", ""],
	["clerk, tooled p2_w2", "clerk", "satchel", "p2_w2", ""],
	["pedlar, rawhide p1", "pedlar", "satchel", "p1", "rawhide"],
	["pedlar, linen p1", "pedlar", "satchel", "p1", "linen_coarse"],
	["pilgrim, scrip + scallop", "pilgrim", "satchel", "p1", ""],
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var records := _pick(_census())
	var viewport := SubViewport.new()
	viewport.size = Vector2i(2600, 1000)
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
	camera.size = 4.4
	camera.position = Vector3(0.0, 1.0, 7.0)
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
		print("bag pick: %s %s %s" % [PICKS[i][0], record["id"], record["wear"]])
	for _frame in 8:
		await process_frame
	var out := OUTPUT_DIR
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--output-dir="):
			out = a.trim_prefix("--output-dir=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	# Full figures, three-quarter: scrips are on the left hip, sacks on the back.
	for i in rigs.size():
		rigs[i].rotation_degrees = Vector3(0, _turn(PICKS[i][2]), 0)
	for _frame in 3:
		await process_frame
	_save(viewport.get_texture().get_image(), out + "/bag_variants_row.png")
	# Close-ups: one perspective tile per bag, composed into a sheet.
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 30.0
	viewport.size = Vector2i(TILE, TILE)
	var sheet := Image.create(TILE * 4, TILE * 2, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.55, 0.57, 0.6))
	for i in rigs.size():
		var sack: bool = PICKS[i][2] == "back_sack"
		var local := Vector3(0.0, 1.25, 0.0) if sack else Vector3(0.12, 0.92, 0.0)
		var view := Vector3(0.0, 0.15, 1.15)
		# The scrip hangs behind the left arm: look at it from the left and a little behind.
		rigs[i].rotation_degrees = Vector3(0, 160.0 if sack else -120.0, 0)
		var focus := rigs[i].global_transform * local
		camera.position = focus + view
		camera.look_at(focus)
		for _frame in 3:
			await process_frame
		var tile := viewport.get_texture().get_image()
		tile.convert(Image.FORMAT_RGBA8)
		var at := Vector2i((i % 4) * TILE, int(i / 4.0) * TILE)
		sheet.blit_rect(tile, Rect2i(Vector2i.ZERO, tile.get_size()), at)
	_save(sheet, out + "/bag_variants_closeup.png")
	quit(0)


## Rig yaw for a three-quarter view of the layer's bag.
func _turn(layer: String) -> float:
	return 160.0 if layer == "back_sack" else -100.0


func _census() -> Array:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(CENSUS))
	return (data as Dictionary).get("residents", []) if data is Dictionary else []


## One census resident per PICKS row (first match by trade, layer, cell and pouch grade).
func _pick(residents: Array) -> Array:
	var picked: Array = []
	for pick: Array in PICKS:
		for record: Dictionary in residents:
			if String(record.get("trade", "")) != pick[1] or record in picked:
				continue
			var cell := _cell(record, pick[2])
			if cell.is_empty() or not cell.begins_with(pick[3]):
				continue
			if not String(pick[4]).is_empty():
				var rawhide := CitizenBags._roll(record) < 0.5
				if rawhide != (pick[4] == "rawhide"):
					continue
			picked.append(record)
			break
	if picked.size() != PICKS.size():
		push_error("capture_bag_variants: only %d of %d picks found" % [picked.size(), PICKS.size()])
		quit(1)
	return picked


func _cell(record: Dictionary, layer: String) -> String:
	for entry: String in record.get("wear", []):
		var parts := EquipmentVariant.split(entry)
		if parts[0] == layer:
			return parts[1] if not parts[1].is_empty() else EquipmentVariant.BASE_CELL
	return ""


func _save(image: Image, path: String) -> void:
	image.save_png(ProjectSettings.globalize_path(path))
	print("plate: ", path)
