# Scene Outline: Root and Ember

## Context

**Type:** Act 1 folklore cycle quest (P4-007)  
**Timeline:** Late spring 1343, after harbor detention round-ups  
**Canon status:** active outline; ambiguous kodukäija / hearth disturbance without literal magic  
**Quest id:** `quest.root_and_ember`

## Premise

Ellen Luik asks Kalev to help a frightened household beside the Foaming Mug brewery. Their hearth throws soot and cold drafts at night. Neighbors whisper about a kodukäija (restless household spirit). Ellen offers an old song and monastery herbs; Kalev can forge an Ember-warmed hook, a Root-ward inlaid with herbs, or a plain iron smoke bracket that explains the trouble as cracked flue work. The household calms, but whether a spirit was laid to rest or a chimney was repaired stays deliberately unclear.

## Locations

* **Lower Town slice (`loc.lower_town.slice`):** Ellen meets Kalev on Mart Street; the disturbed hearth sits beside `brewery_door`; monastery herb lane is reached through `katariina_kaik`.
* **Kalev's Smithy (`loc.kalev_smithy`):** Commission forge work for the hearth ward hardware.

## Characters

* **Ellen Luik:** Midwife and keeper of old songs; quest-giver; distinguishes witnessed soot from sung omens.
* **Kalev:** Player; chooses folklore-facing or materialist craft without a universal morality score.

## Day Phase: Investigation

Three authored inspection sites (journal facts, no new investigation framework):

1. **Ellen on Mart Street:** Ellen summons Kalev and describes the household's night terrors (`fact.root_and_ember.ellen_summoned`).
2. **Disturbed hearth:** Soot climbs the wrong wall; drafts pull cold when the flue should draw warm (`fact.root_and_ember.soot_updraft`).
3. **Monastery herb lane:** Dried roots and linden bark Ellen uses for birth wards (`fact.root_and_ember.herb_lane_roots`).

## Forge Phase: Commission

Commission record: `commission.root_and_ember` (reuses `ForgeCommissionRunner` and modification branches).

| Option | Technique introduced | Label |
| :--- | :--- | :--- |
| `ember_rite` | **Ember** | Warm iron hearth-hook with Ellen's sung rite words |
| `root_ward` | **Root** | Herb-inlaid ward hook using monastery lane roots |
| `iron_bracket` | (materialist) | Practical smoke-hood bracket; no spirit vocabulary |

Each option writes a forged record, Ellen outcome flag, household location state, and a Hingepuu reflection mark through `mechanism.root_and_ember_hearth`.

## Day Phase: Household Install

Peaceful install at the brewery-neighbor hearth (`interact.root_and_ember.hearth_install`). No combat subsystem; mechanism commit resolves household calm.

## Aftermath States

| State | Forging option | Visible consequence |
| :--- | :--- | :--- |
| Belief honored | `ember_rite` | Household keeps Ellen's song; Ember technique equipped; Mercy reflection mark |
| Remedy trusted | `root_ward` | Household trusts herb ward; Root technique equipped; Mercy reflection mark |
| Skepticism respected | `iron_bracket` | Household accepts flue repair; Ellen notes Kalev's honesty; Duty reflection mark |

## Hingepuu Reflection Hook

Mechanism responses set `flag.reflection.conviction_mercy` (ember/root) or `flag.reflection.conviction_duty` (iron) without confirming supernatural agency.

## Systems Reused

* Quest package pipeline (P4-018)
* Investigation interactables and journal facts
* Forge commission modifications (not a second-game subsystem)
* Mechanism resolver for install aftermath
* Patrol bark pool for Mart's street commentary
* Existing Ember / Root forge technique IDs

## Confidence

`folklore` for kodukäija framing; `plausible composite` for Ellen Luik; `invented` for quest structure.
