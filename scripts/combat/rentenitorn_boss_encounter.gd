class_name RentenitornBossEncounter
extends RefCounted

## Authored Rentenitorn encounter. The alternate branch represents serving the
## town's sealed rent tally so the watcher must unseal the strongroom and stand
## down. It is deliberately neither Nunnatorn's parley nor Kuldjala's repair
## ledger, and the composition inverts the usual leader/escort archetypes: the
## named boss shoots down the closed tower from the counting chamber while the
## hired strongarm holds the dues chest below.

const ENCOUNTER_ID := &"encounter.rentenitorn_boss"
const BOSS_ID := &"rentenitorn_boss"
const ENTRY_ANCHOR_ID := &"rentenitorn_boss"
const ALTERNATE_ANCHOR_ID := &"rentenitorn_boss_alternate_resolution"
const STRONGROOM_ANCHOR_ID := &"rentenitorn_floor_ground"
const EXIT_ANCHOR_ID := &"rentenitorn_exit"
const BOSS_NAME := "The Rent Tower Watcher"
const QUEST_ID := &"quest.bitter_brew"
const RESOLVED_FLAG := &"flag.rentenitorn_boss_resolved"
const DEFEATED_FLAG := &"flag.rentenitorn_boss_defeated"
const ALTERNATE_FLAG := &"flag.rentenitorn_boss_alternate_resolution"


static func enemy_composition() -> Array[Dictionary]:
	return [
		{
			"id": BOSS_ID,
			"display_name": BOSS_NAME,
			"archetype_id": EnemyArchetype.ID_CROSSBOWMAN,
			"role": "named_boss",
			"anchor_id": ENTRY_ANCHOR_ID,
		},
		{
			"id": &"rentenitorn_strongroom_strongarm",
			"display_name": "Rent Tower strongarm",
			"archetype_id": EnemyArchetype.ID_BANDIT,
			"role": "strongroom_guard",
			"anchor_id": STRONGROOM_ANCHOR_ID,
		},
	]


static func authored_anchors() -> Dictionary:
	return {
		"entry": ENTRY_ANCHOR_ID,
		"boss": ENTRY_ANCHOR_ID,
		"alternate": ALTERNATE_ANCHOR_ID,
		"strongroom_guard": STRONGROOM_ANCHOR_ID,
		"exit": EXIT_ANCHOR_ID,
	}


static func definition_from_content(content_db: ContentDB) -> EncounterOutcomeDefinition:
	return EncounterOutcomeDefinition.from_content_db(content_db, ENCOUNTER_ID)


## Unsupported kinds fail closed before any flag, quest state, or enemy changes.
static func resolve(
	state: GameState,
	content_db: ContentDB,
	kind: StringName,
	enemies: Array = [],
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
