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

	# The old Reval district maps are gone: the city is one seamless plan.
	for retired in [
		"reval_east",
		"reval_center",
		"reval_north",
		"reval_monastery",
		"reval_toompea",
		"reval_south",
		"town_hall",
		"viru_gate_foreland",
		"reval_harbor_north",
		"reval_harbor_east",
		"world_padise",
	]:
		if not MapCatalog.get_map(retired).is_empty():
			_failures.append("'%s' was retired and must not be in the catalog" % retired)
