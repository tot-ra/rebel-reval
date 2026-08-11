class_name SaveService
extends RefCounted

## Atomic one-slot persistence with a single rolling backup. Validation and
## envelope migration live in SaveEnvelope (P1-008).

const CURRENT_SAVE_VERSION := SaveEnvelope.CURRENT_ENVELOPE_VERSION
const DEFAULT_SLOT := 0

## Scan all known save slots and return metadata for every valid save found.
## Each entry contains: slot (int), saved_at_unix (int), phase (String),
## location_id (String), spawn_id (String).
const MAX_SLOT := 8

## A temp path is shared by every SaveService targeting the same slot. Serialize
## the full rotation protocol so concurrent autosave/manual-save calls cannot
## delete or promote each other's temp files.
static var _write_mutex := Mutex.new()

var save_directory: String = "user://saves"


func slot_path(slot: int) -> String:
	return "%s/slot_%d.json" % [save_directory.trim_suffix("/"), slot]


func backup_path(slot: int) -> String:
	return "%s/slot_%d.bak.json" % [save_directory.trim_suffix("/"), slot]


func temp_path(slot: int) -> String:
	return "%s/slot_%d.tmp.json" % [save_directory.trim_suffix("/"), slot]


func has_save(slot: int = DEFAULT_SLOT) -> bool:
	return FileAccess.file_exists(slot_path(slot)) or FileAccess.file_exists(backup_path(slot))


## Returns metadata for every save slot that has a loadable envelope on disk.
## The list is sorted by saved_at_unix descending (most recent first).
func list_saves() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for slot in range(0, MAX_SLOT + 1):
		if not has_save(slot):
			continue
		var envelope := _read_envelope_meta(slot_path(slot))
		if envelope.is_empty():
			# Primary file missing or corrupt - try the backup.
			envelope = _read_envelope_meta(backup_path(slot))
		if envelope.is_empty():
			continue
		var game_state: Variant = envelope.get("game_state", {})
		if not game_state is Dictionary:
			continue
		var gs := game_state as Dictionary
		var player: Variant = gs.get("player", {})
		var location_id := ""
		if player is Dictionary:
			location_id = String((player as Dictionary).get("location_id", ""))
		(
			entries
			. append(
				{
					"slot": slot,
					"saved_at_unix": int(envelope.get("saved_at_unix", 0)),
					"phase": String(gs.get("phase", "")),
					"location_id": location_id,
				}
			)
		)
	entries.sort_custom(func(a, b): return a["saved_at_unix"] > b["saved_at_unix"])
	return entries


func save_game(state: GameState, slot: int = DEFAULT_SLOT) -> bool:
	var envelope := {
		"save_version": SaveEnvelope.CURRENT_ENVELOPE_VERSION,
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
		if not parsed.has("state"):
			for entry in parsed.get("errors", PackedStringArray()):
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
	var parsed := SaveEnvelope.parse_file(path)
	if not parsed["ok"]:
		return {"errors": parsed["errors"]}
	return {"state": parsed["state"]}


## Read only the outer envelope (without hydrating a full GameState) so we can
## display metadata cheaply for the save-list overlay.
func _read_envelope_meta(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	var parsed: Variant = json.data
	if not parsed is Dictionary:
		return {}
	var migrated := SaveEnvelope.migrate_envelope(parsed as Dictionary)
	if not migrated["ok"]:
		return {}
	return migrated["envelope"]


func _atomic_write(slot: int, json: String) -> bool:
	_write_mutex.lock()
	var succeeded := _atomic_write_locked(slot, json)
	_write_mutex.unlock()
	return succeeded


func _atomic_write_locked(slot: int, json: String) -> bool:
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
