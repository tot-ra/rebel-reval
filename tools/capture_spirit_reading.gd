extends SceneTree

## Review plates for reading a soul (SS-4, R-1487, ADR 0041 section 4). GPU run:
##   tools/godot_render.sh --resolution 1280x720 --script tools/capture_spirit_reading.gd -- \
##     --out=res://docs/reports/images/spirit_reading
## Plates: a resident read at the New Game awareness (the masked root light veiled) and the
## same resident read at awareness 5 (the closed root revealed, the stranger-duel topic hint).
## The real SpiritAuraManager and SpiritReadingPanel run; the focus point is the resident's
## chest on screen, as the mouse would rest there.

const RIG_SCENE := preload("res://assets/characters/shared/shared_character_rig.tscn")
const AuraManager := preload("res://scripts/combat/spirit_aura_manager.gd")
const ReadingPanel := preload("res://scripts/ui/spirit_reading_panel.gd")
const AURA := {
	"levels": {
		"aspect.nature": 0, "aspect.affection": 3, "aspect.tenacity": 4, "aspect.unity": 1,
		"aspect.resonance": 2, "aspect.awareness": 2, "aspect.light": 3,
	},
	"clarity": 0.45,
	"closed_mask": ["aspect.nature"],
}

var _stage: Node3D


func _init() -> void:
	var out := "res://build/spirit_reading"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	await process_frame
	await _plate(out + "/reading_awareness_start.png", 15)
	await _plate(out + "/reading_awareness_5.png", 40)
	quit()


func _plate(path: String, awareness_rank: int) -> void:
	_stage = Node3D.new()
	root.add_child(_stage)
	_add_world()
	var state := GameState.new()
	state.grant_natural_points(awareness_rank - GameState.NATURAL_ASPECT_BASELINE)
	while state.get_natural_aspect_rank(&"aspect.awareness") < awareness_rank:
		state.spend_natural_point(&"aspect.awareness")
	var manager := AuraManager.new()
	manager.follow_session = false
	manager.state = state
	manager.fade = 1.0
	manager.center_override = Vector3.ZERO
	_stage.add_child(manager)
	var rig := RIG_SCENE.instantiate() as SharedCharacterRig
	rig.name = "CarterRig"
	rig.set_meta(&"display_name", "a carter")
	_stage.add_child(rig)
	rig.global_position = Vector3(-0.6, 0.0, 0.0)
	var ring := rig.get_node_or_null("HealthRing") as Node3D
	if ring != null:
		ring.visible = false
	manager.register(rig, SpiritAuraProfile.from_record(&"char.carter", {"aura": AURA}))
	var camera := Camera3D.new()
	camera.fov = 40.0
	_stage.add_child(camera)
	camera.look_at_from_position(Vector3(0.4, 1.5, 4.2), Vector3(0.2, 1.05, 0.0))
	camera.current = true
	await _wait(0.4)
	manager.refresh()
	var panel := ReadingPanel.new()
	panel.follow_session = false
	panel.manager = manager
	panel.state = state
	panel.camera_override = camera
	panel.content_db = root.get_node("SessionState").get(&"content_db") as ContentDB
	_stage.add_child(panel)
	panel.set_process(false)
	panel.focus_point_override = camera.unproject_position(manager.view_for(rig).anchors[3])
	panel.tick(SpiritReading.FOCUS_DELAY + 0.05)
	print("reading open=%s depth=%s" % [panel.is_open(), panel.reading.get("depth")])
	await _wait(1.4)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image.get_width() > 1280:
		image.resize(1280, 720, Image.INTERPOLATE_LANCZOS)
	image.save_png(path)
	print("CAPTURED ", path)
	_stage.free()


func _add_world() -> void:
	# A stand-in for the spirit-sight grade, as in capture_spirit_auras.gd.
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.06, 0.07, 0.12)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.45, 0.48, 0.62)
	environment.ambient_light_energy = 0.5
	environment.adjustment_enabled = true
	environment.adjustment_saturation = 0.35
	var world := WorldEnvironment.new()
	world.environment = environment
	_stage.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 0.55
	sun.light_color = Color(0.7, 0.74, 1.0)
	_stage.add_child(sun)
	sun.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80.0, 80.0)
	ground.mesh = plane
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color(0.22, 0.23, 0.27)
	ground.material_override = ground_material
	_stage.add_child(ground)


func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame
