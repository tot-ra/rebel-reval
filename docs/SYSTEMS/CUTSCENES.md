# Cutscenes

**Status:** implemented (tasks **R-1316**, **R-1317**, **R-1318**, **R-1331**; [ADR 0034](../adr/0034-cutscene-mode-and-cinematic-prologue.md))

Authored cinematic sequences played as a dedicated mode: a letterboxed frame with a slow
camera move, a place-and-date caption, a speaker plate, and a chain to whatever runs next.
The shipped tier is **stills**; every shot already carries the slot and the prompt for the
later **AI-video tier** with voice-over and lip-sync.

**In scope:** the sequence record format, the player, skip and chaining behaviour, and the
three prologue sequences. **Out of scope here:** in-engine scripted-camera cinematics
(removed by ADR 0034), ambience (field reserved, nothing wired), localization of shot text,
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
`caption`, `lines` with optional `speaker`/`speaker_id`/`seconds`/`delivery`/`conditions`, reserved
`sound`, and a required **`authoring`** block holding `direction`, `image_prompt` and
`video_prompt`. The runtime ignores `authoring`; it exists so the prompt that produced a
frame is inseparable from the frame, and so the video tier is written while the scene is
being authored rather than reconstructed later. Grammar for those prompts:
[`cinematics/PROMPT_GRAMMAR.md`](../../cinematics/PROMPT_GRAMMAR.md).

**Conditional lines (R-1335):** a line may carry `conditions` (the dialogue condition ops
from `common.schema.json`, for example `flag_is`). `CutsceneSequence.from_record(record,
state)` keeps such a line only when every condition holds for `state`; without a state
(`CutscenePlayer.play_id`, `CutsceneSceneHost`) conditional lines are dropped, so a
context-free player never echoes a choice the player did not make. `AlmshouseOpening` parses
`cutscene.prologue.taken_in` with the session state, so its first shot adds one line for the
duel's ending (`l1_spared`, `l1_broke`, `l1_struck`, `l1_punished`). Those lines have no voice
take yet and play as timed narration.

Shot and line IDs are stable API: renaming one breaks the generated-art mapping and the
future voice-line mapping. Do not renumber shots when inserting one; append a new ID.

## Where the frames live

`assets/cutscenes/<sequence>/<shot_id>.jpg`, one folder per sequence, with the Godot
`*.import` sidecar committed beside each file. Every frame has a provenance row in
`assets/SOURCES.csv` carrying the generator, the model and the full prompt. 1536x1024,
JPEG; at roughly 0.5 MB each the set stays well under the 10 MiB Git LFS threshold in
[`ASSET_STORAGE_POLICY.md`](../ASSET_STORAGE_POLICY.md).

## Narration voice (R-1331)

Only the conquest prologue (`cutscene.prologue.conquest`, shots 1-5) is narrated: from the spring 1343 shot on the story is "now" and plays without a voice-over (maintainer decision), so chapters II and III and the spring shot carry text or captions only. A line may carry an optional `voice` (`res://assets/audio/cutscene_voice/<sequence>/<shot>_<line>.mp3`).
`CutscenePlayer` plays it on the `Voice` bus when the line starts, stops it when the line
is advanced or skipped, and holds auto-advance until the take ends plus a 0.9 s tail (1.8 s when the line closes a shot) and never advances while audio is still playing (the
authored `seconds` is the floor). A missing file degrades to the silent timed line.

The takes are generated by `python3 tools/generate_cutscene_voice.py` with **ElevenLabs Eleven
v4** (`elevenlabs/eleven-v4`) through OpenRouter (`/api/v1/audio/speech`). Eleven v4 is steered
by inline audio tags in the input text, so every take is sent as `CINEMATIC` (`[dramatic]`)
plus a per-line emotion tag (`[sorrowful]`, `[bitter]`, `[softly]`, `[hopeful]`) plus the line.
Keep tags to one short standard word: long descriptive tags made v4 speak the tag words and
stutter the first phrase. After regenerating, transcribe a few takes (`stt` tool) and compare
with the line text; seconds-per-word far above ~0.5 flags a suspect take. The tags go to
the model only; the on-screen text stays untouched in the cutscene JSON. One voice (`brian`);
the emotion runs from sorrowful with a vengeful edge for the conquest history, through
bitter controlled anger on two defiant lines, to hushed and then hopeful once the narration
reaches the boy. Per-line exceptions live in `LINE_OVERRIDES`. The key comes from `OPENROUTER_API_KEY` or the Brute OpenRouter provider config. Re-runs
skip existing files; `--force` regenerates all, `--only <id fragment>` limits to one
cutscene. To retune: edit the tag constants, delete the mp3s to replace, re-run, then
`godot --headless --path . --import`. The tool also writes the `voice` field and the
`assets/SOURCES.csv` rows (approval `draft` until a maintainer listens through).

## Music

A shot's `sound.music` (res:// mp3/ogg) starts an underscore on the `Music` bus, with a 2 s
fade-in, at `sound.music_volume_db` (default -16 dB, kept well under the narrator on the `Voice`
bus; tune it per shot). It keeps playing across the following shots (an empty `music` leaves
it alone; a different path replaces it) and fades out over 3 s when the sequence ends or is
skipped. The fade runs on the tree root so a scene change cannot cut it. The main-menu theme is
crossfaded out by `MusicDirector` as soon as the cutscene scene loads. Shipped: *The Weight of
Centuries* (`music/intro/`, prompt in `music/README.md`) starts with shot `s01_fleet` of
`cutscene.prologue.conquest` at -11 dB, while the narration is trimmed by -4 dB (`VOICE_DB` in `CutscenePlayer`). Player Music-bus volume from settings still applies on top.

## Saved state

Cutscenes write no flags. They read state only through conditional lines (above); the almshouse scene around them owns
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

- **Only the opening is scored.** `sound.ambience` is in the schema and unused; only the
  conquest prologue has music and narration. The voice is one narrator for every line, not yet
  auditioned by a maintainer, so the takes are `draft`.
- **Not localized.** Captions and lines are authored English strings in the record. The
  dialogue-localization route does not cover them yet.
- **No menu replay.** ADR 0034 calls for replaying a seen prologue from the main menu; not
  built.
- **Chapters II and III art is provisional.** The OpenAI image credit ran out during
  **R-1318**, so those six frames are Leonardo.ai fallbacks and are marked `provisional` in
  `assets/SOURCES.csv`. They are visibly softer than the six `gpt-image-1` frames of chapter
  I and contain minor anachronisms (an overhead wire in `prologue_taken_in/s02_street.jpg`,
  modern-looking footwear in `s01_door.jpg`, window glazing bars in the almshouse frames).
  Regeneration is tracked as **R-1330**; the prompts to re-run are already in the records.
- **No video tier.** `video` is parsed and preferred over `still` when set, but no shot sets
  it and no video decoding path has been exercised.
