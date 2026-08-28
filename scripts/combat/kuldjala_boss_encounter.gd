class_name KuldjalaBossEncounter
extends RefCounted

## Authored Kuldjala encounter. The alternate branch represents exposing the
## warden's illicit repair ledger and forcing a stand-down, not Nunnatorn's route.

const ENCOUNTER_ID := &"encounter.kuldjala_boss"
const BOSS_ID := &"kuldjala_boss"
const ENTRY_ANCHOR_ID := &"kuldjala_boss"
const ALTERNATE_ANCHOR_ID := &"kuldjala_boss_alternate_resolution"
const EXIT_ANCHOR_ID := &"kuldjala_exit"
const BOSS_NAME := "The Golden Leg Warden"
const QUEST_ID := &"quest.bitter_brew"
const RESOLVED_FLAG := &"flag.kuldjala_boss_resolved"
const DEFEATED_FLAG := &"flag.kuldjala_boss_defeated"
const ALTERNATE_FLAG := &"flag.kuldjala_boss_alternate_resolution"


static func enemy_composition() -> Array[Dictionary]:
	return [
		{
			"id": BOSS_ID,
			"display_name": BOSS_NAME,
			"archetype_id": EnemyArchetype.ID_WATCHMAN,
			"role": "named_boss",
			"anchor_id": ENTRY_ANCHOR_ID,
		},
		{
			"id": &"kuldjala_crossbow_guard",
			"display_name": "Golden Leg crossbow guard",
			"archetype_id": EnemyArchetype.ID_CROSSBOWMAN,
			"role": "wall_walk_guard",
			"anchor_id": &"kuldjala_wall_walk",
		},
	]


static func authored_anchors() -> Dictionary:
	return {
		"entry": ENTRY_ANCHOR_ID,
		"boss": ENTRY_ANCHOR_ID,
		"alternate": ALTERNATE_ANCHOR_ID,
		"wall_walk_guard": &"kuldjala_wall_walk",
		"exit": EXIT_ANCHOR_ID,
	}


static func definition_from_content(content_db: ContentDB) -> EncounterOutcomeDefinition:
	return EncounterOutcomeDefinition.from_content_db(content_db, ENCOUNTER_ID)


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
