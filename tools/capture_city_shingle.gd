extends SceneTree

## R-1606 review captures of the city shingle band and shore stones. Picks two
## coast spots from the plan (a cart road crossing the shingle band, and open
## beach away from roads) and shoots each from the gameplay height and close up.
##   tools/godot_render.sh --script tools/capture_city_shingle.gd [-- --tag=after --out=res://build/shingle]
## Output: <out>/shingle_<spot>_<view>_<tag>.png

const VIEWPORT_SIZE := Vector2i(1600, 900)
const DAY_PROGRESS := 0.42
## Shingle band of city_ground.gdshader (height above the sea, world units).
const BAND := Vector2(0.6, 1.5)
const STEP := 4.0

var _tag := "before"
var _out := "res://build/shingle"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tag="):
			_tag = arg.substr(6)
		if arg.begins_with("--out="):
			_out = arg.substr(6)
	call_deferred("_run")


## Road body at a world position (roads.png R channel), like CityGrass.road_at.
func _road(plan: CityPlan, roads: Image, p: Vector2) -> float:
	var t := (p - plan.bounds.position) / plan.bounds.size * Vector2(roads.get_size())
	return roads.get_pixel(clampi(int(t.x), 0, roads.get_width() - 1), clampi(int(t.y), 0, roads.get_height() - 1)).r


## Downhill (seaward) unit direction from the heightfield.
func _seaward(plan: CityPlan, p: Vector2) -> Vector2:
	var e := 2.0
	var g := Vector2(
		plan.ground_height(p + Vector2(e, 0)) - plan.ground_height(p - Vector2(e, 0)),
		plan.ground_height(p + Vector2(0, e)) - plan.ground_height(p - Vector2(0, e))
	)
	return -g.normalized() if g.length() > 1e-4 else Vector2(0, 1)


func _spots(plan: CityPlan) -> Dictionary:
	var roads := (load(plan.roads_path()) as Texture2D).get_image()
	if roads.is_compressed():
		roads.decompress()
	var road_spot := Vector2.INF
	var road_score := -1.0
	var beach_spot := Vector2.INF
	var beach_score := -1.0
	var r := plan.bounds
	var y := r.position.y
	while y < r.end.y:
		var x := r.position.x
		while x < r.end.x:
			var p := Vector2(x, y)
			x += STEP
			var h := plan.ground_height(p)
			if h < BAND.x or h > BAND.y or plan.slope_at(p) > 0.3 or plan.building_at(p) >= 0:
				continue
			var rd := _road(plan, roads, p)
			# A road crossing the band: the road body here, sea within a few metres.
			if rd > 0.6 and plan.ground_height(p + _seaward(plan, p) * 8.0) < 0.2:
				if rd > road_score:
					road_score = rd
					road_spot = p
			# Open beach: no road within 14 m, gentle shore.
			if rd < 0.01 and plan.ground_height(p + _seaward(plan, p) * 6.0) < 0.1:
				var clear := true
				for d: Vector2 in [Vector2(14, 0), Vector2(-14, 0), Vector2(0, 14), Vector2(0, -14)]:
					if _road(plan, roads, p + d) > 0.05 or plan.building_at(p + d) >= 0:
						clear = false
						break
				if clear:
					var score := 1.0 - absf(h - 1.0)
					if score > beach_score:
						beach_score = score
						beach_spot = p
			pass
		y += STEP
	var out := {}
	if road_spot != Vector2.INF:
		out["road"] = road_spot
	if beach_spot != Vector2.INF:
		out["beach"] = beach_spot
	return out


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	var plan := CityPlan.load_default()
	var spots := _spots(plan)
	print("shingle spots: %s" % spots)
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world := CityWorld3D.create(plan)
	viewport.add_child(world)
	var camera := Camera3D.new()
	camera.far = 6000.0
	camera.near = 0.1
	viewport.add_child(camera)
	camera.current = true
	world.setup_lighting(camera)
	world.apply_time(DAY_PROGRESS)
	for spot_name: String in spots:
		var p: Vector2 = spots[spot_name]
		var sea := _seaward(plan, p)
		# Look along the shore with the sea on one side so band, edge and sand all show.
		var along := Vector2(-sea.y, sea.x)
		var h := plan.ground_height(p)
		var views := {
			# Third-person gameplay framing: ~9 m up, 11 m back.
			"game": [p - along * 11.0 - sea * 3.0, 9.0, 52.0],
			"close": [p - along * 3.2 - sea * 0.8, 1.6, 60.0],
		}
		for view: String in views:
			var v: Array = views[view]
			var eye2: Vector2 = v[0]
			camera.fov = v[2]
			camera.look_at_from_position(
				Vector3(eye2.x, plan.ground_height(eye2) + float(v[1]), eye2.y), Vector3(p.x, h, p.y), Vector3.UP
			)
			world.apply_time(DAY_PROGRESS)
			for i in 8:
				await process_frame
			var path := "%s/shingle_%s_%s_%s.png" % [_out, spot_name, view, _tag]
			viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
			print("captured %s" % path)
	quit(0)
