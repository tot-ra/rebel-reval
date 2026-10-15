extends SceneTree

## Visual check of the motion style network (ADR 0051) on the real rigs: a row of people and a row
## of
## animals, each in another situation, posed by the same layer. Writes
## res://docs/reports/images/motion_style/lineup.png (and a walk plate with --walk).
##   tools/godot_render.sh --script tools/capture_motion_style.gd -- [--walk] [--animals] [--off]
## (--off renders the same scene with the style layer disabled, for comparison)

const RIG_SCENE := "res://assets/characters/shared/shared_character_rig.tscn"
const MotionEnvironment := preload("res://scripts/motion/motion_environment.gd")
const MotionStylePresenter := preload("res://scripts/motion/motion_style_presenter.gd")
const AnimalModels := preload("res://scripts/map/view3d/map_view_medieval_animal_models.gd")
const OUT := "res://docs/reports/images/motion_style/"
const HUMAN_KNOBS: Array = [
	"crouch",
	"trunk_pitch",
	"trunk_roll",
	"arm_out",
	"hug_L",
	"hug_R",
	"press_L",
	"press_R",
	"tremor",
	"limp",
]
const ANIMAL_KNOBS: Array = [
	"crouch",
	"trunk_pitch",
	"arm_out",
	"hug_L",
	"head_down",
	"tail_tuck",
	"fluff",
	"tremor",
	"limp",
]

const PEOPLE: Array = [
	["dry, mild", []],
	["ice", [&"ice"]],
	["soaked at 3 C", [&"drenched", {"air_temp": 3.0}]],
	["bleeding L thigh", []],
	["broken R arm", [[&"broken_arm", 1.0, {"side": "R"}]]],
	["gale from the left", [[&"gale", 1.0, {"dir": PI / 2.0}]]],
	["deep snow, frost", [&"deep_snow", {"air_temp": -15.0}]],
	["smoke", [&"smoke"]],
]
const ANIMALS: Array = [
	["dog, dry", &"dog", []],
	["dog on ice", &"dog", [&"ice"]],
	["dog soaked, cold", &"dog", [&"drenched", {"air_temp": 2.0}]],
	["horse, lame L", &"horse", [[&"sprain", 1.0, {"side": "L"}]]],
	["hen on ice", &"chicken", [&"ice"]],
	["hen soaked, cold", &"chicken", [&"drenched", {"air_temp": 2.0}]],
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var walking := "--walk" in OS.get_cmdline_user_args()
	MotionEnvironment.set_current(MotionEnvironment.new())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var vp := SubViewport.new()
	vp.size = Vector2i(1800, 900)
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var scene := Node3D.new()
	vp.add_child(scene)
	_lights(scene)
	var labels: Array = []
	var rigs: Array = []
	for i in PEOPLE.size():
		var rig := (load(RIG_SCENE) as PackedScene).instantiate()
		scene.add_child(rig)
		rig.position = Vector3(-6.3 + i * 1.8, 0.0, 0.0)
		rig.rotation.y = deg_to_rad(-35.0)
		rigs.append(rig)
	var animals: Array = []
	for i in ANIMALS.size():
		var holder := Node3D.new()
		scene.add_child(holder)
		holder.position = Vector3(-5.5 + i * 2.2, 0.0, -3.2)
		holder.rotation.y = deg_to_rad(-60.0)
		AnimalModels.add_model(holder, ANIMALS[i][1])
		holder.set_meta(&"species", ANIMALS[i][1])
		animals.append(holder)
	await process_frame
	for i in rigs.size():
		rigs[i].play_animation(&"walk" if walking else &"idle", 0.0)
		if i == 3:
			var agent: RefCounted = MotionStylePresenter.agent_for(rigs[i], &"biped", 70.0, 0.9)
			agent.add_wound("thigh", "L", 0.9, 0.5)
	for step in 40:
		for i in rigs.size():
			MotionStylePresenter.humanoid(rigs[i], 0.05, 1.3 if walking else 0.0, PEOPLE[i][1])
		for i in animals.size():
			MotionStylePresenter.animal(animals[i], 0.05, ANIMALS[i][1], ANIMALS[i][2])
	for i in rigs.size():
		print(PEOPLE[i][0], ": ", _knobs(rigs[i], HUMAN_KNOBS))
	for i in animals.size():
		print(ANIMALS[i][0], ": ", _knobs(animals[i], ANIMAL_KNOBS))
	if "--off" in OS.get_cmdline_user_args():
		for a: Node in animals:
			var m: Variant = a.get_meta(&"motion_style_modifier")
			if m is SkeletonModifier3D:
				(m as SkeletonModifier3D).active = false
		for r: Node in rigs:
			(r.get_meta(&"motion_style_modifier") as SkeletonModifier3D).active = false
	var cam := Camera3D.new()
	scene.add_child(cam)
	if "--animals" in OS.get_cmdline_user_args():
		for r: Node in rigs:
			r.visible = false
		cam.position = Vector3(0.0, 1.6, 2.2)
		cam.look_at(Vector3(0.0, 0.4, -3.2))
	else:
		cam.position = Vector3(0.0, 2.6, 7.6)
		cam.look_at(Vector3(0.0, 0.7, -1.2))
	cam.fov = 58.0
	cam.current = true
	for f in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	var name := (
		("lineup_walk" if walking else "lineup")
		+ ("_off" if "--off" in OS.get_cmdline_user_args() else "")
		+ ("_animals" if "--animals" in OS.get_cmdline_user_args() else "")
		+ ".png"
	)
	img.save_png(ProjectSettings.globalize_path(OUT + name))
	var legend := PackedStringArray()
	for p: Array in PEOPLE:
		legend.append(p[0])
	print("people (left to right): ", ", ".join(legend))
	legend.clear()
	for a: Array in ANIMALS:
		legend.append(a[0])
	print("animals (left to right, back row): ", ", ".join(legend))
	print("wrote ", OUT + name)
	quit()


func _knobs(node: Node, keys: Array) -> String:
	var st: Dictionary = (node.get_meta(&"motion_style_agent") as RefCounted).style
	var parts := PackedStringArray()
	for k: String in keys:
		parts.append("%s %.2f" % [k, float(st[k])])
	return " ".join(parts)


func _lights(scene: Node3D) -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("6f7f8a")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c5d6dd")
	environment.ambient_light_energy = 0.7
	var world := WorldEnvironment.new()
	world.environment = environment
	scene.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -30, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	scene.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 20)
	ground.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("8d8273")
	ground.material_override = mat
	scene.add_child(ground)
