class_name TestMapCatalog
extends RefCounted

var _failures: Array[String] = []

func _get_failures() -> Array[String]:
	return _failures

func test_map_catalog() -> void:
	var forge = MapCatalog.get_map("forge")
	if forge.is_empty():
		_failures.append("Expected 'forge' map in catalog")
	elif forge.get("scope") != "production":
		_failures.append("Expected 'forge' to be production")
		
	var toompea = MapCatalog.get_map("reval_toompea")
	if toompea.is_empty():
		_failures.append("Expected 'reval_toompea' in catalog")
	elif toompea.get("scope") != "prototype":
		_failures.append("Expected 'reval_toompea' to be prototype")

	var south = MapCatalog.get_map("reval_south")
	if south.is_empty():
		_failures.append("Expected 'reval_south' in catalog")
	elif south.get("scope") != "prototype":
		_failures.append("Expected 'reval_south' to be prototype")
