class_name MapBlueprintCompilerExpandTerrain
extends RefCounted

## Terrain primitive expansion for MapBlueprintCompilerExpand.


static func expand_terrain_rects(
	object_id: StringName,
	style_id: StringName,
	data: Dictionary,
	style: Dictionary,
	inline: Dictionary,
	blueprint: MapBlueprint,
	path: String,
	expanded: Dictionary,
	global: Dictionary,
	errors: Array[String]
) -> void:
	var values := MapBlueprintCompilerExpand.resolved_values(
		object_id, data, style, inline, global, MapBlueprintCompiler.TERRAIN_KEYS, path, errors
	)
	MapBlueprintCompilerExpand.register_id(object_id, path, expanded, errors)
	if not MapTypes.ALL_TERRAINS.has(values.get("terrain", &"")):
		errors.append("%s terrain is unknown: %s" % [path, str(values.get("terrain", ""))])
	var style_variant := TerrainVegetation.resolved_variant(style_id, values)
	if not TerrainVegetation.is_known_variant(style_variant):
		errors.append("%s style_variant is unknown: %s" % [path, String(style_variant)])
	var rects: Variant = data.get("rects")
	if not rects is Array or rects.is_empty():
		errors.append("%s.rects must be a non-empty Array[Rect2i]" % path)
		return
	var sorted_rects: Array = rects.duplicate()
	sorted_rects.sort_custom(MapBlueprintCompiler._compare_rects)
	for fragment_index in sorted_rects.size():
		var rect: Variant = sorted_rects[fragment_index]
		if not rect is Rect2i:
			errors.append("%s.rects[%d] must be Rect2i" % [path, fragment_index])
			continue
		if values.has("rect") and sorted_rects.size() == 1:
			rect = values["rect"]
		MapBlueprintCompiler._validate_rect(
			rect, "%s.rects[%d]" % [path, fragment_index], blueprint.size_cells, errors
		)
		var entry := {
			"source_id": object_id,
			"terrain": values.get("terrain", &""),
			"rect": rect,
			"layer": int(data.get("layer", 0)),
			"order": int(data.get("order", 0)),
			"fragment": fragment_index,
		}
		if not style_variant.is_empty():
			entry["style_variant"] = style_variant
		if values.has("movement_speed_multiplier"):
			entry["movement_speed_multiplier"] = float(values["movement_speed_multiplier"])
		if values.has("shore_confidence"):
			_validate_shore_confidence(
				values["shore_confidence"], "%s.shore_confidence" % path, errors
			)
			entry["shore_confidence"] = values["shore_confidence"]
		expanded["terrain"].append(entry)


static func expand_terrain_stroke(
	object_id: StringName,
	style_id: StringName,
	data: Dictionary,
	style: Dictionary,
	inline: Dictionary,
	blueprint: MapBlueprint,
	path: String,
	expanded: Dictionary,
	global: Dictionary,
	errors: Array[String]
) -> void:
	var values := MapBlueprintCompilerExpand.resolved_values(
		object_id, data, style, inline, global, MapBlueprintCompiler.TERRAIN_KEYS, path, errors
	)
	MapBlueprintCompilerExpand.register_id(object_id, path, expanded, errors)
	if not MapTypes.ALL_TERRAINS.has(values.get("terrain", &"")):
		errors.append("%s terrain is unknown: %s" % [path, str(values.get("terrain", ""))])
	var style_variant := TerrainVegetation.resolved_variant(style_id, values)
	if not TerrainVegetation.is_known_variant(style_variant):
		errors.append("%s style_variant is unknown: %s" % [path, String(style_variant)])
	var points: Variant = data.get("points")
	var thickness := int(data.get("thickness", 0))
	if not points is Array or points.size() < 2:
		errors.append("%s.points must contain at least two Vector2i points" % path)
		return
	if thickness <= 0:
		errors.append("%s.thickness must be positive" % path)
		return
	for point_index in points.size():
		if not points[point_index] is Vector2i:
			errors.append("%s.points[%d] must be Vector2i" % [path, point_index])
			return
	for index in points.size() - 1:
		var start: Vector2i = points[index]
		var finish: Vector2i = points[index + 1]
		if start == finish or (start.x != finish.x and start.y != finish.y):
			errors.append(
				(
					"%s segment %d must be non-zero and orthogonal: %s -> %s"
					% [path, index, start, finish]
				)
			)
			continue
		var rect: Rect2i
		if start.y == finish.y:
			rect = Rect2i(mini(start.x, finish.x), start.y, absi(finish.x - start.x) + 1, thickness)
		else:
			rect = Rect2i(start.x, mini(start.y, finish.y), thickness, absi(finish.y - start.y) + 1)
		MapBlueprintCompiler._validate_rect(
			rect, "%s.segment[%d]" % [path, index], blueprint.size_cells, errors
		)
		var entry := {
			"source_id": object_id,
			"terrain": values.get("terrain", &""),
			"rect": rect,
			"layer": int(data.get("layer", 0)),
			"order": int(data.get("order", 0)),
			"fragment": index,
		}
		if not style_variant.is_empty():
			entry["style_variant"] = style_variant
		if values.has("movement_speed_multiplier"):
			entry["movement_speed_multiplier"] = float(values["movement_speed_multiplier"])
		if values.has("shore_confidence"):
			_validate_shore_confidence(
				values["shore_confidence"], "%s.shore_confidence" % path, errors
			)
			entry["shore_confidence"] = values["shore_confidence"]
		expanded["terrain"].append(entry)


static func _validate_shore_confidence(value: Variant, path: String, errors: Array[String]) -> void:
	if value not in [&"attested", &"reconstructed"]:
		errors.append("%s must be attested or reconstructed" % path)


## ADR 0023: validate relief primitives and sum them, in authored order, into a
## quantised per-cell field sampled at cell centres. Returns {"features", "heights"};
## heights stay empty when the map authors no relief, so legacy maps compile to
## exactly the datum they rendered before. Legacy elevation_profiles add nothing.
static func compile_relief(blueprint: MapBlueprint, errors: Array[String]) -> Dictionary:
	var result := {"features": [] as Array[Dictionary], "heights": PackedFloat32Array()}
	if blueprint.relief_features.is_empty():
		return result
	var seen_ids: Dictionary = {}
	for profile in blueprint.elevation_profiles:
		seen_ids[StringName(profile.get("id", &""))] = true
	var valid := true
	for index in blueprint.relief_features.size():
		var feature: Dictionary = blueprint.relief_features[index]
		var path := "relief[%d]" % index
		var relief_id := StringName(feature.get("id", &""))
		MapBlueprintCompiler._validate_id(relief_id, "%s.id" % path, false, errors)
		if seen_ids.has(relief_id):
			errors.append("%s duplicate relief stable id: %s" % [path, relief_id])
			valid = false
		seen_ids[relief_id] = true
		if not _validate_relief_feature(feature, path, blueprint.size_cells, errors):
			valid = false
	if not valid:
		return result
	var size := blueprint.size_cells
	var sums := PackedFloat64Array()
	sums.resize(size.x * size.y)
	for feature in blueprint.relief_features:
		_accumulate_relief(feature, blueprint.map_seed, size, sums)
	var heights := PackedFloat32Array()
	heights.resize(sums.size())
	for index in sums.size():
		heights[index] = snappedf(sums[index], MapDefinition.RELIEF_QUANTUM)
	result["features"] = blueprint.relief_features.duplicate(true)
	result["heights"] = heights
	return result


## Per-cell mask (1 = lowered) of one relief_cliff. The semantic validator uses it
## to accept steep faces that were authored on purpose.
static func cliff_lowered_mask(feature: Dictionary, size: Vector2i) -> PackedByteArray:
	var mask := PackedByteArray()
	mask.resize(size.x * size.y)
	var start := Vector2(feature["start"])
	var direction := Vector2(feature["end"]) - start
	var length := direction.length()
	if length <= 0.0:
		return mask
	direction /= length
	for y in size.y:
		for x in size.x:
			var offset := Vector2(x, y) - start
			var along := offset.dot(direction)
			if along < 0.0 or along > length:
				continue
			# Positive cross product is the right-hand side walking start->end with
			# y pointing south, i.e. as the map reads on screen.
			if direction.x * offset.y - direction.y * offset.x > 0.0:
				mask[y * size.x + x] = 1
	return mask


static func _validate_relief_feature(
	feature: Dictionary, path: String, size: Vector2i, errors: Array[String]
) -> bool:
	var before := errors.size()
	var kind: StringName = feature.get("kind", &"")
	match kind:
		&"hill":
			_require_cell(feature.get("center"), "%s.center" % path, size, errors)
			_require_positive(feature.get("radius"), "%s.radius" % path, errors)
			_require_signed(feature.get("height"), "%s.height" % path, true, errors)
			_require_falloff(feature.get("falloff"), "%s.falloff" % path, errors)
		&"ridge":
			_require_segment(feature, path, size, errors)
			_require_positive(feature.get("width"), "%s.width" % path, errors)
			_require_signed(feature.get("height"), "%s.height" % path, true, errors)
			_require_falloff(feature.get("falloff"), "%s.falloff" % path, errors)
		&"ditch":
			_require_segment(feature, path, size, errors)
			_require_positive(feature.get("width"), "%s.width" % path, errors)
			_require_signed(feature.get("depth"), "%s.depth" % path, true, errors)
		&"terrace":
			var rect: Variant = feature.get("rect")
			if not rect is Rect2i:
				errors.append("%s.rect must be Rect2i" % path)
			else:
				MapBlueprintCompiler._validate_rect(rect, "%s.rect" % path, size, errors)
			_require_signed(feature.get("height"), "%s.height" % path, false, errors)
			var edge: Variant = feature.get("edge")
			if not edge is int or edge < 0 or edge > 16:
				errors.append("%s.edge must be an integer between 0 and 16" % path)
		&"cliff":
			_require_segment(feature, path, size, errors)
			_require_signed(feature.get("drop"), "%s.drop" % path, true, errors)
		&"noise":
			var rect: Variant = feature.get("rect")
			if not rect is Rect2i:
				errors.append("%s.rect must be Rect2i" % path)
			else:
				MapBlueprintCompiler._validate_rect(rect, "%s.rect" % path, size, errors)
			_require_positive(feature.get("amplitude"), "%s.amplitude" % path, errors)
			if feature.has("seed") and not feature["seed"] is int:
				errors.append("%s.seed must be an integer" % path)
		_:
			errors.append("%s.kind is unknown: %s" % [path, str(kind)])
	return errors.size() == before


static func _require_cell(
	value: Variant, path: String, size: Vector2i, errors: Array[String]
) -> void:
	if not value is Vector2i:
		errors.append("%s must be Vector2i" % path)
	elif value.x < 0 or value.y < 0 or value.x >= size.x or value.y >= size.y:
		errors.append("%s is outside map bounds: %s" % [path, value])


static func _require_segment(
	feature: Dictionary, path: String, size: Vector2i, errors: Array[String]
) -> void:
	_require_cell(feature.get("start"), "%s.start" % path, size, errors)
	_require_cell(feature.get("end"), "%s.end" % path, size, errors)
	if feature.get("start") == feature.get("end"):
		errors.append("%s.start and end must differ" % path)


static func _require_positive(value: Variant, path: String, errors: Array[String]) -> void:
	if not (value is float or value is int) or not is_finite(float(value)) or float(value) <= 0.0:
		errors.append("%s must be positive and finite" % path)


## Primitive magnitudes share the ADR 0023 span so a single statement cannot
## exceed what the whole field may hold; the summed field is range-checked later.
static func _require_signed(
	value: Variant, path: String, positive: bool, errors: Array[String]
) -> void:
	var limit := MapDefinition.RELIEF_MAX_HEIGHT - MapDefinition.RELIEF_MIN_HEIGHT
	if not (value is float or value is int) or not is_finite(float(value)):
		errors.append("%s must be finite" % path)
	elif positive and float(value) <= 0.0:
		errors.append("%s must be positive" % path)
	elif float(value) == 0.0 or absf(float(value)) > limit:
		errors.append("%s must be non-zero and within +-%s world units" % [path, limit])


static func _require_falloff(value: Variant, path: String, errors: Array[String]) -> void:
	if value not in [&"smooth", &"linear", &"plateau"]:
		errors.append("%s must be smooth, linear or plateau" % path)


static func _accumulate_relief(
	feature: Dictionary, map_seed: int, size: Vector2i, sums: PackedFloat64Array
) -> void:
	# Cells and primitive coordinates are both evaluated at cell centres, so the
	# +0.5 offsets cancel and integer coordinates are compared directly.
	match feature["kind"]:
		&"hill":
			var center := Vector2(feature["center"])
			var radius := float(feature["radius"])
			var height := float(feature["height"])
			var falloff: StringName = feature["falloff"]
			var bounds := Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0)
			for cell in _cells_in(bounds, size):
				var t := 1.0 - Vector2(cell).distance_to(center) / radius
				if t > 0.0:
					sums[cell.y * size.x + cell.x] += height * _falloff_weight(t, falloff)
		&"ridge", &"ditch":
			var start := Vector2(feature["start"])
			var finish := Vector2(feature["end"])
			var half_width := float(feature["width"]) * 0.5
			var is_ditch: bool = feature["kind"] == &"ditch"
			var amount := -float(feature["depth"]) if is_ditch else float(feature["height"])
			# Ditches keep a flat bed across their inner half (moats, drains).
			var falloff: StringName = &"plateau" if is_ditch else feature["falloff"]
			var bounds := Rect2(start, Vector2.ZERO).expand(finish).grow(half_width)
			for cell in _cells_in(bounds, size):
				var closest := Geometry2D.get_closest_point_to_segment(Vector2(cell), start, finish)
				var t := 1.0 - Vector2(cell).distance_to(closest) / half_width
				if t > 0.0:
					sums[cell.y * size.x + cell.x] += amount * _falloff_weight(t, falloff)
		&"terrace":
			var rect: Rect2i = feature["rect"]
			var edge: int = feature["edge"]
			var height := float(feature["height"])
			var bounds := Rect2(Vector2(rect.position), Vector2(rect.size - Vector2i.ONE)).grow(
				float(edge)
			)
			for cell in _cells_in(bounds, size):
				var dx := maxi(maxi(rect.position.x - cell.x, cell.x - (rect.end.x - 1)), 0)
				var dy := maxi(maxi(rect.position.y - cell.y, cell.y - (rect.end.y - 1)), 0)
				# Chebyshev rings keep a worked edge equally steep along sides and corners.
				var distance := maxi(dx, dy)
				if distance <= edge:
					# The worked edge steps down linearly, reaching zero one cell past it.
					sums[cell.y * size.x + cell.x] += (
						height * (1.0 - float(distance) / float(edge + 1))
					)
		&"cliff":
			var mask := cliff_lowered_mask(feature, size)
			var drop := float(feature["drop"])
			for index in mask.size():
				if mask[index] == 1:
					sums[index] -= drop
		&"noise":
			var rect: Rect2i = feature["rect"]
			var amplitude := float(feature["amplitude"])
			var noise_seed: int = feature.get("seed", map_seed + String(feature["id"]).hash())
			for y in range(rect.position.y, rect.end.y):
				for x in range(rect.position.x, rect.end.x):
					var inset := mini(
						mini(x - rect.position.x, rect.end.x - 1 - x),
						mini(y - rect.position.y, rect.end.y - 1 - y)
					)
					# Fade in from the rect edge so the undulation meets untouched ground.
					var fade := smoothstep(0.0, 3.0, float(inset) + 1.0)
					var value := _value_noise(Vector2(x, y) / 6.0, noise_seed) * 2.0 - 1.0
					sums[y * size.x + x] += amplitude * value * fade


static func _cells_in(bounds: Rect2, size: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var x0 := clampi(floori(bounds.position.x), 0, size.x - 1)
	var y0 := clampi(floori(bounds.position.y), 0, size.y - 1)
	var x1 := clampi(ceili(bounds.end.x), 0, size.x - 1)
	var y1 := clampi(ceili(bounds.end.y), 0, size.y - 1)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			cells.append(Vector2i(x, y))
	return cells


static func _falloff_weight(t: float, falloff: StringName) -> float:
	match falloff:
		&"linear":
			return t
		&"plateau":
			return smoothstep(0.0, 0.5, t)
	return smoothstep(0.0, 1.0, t)


## Smooth value noise in [0, 1]. Integer-only hashing (masked to 32 bits) keeps
## the result identical on every platform; the view layer's noise is not reused
## because compiled data must not depend on view code.
static func _value_noise(p: Vector2, noise_seed: int) -> float:
	var xi := floori(p.x)
	var yi := floori(p.y)
	var fx := p.x - float(xi)
	var fy := p.y - float(yi)
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	var a := _hash01(xi, yi, noise_seed)
	var b := _hash01(xi + 1, yi, noise_seed)
	var c := _hash01(xi, yi + 1, noise_seed)
	var d := _hash01(xi + 1, yi + 1, noise_seed)
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)


static func _hash01(x: int, y: int, noise_seed: int) -> float:
	var h := (x * 374761393 + y * 668265263 + noise_seed * 144665) & 0xFFFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
	h = (h ^ (h >> 16)) & 0xFFFFFFFF
	return float(h & 0xFFFF) / 65535.0
