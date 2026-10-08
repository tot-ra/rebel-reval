extends SceneTree

## Review plates for cart-road mud, verge grass and footprints
## (docs/SYSTEMS/SEAMLESS_CITY.md, "Ground relief, roads and prints"). Picks a
## busy road, walks a stretch of it in wet or dry ground so the trail map fills
## with prints, then shoots from eye, gameplay and low grazing cameras.
##   tools/godot_render.sh --script tools/capture_city_mud.gd -- --tag=now [--wet=0.9]
## Output: build/mud/<shot>_<tag>.png

const OUTPUT_DIR := "res://build/mud"
const VIEWPORT_SIZE := Vector2i(1600, 900)

var _tag := "now"
var _wet := 0.9
var _puddles := -1.0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tag="):
			_tag = arg.substr(6)
		elif arg.begins_with("--puddles="):
			_puddles = float(arg.substr(10))
		elif arg.begins_with("--wet="):
			_wet = float(arg.substr(6))
	call_deferred("_run")


## A straight, busy stretch: road body and wear both high over 14 wu in a line.
func _find_road(plan: CityPlan) -> Dictionary:
	var img := (load(CityPlan.ROADS_PATH) as Texture2D).get_image()
	if img.is_compressed():
		img.decompress()
	var size := Vector2(img.get_size())
	var splat := (load(CityPlan.SPLAT_PATH) as Texture2D).get_image()
	if splat.is_compressed():
		splat.decompress()
	var best := {}
	var best_score := -1.0
	for y in range(8, img.get_height() - 8, 6):
		for x in range(8, img.get_width() - 8, 6):
			var px := img.get_pixel(x, y)
			if px.r < 0.95 or px.b < 0.5:
				continue
			var wp := plan.bounds.position + Vector2(x, y) / size * plan.bounds.size
			if plan.ground_height(wp) < 0.5 or plan.slope_at(wp) > 0.1:
				continue
			var near := wp.length()
			if near > 1400.0 or not _open_with_verge(plan, wp, splat, size):
				continue
			# Prefer a road with grass nearby (verge) and heavy wear.
			var score := px.b - near * 0.0005
			if score > best_score:
				best_score = score
				best = {"pos": wp, "px": Vector2i(x, y)}
	return best


## Open ground: no building within 12 wu, unpaved under the road, grass beside it.
func _open_with_verge(plan: CityPlan, wp: Vector2, splat: Image, size: Vector2) -> bool:
	for k in 12:
		if plan.building_at(wp + Vector2.from_angle(float(k) / 12.0 * TAU) * 12.0) >= 0:
			return false
	var at := func(q: Vector2) -> Color:
		var p := (q - plan.bounds.position) / plan.bounds.size * Vector2(splat.get_size())
		return splat.get_pixel(
			clampi(int(p.x), 0, splat.get_width() - 1),
			clampi(int(p.y), 0, splat.get_height() - 1)
		)
	if (at.call(wp) as Color).r > 0.2:
		return false
	var grass := 0
	for k in 8:
		var c: Color = at.call(wp + Vector2.from_angle(float(k) / 8.0 * TAU) * 7.0)
		if c.r < 0.2 and c.g < 0.2 and c.b < 0.2 and c.a < 0.2:
			grass += 1
	return grass >= 2


func _road_dir(plan: CityPlan, at: Vector2) -> Vector2:
	var img := (load(CityPlan.ROADS_PATH) as Texture2D).get_image()
	if img.is_compressed():
		img.decompress()
	var size := Vector2(img.get_size())
	var best := Vector2.RIGHT
	var best_len := -1
	for k in 16:
		var d := Vector2.from_angle(float(k) / 16.0 * PI)
		var n := 0
		for s in range(1, 40):
			var wp := at + d * float(s) * 0.5
			var p := (wp - plan.bounds.position) / plan.bounds.size * size
			var px := img.get_pixel(
				clampi(int(p.x), 0, img.get_width() - 1), clampi(int(p.y), 0, img.get_height() - 1)
			)
			if px.r > 0.9:
				n += 1
		if n > best_len:
			best_len = n
			best = d
	return best


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var plan := CityPlan.load_default()
	var found := _find_road(plan)
	var at: Vector2 = found["pos"]
	var dir := _road_dir(plan, at)
	print("road at ", at, " dir ", dir)
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world := CityWorld3D.create(plan)
	viewport.add_child(world)
	var camera := Camera3D.new()
	camera.far = 4000.0
	viewport.add_child(camera)
	camera.current = true
	world.setup_lighting(camera)
	world.apply_time(0.42)
	var ground := CityTerrainBuilder.shared_material()
	ground.set_shader_parameter("wetness", _wet)
	ground.set_shader_parameter("puddles", _puddles if _puddles >= 0.0 else _wet * 0.5)
	world.trail.wetness = _wet
	# Walk 24 wu along the road, a little wandering, so prints fill the window.
	var side := Vector2(-dir.y, dir.x)
	var pos := at - dir * 12.0
	world.trail.update_for(pos, 0.016)
	for i in 480:
		pos += dir * 0.05 + side * sin(float(i) * 0.05) * 0.004
		world.trail.update_for(pos, 0.016)
		world.grass.update_for(pos)
		if i % 60 == 0:
			await process_frame
	var g := plan.ground_height(pos)
	var focus := pos - dir * 5.0
	var gf := plan.ground_height(focus)
	var specs := [
		["eye", focus - dir * 4.0 + side * 1.0, 1.7, 0.0, 65.0],
		["game", focus - dir * 9.0 + side * 3.0, 6.0, 0.0, 55.0],
		["low", focus - dir * 2.2 + side * 0.4, 0.45, 0.0, 60.0],
		["verge", focus + side * 4.5 - dir * 3.0, 1.2, 0.0, 65.0],
	]
	for spec: Array in specs:
		var e: Vector2 = spec[1]
		camera.fov = spec[4]
		camera.look_at_from_position(
			Vector3(e.x, plan.ground_height(e) + float(spec[2]), e.y),
			Vector3(focus.x, gf, focus.y), Vector3.UP
		)
		for i in 40:
			world.grass.update_for(focus)
			await process_frame
		await RenderingServer.frame_post_draw
		var path := "%s/%s_%s.png" % [OUTPUT_DIR, spec[0], _tag]
		viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
		print("captured ", path)
	quit(0)
