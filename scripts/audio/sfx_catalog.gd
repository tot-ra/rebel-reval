class_name SfxCatalog
extends RefCounted

## Read-only view of content/audio/sfx_catalog.json (ADR 0035). Callers address
## sounds by stable ID and never reference stream files directly.

const DEFAULT_PATH := "res://content/audio/sfx_catalog.json"

## Parsed once per run: doors, footsteps and ambience all ask for the default
## catalog, and re-reading the JSON per caller showed up as avoidable churn.
static var _default_catalog: SfxCatalog

var _entries: Dictionary = {}


static func load_default() -> SfxCatalog:
	if _default_catalog == null:
		_default_catalog = load_from_path(DEFAULT_PATH)
	return _default_catalog


## Drops the shared instance. Tests that write a temporary catalog call this.
static func clear_default_cache() -> void:
	_default_catalog = null


static func load_from_path(path: String) -> SfxCatalog:
	var catalog := SfxCatalog.new()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("SfxCatalog: cannot open %s" % path)
		return catalog
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		catalog.load_dictionary(parsed)
	else:
		push_warning("SfxCatalog: %s is not a JSON object" % path)
	return catalog


func load_dictionary(data: Dictionary) -> void:
	_entries.clear()
	for raw in data.get("entries", []):
		if raw is Dictionary and raw.has("id"):
			_entries[StringName(raw["id"])] = raw


func has_entry(sound_id: StringName) -> bool:
	return _entries.has(sound_id)


func get_entry(sound_id: StringName) -> Dictionary:
	return _entries.get(sound_id, {})


func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for key in _entries.keys():
		out.append(key)
	out.sort()
	return out
