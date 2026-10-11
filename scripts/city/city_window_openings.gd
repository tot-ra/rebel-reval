extends RefCounted

## Subtract rectangular apertures from existing wall triangles. This preserves
## the rounded footprint, gable profile and door geometry instead of rebuilding
## a competing shell. Attribute interpolation keeps the material UVs intact.


static func cut(shell: CityBuildingBuilder.Shell, windows: Array[Dictionary], thick: float) -> void:
	for key: String in shell.surfaces.keys():
		if not key.begins_with("wall:") and key != "interior":
			continue
		var source: CityBuildingBuilder.Surf = shell.surfaces[key]
		for window in windows:
			source = _cut_surface(source, window, thick)
		shell.surfaces[key] = source


static func _cut_surface(
	source: CityBuildingBuilder.Surf, window: Dictionary, thick: float
) -> CityBuildingBuilder.Surf:
	var result := CityBuildingBuilder.Surf.new()
	var m: Vector2 = window["m"]
	var dir: Vector2 = window["dir"]
	var nrm: Vector2 = window["nrm"]
	var out := Vector3(nrm.x, 0, nrm.y)
	var hw: float = window["w"] * 0.5
	var bottom: float = window["y"]
	var top: float = bottom + float(window["h"])
	for i in range(0, source.verts.size(), 3):
		var polygon: Array[Dictionary] = []
		var eligible := absf(source.normals[i].dot(out)) > 0.999
		for j in 3:
			var v := source.verts[i + j]
			var p := Vector2(v.x, v.z) - m
			var depth := p.dot(nrm)
			eligible = eligible and depth >= -thick - 0.025 and depth <= 0.025
			polygon.append(
				{
					"v": v,
					"uv": source.uvs[i + j],
					"color": source.colors[i + j],
					"p": Vector2(p.dot(dir), v.y)
				}
			)
		var p0: Vector2 = polygon[0]["p"]
		var p1: Vector2 = polygon[1]["p"]
		var p2: Vector2 = polygon[2]["p"]
		eligible = eligible and minf(p0.x, minf(p1.x, p2.x)) < hw
		eligible = eligible and maxf(p0.x, maxf(p1.x, p2.x)) > -hw
		eligible = eligible and minf(p0.y, minf(p1.y, p2.y)) < top
		eligible = eligible and maxf(p0.y, maxf(p1.y, p2.y)) > bottom
		if not eligible:
			_emit(result, polygon, source.normals[i])
			continue
		# At each boundary retain the outside piece, then clip the remainder
		# inward. The final inside polygon is discarded, leaving a real hole.
		for plane: Vector3 in [
			Vector3(1, 0, -hw), Vector3(-1, 0, -hw), Vector3(0, 1, bottom), Vector3(0, -1, -top)
		]:
			_emit(result, _clip(polygon, plane, false), source.normals[i])
			polygon = _clip(polygon, plane, true)
			if polygon.is_empty():
				break
	return result


static func _clip(poly: Array[Dictionary], plane: Vector3, inside: bool) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if poly.is_empty():
		return result
	var axis := Vector2(plane.x, plane.y)
	for i in poly.size():
		var a: Dictionary = poly[i]
		var b: Dictionary = poly[(i + 1) % poly.size()]
		var da: float = axis.dot(a["p"]) - plane.z
		var db: float = axis.dot(b["p"]) - plane.z
		var keep_a := da >= 0.0 if inside else da <= 0.0
		var keep_b := db >= 0.0 if inside else db <= 0.0
		if keep_a:
			result.append(a)
		if keep_a != keep_b:
			var t := da / (da - db)
			result.append(
				{
					"v": (a["v"] as Vector3).lerp(b["v"], t),
					"uv": (a["uv"] as Vector2).lerp(b["uv"], t),
					"color": (a["color"] as Color).lerp(b["color"], t),
					"p": (a["p"] as Vector2).lerp(b["p"], t)
				}
			)
	return result


static func _emit(
	surface: CityBuildingBuilder.Surf, poly: Array[Dictionary], normal: Vector3
) -> void:
	for i in range(1, poly.size() - 1):
		var a: Dictionary = poly[0]
		var b: Dictionary = poly[i]
		var c: Dictionary = poly[i + 1]
		if (c["v"] - a["v"]).cross(b["v"] - a["v"]).length_squared() < 1e-12:
			continue
		surface.add(a["v"], b["v"], c["v"], normal, a["color"], a["uv"], b["uv"], c["uv"])
