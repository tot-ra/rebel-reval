extends SceneTree

## R-1430 deterministic soft-particle regression. Red card cuts a sloped opaque
## bank; compare old/fixed shader at overview and steep camera pitches. No city
## assets are required. A screen-reading water strip reproduces Compatibility's
## back-buffer copy. Run: tools/godot_render.sh --script tools/capture_fog_contacts.gd

const Puff := preload("res://scripts/map/view3d/local_fog_puff.gdshader")
const Banks := preload("res://scripts/map/view3d/local_fog_banks.gd")
const SIZE := Vector2i(640, 480)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.12, 0.12, 0.12)
	viewport.add_child(environment)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(50, 50)
	ground.mesh = plane
	var ground_material := StandardMaterial3D.new()
	ground_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ground_material.albedo_color = Color(0.15, 0.15, 0.15)
	ground.material_override = ground_material
	ground.rotation.z = deg_to_rad(12)
	viewport.add_child(ground)
	var water := MeshInstance3D.new()
	var water_plane := PlaneMesh.new()
	water_plane.size = Vector2(6, 40)
	water.mesh = water_plane
	water.position = Vector3(7, 2.0, 0)
	var water_shader := Shader.new()
	water_shader.code = """shader_type spatial;
render_mode unshaded;
uniform sampler2D screen_tex : hint_screen_texture;
void fragment() { ALBEDO = texture(screen_tex, SCREEN_UV).rgb * 0.8; ALPHA = 0.5; }
"""
	var water_material := ShaderMaterial.new()
	water_material.shader = water_shader
	water.material_override = water_material
	viewport.add_child(water)
	var puff := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(18, 10)
	puff.mesh = quad
	puff.position = Vector3(0, 1.6, 0)
	viewport.add_child(puff)
	var material := ShaderMaterial.new()
	material.render_priority = Banks.FOG_RENDER_PRIORITY
	material.set_shader_parameter("bank_strength", 1.0)
	material.set_shader_parameter("ambient_color", Color(1, 0.25, 0.25))
	material.set_shader_parameter("light_amount", 0.0)
	material.set_shader_parameter("max_alpha", 0.9)
	puff.material_override = material
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 24
	camera.far = 100
	viewport.add_child(camera)
	camera.make_current()
	var frozen := Shader.new()
	frozen.code = Puff.code.replace("TIME", "0.0")
	var old: Shader
	if FileAccess.file_exists("res://build/scratch/local_fog_puff_before.gdshader"):
		old = Shader.new()
		old.code = FileAccess.get_file_as_string(
			"res://build/scratch/local_fog_puff_before.gdshader"
		).replace("TIME", "0.0")
	var sheet := Image.create(SIZE.x * 2, SIZE.y * 2, false, Image.FORMAT_RGB8)
	DirAccess.make_dir_recursive_absolute("res://build/local_fog")
	for row in 2:
		var pitch := deg_to_rad(30 if row == 0 else 75)
		camera.look_at_from_position(
			Vector3(0, sin(pitch), cos(pitch)) * 30, Vector3.ZERO, Vector3.UP
		)
		for column in 2:
			material.shader = old if column == 0 and old != null else frozen
			for _frame in 8:
				await process_frame
			await RenderingServer.frame_post_draw
			var image := viewport.get_texture().get_image()
			image.convert(Image.FORMAT_RGB8)
			sheet.blit_rect(image, Rect2i(Vector2i.ZERO, SIZE), Vector2i(column, row) * SIZE)
	sheet.save_png("res://build/local_fog/fog_contacts_before_after.png")
	print("Fog contact plate: old left / fixed right; overview top / steep bottom")
	viewport.queue_free()
	await process_frame
	quit()
