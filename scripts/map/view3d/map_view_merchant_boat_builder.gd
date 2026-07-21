class_name MapViewMerchantBoatBuilder
extends RefCounted

## Procedural fourteenth-century Baltic trading cog used by the 3D map view.


static func add_to(root: Node3D) -> void:
	# A deep clinker-built hull and open timber castles preserve the period
	# silhouette while keeping the working cargo deck visible from above.
	var hull := MeshInstance3D.new()
	hull.name = "Hull"
	hull.mesh = _hull_mesh()
	hull.material_override = MapViewMeshBuilderPrimitives.role_material(&"wood")
	root.add_child(hull)

	_add_hull_timber(root)
	_add_deck(root)
	_add_castle(root, "Aftcastle", -2.35, -1.5, 1.42, 1.02)
	_add_castle(root, "Forecastle", 1.95, 2.85, 1.38, 0.88)
	_add_cargo(root)
	_add_rig(root)

	_add_spar(root, "Bowsprit", Vector3(2.66, 1.25, 0.0), Vector3(4.18, 1.83, 0.0), 0.07, &"timber")
	MapViewMeshBuilderPrimitives.box(root, "Rudder", Vector3(0.12, 0.9, 0.52), Vector3(-3.4, 0.32, 0.0), &"timber")
	_add_spar(root, "Tiller", Vector3(-3.34, 0.73, 0.0), Vector3(-2.45, 1.32, 0.0), 0.045, &"timber")


static func _add_cargo(root: Node3D) -> void:
	MapViewMeshBuilderPrimitives.box(root, "CargoHatch", Vector3(1.35, 0.1, 1.05), Vector3(0.72, 1.08, 0.0), &"ink")
	for side in [-1.0, 1.0]:
		var side_name := "Port" if side < 0.0 else "Starboard"
		_add_spar(root, "HatchCoaming%s" % side_name, Vector3(0.02, 1.16, side * 0.59), Vector3(1.42, 1.16, side * 0.59), 0.045, &"timber")
	_add_spar(root, "HatchCoamingAft", Vector3(0.02, 1.16, -0.59), Vector3(0.02, 1.16, 0.59), 0.045, &"timber")
	_add_spar(root, "HatchCoamingFore", Vector3(1.42, 1.16, -0.59), Vector3(1.42, 1.16, 0.59), 0.045, &"timber")
	MapViewMeshBuilderPrimitives.box(root, "CargoCrateLarge", Vector3(0.72, 0.62, 0.66), Vector3(-0.76, 1.34, -0.42), &"wood")
	MapViewMeshBuilderPrimitives.box(root, "CargoCrateSmall", Vector3(0.52, 0.46, 0.5), Vector3(-0.84, 1.26, 0.42), &"timber")


static func _add_rig(root: Node3D) -> void:
	# One mast and one broad square sail are defining cog features. The sail bows
	# in front of the mast and uses panel value changes instead of a flat box.
	_add_spar(root, "Mast", Vector3(-0.18, 0.76, 0.0), Vector3(-0.18, 6.25, 0.0), 0.105, &"timber")
	_add_spar(root, "Yard", Vector3(-0.14, 5.48, -2.18), Vector3(-0.14, 5.48, 2.18), 0.075, &"timber")
	var sail := MeshInstance3D.new()
	sail.name = "SquareSail"
	sail.mesh = _sail_mesh()
	# Cloth must stay visible when the map camera rotates behind it, while vertex
	# colors provide subtle alternating panels without a ship-specific texture.
	# Wind-driven billow comes from the shared world wind cloth shader.
	sail.material_override = MapViewMaterials.sail_cloth()
	root.add_child(sail)

	var rigging := Node3D.new()
	rigging.name = "Rigging"
	root.add_child(rigging)
	_add_spar(rigging, "Forestay", Vector3(-0.18, 6.16, 0.0), Vector3(3.32, 1.28, 0.0), 0.018, &"ink")
	_add_spar(rigging, "Backstay", Vector3(-0.18, 6.16, 0.0), Vector3(-3.08, 1.24, 0.0), 0.018, &"ink")
	for side in [-1.0, 1.0]:
		var side_name := "Port" if side < 0.0 else "Starboard"
		_add_spar(rigging, "Shroud%sA" % side_name, Vector3(-0.18, 5.35, 0.0), Vector3(-0.82, 1.04, side * 1.34), 0.018, &"ink")
		_add_spar(rigging, "Shroud%sB" % side_name, Vector3(-0.18, 5.0, 0.0), Vector3(0.18, 1.02, side * 1.4), 0.018, &"ink")
		_add_spar(rigging, "YardLift%s" % side_name, Vector3(-0.18, 6.12, 0.0), Vector3(-0.14, 5.48, side * 2.18), 0.014, &"ink")
		_add_spar(rigging, "Sheet%s" % side_name, Vector3(0.1, 2.96, side * 1.62), Vector3(-2.22, 1.48, side * 0.86), 0.014, &"ink")


## A faceted station-built shell gives the ship a full cargo-carrying midsection,
## a deep keel and narrow ends. The open top is closed by a separate tapered deck.
static func _hull_mesh() -> ArrayMesh:
	var stations: Array[Vector4] = [
		Vector4(-3.42, 0.18, -0.2, 1.14),
		Vector4(-2.78, 1.08, -0.48, 1.05),
		Vector4(-1.52, 1.43, -0.64, 1.0),
		Vector4(0.0, 1.55, -0.69, 1.0),
		Vector4(1.52, 1.42, -0.6, 1.05),
		Vector4(2.74, 0.96, -0.4, 1.16),
		Vector4(3.48, 0.14, 0.08, 1.36),
	]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for station_index in stations.size() - 1:
		var aft := _hull_section(stations[station_index])
		var fore := _hull_section(stations[station_index + 1])
		for section_index in aft.size() - 1:
			_add_mesh_quad(surface, aft[section_index], fore[section_index], fore[section_index + 1], aft[section_index + 1])
	# Close the narrow stem faces without filling the open deck.
	for station_index in [0, stations.size() - 1]:
		var section := _hull_section(stations[station_index])
		for section_index in range(1, section.size() - 1):
			_add_mesh_triangle(surface, section[0], section[section_index], section[section_index + 1])
	surface.generate_normals()
	return surface.commit()


static func _hull_section(station: Vector4) -> Array[Vector3]:
	var chine_y := lerpf(station.z, station.w, 0.43)
	var chine_half_beam := station.y * 0.72
	return [
		Vector3(station.x, station.w, -station.y),
		Vector3(station.x, chine_y, -chine_half_beam),
		Vector3(station.x, station.z, 0.0),
		Vector3(station.x, chine_y, chine_half_beam),
		Vector3(station.x, station.w, station.y),
	]


static func _add_hull_timber(root: Node3D) -> void:
	_add_spar(root, "Keel", Vector3(-3.22, -0.48, 0.0), Vector3(3.24, -0.38, 0.0), 0.075, &"timber")
	_add_spar(root, "Sternpost", Vector3(-3.26, -0.34, 0.0), Vector3(-3.43, 1.24, 0.0), 0.07, &"timber")
	_add_spar(root, "BowStem", Vector3(3.22, -0.26, 0.0), Vector3(3.51, 1.48, 0.0), 0.075, &"timber")
	var rail_stations: Array[Vector3] = [
		Vector3(-3.18, 0.84, 0.48),
		Vector3(-2.68, 0.72, 1.08),
		Vector3(-1.45, 0.68, 1.4),
		Vector3(0.0, 0.68, 1.52),
		Vector3(1.48, 0.72, 1.38),
		Vector3(2.68, 0.84, 0.94),
		Vector3(3.3, 1.13, 0.28),
	]
	for side in [-1.0, 1.0]:
		var side_name := "Port" if side < 0.0 else "Starboard"
		for rail_index in rail_stations.size() - 1:
			var start := rail_stations[rail_index]
			var end := rail_stations[rail_index + 1]
			start.z *= side
			end.z *= side
			_add_spar(root, "ClinkerStrake%s%d" % [side_name, rail_index], start, end, 0.035, &"timber")
		for rail_index in rail_stations.size() - 1:
			var start := rail_stations[rail_index]
			var end := rail_stations[rail_index + 1]
			start.y += 0.3
			end.y += 0.3
			start.z = start.z * side * 1.015
			end.z = end.z * side * 1.015
			_add_spar(root, "Gunwale%s%d" % [side_name, rail_index], start, end, 0.05, &"timber")


static func _add_deck(root: Node3D) -> void:
	var deck := MeshInstance3D.new()
	deck.name = "Deck"
	deck.mesh = _deck_mesh([
		Vector2(-3.02, 0.5),
		Vector2(-2.55, 1.0),
		Vector2(-1.3, 1.26),
		Vector2(0.0, 1.34),
		Vector2(1.42, 1.24),
		Vector2(2.56, 0.9),
		Vector2(3.08, 0.4),
	], 1.01)
	deck.material_override = MapViewMeshBuilderPrimitives.role_material(&"timber")
	root.add_child(deck)


static func _add_castle(root: Node3D, node_name: String, aft_x: float, fore_x: float, deck_y: float, half_beam: float) -> void:
	var castle := Node3D.new()
	castle.name = node_name
	root.add_child(castle)
	var platform := MeshInstance3D.new()
	platform.name = "Platform"
	platform.mesh = _deck_mesh([
		Vector2(aft_x, half_beam * 0.82),
		Vector2(fore_x, half_beam),
	], deck_y)
	platform.material_override = MapViewMeshBuilderPrimitives.role_material(&"timber")
	castle.add_child(platform)
	var post_height := 0.52
	for side in [-1.0, 1.0]:
		var side_name := "Port" if side < 0.0 else "Starboard"
		var side_z: float = half_beam * float(side)
		for post_index in 3:
			var t := float(post_index) / 2.0
			var x := lerpf(aft_x, fore_x, t)
			_add_spar(castle, "Post%s%d" % [side_name, post_index], Vector3(x, deck_y, side_z), Vector3(x, deck_y + post_height, side_z), 0.035, &"timber")
		_add_spar(castle, "Rail%s" % side_name, Vector3(aft_x, deck_y + post_height, side_z), Vector3(fore_x, deck_y + post_height, side_z), 0.04, &"timber")
	_add_spar(castle, "EndRail", Vector3(aft_x, deck_y + post_height, -half_beam * 0.82), Vector3(aft_x, deck_y + post_height, half_beam * 0.82), 0.04, &"timber")


static func _deck_mesh(profile: Array[Vector2], deck_y: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in profile.size() - 1:
		var aft := profile[index]
		var fore := profile[index + 1]
		_add_mesh_quad(
			surface,
			Vector3(aft.x, deck_y, -aft.y),
			Vector3(aft.x, deck_y, aft.y),
			Vector3(fore.x, deck_y, fore.y),
			Vector3(fore.x, deck_y, -fore.y)
		)
	surface.generate_normals()
	return surface.commit()


static func _sail_mesh() -> ArrayMesh:
	var row_heights := [5.31, 4.52, 3.72, 2.96]
	var row_half_widths := [1.92, 1.86, 1.74, 1.62]
	var row_bulges := [0.02, 0.2, 0.29, 0.1]
	const COLUMN_COUNT := 6
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in row_heights.size() - 1:
		for column in COLUMN_COUNT:
			var left_t := float(column) / float(COLUMN_COUNT)
			var right_t := float(column + 1) / float(COLUMN_COUNT)
			var vertices := [
				_sail_point(row_heights[row], row_half_widths[row], row_bulges[row], left_t),
				_sail_point(row_heights[row], row_half_widths[row], row_bulges[row], right_t),
				_sail_point(row_heights[row + 1], row_half_widths[row + 1], row_bulges[row + 1], right_t),
				_sail_point(row_heights[row + 1], row_half_widths[row + 1], row_bulges[row + 1], left_t),
			]
			var panel_tone := 0.9 + 0.035 * float((row + column) % 2)
			for vertex_index in [0, 1, 2, 0, 2, 3]:
				surface.set_color(Color(panel_tone, panel_tone * 0.98, panel_tone * 0.9))
				surface.set_uv(Vector2(left_t if vertex_index in [0, 3] else right_t, float(row + (1 if vertex_index in [2, 3] else 0)) / float(row_heights.size() - 1)))
				surface.add_vertex(vertices[vertex_index])
	surface.generate_normals()
	return surface.commit()


static func _sail_point(height: float, half_width: float, bulge: float, horizontal_t: float) -> Vector3:
	var centered := horizontal_t * 2.0 - 1.0
	return Vector3(-0.14 + bulge * (1.0 - centered * centered), height, centered * half_width)


static func _add_spar(parent: Node3D, node_name: String, start: Vector3, end: Vector3, radius: float, role: StringName) -> void:
	var direction := end - start
	if direction.is_zero_approx():
		return
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = direction.length()
	mesh.radial_segments = 6
	mesh.rings = 1
	instance.mesh = mesh
	instance.position = (start + end) * 0.5
	instance.quaternion = Quaternion(Vector3.UP, direction.normalized())
	instance.material_override = MapViewMeshBuilderPrimitives.role_material(role)
	parent.add_child(instance)


static func _add_mesh_quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for vertex in [a, b, c, a, c, d]:
		surface.set_uv(Vector2(vertex.x, vertex.y + vertex.z))
		surface.add_vertex(vertex)


static func _add_mesh_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	for vertex in [a, b, c]:
		surface.set_uv(Vector2(vertex.x, vertex.y + vertex.z))
		surface.add_vertex(vertex)
