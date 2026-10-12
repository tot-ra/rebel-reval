extends SceneTree

## Wardrobe plate (docs/SYSTEMS/CITIZEN_WARDROBE.md): one citizen body per kit,
## dressed through CitizenWardrobe exactly as in the city, front and back three-quarter.
## Requires a rendering run:
##   tools/godot_render.sh --script tools/capture_citizen_wardrobe.gd \
##     [-- --output-dir=PATH] [--walk]

const OUTPUT_DIR := "res://docs/reports/images/characters"
const SPACING := 1.15
## Rows stand apart along X; each is shot on its own.
const ROW_OFFSET := 40.0
const RED := [0.58, 0.11, 0.09]
const BLACK := [0.12, 0.11, 0.10]
const WHITE := [0.88, 0.86, 0.8]
## [label, body, cloth dye, wear, wear_dye]
const ROWS := [
	[
		[
			"labourer",
			"citizen_m_adult_thin",
			[0.46, 0.44, 0.4],
			["wool_cap", "back_sack"],
			{"wool_cap": [0.36, 0.28, 0.2]},
		],
		[
			"journeyman",
			"citizen_m_adult_average",
			[0.36, 0.4, 0.28],
			["coif"],
			{"coif": [0.74, 0.7, 0.6]},
		],
		[
			"smith",
			"citizen_m_adult_sturdy",
			[0.46, 0.44, 0.4],
			["smith_apron", "coif"],
			{"coif": [0.74, 0.7, 0.6]},
		],
		[
			"baker",
			"citizen_m_adult_heavy",
			[0.6, 0.52, 0.28],
			["waist_apron", "hood"],
			{"waist_apron": WHITE, "hood": [0.52, 0.25, 0.18]},
		],
		[
			"clerk",
			"citizen_m_adult_average_b",
			[0.27, 0.35, 0.46],
			["hood", "satchel"],
			{"hood": [0.17, 0.24, 0.38]},
		],
		[
			"merchant",
			"citizen_m_adult_heavy_b",
			[0.42, 0.13, 0.1],
			["hood", "keys"],
			{"hood": [0.2, 0.17, 0.15]},
		],
		[
			"monk",
			"citizen_m_adult_thin_b",
			BLACK,
			["hood", "paternoster"],
			{"hood": BLACK},
		],
		[
			"watch",
			"citizen_m_adult_average",
			[0.3, 0.3, 0.28],
			["gambeson", "kettle_hat"],
			{},
		],
		[
			"crown",
			"citizen_m_adult_sturdy",
			RED,
			["gambeson", "mail_haubergeon", "surcoat", "kettle_hat"],
			{"surcoat": RED},
		],
		[
			"sergeant",
			"citizen_m_adult_heavy",
			[0.18, 0.2, 0.3],
			["gambeson", "mail_haubergeon", "mail_coif", "kettle_hat"],
			{},
		],
		[
			"knight",
			"citizen_m_adult_average_b",
			[0.17, 0.24, 0.38],
			["gambeson", "mail_haubergeon", "surcoat", "mail_coif", "bascinet"],
			{"surcoat": [0.86, 0.85, 0.8]},
		],
	],
	[
		[
			"maid",
			"citizen_f_adult_thin",
			[0.36, 0.28, 0.2],
			["waist_apron"],
			{"waist_apron": [0.74, 0.7, 0.6]},
		],
		[
			"wife",
			"citizen_f_adult_average_b",
			[0.27, 0.35, 0.46],
			["veil_over", "keys"],
			{"veil_over": WHITE},
		],
		[
			"patrician",
			"citizen_f_adult_heavy_b",
			[0.42, 0.13, 0.1],
			["veil_over", "keys", "paternoster"],
			{"veil_over": WHITE, "paternoster": [0.7, 0.42, 0.12]},
		],
		[
			"nun",
			"citizen_f_adult_sturdy_b",
			BLACK,
			["veil_over", "paternoster"],
			{"veil_over": BLACK},
		],
		[
			"midwife",
			"citizen_f_adult_average",
			[0.35, 0.4, 0.28],
			["satchel", "waist_apron"],
			{},
		],
		[
			"widow",
			"citizen_f_elder_thin",
			[0.2, 0.17, 0.15],
			["veil_over", "paternoster"],
			{"veil_over": [0.74, 0.7, 0.6]},
		],
		[
			"elder",
			"citizen_m_elder_heavy",
			[0.36, 0.28, 0.2],
			["hood", "keys"],
			{"hood": [0.27, 0.35, 0.46]},
		],
		[
			"old man",
			"citizen_m_elder_thin",
			[0.46, 0.44, 0.4],
			["coif", "paternoster"],
			{},
		],
		[
			"boy",
			"citizen_m_child_average",
			[0.5, 0.35, 0.21],
			["wool_cap"],
			{"wool_cap": [0.3, 0.21, 0.14]},
		],
		[
			"boy",
			"citizen_m_child_average",
			[0.27, 0.35, 0.46],
			["hood"],
			{"hood": [0.52, 0.25, 0.18]},
		],
		[
			"girl",
			"citizen_f_child_average",
			[0.52, 0.25, 0.18],
			[],
			{},
		],
	],
]

## Armour range (WD-4): five kits on each of four builds, one plate row per build.
const ARMOUR_BUILDS := [
	"citizen_m_adult_thin",
	"citizen_m_adult_average_b",
	"citizen_m_adult_sturdy",
	"citizen_m_adult_heavy_b",
]
const BLUE := [0.17, 0.24, 0.38]
## [label, cloth dye, wear, wear_dye, shield]
const ARMOUR_KITS := [
	[
		"man-at-arms",
		[0.3, 0.3, 0.28],
		[
			"gambeson",
			"mail_haubergeon",
			"mail_chausses",
			"surcoat",
			"kettle_hat",
		],
		{"surcoat": RED},
		"crown",
	],
	[
		"coat of plates",
		[0.3, 0.3, 0.28],
		[
			"gambeson",
			"mail_haubergeon",
			"coat_of_plates",
			"aventail",
			"bascinet",
			"mail_chausses",
			"gauntlets",
		],
		{"coat_of_plates": RED},
		"crown",
	],
	[
		"vassal knight",
		[0.3, 0.3, 0.28],
		["gambeson", "mail_haubergeon", "surcoat", "aventail", "bascinet", "mail_chausses", "gauntlets"],
		{"surcoat": BLUE},
		"field",
	],
	[
		"great helm",
		[0.3, 0.3, 0.28],
		[
			"gambeson",
			"mail_haubergeon",
			"coat_of_plates",
			"mail_coif",
			"great_helm",
			"mail_chausses",
			"gauntlets",
		],
		{"coat_of_plates": BLUE},
		"field",
	],
	[
		"Order brother",
		[0.3, 0.3, 0.28],
		[
			"gambeson",
			"mail_haubergeon",
			"mail_chausses",
			"gauntlets",
			"surcoat",
			"order_mantle",
			"aventail",
			"bascinet",
		],
		{"surcoat": WHITE, "order_mantle": WHITE},
		"order",
	],
]


func _armour_rows() -> Array:
	var rows: Array = []
	for body: String in ARMOUR_BUILDS:
		var row: Array = []
		for kit: Array in ARMOUR_KITS:
			row.append([kit[0], body, kit[1], kit[2], kit[3], kit[4]])
		rows.append(row)
	return rows


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var walk := OS.get_cmdline_user_args().has("--walk")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(2600, 900)
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
	var labels: Array = []
	var rows: Array = ROWS.duplicate()
	rows.append_array(_armour_rows())
	for row_index in rows.size():
		var row: Array = rows[row_index]
		for i in row.size():
			var entry: Array = row[i]
			var scene := load("res://assets/characters/variants/%s.tscn" % entry[1]) as PackedScene
			var rig := scene.instantiate() as SharedCharacterRig
			viewport.add_child(rig)
			var x := (i - (row.size() - 1) * 0.5) * SPACING + row_index * ROW_OFFSET
			rig.position = Vector3(x, 0.0, 0.0)
			rigs.append(rig)
			labels.append([entry, rig])
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.6
	camera.position = Vector3(0.0, 1.05, 7.0)
	viewport.add_child(camera)
	camera.current = true
	for _frame in 4:
		await process_frame
	for pair in labels:
		var entry: Array = pair[0]
		var rig: SharedCharacterRig = pair[1]
		var record := {
			"body": entry[1],
			"cloth": entry[2],
			"under": [0.22, 0.2, 0.17],
			"wear": entry[3],
			"wear_dye": entry[4],
		}
		if entry.size() > 5:
			record["shield"] = entry[5]
		CityCitizens.dye(rig, record)
		CitizenGear.arm(rig, record)
		if walk:
			rig.play_animation(&"walk")
		var label := Label3D.new()
		label.text = entry[0]
		label.font_size = 40
		label.pixel_size = 0.004
		label.position = Vector3(0, -0.12, 0.3)
		rig.add_child(label)
	for _frame in 8:
		await process_frame
	var out := OUTPUT_DIR
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--output-dir="):
			out = a.trim_prefix("--output-dir=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var suffix := "_walk" if walk else ""
	for row_index in rows.size():
		camera.position.x = row_index * ROW_OFFSET
		for rig in rigs:
			rig.rotation_degrees = Vector3.ZERO
		for _frame in 3:
			await process_frame
		_save(viewport, out + "/citizen_wardrobe_%d_front%s.png" % [row_index + 1, suffix])
		for rig in rigs:
			rig.rotation_degrees = Vector3(0, 150, 0)
		for _frame in 3:
			await process_frame
		_save(viewport, out + "/citizen_wardrobe_%d_back%s.png" % [row_index + 1, suffix])
	quit(0)


func _save(viewport: SubViewport, path: String) -> void:
	viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
