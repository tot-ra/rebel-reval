# ADR 0034: Cutscene mode and the cinematic prologue

- **Status:** Accepted (maintainer-directed, 2026-10-08). Implemented for the prologue by **R-1316**..**R-1318**; later chapters are gated by their own tasks.
- **Amends:** [ADR 0033](0033-teen-protagonist-and-spirit-dialogue-combat.md) §7 (Prologue) by giving the prologue a presentation layer. Retires the legacy intro-video path in `scenes/intro/` and the Kalev-as-protagonist treatments in [`cinematics/`](../../cinematics/README.md).
- **Does not supersede:** ADR 0003 (offline authored content, no runtime LLM), ADR 0007 (painted art direction for the playable world), ADR 0019/0027/0028 (seamless world), ADR 0022 (realistic humans), the MVP-first delivery order.

## Context

New Game currently drops the player onto a near-black `ColorRect` with six `Label` nodes
(`scripts/prologue/almshouse_opening.gd`), then straight into a spirit duel. The player is given no
year, no place, no reason to care about the boy or about Reval. The game's premise - a conquered
people, a 124-year-old debt, extraordinary taxes, and a clairvoyant orphan - is entirely absent from
the first two minutes.

Three constraints shape the fix:

1. **ADR 0003 forbids runtime generation.** Whatever a cutscene is, it is authored offline and
   deterministic.
2. **The target presentation is AI-generated video** with voice-over and lip-sync, which does not
   exist yet and will not for some time. Stills are the first tier, not the design.
3. **The playable world is stylized** (ADR 0007, `style-lock-v1.1`). Cutscene art is a separate
   surface and does not have to match the in-game renderer pixel for pixel - but it must not look
   like a different game.

Legacy material exists but cannot be used as-is: `cinematics/1-intro.md` and
`story/prequel_image_prompts.md` script a 1219 grove massacre around Lembitu and Aita with Kalev as
the eventual protagonist, which ADR 0033 replaced. The images in `story/` and `history/` are
low-fidelity, undated, and have no provenance rows.

## Decision

### 1. Cutscenes are a mode, not a scene

A cutscene is a **`cutscene` content record** ([`schemas/cutscene.schema.json`](../../schemas/cutscene.schema.json))
played by one runtime player (`scripts/cutscene/cutscene_player.gd`). The record owns the shot list,
the dialogue, the direction, and the chain to whatever comes next. No cutscene gets its own
bespoke scene, script, or camera rig.

Player affordances are fixed and match the blockbuster convention the maintainer named (The Witcher 3,
Kingdom Come: Deliverance II, Red Dead Redemption 2): letterbox bars, a slow camera move over every
shot, a caption line for place and date, a speaker plate for dialogue, advance-on-input, tap-Esc to
skip a shot, hold-Esc to skip the sequence.

### 2. Presentation tiers: the authored record outlives the tier

Every shot carries both a `still` and a `video` path plus a `motion` block. The player uses the
`video` when present and falls back to the `still`. A tier upgrade therefore adds files and changes
nothing in the script, the timing, or the code path. Each shot also carries an **authoring block**
with `image_prompt`, `video_prompt`, and `direction` so the prompt that produced a frame lives next
to the frame it produced, and the video prompt is written *now*, while the scene is being authored,
rather than reconstructed later from a finished still.

Three tiers, in order: `still` (shipped), `video` (AI-generated shot with ambient motion and a voice
track, lip-synced where a face speaks), `realtime` (in-engine, if ever justified).

### 3. Style lock: cinematic realism with a per-chapter grade

Cutscene stills and future video use **photographic cinematic realism** - real lens behaviour, film
grain, practical light sources, period-correct dirt and wear - not painted illustration. Reasons:

- it is the common denominator of the three named references;
- it survives the move to AI video intact, where a painterly look degrades into smear;
- it reads as "the historical record" against the stylized playable world, which is a useful
  separation rather than an inconsistency.

Chapters are separated by **colour grade**, not by medium: the 1219-1342 historical chapter is cold,
desaturated, heavy-grained, firelit (`grade: "memory_cold"`); 1343 scenes are warmer, cleaner, with
forge amber and daylight (`grade: "present_warm"`). The palette masters in
[`ART_BIBLE.md`](../ART_BIBLE.md) still govern wardrobe, architecture, and faction colour.

### 4. The prologue is two chapters, twelve shots

| Record | Chapter | Shots | Where it plays |
|---|---|---|---|
| `cutscene.prologue.conquest` | The Forging of Chains, 1219-1343 | 6 | New Game, before the almshouse |
| `cutscene.prologue.almshouse_dawn` | The almshouse of the Holy Spirit, spring 1343 | 3 | Replaces the almshouse title card |
| `cutscene.prologue.taken_in` | Kalev takes the apprentice | 3 | After the Kalev dialogue, before the forge |

The historical chapter states the year, names the Danish conquest of 1219 and Valdemar IV's
extraordinary tax, and stops short of the uprising: the game opens in spring 1343, **before**
St George's Night (23 April), so the chapter ends on pressure, not on revolt. Historical claims carry
confidence labels in [`CANON.md`](../CANON.md); Lembitu and the grove massacre are **not** reinstated,
because ADR 0033 removed the ancestral-blood-debt framing that needed them.

### 5. Skipping and replay

Esc skips. A skip is not a loss of information: the skipped sequence's captions are written so that
the journal entry seeded by the prologue carries the same facts. The prologue is replayable from the
main menu once seen, so the first impression is not a one-shot asset.

## Equivalent scope accounting (per AGENTS.md scope-change rule)

**Removed as the offset:**

- **In-engine scripted-camera cinematics**: posed actors, per-scene camera rigs and animation
  authoring, cinematic-only character LODs, and an in-engine lip-sync rig. This was the implicit plan
  behind ADR 0033's prologue and is the single most expensive unbuilt presentation item. Replaced by
  the data-driven sequence player.
- **The legacy intro-video path**: `scenes/intro/intro.tscn` and the tracked `scenes/menu/intro.mp4`
  prequel video stop being a delivery route for story. The menu background loop (`intro.ogv`) stays
  as decoration.
- **Per-scene cinematic treatments as deliverables**: `cinematics/1-intro.md`, `cinematics/2-forge.md`,
  `story/prequel_image_prompts.md`, and `story/act1_image_prompts.md` become `reference` and are not
  maintained against canon. Their canon-valid content moves into cutscene records.

## Alternatives considered

- **Keep the text title card, add a single splash image.** Rejected: does not deliver an opening, and
  there would be no structure to upgrade to video.
- **A video file per cutscene, authored in a video editor.** Rejected: no per-shot timing, no
  subtitles, no skip granularity, no localization hook, and it blocks the still tier entirely.
- **Painted illustration (Witcher 3 journal look).** Rejected as the lock: it hides generation
  artifacts today at the cost of a style break when the video tier lands, which is the tier that
  matters.
- **An in-engine 3D cutscene in the existing city.** Rejected now: the 1219 grove, the Danish fleet,
  and the almshouse interior do not exist as maps, and building them for a two-minute opening
  inverts the delivery order.
- **A separate `cinematic` autoload.** Rejected: AGENTS.md forbids new frameworks without need, and a
  scene plus a record is sufficient.

## Consequences

- New feature page [`docs/SYSTEMS/CUTSCENES.md`](../SYSTEMS/CUTSCENES.md) (`Status: implemented`).
- New content type `cutscene` with prefix `cutscene.` in `ContentDB` and the Python validators;
  records live in `content/cutscenes/`.
- New prompt grammar [`cinematics/PROMPT_GRAMMAR.md`](../../cinematics/PROMPT_GRAMMAR.md) binding on
  every future cutscene, covering the still tier and the video tier (shot, lens, motion, light,
  wardrobe, dialogue delivery, voice casting, lip-sync).
- New gate `python3 tools/verify_cutscenes.py`: every shot's still exists, is imported, has an
  `assets/SOURCES.csv` row, and every record chains to a real target.
- Stills are AI-generated project art and need provenance rows; they are **not** covered by the
  P0-040 asset freeze, which governs legacy isometric/pixel/HUD art, but every new cutscene still
  needs a task naming its files.
- Localization: shot captions and dialogue lines are authored strings in the record, so the existing
  dialogue-localization route can be extended to them by a later task. Not done here.
- Audio: music and ambience fields are reserved in the schema and unused in this change; the
  prologue plays silent. Tracked as a limit on the feature page.
