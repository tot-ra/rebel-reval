class_name SpiritSpellCatalog
extends RefCounted
## Read-only catalogue of the psychological word spells (ADR 0048, SPL-1 R-1913): one JSON record
## per spell in content/spirit_spells, validated offline by tools/validate_content.py
## (schemas/spirit_spell.schema.json). Nothing reads it in play yet; SpiritDuel (SPL-2) and the
## cast bar loadout (SPL-4) will. Deterministic: records are kept sorted by id, starters in the
## slot order of SpiritWordSpells.DEFAULT_ELEMENTS.

const DEFAULT_DIRECTORY := "res://content/spirit_spells"
const RECORD_TYPE := "spirit_spell"
const ID_PREFIX := "spell.word."
const KIND_LOWERING := &"lowering"
const KIND_RAISING := &"raising"
const KIND_MIXED := &"mixed"
const LINE_DEFAULT := "default"

var _spells: Dictionary = {}
var _ids: Array[StringName] = []
var _errors: Array[String] = []


## Load every record under `directory`. Returns false (and keeps nothing) when a file is
## unreadable, malformed or repeats an id; errors() says why.
func load_catalog(directory: String = DEFAULT_DIRECTORY) -> bool:
	_spells.clear()
	_ids.clear()
	_errors.clear()
	var dir := DirAccess.open(directory)
	if dir == null:
		_errors.append("spirit spell directory is missing or unreadable: %s" % directory)
		return false
	var files: Array[String] = []
	for entry: String in dir.get_files():
		if entry.ends_with(".json"):
			files.append(directory.path_join(entry))
	files.sort()
	var staged: Dictionary = {}
	for path: String in files:
		var record := _read_record(path)
		if record.is_empty():
			return false
		var spell_id := StringName(String(record["id"]))
		if staged.has(spell_id):
			_errors.append("%s: duplicate spirit spell id %s" % [path, spell_id])
			return false
		staged[spell_id] = record
	if staged.is_empty():
		_errors.append("no spirit spells in %s" % directory)
		return false
	# Publish only a complete catalogue, never a half-read one.
	_spells = staged
	for spell_id: StringName in staged.keys():
		_ids.append(spell_id)
	_ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return true


func errors() -> Array[String]:
	return _errors.duplicate()


func size() -> int:
	return _ids.size()


func has_spell(spell_id: StringName) -> bool:
	return _spells.has(spell_id)


## Every spell id, sorted.
func ids() -> Array[StringName]:
	return _ids.duplicate()


## A copy of the record, {} when unknown.
func get_spell(spell_id: StringName) -> Dictionary:
	var record: Dictionary = _spells.get(spell_id, {})
	return record.duplicate(true)


## Starter ids in slot order (SpiritWordSpells.DEFAULT_ELEMENTS); an element without a starter
## is skipped.
func starter_ids() -> Array[StringName]:
	var by_element: Dictionary = {}
	for spell_id: StringName in _ids:
		var record: Dictionary = _spells[spell_id]
		if bool(record.get("starter", false)):
			by_element[StringName(String(record.get("element", "")))] = spell_id
	var result: Array[StringName] = []
	for element: StringName in SpiritWordSpells.DEFAULT_ELEMENTS:
		if by_element.has(element):
			result.append(by_element[element])
	return result


## Spell ids of `element`, sorted; `kind` filters to lowering / raising / mixed when given.
func ids_for_element(element: StringName, kind: StringName = &"") -> Array[StringName]:
	var result: Array[StringName] = []
	for spell_id: StringName in _ids:
		var record: Dictionary = _spells[spell_id]
		if StringName(String(record.get("element", ""))) != element:
			continue
		if kind != &"" and StringName(String(record.get("kind", ""))) != kind:
			continue
		result.append(spell_id)
	return result


## Signed delta the spell puts on `aspect`, 0 when it does not touch that light.
func light_delta(spell_id: StringName, aspect: StringName) -> int:
	var record: Dictionary = _spells.get(spell_id, {})
	for entry: Variant in record.get("light_vector", []):
		if entry is Dictionary and StringName(String(entry.get("aspect", ""))) == aspect:
			return int(entry.get("delta", 0))
	return 0


## Authored lines of `context` (answer.<kind>, topic.<id>, weak, default); empty when absent.
func lines(spell_id: StringName, context: String = LINE_DEFAULT) -> Array[String]:
	var result: Array[String] = []
	var record: Dictionary = _spells.get(spell_id, {})
	var by_context: Dictionary = record.get("lines", {})
	for line: Variant in by_context.get(context, []):
		result.append(String(line))
	return result


## Runtime shape guard only; the full rules are the offline validator's job.
func _read_record(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		_errors.append("%s: not a JSON object" % path)
		return {}
	var record: Dictionary = parsed
	if String(record.get("type", "")) != RECORD_TYPE:
		_errors.append("%s: type must be %s" % [path, RECORD_TYPE])
		return {}
	if not String(record.get("id", "")).begins_with(ID_PREFIX):
		_errors.append("%s: id must start with %s" % [path, ID_PREFIX])
		return {}
	var vector: Variant = record.get("light_vector", [])
	if not vector is Array or (vector as Array).is_empty():
		_errors.append("%s: light_vector is missing" % path)
		return {}
	var by_context: Variant = record.get("lines", {})
	if not by_context is Dictionary or not (by_context as Dictionary).has(LINE_DEFAULT):
		_errors.append("%s: default lines are missing" % path)
		return {}
	return record
