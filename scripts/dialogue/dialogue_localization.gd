class_name DialogueLocalization
extends RefCounted

## Deterministic, authored-only localization catalog resolver.
## Catalogs are flat JSON objects: {"locale": "en", "translations": {"key": "text"}}.

const DEFAULT_LOCALE := "en"

var default_locale: String = DEFAULT_LOCALE
var locale: String = DEFAULT_LOCALE
var _catalogs: Dictionary = {}


func set_locale(value: String) -> void:
	var normalized := _normalize_locale(value)
	locale = normalized if not normalized.is_empty() else default_locale


func get_locale() -> String:
	return locale


func add_catalog(catalog_locale: String, translations: Dictionary) -> bool:
	var normalized := _normalize_locale(catalog_locale)
	if normalized.is_empty() or translations.is_empty():
		return false
	var clean: Dictionary = {}
	for key: Variant in translations:
		if typeof(key) != TYPE_STRING:
			continue
		var value: Variant = translations[key]
		if typeof(value) == TYPE_STRING and not String(value).is_empty():
			clean[String(key)] = String(value)
	if clean.is_empty():
		return false
	_catalogs[normalized] = clean
	return true


func load_from_directories(directories: Array[String]) -> bool:
	_catalogs.clear()
	var loaded := false
	for directory in directories:
		var files: Array[String] = []
		_discover_json_files(directory, files)
		for path in files:
			if _load_catalog(path):
				loaded = true
	return loaded


func resolve(text_key: String, inline_text: String = "") -> String:
	var key := text_key.strip_edges()
	if not key.is_empty():
		for candidate in _locale_fallbacks():
			var catalog: Variant = _catalogs.get(candidate, {})
			if typeof(catalog) != TYPE_DICTIONARY:
				continue
			if catalog.has(key) and typeof(catalog[key]) == TYPE_STRING:
				var translated := String(catalog[key])
				if not translated.is_empty():
					return translated
	return inline_text


func _locale_fallbacks() -> Array[String]:
	var result: Array[String] = []
	_add_locale_candidate(result, locale)
	_add_locale_candidate(result, _base_locale(locale))
	_add_locale_candidate(result, default_locale)
	_add_locale_candidate(result, _base_locale(default_locale))
	return result


func _add_locale_candidate(result: Array[String], candidate: String) -> void:
	if not candidate.is_empty() and not result.has(candidate):
		result.append(candidate)


func _load_catalog(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var catalog: Dictionary = parsed
	var catalog_locale := String(catalog.get("locale", ""))
	var translations: Variant = catalog.get("translations", {})
	if typeof(translations) != TYPE_DICTIONARY:
		return false
	return add_catalog(catalog_locale, translations as Dictionary)


func _discover_json_files(directory: String, discovered: Array[String]) -> void:
	var dir := DirAccess.open(directory)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var path := directory.path_join(entry)
			if dir.current_is_dir():
				_discover_json_files(path, discovered)
			elif entry.ends_with(".json"):
				discovered.append(path)
		entry = dir.get_next()
	dir.list_dir_end()
	discovered.sort()


static func _normalize_locale(value: String) -> String:
	return value.strip_edges().to_lower().replace("_", "-")


static func _base_locale(value: String) -> String:
	var separator := value.find("-")
	return value.left(separator) if separator > 0 else value
