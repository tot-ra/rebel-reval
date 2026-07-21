class_name MapViewFishingBoatBuilder
extends RefCounted

const Primitives := preload("res://scripts/map/view3d/map_view_mesh_builder_primitives.gd")

## Procedural fourteenth-century inshore fishing boat used by the 3D map view.


static func add_to(root: Node3D) -> void:
	# A narrow clinker-built open boat fits a fourteenth-century inshore fishery.
	# The raised stem, curved gunwales and visible bilge replace the old flat prism;
	# benches, oars and furled rig keep a moored boat readable as working craft.
	var hull := MeshInstance3D.new()
	hull.name = "Hull"
	hull.mesh = _hull_mesh()
	hull.material_override = Primitives.role_material(&"wood")
	root.add_child(hull)

	Primitives.box(root, "Interior", Vector3(2.5, 0.08, 0.58), Vector3(-0.05, 0.12, 0.0), &"ink")
	_add_spar(root, "Keel", Vector3(-1.68, -0.27, 0.0), Vector3(1.7, -0.19, 0.0), 0.045, &"timber")
	_add_spar(root, "Sternpost", Vector3(-1.68, -0.2, 0.0), Vector3(-1.86, 0.77, 0.0), 0.045, &"timber")
	_add_spar(root, "BowStem", Vector3(1.68, -0.16, 0.0), Vector3(1.94, 0.92, 0.0), 0.05, &"timber")
	_add_clinker_rails(root)

	for index in 3:
		var x := -0.72 + float(index) * 0.72
		Primitives.box(root, "Bench%d" % index, Vector3(0.18, 0.09, 1.13), Vector3(x, 0.59, 0.0), &"timber")

	_add_spar(root, "Mast", Vector3(0.17, 0.2, 0.0), Vector3(0.17, 2.62, 0.0), 0.055, &"timber")
	var yard := Node3D.new()
	yard.name = "Yard"
	root.add_child(yard)
	_add_spar(yard, "Spar", Vector3(-0.22, 2.29, -0.76), Vector3(0.62, 2.08, 0.79), 0.035, &"timber")
	_add_spar(yard, "FurledSail", Vector3(-0.12, 2.27, -0.58), Vector3(0.54, 2.11, 0.61), 0.09, &"plaster")
	_add_rigging(root)

	_add_oar(root, "OarPort", Vector3(-0.35, 0.7, -0.2), Vector3(0.72, 0.54, -1.45))
	_add_oar(root, "OarStarboard", Vector3(-0.62, 0.72, 0.18), Vector3(0.42, 0.5, 1.48))
	Primitives.box(root, "Rudder", Vector3(0.12, 0.62, 0.34), Vector3(-1.82, 0.12, 0.16), &"timber")
	_add_spar(root, "Tiller", Vector3(-1.79, 0.39, 0.12), Vector3(-1.08, 0.68, 0.04), 0.035, &"timber")
	Primitives.cylinder(root, "FishBasket", 0.17, 0.22, Vector3(1.02, 0.52, -0.18), &"hay")


static func _add_clinker_rails(root: Node3D) -> void:
	var rail_stations: Array[Vector3] = [
		Vector3(-1.78, 0.73, 0.12),
		Vector3(-1.42, 0.58, 0.5),
		Vector3(-0.72, 0.54, 0.66),
		Vector3(0.0, 0.53, 0.7),
		Vector3(0.78, 0.57, 0.63),
		Vector3(1.45, 0.67, 0.43),
		Vector3(1.88, 0.88, 0.08),
	]
	for side in [-1.0, 1.0]:
		var side_name := "Port" if side < 0.0 else "Starboard"
		for station_index in rail_stations.size() - 1:
			var start := rail_stations[station_index]
			var end := rail_stations[station_index + 1]
			start.z *= side
			end.z *= side
			_add_spar(root, "Gunwale%s%d" % [side_name, station_index], start, end, 0.045, &"timber")
			# The lower rail traces a clinker plank overlap, breaking up the slab-like side.
			start.y -= 0.22
			end.y -= 0.22
			start.z *= 0.91
			end.z *= 0.91
			_add_spar(root, "Strake%s%d" % [side_name, station_index], start, end, 0.025, &"timber")


static func _add_rigging(root: Node3D) -> void:
	var rigging := Node3D.new()
	rigging.name = "Rigging"
	root.add_child(rigging)
	_add_spar(rigging, "Forestay", Vector3(0.17, 2.56, 0.0), Vector3(1.83, 0.86, 0.0), 0.012, &"ink")
	_add_spar(rigging, "Backstay", Vector3(0.17, 2.56, 0.0), Vector3(-1.73, 0.72, 0.0), 0.012, &"ink")
	_add_spar(rigging, "ShroudPort", Vector3(0.17, 2.18, 0.0), Vector3(0.0, 0.52, -0.7), 0.012, &"ink")
	_add_spar(rigging, "ShroudStarboard", Vector3(0.17, 2.18, 0.0), Vector3(0.0, 0.52, 0.7), 0.012, &"ink")


## Faceted stations form an open shell with a deep keel, broad working middle and
## fine ends. The open top is intentional: benches and fishing gear remain visible
## from the fixed high camera instead of resting on a solid deck.
static func _hull_mesh() -> ArrayMesh:
	var stations: Array[Vector4] = [
		Vector4(-1.86, 0.1, -0.16, 0.73),
		Vector4(-1.42, 0.52, -0.29, 0.58),
		Vector4(-0.72, 0.68, -0.36, 0.54),
		Vector4(0.0, 0.72, -0.38, 0.53),
		Vector4(0.78, 0.65, -0.34, 0.57),
		Vector4(1.45, 0.46, -0.24, 0.67),
		Vector4(1.92, 0.06, 0.04, 0.88),
	]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for station_index in stations.size() - 1:
		var aft := _hull_section(stations[station_index])
		var fore := _hull_section(stations[station_index + 1])
		for section_index in aft.size() - 1:
			_add_mesh_quad(surface, aft[section_index], fore[section_index], fore[section_index + 1], aft[section_index + 1])
	for station_index in [0, stations.size() - 1]:
		var section := _hull_section(stations[station_index])
		for section_index in range(1, section.size() - 1):
			_add_mesh_triangle(surface, section[0], section[section_index], section[section_index + 1])
	surface.generate_normals()
	return surface.commit()


static func _hull_section(station: Vector4) -> Array[Vector3]:
	var chine_y := lerpf(station.z, station.w, 0.38)
	var chine_half_beam := station.y * 0.68
	return [
		Vector3(station.x, station.w, -station.y),
		Vector3(station.x, chine_y, -chine_half_beam),
		Vector3(station.x, station.z, 0.0),
		Vector3(station.x, chine_y, chine_half_beam),
		Vector3(station.x, station.w, station.y),
	]


static func _add_oar(root: Node3D, node_name: String, start: Vector3, end: Vector3) -> void:
	var oar := Node3D.new()
	oar.name = node_name
	root.add_child(oar)
	_add_spar(oar, "Shaft", start, end, 0.025, &"timber")
	var horizontal_direction := Vector2(end.x - start.x, end.z - start.z).normalized()
	var blade := MeshInstance3D.new()
	blade.name = "Blade"
	var blade_mesh := BoxMesh.new()
	blade_mesh.size = Vector3(0.38, 0.045, 0.14)
	blade.mesh = blade_mesh
	blade.position = end + Vector3(horizontal_direction.x, 0.0, horizontal_direction.y) * 0.14
	blade.rotation.y = -atan2(horizontal_direction.y, horizontal_direction.x)
	blade.material_override = Primitives.role_material(&"wood")
	oar.add_child(blade)


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
	instance.material_override = Primitives.role_material(role)
	parent.add_child(instance)


static func _add_mesh_quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for vertex in [a, b, c, a, c, d]:
		surface.set_uv(Vector2(vertex.x, vertex.y + vertex.z))
		surface.add_vertex(vertex)


static func _add_mesh_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	for vertex in [a, b, c]:
		surface.set_uv(Vector2(vertex.x, vertex.y + vertex.z))
		surface.add_vertex(vertex)
