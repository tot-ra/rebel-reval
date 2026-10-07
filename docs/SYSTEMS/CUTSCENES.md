# Cutscenes

**Status:** implemented (tasks **R-1316**, **R-1317**, **R-1318**; [ADR 0034](../adr/0034-cutscene-mode-and-cinematic-prologue.md))

Authored cinematic sequences played as a dedicated mode: a letterboxed frame with a slow
camera move, a place-and-date caption, a speaker plate, and a chain to whatever runs next.
The shipped tier is **stills**; every shot already carries the slot and the prompt for the
later **AI-video tier** with voice-over and lip-sync.

**In scope:** the sequence record format, the player, skip and chaining behaviour, and the
three prologue sequences. **Out of scope here:** in-engine scripted-camera cinematics
(removed by ADR 0034), audio (fields reserved, nothing wired), localization of shot text,
and menu replay of a seen cutscene.

## What the player sees and does

New Game opens on **I. The Forging of Chains**: six shots from the Danish landing at
Lyndanisse in 1219 to Reval in spring 1343, narrated. It chains into the almshouse scene,
whose text title card is now **II. The almshouse of the Holy Spirit** (three shots, ending
on the matron and the porter starting their quarrel), and after Kalev takes the apprentice
**III. The forge** (three shots) walks the boy to the forge door.

| Input | Effect |
|---|---|
| `interact`, `ui_accept`, left click | advance one line; at the last line of a shot, advance one shot |
| `ui_cancel` tapped | skip the rest of the current shot |
| `ui_cancel` held 0.6 s | skip the whole sequence and jump to its chain target |
| nothing | lines auto-advance after their authored `seconds` |

Keyboard, mouse and gamepad all work, because the player only reads the existing input
actions and never binds a key directly. Skipping is not a loss of information: ADR 0034
requires the facts a player needs to be in the shot **captions**, which are the first thing
written for each shot.

## Runtime entry points

| File | Role |
|---|---|
| `scripts/cutscene/cutscene_sequence.gd` (`CutsceneSequence`) | typed parse of a `cutscene` record into shots and lines; refuses a malformed record by returning `null` |
| `scripts/cutscene/cutscene_player.gd` (`CutscenePlayer`) | `CanvasLayer` that presents the sequence, handles input and timing, and follows the `next` chain |
| `scripts/cutscene/cutscene_scene_host.gd` (`CutsceneSceneHost`) | makes a sequence a `change_scene_to_file` target via an exported `sequence_id` |
| `scenes/cutscene/prologue_opening.tscn` | the New Game entry point, playing `cutscene.prologue.conquest` |
| `scenes/intro/start_label.gd` | main-menu **Start** points at the scene above |
| `scripts/prologue/almshouse_opening.gd` | plays the almshouse and forge sequences around the spirit duels |

`CutscenePlayer` runs with `PROCESS_MODE_ALWAYS` and does not pause the tree, so it works
whether or not a world is running. `auto_continue = false` stops it before any scene change;
tests use that.

## Data and stable IDs

Records live in `content/cutscenes/`, are typed `cutscene` with the `cutscene.` ID prefix,
and are loaded by `ContentDB` through `SessionState.DEMO_CONTENT_DIRS`. Schema:
[`schemas/cutscene.schema.json`](../../schemas/cutscene.schema.json).

| ID | Shots | Chain target |
|---|---|---|
| `cutscene.prologue.conquest` | 6 | `scene_file` → `res://scenes/prologue/almshouse_opening.tscn` |
| `cutscene.prologue.almshouse_dawn` | 3 | `return` (the host scene continues) |
| `cutscene.prologue.taken_in` | 3 | `door` → scene `forge`, spawn `smithy_start` |

Per shot: a stable `id`, a `still` under `res://assets/cutscenes/`, a reserved `video`,
`transition_in` (`cut`/`fade`/`dissolve`), a `motion` block (`push_in`, `pull_out`,
`pan_left`, `pan_right`, `tilt_up`, `tilt_down`, `hold` with `zoom_from`/`zoom_to`), a
`caption`, `lines` with optional `speaker`/`speaker_id`/`seconds`/`delivery`, reserved
`sound`, and a required **`authoring`** block holding `direction`, `image_prompt` and
`video_prompt`. The runtime ignores `authoring`; it exists so the prompt that produced a
frame is inseparable from the frame, and so the video tier is written while the scene is
being authored rather than reconstructed later. Grammar for those prompts:
[`cinematics/PROMPT_GRAMMAR.md`](../../cinematics/PROMPT_GRAMMAR.md).

Shot and line IDs are stable API: renaming one breaks the generated-art mapping and the
future voice-line mapping. Do not renumber shots when inserting one; append a new ID.

## Where the frames live

`assets/cutscenes/<sequence>/<shot_id>.jpg`, one folder per sequence, with the Godot
`*.import` sidecar committed beside each file. Every frame has a provenance row in
`assets/SOURCES.csv` carrying the generator, the model and the full prompt. 1536x1024,
JPEG; at roughly 0.5 MB each the set stays well under the 10 MiB Git LFS threshold in
[`ASSET_STORAGE_POLICY.md`](../ASSET_STORAGE_POLICY.md).

## Saved state

None. Cutscenes write no flags and read no state; the almshouse scene around them owns
`flag.prologue.apprenticed` exactly as before. A cutscene is therefore safe to replay and
safe to skip.

## Verification

```bash
python3 tools/validate_content.py content/cutscenes      # schema and ID rules
python3 tools/verify_cutscenes.py                        # frames, sidecars, provenance, chains
godot --headless --path . --script tools/run_godot_tests.gd   # tests/godot/test_cutscene_player.gd
```

`tools/verify_cutscenes.py` fails when a still is missing, has no `*.import` sidecar, has no
`assets/SOURCES.csv` row, when a shot or line ID repeats, when an authoring field is empty,
or when a `next` target names a cutscene, a transition-manifest scene and spawn, or a scene
file that does not exist.

## Adding a cutscene

1. Write the record in `content/cutscenes/`, captions first, then lines, then the authoring
   block for every shot (follow `cinematics/PROMPT_GRAMMAR.md`).
2. Generate the stills into `assets/cutscenes/<sequence>/`, import them headless
   (`godot --headless --path . --import`), and add `assets/SOURCES.csv` rows.
3. Point something at it: a `CutsceneSceneHost` scene, or `CutscenePlayer.play_id()` from an
   existing scene.
4. Run the three commands above and extend this page.

## Limits

- **Silent.** `sound.music` and `sound.ambience` are in the schema and unused. The prologue
  plays without audio.
- **Not localized.** Captions and lines are authored English strings in the record. The
  dialogue-localization route does not cover them yet.
- **No menu replay.** ADR 0034 calls for replaying a seen prologue from the main menu; not
  built.
- **Chapters II and III art is provisional.** The OpenAI image credit ran out during
  **R-1318**, so those six frames are Leonardo.ai fallbacks and are marked `provisional` in
  `assets/SOURCES.csv`. They are visibly softer than the six `gpt-image-1` frames of chapter
  I and contain minor anachronisms (an overhead wire in `prologue_taken_in/s02_street.jpg`,
  modern-looking footwear in `s01_door.jpg`, window glazing bars in the almshouse frames).
  Regeneration is tracked as a follow-up; the prompts to re-run are already in the records.
- **No video tier.** `video` is parsed and preferred over `still` when set, but no shot sets
  it and no video decoding path has been exercised.
