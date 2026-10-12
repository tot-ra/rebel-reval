# ADR 0048: Psychological spells, trust endings and a willpower cost for the spirit world

**Reference:** design commit 578f6ea09 (maintainer discussion 2026-10-13), plan in
[SPIRIT_DIALOGUE.md](../SYSTEMS/SPIRIT_DIALOGUE.md#psychological-spells-and-willpower-planned).
Tasks **R-1913..R-1917** (SPL-1..SPL-5) and **R-1918** (TALK-8). Order: SPL-1 -> SPL-2 -> SPL-3,
SPL-4, SPL-5; TALK-8 after SPL-2 and TALK-5 (R-1889, shipped in 228783e3).

**Amends:** [ADR 0041](0041-spirit-sight-auras-and-soul-lights.md) (accepted), the spirit-sight
"Toggle" bullet ("Free, no timer, no resource"), and extends the word-spell design of
[ADR 0038](0038-realtime-3d-spirit-arena-and-topic-spells.md) (still Proposed) item 4 ("A spell is
one emotional strike"). Everything else in 0033, 0038 and 0041 stays.

## Status

**Proposed (2026-10-13).** Needs maintainer approval before R-1914 (SPL-2) and R-1915 (SPL-3) are
coded. R-1913 (catalogue data only) does not change behaviour and may start before approval.

## Context

- Word spells can only lower a light, so the only way to win a duel is to break the other person.
- Spirit sight is free and has no timer (ADR 0041), and since ADR 0047 any resident can be duelled
  from sight. Duelling everyone costs nothing and changes nothing.
- The game already has one spirit-facing resource, willpower (`resource.willpower`, the HUD mana
  orb), spent by elemental magic and word spells.

This is a new rule on existing systems (no new resource, area or pillar), so it is not a scope
change that needs equivalent-cost scope removal. It does reverse an explicit sentence of the
accepted ADR 0041, which needs an ADR of its own.

## Decision

1. **Spells are social moves** with a signed light vector over one or two `aspect.*` lights.
   Lowering a light deals pressure (as today), raising one builds trust (new 0..100 meter). A duel
   ends `resolved_broken` (pressure 0), `resolved_eased` (trust 100) or `resolved_left` (hold Esc).
   Shifts are copies that live only for the duel.
2. **Spirit sight and duels cost willpower** from the one existing pool: -1 per 12 s with sight
   open, -1 per 6 s in a duel, plus free-cast costs. At 0 sight closes for 30 s; in a duel each
   drain tick costs composure instead. Recovery only with sight closed (time, sleep, prayer, the
   anvil, an eased duel). Maximum 6 + floor(`aspect.light` rank / 2).
3. **Stranger duels leave consequences** (TALK-8): per-resident memory, guilt circumstance
   `act.spirit_intrusion` for breaking, capped Living City Hope/Fear.
4. All numbers are prototype values, tuned after the first playtest.

## Alternatives

- **Separate focus pool for the spirit world.** Rejected (decision 3 below): a second bar for the
  same kind of effort; one orb, one rule.
- **Lasting light shifts on the resident.** Rejected for now (decision 1): the memory record
  carries the consequence without a per-resident light save.
- **Keep sight free and cost only duels.** Rejected: the hero could read every aura in the city
  without any trade-off, and sight would never close on its own.
- **Cooldown on duels instead of a resource.** Rejected: a timer is not a choice; willpower makes
  the hero weigh sight against magic.

## Consequences

- ADR 0041 "Free, no timer, no resource" no longer holds once R-1915 lands; SPIRIT_SIGHT.md gets
  the cost line in that task.
- The five starter words keep their exact numbers; existing tests stay green.
- Save gains known spells, loadout (R-1916) and per-resident duel memory (R-1918); the willpower
  pool is already saved.

## Decisions recorded

Questions to the maintainer (2026-10-13) went unanswered (two prompts timed out). The design
defaults are adopted as **provisional** decisions; approving this ADR confirms them.

1. Lasting per-resident light shifts: **no**, shifts last only for the duel.
2. Hero soul-light growth from duels: **no** until NATURAL point balance (P7-011) is in.
3. Separate focus pool: **no**, one shared willpower pool.
4. Numbers: **prototype values** for the first playtest.
