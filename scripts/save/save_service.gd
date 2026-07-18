class_name SaveService
extends RefCounted

## Atomic one-slot persistence with a single rolling backup. P1-008 will add
## validation fixtures and version migration; this service only writes v1 envelopes.

const CURRENT_SAVE_VERSION := 1
const DEFAULT_SLOT := 0

var save_directory: String = "user://saves"


func slot_path(slot: int) -> String:
	return "%s/slot_%d.json" % [save_directory.trim_suffix("/"), slot]


func backup_path(slot: int) -> String:
	return "%s/slot_%d.bak.json" % [save_directory.trim_suffix("/"), slot]


func temp_path(slot: int) -> String:
	return "%s/slot_%d.tmp.json" % [save_directory.trim_suffix("/"), slot]


func has_save(slot: int = DEFAULT_SLOT) -> bool:
	return FileAccess.file_exists(slot_path(slot)) or FileAccess.file_exists(backup_path(slot))


func save_game(state: GameState, slot: int = DEFAULT_SLOT) -> bool:
	var envelope := {
		"save_version": CURRENT_SAVE_VERSION,
		"saved_at_unix": Time.get_unix_time_from_system(),
		"game_state": state.save_payload(),
	}
	var json := JSON.stringify(envelope, "\t")
	return _atomic_write(slot, json)


func load_game(slot: int = DEFAULT_SLOT) -> Dictionary:
	var result := {
		"ok": false,
		"state": null,
		"errors": PackedStringArray(),
		"source": "",
	}
	for source_path in [slot_path(slot), backup_path(slot)]:
		if not FileAccess.file_exists(source_path):
			continue
		var parsed := _read_envelope(source_path)
		if parsed.is_empty():
			continue
		var envelope_errors: Variant = parsed.get("errors", PackedStringArray())
		if envelope_errors is Array and not (envelope_errors as Array).is_empty():
			for entry in envelope_errors as Array:
				result["errors"].append(String(entry))
			continue
		result["ok"] = true
		result["state"] = parsed["state"]
		result["source"] = source_path
		return result

	if result["errors"].is_empty():
		result["errors"] = PackedStringArray(["no loadable save found for slot %d" % slot])
	return result


func _read_envelope(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	if text.is_empty():
		return {}

	var json := JSON.new()
	if json.parse(text) != OK:
		return {"errors": ["invalid JSON in %s" % path]}

	var parsed: Variant = json.data
	if not parsed is Dictionary:
		return {"errors": ["invalid JSON in %s" % path]}

	var envelope := parsed as Dictionary
	var save_version := int(envelope.get("save_version", 0))
	if save_version != CURRENT_SAVE_VERSION:
		return {
			"errors": [
				"unsupported save envelope version %d in %s" % [save_version, path]
			],
		}

	var game_payload: Variant = envelope.get("game_state", {})
	if not game_payload is Dictionary:
		return {"errors": ["missing game_state dictionary in %s" % path]}

	var state := GameState.new()
	var load_errors := state.load_payload(game_payload as Dictionary)
	if not load_errors.is_empty():
		return {"errors": load_errors}
	return {"state": state}


func _atomic_write(slot: int, json: String) -> bool:
	if not _ensure_directory():
		return false

	var target := slot_path(slot)
	var backup := backup_path(slot)
	var temp := temp_path(slot)

	if FileAccess.file_exists(temp):
		DirAccess.remove_absolute(temp)

	var temp_file := FileAccess.open(temp, FileAccess.WRITE)
	if temp_file == null:
		return false
	temp_file.store_string(json)
	temp_file.flush()
	temp_file.close()

	if FileAccess.file_exists(backup):
		DirAccess.remove_absolute(backup)
	if FileAccess.file_exists(target):
		var rename_backup := DirAccess.rename_absolute(target, backup)
		if rename_backup != OK:
			DirAccess.remove_absolute(temp)
			return false

	var rename_target := DirAccess.rename_absolute(temp, target)
	if rename_target != OK:
		# Restore the previous primary save when promotion fails.
		if FileAccess.file_exists(backup) and not FileAccess.file_exists(target):
			DirAccess.rename_absolute(backup, target)
		DirAccess.remove_absolute(temp)
		return false
	return true


func _ensure_directory() -> bool:
	var normalized := save_directory.trim_suffix("/")
	if normalized.is_empty():
		return false
	if DirAccess.dir_exists_absolute(normalized):
		return true
	return DirAccess.make_dir_recursive_absolute(normalized) == OK
