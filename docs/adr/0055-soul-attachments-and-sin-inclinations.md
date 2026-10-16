# ADR 0055: Soul attachments and per-light sin inclinations

- **Status:** Proposed (drafted 2026-10-16 from a maintainer idea). **No code until the maintainer approves this ADR.** First task: **R-2076** (ATT-1), `idea` + `needs-approval` until then.
- **Builds on:** [ADR 0041](0041-spirit-sight-auras-and-soul-lights.md) (seven soul lights, earth tethers, reading depth), [ADR 0046](0046-church-services-and-collective-channeling.md) (soot, services; still proposed), [ADR 0033](0033-teen-protagonist-and-spirit-dialogue-combat.md) (per-school guilt), [ADR 0048](0048-psychological-spells-and-willpower-cost.md) (spells as social moves), [ADR 0052](0052-healer-apprentice-and-family-cure-loop.md) (the household-cure loop).
- **Amends:** ADR 0041 in two narrow points: the earth tethers become the soul's attachment threads as well as its weakness (one quad per light, both looks), and the awareness-5 reading line "Weighs on them" shows attachments instead of duel topic tags.
- **Does not supersede:** the ban on a universal good/evil score, ADR 0003 (authored offline dialogue), the asset freeze (P0-040).

## Context

The maintainer's idea (2026-10-16): what *binds* a person - money, a feud, fear, a debt, a love - should be its own list of data, separate from soot, and each binding should be drawn as a coloured thread from the root light. The bindings map to the seven deadly sins as per-light inclinations (root: gluttony and lust, belly: greed, solar plexus: wrath, heart: envy, throat: pride, brow: sloth / *acedia*, crown: vainglory), derived from the NATURAL aspect behind each light.

What exists today:

- Every being has seven lights (`aspect.*`, level 0..5) and one clarity. A closed light (0) drags a dark earth tether, an ember (1) a faint one (`SpiritAuraView.earth_tether_for_level`), in quads 8..14 of `spirit_aura_light.gdshader`. **The docs say all seven tethers start at the root light; the code still starts each at its own light** (`top = anchors[i]`) and only ends them at the ground under the root. This ADR makes the docs true.
- Guilt is per school (`guilt.church`, `guilt.folk`, `guilt.civic`, 0..10), hero only, and drives the hero's clarity.
- Soot (*tahm*, ADR 0046, proposed) is a 0..1 burden per light that dims it, cleaned by church and folk rites.
- Nothing records *who or what* a person is bound to. Duel topics (`daily_burden`, `rusted_key`) carry the theme of one duel, not a fact about the person, and the healer loop (ADR 0052) needs exactly such facts ("the husband's debt makes the house sick").

### The period sin lists (CANON)

| List | Date | Names | Label |
|---|---|---|---|
| Cassian, *Institutes* (after Evagrius' eight thoughts) | c. 420 | gula, luxuria, avaritia, ira, tristitia, acedia, cenodoxia (vainglory), superbia | `attested` |
| Gregory the Great, *Moralia in Iob* XXXI | c. 590 | pride (*superbia*) as the root and queen of all, then seven: inanis gloria, invidia, ira, tristitia, avaritia, ventris ingluvies (gluttony), luxuria | `attested` |
| Scholastic capital vices (Peter Lombard; Aquinas, *ST* I-II q. 84 a. 4, c. 1270) | 12th-13th c. | Gregory's seven with *acedia* for *tristitia*; pride stays above them as the root | `attested` |
| The SALIGIA mnemonic (superbia, avaritia, luxuria, ira, gula, invidia, acedia) | 13th c. canon-law and confessors' manuals | pride in the seven, vainglory folded into it | `attested` as 13th-century; the attribution to Hostiensis is common but not checked here |

So in 1343 both forms were current: seven with pride inside (SALIGIA), or pride as the root above seven with vainglory. The maintainer's mapping uses **eight names on seven lights** (gluttony and lust share the root), which is the Gregorian-scholastic set with *acedia*: period-correct. Confessors examined penitents vice by vice (Fourth Lateran canon 21 confession, already `attested` in CANON). Reval's Dominicans of St Catherine, a preaching and confessing order, using this scheme in 1343 is `plausible composite`. The mapping of sins to lights is **`invented`**.

## Decision

### 1. An attachment is a fact about a life, not a stain

An **attachment** binds a holder to a target in the world. It is data, never derived from the lights.

```json
"attachments": [
  {"kind": "attachment.debt", "target": "char.aita", "strength": 0.7},
  {"kind": "attachment.love", "target": "char.mart", "strength": 0.9},
  {"kind": "attachment.fear", "target": "faction.livonian_order", "strength": 0.4}
]
```

- `kind`: a stable `attachment.*` id from the catalog below. `target`: a stable id (`char.*`, `faction.*`, `site.*`, `item.*`, a bestiary creature id) or `self`; each kind lists the prefixes it accepts. `strength`: 0..1 (two decimals).
- One instance per (`kind`, `target`) pair, at most **6** per holder (readability and the strand budget). There is no separate instance id; the pair is the key.
- An attachment is not good or bad. Love for a missing boy and fear of a bailiff are both attachments. What can go wrong is the **inclination** (section 2).

**Catalog** (`content/spirit/attachment_kinds.json`). Each kind has one home light: the light whose guarded duel element names the same thing (ADR 0041 table) or whose NATURAL sub-stats it pulls on.

| Light | Aspect (NATURAL place, sub-stats) | Guards | Kinds | Inclination (sin id) |
|---|---|---|---|---|
| 1 root | `aspect.nature` (root system: vitality, stability, endurance) | fear | `attachment.fear`, `attachment.craving` | `sin.gula` (gluttony) for a craving of food or drink, `sin.luxuria` (lust) otherwise |
| 2 belly | `aspect.affection` (base of trunk: the grasping hand, agility, dexterity) | coin | `attachment.money`, `attachment.debt` | `sin.avaritia` (greed) |
| 3 solar plexus | `aspect.tenacity` (main trunk: strength, intimidation) | duty | `attachment.feud` | `sin.ira` (wrath) |
| 4 heart | `aspect.unity` (large branch: charisma, empathy) | love | `attachment.love`, `attachment.rivalry` | `sin.invidia` (envy) |
| 5 throat | `aspect.resonance` (high windy branch: persuasion, deception, leadership) | shame | `attachment.honour`, `attachment.secret` | `sin.superbia` (pride) |
| 6 brow | `aspect.awareness` (treetop perch: perception, wisdom) | sight | `attachment.grief` | `sin.acedia` (sloth) |
| 7 crown | `aspect.light` (sky above the tree: faith, spirit) | faith | `attachment.glory` | `sin.inanis_gloria` (vainglory) |

Why each sin sits where it does:

- **Root, nature:** the body's survival and appetite. Gregory and Aquinas call gluttony and lust the two *carnal* vices; fear is the body clinging to life.
- **Belly, affection:** what one holds dear and holds on to; it guards coin. Greed is affection fixed on things.
- **Solar plexus, tenacity:** strength, intimidation and duty. Wrath is tenacity turned to harm; a feud is duty to vengeance.
- **Heart, unity:** fellowship and empathy; it guards love. Envy, sorrow at another's good, is the scholastic opposite of charity.
- **Throat, resonance:** the voice that persuades, deceives and leads; it guards shame. Pride raises the voice over others, and shame is pride's wound, so a kept secret binds here.
- **Brow, awareness:** seeing and attending. *Acedia* is the weary, closed inner eye that will not attend (Cassian's noonday demon); grief is its sister *tristitia* in the older lists.
- **Crown, light:** the tie to the sky. Vainglory is glory turned from God to the self: the beam bent to show.

### 2. Inclination: derived, per light, never summed

- `pull(light)` = min(1, sum of the strengths of the holder's attachments homed on that light).
- `inclination(light)` = clamp(pull - effective level / 5, 0, 1). The effective level is the soot-dimmed float level once ADR 0046 lands, the integer level until then.
- A strong light holds its attachments without being ruled by them; a weak light is ruled. A rich merchant with a blazing belly light carries money and leans to nothing; a widow with an ember belly light and a hard debt leans to greed.
- Inclinations are **never stored and never summed** across lights. There is no sin score, no virtue score, no total. This keeps the ban on a universal morality score.
- No gameplay rule reads an inclination in ATT-1 except the reading card (section 5). It is a description, like clarity.

### 3. Soot, guilt and attachments are three different things

| | Soot (*tahm*, ADR 0046) | Guilt (ADR 0033) | Attachment (this ADR) |
|---|---|---|---|
| What it is | burden on a light | the hero's breach of a code | a binding to someone or something |
| Shape | 0..1 per light | 0..10 per school | list of (kind, target, strength) |
| Who has it | every being | the hero | every person (animals: none) |
| Names a cause | no | an act id | yes: a target |
| Changes the light | dims it, lowers clarity | lowers the hero's clarity | no; it adds a thread and may tip an inclination |
| Comes from | wear, Fear, lost duels, night visitors, guilt events | `GuiltLedger.record_act` | authored content and story ops only |
| Goes away by | church (upper lights), folk rites (root) | `GuiltLedger.absolve` per rite id | an act in the world: the debt paid, the feud settled, the grief worked through |
| Drawn as | darker, murkier lights | the hero's clarity | coloured strands in the light's tether from the root |

They interact only through the effective level: soot dims a light, a dimmer light makes the same attachment incline harder. Guilt never creates an attachment, and an attachment never creates guilt; acting on an inclination can record guilt through authored content (`record_act`), as any act can.

### 4. Church and folk rites: they ease the sin, not the bond

- A mass or vespers (ADR 0046) cleans upper-light soot and `guilt.church`. **It never removes or weakens an attachment.** Because the inclination reads the effective level, a cleaner light inclines less: the service eases the grip of the sin while the thread stays. The sauna and the hiis do the same for the root lights. "Mass cleanses sins but not attachments" falls out of one formula, not a second rule.
- **Confession** (CS-6, R-1741): the authored examination follows the capital vices, as confessors' manuals did. The priest names the hero's inclinations above 0.25. A confessor may set a penance of **restitution** (period canon law required restitution of ill-gotten goods and usury before absolution, `attested`): an authored quest whose end runs `attachment.loosen` or `attachment.release`. Absolution itself still only clears `guilt.church` and soot.
- A corrupt priest (ADR 0046) adds soot; he cannot bind or release an attachment.
- If ADR 0046 is not approved, this section shrinks to the confession penance, which needs only dialogue content.

### 5. Seeing and reading attachments

- **Threads (everyone in full-aura range):** each light's tether quad also carries that light's attachment strands, so the threads are visible at any awareness, like the lights.
- **Reading card** (`SpiritReading`, by the hero's awareness level): 3 lists the attachment kinds ("bound by: debt, love"); 4 adds targets (the record's name for a known `char.*`, a faction name, else "someone"); 5 names inclinations above 0.25 ("leans to greed"). The awareness-5 line "Weighs on them" (today the first three duel topic tags) becomes this list. Wording describes binding and leaning, never a verdict.
- **Knowing:** reading a person at awareness 4+ makes their attachments **known** to the hero; story content can reveal one too (`attachment.reveal`). Known attachments are saved (section 7).

### 6. Dialogue leverage (ATT-2)

- **Authored conditions:** `attachment.has {holder, kind, target?, min_strength?}` and `attachment.known {holder, kind, target}` gate options in authored dialogue ("You still owe Aita for the winter's ale."). No free text, no generated lines (ADR 0003).
- **Story ops:** `attachment.bind`, `attachment.loosen {amount}`, `attachment.release`, `attachment.reveal`, holder default `char.apprentice`. The healer loop (ADR 0052) uses them: curing a household often means loosening the debt or the feud that sickens it.
- **Duel factor:** a word striking (or, under ADR 0048, raising) a light that holds attachments gets x(1 + 0.25 x pull) "a pulled thread", inside the existing 0.5..2.0 `SpiritDuel.word_product` clamp. It works both ways: the hero's own attachments are where opponents hurt him. Prototype number, tuned after play.

### 7. Data, determinism and saves

- **Catalog and tuning:** `content/spirit/attachment_kinds.json` (kind id, home light, sin id, accepted target prefixes, display name) and `content/spirit/attachment_crowd.json` (profession table), both validated.
- **Named NPCs:** an optional `attachments` array on the character record, validated (`ATTACHMENT_KIND`, `ATTACHMENT_TARGET`, `ATTACHMENT_STRENGTH`, `ATTACHMENT_DUPLICATE`, `ATTACHMENT_LIMIT`). Changes made by story ops are saved as `npc_attachments.<char id>` (the full list) only when it differs from the authored list.
- **Crowd:** derived, never saved: a stable SHA-256 hash of (citizen id, profession) picks 0..2 attachments from the profession table, with targets `self` or `faction.*` only (a crowd citizen never names a named character). Same inputs, same threads in any process.
- **Hero:** `soul.attachments` (strengths quantised to 1/100) and `soul.known_attachments` (keys `holder|kind|target`). The starting list is Narrative content, not decided here. Older saves load with none and no error.
- **Animals:** no attachments.

### 8. The minimal render change

Inside the existing light draw call (`spirit_aura_light.gdshader`, quads 8..14), no new mesh, quad or draw call:

1. Every tether quad starts at the root light (`anchors[0]`), not at its own light, and keeps its splay toward the ground. This makes the 2026-10-13 description true.
2. Two new uniform arrays: `attachment_pull[7]` (0..1) and `attachment_strands[7]` (0..3, the count of attachments on that light, capped at 3).
3. Quad strength = max(earth tether for the level, pull). The dark core and knots still come only from the closed / ember rule; 1..3 thin bright strands in the light's colour are laid inside the same quad, drifting down slowly (stilled by reduced flashing).
4. A closed light without attachments looks exactly as today; a bright light with a debt shows one orange thread from the root into the earth; a closed light with a fear shows the dark tether with a red strand.
5. GLOW tier: unchanged, no threads. `SpiritAuraView` writes the two arrays on profile change, never per frame, and mirrors the strength rule in a static helper for tests.

**Deferred (ATT-3):** threads that run to a visible target (the debtor's thread crossing the street to the creditor). It needs pairing across two auras and its own budget, and waits until the root threads have been seen in play.

## Equivalent scope accounting

1. **Removed:** the awareness-5 "Weighs on them" duel-topic line. The reading shows attachments instead; there is no second burden line.
2. **Not built:** a sin or virtue meter, stored sin values, a sin-cleansing rite, a penance minigame. Inclinations are derived; penance is an ordinary authored quest.
3. **Not built:** an attachment-specific UI screen. The reading card and authored dialogue are the only surfaces.
4. **Deferred:** threads to visible targets (ATT-3), hero starting attachments (Narrative), any attachment for animals.
5. No new art (procedural strands in an existing quad), no new draw call, no new shader file.

## Alternatives considered

- **Attachments as more soot.** One number per light cannot say *who* binds a person, and rites would wash away debts. Rejected: the bond must survive a mass.
- **Store a sin value per light and let rites lower it.** A hidden morality score and a second meter beside soot. Rejected for a derived inclination.
- **Pride at the crown (Gregory's "queen of vices") and vainglory folded in (SALIGIA).** Also period-correct and simpler, but it loses the voice/shame link of the throat and the maintainer chose eight names. Kept as the fallback if Canon prefers a seven-name list.
- **Each attachment its own quad.** Up to 6 more quads per full aura (72 in a 12-aura crowd). Rejected for strands inside the existing seven quads.
- **Threads from each light (today's code).** Seven lines crossing the torso read as noise; one root bundle reads as "what holds this soul to the earth". Rejected.
- **Derive crowd attachments from the household graph** (named debtor and creditor pairs). Richer, but couples the aura to the census graph and to ATT-3. Deferred.

## Consequences

- [`SPIRIT_SIGHT.md`](../SYSTEMS/SPIRIT_SIGHT.md) gains "Attachments and sins" (`Status: planned`) and its tether bullet notes the code gap; [`STATE_AND_SAVES.md`](../SYSTEMS/STATE_AND_SAVES.md) gets the `soul.attachments`, `soul.known_attachments` and `npc_attachments` rows when ATT-1 lands.
- [`CANON.md`](../CANON.md) carries the labels: the eight thoughts, Gregory's seven with pride as root, the scholastic capital vices with *acedia*, SALIGIA, confession by the vices and restitution are **`attested`**; their use by Reval's Dominicans in 1343 is **`plausible composite`**; attachments, inclinations and the sin-to-light mapping are **`invented`**.
- Tasks: **R-2076** ATT-1 (data, model, render, reading, saves). On approval: ATT-2 (dialogue conditions, story ops, duel factor; after ATT-1 and SPL-2 R-1914), ATT-3 (threads to visible targets; after play review). CS-6 (R-1741) gains the restitution penance when it is written.
- Tests: pull and inclination math, catalog and validator codes, crowd determinism, save round trip and old saves, tether origin and strand rule, reading depth.
- Risks: sin words read as a verdict (mitigated: no score, "leans to", inclination only where a light is weaker than its pull); thread clutter in crowds (cap 6 per holder, 3 strands per light, full tier only); confusion between a dark tether and a thread (dark core = weak light, bright strand = bond, both shown in the [legend plate](../SYSTEMS/SPIRIT_SIGHT.md#attachments-and-sins-planned-adr-0055)).
- Keyboard and gamepad: nothing new; reading uses the existing focus.
