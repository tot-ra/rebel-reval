class_name CitySiteRegistry
extends RefCounted

## Loads the city's landmark sites (ADR 0032) from the explicit registry
## `content/world/reval_city/sites/registry.json`, pairing each manifest with
## the placement the compiler wrote into the plan. A site whose manifest is
## missing or has no compiled placement is skipped with an error, and the
## generic buildings it would replace are already gone from the plan, so the
## compiler is the gate: run tools/city/build_reval_city_plan.py after editing.
## A regional site (ADR 0042) passes its own directory; without a registry
## there it has no landmark sites.

const SITES_DIR := "res://content/world/reval_city/sites"


static func load_for(plan_data: Dictionary, sites_dir: String = SITES_DIR) -> Array[CitySite]:
	var out: Array[CitySite] = []
	var registry := _read_json("%s/registry.json" % sites_dir)
	var placed: Dictionary = {}
	for record: Dictionary in plan_data.get("sites", []):
		placed[String(record["id"])] = record
	for name: String in registry.get("sites", []):
		var manifest := _read_json("%s/%s.json" % [sites_dir, name])
		if manifest.is_empty():
			push_error("City site manifest missing: %s" % name)
			continue
		var record: Dictionary = placed.get(String(manifest.get("id", "")), {})
		if record.is_empty():
			push_error("City site %s has no compiled placement; rebuild the plan" % name)
			continue
		out.append(CitySite.from_manifest(manifest, record))
	return out


static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
