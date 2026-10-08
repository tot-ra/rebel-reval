# Muscle-driven locomotion prototype (build-time research)

Design, results and roadmap: [`docs/SYSTEMS/MUSCLE_LOCOMOTION.md`](../../../docs/SYSTEMS/MUSCLE_LOCOMOTION.md). Nothing here runs in the game.

## Run it on a Mac (or any machine)

```bash
cd tools/research/muscle_locomotion
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt          # mujoco has native Apple Silicon wheels
```

Rendering uses the native OpenGL on macOS (no extra install). On headless Linux install `libosmesa6` first.
Training uses every CPU core by default (`--procs N` to change); runs scale almost linearly with cores. Training writes a `<out>.partial` checkpoint every 25 generations, so an interrupted run resumes with `--init <out>.partial`.
Write outputs under `runs/` (git-ignored).

### Finish the 3D human (assist curriculum)

The harness that holds the 3D human up is annealed from 100 % to 0 %. Stages 1.0 and 0.7 are done and stored in `checkpoints/`; continue from 0.7:

```bash
python evolve3d.py --stages "0.45:150,0.25:150,0.1:150,0.0:400" --init checkpoints/human3d_assist0.70.json --out runs/human3d
python demo3d.py runs/human3d_a0.00.json --out runs/human3d.gif --label "3D human"     # three views
```

A result only counts when it walks at assist 0.00 (`alive 1.00` in the printout). Earlier stages show how far it got.

### Planar generalist biped (many bodies, many speeds)

```bash
python evolve_general.py biped --ranges human_wide --fr 0.25 0.5 --gens 800 --w-speed 4 \
    --init results/biped_general.json --sigma 0.3 --out runs/biped_wide.json
python render.py runs/biped_wide.json --fr 0.35          # gallery PNG and one baked clip per body
python demo_planar.py runs/biped_wide.json --fr 0.35 --seconds 4 --out runs/biped_wide.gif
```

`checkpoints/biped_planar_wide_partial.json` is the last checkpoint of an interrupted wide run (resume with `--init`).

### Quadruped

The generalist trainer supports `quadruped` (`--ranges dog_narrow`, then `dog_wide`, `--fr 0.3 0.7`); no result is stored yet, a first run was interrupted. The natural-gait costs and left-right symmetry are on for the biped only so far.

## Files

`creature.py` / `presets.py` / `sim.py` planar creatures; `creature3d.py` / `presets3d.py` / `sim3d.py` the 3D human; `evolve.py` single-body search (old); `evolve_general.py` planar generalist trainer; `evolve3d.py` 3D curriculum trainer; `render.py`, `demo_planar.py`, `demo3d.py`, `viz.py` rendering; `results/` stored results, clips and demo GIFs; `checkpoints/` resumable states.

To share a result, copy the JSON into `results/`, re-render the gallery and clips, and open a PR. Keep GIFs few and small (each is 4 to 5 MB).
