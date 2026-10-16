# ADR 0054: The hero sits on chairs, stools and benches

**Reference:** maintainer request 2026-10-16 (session): "we also need to wire sitting at chairs and
benches in the game". Feature page: [`SITTING.md`](../SYSTEMS/SITTING.md).

## Status

**Proposed; implemented at the maintainer's request (2026-10-16), pending approval.** Additive;
reverting removes `scripts/world/city_seats.gd`, `scripts/world/seat_prompt.gd`,
`scripts/player/player_seat.gd` and their hooks.

## Context

- Residents already sit: household sit slots (`HouseholdLayout`, with seat heights), landmark-site
  people with `pose: sit`, the smithy routines. The shared rig has `Sit_Chair_Down`, `Sit_Chair_Idle`,
  `Sit_Chair_StandUp`, and catalogue seats list the `sit` action. Kalev could not sit anywhere
  ([`HOUSEHOLDS.md`](../SYSTEMS/HOUSEHOLDS.md) limits).
- Seats are data, not nodes (household slots are dictionaries; church benches are manifest
  `benches`; catalogue furniture is site dressing). An `Interactable` per seat would be thousands of
  areas for a handful that are ever near Kalev.

## Decision

1. **Seats are read from the data that places them** (`CitySeats`): household sit slots of furnished
   homes, nave benches (one seat every 0.55 m, facing the altar) and catalogue dressing whose household
   piece has a `seat_h` (bench, stool, chair). A seat with a resident sitting on it is not offered.
2. **One prompt follows the nearest free seat** (`SeatPrompt`): a single `Interactable` moved to the
   nearest free seat within 1.3 m, so the ordinary `interact` key and prompt UI work; while seated it
   offers "Stand up".
3. **Kalev sits like a resident** (`PlayerSeat`): sit down (1.2 s, `sit_down`), seated (`sit_idle`)
   until a movement key, jump or interact, stand up (1.0 s, `sit_up`) a step in front of the seat. The
   logic body stands where seated residents stand (0.44 m in front of the seat) with collision off; the
   rig is lowered by `seat height - 0.95` as `CitizenActor` does. The motion style layer keeps its
   trunk, head and arm answers (a cold, wet Kalev hugs himself on the bench) and leaves the legs alone.
4. **No consequences yet.** Sitting is presentation and pacing: no rest, no stamina, no ownership or
   trespass rules, nothing saved.

## Consequences

- Every bench, stool and chair the city already places can be sat on, with no authoring.
- Not done: seats only in the seamless city; town hall, choir stall and cog seats are geometry boxes
  without seat data; the camera does not cut household walls for a hero teleported into a room (the
  capture uses site interiors); no resting benefit; residents do not react to Kalev in their seat.
- Board: no task ID yet (no task-board tool in the implementing session); a second review is owed.
