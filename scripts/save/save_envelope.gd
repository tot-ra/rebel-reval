class_name SaveEnvelope
extends RefCounted

## Validation and version migration for save-slot JSON envelopes (P1-008).
## SaveService writes the current envelope; this class parses, migrates older
## shapes, validates types, and hydrates GameState payloads.

const CURRENT_ENVELOPE_VERSION := 1
const RELEASED_MANIFEST_PATH := "res://content/saves/released_manifest.json"
const RELEASED_ROOT := "res://content/saves/"


static func parse_text(text: String) -> Dictionary:
	var result := {
		"ok": false,
		"state": null,
		"errors": PackedStringArray(),
		"migrated_from": -1,
		"envelope": {},
	}
	if text.is_empty():
		result["errors"] = PackedStringArray(["save file is empty or truncated"])
		return result

	var json := JSON.new()
	if json.parse(text) != OK:
		result["errors"] = PackedStringArray(["invalid JSON: %s" % json.get_error_message()])
		return result

	var parsed: Variant = json.data
	if not parsed is Dictionary:
		result["errors"] = PackedStringArray(["save root must be a JSON object"])
		return result

	var migrated := migrate_envelope(parsed as Dictionary)
	if not migrated["ok"]:
		result["errors"] = migrated["errors"]
		result["migrated_from"] = migrated["migrated_from"]
		return result

	var envelope: Dictionary = migrated["envelope"]
	result["migrated_from"] = migrated["migrated_from"]
	result["envelope"] = envelope

	var loaded := load_game_state_from_envelope(envelope)
	if not loaded["ok"]:
		result["errors"] = loaded["errors"]
		return result

	result["ok"] = true
	result["state"] = loaded["state"]
	return result


static func parse_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {
			"ok": false,
			"state": null,
			"errors": PackedStringArray(["save file not found: %s" % path]),
			"migrated_from": -1,
			"envelope": {},
		}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {
			"ok": false,
			"state": null,
			"errors": PackedStringArray(["could not open save file: %s" % path]),
			"migrated_from": -1,
			"envelope": {},
		}
	var text := file.get_as_text()
	file.close()
	var result := parse_text(text)
	if result["ok"]:
		result["source"] = path
	return result


static func migrate_envelope(raw: Dictionary) -> Dictionary:
	var result := {
		"ok": false,
		"envelope": {},
		"errors": PackedStringArray(),
		"migrated_from": -1,
	}
	var envelope := raw.duplicate(true)
	var version := _detect_envelope_version(envelope)
	var migrated_from := -1

	while version < SaveEnvelope.CURRENT_ENVELOPE_VERSION:
		if migrated_from < 0:
			migrated_from = version
		match version:
			0:
				envelope = _migrate_v0_to_v1(envelope)
				version = 1
			_:
				result["errors"] = PackedStringArray([
					"unsupported save envelope version %d (supported: 0-%d)" % [
						version,
						SaveEnvelope.CURRENT_ENVELOPE_VERSION,
					]
				])
				result["migrated_from"] = migrated_from
				return result

	if version > SaveEnvelope.CURRENT_ENVELOPE_VERSION:
		result["errors"] = PackedStringArray([
			"unsupported save envelope version %d (supported: 0-%d)" % [
				version,
				SaveEnvelope.CURRENT_ENVELOPE_VERSION,
			]
		])
		result["migrated_from"] = migrated_from
		return result

	var shape_errors := _validate_envelope_shape(envelope)
	if not shape_errors.is_empty():
		result["errors"] = shape_errors
		result["migrated_from"] = migrated_from
		return result

	result["ok"] = true
	result["envelope"] = envelope
	result["migrated_from"] = migrated_from
	return result


static func load_game_state_from_envelope(envelope: Dictionary) -> Dictionary:
	var result := {
		"ok": false,
		"state": null,
		"errors": PackedStringArray(),
	}
	var game_payload: Variant = envelope.get("game_state", {})
	if not game_payload is Dictionary:
		result["errors"] = PackedStringArray(["game_state must be a dictionary"])
		return result

	var state := GameState.new()
	var load_errors := state.load_payload(game_payload as Dictionary)
	if not load_errors.is_empty():
		for entry in load_errors:
			result["errors"].append(String(entry))
		return result

	result["ok"] = true
	result["state"] = state
	return result


static func list_released_fixture_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if not FileAccess.file_exists(RELEASED_MANIFEST_PATH):
		return entries

	var file := FileAccess.open(RELEASED_MANIFEST_PATH, FileAccess.READ)
	if file == null:
		return entries
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		return entries
	file.close()

	var parsed: Variant = json.data
	if not parsed is Dictionary:
		return entries
	var fixtures: Variant = (parsed as Dictionary).get("fixtures", [])
	if not fixtures is Array:
		return entries
	for row in fixtures as Array:
		if row is Dictionary:
			entries.append((row as Dictionary).duplicate(true))
	return entries


static func released_fixture_path(relative_path: String) -> String:
	return "%s%s" % [RELEASED_ROOT, relative_path.trim_prefix("/")]


static func _detect_envelope_version(envelope: Dictionary) -> int:
	if envelope.has("save_version"):
		return int(envelope.get("save_version", 0))
	# Pre-envelope v1 used "version" plus either "state" or "game_state".
	if envelope.has("version") and (envelope.has("state") or envelope.has("game_state")):
		return 0
	return int(envelope.get("save_version", 0))


static func _migrate_v0_to_v1(envelope: Dictionary) -> Dictionary:
	var saved_at: Variant = envelope.get("saved_at_unix", envelope.get("saved_at", 0))
	var game_state: Variant = envelope.get("game_state", envelope.get("state", {}))
	return {
		"save_version": SaveEnvelope.CURRENT_ENVELOPE_VERSION,
		"saved_at_unix": int(saved_at),
		"game_state": game_state if game_state is Dictionary else {},
	}


static func _validate_envelope_shape(envelope: Dictionary) -> PackedStringArray:
	var errors: PackedStringArray = []
	if int(envelope.get("save_version", 0)) != SaveEnvelope.CURRENT_ENVELOPE_VERSION:
		errors.append(
			"envelope save_version must be %d" % SaveEnvelope.CURRENT_ENVELOPE_VERSION
		)

	var saved_at: Variant = envelope.get("saved_at_unix", null)
	if saved_at != null and not (saved_at is int or saved_at is float):
		errors.append("saved_at_unix must be a number")

	var game_state: Variant = envelope.get("game_state", null)
	if game_state == null:
		errors.append("game_state is required")
	elif not game_state is Dictionary:
		errors.append("game_state must be a dictionary")

	return errors
