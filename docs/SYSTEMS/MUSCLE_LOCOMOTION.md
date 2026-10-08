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

How to run it locally (macOS included), resume interrupted training and continue the 3D curriculum: [`tools/research/muscle_locomotion/README.md`](../../tools/research/muscle_locomotion/README.md).

Files: `creature.py` (bone graph to MuJoCo XML), `presets.py` (parametric `biped` and `quadruped`; `Body` = size, mass multiplier, strength, load, belly), `sim.py` (simulation, controller, fitness), `evolve_general.py` (CMA-ES, one controller for a range of bodies and speeds), `evolve.py` (older single-body search), `render.py` (replay on named bodies, gallery PNG, baked clip JSON), `results/`.

```bash
pip install -r tools/research/muscle_locomotion/requirements.txt
cd tools/research/muscle_locomotion
python evolve_general.py biped --ranges human_narrow --fr 0.25 0.45 --gens 500 --out narrow.json   # about 20 min on 4 cores
python evolve_general.py biped --ranges human_wide --fr 0.25 0.5 --gens 800 --w-speed 3 --init narrow.json --sigma 0.3 --out wide.json
python render.py wide.json --fr 0.35          # gallery PNG and one baked clip per named body
```

Design points that mattered:

- Planar (sagittal) 2D: x forward, z up, hinge joints about y. Legs left and right are independent in the same plane.
- Muscles are MuJoCo **fixed tendons**: length = linear function of the joint angle with a constant moment arm, length range swept over the joint limits. This is the "line with min and max length" and also allows muscles that cross two joints. Point-to-point straight tendons were tried first and failed: on bent rest poses the line passed on the wrong side of the joint, so both antagonists pushed the same way.
- Muscle strength is a per-joint peak torque; the MuJoCo muscle model adds activation lag (10 ms up, 40 ms down) and the force-length curve.
- Generalist controller: the network sees a context vector (Froude number of the target speed plus log size, log mass, log strength, load and belly), and biases, oscillation amplitude and co-contraction are linear in that context, so one set of weights covers many bodies and speeds. Speed is set as a Froude number (speed = Fr x sqrt(g x standing height)) so scaled bodies move in dynamically similar ways. Joint damping scales with size^4.5 and armature with size^5; a fixed damping made dwarfs fail until this was corrected. Every generation scores all candidates on the same few (body, speed) cases, with the plain body and parameter extremes always in the mix (a controller trained on random mid-range bodies failed on the plain body).
- Gait realism: the first generalist "walked" by shuffling at 3 Hz with small steps; limiting the stride frequency to 0.6 to 2.0 Hz (scaled by 1/sqrt(size)) and adding a cost for foot air time (each foot should be off the ground about 38 % of the time) produced a real swing-and-plant gait.
- Controller of the first single-body experiment (49 parameters for the biped, 121 for the quadruped): per joint a bias, oscillation amplitude, phase, co-contraction and sensor weights, plus one global stride frequency. The flexor gets `c + x`, the extensor `c - x`. Structure matters: a free per-muscle parametrisation sat in a "stand still" local optimum.
- Fitness (CMA-ES, lower is better): 10 x fraction of the episode not survived, plus mean absolute speed error against the target, plus a small effort term. Falling = root too low, trunk tilted past a limit, or any non-foot part touching the ground.

## Results (honest)

| Creature | Result | Evidence |
|---|---|---|
| Biped, one generalist controller for many bodies (6 joints, 12 muscles, symmetric: 127 parameters) | Trained on the narrow range (size 0.9 to 1.1, mass x0.9 to 1.2, load up to 10 %). All six named bodies stay up 15 s with legs that alternate and pass each other, but speed is below target: normal 0.84 m/s (target 1.04), dwarf 0.39 (0.84), tall 0.92 (1.11), heavy 0.69, armoured 0.72, belly 0.54. 29 of 30 held-out narrow-range cases survive 15 s. The earlier non-symmetric version tracked speed better but walked with one leg always ahead (`results/demo/biped_planar_bodies.gif`, kept as the before picture); the symmetric one is `biped_planar_symmetric_v1.gif`. Wide-range retraining with a higher speed weight was interrupted by a session restart | [`results/biped_general_gallery.png`](../../tools/research/muscle_locomotion/results/biped_general_gallery.png), `results/demo/*.gif`, `biped_general*_clip.json` |
| Quadruped, same generalist method | Training queued; the earlier single-body quadruped (0.77 m/s, 8 s) used the previous code and was removed with its stale results | n/a |
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


`python render.py results/biped_general.json --fr 0.35` replays the stored controller on six named bodies and must print `alive 1.00` for each, with speeds about 0.84, 0.39, 0.92, 0.69, 0.72, 0.54 m/s (normal, dwarf, tall, heavy, armoured, belly) and writes the gallery and clips. There are no automated tests yet.

## Pushing evolution toward natural gaits

Observed (2026-10-08): in the planar biped GIF one leg (orange) stays ahead of the pelvis and the other (blue) stays behind, so the legs never swap: a lunging, slow, statically stable gait. Evolution optimises the fitness, not the intent; if survival and speed error are the only terms, any stable shuffle is a valid answer. Remedies, from cheapest to most expensive; the first four are implemented in the planar prototype (`sim.py`), the 3D trainer already has the first.

1. **Structure (removes whole classes of bad solutions).** The right leg runs the left leg's controller half a cycle later with mirrored sensors (`Creature.symmetric`). A lead leg is then impossible by construction. Also halves the search space.
2. **Gait-shape costs measured from the simulation.**
   - Lead asymmetry: the mean forward position of each foot relative to the pelvis must match (`w_lead`).
   - Excursion: each foot must swing through at least about 0.6 leg lengths (`w_exc`), so a trailing foot that barely moves is punished.
   - Swing clearance: the average height of an airborne foot should reach about 5 cm (`w_clear`), against dragging.
   - Alternation: heel strikes must alternate left, right, left, right (`w_alt`).
   - Foot air time about 38 % per foot (`w_air`), as before.
3. **Energy.** Natural walking is close to energy-optimal (pendulum-like gait). The effort term is a cost of transport proxy; raising its weight late in training removes needless co-contraction. It must not be raised first, or standing still wins.
4. **Speed pressure.** A slow target allows a static lunge; a faster target (Froude 0.35 and up) needs real swing phases. Curriculum: train at the faster end, then widen.
5. **Environment (not yet implemented, same trainer hooks).** Small random bumps and kerbs force foot lift; random pushes force stepping, which swaps the legs; slopes and stairs need a clearance. These also make the gait robust, which fixed-trajectory training does not.
6. **Reference prior (optional, needs care).** A soft penalty on the distance of the joint-angle curves to generic human walking curves (hip about 30 degrees flexed at heel strike to 10 degrees extended at toe-off, knee about 15 degrees in loading and 60 degrees in swing, ankle small) pulls the shape toward human walking. It needs a correct reference (motion capture or published curves); I did not have one in the session, so this is left out, and values quoted here are from memory.
7. **Learned discriminator (heavier).** An adversarial motion prior learns "does this look like a real gait" from example clips (as in AMP-style imitation); it needs a dataset of human or animal motion and reinforcement learning.

Results of the planar retrain with items 1 to 4 are in the Results table once finished.

## 3D architecture (in progress)

The planar prototype proved the method. The target is a full 3D system for procedural people, animals, birds and snakes. Design decisions for `creature3d.py` and `sim3d.py`:

- **Skeleton:** bones are rigid capsules (boxes for feet) joined in a tree. Each bone gives a rest direction in the creature frame (x forward, y left, z up), a length, a mass, an attach point on its parent and a list of **degrees of freedom**; a joint is up to three hinges in series (hip: flexion, abduction, rotation). Joint ranges are the only limits.
- **Muscles:** every degree of freedom gets an antagonist pair of fixed-tendon muscles with constant moment arm and a length range taken from the joint range (as in 2D). Biarticular muscles are added as extra tendons crossing two joints.
- **Bilateral symmetry by construction:** only the left side and the midline are described; the right side is generated by mirroring (axial-vector rule for hinge axes: axis becomes (-ax, ay, -az)). The right side runs the left controller half a cycle later with mirrored sensors, which halves the parameters and removes asymmetric gaits.
- **Body:** free root joint, pelvis, a three-axis spine joint, arms (needed for balance now, for combat later), three-axis hips, knees, two-axis ankles. A quadruped, a bird and a snake are other bone trees on the same code.
- **Sensors:** gravity vector, angular velocity and linear velocity in the body frame, foot contacts, plus the body context vector. These are what a real animal has (vestibular, proprioceptive, touch).
- **Controller:** per degree of freedom an oscillator plus linear feedback on the sensors, as in 2D. Balance in 3D is hard to find from scratch, so training uses an **assist curriculum**: an upright-and-height support force on the pelvis that starts strong and is annealed to zero, the standard way to bootstrap bipedal control; a finished controller must walk with assist = 0.
- **Tasks beyond plain walking** reuse the same machinery by adding scenario parameters to the controller context and to the scene: target speed (running), slope angle, step height and a ceiling, random pushes, and later a second agent. Combat needs a goal-conditioned policy and is the last stage.

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
