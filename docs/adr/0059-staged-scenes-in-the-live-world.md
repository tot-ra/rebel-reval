# ADR 0059: Staged scenes in the live world; stills and AI video only for memory and vision

- **Status:** Proposed (2026-10-17). Needs maintainer approval before any dev task starts. Pilot beat sheet: **R-2157** (no code).
- **Amends:** [ADR 0034](0034-cutscene-mode-and-cinematic-prologue.md):
  - §2 (presentation tiers): the `realtime` tier stops being "if ever justified" and becomes the primary path for every story scene set in 1343 "now"; the `still` / `video` tiers are kept only for memory and vision chapters.
  - The first offset bullet of its scope accounting ("in-engine scripted-camera cinematics" removed): reinstated in a **data-driven** form only. Per-scene camera rigs, per-scene scripts, hand-keyed animation and cinematic-only LODs stay removed.
  - The maintainer rule recorded in [`SYSTEMS/CUTSCENES.md`](../SYSTEMS/CUTSCENES.md#narration-voice-r-1331) that 1343 scenes play "without a voice-over": narration stays banned in "now" scenes; **character voices** are allowed (see §3.6).
- **Extends:** [ADR 0047](0047-interaction-stances-and-conversation-camera.md): `ConversationShot` becomes one shot type of the scene director instead of the only story camera.
- **Depends on:** the content-maturity policy ADR (separate task, not yet numbered) for what violence and sexuality may be shown (§4).
- **Does not supersede:** ADR 0003 (offline authored content; no runtime generation of lines, voice, or motion), ADR 0019/0027/0028 (seamless world), ADR 0022 (MPFB realistic humans), ADR 0035 (audio sourcing; its voice decision is used here), ADR 0044 (named NPC tier), ADR 0058 (the hero is 18), the MVP-first delivery order.

## Context

The maintainer wants story scenes, starting with the New Game opening, to play like GTA, Kingdom Come: Deliverance II and The Witcher 3 cinematics: a film rather than scripted dialogue, with action, emotion, everyday danger and violence, adult sexuality, grounded in 1343 Reval.

What exists today and why it cannot get there:

1. **ADR 0034 bet on stills, then AI video.** Its offset removed in-engine cinematics (posed actors, per-scene camera rigs, animation authoring, lip-sync rig). AI video cannot show our MPFB characters, in their current wardrobe, in the live seamless city at the current time of day and weather. Every cut from a generated clip back into play is a visible change of medium. The tier fits memory and vision sequences (the 1219-1342 conquest remake in [`cinematics/OPENING_VISION_VIDEO_BRIEF.md`](../../cinematics/OPENING_VISION_VIDEO_BRIEF.md)), not the present day.
2. **`ConversationShot` (`scripts/prologue/conversation_shot.gd`, ADR 0047) frames talk only:** an opening two-shot, over-the-shoulder close shots and a crane back to the gameplay camera, with line of sight from `ShotOcclusion` (`scripts/prologue/shot_occlusion.gd`). Actors stand idle; nothing moves on cue.
3. **The opening is sequenced in code.** `scripts/prologue/smithy_opening.gd` chains `_begin_carried_in`, `_begin_lambert_duel`, `_begin_kalev` and places speakers at the cut; Kalev appears at the foot of the sickbed instead of walking in ([`CUTSCENES.md` Limits](../SYSTEMS/CUTSCENES.md#limits)). Every further scene written this way is another bespoke script, which ADR 0034 §1 forbids for cutscenes.
4. **The performance layer is thin.** `build_human.py` exports six facial blend shapes from MakeHuman's CC0 expression units (`blink`, `jaw_open`, `smile`, `brow_up`, `frown`, `pucker`). `assets/characters/realistic/realistic_rig.gd` blinks on a timer, holds an expression by weight, and "talks" with a syllable oscillator on `jaw_open` timed by text length. There are no visemes and no lip-sync. **R-1147** (look-at, blink, talk gestures) is still open and its contract predates these blend shapes. The shared rig carries a 76-clip CC0 library; the clips the runtime names are locomotion, combat, `Sit_Chair_*` (ADR 0054), `PickUp`, `Interact`, `Hit_A`, `Death_A/B`. No carry, grab, shove, kneel, lie-down or two-person (paired) clip is wired.
5. **Voice is already decided.** ADR 0035 Open question 3: AI voices through ElevenLabs, no cloning of real people, disclosed in credits. `tools/generate_cutscene_voice.py` produces narration takes (one voice) for cutscene records. Bundled dialogue voice is a separate open task (**R-630**).

## Decision

### 1. Two presentation paths

| Path | Used for | Medium | Record |
|---|---|---|---|
| **Staged scene** | Every story scene set in 1343 "now" with in-game characters: the New Game opening, quest beats, faction turns, act transitions | In-engine, in the live seamless world, current wardrobe / time / weather, no loading | new `scene` record (§2) |
| **Memory / vision** | The past (1219-1342), dreams, clairvoyant visions, spirit-world memories, anything the live world cannot be | Still tier now, AI-video tier later, colour grade per ADR 0034 §3 | existing `cutscene` record, unchanged |

Rule of thumb for authors: if the scene happens in Reval in 1343 and the player could have walked there, it is staged. A staged scene may *cut to* a memory / vision cutscene and back (the `next` chain both records already have).

### 2. A staged scene is a data-driven beat record

New content type `scene` (prefix `scene.`, records in `content/scenes/`, schema `schemas/scene.schema.json`). It is a separate type rather than an extension of `cutscene`, because a cutscene shot *is* an image while a staged beat *changes the world* (actors move, props change hands, flags may be set). The two schemas share definitions (`$defs`) for caption, line, voice, sound and `next`, so authoring and validators stay common.

A record has: `id`, a location anchor (existing map / anchor IDs), a **cast** (role -> character ID, spawn anchor, optional wardrobe override), preconditions (flags), an ordered list of **beats**, and the end state applied on completion or skip.

Each beat may declare, all optional:

- **Blocking per actor:** `walk_to` / `run_to` a named mark via the existing locomotion, `carry` (prop or actor), `grab`, `shove`, `strike`, `sit`, `kneel`, `lie`, `stand`, `turn_to`; `wait_for` arrival.
- **Performance per actor:** acting / gesture clip from the library, props in hand by slot (item IDs), `look_at` target (actor, mark, camera), facial expression weights, line delivery tag.
- **Camera:** shot type `establishing`, `two_shot` / `over_shoulder` (delegates to `ConversationShot`), `tracking` (follow a role), `handheld` (noise amplitude), `dolly` (mark to mark), `crane`, `insert` (close-up on a prop or mark), `rack_focus` (from target to target), `pov`; lens in mm; transition `cut`, `cut_on_action` (on an actor event such as contact or arrival) or `blend` seconds. Every shot is line-of-sight tested by `ShotOcclusion` and falls back the way `ConversationShot` already does.
- **Audio:** voiced line (speaker, text, take path), foley and ambience by `SfxPlayer` catalog ID (ADR 0035), music stinger, and a J-cut / L-cut offset so sound can lead or trail the picture cut.
- **Timing:** advance on `line_end`, `arrived`, `seconds`, `event`, or input.
- **Interactive hand-off:** `dialogue` (dialogue ID), `spirit_duel` (duel ID), `brawl` (setup for `citizen_brawler`), or `play` (free control until a trigger), each with outcome -> next beat. Control passes to the player and back in place, without a load or a scene change, Witcher 3 style: the director releases the camera with `ConversationShot.release(blend_sec)` and re-frames when the interactive part closes.

Illustrative shape only; the schema is the first task's deliverable:

```json
{ "id": "b04_kalev_enters",
  "actors": [ { "role": "kalev", "walk_to": "mark.sickbed_foot", "look_at": "lambert", "props": { "hand.r": "item.spearhead" } },
              { "role": "matron", "turn_to": "kalev", "expression": { "brow_up": 0.6 } } ],
  "camera": { "shot": "tracking", "follow": "kalev", "lens_mm": 35, "then": { "shot": "insert", "target": "item.spearhead", "rack_focus": "kalev" } },
  "audio": { "foley": "sfx.door.wood.open", "ambience_duck_db": -8, "l_cut_sec": 0.6 },
  "advance": "arrived" }
```

**One runtime director, no per-scene scripts.** A single `SceneDirector` (scene-mounted by whatever triggers the scene, not an autoload) plays every record. It reuses `ConversationShot` and `ShotOcclusion` for framing and line of sight, `DialogueRunner`, `SpiritArenaHost`, `citizen_brawler`, `SfxPlayer` and `music_director`. `smithy_opening.gd`'s hand-written sequence becomes the first record; its flags, duel IDs and outcome IDs are preserved. Behaviour that would need a new script per scene is a schema gap to raise, not a script to write.

**Skip, save, determinism.** Tap Esc skips a beat; hold Esc skips the scene and applies its authored end state (positions, flags, items), so a skip loses no state and the journal carries the facts (ADR 0034 §5). Interactive beats cannot be skipped past, only their non-interactive lead-in. No save inside a scene; save points sit at scene boundaries. Marks are authored, so blocking is deterministic; if a path is blocked, the actor is placed at the mark off-camera and the event is logged as a defect.

### 3. Performance layer requirements

These are prerequisites of the pilot, each a separate task after approval:

1. **Look-at, blink, talk gestures: R-1147**, re-scoped to the blend shapes that now exist (head and eye look-at, saccades, blink on cut, talk-gesture coupling of arms and head).
2. **Facial expression and visemes on MPFB heads.** Extend `EXPRESSIONS` in `tools/assets/realistic_humans/build_human.py` from six shapes to a viseme set (about 12-15 mouth shapes, built from MakeHuman CC0 expression units; the exact unit list is verified in the task) plus emotion shapes needed by acting (anger, fear, pain, disgust, grief). Blend-shape count is budgeted against the instance-uniform limits seen in R-1994 / R-2022.
3. **Lip-sync baked offline.** A viseme track is generated from each voice take at build time (an open-source phoneme aligner, licence checked in the task) and stored next to the take; `realistic_rig.gd` plays the track and keeps the text-length oscillator as the fallback when no take exists. Nothing is generated at runtime (ADR 0003, ADR 0035).
4. **Acting clips.** A clip list is a deliverable of R-2157. Expected minimum: carry (object, body, stretcher pair), grab-collar / pin-to-wall (paired), shove and stagger, fall and get up, kneel and stand, lie and writhe, hands on a wound, point, beckon, cross arms, pray, drink, struggle, embrace (paired, subject to §4). Sources: CC0 or redistribution-compatible mocap retargeted to the shared rig, each with an `assets/SOURCES.csv` row; procedural IK (reach, grip, contact) for props and paired contact rather than hand-keyed clips. Later output of ADR 0056 (neural motor control) may replace some clips; it is not a dependency.
5. **Close-up quality: R-1568** (named-NPC close-up kit, face light rig) is a prerequisite for `insert` and close shots.
6. **Voice acting for character lines.** Characters speak their lines with AI voices per ADR 0035 Open question 3. `tools/generate_cutscene_voice.py` (or a sibling tool) is extended to `scene` records and to dialogue lines with a per-character casting table (voice, register, delivery tags), aligned with **R-630**. Narration over 1343 "now" scenes stays banned: the maintainer's no-voice-over decision was about a narrator, and character voices are a different thing. Spoken language (English with period flavour, or Estonian / Low German with subtitles) is an open question for the maintainer.

### 4. Content maturity

This ADR provides the *grammar* for violent and intimate beats (blocking, paired clips, camera, cut-away). What may be shown, how explicitly, the rating target, the always-on exclusions (no sexual content involving minors, in line with the spirit-sight rule that minors are never shown nude), and any player content toggles belong to the content-maturity ADR (separate task). Until that ADR is accepted, no sexual or graphic-violence beat may be authored; scenes keep to what the current canon and dialogue rules already allow. The protagonist is 18 (ADR 0058); scenes about other characters still follow the policy.

## Equivalent scope accounting (per the scope-change rule)

**Removed as the offset:**

- **The AI-video tier for 1343 "now" scenes.** No video remakes of `cutscene.prologue.almshouse_dawn` or `cutscene.prologue.taken_in`; both records and their six stills are retired once the staged opening ships, and **R-1330** (regenerate those six provisional stills) is cancelled. The video tier remains only for memory / vision (`OPENING_VISION_VIDEO_BRIEF.md`).
- **New still-tier cutscenes for present-day story.** Acts 1-3 get no new present-day still sequences; their scenes are staged.
- **Menu replay of the prologue** (ADR 0034 §5, never built) is dropped: a staged scene plays in the live world from a save state and is not a menu asset.
- **Voice scope is bounded.** Voiced lines are limited to named characters in staged scenes and authored dialogue; generic citizens, barks and crowd chatter stay unvoiced text or vocal efforts (ADR 0035 Phase 3). No hired actors and no motion-capture sessions.
- **Animation authoring stays out.** No hand-keyed per-scene animation, no Godot `AnimationPlayer` timelines per scene, no cinematic-only character LODs or rigs; only library clips, procedural IK, and the director.
- **The bespoke opening sequencer.** `smithy_opening.gd`'s per-beat code is deleted when its record lands, and no later scene gets a script of its own.

## Alternatives considered

- **Keep stills and AI video for everything (ADR 0034 as is).** Rejected for present-day scenes: it cannot show our characters in the live city, and the cut back into play breaks the film.
- **Extend the `cutscene` schema with beats.** Considered. Rejected as one type because an image shot and a world-changing beat have different validation and runtime; sharing `$defs` keeps the common parts identical.
- **Per-scene `AnimationPlayer` / timeline scenes.** Rejected: per-scene authoring, breaks whenever the seamless world, wardrobe or citizens change, and is exactly what ADR 0034 cut.
- **Pre-rendered in-engine video.** Rejected: frozen time of day, weather and wardrobe; the seamless hand-back to play is lost.
- **A third-party cutscene or dialogue-timeline plugin.** Rejected: a new framework (forbidden without need); the existing camera, occlusion, dialogue and duel code already covers most of the runtime.
- **Only extend `ConversationShot` with more angles.** Rejected: it frames talk; it has no blocking, props, action or audio cues.

## Consequences

- After approval, an epic with tasks in this order: schema and validator (`tools/verify_scenes.py`: marks resolve to anchors, cast IDs exist, clips exist in the library, takes and viseme tracks exist, interactive targets exist, `next` resolves); `SceneDirector` blocking and camera; interactive hand-off; R-1147; visemes and lip-sync bake; acting clips import; character voice casting; then the pilot, the almshouse opening restaged from R-2157's beat sheet. Each task names allowed files and verification per the feature-docs skill.
- New feature page `docs/SYSTEMS/STAGED_SCENES.md` (`Status: planned`) is created by the first dev task; until then [`SYSTEMS/CUTSCENES.md`](../SYSTEMS/CUTSCENES.md) carries a note pointing here.
- Visual verification: every staged scene ships captures through `tools/godot_render.sh` (headless rule), one per camera shot type it uses.
- `cinematics/PROMPT_GRAMMAR.md` stays binding for memory / vision cutscenes only; the shot vocabulary of §2 becomes the grammar for staged scenes.
- Risks: acting quality is bounded by available CC0 / compatible mocap and six-to-twenty facial shapes; paired contact (grab, carry, embrace) needs IK work that may slip; AI voices across a large cast need a casting table to stay consistent.
- Open questions for the maintainer: spoken language of voiced lines; letterbox bars in staged scenes or not; whether the player may skip a scene on first viewing; the rating target (content-maturity ADR).
