class_name NunnatornBossEncounter
extends RefCounted

## R-625: authored encounter adapter for the reserved Nunnatorn boss anchor.
## Why: the shared resolver owns state mutation and enemy closing; this class only
## supplies the deterministic encounter package and player-readable route IDs.

const ENCOUNTER_ID := &"encounter.nunnatorn_boss"
const BOSS_ID := &"nunnatorn_boss"
const ENTRY_ANCHOR_ID := &"nunnatorn_boss"
const ALTERNATE_ANCHOR_ID := &"nunnatorn_boss_alternate_resolution"
const EXIT_ANCHOR_ID := &"nunnatorn_exit"
const BOSS_NAME := "Marten of Nunnatorn"
const QUEST_ID := &"quest.bitter_brew"
const RESOLVED_FLAG := &"flag.nunnatorn_boss_resolved"
const DEFEATED_FLAG := &"flag.nunnatorn_boss_defeated"
const ALTERNATE_FLAG := &"flag.nunnatorn_boss_alternate_resolution"


## The leader is a sergeant-shaped boss and the guard is a watchman-shaped escort.
## A fixed order keeps tests and authored encounter entry deterministic.
static func enemy_composition() -> Array[Dictionary]:
	return [
		{
			"id": BOSS_ID,
			"display_name": BOSS_NAME,
			"archetype_id": EnemyArchetype.ID_SERGEANT,
			"role": "named_boss",
			"anchor_id": ENTRY_ANCHOR_ID,
		},
		{
			"id": &"nunnatorn_boss_guard",
			"display_name": "Nunnatorn tower guard",
			"archetype_id": EnemyArchetype.ID_WATCHMAN,
			"role": "escort",
			"anchor_id": ENTRY_ANCHOR_ID,
		},
	]


static func authored_anchors() -> Dictionary:
	return {
		"entry": ENTRY_ANCHOR_ID,
		"boss": ENTRY_ANCHOR_ID,
		"alternate": ALTERNATE_ANCHOR_ID,
		"exit": EXIT_ANCHOR_ID,
	}


static func definition_from_content(content_db: ContentDB) -> EncounterOutcomeDefinition:
	return EncounterOutcomeDefinition.from_content_db(content_db, ENCOUNTER_ID)


## Apply the authored branch marker after the shared resolver writes quest state.
## Unsupported kinds fail closed before any flag or enemy state is changed.
static func resolve(
	state: GameState,
	content_db: ContentDB,
	kind: StringName,
	enemies: Array = []
) -> bool:
	if kind != EncounterOutcome.KIND_KILL and kind != EncounterOutcome.KIND_BYPASS:
		return false
	var definition := definition_from_content(content_db)
	var resolver := EncounterOutcomeResolver.new()
	if not resolver.resolve(state, definition, kind, enemies):
		return false
	if kind == EncounterOutcome.KIND_KILL:
		state.set_flag(DEFEATED_FLAG, true)
	else:
		state.set_flag(ALTERNATE_FLAG, true)
	state.set_flag(RESOLVED_FLAG, true)
	return true
