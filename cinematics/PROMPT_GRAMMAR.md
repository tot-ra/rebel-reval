# Cutscene prompt grammar

Binding for every cutscene shot ([ADR 0034](../docs/adr/0034-cutscene-mode-and-cinematic-prologue.md)).
Prompts live inside the shot's `authoring` block in `content/cutscenes/*.json`, not in this
file; this page says how to write them. Feature page: [`docs/SYSTEMS/CUTSCENES.md`](../docs/SYSTEMS/CUTSCENES.md).

Write all three fields **before** generating anything:

| Field | Answers |
|---|---|
| `direction` | what this shot has to accomplish in the story, and how the frame carries it |
| `image_prompt` | the still, now |
| `video_prompt` | the shot, later: subject motion, camera motion, duration, audio, lip-sync |

Writing `video_prompt` while the scene is being authored is the point. Reconstructing a
shot's intent from a finished still loses the staging, and the staging is the direction.

## Style lock

Photographic **cinematic realism**, not painted illustration. Real lens behaviour, practical
light sources, period dirt and wear, film grain. The playable world is stylized
([ADR 0007](../docs/adr/0007-visual-direction.md)); cutscenes read as the historical record
against it, and they survive the move to AI video, which a painterly look does not.

Chapters are separated by **colour grade**, never by medium:

| `grade` | Use | Words to carry it |
|---|---|---|
| `memory_cold` | history, 1219-1342 | cold desaturated grade, steel-blue shadows, pale ochre highlights, heavy 35mm film grain, overcast or firelit |
| `present_warm` | 1343 and later | warm filmic grade, amber practical light, cool fill, fine film grain |

Wardrobe, architecture and faction colour still obey the palette masters in
[`docs/ART_BIBLE.md`](../docs/ART_BIBLE.md). Spirit-world apparitions use moon cyan
(`#58C7E8`) against forge amber (`#F0A13E`) and nothing else.

## Image prompt order

Keep this order. Generators weight the opening clause heaviest, so the shot type and the
lens go first and the grade goes last.

```
Cinematic film still, <lens / shot size>, <camera position and framing>:
<subject and action> ,
<setting and period detail> ,
<secondary figures and where they sit in the frame> ,
<weather and time of day> ,
<light design> , <grade words> , <grain and atmosphere> ,
Historically accurate <place> <year>. <hard exclusions>.
```

Rules that earned themselves during **R-1318**:

- **Name the frame position of every person.** "Centre", "lower left", "deep in a doorway".
  Without it the generator produces a posed group portrait facing the lens.
- **Say "nobody looks at the camera"** for any shot with more than two people, and put
  `looking at camera, eye contact, posed group portrait` in the negative prompt. This was the
  single most common failure.
- **Exclude the wrong century explicitly.** `glass lantern, street lamp, louvred shutters,
  paving slabs, trench coat, lace-up boots, plastic, drain grate, power line`. A generic
  "historically accurate" does not stop these.
- **Exclude the wrong geography.** Baltic shots need `no cypress trees, no Mediterranean
  vegetation`; Baltic pine and juniper have to be asked for by name.
- **Get heraldry right by description, not by name.** "red surcoat with a white cross", not
  "Danish knight"; add `no black Teutonic crosses` when the two can be confused.
- **Violence is aftermath and silhouette.** Broken shafts, a fallen shield, churned mud, a
  regrouping line. Never bodies, blood or a blow landing - it reads as exploitation, it trips
  content filters, and it is less frightening than a bored official with a set of scales.
- **Repeat the character description verbatim** across every shot a character appears in.
  Nothing else holds a face together between generations.
- **Fewer people is more reliable.** A crowded street fails far more often than the same
  street with four figures in it. Cut the crowd before cutting the detail.

## Video prompt order

```
<duration in seconds>.
Camera: <move>, <lens>, <rig and quality of motion>.
Subject motion: <what each element does, in order, with the beat it lands on>.
Audio: <ambience>, <effects tied to specific moments>, <music entry and exit>.
<Lip-sync note>.
<Which narration or dialogue lines run over the shot, and where they land>.
```

- **Duration is 8-11 seconds.** Shorter cannot carry two narration lines; longer exposes
  the generator.
- **One camera move per shot**, matching the record's `motion.kind` so the still tier and
  the video tier stage identically.
- **State lip-sync explicitly, including when it is not needed.** Most prologue shots are
  voice-over over faces that do not speak: say "Voice-over only, no lip-sync" so nobody
  animates a mouth to narration. Where a character will be voiced later, say
  "LIP-SYNC REQUIRED LATER for X" and keep their speech unintelligible in the first tier.
- **Tie audio to frames, not to the shot.** "A hammer stroke on the first word of l2" is
  directable; "blacksmith sounds" is not.
- **Say what the last frame holds on.** The cut out of a shot is part of the shot.

## Voice casting

`delivery` on every line is voice direction, not flavour text: tone, pace, accent, breath,
and what the line is *doing*. The prologue narrator is one voice across all three sequences -
an older Estonian woman, close-mic, unhurried, no grandeur - and that consistency is the
reason to write `delivery` before any audio exists.

## Generating

OpenAI `gpt-image-1` at 1536x1024 is the default and produced chapter I. Leonardo.ai with
the `CINEMATIC` preset is the documented fallback and produced chapters II-III after the
OpenAI credit ran out; it needs harder negative prompts and more passes for the same result.
Whichever is used, write the **final** prompt back into the record's `authoring` block, so a
regeneration reproduces the frame instead of reinventing it, and record the generator and
model in `assets/SOURCES.csv`.
