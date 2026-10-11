extends SceneTree

## Backlit golden-hour forest probe (Witcher look gap analysis, 2026-10-11).
## Frames the largest oak and the densest stand of the seamless city against a
## low sun (18.6 h, 15 July, clear sky) twice: "stock" with the shipped grade and
## "tuned" with the sky fill and outdoor gain pulled down and glow raised, to show
## how much of the gap is lighting alone. Report:
## docs/reports/witcher_backlit_forest_gap_2026-10-11.md. Needs a renderer:
##   tools/godot_render.sh --script tools/capture_backlit_forest.gd
## Output: build/backlit_forest/<bigoak|grove>_<stock|tuned>.png.
## CityWorld3D only: the CityMapView AO, god-ray and haze passes are not mounted.

const OUT := "res://build/backlit_forest"
const SIZE := Vector2i(1600, 754)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var plan := CityPlan.load_default()
	var viewport := SubViewport.new()
	viewport.size = SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world := CityWorld3D.create(plan)
	viewport.add_child(world)
	var camera := Camera3D.new()
	camera.far = 4000.0
	camera.near = 0.1
	viewport.add_child(camera)
	camera.current = true
	world.setup_lighting(camera)
	MapViewMaterials.apply_vegetation_season({"year": 1343, "month": 7, "day": 15})
	var sky: SkyWeather3D = world.sky_weather
	sky.auto_weather = false
	sky.set_weather(SkyWeather3D.WEATHER_CLEAR)
	var trees: Array = plan.data.get("trees", [])
	# Biggest oak and the densest stand (most trees within 25 m).
	var big: Array = []
	var dense: Array = []
	var dense_n := -1
	for t: Array in trees:
		if String(t[2]) == "oak" and (big.is_empty() or float(t[3]) > float(big[3])):
			big = t
	for i in range(0, trees.size(), 7):
		var t: Array = trees[i]
		var n := 0
		for o: Array in trees:
			if Vector2(t[0], t[1]).distance_to(Vector2(o[0], o[1])) < 25.0:
				n += 1
		if n > dense_n:
			dense_n = n
			dense = t
	print("big oak ", big, " dense ", dense, " n=", dense_n)
	var targets := [["bigoak", big], ["grove", dense]]
	for target in targets:
		var t: Array = target[1]
		var sp := StringName(String(t[2]))
		var p := Vector2(t[0], t[1])
		var g := plan.ground_height(p)
		var h := (
			CityVegetationBuilder.species_scale(sp, plan.metres_per_unit)
			* CityVegetationBuilder.size_factor(float(t[3]))
			* MapViewTreeMeshes.city_canopy_far_mesh(sp).get_aabb().end.y
		)
		var hour := 18.6
		world.apply_time(hour / 24.0)
		var to_sun := world.sun.global_transform.basis.z.normalized()
		var elev := asin(to_sun.y)
		var flat := Vector2(to_sun.x, to_sun.z).normalized()
		var crown_y := g + h * 0.65
		var dist := clampf((crown_y - g - 1.7) / tan(maxf(elev, 0.05)), 8.0, 40.0)
		var eye2 := p - flat * dist
		var eye := Vector3(eye2.x, plan.ground_height(eye2) + 1.7, eye2.y)
		print("%s h=%.1f elev=%.1f dist=%.1f" % [target[0], h, rad_to_deg(elev), dist])
		camera.fov = 75.0
		camera.look_at_from_position(eye, Vector3(p.x, g + h * 0.55, p.y), Vector3.UP)
		for variant in ["stock", "tuned"]:
			for i in 50:
				world.apply_time(hour / 24.0)
				if variant == "tuned":
					# Hypothesis probe only: dim sky fill, drop the outdoor gain, more glow.
					world.environment.ambient_light_energy *= 0.18
					world.environment.tonemap_exposure *= 0.75
					world.environment.glow_intensity = 0.6
					world.environment.glow_bloom = 0.15
					world.sun.light_energy *= 1.6
				world.grass.update_for(p)
				await process_frame
			var image := viewport.get_texture().get_image()
			var path := "%s/%s_%s.png" % [OUT, target[0], variant]
			image.save_png(ProjectSettings.globalize_path(path))
			print("captured ", path)
	quit(0)
