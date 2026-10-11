class_name MapPrefabPackage
extends RefCounted

## Explicit package registration avoids filesystem enumeration and makes the
## prefab library input deterministic and reusable across maps.

var package_id: StringName
var version: int
var prefabs: Array[MapPrefab] = []


func _init(package_id_value: StringName, version_value: int = 1) -> void:
	package_id = package_id_value
	version = version_value


func add_prefab(prefab: MapPrefab) -> MapPrefabPackage:
	prefabs.append(prefab)
	return self
