# ADR 0051: Condition-adaptive motion style from a small neural network

**Reference:** maintainer request 2026-10-16 (session): "the initial idea was a small fast neural
network that would adapt to different situations in the game, affecting the creature's behaviour
with its limbs ... we ended up with simple hard-coded behaviours instead. Make it a universal
approach so creatures adapt to different situations and can be re-trained fast when new
environmental features are added: bleeding, freezing, wet, slipping on ice ... without hard-coding
those animations, because the environment is interactive. Not only citizens walking, also birds
and animals." The same session asked to use existing solutions where they are commercially usable;
the survey is [`procedural_motion_existing_solutions.md`](../reports/procedural_motion_existing_solutions.md).

Related: ADR 0040 (procedural motion on `SharedCharacterRig`, proposed in a session and never
committed) and the skeleto-nn research
([`MUSCLE_LOCOMOTION.md`](../SYSTEMS/MUSCLE_LOCOMOTION.md)). Feature page:
[`MOTION_STYLE.md`](../SYSTEMS/MOTION_STYLE.md).

## Status

**Proposed; implemented at the maintainer's request (2026-10-16), pending approval.** The layer is
additive and calibrated to change nothing in a normal situation; reverting it removes
`scripts/motion/`, `assets/motion/` and the presenter hooks listed in the feature page.

## Context

- Creature motion in the city is authored clips (people, mammals) and hand-written formulas (bird
  wingbeat profiles per family, the swim stroke modifier, hand-to-wound and limp rules in the
  skeleto-nn hit model). Each new situation needs new code, and nothing reacts to ice, rain, cold,
  wind or wounds.
- The game already simulates the situations: weather and seasons (rain, snow, ice, temperature,
  wind), time of day, and the world has quays, mud roads and snow.
- skeleto-nn's earlier learned parts (evolved reflexes, a PPO tracker) were controllers for physics
  bodies that the engine does not have. A Godot runtime cannot afford a muscle simulation per
  citizen.
- Licence check (report above): learned-animation research code and mocap datasets that would
  help are mostly non-commercial (AI4Animation, ASE/CALM, LAFAN1, AMASS); training tools
  (PyTorch, MuJoCo, pycma) are permissive; an ONNX GDExtension exists but is immature. A tiny MLP
  in GDScript has no dependency and runs everywhere.

## Decision

1. **Situations are data that set physical channels.** A condition (ice, wet cobbles, mud, deep
   snow, frost, gale, night, smoke, bleeding at a body region, sprain, broken arm, drunk, exhausted,
   heavy load ...) only states its effect on 24 channels (friction, sink, wetness, insulation, air
   temperature, core cooling, wind, bleeding and wound position, pain per region, fatigue,
   dizziness, load, darkness, smoke). The registry is one JSON file shared by trainer and game.
2. **One style network for every body plan.** An MLP (31 inputs, two hidden layers of 64, 24
   outputs; about 7,800 weights) maps the channels and the body (biped, quadruped, bird; mass; leg
   length; flying; speed as a Froude number) to generic style knobs: speed taken, stride, ground
   contact share, stance width, crouch, trunk pitch and roll, arms out, each arm hugged, each hand
   pressed on the wound point, head down, shoulders raised, shiver, flat feet, swing clearance,
   limp side, caution, tail tuck, fur or feather fluff, wingbeat rate, amplitude and glide share.
3. **Trained on consequences, offline, in skeleto-nn** (MIT, the maintainer's repo). A
   differentiable model of what a style would cause (slipping against available friction and the
   injury of the fall, tripping, sideways balance, wind moment, heat lost against heat made, blood
   lost under a hand's pressure, pain from loading sore limbs, smoke breathed, lift against weight,
   effort, not reaching the commanded speed) is minimised by gradient descent in about 25 s on a
   CPU. No example motions and no third-party data or weights.
4. **Body state in the game.** Wetness, core cooling, blood lost, fatigue, pain and wounds advance
   with exposure (rain unless sheltered, water, a fire) and with the style actually in use, by the
   same equations as the trainer. Deterministic, no randomness.
5. **Calibrated, additive presentation.** What is applied is
   `neutral + net(situation) - net(no situation)`, so in a normal situation every creature moves
   exactly as before. Presenters apply the knobs on top of the existing clips: a
   `SkeletonModifier3D` on the shared humanoid rig, a playback and posture layer for the city
   mammals, and the wingbeat parameters of the flying birds. The logic plane, `GameState`, saves and
   navigation are unchanged.
6. **Re-training workflow.** A condition over existing channels is a JSON entry (no retraining). A
   new physical effect is a channel plus a cost term in skeleto-nn and a warm-started retrain of
   about 10 s; old weight files load into the wider schema with a zero column. The export command
   writes the weights, the registry and golden vectors that the Godot test checks.

## Consequences

- One mechanism covers ground, weather, injury and state for people, animals and birds; nothing
  in the game names a situation in motion code.
- The style is a modulation of clips, not physics: it changes how a walk looks and how fast it
  goes, it does not make a body fall on ice. Falls, knock-downs and reactions to blows stay with
  combat animation.
- Cost: one 7,800-multiply forward pass per creature at 4 Hz, cached by quantised input; measured
  0.14 ms per evaluation and 0.34 ms per frame for 40 agents in headless GDScript.
- Constants of the teacher are order-of-magnitude values; the result is judged by eye in the game.

## Alternatives considered

- **Hand-written rules per situation** (as the bird wingbeat profiles and the hit model): what the
  maintainer asked to replace; grows with every new situation.
- **Clip libraries per situation** (limp walk, cold walk, ice walk): no commercially usable mocap
  for animals; combinations (drunk on ice in a gale) explode.
- **A learned physics controller** (PPO, AMP): needs a physical rig and a muscle model in Godot;
  skeleto-nn's PPO tracker did not converge. Possible later for the hero only.
- **ONNX runtime GDExtension:** viable for larger networks later; unnecessary for 7,800 weights.
