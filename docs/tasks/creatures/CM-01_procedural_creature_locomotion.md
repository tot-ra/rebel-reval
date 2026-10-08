# CM-01: Procedural muscle-driven locomotion for people and animals

Board row: not yet created (the `tasks` tool was not available in the authoring session; create the row and point it here). Priority: medium, research. Depends on: none for the build-time work; integration depends on a new ADR.

## Player-facing goal

Many body types of people, mammals, birds and snakes move believably and fluidly in the game without a hand-made clip library per species: they walk and run at the right speed for their size and weight, climb slopes and stairs, step over, duck under and go around obstacles, keep balance when shoved, push through or avoid crowds, and fight. A heavy, armoured, dwarf, tall, obese or dress-wearing person looks different when moving.

## Why this is needed

See [Goal and motivation](../../SYSTEMS/MUSCLE_LOCOMOTION.md) (the single source for the why and the maintainer's list of situations). In short: the animal set is tiny, AI-generated animals are unreliable, downloaded animals lack clips, and hand animation does not scale to the variety wanted.

## Deliverable (staged; each stage needs its own review, GIFs and a verification line)

| Stage | Result | Verification |
|---|---|---|
| M1 | Planar biped walks, many bodies, many speeds, natural alternating gait | `render.py results/biped_general.json` prints `alive 1.00` for all six bodies; legs alternate in the gallery (done at low speed accuracy; speed tracking still below target) |
| M2 | 3D human walks with the harness at 0 | `demo3d.py` result with `harness 0%` and `alive 1.00` for 15 s, three-view GIF reviewed |
| M3 | Quadruped walks (planar then 3D), dog sizes and loads | planar quadruped generalist survives the held-out table; GIF |
| M4 | Run (flight phase, Froude 0.7 to 1.2) for biped and quadruped | GIF; speed within 15 % of target |
| M5 | Slopes up and down, stairs | scene parameters in the trainer; survival table per slope angle; GIF |
| M6 | Obstacles: step over, jump, duck under a ceiling, steer around | scenario table and GIFs |
| M7 | Push recovery | survival under random impulses in training and an unseen impulse test; GIF |
| M8 | Body variety: armour, belly, dress, obese, tall, dwarf, horse with rider | per-body table and GIF gallery |
| M9 | Birds (ground gait, then flight) and snakes | GIFs; own objectives documented |
| M10 | Arms, strikes, blocking, reactive combat and crowd contact | needs a goal-conditioned policy; separate design review |
| M11 | Integration: bake clips or run policies in Godot | needs an ADR (scope change, AGENTS.md), a named scope trade-off and a task |

## Allowed files

`tools/research/muscle_locomotion/**`, `docs/SYSTEMS/MUSCLE_LOCOMOTION.md`, `docs/ANIMAL_3D_SOURCING.md`, `docs/tasks/creatures/**` and the generated docs indexes. No runtime script, scene or asset under `scripts/`, `scenes/` or `assets/` changes until M11 is approved.

## Constraints and non-goals

- Build-time and research only until M11; nothing here is loaded by the game.
- Not a replacement of the shipped animal or character rigs yet; baked output must map onto them in a separate task.
- Results must be reproducible from stored JSON with the commands in the README; do not store giant binaries (each GIF is 4 to 5 MB, keep few).
- Honest reporting: say when a gait is a shuffle, a limp or only works at one speed; the lessons in the system page apply.
- Asset freeze (P0-040) does not apply to this research code, but any production art or rig it produces needs its own task.

## Verification

`python3 tools/validate_*` is not involved. Per stage: the commands and expected printout in [`tools/research/muscle_locomotion/README.md`](../../../tools/research/muscle_locomotion/README.md) and the table in the system page; GIFs under `results/demo/`; `python3 tools/docs_index.py --check`.

## Documentation

[`docs/SYSTEMS/MUSCLE_LOCOMOTION.md`](../../SYSTEMS/MUSCLE_LOCOMOTION.md) is the owning page; update its Results table and Roadmap with every stage.
