extends "res://tests/godot/test_case.gd"

## R-1655: thin skyline strips must not bridge courtyards. Audit generated
## geometry, not just the helper's return value, so _roof cannot bypass clipping.
const Builder := preload("res://scripts/city/city_building_builder.gd")
const MAX_SPAN_M := 8.0
const THIN_M := 0.08


func test_city_ridge_caps_are_supported_by_the_roof() -> void:
	var plan := CityPlan.load_default()
	var context := CityWorld3D.new()
	context.plan = plan
	var checked := 0
	var offenders: Array[String] = []
	for i in plan.buildings.size():
		var b: Dictionary = plan.buildings[i]
		var ring := Builder.wall_ring(b, plan.footprint(i))
		var frame := Builder.roof_frame(
			ring, b["ridge_angle"], plan.floor_height(i) + float(b["wall_h"]), Builder.roof_pitch(b)
		)
		var outline: PackedVector2Array = Geometry2D.offset_polygon(
			ring, Builder.OVERHANG, Geometry2D.JOIN_MITER
		)[0]
		var keep_out := context._site_keep_out(ring)
		for poly in keep_out:
			var best := -1.0
			for piece in Geometry2D.clip_polygons(outline, poly):
				var area := absf(Builder.signed_area(piece))
				if area > best:
					best = area
					outline = piece
		var shell := Builder.Shell.new()
		Builder._roof(shell, "roof:tile", ring, frame, Color.WHITE, &"tile", keep_out)
		var surf: Builder.Surf = shell.surface("roof:tile")
		var cap_color := Color(0.9, 0.9, 0.9, 1.0)
		for t in range(0, surf.verts.size(), 3):
			if not surf.colors[t].is_equal_approx(cap_color):
				continue
			checked += 1
			# Project the cap's radial thickness back onto its centreline.
			# Endpoints AND interior samples catch a cap spanning a concave notch.
			var a := surf.verts[t]
			var c := surf.verts[t + 1]
			var d := surf.verts[t + 2]
			var valid := true
			for p: Vector3 in [a, c, d, (a + c) * 0.5, (a + d) * 0.5, (a + c + d) / 3.0]:
				var r: Vector2 = frame["r"]
				var n: Vector2 = frame["n"]
				var q := r * Vector2(p.x, p.z).dot(r) + n * float(frame["mid"])
				if not _inside_or_boundary(q, outline):
					valid = false
			if not valid:
				offenders.append(String(b["id"]))
				break
	context.free()
	assert_true(checked > 1000, "audit actual ridge geometry throughout the city")
	assert_eq(offenders, [], "unsupported ridge caps: %s" % [offenders])


func test_concave_rotated_roof_keeps_separate_ridge_runs() -> void:
	# A 12 m courtyard gap, translated far from the origin and rotated, as
	# in the real OSM footprints. Also covers reversed polygon winding.
	var shape := PackedVector2Array([
		Vector2(0, 0), Vector2(32, 0), Vector2(32, 12), Vector2(22, 12),
		Vector2(22, 3), Vector2(10, 3), Vector2(10, 12), Vector2(0, 12),
	])
	for i in shape.size():
		shape[i] = shape[i].rotated(0.63) + Vector2(130, -450)
	for reverse in [false, true]:
		if reverse:
			shape.reverse()
		var frame := Builder.roof_frame(shape, 0.63, 10.0, 50.0)
		var spans := Builder._ridge_spans(shape, frame)
		assert_eq(spans.size(), 2, "no ridge over the courtyard")
		for span in spans:
			assert_almost_eq(span.y - span.x, 10.0, 0.01)
		var outside := PackedVector2Array([
			Vector2(1000, 1000), Vector2(1001, 1000), Vector2(1001, 1001),
		])
		assert_true(Builder._ridge_spans(outside, frame).is_empty())


func test_city_thin_bars_and_ropes_have_bounded_spans() -> void:
	var world := CityWorld3D.create(CityPlan.load_default())
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(world)
	var offenders: Array[String] = []
	var ropes := 0
	var triangles := 0
	for node: Node in world.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		var path := String(world.get_path_to(mi))
		var scale := mi.global_basis.get_scale().abs()
		var scale_max := maxf(scale.x, maxf(scale.y, scale.z))
		if mi.has_meta(&"rope_length"):
			ropes += 1
			assert_true(
				float(mi.get_meta(&"rope_length")) * scale_max <= MAX_SPAN_M,
				"%s: hoist rope exceeds 8 m" % path
			)
		# Individual bar/rope primitives are audited regardless of material.
		var size := Vector3.ZERO
		if mi.mesh is BoxMesh:
			size = (mi.mesh as BoxMesh).size * scale
		elif mi.mesh is CylinderMesh:
			var cylinder := mi.mesh as CylinderMesh
			var diameter := 2.0 * maxf(cylinder.top_radius, cylinder.bottom_radius)
			size = Vector3(diameter, cylinder.height, diameter) * scale
		var dimensions := [size.x, size.y, size.z]
		dimensions.sort()
		if dimensions[1] <= THIN_M and dimensions[2] > MAX_SPAN_M:
			offenders.append("%s: primitive %.2f m" % [path, dimensions[2]])
		# Kit.bar is merged into timber/dark surfaces. Do not mistake a long
		# wall, floor or roof face for a rope just because one triangle is thin.
		for surface in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(surface)
			if (
				mat != CitySiteKit.material_for("timber")
				and mat != CitySiteKit.material_for("dark")
				and mat != CogRig.rope_material()
			):
				continue
			var arrays := mi.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = PackedInt32Array()
			if arrays[Mesh.ARRAY_INDEX] != null:
				indices = arrays[Mesh.ARRAY_INDEX]
			var count := indices.size() if not indices.is_empty() else vertices.size()
			for t in range(0, count - 2, 3):
				var a := vertices[indices[t] if not indices.is_empty() else t]
				var b := vertices[indices[t + 1] if not indices.is_empty() else t + 1]
				var c := vertices[indices[t + 2] if not indices.is_empty() else t + 2]
				var wa := mi.global_basis * a
				var wb := mi.global_basis * b
				var wc := mi.global_basis * c
				var edges := [wa.distance_to(wb), wb.distance_to(wc), wc.distance_to(wa)]
				edges.sort()
				if edges[0] > THIN_M + 0.001:
					continue
				triangles += 1
				if edges[2] > MAX_SPAN_M and not _named_exception(path, a, b, c, edges[2]):
					offenders.append("%s: thin span %.2f m at %s" % [path, edges[2], a])
					break
	world.free()
	assert_true(ropes > 20, "real city dressing is present")
	assert_true(triangles > 1000, "merged bars/ropes are inspected")
	assert_eq(offenders, [], "overlong thin spans: %s" % [offenders])


func _named_exception(path: String, a: Vector3, b: Vector3, c: Vector3, span: float) -> bool:
	# Named, bounded exceptions, not a blanket waiver for an entire building.
	if path.begins_with("Ships/") and path.ends_with("/Cog/Rigging"):
		return span <= 32.0  # standing/running rigging of the 21 m cog
	if path.begins_with("Site_st_olaf/Church/Roof"):
		return span <= 30.31 and _within(
			a, b, c, AABB(Vector3(2.97, 1.19, -11.53), Vector3(0.06, 30.32, 0.06))
		)  # vertical scaffold hoist from its jib to the yard
	if path.begins_with("Site_st_mary/Cathedral/"):
		# Supported stall rails, porch stair edges, scaffold platform edges.
		for box: AABB in [
			AABB(Vector3(-5.21, 0.99, -9.11), Vector3(13.22, 0.1, 18.22)),
			AABB(Vector3(-14.66, 0.0, -16.61), Vector3(0.32, 2.41, 12.92)),
			AABB(Vector3(-27.41, 2.45, -19.31), Vector3(12.22, 5.1, 35.62)),
		]:
			if span <= 13.21 and _within(a, b, c, box):
				return true
	return false


func _within(a: Vector3, b: Vector3, c: Vector3, box: AABB) -> bool:
	return box.has_point(a) and box.has_point(b) and box.has_point(c)


func _inside_or_boundary(p: Vector2, polygon: PackedVector2Array) -> bool:
	if Geometry2D.is_point_in_polygon(p, polygon):
		return true
	for i in polygon.size():
		var closest := Geometry2D.get_closest_point_to_segment(
			p, polygon[i], polygon[(i + 1) % polygon.size()]
		)
		if p.distance_to(closest) < 0.002:
			return true
	return false
