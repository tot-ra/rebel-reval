# P7-009 Cast and Faction Promotion Plan

**Status:** Delivered planning artifact (pending Canon Keeper `review: canon` on first briefs)  
**Source:** [`characters/`](../characters/), [`characters/README.md`](../characters/README.md)  
**Active home for promoted cast:** [`docs/CHARACTERS/`](./CHARACTERS/)  
**Evaluated against:** ADR 0008 eight launch factions, ADR 0016/0017 fidelity and art rules, [`docs/CANON.md`](./CANON.md), [`docs/quest_seed_shortlist.md`](./quest_seed_shortlist.md)

---

## Art rule (binding)

Legacy portraits, pixel GIFs, and sheet art under `characters/**` are **inspiration only**. Production models use the shared rig and fidelity tiers (ADR 0007 / 0016). Do not ship legacy 2D sheets as runtime characters.

| Tier | Use for promote-first cast |
|---:|---|
| **0 Hero** | Reserved for the seven slice-core briefs already in `docs/CHARACTERS/` (Kalev + Mart, Aita, Kaja, Henning, Jürgen, Ellen). New promotions do **not** enter Tier 0 without a separate art/ADR decision. |
| **1 Named NPC** | Default for promote-first quest and faction faces. |
| **2 Crowd/battle** | Ambient townsfolk, siege ranks, unnamed Harju fighters - no individual brief required. |

---

## Eight launch factions (unchanged ledger set)

These keep shipped `faction.*` ledger IDs. Promotion of NPCs into these factions does **not** create a ninth launch faction.

| Faction | Ledger ID (shipped / planned) | Notes |
|---|---|---|
| Danish Crown | `faction.danish_crown` | Toompea authority through spring 1343; weakens after Order leverage. |
| Livonian Order | `faction.livonian_order` | Primary military pressure; Act 2/3 handlers. |
| Hanseatic guilds | `faction.hanseatic_guilds` | Trade, grain, amber; Jürgen Witte is the active brief. |
| Harju Kings | `faction.harju_kings` | Rural uprising leadership; Act 2 face. |
| Black Cloaks | `faction.black_cloaks` | Urban cell inside Reval walls. |
| Cult of Metsik | `faction.cult_of_metsik` | Folklore/old-ways pressure; Ellen is the active brief. |
| Pskov / Novgorod emissaries | `faction.pskov_novgorod` | Combined launch seat; distinguish Pskov vs Novgorod in dialogue, not as two launch ledgers yet. |
| Vitalienbrüder | `faction.vitalienbruder` | Harbour raiders / hireable chaos; no fleet sim. |

---

## Faction candidates beyond the eight (evaluate / gate)

| Candidate | Decision | Act gate | Ledger? | Notes |
|---|---|---|---|---|
| Brotherhood of Blackheads | **promote-candidate** | A1–A2 | **Candidate ledger seat** (`faction.blackheads` via P4-045; events/IDs only, not a ninth launch faction) | Unmarried merchants / foreigners; city-republic ambition. First faces: Johann von Minden, Hinrik the Cartographer, Mart Weaver (`char.mart_weaver` - **not** apprentice Mart). Wiring: `docs/data/faction_blackheads_candidate.json`. |
| Bishopric of Ösel-Wiek | **promote-candidate** | A3 | Later | Saaremaa / Haapsalu sovereignty vs Order. Face: Hermann II Osenbrügge. |
| Bishopric of Dorpat | **adapt-candidate** | A2 colour | No full ledger in A1/A2 | Otepää / Pskov colour; Meelis of Otepää as local contact. Do not open Dorpat as a playable city. |
| Archbishopric of Riga | **defer** | post-campaign | No | Other-city campaign exclusion (ADR 0008). Mention-only diplomacy. |
| Lizard Union | **defer-as-ninth-faction**; **promote as intrigue cell** | A2–A3 | No ninth launch ledger | Matches CANON P7-008 defer. Ship as clandestine Prussian/Baltic noble cell using existing Order/Hanseatic ledger pressure plus invented cell flags. Face: Nikolaus von Danzig. Requires a later ADR before any ninth launch faction. |
| Grand Duchy of Lithuania | **mention-only** | A2–A3 | No | Remote context; Algirdas stays off-stage. |
| Golden Horde | **mention-only** | A3 | No | Distant overlords; Jani Beg stays off-stage. |
| Split Pskov vs Novgorod ledgers | **defer** | after A2 emissary line ships | Keep combined | Distinguish voices in content; do not fork ledger IDs until P5 faction lines need it. |

---

## Legend

| Label | Meaning |
|---|---|
| **promote-first** | Write / keep a `docs/CHARACTERS/` brief before quest content treats the NPC as active cast. |
| **adapt** | Legacy sheet usable after rename, confidence, or Kalev-collision fixes. |
| **merge** | Do not create a second brief; fold hooks into an existing active brief. |
| **defer** | Keep under `characters/` until a later act wave. |
| **reject** | Do not promote (anachronism, other-city, or conflicts with kalev-family / canon). |

Act tags: **A1** Act 1, **A2** Act 2, **A3** Act 3.

---

## Promote-first NPC shortlist (18)

Priority is production order inside each act wave. Content IDs are stubs for later packages.

### Wave A - Act 1 / Lower Town density (after slice core)

| # | NPC | Legacy seed | Label | Act | Art tier | Faction seat | Content-ID stub | Notes |
|---|---|---|---|---|---|---|---|---|
| 1 | Old Toomas | `characters/forge_folk/old_toomas/` | **promote-first** | A1 | 1 | Black Cloaks (support) | `char.old_toomas` | Quiet forge mentor; first brief landed. |
| 2 | Martin of the Cloaks | `characters/rebels/martin_the_blacksmith.md` | **adapt** | A1 | 1 | Black Cloaks | `char.martin_cloaks` | Must **not** replace Kalev as smith. Younger urban cell smith-contact. First brief landed. |
| 3 | Viceroy Konrad Preen | `characters/denmark/viceroy_konrad_preen.md` | **promote-first** | A1–A2 | 1 | Danish Crown | `char.konrad_preen` | Fading Danish authority on Toompea. First brief landed. |
| 4 | Brother Hermann | `story/STORY.md` Order handler | **adapt** | A1–A3 | 1 | Livonian Order | `char.brother_hermann` | CANON P7-008 adapt; name may shift in P6-001. Forced-forge Act 3 face. |
| 5 | Johann von Minden | `characters/blackhead/johann_von_minden.md` | **promote-first** | A1–A2 | 1 | Blackheads candidate | `char.johann_von_minden` | Merchant-republic ambition; no toll-booth invention. |
| 6 | Hinrik the Cartographer | `characters/blackhead/hinrik_the_cartographer.md` | **promote-first** | A1 | 1 | Blackheads candidate | `char.hinrik_cartographer` | Maps, harbour intelligence, cart corridors. |
| 7 | Mart Weaver | `characters/blackhead/mart_the_weaver.md` | **adapt** | A1 | 1 | Blackheads candidate | `char.mart_weaver` | Rename away from apprentice Mart in all player-facing copy. |
| 8 | Order Squire (Henning's detail) | `characters/order/squire.md` | **adapt** | A1 | 1 | Livonian Order | `char.order_squire` | Street-level Order pressure under Henning / Hermann; give a stable personal name when the brief lands. |

### Wave B - Act 2 uprising and siege

| # | NPC | Legacy seed | Label | Act | Art tier | Faction seat | Content-ID stub | Notes |
|---|---|---|---|---|---|---|---|---|
| 9 | Lembit Helme | `characters/rebels/lembit_helme.md` | **promote-first** | A2 | 1 | Harju Kings | `char.lembit_helme` | Elder king / spokesman. First brief landed. |
| 10 | Jüri Ratnik | `characters/rebels/juri_ratnik.md` | **promote-first** | A2 | 1 | Harju Kings | `char.juri_ratnik` | Field captain archetype. |
| 11 | Urmas Laar | `characters/rebels/urmas_laar.md` | **promote-first** | A2 | 1 | Harju Kings | `char.urmas_laar` | Village muster / grievance face. |
| 12 | Master Burchard von Dreileben | `characters/order/master_burchard_von_dreileben.md` | **adapt** | A2–A3 | 1 | Livonian Order | `char.burchard_dreileben` | Historical Master; keep confidence labelled; player meets via envoys more than constant presence. |
| 13 | Brother Goswin von Herike | `characters/order/brother_goswin_von_herike.md` | **promote-first** | A2 | 1 | Livonian Order | `char.goswin_herike` | Field commander under Burchard. |
| 14 | Mikhail Kolovrat | `characters/pskov/mihail_kolovrat.md` | **promote-first** | A2 | 1 | Pskov/Novgorod | `char.mikhail_kolovrat` | Pskov scout/emissary; fits quest seeds 11–12. |
| 15 | Jana Podajalnaja | `characters/novgorod/jana_podajalnaja.md` | **promote-first** | A2 | 1 | Pskov/Novgorod | `char.jana_podajalnaja` | Novgorod trade/intel voice inside combined seat. |
| 16 | "Ironhand" Störtebeker | `characters/pirates/ironhand_stortebeker.md` | **adapt** | A2 | 1 | Vitalienbrüder | `char.ironhand` | Hireable harbour chaos; no naval battle sim. Legendary name stays `invented`/`plausible composite` unless research upgrades it. |
| 17 | Nikolaus von Danzig | `characters/lizard_union/nikolaus_von_danzig.md` | **promote-first** (cell only) | A2–A3 | 1 | Lizard intrigue cell | `char.nikolaus_danzig` | Not a ninth launch faction face until ADR. |

### Wave C - Act 3 island / occupation

| # | NPC | Legacy seed | Label | Act | Art tier | Faction seat | Content-ID stub | Notes |
|---|---|---|---|---|---|---|---|---|
| 18 | Hermann II Osenbrügge | `characters/bishopric_osel_wiek/hermann_osenbrugge.md` | **promote-first** | A3 | 1 | Ösel-Wiek candidate | `char.hermann_osenbrugge` | Saaremaa sovereignty vs Order; P6 island arc. |

**Verify count:** 18 promote-first / adapt rows (≥15 required), plus 7 faction candidates beyond the eight launch factions (Blackheads, Ösel-Wiek, Dorpat, Riga-defer, Lizard-cell, Lithuania, Golden Horde).

---

## Merge / defer / reject (non-promote-first)

| Seed | Decision | Reason |
|---|---|---|
| Jürgen von League (`characters/hansa/`) | **merge** | Active brief is [`jurgen.md`](./CHARACTERS/jurgen.md) (Jürgen Witte). Fold amber-merchant hooks there; do not duplicate. |
| Kaja Lahekivi (`characters/rebels/`) | **merge** | Active brief is [`kaja.md`](./CHARACTERS/kaja.md). Rural surname may appear as alias in dialogue, not a second cast ID. |
| Ellen Luik (`characters/metsik_cult/`) | **merge** | Active brief is [`ellen.md`](./CHARACTERS/ellen.md). |
| Famous off-stage roster (Algirdas, Jani Beg, Petrarch, …) | **defer** / mention | CANON historical-figures rules; no playable agency. |
| Workers-quarter ambient sheets (`characters/workers_quarter/**`) | **defer** as Tier 2 | Crowd variants; promote individuals only when a quest names them. |
| Hostage wife/daughter grove cast | **reject** | Conflicts with [`kalev-family.md`](./CHARACTERS/kalev-family.md). |
| Sergius of Radonezh / anachronistic saints as quest givers | **reject** or heavy **adapt** | Keep out of 1343 Reval agency unless research upgrades with confidence labels. |

---

## First briefs landed (this delivery)

| Brief | Path | Wave |
|---|---|---|
| Old Toomas | [`docs/CHARACTERS/old_toomas.md`](./CHARACTERS/old_toomas.md) | A |
| Martin of the Cloaks | [`docs/CHARACTERS/martin_black_cloaks.md`](./CHARACTERS/martin_black_cloaks.md) | A |
| Viceroy Konrad Preen | [`docs/CHARACTERS/konrad_preen.md`](./CHARACTERS/konrad_preen.md) | A |
| Lembit Helme | [`docs/CHARACTERS/lembit.md`](./CHARACTERS/lembit.md) | B |

[`docs/CHARACTERS/README.md`](./CHARACTERS/README.md) indexes these and points at this plan.

---

## Production follow-ons

| Need | Suggested owner | Notes |
|---|---|---|
| Remaining Wave A briefs (#4–#8) | Design / Narrative | Tracked as **P7-013**. |
| Wave B/C brief batches | Design / Narrative | Open after P5-001 canon accept / P6 design. |
| `faction.blackheads` ledger stub + events | Quest / Dev | **P4-045** delivered: candidate seat records events via `FactionCandidateSeats`; README / ADR 0008 launch-eight unchanged; Lizard Union still has no ledger ID. Elevation to launch table needs a later ADR/Producer row. |
| Shared-rig models for Wave A faces | Art | After briefs + P2-004 / P0-150 pipelines; 2D seeds inspiration only. |
| Lizard Union as ninth launch faction | Maintainer ADR | Explicitly out until ADR; intrigue cell may ship earlier. |

---

## Recommendation

1. Treat the seven slice-core briefs as frozen MVP cast; expand only through this list.
2. Prefer Blackheads and Danish/Order faces for near-term Act 1 density; Harju Kings and Pskov faces for Act 2 design.
3. Keep Lizard Union as an intrigue cell, not a ledger peer of the eight, until a dedicated ADR. P4-045 does **not** add `faction.lizard_union`; only `faction.blackheads` is a candidate seat.
4. Never promote a second “Kalev-the-smith” or a second “Mart” without a distinct content ID and player-facing name.
