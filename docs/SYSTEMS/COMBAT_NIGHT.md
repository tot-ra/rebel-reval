# COMBAT_NIGHT.md - Hammer combat and authored night missions

**Status:** Active design addendum (P7-005)
**Approval basis:** [ADR 0017](../adr/0017-legacy-design-reintroduction.md), [ADR 0008](../adr/0008-three-act-campaign-and-faction-scope.md)
**Inputs reconciled:** [`character/COMBAT.md`](../../character/COMBAT.md), [`docs/GAMEPLAY-NIGHT.md`](../GAMEPLAY-NIGHT.md), [`docs/SYSTEMS/MAGIC.md`](./MAGIC.md), [`docs/SYSTEMS/NATURAL.md`](./NATURAL.md), [`docs/SYSTEMS/PSYCHE.md`](./PSYCHE.md), and [`docs/reports/p5_001_act2_design.md`](../reports/p5_001_act2_design.md)
**Runtime ownership:** combat remains act-gated after the slice foundations; night mission packages are owned by **P5-004** and the dependent Act 2 rows.

This document is the reconciled design authority for the legacy combat and night-gameplay seeds. It keeps the useful player-facing verbs while rejecting the superseded tower-capture strategy loop, broad weapon-family progression, party control, and a universal balance meter.

---

## 1. Product boundary

Reval Rebel is a compact, authored action RPG about one smith. Combat and night missions must reinforce the commission → consequence → reflection loop rather than become a separate war simulator.

| Keep | Reject or defer |
|---|---|
| Kalev as the only directly controlled combatant | Party-control UI, follower commands, and army/fleet simulation |
| Small, readable hammer encounters with authored enemy states | A sprawling weapon-family loot tree or random gear grind |
| Stamina, guard, stagger, dodge, and deliberate recovery | A second combat progression economy disconnected from NATURAL and forged records |
| Compact night missions with combat and non-combat routes | One-tower-per-night missions, tower majority victory, or a tower-capture meta-game |
| Explicit faction ledger, Hope/Fear, district pressure, and psyche hooks | A `Balance of Power` or good/evil aggregate inferred from combat |
| Fixed historical milestones with steerable local cost | Rewriting attested battles as free-form strategic outcomes |

Magic is an authored extension of combat, not a replacement for it. The hammer remains the physical weapon and the forge conduit; spell and rite records resolve through the closed rules in [`MAGIC.md`](./MAGIC.md). NATURAL ranks modify derived checks only when the system is enabled, and missing NATURAL fields preserve baseline combat behaviour.

---

## 2. Player-visible combat contract

### 2.1 Core verbs

The player-facing action set is intentionally small and should be teachable in the prologue:

| Verb ID | Player action | Cost / risk | Result |
|---|---|---|---|
| `combat.attack.light` | Quick hammer strike | Low stamina; short recovery | Interrupts light enemies and builds pressure |
| `combat.attack.heavy` | Committed hammer blow | High stamina; long recovery | High guard damage; miss exposes Kalev |
| `combat.guard` | Hold hammer or shield to receive a blow | Stamina drains while held; reduced movement | Mitigates damage; timing can open a riposte |
| `combat.parry` | Release a timed guard at impact | Narrow timing window | Negates the hit and creates a brief counter window |
| `combat.dodge` | Short directional evade | Significant stamina; no attack during movement | Avoids an incoming strike; poor timing can still be caught |
| `combat.riposte` | Follow a successful parry | Brief opportunity window | Reliable counter damage; never an always-available finisher |
| `combat.recover` | Stop attacking and regain footing | Gives the enemy initiative | Restores stamina/poise pacing and prevents button-mash loops |
| `combat.forge_technique` | Use one equipped, authored forge technique | Content-defined resource/cooldown | A visible consequence of prior forging, not a generic skill tree |
| `combat.cast` | Resolve an authored spell or rite when granted | Willpower, piety, health, or suppression rules | Applies a fixed effect; failure returns a stable `magic.fail.*` code |
| `combat.flee` | Break contact through an authored exit route | Mission state may worsen | Preserves fail-forward play instead of requiring every fight to end in a kill |

The default vertical-slice loadout is the hammer plus one equipped forge technique. Other weapons may appear as enemy or quest objects, but they do not create a player-facing weapon-class tree in this design addendum.

### 2.2 Combat state and readability

Combat uses authored state, not hidden simulation depth:

- **Vitals:** health and stamina are visible or communicated through the existing readable combat presentation; exhaustion leaves Kalev vulnerable but does not silently kill him.
- **Guard / poise:** each combatant has a bounded guard state. Heavy hits and successful ripostes apply strong guard pressure. At zero guard, the target enters `combat.state.staggered` for an authored duration.
- **Recovery:** every attack has a committed recovery window. Enemy attack telegraphs, impact, stagger, and recovery are readable through animation and feedback.
- **Space:** encounters are compact rooms, streets, yards, or mission routes. Collision and navigation remain deterministic; combat must not require a free-roaming arena or seamless overworld.
- **Difficulty:** authored enemy archetypes and encounter composition carry difficulty. Do not add a global level-scaling formula or randomized affix system.

Canonical combat result IDs for content and tests:

- `combat.result.hit`
- `combat.result.blocked`
- `combat.result.parried`
- `combat.result.staggered`
- `combat.result.defeated`
- `combat.result.escaped`
- `combat.result.interrupted`

A combat beat may emit a psyche or city-pressure hook, but the runtime never infers faction standing, Hope/Fear, or psyche states from damage alone. Content explicitly lists those effects.

### 2.3 Hammer and forge identity

The hammer is both a weapon and Kalev's craft identity:

1. Basic hammer attacks are always available when the hammer is equipped.
2. A forged object or technique may change an encounter through an authored effect, such as reliable impact, hidden weakness, or a one-use opening.
3. `conduit.forge_spell` and `conduit.forge_rite` follow [`MAGIC.md`](./MAGIC.md); the conduit does not invent a new combat move.
4. Forge techniques use stable content IDs such as `technique.hammer.breaker` and `technique.hammer.ward`, with exact costs and effects owned by later content/runtime tasks.
5. A missing, broken, or withheld forged object produces a named consequence state. It does not silently change base hammer damage.

The player should understand the causal chain: a commission choice changes what Kalev carries, an encounter exposes that change, and the aftermath records who noticed it.

---

## 3. Authored night-mission contract

Night is a phase of compact, authored operations. It is not a repeatable procedural run and not a map-conquest screen. Each mission package supplies:

- one stable `mission.*` ID and phase window;
- a daytime setup or information beat when needed;
- a target, route, and at least one readable alternative route;
- combat and non-combat resolution where the template promises both;
- explicit failure or escape that advances state without a soft lock;
- ledger, Living City, district-pressure, relationship, psyche, and forged-object effects as explicit operations;
- a clean-save checkpoint before entry and a validated aftermath record on exit.

### 3.1 The four P5-004 templates

| Template ID | Player-facing goal | Combat route | Non-combat route | Typical remembered consequence |
|---|---|---|---|---|
| `mission.template.sabotage` | Damage or alter a named object or mechanism | Break through a guard cordon, then act under pressure | Bypass patrols, use a forged weakness, or manipulate a station | Object condition, patrol response, ledger event, Hope/Fear event if publicly noticed |
| `mission.template.theft` | Take a specific item or record | Steal during a short confrontation and escape | Use a key, distraction, social cover, or alternate entry | Item ownership/evidence state, suspicion, faction relationship, pursuit flag |
| `mission.template.escort` | Move a person, object, or message through danger | Protect the route and resolve interceptors | Choose safer route, bribe, hide, or distract | Arrival state, survivor/recipient state, time or resource cost, faction event |
| `mission.template.defense` | Hold a named person, place, or object until an authored condition is met | Survive waves or a named assault beat | Reinforce, misdirect, seal an entrance, or evacuate | Held/lost condition, district pressure, damage dressing, faction and city events |

The templates can share the same `EnemyCombatStateMachine`, patrol logic, dialogue, save envelope, and effect operations. They must not share a generic objective that erases their different dramatic verbs.

### 3.2 Mission flow

Every package follows this state sequence, with optional states omitted only when the package declares why:

1. `night.setup` - show the objective, known risk, loadout, and available forged clue.
2. `night.approach` - enter through a named route; stealth is patrol avoidance and authored alternate traversal, not a hidden stealth-stat simulation.
3. `night.objective` - interact with the target or escort subject.
4. `night.complication` - trigger a guard, time, route, or moral pressure authored by the package.
5. `night.resolution` - combat, non-combat, escape, or an explicit fail-forward result.
6. `night.aftermath` - write records, feedback, and the next phase destination.
7. `night.reflection_hook` - optionally set a psyche/reflection mark for the next Hingepuu visit.

Mission packages may offer a choice of allegiance or route, but they never open a join-faction menu. Offers come from the existing ledger, boundary flags, authored knowledge, and phase state.

### 3.3 Consequence operations

A mission's effect list may contain any combination below, but each effect is explicit and idempotent:

- `record_faction_event` for a named faction's standing;
- `record_living_city_event` for independent `living_city.hope` / `living_city.fear` changes;
- existing personal pressure adjustments such as `pressure.suspicion` or `pressure.solidarity`;
- relationship memory for named characters;
- forged-object condition or recall flags;
- `psyche.apply_state` or a face-integration delta;
- district props, patrols, route availability, prices, or barks;
- a validated `act_transition` or phase advancement.

No operation named `capture_tower`, `balance_of_power`, `morality`, or `npc_allegiance_sum` is valid. Historical battles and siege phases advance through authored missions and calendar gates, not tower ownership.

---

## 4. Act and phase hooks

### 4.1 Vertical slice and Act 1

The slice proves the smallest complete loop before Act 2 breadth:

- `P2-009` owns a night consequence with combat and non-combat routes. It should use the core verbs and one forged-object consequence, not a full four-template framework.
- `P2-012` owns end-to-end branch reachability. Its night branches must preserve combat/non-combat outcomes, aftermath state, and reflection entry without requiring magic, NATURAL, Living City, or party control.
- `P2-017` owns supported keyboard/mouse and gamepad completion. All core verbs must have an input path that works without debug-only shortcuts.
- `P4-021` may reuse the templates for Act 1 faction lines only after its content packages define their own target, route, and remembered ledger consequence.

### 4.2 Act 2

`P5-004` implements the four content-defined templates and their generated traversal tests. `P5-006` composes them into the investment, sortie/supply, and assault phases defined by [P5-001](../reports/p5_001_act2_design.md). `P5-007` and `P5-009` preserve attested local outcomes and allow the player to steer survivor, casualty, knowledge, and faction states without changing the historical milestone itself.

Act 2 combat hosts reuse the enemy state machine and P5-008 archetypes. Mission allies are scripted support: they can open a route, carry a message, hold a position, or react to a trigger, but the player cannot issue party commands or allocate ally builds.

### 4.3 Magic, NATURAL, and psyche

- `P7-010` owns cast validation, resource spend, grants/revokes, and failure codes. Combat packages reference authored spells/rites; they do not define an alternate spell system.
- `P7-011` owns NATURAL-derived combat formulas and psyche save/runtime behaviour. The baseline works with the system disabled or absent from a save.
- `P7-012` owns Living City event runtime. Night missions may author Hope/Fear events, but the ledger and meters remain separate.
- A combat or night mission can set a psyche state only through an authored hook. Damage, kills, or mission count do not automatically create a state.

---

## 5. Handoff and acceptance matrix

| Owner | Required follow-up | Definition of ready |
|---|---|---|
| Dev / `P2-009` | Keep one compact night combat/non-combat proof | Core verbs, escape/fail-forward, forged consequence, and clean aftermath are testable |
| Dev / `P5-004` | Implement four template contracts | Each template has stable IDs, route alternatives, effect list, save boundary, and generated traversal coverage |
| Quest / `P5-004` and `P5-006` | Author mission packages for siege phases | Packages use existing schemas and name ledger/pressure/relationship outputs explicitly |
| Character / `P5-008` | Supply enemy and scripted-ally briefs | Enemy roles have readable telegraphs and allies have authored support triggers, never party commands |
| QA / dependent gates | Verify player path and failure paths | Combat/non-combat routes, input parity, save/reload, no tower or morality aggregate, and no `GameState` drift when optional systems are disabled |
| Canon | Review only historical claims | Attested events and confidence labels remain intact; invented mission framing is marked as such |

Acceptance rejects a delivery when it introduces any of the following: tower ownership as a win condition, a second global meter, party command controls, procedural night objectives, random loot progression, or a requirement that the slice enable magic/NATURAL/Living City to remain playable.

---

## 6. Stable content hooks

These IDs are design-level names for later schema/runtime work; this document does not add runtime dictionaries:

| Kind | Forms / examples |
|---|---|
| Combat verb | `combat.attack.light`, `combat.attack.heavy`, `combat.guard`, `combat.parry`, `combat.dodge`, `combat.riposte`, `combat.recover`, `combat.flee` |
| Combat result | `combat.result.hit`, `combat.result.parried`, `combat.result.staggered`, `combat.result.defeated`, `combat.result.escaped` |
| Mission template | `mission.template.sabotage`, `.theft`, `.escort`, `.defense` |
| Mission state | `night.setup`, `night.approach`, `night.objective`, `night.complication`, `night.resolution`, `night.aftermath` |
| Mission effect | `mission.set_object_condition`, `mission.set_route_state`, `mission.set_survivor_state`, `mission.write_aftermath` |
| Forge technique | `technique.hammer.<slug>`; exact records are authored by the owning content/runtime row |
| Mission package | `mission.act2.night.<template>` plus a unique quest/package ID |

These hooks are closed vocabulary. Unknown combat verbs, mission templates, or effect operations must fail validation rather than becoming permissive runtime behaviour.

---

## 7. Verification checklist

- [x] Legacy combat seeds are reconciled into a small hammer-first action set.
- [x] Player-visible verbs include attack, guard, dodge, parry/riposte, recovery, forge technique, cast, and flee.
- [x] Four P5-004 night templates have distinct goals, combat/non-combat routes, and remembered consequences.
- [x] P2/P4/P5 follow-ups identify the rows that must change or consume this contract.
- [x] Party control, tower-capture, Balance of Power, procedural missions, and broad weapon-family loot remain explicitly out.
- [x] Magic, NATURAL, psyche, faction ledger, and Living City coupling is explicit and fail-closed.
- [ ] Runtime implementation and content-package acceptance remain owned by the named follow-up rows; this document does not claim those rows complete.

## 8. Sources and confidence

Combat verbs and system boundaries are **invented gameplay design**. Historical weapons, fortifications, uprising dates, and siege milestones remain governed by `docs/CANON.md` and the relevant research dossiers. The night mission framework is authored campaign structure around attested events, not a claim that the exact playable operations occurred historically.
