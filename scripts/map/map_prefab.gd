class_name MapPrefab
extends RefCounted

## Reusable local-coordinate composition. Values may reference declared parameters
## with MapPrefab.parameter(), keeping prefab payloads deterministic and typed.

const TYPE_BOOL := &"bool"
const TYPE_INT := &"int"
const TYPE_FLOAT := &"float"
const TYPE_STRING := &"string"
const TYPE_STRING_NAME := &"string_name"
const TYPE_VECTOR2 := &"vector2"
const TYPE_VECTOR2I := &"vector2i"
const TYPE_RECT2I := &"rect2i"
const TYPE_COLOR := &"color"
const PARAMETER_REFERENCE_KEY := &"$parameter"
const PARAMETER_TYPES: Array[StringName] = [
	TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME,
	TYPE_VECTOR2, TYPE_VECTOR2I, TYPE_RECT2I, TYPE_COLOR,
]

var prefab_id: StringName
var version: int
var parameters: Array[Dictionary] = []
var primitives: Array[Dictionary] = []
var instances: Array[Dictionary] = []


func _init(prefab_id_value: StringName, version_value: int = 1) -> void:
	prefab_id = prefab_id_value
	version = version_value


static func parameter(parameter_id: StringName) -> Dictionary:
	return {PARAMETER_REFERENCE_KEY: parameter_id}


func declare_parameter(parameter_id: StringName, type_id: StringName, default_value: Variant) -> MapPrefab:
	parameters.append({"id": parameter_id, "type": type_id, "default": default_value})
	return self


func primitive(
	primitive_kind: StringName,
	local_id: StringName,
	data: Dictionary,
	style_id: StringName = &"",
	overrides: Dictionary = {}
) -> MapPrefab:
	primitives.append({
		"primitive": primitive_kind,
		"id": local_id,
		"data": data.duplicate(true),
		"style": style_id,
		"overrides": overrides.duplicate(true),
	})
	return self


func terrain_rect(
	local_id: StringName,
	terrain: Variant,
	rect: Variant,
	layer: int = 0,
	order: int = 0,
	style_id: StringName = &"",
	overrides: Dictionary = {}
) -> MapPrefab:
	return primitive(&"terrain_rect", local_id, {
		"terrain": terrain,
		"rects": [rect],
		"layer": layer,
		"order": order,
	}, style_id, overrides)


func structure_rect(
	local_id: StringName,
	kind: StringName,
	footprint: Variant,
	style_id: StringName = &"",
	overrides: Dictionary = {}
) -> MapPrefab:
	return primitive(&"structure_rect", local_id, {"kind": kind, "rect": footprint}, style_id, overrides)


func prop(
	local_id: StringName,
	kind: StringName,
	cell: Variant,
	style_id: StringName = &"",
	overrides: Dictionary = {}
) -> MapPrefab:
	return primitive(&"prop", local_id, {"kind": kind, "cell": cell}, style_id, overrides)


func view_landmark(
	local_id: StringName,
	kind: StringName,
	rect: Variant,
	style_id: StringName = &"",
	overrides: Dictionary = {}
) -> MapPrefab:
	return primitive(&"view_landmark", local_id, {"kind": kind, "rect": rect}, style_id, overrides)


func instance(
	local_instance_id: StringName,
	prefab_id_value: StringName,
	origin: Variant,
	transform: MapTransform = null,
	parameter_values: Dictionary = {},
	overrides_by_local_id: Dictionary = {}
) -> MapPrefab:
	instances.append({
		"id": local_instance_id,
		"prefab_id": prefab_id_value,
		"origin": origin,
		"transform": transform if transform != null else MapTransform.new(),
		"parameters": parameter_values.duplicate(true),
		"overrides": overrides_by_local_id.duplicate(true),
	})
	return self
