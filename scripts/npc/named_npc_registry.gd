class_name NamedNpcRegistry
extends RefCounted

## The named NPCs of Reval (ADR 0044, docs/SYSTEMS/NAMED_NPCS.md): one data row
## per person in content/npcs/named_npcs.json, read by every system that shows
## them (city spawn, marker, faction identity, dialogue portrait). Static content:
## the registry never changes at runtime and is not saved.
## tools/validate_named_npcs.py is the full schema check; this loader rejects
## what would break the runtime (bad faction, bad census link, broken schedule).

const DATA_PATH := "res://content/npcs/named_npcs.json"
## Schedule anchor meaning "indoors at home_anchor" (not shown in the street).
const HOME := "home"
## Census link modes (ADR 0044 section 5).
const REPLACES := "replaces"
const EXTRA := "extra"

static var _default: NamedNpcRegistry

var npcs: Array[Dictionary] = []
var errors: PackedStringArray = []
var _by_id: Dictionary = {}


static func load_default() -> NamedNpcRegistry:
	if _default == null:
		_default = NamedNpcRegistry.new()
		if not _default.load_file(DATA_PATH):
			push_error("NamedNpcRegistry: %s" % "; ".join(_default.errors))
	return _default


## Faction ids a named NPC may carry: the eight launch seats plus candidate seats.
## Same source as tools/validate_named_npcs.py, which parses these constants.
static func known_faction(faction: Variant) -> bool:
	if faction == null:
		return true
	var key := String(faction)
	if not key.begins_with("faction."):
		return false
	var id := StringName(key.substr("faction.".length()))
	return FactionLedger.ACTIVE_FACTIONS.has(id) or FactionCandidateSeats.CANDIDATE_FACTIONS.has(id)


## Loads `path`; on any error the registry stays empty and `errors` says why.
func load_file(path: String) -> bool:
	npcs.clear()
	_by_id.clear()
	errors.clear()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or not (parsed as Dictionary).get("npcs") is Array:
		errors.append("cannot read %s" % path)
		return false
	var linked := {}
	var loaded: Array[Dictionary] = []
	for raw: Variant in parsed["npcs"]:
		if not raw is Dictionary:
			errors.append("entry is not an object")
			continue
		var npc: Dictionary = raw
		var id := String(npc.get("id", ""))
		if not id.begins_with("char.") or _by_id.has(id):
			errors.append("bad or duplicate id %s" % id)
			continue
		if not known_faction(npc.get("faction")):
			errors.append("%s: unknown faction %s" % [id, npc.get("faction")])
		var census: Variant = npc.get("census_id")
		if npc.get("census_mode") == REPLACES:
			if census == null or linked.has(census):
				errors.append("%s: census_id missing or linked twice" % id)
			linked[census] = true
		elif census != null:
			errors.append("%s: census_mode extra with a census_id" % id)
		if not _schedule_ok(npc.get("schedule")):
			errors.append("%s: schedule must cover 0..24 without gaps" % id)
		_by_id[id] = loaded.size()
		loaded.append(npc)
	if not errors.is_empty():
		_by_id.clear()
		return false
	npcs = loaded
	return true


func count() -> int:
	return npcs.size()


func ids() -> PackedStringArray:
	var out := PackedStringArray()
	for npc in npcs:
		out.append(String(npc["id"]))
	return out


func has_npc(id: String) -> bool:
	return _by_id.has(id)


## The registry row of `id`, or an empty dictionary.
func get_npc(id: String) -> Dictionary:
	return npcs[int(_by_id[id])] if _by_id.has(id) else {}


func by_faction(faction_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for npc in npcs:
		if npc.get("faction") == faction_id:
			out.append(npc)
	return out


## The named NPC that replaces census resident `census_id`, or an empty dictionary.
func by_census_id(census_id: String) -> Dictionary:
	for npc in npcs:
		if npc.get("census_mode") == REPLACES and npc.get("census_id") == census_id:
			return npc
	return {}


## Census resident ids the city must not spawn: a named NPC is that person.
func replaced_census_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for npc in npcs:
		if npc.get("census_mode") == REPLACES:
			out.append(String(npc["census_id"]))
	return out


## The schedule entry of `id` at `hour` (0..24): {from, to, anchor, prev_anchor}.
## `anchor` is a city anchor id or HOME; prev_anchor is the post before it
## (wrapping past midnight). Empty when `id` is unknown.
func post_at(id: String, hour: float) -> Dictionary:
	var npc := get_npc(id)
	if npc.is_empty():
		return {}
	return schedule_post(npc["schedule"], hour)


static func schedule_post(schedule: Array, hour: float) -> Dictionary:
	var h := fposmod(hour, 24.0)
	for i in schedule.size():
		var post: Dictionary = schedule[i]
		if h >= float(post["from"]) and h < float(post["to"]):
			var prev: Dictionary = schedule[i - 1] if i > 0 else schedule[-1]
			return {
				"from": float(post["from"]), "to": float(post["to"]),
				"anchor": String(post["anchor"]), "prev_anchor": String(prev["anchor"]),
			}
	return {}


static func _schedule_ok(schedule: Variant) -> bool:
	if not schedule is Array or (schedule as Array).is_empty():
		return false
	var t := 0.0
	for post: Variant in schedule:
		if not post is Dictionary:
			return false
		var from := float(post.get("from", -1.0))
		var to := float(post.get("to", -1.0))
		if not is_equal_approx(from, t) or to <= from or String(post.get("anchor", "")).is_empty():
			return false
		t = to
	return is_equal_approx(t, 24.0)
