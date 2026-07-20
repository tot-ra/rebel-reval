class_name ContentDB
extends RefCounted

enum LookupResult {
	OK,
	NOT_LOADED,
	MALFORMED_ID,
	MISSING_ID,
	TYPE_MISMATCH,
}

const TYPE_CHARACTER := "character"
const TYPE_DIALOGUE := "dialogue"
const TYPE_BARK_POOL := "bark_pool"
const TYPE_QUEST := "quest"
const TYPE_ITEM := "item"
const TYPE_COMMISSION := "commission"
const TYPE_LOCATION := "location"
const TYPE_MECHANISM := "mechanism"
const TYPE_ENCOUNTER := "encounter"
const TYPE_PHASE_PROFILE := "phase_profile"

const CONTENT_ID_REGEX := "^[a-z][a-z0-9]*(\\.[a-z0-9_]+)+$"

const _TYPE_BY_PREFIX := {
	"char.": TYPE_CHARACTER,
	"dialogue.": TYPE_DIALOGUE,
	"bark.": TYPE_BARK_POOL,
	"quest.": TYPE_QUEST,
	"item.": TYPE_ITEM,
	"commission.": TYPE_COMMISSION,
	"loc.": TYPE_LOCATION,
	"mechanism.": TYPE_MECHANISM,
	"encounter.": TYPE_ENCOUNTER,
	"phase_profile.": TYPE_PHASE_PROFILE,
	"slicephase.": TYPE_PHASE_PROFILE,
}

static var _content_id_regex: RegEx

var _loaded := false
var _records: Dictionary = {}
var _last_lookup_result := LookupResult.OK
var _load_errors: Array[String] = []


static func _regex() -> RegEx:
	if _content_id_regex == null:
		_content_id_regex = RegEx.new()
		_content_id_regex.compile(CONTENT_ID_REGEX)
	return _content_id_regex


func load_from_directories(directories: Array[String]) -> bool:
	_loaded = false
	_records.clear()
	_load_errors.clear()
	_last_lookup_result = LookupResult.OK

	var json_files := _discover_json_files(directories)
	if not _load_errors.is_empty():
		return false

	var staged: Array[Dictionary] = []
	for path in json_files:
		var record: Dictionary = _read_json_object(path)
		if record.is_empty() and not _load_errors.is_empty():
			return false
		staged.append({
			"path": path,
			"record": record,
		})

	var seen_ids: Dictionary = {}
	var candidate_records: Dictionary = {}
	for entry in staged:
		var path := String(entry["path"])
		var record: Dictionary = entry["record"]
		var shape_error := _validate_record_shape(record, path)
		if not shape_error.is_empty():
			_load_errors.append(shape_error)
			return false

		var content_id := StringName(String(record["id"]))
		if seen_ids.has(content_id):
			_load_errors.append(
				"%s: duplicate global content id %s (first in %s)"
				% [path, String(content_id), String(seen_ids[content_id])]
			)
			return false
		seen_ids[content_id] = path
		candidate_records[content_id] = record.duplicate(true)

	# Publish only after every file has passed runtime shape and uniqueness checks.
	# A failed reload must never expose a partially built index to callers.
	_records = candidate_records
	_loaded = true
	return true


func is_loaded() -> bool:
	return _loaded


func get_record_count() -> int:
	return _records.size()


func get_load_errors() -> Array[String]:
	return _load_errors.duplicate()


func get_last_lookup_result() -> LookupResult:
	return _last_lookup_result


func has_record(content_id: StringName) -> bool:
	if not _loaded:
		return false
	if not _is_valid_content_id(content_id):
		return false
	return _records.has(content_id)


func get_record_type(content_id: StringName) -> String:
	if not has_record(content_id):
		return ""
	var record: Dictionary = _records[content_id]
	return String(record.get("type", ""))


func lookup(content_id: StringName) -> Dictionary:
	_last_lookup_result = LookupResult.OK
	if not _loaded:
		_last_lookup_result = LookupResult.NOT_LOADED
		return {}
	if not _is_valid_content_id(content_id):
		_last_lookup_result = LookupResult.MALFORMED_ID
		return {}
	if not _records.has(content_id):
		_last_lookup_result = LookupResult.MISSING_ID
		return {}
	return (_records[content_id] as Dictionary).duplicate(true)


func get_character(content_id: StringName) -> Dictionary:
	return _lookup_typed(content_id, TYPE_CHARACTER)


func get_dialogue(content_id: StringName) -> Dictionary:
	return _lookup_typed(content_id, TYPE_DIALOGUE)


func get_bark_pool(content_id: StringName) -> Dictionary:
	return _lookup_typed(content_id, TYPE_BARK_POOL)


func get_quest(content_id: StringName) -> Dictionary:
	return _lookup_typed(content_id, TYPE_QUEST)


func get_item(content_id: StringName) -> Dictionary:
	return _lookup_typed(content_id, TYPE_ITEM)


func get_commission(content_id: StringName) -> Dictionary:
	return _lookup_typed(content_id, TYPE_COMMISSION)


func get_location(content_id: StringName) -> Dictionary:
	return _lookup_typed(content_id, TYPE_LOCATION)


func get_mechanism(content_id: StringName) -> Dictionary:
	return _lookup_typed(content_id, TYPE_MECHANISM)


func get_encounter(content_id: StringName) -> Dictionary:
	return _lookup_typed(content_id, TYPE_ENCOUNTER)


func get_phase_profile(content_id: StringName) -> Dictionary:
	return _lookup_typed(content_id, TYPE_PHASE_PROFILE)


func get_ids_by_type(expected_type: String) -> Array[StringName]:
	var ids: Array[StringName] = []
	if not _loaded:
		return ids
	for content_id: StringName in _records:
		var record: Dictionary = _records[content_id]
		if String(record.get("type", "")) == expected_type:
			ids.append(content_id)
	ids.sort()
	return ids


func _lookup_typed(content_id: StringName, expected_type: String) -> Dictionary:
	var record := lookup(content_id)
	if record.is_empty():
		return {}
	if String(record.get("type", "")) != expected_type:
		_last_lookup_result = LookupResult.TYPE_MISMATCH
		return {}
	return record


func _discover_json_files(directories: Array[String]) -> Array[String]:
	var discovered: Array[String] = []
	for directory in directories:
		_discover_json_files_in(directory, discovered)
	discovered.sort()
	return discovered


func _discover_json_files_in(directory: String, discovered: Array[String]) -> void:
	var dir := DirAccess.open(directory)
	if dir == null:
		_load_errors.append("content directory is missing or unreadable: %s" % directory)
		return

	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var path := directory.path_join(entry)
			if dir.current_is_dir():
				_discover_json_files_in(path, discovered)
			elif entry.ends_with(".json"):
				discovered.append(path)
		entry = dir.get_next()
	dir.list_dir_end()


func _read_json_object(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		_load_errors.append("content file is missing: %s" % path)
		return {}

	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed == null:
		_load_errors.append("invalid JSON in %s" % path)
		return {}
	if typeof(parsed) != TYPE_DICTIONARY:
		_load_errors.append("top-level JSON value must be an object in %s" % path)
		return {}
	return parsed as Dictionary


func _validate_record_shape(record: Dictionary, path: String) -> String:
	if not record.has("type") or typeof(record["type"]) != TYPE_STRING or String(record["type"]).is_empty():
		return "%s: missing or invalid type field" % path
	if not record.has("id") or typeof(record["id"]) != TYPE_STRING:
		return "%s: missing or invalid id field" % path

	var content_id := String(record["id"])
	if not _is_valid_content_id_string(content_id):
		return "%s: malformed content id %s" % [path, content_id]

	var expected_type := _expected_type_for_id(content_id)
	if expected_type.is_empty():
		return "%s: unknown content id prefix for %s" % [path, content_id]
	if String(record["type"]) != expected_type:
		return "%s: id prefix implies type %s, got %s" % [path, expected_type, String(record["type"])]
	return ""


func _expected_type_for_id(content_id: String) -> String:
	for prefix in _TYPE_BY_PREFIX.keys():
		if content_id.begins_with(prefix):
			return String(_TYPE_BY_PREFIX[prefix])
	return ""


func _is_valid_content_id(content_id: StringName) -> bool:
	return _is_valid_content_id_string(String(content_id))


func _is_valid_content_id_string(content_id: String) -> bool:
	if content_id.is_empty():
		return false
	return _regex().search(content_id) != null
