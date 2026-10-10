class_name SpiritAuraProfile
extends RefCounted
## SS-2: deterministic soul-light data. No scene, RNG, or persistence side effects.

const LIGHT_IDS: Array[StringName] = GameState.NATURAL_ASPECT_IDS
const ELEMENTS: Dictionary = {
	&"aspect.nature": &"fear", &"aspect.affection": &"coin", &"aspect.tenacity": &"duty",
	&"aspect.unity": &"love", &"aspect.resonance": &"shame", &"aspect.awareness": &"sight",
	&"aspect.light": &"faith",
}
## Minimum NATURAL rank for each level, ascending; capped at level 5.
const RANK_BANDS: Array[int] = [5, 10, 15, 25, 40]
## Spirit-sight aura radius (ADR 0041 section 6): base metres at awareness level 2 and
## below, plus metres for each level above it.
const SIGHT_RADIUS_BASE := 12.0
const SIGHT_RADIUS_PER_LEVEL := 4.0
const SIGHT_RADIUS_BASE_LEVEL := 2
## Nature, unity, awareness; all other animal lights stay closed. Unknown species use default.
const SPECIES_LEVELS: Dictionary = {
	"default": [2, 2, 0],
	"dog": [3, 3, 2], "horse": [3, 2, 1], "cat": [3, 2, 0],
	"cow": [3, 2, 0], "pig": [3, 2, 0], "sheep": [2, 2, 0],
	"goat": [3, 2, 0], "chicken": [2, 1, 0], "crow": [2, 1, 0],
}

var levels: Dictionary[StringName, int] = {}
var clarity: float = 1.0
## Closed lights concealed from shallow reading, not an instruction to close a light.
var closed_mask: Array[StringName] = []


func _init() -> void:
	for light in LIGHT_IDS:
		levels[light] = 1


static func for_character(
	id: StringName, content_db: ContentDB, state: GameState = null
) -> SpiritAuraProfile:
	var record: Dictionary = {}
	if content_db != null and content_db.has_record(id):
		record = content_db.get_character(id)
	return from_record(id, record, state)


## Also accepts in-memory citizen metadata before it has a ContentDB record.
static func from_record(
	id: StringName, record: Dictionary, state: GameState = null
) -> SpiritAuraProfile:
	var profile := SpiritAuraProfile.new()
	var hero := id == &"char.apprentice" or bool(record.get("is_player", false))
	if hero:
		for aspect in LIGHT_IDS:
			var rank := GameState.NATURAL_ASPECT_BASELINE
			if state != null:
				rank = state.get_natural_aspect_rank(aspect)
			profile.levels[aspect] = level_for_rank(rank)
		# The hero has one progression source: authored aura levels cannot fork NATURAL.
		if record.get("aura") is Dictionary:
			profile._apply_mask(record["aura"])
	elif record.get("aura") is Dictionary:
		profile._apply_authored(record["aura"])
	elif not String(record.get("species", "")).is_empty():
		profile = for_species(String(record["species"]))
	else:
		profile._derive(id, record)
	# Hero conflict tracks the live ledger independently of NATURAL strength.
	if hero:
		var max_tier := 0
		if state != null:
			for school in GuiltLedger.SCHOOLS:
				max_tier = maxi(max_tier, state.guilt.debuff_tier(school))
		profile.clarity = clampf(1.0 - float(max_tier) / 3.0, 0.0, 1.0)
	return profile


## The lock parameter supports a future lock-aware reader without inventing saved state.
## GameState does not implement natural.lock_aspect yet; current calls use stored rank.
static func level_for_rank(rank: int, locked: bool = false) -> int:
	if locked:
		return 0
	var result := 0
	for threshold in RANK_BANDS:
		if rank >= threshold:
			result += 1
	return result


## The hero's awareness light from the stored rank, the same source as his aura. A null
## state is the neutral baseline.
static func hero_awareness_level(state: GameState) -> int:
	var rank := GameState.NATURAL_ASPECT_BASELINE
	if state != null:
		rank = state.get_natural_aspect_rank(&"aspect.awareness")
	return level_for_rank(rank)


## Levels at or below 2 keep the base radius; a dim gift never shrinks sight below it.
static func sight_radius_for_level(awareness_level: int) -> float:
	var above := maxi(0, awareness_level - SIGHT_RADIUS_BASE_LEVEL)
	return SIGHT_RADIUS_BASE + SIGHT_RADIUS_PER_LEVEL * float(above)


static func for_species(species: String) -> SpiritAuraProfile:
	var profile := SpiritAuraProfile.new()
	var values: Array = SPECIES_LEVELS.get(species.to_lower(), SPECIES_LEVELS["default"])
	for light in LIGHT_IDS:
		profile.levels[light] = 0
	profile.levels[&"aspect.nature"] = int(values[0])
	profile.levels[&"aspect.unity"] = int(values[1])
	profile.levels[&"aspect.awareness"] = int(values[2])
	return profile


func _apply_authored(aura: Dictionary) -> void:
	var authored_levels: Dictionary = aura.get("levels", {})
	for light in LIGHT_IDS:
		levels[light] = clampi(int(authored_levels.get(String(light), 1)), 0, 5)
	clarity = clampf(float(aura.get("clarity", 1.0)), 0.0, 1.0)
	_apply_mask(aura)


func _apply_mask(aura: Dictionary) -> void:
	for light in LIGHT_IDS:
		if levels[light] == 0 and String(light) in aura.get("closed_mask", []):
			closed_mask.append(light)


func _derive(id: StringName, record: Dictionary) -> void:
	var tags: Array[String] = []
	for tag: String in record.get("temperament", []):
		if not tags.has(tag):
			tags.append(tag)
	tags.sort()
	# Fixed array serialization and SHA-256 avoid Dictionary iteration order and
	# engine hash/RNG changes. Tags are a set: ordering does not alter a soul.
	var seed_text := JSON.stringify([
		String(id), String(record.get("faction", "")),
		String(record.get("profession", "")), tags,
	])
	var digest := seed_text.sha256_buffer()
	for i in LIGHT_IDS.size():
		levels[LIGHT_IDS[i]] = int(digest[i]) % 6
	clarity = float(digest[7]) / 255.0
