# P5-001 Act 2 Design: The Fire of Rebellion

**Status:** delivered for Canon Keeper review  
**Dependencies:** P4-013 closed (Act 1 package accepted)  
**Authority:** [ADR 0008](../adr/0008-three-act-campaign-and-faction-scope.md), [README](../../README.md) Act table, `content/packages/st_georges_night/`  
**Machine table:** [`docs/data/act2_design_manifest.json`](../data/act2_design_manifest.json)

## Player-facing goal

After St. George's Night at Viru Gate, the player continues as Kalev into the April-May 1343 siege: night missions, world travel to Harju sites, authored field battles, forged-object recall, and a Paide finale that writes the Act 3 opening state. Attested milestones stay on the calendar; the player steers local cost, survivors, and faction standing.

## 1. Uprising-night opening (act-boundary)

Act 1 closes through `quest.st_georges_night` with exactly one boundary family:

| Boundary flag | Family | Immediate Act 2 posture |
|---|---|---|
| `flag.act_boundary.viru_seal` | Seal | City holds the eastern gate with Henning; rebels press the walls from outside; Kalev starts under watch scrutiny inside All-linn |
| `flag.act_boundary.viru_break` | Break | Fractured chain / failed defence; rebel foothold on the Viru apron; watch morale drops; Kalev may be blamed or recruited |
| `flag.act_boundary.viru_open` | Open | Concealed release used; rebels enter through Viru; Danish/Hanseatic panic; Kalev is marked as a collaborator or liberator depending on prior ledger |

Shared opening beat (all families):

1. Dawn after 23 April records `flag.act_transition.act1_recorded`.
2. Short forge/home staging on `kalev_smithy` / `lower_town_slice` shows the night's consequence (patrol barks, damaged or held gate dressing, Mart/Aita/Kaja availability from Act 1 state).
3. First Act 2 travel prompt unlocks world destinations required by the siege phase (see P5-002).
4. No second Open/Seal/Break choice - the boundary is fixed input to Act 2 systems.

Confidence: Viru Gate climax families are **`invented`** act-boundary framing on an **`attested`** uprising night ([`docs/CANON.md`](../CANON.md)).

## 2. Three-phase siege structure

Calendar spine (attested dates stay fixed; interior mission timing is authored within the phase windows):

| Phase id | Window | Attested / framing | Player loop |
|---|---|---|---|
| `siege.investment` | Late April - ~8 May | Rebels invest Reval; Swedish aid sought; city appeals to the Order (**`attested`** siege) | Night missions (P5-004), district pressure, supply intercepts, forged-object probes (P5-005) |
| `siege.sortie_supply` | ~9-13 May | Order approaches; Kanavere Bog 11 May (**`attested`**) | Sortie/supply missions (P5-006), travel to Harju camp / bog (P5-002/P5-003), Kanavere mission (P5-007) |
| `siege.assault` | 14-16 May | Sõjamäe 14 May (**`attested`**); Order leverage on Toompea rises toward 16 May handover (**`attested`** context) | Assault/defence missions (P5-006), Sõjamäe mission (P5-007), Paide finale (P5-009), Act 3 handoff |

Allegiance is not a join-faction menu. Rebel-aligned vs ruler-aligned mission *offers* come from ledger standing and the Viru boundary family. Both paths still hit attested milestones on schedule (ADR 0008).

### Phase exit gates

- Investment → sortie/supply: at least one night-mission template completed **or** one supply-chain intercept resolved; calendar may force advance if the player stalls (attested dates win).
- Sortie/supply → assault: Kanavere beat resolved (survivor/casualty ledger written).
- Assault → Act 3 opening: Paide finale writes validated act-transition records (P5-009).

## 3. Mission list

Every mission maps to a TODO row and/or shipped system. IDs are stable design keys for later content packages.

| Mission id | Title | Phase | TODO / system | Routes | Notes |
|---|---|---|---|---|---|
| `mission.act2.opening_aftermath` | Dawn after Viru | Opening | P5-001 (this design); uses Act 1 `st_georges_night` flags | story | Boundary-specific staging only |
| `mission.act2.night.sabotage` | Night sabotage template | investment | P5-004 | combat + non-combat | Content package; ledger events |
| `mission.act2.night.theft` | Night theft template | investment | P5-004 | combat + non-combat | Content package; ledger events |
| `mission.act2.night.escort` | Night escort template | investment | P5-004 | combat + non-combat | Content package; ledger events |
| `mission.act2.night.defense` | Night defence template | investment | P5-004 | combat + non-combat | Content package; ledger events |
| `mission.act2.recall.spearhead` | Recalled spearhead | investment / sortie | P5-005; forge records | encounter matrix | Act 1 forged record resurfaces |
| `mission.act2.recall.gate_chain` | Recalled gate chain | investment / assault | P5-005; `bell_and_chain` | encounter matrix | Seal/Break/Open bias echoes |
| `mission.act2.recall.brew_work` | Recalled brewery iron | investment | P5-005; bitter-brew / Act 1 forge | encounter matrix | Honest vs defect vs secret |
| `mission.act2.siege.investment_rebel` | Rebel investment beat | investment | P5-006 | rebel-aligned | Wall pressure / courier |
| `mission.act2.siege.investment_ruler` | Ruler investment beat | investment | P5-006 | ruler-aligned | Watch/Hanseatic hold |
| `mission.act2.siege.sortie_rebel` | Rebel sortie / supply | sortie_supply | P5-006 | rebel-aligned | Supply run to camp |
| `mission.act2.siege.sortie_ruler` | Ruler sortie / supply | sortie_supply | P5-006 | ruler-aligned | Sortie or convoy guard |
| `mission.act2.siege.assault_rebel` | Rebel assault beat | assault | P5-006 | rebel-aligned | Pre-Sõjamäe pressure |
| `mission.act2.siege.assault_ruler` | Ruler assault beat | assault | P5-006 | ruler-aligned | Wall defence / Order liaison |
| `mission.act2.kanavere` | Battle of Kanavere Bog | sortie_supply | P5-007; P5-008 archetypes | steerable cost | Attested rebel win; survivor states differ |
| `mission.act2.sojamae` | Battle of Sõjamäe | assault | P5-007; P5-008 | steerable cost | Attested rebel defeat; casualties differ |
| `mission.act2.paide` | Four Kings at Paide | assault close | P5-009; lore P5-013/P5-014 | knowledge branches | Attested killings; player warning states |
| `mission.act2.travel.harju_camp` | Travel: rebel kings' camp | sortie_supply | P5-002, P5-003 | travel events | World activation wave 1 |
| `mission.act2.travel.harju_village` | Travel: Harju village | investment / sortie | P5-002, P5-003 | travel events | Rural staging |
| `mission.act2.travel.sacred_grove` | Travel: sacred grove | investment | P5-002, P5-003; Cult of Metsik | travel events | Folklore-labelled beats only |

Combat hosts reuse `EnemyCombatStateMachine` and P5-008 knight/crossbowman archetypes. Mission allies use scripted support without party-control UI (P5-008).

## 4. Faction war-state table

Standing remains event-sourced via `FactionLedger` (`danish_crown`, `livonian_order`, `hanseatic`, `harju_kings`, `black_cloaks`, `cult_metsik`, `pskov_novgorod`, `vitalienbruder`). Act 2 adds a **war-state** overlay used for mission offers and travel pressure - not a second morality meter.

| Faction id | Investment default | After Kanavere | After Sõjamäe | After Paide | Boundary modifiers |
|---|---|---|---|---|---|
| `danish_crown` | Defending Toompea / walls | Appeals harder to Order | Relieved if Order wins field | Castle handover leverage rises (16 May context) | Seal: stronger inside city; Open: legitimacy crisis; Break: scramble |
| `livonian_order` | Approaching from east/south ops | Stung by bog loss; accelerates | Field supremacy | Paide treachery complete; Toompea entry path | Seal: invited as saviour; Open/Break: enters as enforcer |
| `hanseatic` | Protect trade / stores | Panic buying / gate politics | Demands Order protection | Accepts Order military fact | Seal: cooperates with watch; Open: bargains with whoever holds streets |
| `harju_kings` | Siege investment | Morale up after bog | Broken field army | Kings dead; remnant leadership | Open: deeper city foothold; Seal: stuck outside; Break: mixed apron control |
| `black_cloaks` | Night networks | Smuggling / intelligence | Survival first | Records who warned whom | Favours non-combat night routes |
| `cult_metsik` | Grove rites / omens | Reads bog as omen | Interprets defeat spiritually | Martyr symbols from Paide | Folklore/`invented` only; never attested doctrine |
| `pskov_novgorod` | Distant feelers | May promise pressure | Withdraws when Harju falls | Cold interest only | Optional travel colour; no army-sim |
| `vitalienbruder` | Coastal rumour | Opportunistic | Avoids Order main force | Absent | Background until later ADR expands |

War-state keys for content (string constants for later systems): `war.siege_phase`, `war.viru_boundary`, `war.order_field_strength`, `war.rebel_field_strength`, `war.kings_alive`.

## 5. Canon timeline decisions

See [`docs/CANON.md`](../CANON.md) Timeline section. Summary:

| Event | Date | Label | Playable mapping |
|---|---|---|---|
| St. George's Night / Viru boundary | 23 Apr 1343 | attested night + invented gate families | Opening |
| Siege of Reval | Late Apr-May 1343 | attested | Phases investment-assault |
| Paide Four Kings killing | Early-mid May 1343 (chronicle tradition) | attested event; exact day vs field battles remains contested in sources | `mission.act2.paide` as Act 2 dramatic close per ADR 0008 |
| Battle of Kanavere Bog | 11 May 1343 | attested | `mission.act2.kanavere` |
| Battle of Sõjamäe | 14 May 1343 | attested | `mission.act2.sojamae` |
| Swedish fleet offshore | 18-19 May 1343 | attested | Post-finale colour / Act 3 seed (too late to save mainland) |
| Order entry / castle leverage | 16 May 1343 context | attested political shift | Act 2→3 bridge; Toompea Order presence |

**Dramaturgy note:** Some chronicle reconstructions place the Paide treachery before the 11-14 May field battles. ADR 0008 and the existing P5 dependency order (P5-007 then P5-009) keep Paide as the Act 2 finale so the player can carry Kanavere/Sõjamäe survivor and knowledge states into the truce. The killings remain **`attested`**; the playable sequencing relative to the bog and Sõjamäe is **`invented`** campaign framing and must not be presented as a settled primary-source day order.

## 6. Non-goals

- No army or fleet battle simulation; battles are authored missions with steerable local cost.
- No seamless overworld; travel is gated (P5-002).
- No party-control UI; allies stay scripted (P5-008).
- No tower-capture loop; no other-city campaigns.
- No plague epilogue (non-canon).
- Do not invent a municipal wheel tax or Order-cross April baseline on Toompea.

## 7. Verification checklist

- [x] Every mission id in the manifest maps to a TODO id or shipped system name.
- [x] Every named historical event in this design carries a confidence label.
- [x] Viru boundary flags match `content/packages/st_georges_night/`.
- [x] Faction ids match `FactionLedger.ACTIVE_FACTIONS`.
- [ ] Canon Keeper accepts CANON timeline additions (`review: canon`).

## 8. Follow-ups

1. **P0-174** - regenerate active Markdown report after ROADMAP Current focus tick.
2. Producer opens Current focus `act2-fire-of-rebellion` with claimable **P5-002** / **P5-004**.
3. Optional Producer request: if Canon insists on historical Paide-before-Kanavere day order, retarget P5-009 deps without changing attested outcomes.
