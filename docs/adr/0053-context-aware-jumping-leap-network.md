# ADR 0053: Context-aware jumping chosen by a small network

**Reference:** maintainer request 2026-10-16 (session): "we need jumping in the game - it needs to be
tied to this NN to also understand the context. are we jumping above some wall or are we jumping
off the cliff into the water, or are we jumping onto some surface above" (with a screenshot of
Kalev at a churchyard wall). Builds on [ADR 0051](0051-condition-adaptive-motion-style-network.md)
(the motion style network and its situation channels). Feature page:
[`LEAPING.md`](../SYSTEMS/LEAPING.md).

## Status

**Proposed; implemented at the maintainer's request (2026-10-16), pending approval.**
Supersedes the jump part of [ADR 0036](0036-jump-vault-and-expanded-melee-verbs.md) (decisions 1 to 4:
a fixed scripted hop over obstacles tagged `vaultable`); its expanded strikes (decision 6) are not
affected. Reverting this ADR returns the city to the fixed hop (`PlayerJumpState`), which is still
the jump on maps without ground heights.

## Context

- The hero had one jump: a fixed 0.85-unit hop (`PlayerJumpState`) that clears steep strips on
  the logic plane. Walls and houses block it; it plays no jump clip; it does not know whether it is
  in front of a waist-high churchyard wall, a quay over the harbour or a 6 m drop onto stone.
- ADR 0036 proposed a scripted vault over obstacles that a map author tags as `vaultable`. That is
  one more hand-written case per kind of obstacle, and it cannot say anything about a drop, a ledge,
  water below, ice underfoot or a sprained ankle.
- The motion style network (ADR 0051) already turns the situation into physical channels (ground
  friction, pain per limb, blood loss, fatigue, load, darkness, wetness, temperature). The same
  channels decide whether and how a jump can be made.
- The city knows the walk height everywhere (`CityPlan.walk_height`), the water surface
  (`CityWorld3D.water_surface_at`), and the heights of authored site walls (their `y1`); the logic
  collision did not carry the heights.

## Decision

1. **One small network decides the jump** (skeleto-nn `adapt/leap.py`, weights
   `assets/motion/leap_net.json`). It sees what lies ahead as a profile: every quarter leg length
   for five leg lengths, the height of whatever is solid there relative to the feet and the depth of
   water on it. One MLP is evaluated for every sample as a landing place, with the body, the ADR 0051
   channels and ten geometric numbers about that place; it returns a score against staying put and a
   jump program (take-off step, arc height, hands on the obstacle, tucked legs, landing give, a roll,
   lowering oneself from an edge first, arms out, trunk lean). The best place wins, or the hero
   stays. Hop, vault, pull-up, jumping down, a jump into the water and a refusal are outcomes, not
   cases in code.
2. **Trained on consequences, not on clips.** As in ADR 0051, the network is trained by gradient
   descent through a differentiable model of what would follow: can the legs (and arms) power the
   arc, does the body clear what lies between, does the take-off slip, the force of the landing
   (drop height over the stroke the knees, a roll or the water give), slipping or running off a
   narrow top, cold water and deep water with a load or a useless arm, effort, time and ground
   gained. It reaches 91 % of a per-case optimisation and the same jump-or-stay decision in 95 % of
   held-out cases; training takes about 12 minutes on a CPU.
3. **The world gives heights.** `CityCollisionBuilder` tags each site wall's collision polygon with
   the world height of its top (`top_y`, from the fabric `y1`); `MotionLeapProbe` reads walk height
   and water from the city and wall tops from the collision; any other solid counts as tall
   (12 m), and nothing inside a solid is a landing place.
4. **Logic stays on the plane.** `PlayerLeap` plays the decision: a step to the take-off point,
   a crouch (or lowering on the hands), a ballistic flight, a landing. Collision is off while the
   body is in the air (the probe proved the way clear and the landing free); landing in a steep
   strip uses the existing slide; landing in water hands over to swimming. Height stays
   presentation, as before (`Player.jump_height()`).
5. **Presentation.** The shared rig plays the unused `Jump_Start`, `Jump_Idle`, `Jump_Land` clips
   (and `roll_forward` for a landing roll); `LeapPoseModifier` adds the network's pose: crouch,
   tucked legs, both hands on the wall top (two-bone reach) with the body diving over it, landing
   give, arms out, and the lean back of a refusal.
6. **Cost.** Stamina 0.6 to 1.2 times the old hop's 8, by flight time; spent stamina weakens the
   legs like fatigue. Deterministic: no randomness, a jump the network chose always lands.

## Alternatives considered

- **ADR 0036's scripted vault with `vaultable` tags.** Rejected: one authored case per obstacle
  kind, no drops, ledges or water, no reaction to the hero's state.
- **One flat network over the whole profile** (tried first). It learned 30 to 60 % of the possible
  gain and mostly refused; scoring each landing place with a shared network is what generalises.
- **Physics (MuJoCo) jumps.** Rejected for the game: skeleto-nn's physical controllers do not yet
  land well, and the logic plane is 2D.

## Consequences

- The jump key does something different in front of every kind of edge, and the same wall can be a
  vault on a dry day and a refusal on ice or with a sprained ankle. Players may be refused where they
  expected a hop; the balk pose shows it was a decision.
- New obstacles need no code: a wall with a known top, a deck or a bank is read from data. New
  situations reach the jump through ADR 0051's channels with no retraining; a new physical effect is
  a channel and a cost term in skeleto-nn and a retrain.
- Not done: citizens and animals do not jump yet (the network covers quadrupeds; a dog over a fence
  is a golden case); there is no fall damage (a chosen jump never fails); walls authored only as
  `walk.walls` (no fabric) and buildings count as tall; the hang-drop (lowering oneself from an edge)
  is in the network but did not win on any city edge tested.
- Board: no task ID yet (no task-board tool in the implementing session); a second review is owed.
