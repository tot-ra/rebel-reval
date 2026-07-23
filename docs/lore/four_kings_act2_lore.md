# Act 2 Lore: The Four Kings (Neli kuningat)

**Task:** P5-013
**Status:** Draft for review
**Scope:** Historical context of the Four Kings, mapping to in-game assets shipped or authored through Act 1.

---

## 1. Historical Core (`attested`)

The "Four Kings" (Estonian: *Neli kuningat*) is a historically attested concept tied to St. George's Night Uprising of 1343. Sources confirm that the rebel forces elected four leaders to command the uprising against Danish and Livonian Order rule. These figures were later lured under truce to Paide Castle and treacherously executed by Master Burchard von Dreileben's forces (per Livonian chronicle tradition, including Hermann de Wartberge).

**Canonical reference:** [`docs/CANON.md`](../CANON.md#terminology) — *The "Four Kings"* entry: *attested*.
> *"Four Estonian leaders chosen by the rebels to lead the siege of Reval; later treacherously killed by the Livonian Order at Paide."*

**Timeline anchor:** [`docs/CANON.md`](../CANON.md#timeline-aprilmay-1343) — April 23, 1343: *"The 'Four Kings' (Neli kuningat) are elected by the rebels."*
> Source cited in canon: *Chronicles of Balthasar Russow / Livonian Chronicle of Hermann de Wartberge.*

**Historical background:** [`history/HISTORY.md`](../../history/HISTORY.md#the-siege-of-reval-and-the-four-kings) — describes the siege strategy and diplomatic moves made by the Four Kings.
> *"Understanding that their initial success was fragile, the four kings made a shrewd diplomatic move. They sent a delegation to the Swedish bailiffs in Turku and Vyborg..."*

---

## 2. Game Character Roster (Legacy Archive)

The following character files exist under `characters/rebels/` as **archive material** per [`docs/CHARACTERS/README.md`](../CHARACTERS/README.md#canon-rules). These are outside the seven-character vertical-slice scope but serve as canonical reference for Act 2 design.

### Lembit Helme — The Elder King

| Field | Value |
|---|---|
| File | [`characters/rebels/lembit_helme.md`](../../characters/rebels/lembit_helme.md) |
| Confidence | `invented` (character); historical archetype: rural elder / village spokesman |
| Role | Primary spokesman and strategist of the four Harju Kings; commands loyalty of farmers and villagers |
| Key asset tie-in | Secret correspondence with **Martin the Blacksmith** (Kalev's alias in rebel lore) — links to forge mechanics |
| Notable relationship | Clashes with Jüri Ratnik over strategy; cautiously open to Cult of Metsik alliance |

### Jüri Ratnik — The Iron Hand

| Field | Value |
|---|---|
| File | [`characters/rebels/juri_ratnik.md`](../../characters/rebels/juri_ratnik.md) |
| Confidence | `invented` (character); historical archetype: warrior-leader / vengeance-driven rebel |
| Role | Military commander of the most aggressive rebel faction; nicknamed "Iron Hand" by Order knights |
| Key asset tie-in | Forger-warrior archetype — connects to P4-018 quest content pipeline and forge modification system |
| Notable relationship | Respects Lembit's wisdom but advocates direct violent action; tests Kalev in combat |

### Urmas Laar — The Seer

| Field | Value |
|---|---|
| File | [`characters/rebels/urmas_laar.md`](../../characters/rebels/urmas_laar.md) |
| Confidence | `invented` (character); historical archetype: pagan prophet / spiritual resistance leader |
| Role | Spiritual guide to the four kings; believes uprising is a holy war to restore old ways |
| Key asset tie-in | Connection to **Cult of Metsik** (`characters/metsik_cult/`) — bridges folklore and rebellion themes |
| Notable relationship | Sees Kalev as reincarnation of prophesied giant-king; consults omens and rituals daily |

---

## 3. Character Briefs and Act 2 Mission Bindings

### Jüri Ratnik — The Iron Hand

**Archetype:** Warrior-leader / vengeance-driven rebel commander.  
**Confidence:** `invented` (character); historical archetype: warrior-leader; nickname "Iron Hand" is game invention.  
**Source file:** [`characters/rebels/juri_ratnik.md`](../../characters/rebels/juri_ratnik.md)

Jüri was a blacksmith from Läänemaa whose brother was flogged to death by a cruel manor lord. He responded by forging a massive war hammer, storming the manor, and leading armed peasants into rebellion. Among the knights he earned the nickname "Iron Hand" — a reputation built on brutal battlefield efficiency and an uncompromising stance toward collaborators.

**Personality in Act 2:** Jüri is the most aggressive of the Four Kings. Where Lembit counsels diplomacy, Jüri pushes for direct strikes. He tests Kalev's worth through combat trials rather than words, viewing him as a weapon to be honed rather than a hero to be celebrated. His relationship with Lembit is one of mutual respect but frequent strategic clashes — Jüri sees caution as cowardice, while Lembit sees recklessness as death.

**Mission bindings (P5-007 / P5-009 scope):**

| Act 2 Mission | Jüri's Role | Encounter / Dialogue Beat |
|---|---|---|
| **Kanavere Bog (P5-007)** | Primary military commander during the initial rebel victory. Authorizes the assault on the Order supply line and personally leads the vanguard through the bog tracks. His tactical decision to split forces creates the opening that later enables the Order counterattack — a consequence the player can influence via scouting choices. | Jüri's pre-battle speech rallies the Harju militia; post-victory, he pushes for pursuit while Lembit argues consolidation. Player choice here branches into aggressive (Jüri-aligned) or cautious (Lembit-aligned) outcome paths. |
| **Sõjamäe (P5-007)** | Commands the rebel rearguard during the retreat after the Order's main force arrives. His last stand buys time for civilian evacuation but results in heavy casualties among his elite warriors — a state that carries into Act 2 ledger and affects later quest availability. | Jüri refuses Lembit's order to retreat until all wounded are clear; player can mediate (reduces casualties, delays escape) or let him hold the line (maximizes delay but loses more men). Distinct survivor/casualty ledger entries per branch. |
| **Paide Finale (P5-009)** | Demands armed resistance when the truce is revealed as a trap. His defiance triggers the Order's immediate execution order — he becomes the first to be put to death, his last words a challenge to von Dreileben that echoes through Act 3 rebel morale mechanics. | If Kalev attempted warning (per P5-009 knowledge states), Jüri's fate can be altered: partial escape → Act 3 underworld contact; full capture → permanent loss but martyr legend boosts Harju Kings standing. |

---

### Urmas Laar — The Seer

**Archetype:** Pagan prophet / spiritual resistance leader who frames the uprising as holy war to restore old ways.  
**Confidence:** `invented` (character); historical archetype: pagan spiritual resistance leader.  
**Source file:** [`characters/rebels/urmas_laar.md`](../../characters/rebels/urmas_laar.md)

Urmas emerged from the remote eastern marshlands where old traditions held strongest against Christianization. Marked by visions from youth, he was apprenticed to a village shaman and learned ancient rites, songs of power, and forest secrets. As churches destroyed sacred groves, he began preaching resistance as divine cleansing — his fiery blend of anti-crusader rhetoric and pagan prophecy drew followers from the marshes into the Harju Kings' ranks.

**Personality in Act 2:** Urmas sees the uprising through a spiritual lens: this is not merely political liberation but a holy war to purge foreign faith from Estonian soil. He reads omens daily, consults the Cult of Metsik for ritual support, and interprets Kalev as the reincarnated giant-king prophesied to save his people. His cryptic prophecies create dramatic irony — when fulfilled, they validate his authority; when misread, they lead rebels into danger.

**Mission bindings (P5-007 / P5-009 scope):**

| Act 2 Mission | Urmas's Role | Encounter / Dialogue Beat |
|---|---|---|
| **Kanavere Bog (P5-007)** | Performs a pre-battle ritual at the bog's edge, reading omens in bird flight and smoke patterns. His prophecy — "the water will remember what the land forgets" — is interpreted differently by each king: Jüri sees it as encouragement to charge through the marshes; Lembit reads it as a warning about hidden Order positions in the wetlands. Player can choose which interpretation to follow, affecting bog-traversal tactics and casualty rates. | Urmas blesses weapons with sacred water from Kanavere spring; his ritual creates a temporary morale buff but requires the player to retrieve rare marsh herbs for the ceremony — a side objective that ties into Cult of Metsik faction standing. |
| **Sõjamäe (P5-007)** | Interprets the Order's arrival as fulfillment of a blood vision he had three nights prior. His cryptic warning — "the iron birds fly south this time" — initially confuses the council until scout reports confirm the southern approach route. His spiritual authority keeps morale from collapsing during the rout, but his refusal to perform last rites for fallen pagan rebels creates tension with any Christian-aligned player choices. | Urmas attempts a spirit-quest during the battle's lull to locate trapped rebel units; success depends on prior Cult of Metsik relationship state. Failed attempt costs him temporary debilitation (no omens available for Act 2 remainder). |
| **Paide Finale (P5-009)** | Foresees the execution before it happens and attempts a ritual intervention — pouring sacred water over the trapdoor hinges to symbolically "wash away" the betrayal. The ritual fails physically but creates a spiritual anchor: Urmas's last vision of the four kings standing together becomes a recurring motif in Act 3 dream sequences and Cult of Metsik rallying symbols. | If Kalev heeded Urmas's pre-truce warning (knowledge state from P5-009), the seer survives the Paide massacre — carrying prophetic fragments into Act 3 that unlock special dialogue branches with the Cult of Metsik. If ignored, his death becomes a defining loss that removes pagan spiritual support for the remainder of the campaign. |

---

## 4. In-Game Map & Event Bindings (Act 2)

The following map locations and events are authored or planned for Act 2, tied to the Four Kings narrative:

| Location / Event | File / Asset | Canon tie-in | Status |
|---|---|---|---|
| **Paide Castle** (`world_paide`) | [`content/maps/world_paide.rrmap`](../../content/maps/world_paide.rrmap) | *"The Four Kings are lured here and executed under truce"* — [`docs/TOURIST_LANDMARKS.md:31`](../TOURIST_LANDMARKS.md#paide-castle) | `world_paide` placeholder authored; Act 2 finale location per [`LANDMARK_NARRATIVE_INTEGRATION.md:173`](../LANDMARK_NARRATIVE_INTEGRATIVE.md#paide-castle) |
| **Mäo Hillfort Site** (Järvamaa) | Landmark integration data | *"Invoked in speeches by the Four Kings"* — [`docs/TOURIST_LANDMARKS.md:42`](../TOURIST_LANDMARKS.md#mäo-hillfort-site); symbolic rallying point for rebel oratory | Referenced in [`LANDMARK_NARRATIVE_INTEGRATION.md:184`](../LANDMARK_NARRATIVE_INTEGRATION.md#mäo) |
| **Rebel Signal Hill** (Harju) | World-travel placeholders (`world_harju`) | *"The Four Kings' election follows the first flames"* — [`docs/TOURIST_LANDMARKS.md:4`](../TOURIST_LANDMARKS.md#rebel-signal-hill) | Foreland `viru_gate_foreland` authored in Act 1 |
| **Event: act2.four_kings** | Landmark integration data | Paide Castle execution event — [`LANDMARK_NARRATIVE_INTEGRATION.md:173`](../LANDMARK_NARRATIVE_INTEGRATION.md#paide-castle) | Task P5-009 (finale design) |
| **Event: act2.harju_uprising** | Landmark integration data | Harju County election and rallying — [`LANDMARK_NARRATIVE_INTEGRATION.md:146`](../LANDMARK_NARRATIVE_INTEGRATION.md#harju-signal-hill) | Task P5-007 (Kanavere/Sõjamäe missions) |

---

## 4. Source Asset Map

All named sources below are already shipped or authored in Act 1:

| Source | Type | Location |
|---|---|---|
| CANON.md — Four Kings terminology entry | Canon document | `docs/CANON.md` |
| CANON.md — April 23, 1343 timeline event | Timeline anchor | `docs/CANON.md` |
| TOURIST_LANDMARKS.md — Paide Castle entry | Landmark catalog | `docs/TOURIST_LANDMARKS.md:38` |
| TOURIST_LANDMARKS.md — Mäo hillfort site | Landmark catalog | `docs/TOURIST_LANDMARKS.md:265` |
| TOURIST_LANDMARKS.md — Rebel signal hill (Harju) | Landmark catalog | `docs/TOURIST_LANDMARKS.md:215` |
| LANDMARK_NARRATIVE_INTEGRATION.md — Paide Castle event binding | Integration map | `docs/LANDMARK_NARRATIVE_INTEGRATION.md:173` |
| LANDMARK_NARRATIVE_INTEGRATION.md — Mäo hillfort event binding | Integration map | `docs/LANDMARK_NARRATIVE_INTEGRATION.md:184` |
| LANDMARK_NARRATIVE_INTEGRATION.md — Harju signal hill event binding | Integration map | `docs/LANDMARK_NARRATIVE_INTEGRATION.md:146` |
| characters/rebels/lembit_helme.md | Character archive (legacy) | `characters/rebels/lembit_helme.md` |
| characters/rebels/juri_ratnik.md | Character archive (legacy) | `characters/rebels/juri_ratnik.md` |
| characters/rebels/urmas_laar.md | Character archive (legacy) | `characters/rebels/urmas_laar.md` |
| history/HISTORY.md — Siege of Reval section | Historical research | `history/HISTORY.md:100-106` |

---

## 5. Confidence Summary

| Element | Label | Notes |
|---|---|---|
| The "Four Kings" as a historical concept | **attested** | Per Livonian chronicle tradition; Russow / Wartberge |
| Lembit Helme as character design | **invented** | Built from attested archetype of Harju rural elder-spokesman |
| Jüri Ratnik as character design | **invented** | Built from attested archetype of warrior-leader; "Iron Hand" nickname is game invention |
| Urmas Laar as character design | **invented** | Built from attested archetype of pagan spiritual resistance leader |
| Paide Castle execution site | **attested** | Per chronicle tradition — the four kings were lured under truce and killed at Paide |
| Mäo hillfort as rallying symbol | **plausible composite** | Hillforts existed in Järvamaa; no specific attestation that Four Kings invoked this one |
| Swedish diplomatic delegation | **attested (context)** | Estonian rebels did seek Swedish aid during the uprising; specifics are reconstructed |

---

## 6. Design Notes for Act 2 Implementation

- The four kings serve as Act 2's central leadership ensemble, replacing Kalev's small-cast focus with a broader rebel council dynamic
- Each king represents a different factional axis: strategy (Lembit), military force (Jüri), spirituality (Urmas) — creating natural story tension and player-choice opportunities
- The Paide execution is the emotional climax of Act 2; per TODO P5-009, it must occur in every branch with the player's knowledge/warning states producing distinct act-transition records
- Legacy character files under `characters/rebels/` are marked archive status — they inform Act 2 design but should not be reactivated as playable characters without a scope decision

---

*Draft authored for task P5-013. All named sources map to assets already shipped or authored in Act 1.*
