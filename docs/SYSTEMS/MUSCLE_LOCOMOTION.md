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
| Biped, 75 kg, 6 joints, 12 muscles | **Walks.** No fall in 20 s and in 40 s tests, 0.99 m/s (target 1.0), stride 0.85 m, period 0.85 s, upright torso, legs swing past each other. First attempt scooted in a split-leg stance and, after retraining at 8 s, fell at 8.5 s on a 20 s test; the fix was proprioceptive sensors, height and tilt cost terms, a stricter fall rule and a final 20 s training run. Planar only, no pushes or terrain | [`results/biped_strip.png`](../../tools/research/muscle_locomotion/results/biped_strip.png), `biped_clip.json` |
| Bird, snake, human sit/stand/fight | Not built | n/a |

The prototype was visually checked only through stick-figure filmstrips. There is no Godot or Blender in the authoring session, so none of this has been seen on a mesh or in the engine.

## What works against it (limits and risks)

- Evolved gaits look odd without realism terms (posture, symmetry, energy per distance, joint-range comfort). Expect weeks of tuning per body plan, not a one-click result.
- The planar biped walks, but 3D balance, pushes and terrain are untested; open-loop oscillators plus three sensors did not suffice, proprioception and a posture cost did.
- Fluid, reactive motion (combat, sitting, standing up, hitting a moving opponent) needs a goal-conditioned closed-loop policy, usually trained with reinforcement learning rather than a periodic cycle. A small network is cheap to run, but the engine would then need a physics rig and a muscle model; Godot 4.7 has none, so the realistic first target is baked clips with procedural layers (foot IK, additive hits), and a PD-driven ragdoll for combat as a later experiment.
- Birds: flight needs an aerodynamic model (MuJoCo has a fluid drag and lift model for ellipsoids) and different objectives (lift, hover, glide, landing, light bones); untested. Snakes need anisotropic ground friction or a fluid medium; untested.
- The prototype is 2D and deterministic only per seed; results depend on the MuJoCo version (3.15 used).
- A baked joint-angle clip must still be mapped onto each mesh's skeleton (see the [sourcing report](../ANIMAL_3D_SOURCING.md)); the prototype's bones do not match the shipped rigs.

## Verification

**Work in progress:** the prototype was just reworked for parametric bodies and one generalist controller (`evolve_general.py`, body and speed as controller inputs). The stored `results/` and the replay commands below belong to the previous version (commit `c097f21`) and will be regenerated with the new code; `render.py` is not yet updated for the new parameter layout.

`python render.py results/quadruped.json 8` replays the stored controller and must print `alive 1.0`, `speed` about 0.77, `dist` about 6.16. `python render.py results/biped.json 20` must print `alive 1.0`, `speed` about 0.986, `dist` about 19.71. There are no automated tests yet.

## Roadmap

Requested scope, ordered so each stage reuses the previous one. Every stage is a build-time experiment first; nothing reaches the game without its own task, an ADR and a named scope trade-off (AGENTS.md).

**A. Gaits.** Biped walk (done in 2D, see Results), the same quality for the quadruped (re-run with the new sensors and cost), then run (flight phase, 2.5 to 4 m/s). Gait is chosen by target speed, as in Geijtenbeek 2013.

**B. Terrain and body variation.**
- Terrain: slopes up and down (5 to 20 degrees), steps and stairs (the city has stairs; riser about 0.18 m), obstacles to step over, climb or jump, routes around obstacles (needs a heading input), and a low doorway or ceiling (the head must stay under a height limit, so the controller needs a stoop strategy: bend hips and knees, shorter stride; the limit is a collision plane at head height).
- Posture and mass: heavy armour (mass on torso and thighs, stooped rest pose), belly (mass at an offset), dress (extra mass plus restricted hip range and a swing drag), obese, tall and lanky, dwarf (shorter bones, different torso to leg ratio). Each is a change of the creature description, not new code.
- Horse, with and without a rider or pack: a horse is a quadruped with a larger, heavier body (about 500 kg), so a separate preset plus the four horse gaits (walk, trot, canter, gallop) found by evolving at different target speeds. A load is first modelled as `extra_mass` on the trunk (the prototype already supports this): the controller then shifts to a lower stride frequency, more co-contraction and a shorter flight phase. A real rider is not a static mass but a second body on a damped joint, whose swing shifts the centre of mass every stride; that is a second stage, with the rider passive first and actively balancing later. A horse trained on a range of loads, with the load as a sensor input, covers empty, packed and mounted without separate runs.
- Key design decision: instead of evolving one controller per body, train **one controller over a distribution of bodies** with the body parameters (leg length, mass, centre of mass offset) as inputs. Then any citizen, including bodies never trained, gets a gait without a new evolution run. Interpolating between a grid of evolved bodies is the cheaper fallback.

**B2. Species differences and the tail.** Not researched in this session; the points below are general biology from memory and need a source check before they drive parameters.
- Cat versus dog versus horse: a cat has a very flexible spine and loosely attached shoulder blades, so the back bends and extends in each stride; a dog is the endurance compromise with a stiffer back; a horse has a rigid back, very long light lower legs (mass concentrated high on the body, lower legs carry little muscle) and runs on a single toe. These are description changes: split the trunk into two or three bones with spine muscles (cat), set stiffness and range per species, shift mass toward the trunk (horse), and change bone proportions and joint ranges. The prototype's trunk is one rigid bone, so spine flexion is a required extension first.
- Tail as a balance organ: a swinging tail changes the body's angular momentum, so it can control pitch while running and jumping and help a cat twist to land on its feet. It is modelled as a chain of light bones with muscles, whose swing the controller learns. The planar prototype can test pitch control by the tail now (add a tail chain, shove the trunk, compare survival with and without it). Righting in the air and sharp turns at speed are rotations about other axes, so they need the 3D stage.
- Birds use the tail the same way as a rudder and pitch control in flight, which feeds the bird design.

**C. Balance under push.** A shove to the chest (a kick, a shoulder, a crowd) is a push-recovery problem, and it is testable in the current planar prototype before arms exist: apply a random horizontal impulse to the trunk at random times during training and score survival. The body has three known recovery strategies: an ankle strategy (small push, shift pressure under the foot), a hip strategy (bend at the hips, move the trunk against the push) and a stepping strategy (take a fast step to put the foot under the falling centre of mass). Evolution finds them if the sensors let it see them (trunk pitch and rate, horizontal speed, foot contacts and joint angles, which the biped already has) and the training pushes are strong enough to force a step. Training on random pushes is also the standard fix for overfitting to one fixed trajectory.

**D. Interaction.** Arms are not in the model yet, so these need new bones and muscles first.
- Crowds: another agent walking toward you, avoid or push through; needs agent to agent contact forces and a steering input.
- Combat: strike, wind-up, block with a shield, reacting to an incoming attack. This is the hard part: it needs a goal-conditioned, closed-loop policy trained with reinforcement learning (or evolution with a much richer controller), not a periodic cycle. Sit and stand, and climbing onto an obstacle, are the same kind of task.

**E. Delivery to the game.** Godot has no muscle model, so the first realistic route is baked clips: a library of locomotion cycles per body type and speed, blended at runtime with foot IK and additive hit layers. Combat and crowd contact stay on authored or procedural layers until a learned policy proves itself offline. Running a policy in the engine would additionally need a physics-driven rig; treat it as a separate experiment.

Open risks: evolved gaits can look unnatural without realism terms; policies overfit to the training horizon (the first biped result fell after 8.5 s when tested for 20 s and had to be retrained); 2D results do not guarantee 3D balance.
