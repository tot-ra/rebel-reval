# Muscle-driven procedural locomotion

Status: planned; **research prototype only** (build-time Python under [`tools/research/muscle_locomotion/`](../../tools/research/muscle_locomotion/), not wired into the game). Nothing here is loaded at runtime. Related: [animal 3D sourcing and animation strategy](../ANIMAL_3D_SOURCING.md), [Flora and fauna](../FLORA_FAUNA.md), [Combat animation](./COMBAT_ANIMATION.md).

Scope: one creature description for biped, quadruped, bird and snake bodies, motion found by evolution instead of hand animation, baked to clips. Out of scope: runtime muscle simulation, ragdoll combat, 3D balance, flight, snakes (designed, not built).

## Idea

1. **Skeleton** = a graph of rigid bones joined by hinge joints; bones never stretch.
2. **Muscles** = lines that only pull. Each has a force and a length range given by the joints it crosses, so it can neither over-contract nor over-stretch. Antagonist pairs move a joint both ways.
3. **Mass** can be added anywhere (belly, heavy head), so the centre of mass changes the gait.
4. **Controller** = a micro-network: a stride oscillator plus a few sensors (trunk pitch, pitch rate, foot contacts) driving each muscle pair.
5. **Evolution** searches the controller weights for the task (move at target speed, do not fall, low effort).
6. A **species is data**: bone lengths, masses, muscle strengths and joint ranges.
7. The winning controller is **baked into a looping clip** (joint rotations per bone), so the engine only plays animation.

## Prior art (so we do not claim novelty)

Not a new idea: [Karl Sims, Evolved Virtual Creatures, 1994](https://karlsims.com/evolved-virtual-creatures.html) (evolved morphology and neural muscle control); [Geijtenbeek et al., Flexible Muscle-Based Locomotion for Bipedal Creatures, SIGGRAPH Asia 2013](https://www.cs.ubc.ca/~van/papers/2013-TOG-MuscleBasedBipeds/index.html) (muscle-driven bipeds, controllers adapt gait to target speed, also in the open-source [SCONE](https://joss.theoj.org/papers/10.21105/joss.01421.pdf)); [Lee et al., Scalable Muscle-actuated Human Simulation, SIGGRAPH 2019](https://mrl.snu.ac.kr/research/ProjectScalable/Page.htm) (346 muscles via learning); [Vaughan 2018](https://research.tees.ac.uk/en/publications/evolution-of-neural-networks-for-physically-simulated-evolved-vir/) (neuroevolution of quadrupeds). MuJoCo has a muscle actuator with force-length-velocity curves built in. What was not found is a ready game pipeline that uses one description for all body plans and bakes clips for an engine; that integration is the possible contribution.

## The prototype

Files: `creature.py` (bone graph to MuJoCo XML), `presets.py` (`biped`, `quadruped`, optional `belly` mass), `sim.py` (simulation, controller, fitness), `evolve.py` (CMA-ES, 4 processes), `render.py` (replay, filmstrip PNG, baked clip JSON), `results/`.

```bash
pip install -r tools/research/muscle_locomotion/requirements.txt
cd tools/research/muscle_locomotion
python evolve.py quadruped --gens 300 --pop 48 --T 8 --v 1.0 --out q.json   # about 3 minutes on 4 cores
python evolve.py biped --gens 400 --pop 48 --T 8 --v 1.2 --belly 12 --out b.json
python render.py results/quadruped.json 8     # writes *_strip.png and *_clip.json
```

Design points that mattered:

- Planar (sagittal) 2D: x forward, z up, hinge joints about y. Legs left and right are independent in the same plane.
- Muscles are MuJoCo **fixed tendons**: length = linear function of the joint angle with a constant moment arm, length range swept over the joint limits. This is the "line with min and max length" and also allows muscles that cross two joints. Point-to-point straight tendons were tried first and failed: on bent rest poses the line passed on the wrong side of the joint, so both antagonists pushed the same way.
- Muscle strength is a per-joint peak torque; the MuJoCo muscle model adds activation lag (10 ms up, 40 ms down) and the force-length curve.
- Controller (49 parameters for the biped, 121 for the quadruped): per joint a bias, oscillation amplitude, phase, co-contraction and sensor weights, plus one global stride frequency. The flexor gets `c + x`, the extensor `c - x`. Structure matters: a free per-muscle parametrisation sat in a "stand still" local optimum.
- Fitness (CMA-ES, lower is better): 10 x fraction of the episode not survived, plus mean absolute speed error against the target, plus a small effort term. Falling = root too low, trunk tilted past a limit, or any non-foot part touching the ground.

## Results (honest)

| Creature | Result | Evidence |
|---|---|---|
| Quadruped, 25 kg, 12 joints, 24 muscles | Walks 8 s without falling at 0.77 m/s (target 1.0), stride 0.51 m, period 0.64 s. Gait is crouched and shuffling, not natural | [`results/quadruped_strip.png`](../../tools/research/muscle_locomotion/results/quadruped_strip.png), `quadruped_clip.json` |
| Biped, 75 kg, 6 joints, 12 muscles | **Does not walk yet.** Survives 8 s but moves by scooting in a split-leg stance at 3 Hz (the frequency limit), 0.62 m/s | [`results/biped_strip.png`](../../tools/research/muscle_locomotion/results/biped_strip.png) |
| Bird, snake, human sit/stand/fight | Not built | n/a |

The prototype was visually checked only through stick-figure filmstrips. There is no Godot or Blender in the authoring session, so none of this has been seen on a mesh or in the engine.

## What works against it (limits and risks)

- Evolved gaits look odd without realism terms (posture, symmetry, energy per distance, joint-range comfort). Expect weeks of tuning per body plan, not a one-click result.
- Bipeds need real balance feedback, a longer curriculum (standing, then stepping, then walking) and probably 3D; open-loop oscillators plus three sensors did not suffice here.
- Fluid, reactive motion (combat, sitting, standing up, hitting a moving opponent) needs a goal-conditioned closed-loop policy, usually trained with reinforcement learning rather than a periodic cycle. A small network is cheap to run, but the engine would then need a physics rig and a muscle model; Godot 4.7 has none, so the realistic first target is baked clips with procedural layers (foot IK, additive hits), and a PD-driven ragdoll for combat as a later experiment.
- Birds: flight needs an aerodynamic model (MuJoCo has a fluid drag and lift model for ellipsoids) and different objectives (lift, hover, glide, landing, light bones); untested. Snakes need anisotropic ground friction or a fluid medium; untested.
- The prototype is 2D and deterministic only per seed; results depend on the MuJoCo version (3.15 used).
- A baked joint-angle clip must still be mapped onto each mesh's skeleton (see the [sourcing report](../ANIMAL_3D_SOURCING.md)); the prototype's bones do not match the shipped rigs.

## Verification

`python render.py results/quadruped.json 8` replays the stored controller and must print `alive 1.0`, `speed` about 0.77, `dist` about 6.16. There are no automated tests yet.

## Next steps (each needs a task with allowed files; a major new system also needs an ADR and a named scope trade-off per AGENTS.md before runtime code)

1. Biped: staged curriculum, torso-upright and symmetry terms, hip abductor model or 3D, longer runs. Done when it walks 20 s at 1.2 m/s with filmstrip review.
2. Quadruped: add posture and effort realism terms, gait diversity (walk, trot, gallop at different targets); add `belly` and heavy-head variants and record how the gait shifts.
3. Export: map a baked clip onto a shipped rig (for example the dog or horse in `tools/assets/medieval_animal_rigs.py`) and review in Godot.
4. Bird and snake prototypes with their own objectives.
5. Decide whether closed-loop policies (combat, sit/stand) are worth the runtime cost.
