# Quests, commissions, and investigations

Status: implemented for the Act 1 commission cycles (tasks **P2-007..P2-010**, **P4-002..P4-009**); Act 2 mission offers wired through `SessionState` (**P5-006**); Act 2 finale and Act 3 ending are data models with tests only (see [Limits](#limits)). Scope: quest state machines, the forge commission loop, daytime investigations, night install consequences, and aftermath. Out of scope: dialogue playback ([`DIALOGUE.md`](./DIALOGUE.md)) and the condition/effect engine ([`STATE_AND_SAVES.md`](./STATE_AND_SAVES.md)).

## Player loop

Each Act 1 cycle follows the README loop: **commission → investigation → modification → consequence → reflection**.

1. A client brings a commission to the forge ledger (`ForgeCommissionAnchor` interactable in the forge scene).
2. Kalev investigates by day: each cycle has authored inspection sites that record `fact.*` evidence. When the required facts are known, the quest moves `investigating → investigation_ready`.
3. Back at the ledger, the commission overlay shows the order, the hidden contradiction, and forging options. Choosing one plays a narrative forging sequence (`ForgeFeedbackSequence`; no timing or accuracy minigame) and writes a forged record.
4. At night the object is installed or used. The install consequence reads the forged record and opens or closes routes (talk, bypass, fight, surrender).
5. Aftermath models map the forged record to one of three outcome families, which change patrol barks, NPC dialogue, and act-climax bias flags.

## Cycles

| Quest ID | Narrative | Runtime entry points | Outcome families |
|---|---|---|---|
| `quest.bitter_brew` | [A Bitter Brew](../SCENES/a-bitter-brew.md) | `BitterBrewInvestigation`, `BitterBrewCommissionController`, `BitterBrewNightConsequence`, `BitterBrewAftermath` | exonerated / confiscated / monopolized |
| `quest.bell_and_chain` | [The Bell and the Chain](../SCENES/the-bell-and-the-chain.md) ([branch map](../SCENES/the-bell-and-the-chain-branch-map.md)) | `BellAndChain*` in `scripts/investigation/`, `scripts/forge/` | honest / defect / release |
| `quest.bread_and_iron` | [Bread and Iron](../SCENES/bread-and-iron.md) ([branch map](../SCENES/bread-and-iron-branch-map.md)) | `BreadAndIron*` | supplied / rationed / debt |
| `quest.price_of_a_name` | [The Price of a Name](../SCENES/the-price-of-a-name.md) ([branch map](../SCENES/the-price-of-a-name-branch-map.md)) | `PriceOfAName*` | cleared / redirected / concealed |
| `quest.root_and_ember` | [Root and Ember](../SCENES/root-and-ember.md) ([branch map](../SCENES/root-and-ember-branch-map.md)) | `RootAndEmber*` | ember / root / iron |
| `quest.st_georges_night` | [St. George's Night](../SCENES/st-georges-night.md) ([branch map](../SCENES/st-georges-night-branch-map.md)) | `StGeorgesNightClimax`, `StGeorgesNightAftermath` | seal / break / open (act boundary) |

The Maker's Mark prologue (`ForgePrologueController`, wired from `scenes/reval_east/forge/forge.gd`) teaches the loop: repair commission, Henning confrontation, missing-apprentice discovery, ledger choice, and bed-rest gating until Kalev commits.

Per-cycle gating (which phases allow investigation, forging, and install; the unlock flag) lives in the matching `scripts/quest/*_quest_model.gd`. Each cycle unlocks the next through a `flag.act1_<cycle>_unlocked` flag.

## Runtime pieces

| Piece | File | Role |
|---|---|---|
| `QuestManager` | `scripts/quest/quest_manager.gd` | The only writer of quest state. `start_quest(id)` and `transition(id, transition_id)` validate the whole quest graph, the transition's conditions, and the effect batch before applying anything. `get_last_error()` explains a refusal. |
| `ForgeCommissionRunner` / `ForgeCommissionModel` | `scripts/forge/` | Build the commission snapshot from `commission.*` content plus `GameState`, resolve the chosen forging option, emit `forging_started` / `finished`. |
| `ForgeCommissionOverlay`, `ForgeFeedbackOverlay` | `scripts/forge/` | Commission UI and forging beats. `ForgeCommissionUiPresenter` bridges runner and overlays. |
| `CommissionDeadlineModel` | `scripts/commission/` | Resolves a commission's `deadline` against phase order: `active`, `met`, `missed`. Backs the `commission_deadline_met` / `_missed` conditions and journal display. |
| `*Investigation` | `scripts/investigation/` | Spawn inspection-site interactables, play inspection dialogue, record facts, then call `QuestManager.transition(..., &"complete_investigation")`. |
| `*InstallConsequence`, `*NightConsequence` | `scripts/investigation/` | Night encounter at the install site, gated by the forged record. |
| `*AftermathModel` + `*Aftermath` | `scripts/investigation/` | Pure resolver from forged records/flags to an outcome family, and the scene node that swaps bark pools and NPC state. |
| `InvestigativeQuestModel` | `scripts/quest/` | Suspect pools and confrontation tiers (`blind` / `partial` / `narrow` / `resolved`) for quests declaring an `investigation` block (example: `quest.stolen_iron`). |
| `Act1AftermathModel` | `scripts/quest/` | When `flag.act_transition.act1_recorded` is written, snapshots character, forge, and district aftermath into one envelope for Act 2. Manifest: `docs/data/act1_aftermath_manifest.json`. |
| `Act2MissionHost` | `scripts/quest/`, owned by `SessionState` | Offers the Act 2 siege packages by siege phase (investment, sortie/supply, assault) and alignment (rebel / ruler, min standing 2), then delegates to `QuestManager`. |
| `NunnatornEvidenceModel` | `scripts/quest/` | Collects the one authored loot/evidence outcome after the Nunnatorn encounter, idempotently. |

## Content

- Quest records: `type: quest`, schema [`schemas/quest.schema.json`](../../schemas/quest.schema.json). A quest is `initial_state`, `states[]` (with `terminal`), and `transitions[]` with `conditions` and `effects`. Conditions and effects use the shared allowlist in [`STATE_AND_SAVES.md`](./STATE_AND_SAVES.md#conditions-and-effects).
- Commission records: [`schemas/commission.schema.json`](../../schemas/commission.schema.json): client, object item, concrete order, hidden contradiction, investigation clues, forging options, night consequence, optional deadline.
- Act 1 records live in `content/examples/valid/` (bitter brew, prologue) and in quest packages under [`content/packages/`](../../content/packages/README.md). A package bundles `quest.json`, `branch_map.json`, and support dialogue; `tools/generate_quest_package_tests.py` emits branch-traversal Godot tests from the branch map.
- Faction quest seeds (not runtime): [`docs/quests/`](../quests/README.md).

## Saved state

Quest state, flags, facts, and forged records live in `GameState` and save with it. Forged records are the persistent memory of what Kalev made (see README "Objects and people remember").

## Verify

```bash
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_quest
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_bitter_brew
python3 tools/verify_quest_packages.py
python3 tools/generate_quest_package_tests.py --check
```

Act gates: `tests/godot/test_act1_*.gd`, `docs/reports/p4_012_act1_gate.md`, `docs/reports/p5_010_act2_gate.md`.

## Limits

- `PaideFinaleModel` (Act 2 finale) and `Act3EndingModel` (1346 sale of Estonia) are deterministic envelope models exercised only by tests; no scene drives them yet.
- `Act1TraversalModel` is a gate matrix used by tests and report tools, not gameplay.
- The commission UI is a list-and-confirm overlay; there is no forging minigame by design.
