extends RefCounted

## Applies map-space transforms to expanded prefab primitives. Keeping geometry
## normalization here lets MapPrefabExpander focus on package resolution,
## namespaces, parameters, recursion, and override precedence.


static func transform_primitive(
	primitive: Dictionary,
	transform: MapTransform,
	origin: Vector2i
) -> Dictionary:
	var result := primitive.duplicate(true)
	var kind: StringName = result.get("primitive", &"")
	var data: Dictionary = result.get("data", {})
	var inline: Dictionary = result.get("overrides", {})
	if kind == &"terrain_stroke":
		_normalize_terrain_stroke(result, transform, origin)
		data = result.get("data", {})
	elif kind == &"placement_row":
		_transform_row_data(data, transform, origin)
	elif kind == &"wall_run":
		_transform_wall_data(data, transform, origin)
	else:
		_transform_dictionary(data, transform, origin, true)
	_transform_dictionary(inline, transform, origin, true)
	result["data"] = data
	result["overrides"] = inline
	result["prefab_expanded"] = true
	return result


static func compose(outer: MapTransform, inner: MapTransform) -> MapTransform:
	# The eight orthogonal transforms are small enough to identify exactly from
	# transformed basis vectors, avoiding float matrices and platform drift.
	var target_x := outer.transform_cell(inner.transform_cell(Vector2i.RIGHT))
	var target_y := outer.transform_cell(inner.transform_cell(Vector2i.DOWN))
	for mirror_x in [false, true]:
		for mirror_y in [false, true]:
			for rotation in [0, 90, 180, 270]:
				var candidate := MapTransform.new(rotation, mirror_x, mirror_y)
				if candidate.transform_cell(Vector2i.RIGHT) == target_x and candidate.transform_cell(Vector2i.DOWN) == target_y:
					return candidate
	return MapTransform.new()


static func _transform_dictionary(
	values: Dictionary,
	transform: MapTransform,
	origin: Vector2i,
	translate: bool
) -> void:
	for key_value in values.keys():
		var key := StringName(key_value)
		var value: Variant = values[key_value]
		match key:
			&"rect":
				if value is Rect2i:
					values[key_value] = _translated_rect(transform.transform_rect(value), origin if translate else Vector2i.ZERO)
			&"rects", &"openings":
				if value is Array:
					var rects: Array = []
					for rect in value:
						rects.append(_translated_rect(transform.transform_rect(rect), origin if translate else Vector2i.ZERO) if rect is Rect2i else rect)
					values[key_value] = rects
			&"cell", &"start", &"end", &"origin":
				if value is Vector2i:
					values[key_value] = transform.transform_cell(value) + (origin if translate else Vector2i.ZERO)
			&"points":
				if value is Array:
					var points: Array = []
					for point in value:
						points.append(transform.transform_cell(point) + (origin if translate else Vector2i.ZERO) if point is Vector2i else point)
					values[key_value] = points
			&"direction", &"step":
				if value is Vector2i:
					values[key_value] = transform.transform_cell(value)
			&"facing", &"door_side":
				if value is StringName or value is String:
					values[key_value] = transform.transform_cardinal(StringName(value))
				elif value is Vector2:
					values[key_value] = transform.transform_vector(value)
			&"ridge_axis", &"passage_axis":
				if value is StringName or value is String:
					values[key_value] = transform.transform_axis(StringName(value))
			&"visual_offset_px", &"spawn_offset_px":
				if value is Vector2:
					values[key_value] = transform.transform_vector(value)


static func _transform_row_data(
	data: Dictionary,
	transform: MapTransform,
	origin: Vector2i
) -> void:
	var local_origin: Variant = data.get("origin")
	var size: Variant = data.get("footprint_size", Vector2i.ONE)
	if local_origin is Vector2i and size is Vector2i:
		var transformed_rect := transform.transform_rect(Rect2i(local_origin, size))
		data["origin"] = transformed_rect.position + origin
		data["footprint_size"] = transformed_rect.size
	if data.get("step") is Vector2i:
		data["step"] = transform.transform_cell(data["step"])


static func _transform_wall_data(
	data: Dictionary,
	transform: MapTransform,
	origin: Vector2i
) -> void:
	var start: Variant = data.get("start")
	var finish: Variant = data.get("end")
	var thickness := int(data.get("thickness", 0))
	if not start is Vector2i or not finish is Vector2i or thickness <= 0:
		return
	var horizontal: bool = start.y == finish.y
	var run_rect := Rect2i(
		mini(start.x, finish.x) if horizontal else start.x,
		start.y if horizontal else mini(start.y, finish.y),
		absi(finish.x - start.x) + 1 if horizontal else thickness,
		thickness if horizontal else absi(finish.y - start.y) + 1
	)
	var transformed := _translated_rect(transform.transform_rect(run_rect), origin)
	var transformed_start := transform.transform_cell(start)
	var transformed_finish := transform.transform_cell(finish)
	if transformed_start.y == transformed_finish.y:
		data["start"] = transformed.position
		data["end"] = Vector2i(transformed.end.x - 1, transformed.position.y)
		data["thickness"] = transformed.size.y
	else:
		data["start"] = transformed.position
		data["end"] = Vector2i(transformed.position.x, transformed.end.y - 1)
		data["thickness"] = transformed.size.x
	var openings: Array = []
	for opening in data.get("openings", []):
		openings.append(_translated_rect(transform.transform_rect(opening), origin) if opening is Rect2i else opening)
	data["openings"] = openings


static func _normalize_terrain_stroke(
	result: Dictionary,
	transform: MapTransform,
	origin: Vector2i
) -> void:
	var data: Dictionary = result.get("data", {})
	var points: Variant = data.get("points")
	var thickness := int(data.get("thickness", 0))
	if not points is Array or points.size() < 2 or thickness <= 0:
		return
	var rects: Array = []
	for index in points.size() - 1:
		var start: Variant = points[index]
		var finish: Variant = points[index + 1]
		if not start is Vector2i or not finish is Vector2i or (start.x != finish.x and start.y != finish.y):
			continue
		var rect := Rect2i(
			mini(start.x, finish.x) if start.y == finish.y else start.x,
			start.y if start.y == finish.y else mini(start.y, finish.y),
			absi(finish.x - start.x) + 1 if start.y == finish.y else thickness,
			thickness if start.y == finish.y else absi(finish.y - start.y) + 1
		)
		rects.append(_translated_rect(transform.transform_rect(rect), origin))
	result["primitive"] = &"terrain_rects"
	result["data"] = {
		"terrain": data.get("terrain", &""),
		"rects": rects,
		"layer": data.get("layer", 0),
		"order": data.get("order", 0),
	}


static func _translated_rect(rect: Rect2i, offset: Vector2i) -> Rect2i:
	return Rect2i(rect.position + offset, rect.size)
