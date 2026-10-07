# Dialogue, barks, and localization

Status: implemented (tasks **P1-011** runner, **P1-012** UI, **P1-013** settings, **P1-014** overflow and pseudo-localization). Scope: authored branching conversations, ambient barks, the dialogue panel, localization catalogs, and the offline voice handoff. Policy: all dialogue is authored offline, with no runtime LLM or free-text chat ([ADR 0003](../adr/0003-authored-offline-dialogue-and-prohibit-runtime-llm.md)).

## Player-facing behavior

- **Conversations** open a bottom panel with speaker name, optional portrait, and typewriter text. Continue with interact / `ui_accept` / click. `ui_cancel` first completes the line, then skips. Choices are listed with keyboard/gamepad focus (`ui_up` / `ui_down`). Disabled choices stay visible and show their authored reason.
- **Backlog**: `ui_page_up` opens the scrollback of earlier lines; `ui_cancel` closes it.
- **Barks** are non-blocking speech bubbles over the speaker's 3D head. They expire after about 3.2 s and never capture input, so movement and camera stay live.
- Speakers in the `dialogue_speakers` group get `on_dialogue_speaker(speaker_id, text_length)` for talking animation.
- Settings (Settings → Dialogue): text scale `small / normal / large / extra_large` (0.85–1.5×), text speed `slow / normal / fast / instant` (18 / 36 / 72 chars/s / instant), high contrast, subtitle background, reduced motion, subtitles and bark subtitles on/off, voice on/off, locale, and pseudo-localization. See [`SETTINGS_AND_ACCESSIBILITY.md`](./SETTINGS_AND_ACCESSIBILITY.md).

## Runtime pieces

| Piece | File | Role |
|---|---|---|
| `DialogueRunner` | `scripts/dialogue/dialogue_runner.gd` | Plays a `dialogue.*` record: entry variants, node conditions, effects, `once` nodes (tracked in `GameState`), choices, and `next_node_id` chains. `start(id)`, `advance()`, `select_choice(id)`; signals `started` / `finished`. Barks: `resolve_bark(pool, phase, location)` / `play_bark(...)`. |
| `DialogueEntryResolver` | `scripts/dialogue/dialogue_entry_resolver.gd` | Picks the highest-priority `entry_variants[]` node whose conditions pass, else `start_node_id`. |
| `DialoguePresenter` / `DialogueUiPresenter` | `scripts/dialogue/` | Presenter contract between runner and UI (tests use `tests/godot/dialogue_test_presenter.gd`). |
| `DialogueUI` | `scripts/dialogue/dialogue_ui.gd` | The panel, with helpers `DialogueUiBuilder` (node tree), `DialogueUiChoices`, `DialogueUiInput`, `DialogueUiReveal` (typewriter), `DialogueUiTheme` (colors), `DialogueTextScale`, `DialogueTextLayout` (overflow geometry). |
| `DialogueBarkPresenter` | `scripts/dialogue/dialogue_bark_presenter.gd` | World-anchored bark bubble. |
| `DialoguePortraitResolver` | `scripts/dialogue/dialogue_portrait_resolver.gd` | Portraits for Mart, Kalev, Henning, and Aita from `assets/characters/portraits/`. Others show no portrait. |
| `DialogueTextFormatter` | `scripts/dialogue/dialogue_text_formatter.gd` | Expands runtime tokens (below). |
| `DialogueLocalization`, `DialoguePseudoLocalization` | `scripts/dialogue/` | Catalog lookup and the layout stress mode. |

Barks are also played by `MapPatrolBarkPresenter`, `SocialReputationController`, `MarketDayController`, `WorldItemPickupFeedback`, and the forge prologue.

## Content

- `type: dialogue` ([`schemas/dialogue.schema.json`](../../schemas/dialogue.schema.json)): `participants`, `start_node_id`, optional `entry_variants[]`, and `nodes[]` with `speaker_id`, `text` or `text_key`, `conditions`, `effects`, `once`, `next_node_id`, and `choices[]` (`target_node_id`, `conditions`, `effects`, `disabled_reason`). Conditions and effects: [`STATE_AND_SAVES.md`](./STATE_AND_SAVES.md#conditions-and-effects).
- Optional foreign-language markup on nodes (`language`, `gist`, `imagery`) and choices (`comprehension`), ADR 0033: see [`SPIRIT_DIALOGUE.md`](./SPIRIT_DIALOGUE.md#language-comprehension-implemented-sd-08).
- Optional spirit-duel markup (`duel`, per-node and per-choice `move`, ADR 0033): see [`SPIRIT_DIALOGUE.md`](./SPIRIT_DIALOGUE.md#dialogue-move-tags-implemented-sd-02).
- `type: bark` ([`schemas/bark.schema.json`](../../schemas/bark.schema.json)): `selection: first_valid_in_order`, optional `phase_ids` / `location_ids` scope, and `entries[]` with `priority` and `conditions`. Selection is deterministic: highest priority first, first passing entry wins.
- Records live in `content/examples/valid/`, `content/demo/`, and quest packages. Every record carries `deterministic_offline: true`.

### Text tokens

`{trade_price:<good_id>}` becomes the current district price for that good (for example `{trade_price:trade.iron}`); see [`FACTIONS_AND_ECONOMY.md`](./FACTIONS_AND_ECONOMY.md#trade-prices).

## Localization and voice

Catalogs live in `localization/<locale>.json` (`en`, `et`). Lookup order is requested locale → language base → default → inline `text`. Details and the offline ElevenLabs voice-manifest handoff are in [`localization/README.md`](../../localization/README.md). The voice manifest is `docs/data/dialogue_voice_manifest.json`.

## Verify

```bash
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_dialogue
python3 tools/dialogue_voice_manifest.py --content content/examples/valid --content content/demo --locale en --output docs/data/dialogue_voice_manifest.json --check
```

## Limits

- The demo Mart street conversation (`DemoMartEncounter`) and the forge Henning/cat conversations (`scenes/reval_east/forge/forge_dialogue_encounter.gd`) still use the linear `DemoDialogueRunner` + `DemoDialogueBox` from D-002, which the script header marks superseded by `DialogueRunner`. Migrating them is open work ([`docs/reports/code_health_audit_2026-10-07.md`](../reports/code_health_audit_2026-10-07.md)).
- Portraits exist for four speakers only.
