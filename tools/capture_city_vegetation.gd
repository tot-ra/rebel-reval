extends SceneTree

## Vegetation review plates for the seamless city (R-712 VEG pass): trees next
## to a 1.83 m reference figure (Kalev's height), needle, bark and grass close-ups,
## conifer macro crowns (R-1404) and the near/far crown LOD switch. Needs a renderer:
##   tools/godot_render.sh --script tools/capture_city_vegetation.gd [-- --tag=before]
##     [--only=<shot>[,<shot>...]] [--date=7-15]
## Output: build/vegetation/<shot>_<tag>.png (copy the ones worth keeping into
## docs/reports/images/vegetation/).

const OUTPUT_DIR := "res://build/vegetation"
const VIEWPORT_SIZE := Vector2i(1600, 900)
const DAY_PROGRESS := 0.42
const KALEV_HEIGHT := 1.83

var _tag := "now"
var _only := ""
var _date := {"year": 1343, "month": 7, "day": 15}


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tag="):
			_tag = arg.substr(6)
		elif arg.begins_with("--only="):
			_only = arg.substr(7)
		elif arg.begins_with("--date="):
			var md := arg.substr(7).split("-")
			_date = {"year": 1343, "month": int(md[0]), "day": int(md[1])}
	call_deferred("_run")


## The most open tree of a species (largest distance to its nearest neighbour
## and to any building), so the plate shows one whole tree, not a wood.
func _open_tree(plan: CityPlan, species: String) -> Dictionary:
	var trees: Array = plan.data.get("trees", [])
	var best := {}
	var best_gap := -1.0
	for t: Array in trees:
		if String(t[2]) != species:
			continue
		var p := Vector2(t[0], t[1])
		var gap := 40.0
		for o: Array in trees:
			if o == t:
				continue
			gap = minf(gap, p.distance_to(Vector2(o[0], o[1])))
		for probe in [Vector2(14, 0), Vector2(-14, 0), Vector2(0, 14), Vector2(0, -14)]:
			if plan.building_at(p + probe) >= 0:
				gap *= 0.5
		if gap > best_gap:
			best_gap = gap
			best = {"at": p, "scale": float(t[3]), "species": StringName(species)}
	return best


func _tree_height(plan: CityPlan, tree: Dictionary) -> float:
	return (
		CityVegetationBuilder.species_scale(tree["species"], plan.metres_per_unit)
		* CityVegetationBuilder.size_factor(float(tree["scale"]))
		* MapViewTreeMeshes.city_canopy_far_mesh(tree["species"]).get_aabb().end.y
	)


func _reference_figure(at: Vector3) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.height = KALEV_HEIGHT
	mesh.radius = 0.24
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.75, 0.12, 0.08)
	mesh.material = material
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at + Vector3.UP * KALEV_HEIGHT * 0.5
	return node


func _shots(plan: CityPlan) -> Array[Dictionary]:
	var shots: Array[Dictionary] = []
	for species: String in ["spruce", "pine", "pine_tall", "oak", "birch"]:
		var tree := _open_tree(plan, species)
		if tree.is_empty():
			continue
		var p: Vector2 = tree["at"]
		var g := plan.ground_height(p)
		var h := _tree_height(plan, tree)
		var side := Vector2(1, 0.35).normalized()
		var stand := p + side * 2.6
		shots.append(
			{
				"name": "%s_scale" % species,
				"figure": Vector3(stand.x, plan.ground_height(stand), stand.y),
				"eye":
				Vector3(p.x + side.x * (h * 1.25 + 6.0), g + 1.7, p.y + side.y * (h * 1.25 + 6.0)),
				"look": Vector3(p.x, g + h * 0.45, p.y),
				"fov": 55.0,
				"focus": p
			}
		)
		# Third-person gameplay distance: camera ~7 m behind and 3.5 m above Kalev.
		var kalev := p + side * 5.0
		shots.append(
			{
				"name": "%s_gameplay" % species,
				"figure": Vector3(kalev.x, plan.ground_height(kalev), kalev.y),
				"eye":
				Vector3(
					kalev.x + side.x * 7.0, plan.ground_height(kalev) + 3.6, kalev.y + side.y * 7.0
				),
				"look": Vector3(p.x, g + 2.5, p.y),
				"fov": 60.0,
				"focus": p
			}
		)
		if species in ["spruce", "pine"]:
			# R-1404 macro crown: a branch an arm's length away, where the 3D
			# needle fronds replace the flat needle cards.
			var low := g + minf(h * 0.35, 4.0)
			var eye := Vector3(p.x + side.x * 2.6, low + 0.2, p.y + side.y * 2.6)
			var look := Vector3(p.x + side.x * 1.2, low - 0.3, p.y + side.y * 1.2)
			if species == "pine":
				# The pine crown is high: stand inside its lowest limbs.
				eye = Vector3(p.x + side.x * 1.2 + 1.0, g + h * 0.78 - 0.3, p.y + side.y * 1.2 - 1.6)
				look = Vector3(p.x + side.x * 2.6 + 1.0, g + h * 0.78, p.y + side.y * 2.6)
			shots.append(
				{"name": "%s_macro" % species, "eye": eye, "look": look, "fov": 60.0, "focus": p}
			)
			# Close-up of the lower crown edge, where the user saw flat needle sheets.
			shots.append(
				{
					"name": "%s_needles_close" % species,
					"eye": Vector3(p.x + side.x * 3.4, g + minf(h * 0.35, 4.0), p.y + side.y * 3.4),
					"look": Vector3(p.x, g + minf(h * 0.4, 5.0), p.y),
					"fov": 60.0,
					"focus": p
				}
			)
		shots.append(
			{
				"name": "%s_bark_close" % species,
				"eye": Vector3(p.x + side.x * 1.4, g + 1.4, p.y + side.y * 1.4),
				"look": Vector3(p.x, g + 1.1, p.y),
				"fov": 55.0,
				"focus": p
			}
		)
		if species == "oak":
			# Far view of a whole stand: exercises the far crown LOD.
			shots.append(
				{
					"name": "stand_far",
					"eye": Vector3(p.x + side.x * 120.0, g + 25.0, p.y + side.y * 120.0),
					"look": Vector3(p.x, g + 4.0, p.y),
					"fov": 50.0,
					"focus": p
				}
			)
			# Ground: grass beside the oak at eye level and from the gameplay camera.
			var meadow := p + side * 9.0
			var mg := plan.ground_height(meadow)
			shots.append(
				{
					"name": "grass_eye",
					"figure": Vector3(meadow.x, mg, meadow.y),
					"eye":
					Vector3(meadow.x + side.x * 4.0, mg + 1.7, meadow.y + side.y * 4.0 + 1.0),
					"look": Vector3(meadow.x, mg + 0.6, meadow.y),
					"fov": 60.0,
					"focus": meadow
				}
			)
			shots.append(
				{
					"name": "grass_wide",
					"figure": Vector3(meadow.x, mg, meadow.y),
					"eye": Vector3(meadow.x + side.x * 14.0, mg + 8.0, meadow.y + side.y * 14.0),
					"look": Vector3(meadow.x, mg, meadow.y),
					"fov": 60.0,
					"focus": meadow
				}
			)
	shots.append_array(_heath_and_bridge_shots(plan))
	# Shrub close-ups beside the reference figure: two drawn with the city bush
	# variants (rose, raspberry) and elder, drawn with the shrub tree meshes.
	for species: String in ["dog_rose", "raspberry", "elder"]:
		var bush := _open_bush(plan, species)
		if bush.is_empty():
			continue
		var b: Vector2 = bush["at"]
		var bg := plan.ground_height(b)
		var side := Vector2(1, 0.35).normalized()
		# Elder is a 3 m tree-mesh shrub: stand back so the camera is outside it.
		var back := 6.5 if species == "elder" else 3.6
		var stand := b + side.orthogonal() * (2.6 if species == "elder" else 1.4)
		shots.append(
			{
				"name": "%s_close" % species,
				"figure": Vector3(stand.x, plan.ground_height(stand), stand.y),
				"eye": Vector3(b.x + side.x * back, bg + 1.6, b.y + side.y * back),
				"look": Vector3(b.x, bg + 0.9, b.y),
				"fov": 55.0,
				"focus": b
			}
		)
	return shots


## R-1617: inside the sandy-coast pine heath at eye level (the mature pines
## beside the reference figure) and the Hareapea road bridges, whose decks no
## tree may grow through.
func _heath_and_bridge_shots(plan: CityPlan) -> Array[Dictionary]:
	var shots: Array[Dictionary] = []
	var tall: Array[Vector2] = []
	for t: Array in plan.data.get("trees", []):
		if String(t[2]) == "pine_tall":
			tall.append(Vector2(t[0], t[1]))
	var best := Vector2.ZERO
	var best_n := -1
	for i in range(0, tall.size(), 4):
		var n := 0
		for q in tall:
			if q.distance_to(tall[i]) < 30.0:
				n += 1
		if n > best_n:
			best_n = n
			best = tall[i]
	if best_n > 0:
		var side := Vector2(1, 0.35).normalized()
		var stand := best + side * 3.0
		var sg := plan.ground_height(stand)
		shots.append({
			"name": "pine_heath_eye", "figure": Vector3(stand.x, sg, stand.y),
			"eye": Vector3(stand.x + side.x * 9.0, sg + 1.7, stand.y + side.y * 9.0),
			"look": Vector3(best.x, sg + 7.0, best.y), "fov": 70.0, "focus": best
		})
		shots.append({
			"name": "pine_heath_wide",
			"eye": Vector3(best.x + side.x * 90.0, sg + 22.0, best.y + side.y * 90.0),
			"look": Vector3(best.x, sg + 8.0, best.y), "fov": 55.0, "focus": best
		})
	for b: Dictionary in plan.data.get("bridges", []):
		var id := String(b["id"])
		if not id.begins_with("bridge.") or id.begins_with("bridge.moat"):
			continue
		var at := Vector2(b["at"][0], b["at"][1])
		var across := Vector2.from_angle(float(b["angle"])).orthogonal()
		var eye := at + across * 34.0 + Vector2.from_angle(float(b["angle"])) * 10.0
		var g := plan.ground_height(at)
		# Raised above the bank alders so the whole deck is in view.
		shots.append({
			"name": "bridge_clear_%s" % id.trim_prefix("bridge."),
			"eye": Vector3(eye.x, g + 14.0, eye.y), "look": Vector3(at.x, g + 1.0, at.y),
			"fov": 60.0, "focus": at
		})
	return shots


## The plan shrub of a species farthest from other shrubs, trees and buildings.
func _open_bush(plan: CityPlan, species: String) -> Dictionary:
	var others: Array = plan.data.get("trees", []) + plan.data.get("bushes", [])
	var best := {}
	var best_gap := -1.0
	for t: Array in plan.data.get("bushes", []):
		if String(t[2]) != species:
			continue
		var p := Vector2(t[0], t[1])
		var gap := 12.0
		for o: Array in others:
			if o != t:
				gap = minf(gap, p.distance_to(Vector2(o[0], o[1])))
		for probe in [Vector2(5, 0), Vector2(-5, 0), Vector2(0, 5), Vector2(0, -5)]:
			if plan.building_at(p + probe) >= 0:
				gap *= 0.5
		if gap > best_gap:
			best_gap = gap
			best = {"at": p}
	return best


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var plan := CityPlan.load_default()
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
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
	MapViewMaterials.apply_vegetation_season(_date)
	var figure: MeshInstance3D = null
	for shot in _shots(plan):
		if not _only.is_empty() and not shot["name"] in _only.split(","):
			continue
		if figure != null:
			figure.queue_free()
			figure = null
		if shot.has("figure"):
			figure = _reference_figure(shot["figure"])
			viewport.add_child(figure)
		camera.fov = shot["fov"]
		camera.look_at_from_position(shot["eye"], shot["look"], Vector3.UP)
		world.apply_time(DAY_PROGRESS)
		# Grass streams one chunk per frame around the focus point.
		for i in 60:
			world.grass.update_for(shot["focus"])
			await process_frame
		var image := viewport.get_texture().get_image()
		var path := "%s/%s_%s.png" % [OUTPUT_DIR, shot["name"], _tag]
		image.save_png(ProjectSettings.globalize_path(path))
		var lod := world.get_node_or_null("Vegetation/TreeLod") as CityTreeLod
		print("captured %s (near crowns: %d)" % [path, lod.near_count() if lod != null else -1])
	quit(0)
