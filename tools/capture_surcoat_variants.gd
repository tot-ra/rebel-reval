extends SceneTree

## Surcoats and the Order mantle in every variant cell (task R-2022,
## docs/SYSTEMS/CITIZEN_WARDROBE.md): crown men-at-arms (red broadcloth, p2), a crown knight
## (scarlet, p3), a vassal knight (field colours, p3) and Order brothers (white surcoat and
## mantle, black cross), each w0 fresh, w1 travel-worn, w2 torn and patched. Dressed through
## CitizenWardrobe exactly as in the city, walking, so the riding slits and the hem show.
## Writes front, side and back plates (JPEG). Requires a rendering run:
##   tools/godot_render.sh --script tools/capture_surcoat_variants.gd [-- --output-dir=PATH]
##     [--body=citizen_m_adult_sturdy] [--idle]

const OUTPUT_DIR := "res://docs/reports/images/equipment"
const SPACING := 1.0
const RED := [0.58, 0.11, 0.09]
const WHITE := [0.88, 0.86, 0.8]
const BLUE := [0.17, 0.24, 0.38]
const CROWN_KIT := ["gambeson", "mail_haubergeon", "surcoat", "kettle_hat"]
const KNIGHT_KIT := [
	"gambeson", "mail_haubergeon", "mail_chausses", "surcoat", "aventail", "bascinet"
]
const ORDER_KIT := [
	"gambeson", "mail_haubergeon", "mail_chausses", "surcoat", "order_mantle", "bascinet"
]
## [label, kit, cell, wear_dye, status]
const KITS := [
	["crown w0", CROWN_KIT, "p2_w0", {"surcoat": RED}, "soldier"],
	["crown w1", CROWN_KIT, "p2_w1", {"surcoat": RED}, "soldier"],
	["crown w2", CROWN_KIT, "p2_w2", {"surcoat": RED}, "soldier"],
	["crown knight w0", KNIGHT_KIT, "p3_w0", {"surcoat": RED}, "noble"],
	["vassal knight w1", KNIGHT_KIT, "p3_w1", {"surcoat": BLUE}, "noble"],
	["Order w0", ORDER_KIT, "p3_w0", {"surcoat": WHITE, "order_mantle": WHITE}, "noble"],
	["Order w1", ORDER_KIT, "p3_w1", {"surcoat": WHITE, "order_mantle": WHITE}, "noble"],
	["Order w2", ORDER_KIT, "p3_w2", {"surcoat": WHITE, "order_mantle": WHITE}, "noble"],
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var body := "citizen_m_adult_sturdy"
	var idle := OS.get_cmdline_user_args().has("--idle")
	var out := OUTPUT_DIR
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--output-dir="):
			out = a.trim_prefix("--output-dir=")
		elif a.begins_with("--body="):
			body = a.trim_prefix("--body=")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(2400, 900)
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
	var scene := load("res://assets/characters/variants/%s.tscn" % body) as PackedScene
	for i in KITS.size():
		var rig := scene.instantiate() as SharedCharacterRig
		viewport.add_child(rig)
		rig.position = Vector3((i - (KITS.size() - 1) * 0.5) * SPACING, 0.0, 0.0)
		rigs.append(rig)
	for _frame in 4:
		await process_frame
	for i in KITS.size():
		var kit: Array = KITS[i]
		var wear: Array = []
		for layer: String in kit[1]:
			wear.append("%s@%s" % [layer, kit[2]])
		var record := {
			"id": "cit.capture.surcoat.%d" % i,
			"body": body,
			"status": kit[4],
			"cloth": [0.3, 0.3, 0.28],
			"under": [0.22, 0.2, 0.17],
			"wear": wear,
			"wear_dye": kit[3],
		}
		CityCitizens.dye(rigs[i], record)
		CitizenGear.arm(rigs[i], record)
		if not idle:
			rigs[i].play_animation(&"walk")
		var label := Label3D.new()
		label.text = String(kit[0])
		label.font_size = 36
		label.pixel_size = 0.004
		label.position = Vector3(0, -0.12, 0.3)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		rigs[i].add_child(label)
		# Stagger the gait so the row shows several phases of the stride.
		for _frame in 5:
			await process_frame
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.4
	camera.position = Vector3(0.0, 1.0, 7.0)
	viewport.add_child(camera)
	camera.current = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	for view: Array in [["front", 15.0], ["side", 90.0], ["back", 165.0]]:
		for rig in rigs:
			rig.rotation_degrees = Vector3(0, float(view[1]), 0)
		for _frame in 3:
			await process_frame
		_save(viewport, out + "/surcoat_variants_%s%s.jpg" % [view[0], "_idle" if idle else ""])
	quit(0)


func _save(viewport: SubViewport, path: String) -> void:
	viewport.get_texture().get_image().save_jpg(ProjectSettings.globalize_path(path), 0.86)
	print("SAVED ", path)
