# Spirit dialogue combat

Status: partial (SW-1, R-1348; reflection panel and first explorable Hingepuu hub are implemented). Scope: the current Hingepuu visit loop over the active city scene. Out of scope: a full spirit-world map, phantom encounters, authored open-world duels, rites, and comprehensive spirit combat; see the SW task chain.

Canon labels: Hingepuu, spirit world, creatures, and guilt rites are `folklore` / `invented` per [`docs/CANON.md`](../CANON.md). The hero's perception is never given a clinical diagnosis.

## Player behavior

Press **H** to enter or leave Hingepuu (when entered from the city player). Move with **WASD**, arrow keys, or the left stick. **E / gamepad A** interacts with the central tree mark; **Esc** returns. The symbolic tree has three visible marks. The central mark opens the existing reflection panel when available; other marks currently provide a placeholder response. Leaving restores the exact city player transform because the player and city scene remain resident underneath the overlay.

## Runtime and persistence

- `scripts/reflection/hingepuu_hub.gd` draws and controls the minimal explorable hub as a `CanvasLayer` overlay.
- `scripts/reflection/reflection_controller.gd` owns the hub and bridges the central mark to `ReflectionModel` / `ReflectionOverlay`.
- The hub stores the return position and active-visit bit in `GameState`'s existing `location_states` dictionary, which is already serialized by `GameStatePersistence` and `SaveService`. `restore_after_load` resumes the visit without replacing the saved return point.
- The hub blocks city movement through `modal_input_overlay` while active. Inputs use existing `ui_left/right/up/down`, `interact`, and `ui_cancel` mappings. `interact` already includes keyboard and gamepad A.

## Verification and limits

Run `godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_hingepuu_hub,test_reflection_overlay,test_save_service`.
The current host is a lightweight symbolic illustration rather than a dedicated streamed location or detailed art environment. Enter/exit is exposed by `ReflectionController.enter_hingepuu()` and `leave_hingepuu()`; an in-world access prompt/anchor, world-tree art, dedicated hub save-slot location, and integrated return-after-process-restart scene restoration remain follow-up work. No visual capture is accepted as historical reference.

## New Game duel in the smithy (R-1872)

Status: implemented (task **R-1872**). Scope: the opening porter duel as a combat mode inside normal play. Out of scope: other authored open-world duels (SW-3 **R-1350**), new word elements, a duel-specific camera.

**Story.** The boy has run from the almshouse to Kalev's smithy with the loaf and the cold-store key; the porter Hanß bursts in after him. The duel is fought by the hearth; Kalev then walks in from the living room and takes the boy as his apprentice. The porter leaves, Kalev stays in his forge, and play simply continues where the boy stands. Decision 2026-10-12 (maintainer request; the narrative option was the recommended one when the question timed out).

**Player behavior.**

- Main menu **Start** loads the seamless city at spawn `kalev_smithy`; no separate opening scene is loaded. The duel opens a few frames after arrival.
- The hero is the normal city `Player`: same third-person camera (orbit, zoom), walking, running, roll (`player_dodge`) and guard (`player_guard`). The duel only clamps him to a 3.2 m disc in the forge bay and greys the world with the duel grade (spirit sight).
- Health reads as in normal play: the hero's **composure** is the top bar of the bottom-left vitals block (`COMPOSURE 70 / 100`), and the porter's **pressure** is the standard overhead bar (`CharacterHealthRing3D`) above his head. The old 2D "Your composure" / "Their pressure" strips are gone in the real-time arena (they remain only for the 2D overlay duel).
- Hold **Esc** to skip the whole opening; while the opening runs Esc does not open the pause menu.

![The porter duel in Kalev's smithy: the boy (back to the camera), the porter with his overhead bar, a Faith word striking his faith light, composure in the vitals frame, the five word sigils](../reports/images/spirit_duel_layer/smithy_duel_words.jpg)

### Word spells: what happens in a spirit duel

A spirit duel is an argument fought with emotions. Each of the five slot keys (**1..5**, or the gamepad spell slots) speaks a **word** of one element. Each slot has a painted sigil (`assets/UI/spirit_words/word_<element>.png`) framed in its colour, with the word's name and key under it.

| Key | Word | Sigil | Strikes the opponent's soul light | What the word does in the argument |
|---|---|---|---|---|
| 1 | Fear | crimson eye in a flame | `aspect.nature` | names what the opponent is afraid of |
| 2 | Shame | blue bowed, hooded head | `aspect.resonance` | holds up what the opponent did |
| 3 | Duty | golden key over a scale | `aspect.tenacity` | reminds of an obligation |
| 4 | Love | green hands round a sprout | `aspect.unity` | appeals to care for someone |
| 5 | Faith | violet candle over a cross | `aspect.light` | appeals to God and conscience |

Rules (`SpiritWordSpells`, `SpiritDuel`):

1. **Cast at any time.** A word speaks the duel topic's line for its element (`duel.topic.lines`) and flies as a bolt in its colour at the opponent's soul light of that element. It costs 1 willpower and the slot cools down for 1.5 s (dark sweep on the icon).
2. **Answering.** When the opponent waits for a reply and one reply has the word's element, the slot gets a **gold rim**: the word *is* that reply and the dialogue follows it. Otherwise the word is a free strike for 6 pressure before modifiers.
3. **Topic.** Replies on the duel topic (the porter's `rusted_key`: key, bread, orphans, hunger) land x1.5; off-topic x0.6.
4. **Weak points.** A closed light (level 0) takes x1.5, an ember (level 1) x1.25; such slots carry a `weak` tag, and the hit label at the light says so (`Faith light -8`, `weak point x1.5`). The hero's own light of the same element scales his word too.
5. **Defence.** The opponent's lines are blows: a red zone on the floor marks where it lands. Roll out of it or face the opponent and hold guard.
6. **End.** Pressure 0 wins (banner, then the arena closes itself); composure 0 loses. The resolution node sets the prologue flags (spared, broken, punished, struck), and striking the porter physically is recorded as guilt.

**Runtime.** `scripts/prologue/smithy_opening.gd` (`SmithyOpening`: `start_new_game`, `consume`, `begin_duel`, `skip`); `scenes/intro/start_label.gd`; `scenes/world/reval_city/reval_city.gd` (calls `SmithyOpening.consume`); `scripts/combat/spirit_arena_host.gd` (`hero_composure`, `opponent_ring`, compact layout); `scripts/ui/player_vitals_hud.gd` (`COMPOSURE` mode); `scripts/combat/spirit_cast_bar.gd` (`ICONS`). Dialogues: `dialogue.prologue.porter_confrontation`, `dialogue.prologue.kalev_arrives` (lines reworded for the smithy). Writes `flag.prologue.apprenticed` and the duel's resolution flags; nothing else is saved (sight stays transient).

**Verify.** `godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_smithy_opening,test_almshouse_opening,test_spirit_arena_hud,test_spirit_word_spells`. Plates: `tools/godot_render.sh --resolution 1600x900 --script tools/capture_smithy_opening.gd -- --out=res://build/smithy_opening`.

**Limits.** The duel grade desaturates the porter's overhead bar along with the world, so its green reads grey-green. The porter wears a crowd body (no bespoke model). Kalev stands still in the forge after the dialogue (no schedule or talk yet). The staged almshouse hall (`scenes/prologue/almshouse_opening.tscn`, `AlmshouseStage`) is no longer reachable from New Game; it remains as the duel's test and capture fixture until a follow-up retires it.
