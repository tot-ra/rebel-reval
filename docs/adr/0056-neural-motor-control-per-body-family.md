# ADR 0056: Neural motor control, one network per body family

**Reference:** maintainer requests 2026-10-16 (session): "lets increase amount of bones and joints in
most important areas, then retrain the model" and "I want everything to be neural-network based. I
want some set of body and env params and maybe initial pose as input => behaviour as output. Trained
in simulated env, maybe with some motivation (pain, maybe some end pose goal, or target to stay
afloat or keep flying etc)". Answers to the follow-up questions: the game runs a distilled pose
network; behaviour is judged by "a very thought-through evaluation system that will take different
aspects of the behavior - strain, energy loss, wind etc. pain is not the only one. goal is the target
motivation"; bipeds, quadrupeds, mixed bodies (monkeys, bears, kangaroos, cats, penguins), birds and
snakes are trained separately. Builds on [ADR 0022](0022-realistic-human-characters.md),
[ADR 0051](0051-condition-adaptive-motion-style-network.md) and
[ADR 0053](0053-context-aware-jumping-leap-network.md). Research code: skeleto-nn.

## Status

**Proposed (2026-10-16), pending approval.** Step 0 (the detail bones) is implemented; everything
else is a plan. Until a family's pose network ships, that family keeps its clips plus the style
(ADR 0051) and leap (ADR 0053) networks.

## Context

- skeleto-nn makes motion in five ways: the style network (trained), *emergent* rules (gait from the
  Froude number, footholds, reactions chosen by predicted pain), *goal scripts* (pelvis, hand and foot
  goals solved by IK: chair, ladder, door), *kinematic models* (swim stroke, flapping, snake: angles as
  functions of a phase) and *physics, evolved* (MuJoCo ragdoll, CMA-ES parameters: fall reflex,
  swimmer, bird). Only the first is a neural network; swimming and flight do not work.
- The game plays 76 CC0 clips on a shared human rig; the networks only bend a few bones on top.
- The human rig bent the trunk at two joints, hung the head straight off the chest and the arms
  straight off the chest: no neck, no collarbones. A shrug or a hunch could only be faked.
- skeleto-nn already has a MuJoCo ragdoll built from any skeleton (`physics.py`: torque-limited PD
  joints, contacts) and a bone-injury model (`injury.py`).
- The machine that trains is an 18-core Apple M5 Pro with 48 GB; MuJoCo runs on the CPU, torch on
  the CPU or Metal.

## Decision

0. **Detail bones on the human rig (done).** MPFB's own neck, clavicles and middle spine bone are no
   longer folded into the coarse bones: `neck`, `shoulder.l`, `shoulder.r` and `spine_upper`
   (75 bones; `tools/assets/realistic_humans/rig_detail.py`). Each new bone copies the rest
   orientation of the bone it splits, so all 76 clips keep their meaning; the build spreads them:
   spine and head rotations are halved between the old bone and the new one, and the collarbone
   follows the arm (it lifts as the arm rises, draws forward as it reaches). The style network's
   shrug now lifts the collarbones, the head drop bends the neck, and the trunk lean is shared by
   three spine joints. The physics body of the biped family is built from this rig, joint for joint.

1. **One policy per body family**, trained separately: *biped* (people of any age, build, strength
   and injury), *quadruped* (dog, cat, wolf, horse, pig, goat, cattle), *mixed* (bodies that switch
   between two and four legs or hop: monkey, bear, kangaroo, penguin, and the cat's climbing and
   jumping), *bird* (walking, take-off, flight, landing, swimming birds) and *snake*. Within a family
   the body is input (segment lengths, masses, strength, joint ranges, injuries, load), so one
   network covers every species and individual of that family.

2. **Input to output.** Each policy sees the body parameters, the environment parameters (ground
   friction, slope and the height field around it, water level, density and current, wind,
   temperature, darkness, smoke), its own state (joint angles and speeds, the trunk's orientation and
   velocity, contacts; the start pose is simply the first state), internal reserves (energy,
   oxygen, body heat) and a goal. It outputs joint targets for the PD muscles 30 times a second.

3. **Goals are the motivation.** A goal is data: a velocity and heading to hold, a point to reach, an
   end pose to reach and hold (sit, lie, kneel, climb onto), stay afloat and breathe, keep altitude
   and airspeed, land on a surface, get up after a fall. The goal is part of the input, so one
   network learns every goal of its family.

4. **The evaluation system scores every behaviour, not only pain.** Every step of training is scored
   by a set of terms, each a physical or physiological consequence measured in the simulation, in
   comparable units (cost per second, calibrated so that a normal walk of a healthy adult has a known
   value for each term):

   | term | measured as |
   |---|---|
   | goal | progress toward the goal; the only reward, everything else is cost |
   | injury | fracture risk per region from contact force and loading rate (`injury.py`) |
   | pain | load on sore regions (a sprained ankle, a broken arm, a wound) and joints driven to their limits |
   | strain | muscle torque against its capacity, squared, per joint; time at the end of a joint's range (ligaments) |
   | energy | metabolic power: positive work over muscle efficiency, negative work, isometric holding, basal rate |
   | fatigue | an energy reserve that drains with effort and refills at rest; a tired body is weaker |
   | balance | fall risk: the centre of mass against the support, trunk tilt and spin, any part other than feet or bracing hands touching the ground |
   | wind and water | aerodynamic and hydrodynamic forces act in the simulation; their cost is the extra effort, strain and fall risk they cause, never a separate wish |
   | heat | heat lost through the exposed surface (posture: arms against the trunk, a curled body expose less), produced by effort and shivering |
   | breath | oxygen spent while the mouth is under water or in smoke |
   | gaze | head shake and spin: a stable head sees where it goes |
   | smoothness | jerk of the muscle commands (the nervous system's own economy; it also makes distillation stable) |

   The weights of the terms are a **motivation profile** that is also an input of the policy (urgency
   raises the goal against comfort; a frightened body accepts pain; an injured one guards). One network
   therefore covers a careful walk and a desperate flight. Every term has probes: scenes in which that
   term alone must decide the outcome (ice: shorter, flatter steps; a sprained ankle: a limp; a gale:
   a lean; deep water: floating and breathing), checked automatically after each training run.

5. **Training** is reinforcement learning (PPO) in MuJoCo, with bodies, environments, goals and
   motivation profiles drawn at random for each episode. No motion capture and no clip is used as a
   reference; naturalness has to come from the evaluation system.

6. **The game runs a distilled pose network.** A second, smaller network per family learns to copy the
   trained policy without physics: from the body, environment, goal and the last poses it predicts
   the next pose. The game evaluates it through a small native extension (GDExtension, C++) so that
   dozens of characters can run it; GDScript runs it for the hero until then. It replaces clips,
   the style network and the leap network family by family, each only after review plates show it
   is at least as good as what it replaces.

7. **Every method of skeleto-nn that is not a network is retired** as the families cover its
   motions: emergent rules, goal scripts, kinematic models and evolved controllers stay only as
   baselines to compare against.

## Plan

| stage | delivers |
|---|---|
| 0 | detail bones on the human rig (done) |
| 1 | evaluation system with its probes; biped physics body from the 75-bone rig; vectorised MuJoCo environment; PPO trainer |
| 2 | biped: stand, walk, run, turn, stop on varied ground, bodies and injuries; distilled pose net; the hero in the game |
| 3 | biped: falls and getting up, jumps and drops, end-pose goals (sit, kneel, lie, climb onto); water (stay afloat, swim) |
| 4 | quadruped family; then birds (flight first); then mixed bodies; then snakes |
| 5 | native inference extension; citizens and animals switch from clips to pose networks |

## Consequences

- The game's motion becomes a product of training: a new situation is new data or a new term plus a
  retrain, not new animation code.
- Training is hours to a night per stage on the local machine, and will need iteration; RL without
  reference motion can find odd but cheap movements. The evaluation terms and their probes are the
  defence, and each stage ships only with review plates.
- A native extension adds a build step for the game (one C++ library per platform).
- The bone count of the human rig changed (71 to 75): every human and garment was rebuilt; anything
  skinned to the rig outside this pipeline must be re-exported.
