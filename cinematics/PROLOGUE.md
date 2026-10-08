# Prologue screenplay

The opening of the game, shot by shot. **The records are the source of truth**
(`content/cutscenes/*.json`); this page is the readable version for writers, voice
direction and review. When they disagree, the record wins.

- Decision: [ADR 0034](../docs/adr/0034-cutscene-mode-and-cinematic-prologue.md)
- How it runs: [`docs/SYSTEMS/CUTSCENES.md`](../docs/SYSTEMS/CUTSCENES.md)
- How prompts are written: [`PROMPT_GRAMMAR.md`](PROMPT_GRAMMAR.md)
- Protagonist and spirit layer: [ADR 0033](../docs/adr/0033-teen-protagonist-and-spirit-dialogue-combat.md)

## Shape

Three sequences, twelve shots, roughly four minutes unskipped.

```
Main menu - Start
  └─ I.  The Forging of Chains      cutscene.prologue.conquest       6 shots   1219 → spring 1343
      └─ II. The almshouse           cutscene.prologue.almshouse_dawn 3 shots
          ├─ observed duel           dialogue.prologue.almshouse_quarrel
          ├─ first own duel          dialogue.prologue.porter_confrontation
          ├─ Kalev                   dialogue.prologue.kalev_arrives
          └─ III. The forge          cutscene.prologue.taken_in       3 shots
              └─ gameplay: the forge, spawn smithy_start
```

Esc held at any point during a sequence jumps to its chain target. Esc during chapter II
skips the whole prologue to the forge, which is the behaviour the old text title card had.

## One narrator

An older Estonian woman, unnamed and unseen, telling this to the player. Close-mic,
unhurried, no grandeur, no self-pity. She is not a historian and not a bard: she is someone
who has told this before and expects nothing from telling it. She warms exactly once, at the
end of chapter I when she turns from the century to the boy, and once more at the forge.

She is never identified. Do not cast her as Aita, as Kalev's mother, or as anyone the player
will later meet; the shot list does not support it and ADR 0033 removed the ancestral
blood-debt frame that would have.

## I. The Forging of Chains

Grade `memory_cold`. Attested history, told as grievance. The Dannebrog banner is presented
explicitly as a story the Danes told about themselves (`folklore` in
[`docs/CANON.md`](../docs/CANON.md)); everything else in the chapter is attested.

| Shot | Caption | Beat |
|---|---|---|
| `s01_fleet` | The coast of Rävala. June 1219. | A fleet too large to count, arriving on an indifferent sea. "Every chain is forged twice." |
| `s02_banner` | Lyndanisse. The fifteenth of June. | The red banner with the white cross, lit from behind, over a trampled hilltop. "Nothing fell out of the sky for us." |
| `s03_hill` | Toompea. The years after. | A half-built stone castle rising on the burnt hill fort, hauled up the ramp by Estonian backs. *Taani linn* - the Danish town. |
| `s04_town` | Reval. A Hanseatic town under Lübeck law. | Wealth and exclusion in one frame. "We were the hands. Useful, and outside." |
| `s05_tax` | The 1340s. King Valdemar the Fourth needs silver. | A bored bailiff weighing coins at a farm table; a cauldron and a scythe already taken. "He will not carry it twice in one spring." |
| `s06_spring` | Reval. Spring, 1343. | Pull out from one lit window to the whole walled town at blue dawn. Nothing has happened yet. "Nobody has told him yet what he is for." |

The chapter stops **before** St George's Night (23 April 1343). The uprising is pressure in
this prologue, not an event. Do not add a signal fire.

## II. The almshouse of the Holy Spirit

Grade `present_warm`. Replaces the old black-screen title card. Three shots, and the third
hands straight into the observed spirit duel.

| Shot | Caption | Beat |
|---|---|---|
| `s01_hall` | The almshouse of the Holy Spirit. Before first light. | Rows of straw pallets. One boy awake, off-centre, looking at nothing. "He always wakes before the bell." |
| `s02_seen` | No one else wakes. | The same room with the spirit layer on top: faceless cyan shapes bowed over the sleepers. The rule of the game, stated once. "He learned early not to say so." |
| `s03_quarrel` | The matron and the porter, over bread. | Over the boy's shoulder into a doorway argument. "It sounds like bread. It is not about bread. Watch them, boy." |

`s02_seen` is the hook and the tutorial. It must read as **perception**, not as a monster
scene: nothing attacks, nothing screams, and the boy's reaction is a blink. The horror is
that this is ordinary to him.

## III. The forge

Grade `present_warm`. Plays after Kalev's dialogue and owns the transition to gameplay.

| Shot | Caption | Beat |
|---|---|---|
| `s01_door` | The lane by the Holy Spirit. Morning. | The almshouse door shuts behind them. Kalev leads and does not look back. The frame does not promise this is better. |
| `s02_street` | Lower Town. | The world the player is about to get. In a doorway, something leans out to look at him. "He kept walking. That is the first thing to learn." |
| `s03_forge` | The forge of Kalev. Lower Town, spring 1343. | Heat, after two cold chapters. "Every commission is somebody's intention, and you will be holding it." Then: "Go in, boy." |

`s03_forge` ends on the boy stepping toward the light, and the cut to gameplay continues
that motion - no fade.

## Art status

Chapter I was generated with OpenAI `gpt-image-1` and is final. Chapters II and III are
Leonardo.ai fallbacks made after the OpenAI credit ran out mid-run; they are marked
`provisional` in `assets/SOURCES.csv` and are listed under **Limits** in
[`docs/SYSTEMS/CUTSCENES.md`](../docs/SYSTEMS/CUTSCENES.md) with their specific defects. The
prompts needed to regenerate them are already in the records.

## Moving to video

Each shot's `authoring.video_prompt` is already written: duration, camera move, subject
motion beat by beat, audio cues tied to specific words, and whether lip-sync is required.
Producing the video tier means generating the clips, dropping them next to the stills,
filling the shot's `video` field, and recording provenance. No record text, no timing and no
code changes. Voice-over comes from the lines; `delivery` on each line is the casting brief.
