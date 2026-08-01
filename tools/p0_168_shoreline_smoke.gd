extends SceneTree

const MAP_PATHS := [
	"res://content/maps/reval_harbor_east.rrmap",
	"res://content/maps/reval_harbor_north.rrmap",
]

func _init() -> void:
	var failures: Array[String] = []
	for path in MAP_PATHS:
		var parsed := MapRrmapParser.parse_file(path)
		if not parsed.is_ok():
			failures.append("%s: %s" % [path, str(parsed.formatted_diagnostics())])
			continue
		var confidence_zones: Dictionary = {}
		for zone in parsed.definition.zones:
			if zone.has("shore_confidence"):
				confidence_zones[String(zone["id"])] = zone
		for zone_id in ["shore.reconstructed_water", "shore.reconstructed_reed"]:
			if not confidence_zones.has(zone_id):
				failures.append("%s missing %s" % [path, zone_id])
				continue
			if confidence_zones[zone_id]["shore_confidence"] != &"reconstructed":
				failures.append("%s %s has wrong confidence" % [path, zone_id])
		var canonical := MapRrmapParser.canonical_print(parsed.blueprint)
		var reparsed := MapRrmapParser.parse(canonical, "%s.canonical.rrmap" % path)
		if not reparsed.is_ok():
			failures.append("%s canonical parse: %s" % [path, str(reparsed.formatted_diagnostics())])
		elif reparsed.definition.fingerprint != parsed.definition.fingerprint:
			failures.append("%s fingerprint changed on canonical round-trip" % path)
		else:
			print("PASS %s: %d confidence zones, canonical fingerprint stable" % [path, confidence_zones.size()])
	if not failures.is_empty():
		for failure in failures:
			push_error(failure)
		quit(1)
	else:
		print("P0-168 shoreline source smoke PASS")
		quit(0)
