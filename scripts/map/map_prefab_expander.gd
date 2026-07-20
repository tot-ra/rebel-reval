class_name MapPrefabExpander
extends RefCounted

const MapPrefabPrimitiveTransformer := preload("res://scripts/map/map_prefab_primitive_transformer.gd")

## Expands package prefabs to ordinary MapBlueprint primitive records. Keeping
## this phase separate lets the proven primitive compiler remain the authority
## for allowlists, final bounds, duplicate IDs, and runtime conversion.

const MAX_NESTING_DEPTH := 32


static func expand(blueprint: MapBlueprint, errors: Array[String]) -> Dictionary:
	var registry := _build_registry(blueprint.prefab_packages, errors)
	var output: Array[Dictionary] = []
	var instance_ids: Dictionary = {}
	var instances: Array = blueprint.prefab_instances.duplicate()
	instances.sort_custom(_compare_instance_ids)
	for index in instances.size():
		var instance_record: Variant = instances[index]
		var path := "prefab_instances[%d]" % index
		if not instance_record is Dictionary:
			errors.append("%s must be Dictionary" % path)
			continue
		var instance_id: StringName = instance_record.get("id", &"")
		_validate_id(instance_id, "%s.id" % path, false, errors)
		if instance_ids.has(instance_id):
			errors.append("%s duplicates prefab instance id: %s" % [path, String(instance_id)])
			continue
		instance_ids[instance_id] = true
		_expand_instance(instance_record, String(instance_id), registry, output, errors, path, [], 0, [], Vector2i.ZERO, MapTransform.new())
	return {"primitives": output, "instance_ids": instance_ids}


static func _build_registry(packages: Array[MapPrefabPackage], errors: Array[String]) -> Dictionary:
	var registry: Dictionary = {}
	var package_ids: Dictionary = {}
	for package_index in packages.size():
		var package := packages[package_index]
		var path := "prefab_packages[%d]" % package_index
		if package == null:
			errors.append("%s is required" % path)
			continue
		_validate_id(package.package_id, "%s.package_id" % path, false, errors)
		if package.version <= 0:
			errors.append("%s.version must be positive" % path)
		if package_ids.has(package.package_id):
			errors.append("%s duplicates prefab package id: %s" % [path, String(package.package_id)])
			continue
		package_ids[package.package_id] = true
		var local_ids: Dictionary = {}
		for prefab_index in package.prefabs.size():
			var prefab := package.prefabs[prefab_index]
			var prefab_path := "%s.prefabs[%d]" % [path, prefab_index]
			if prefab == null:
				errors.append("%s is required" % prefab_path)
				continue
			_validate_id(prefab.prefab_id, "%s.prefab_id" % prefab_path, false, errors)
			if prefab.version <= 0:
				errors.append("%s.version must be positive" % prefab_path)
			if local_ids.has(prefab.prefab_id):
				errors.append("%s duplicates prefab id in package: %s" % [prefab_path, String(prefab.prefab_id)])
				continue
			local_ids[prefab.prefab_id] = true
			var qualified_id := StringName("%s.%s" % [String(package.package_id), String(prefab.prefab_id)])
			registry[qualified_id] = prefab
	return registry


static func _expand_instance(
	instance_record: Dictionary,
	id_namespace: String,
	registry: Dictionary,
	output: Array[Dictionary],
	errors: Array[String],
	path: String,
	prefab_stack: Array[StringName],
	depth: int,
	inherited_override_layers: Array[Dictionary],
	parent_origin: Vector2i,
	parent_transform: MapTransform
) -> void:
	if depth >= MAX_NESTING_DEPTH:
		errors.append("%s exceeds maximum prefab nesting depth %d" % [path, MAX_NESTING_DEPTH])
		return
	var prefab_id: StringName = instance_record.get("prefab_id", &"")
	_validate_id(prefab_id, "%s.prefab_id" % path, false, errors)
	if not registry.has(prefab_id):
		errors.append("%s references unknown prefab: %s" % [path, String(prefab_id)])
		return
	if prefab_stack.has(prefab_id):
		var cycle := prefab_stack.duplicate()
		cycle.append(prefab_id)
		var names: Array[String] = []
		for item in cycle:
			names.append(String(item))
		errors.append("recursive prefab instance_record: %s" % " -> ".join(names))
		return

	var local_origin: Variant = instance_record.get("origin")
	if not local_origin is Vector2i:
		errors.append("%s.origin must be Vector2i" % path)
		return
	var local_transform := _read_transform(instance_record.get("transform"), "%s.transform" % path, errors)
	if local_transform == null:
		return
	var map_origin := parent_origin + parent_transform.transform_cell(local_origin)
	var composed_transform := MapPrefabPrimitiveTransformer.compose(parent_transform, local_transform)
	var prefab: MapPrefab = registry[prefab_id]
	var parameters := _resolve_parameters(prefab, instance_record.get("parameters", {}), path, errors)

	var own_overrides := _normalize_overrides(instance_record.get("overrides", {}), "%s.overrides" % path, errors)
	var next_override_layers: Array[Dictionary] = [own_overrides]
	next_override_layers.append_array(inherited_override_layers)
	var local_object_ids: Dictionary = {}
	var primitive_ids: Dictionary = {}
	for primitive_index in prefab.primitives.size():
		var primitive: Variant = prefab.primitives[primitive_index]
		var primitive_path := "%s.prefab[%s].primitives[%d]" % [path, String(prefab_id), primitive_index]
		if not primitive is Dictionary:
			errors.append("%s must be Dictionary" % primitive_path)
			continue
		var local_id: StringName = primitive.get("id", &"")
		_validate_id(local_id, "%s.id" % primitive_path, false, errors)
		if local_object_ids.has(local_id):
			errors.append("%s duplicates prefab-local id: %s" % [primitive_path, String(local_id)])
			continue
		local_object_ids[local_id] = true
		primitive_ids[local_id] = true
		var resolved: Dictionary = _resolve_variant(primitive, parameters, primitive_path, errors)
		var transformed := MapPrefabPrimitiveTransformer.transform_primitive(
			resolved,
			composed_transform,
			map_origin
		)
		transformed["id"] = StringName("%s/%s" % [id_namespace, String(local_id)])
		_apply_override_layers(transformed, String(local_id), next_override_layers)
		output.append(transformed)

	var next_stack := prefab_stack.duplicate()
	next_stack.append(prefab_id)
	var nested_instances: Array = prefab.instances.duplicate()
	nested_instances.sort_custom(_compare_instance_ids)
	for nested_index in nested_instances.size():
		var nested: Variant = nested_instances[nested_index]
		var nested_path := "%s.prefab[%s].instances[%d]" % [path, String(prefab_id), nested_index]
		if not nested is Dictionary:
			errors.append("%s must be Dictionary" % nested_path)
			continue
		var resolved_nested: Dictionary = _resolve_variant(nested, parameters, nested_path, errors)
		var nested_id: StringName = resolved_nested.get("id", &"")
		_validate_id(nested_id, "%s.id" % nested_path, false, errors)
		if local_object_ids.has(nested_id):
			errors.append("%s duplicates prefab-local id: %s" % [nested_path, String(nested_id)])
			continue
		local_object_ids[nested_id] = true
		var nested_namespace := "%s/%s" % [id_namespace, String(nested_id)]
		var nested_override_layers := _descend_override_layers(next_override_layers, String(nested_id))
		_expand_instance(resolved_nested, nested_namespace, registry, output, errors, nested_path, next_stack, depth + 1, nested_override_layers, map_origin, composed_transform)

	# Override keys name semantic local objects or nested paths, never array slots.
	var expanded_local_targets: Dictionary = {}
	for primitive in output:
		var resolved_id := String(primitive.get("id", ""))
		var prefix := id_namespace + "/"
		if resolved_id.begins_with(prefix):
			expanded_local_targets[StringName(resolved_id.trim_prefix(prefix))] = true
	for target in own_overrides.keys():
		if not expanded_local_targets.has(StringName(target)):
			errors.append("%s.overrides targets unknown prefab object: %s" % [path, String(target)])


static func _resolve_parameters(prefab: MapPrefab, supplied_value: Variant, path: String, errors: Array[String]) -> Dictionary:
	var supplied: Dictionary = supplied_value if supplied_value is Dictionary else {}
	if not supplied_value is Dictionary:
		errors.append("%s.parameters must be Dictionary" % path)
	var declarations: Dictionary = {}
	var values: Dictionary = {}
	for index in prefab.parameters.size():
		var declaration: Variant = prefab.parameters[index]
		var parameter_path := "%s.parameters[%d]" % [path, index]
		if not declaration is Dictionary:
			errors.append("%s declaration must be Dictionary" % parameter_path)
			continue
		var parameter_id: StringName = declaration.get("id", &"")
		_validate_id(parameter_id, "%s.id" % parameter_path, false, errors)
		if declarations.has(parameter_id):
			errors.append("%s duplicates parameter: %s" % [parameter_path, String(parameter_id)])
			continue
		declarations[parameter_id] = true
		var type_id: StringName = declaration.get("type", &"")
		if not MapPrefab.PARAMETER_TYPES.has(type_id):
			errors.append("%s has unknown parameter type: %s" % [parameter_path, String(type_id)])
		var value: Variant = supplied.get(parameter_id, supplied.get(String(parameter_id), declaration.get("default")))
		if not _matches_parameter_type(value, type_id):
			errors.append("%s value for %s must have type %s" % [path, String(parameter_id), String(type_id)])
		values[parameter_id] = value
	for key in supplied.keys():
		if not declarations.has(StringName(key)):
			errors.append("%s.parameters has unknown parameter: %s" % [path, String(key)])
	return values


static func _resolve_variant(value: Variant, parameters: Dictionary, path: String, errors: Array[String]) -> Variant:
	if value is Dictionary:
		if value.size() == 1 and value.has(MapPrefab.PARAMETER_REFERENCE_KEY):
			var parameter_id: StringName = value[MapPrefab.PARAMETER_REFERENCE_KEY]
			if not parameters.has(parameter_id):
				errors.append("%s references undeclared parameter: %s" % [path, String(parameter_id)])
				return null
			return parameters[parameter_id]
		var resolved: Dictionary = {}
		for key in value.keys():
			resolved[key] = _resolve_variant(value[key], parameters, "%s.%s" % [path, String(key)], errors)
		return resolved
	if value is Array:
		var resolved: Array = []
		for index in value.size():
			resolved.append(_resolve_variant(value[index], parameters, "%s[%d]" % [path, index], errors))
		return resolved
	return value


static func _apply_override_layers(primitive: Dictionary, local_id: String, layers: Array[Dictionary]) -> void:
	var inline: Dictionary = primitive.get("overrides", {}).duplicate(true)
	for layer in layers:
		var values: Variant = layer.get(StringName(local_id), layer.get(local_id, {}))
		if values is Dictionary:
			for key in values.keys():
				inline[key] = values[key]
	primitive["overrides"] = inline


static func _normalize_overrides(value: Variant, path: String, errors: Array[String]) -> Dictionary:
	if not value is Dictionary:
		errors.append("%s must be Dictionary" % path)
		return {}
	var result: Dictionary = {}
	for target in value.keys():
		var target_id := StringName(target)
		_validate_id(target_id, "%s target" % path, true, errors)
		if result.has(target_id):
			errors.append("%s has duplicate target: %s" % [path, String(target_id)])
			continue
		if not value[target] is Dictionary:
			errors.append("%s[%s] must be Dictionary" % [path, String(target)])
			continue
		result[target_id] = value[target]
	return result


static func _read_transform(value: Variant, path: String, errors: Array[String]) -> MapTransform:
	if not value is MapTransform:
		errors.append("%s must be MapTransform" % path)
		return null
	if not value.is_valid():
		errors.append("%s rotation must be a multiple of 90 degrees" % path)
		return null
	return value


static func _matches_parameter_type(value: Variant, type_id: StringName) -> bool:
	match type_id:
		MapPrefab.TYPE_BOOL:
			return value is bool
		MapPrefab.TYPE_INT:
			return value is int
		MapPrefab.TYPE_FLOAT:
			return value is float
		MapPrefab.TYPE_STRING:
			return value is String
		MapPrefab.TYPE_STRING_NAME:
			return value is StringName
		MapPrefab.TYPE_VECTOR2:
			return value is Vector2
		MapPrefab.TYPE_VECTOR2I:
			return value is Vector2i
		MapPrefab.TYPE_RECT2I:
			return value is Rect2i
		MapPrefab.TYPE_COLOR:
			return value is Color
	return false


static func _descend_override_layers(layers: Array[Dictionary], nested_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var prefix := nested_id + "/"
	for layer in layers:
		var descended: Dictionary = {}
		for target in layer.keys():
			var target_text := String(target)
			if target_text.begins_with(prefix):
				descended[StringName(target_text.trim_prefix(prefix))] = layer[target]
		result.append(descended)
	return result


static func _validate_id(value: StringName, path: String, allow_namespace: bool, errors: Array[String]) -> void:
	var text := String(value)
	if text.is_empty():
		errors.append("%s is required" % path)
		return
	var segments := text.split("/")
	if not allow_namespace and segments.size() != 1:
		errors.append("%s cannot contain reserved id_namespace separator '/': %s" % [path, text])
		return
	var regex := RegEx.new()
	regex.compile("^[a-z0-9_.-]+$")
	for segment in segments:
		if segment.is_empty() or regex.search(segment) == null:
			errors.append("%s has invalid stable id '%s'" % [path, text])
			return


static func _compare_instance_ids(left: Variant, right: Variant) -> bool:
	if not left is Dictionary or not right is Dictionary:
		return str(left) < str(right)
	return String(left.get("id", "")) < String(right.get("id", ""))
