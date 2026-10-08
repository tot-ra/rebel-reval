extends "res://tests/godot/test_case.gd"

const Openings := preload("res://scripts/city/city_window_openings.gd")


func _window() -> Dictionary:
	return {
		"m": Vector2(3, 0),
		"dir": Vector2.RIGHT,
		"nrm": Vector2(0, 1),
		"w": 0.72,
		"h": 0.95,
		"y": 1.05,
		"base_y": 1.05,
		"jitter": 0.6,
		"style": &"plain",
		"look":
		{
			"trim": Color(0.6, 0.4, 0.2),
			"shutter": Color(0.4, 0.3, 0.2),
			"panes": 2,
			"glazing": &"forest"
		}
	}


func _wall() -> CityBuildingBuilder.Shell:
	var shell := CityBuildingBuilder.Shell.new()
	shell.quad_out(
		"wall:plank",
		Vector3(0, 0, 0),
		Vector3(6, 0, 0),
		Vector3(6, 3, 0),
		Vector3(0, 3, 0),
		Color.WHITE,
		Vector3.BACK
	)
	shell.quad_out(
		"interior",
		Vector3(0, 0, -0.32),
		Vector3(6, 0, -0.32),
		Vector3(6, 3, -0.32),
		Vector3(0, 3, -0.32),
		Color.WHITE,
		Vector3.FORWARD
	)
	return shell


func _area(surface: CityBuildingBuilder.Surf) -> float:
	var result := 0.0
	for i in range(0, surface.verts.size(), 3):
		result += (
			(
				(surface.verts[i + 1] - surface.verts[i])
				. cross(surface.verts[i + 2] - surface.verts[i])
				. length()
			)
			* 0.5
		)
	return result


func _covers(surface: CityBuildingBuilder.Surf, p: Vector3) -> bool:
	for i in range(0, surface.verts.size(), 3):
		var a := surface.verts[i]
		var b := surface.verts[i + 1]
		var c := surface.verts[i + 2]
		if absf((p - a).dot(surface.normals[i])) > 0.001:
			continue
		if Geometry2D.is_point_in_polygon(
			Vector2(p.x, p.y),
			PackedVector2Array([Vector2(a.x, a.y), Vector2(b.x, b.y), Vector2(c.x, c.y)])
		):
			return true
	return false


func test_cut_removes_exact_aperture_from_both_wall_faces() -> void:
	var shell := _wall()
	var windows: Array[Dictionary] = [_window()]
	Openings.cut(shell, windows, 0.32)
	for key: String in ["wall:plank", "interior"]:
		var face := shell.surface(key)
		assert_almost_eq(_area(face), 18.0 - 0.72 * 0.95, 0.0001, key)
		var depth := 0.0 if key == "wall:plank" else -0.32
		assert_false(_covers(face, Vector3(3, 1.5, depth)), "centre is a real hole")
		assert_true(_covers(face, Vector3(1, 1.5, depth)), "wall beside hole survives")
		for normal in face.normals:
			assert_almost_eq(normal.length(), 1.0, 0.001, "normals survive clipping")


func test_interior_sill_projects_past_inner_wall_and_glass_is_two_sided() -> void:
	var shell := CityBuildingBuilder.Shell.new()
	CityWindows.add_placed(shell, _window())
	CityWindows.add_interior(shell, _window(), 0.62)
	var min_z := 0.0
	for v in shell.surface("paint").verts:
		min_z = minf(min_z, v.z)
	assert_almost_eq(min_z, -0.8, 0.001, "18 cm interior sill on 62 cm wall")
	var horn := CityBuildingBuilder.glass_material(&"horn") as ShaderMaterial
	var forest := CityBuildingBuilder.glass_material(&"forest") as ShaderMaterial
	var clear := CityBuildingBuilder.glass_material(&"clear") as ShaderMaterial
	assert_true(horn.get_shader_parameter("opacity") > forest.get_shader_parameter("opacity"))
	assert_true(forest.get_shader_parameter("opacity") > clear.get_shader_parameter("opacity"))
	assert_true(clear.shader.code.contains("cull_disabled"), "visible from both sides")


func test_closed_shutters_occlude_inside_and_open_holes_have_no_fake_glass() -> void:
	var window := _window()
	window["style"] = &"shutters_closed"
	var shell := CityBuildingBuilder.Shell.new()
	CityWindows.add_placed(shell, window)
	assert_true(_covers(shell.surface("paint"), Vector3(3, 1.5, 0.06)), "solid back")
	window["look"]["glazing"] = &"open"
	window["style"] = &"plain"
	shell = CityBuildingBuilder.Shell.new()
	CityWindows.add_placed(shell, window)
	assert_false(shell.surfaces.has("opening"), "no opaque backdrop")
	assert_false(shell.surfaces.has("glass:open"), "unglazed hole is empty")


func test_low_cottage_placements_fit_and_avoid_door() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 6
	var house_look := CityWindows.look(rng, &"log")
	var windows := CityWindows.placements(
		Vector2.ZERO, Vector2(12, 0), 0.0, 2.6, Vector2(0.4, 0.6), rng, house_look
	)
	assert_true(windows.size() > 0)
	for window in windows:
		assert_true(window["y"] + window["h"] + 0.18 <= 2.55, "below eaves")
		var centre: Vector2 = window["m"]
		assert_true(centre.x < 3.4 or centre.x > 8.6, "no overlap with doorway")


func test_building_integration_cuts_both_faces_without_touching_site_models() -> void:
	var ring := PackedVector2Array([Vector2(0, 0), Vector2(0, 8), Vector2(10, 8), Vector2(10, 0)])
	var b := {
		"id": "test.windows",
		"material": "limestone",
		"roof": "shingle",
		"base_h": 0.0,
		"wall_h": 4.0,
		"ridge_angle": 0.0,
		"roof_pitch_deg": 40.0
	}
	var first := CityBuildingBuilder.build_building(b, ring, 0.0, true)
	var second := CityBuildingBuilder.build_building(b, ring, 0.0, true)
	var shell: CityBuildingBuilder.Shell = first["shell"]
	assert_eq(shell.surface("paint").verts, second["shell"].surface("paint").verts)
	assert_eq(first["chimney"], second["chimney"])
	var glass_key := ""
	for key: String in shell.surfaces:
		if key.begins_with("glass:"):
			glass_key = key
	assert_false(glass_key.is_empty(), "builder mounts actual glazing")
	b["openings"] = false
	var site := CityBuildingBuilder.build_building(b, ring, 0.0, true)
	assert_false(site["shell"].surfaces.has(glass_key), "custom site openings stay untouched")


func test_rotated_aperture_preserves_uvs_and_far_parallel_wall() -> void:
	var shell := _wall()
	var window := _window()
	var rotation := Basis(Vector3.UP, 0.63)
	for key: String in shell.surfaces:
		var face := shell.surface(key)
		for i in face.verts.size():
			face.uvs[i] = Vector2(face.verts[i].x, face.verts[i].y)
			face.verts[i] = rotation * face.verts[i]
			face.normals[i] = rotation * face.normals[i]
	var centre := rotation * Vector3(3, 0, 0)
	var along := rotation * Vector3.RIGHT
	var out := rotation * Vector3.BACK
	window["m"] = Vector2(centre.x, centre.z)
	window["dir"] = Vector2(along.x, along.z)
	window["nrm"] = Vector2(out.x, out.z)
	var far := CityBuildingBuilder.Surf.new()
	far.absorb(shell.surface("wall:plank"), out * -8.0)
	shell.surfaces["wall:far"] = far
	var windows: Array[Dictionary] = [window]
	Openings.cut(shell, windows, 0.32)
	assert_almost_eq(_area(shell.surface("wall:far")), 18.0, 0.001, "far wall unchanged")
	for key: String in ["wall:plank", "interior"]:
		var face := shell.surface(key)
		assert_almost_eq(_area(face), 18.0 - 0.72 * 0.95, 0.001, "rotated hole")
		for i in face.verts.size():
			var local := rotation.inverse() * face.verts[i]
			assert_almost_eq(face.uvs[i].x, local.x, 0.001, "interpolated u")
			assert_almost_eq(face.uvs[i].y, local.y, 0.001, "interpolated v")


func test_actual_plan_house_glass_centres_have_no_wall_backing() -> void:
	var plan := CityPlan.load_default()
	for family: String in ["log", "plank", "limestone"]:
		var checked := false
		for i in plan.buildings.size():
			var b: Dictionary = plan.buildings[i]
			if b.get("material", "") != family or b.get("kind", "") != "house":
				continue
			if not b.get("openings", true):
				continue
			var built := CityBuildingBuilder.build_building(
				b, plan.footprint(i), plan.floor_height(i), true
			)
			var shell: CityBuildingBuilder.Shell = built["shell"]
			for key: String in shell.surfaces:
				if not key.begins_with("glass:"):
					continue
				var glass := shell.surface(key)
				for j in range(0, glass.verts.size(), 6):
					var centre := Vector3.ZERO
					for vertex in range(j, j + 6):
						centre += glass.verts[vertex]
					centre /= 6.0
					var out := glass.normals[j]
					var start := centre - out
					var end := centre + out * 0.1
					for wall_key: String in shell.surfaces:
						if not wall_key.begins_with("wall:") and wall_key != "interior":
							continue
						var wall := shell.surface(wall_key)
						for k in range(0, wall.verts.size(), 3):
							var hit: Variant = Geometry3D.segment_intersects_triangle(
								start, end, wall.verts[k], wall.verts[k + 1], wall.verts[k + 2]
							)
							assert_true(hit == null, "%s: no wall behind pane" % b["id"])
				checked = true
			if checked:
				break
		assert_true(checked, "%s plan house has tested glazing" % family)
