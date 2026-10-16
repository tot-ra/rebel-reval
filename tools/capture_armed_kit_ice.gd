extends SceneTree

## R-2036 visual check: armed census kits (watch, crown, sergeant) standing on icy snow with the
## motion style layer (ADR 0051) running as in the city, plus a watchman walking on the ice (free
## arm out for balance, spear hand kept). `--legacy` forces the old behaviour (arms out while
## standing, weapon hand included) for a before/after pair.
##   tools/godot_render.sh --script tools/capture_armed_kit_ice.gd -- [--legacy]
## Writes res://docs/reports/images/motion_style/armed_kit_ice[_legacy].png

const MotionEnvironment := preload("res://scripts/motion/motion_environment.gd")
const MotionStylePresenter := preload("res://scripts/motion/motion_style_presenter.gd")
const OUT := "res://docs/reports/images/motion_style/"
const BODY := "citizen_m_adult_average"
const SPACING := 1.35
const FRAME_DT := 1.0 / 30.0
## [label, kit, gear wear layers, walking]
const ROW: Array = [
	["watch, standing", "watch", ["gambeson", "kettle_hat"], false],
	["crown, standing", "crown", ["gambeson", "kettle_hat"], false],
	["sergeant, standing", "sergeant", ["gambeson", "kettle_hat"], false],
	["watch, walking", "watch", ["gambeson", "kettle_hat"], true],
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var legacy := "--legacy" in OS.get_cmdline_user_args()
	var env_state: RefCounted = MotionEnvironment.new()
	env_state.air_temp_c = -6.0
	env_state.puddle_wetness = 0.9
	MotionEnvironment.set_current(env_state)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1600, 900)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.62, 0.66, 0.72)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.72, 0.75, 0.8)
	viewport.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -25, 0)
	sun.shadow_enabled = true
	viewport.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(12.0, 6.0)
	var snow := StandardMaterial3D.new()
	snow.albedo_color = Color(0.88, 0.9, 0.94)
	snow.roughness = 0.35
	plane.material = snow
	ground.mesh = plane
	viewport.add_child(ground)
	var rigs: Array[SharedCharacterRig] = []
	for i in ROW.size():
		var entry: Array = ROW[i]
		var scene := load("res://assets/characters/variants/%s.tscn" % BODY) as PackedScene
		var rig := scene.instantiate() as SharedCharacterRig
		viewport.add_child(rig)
		rig.position = Vector3((i - (ROW.size() - 1) * 0.5) * SPACING, 0.0, 0.0)
		rig.rotation_degrees = Vector3(0, 25.0, 0)
		var record := {
			"body": BODY,
			"cloth": [0.3, 0.3, 0.28],
			"under": [0.22, 0.2, 0.17],
			"wear": entry[2],
			"wear_dye": {},
			"duty": {"kit": entry[1], "shift": "day"},
		}
		CityCitizens.dye(rig, record)
		CitizenGear.arm(rig, record)
		if entry[3]:
			rig.play_animation(&"walk")
		var label := Label3D.new()
		label.text = entry[0]
		label.font_size = 36
		label.pixel_size = 0.004
		label.position = Vector3(0, -0.12, 0.45)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		rig.add_child(label)
		rigs.append(rig)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.0
	camera.position = Vector3(0.0, 1.3, 7.0)
	viewport.add_child(camera)
	camera.current = true
	# Two seconds of the city's per-frame presenter call, standing (0 m/s) or walking (1.4 m/s).
	for _frame in 60:
		for i in rigs.size():
			MotionStylePresenter.humanoid(rigs[i], FRAME_DT, 1.4 if ROW[i][3] else 0.0)
			if legacy:
				var modifier: Object = rigs[i].get_meta(MotionStylePresenter.MODIFIER_META)
				modifier.set(&"balance", 1.0)
				modifier.set(&"held_l", false)
				modifier.set(&"held_r", false)
		await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var path := OUT + ("armed_kit_ice_legacy.png" if legacy else "armed_kit_ice.png")
	viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("plate: ", path)
	quit(0)
