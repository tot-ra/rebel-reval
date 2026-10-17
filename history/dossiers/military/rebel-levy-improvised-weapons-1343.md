---
domain: military
slug: rebel-levy-improvised-weapons-1343
status: partial
consumers: [art, dev, quest]
related:
  - arms-and-armour-livonia-1340s.md
  - lower-town-weapon-finds-1340s.md
  - watch-duty-and-town-defence.md
  - ../../../docs/SYSTEMS/EQUIPMENT_VARIANTS.md
  - ../../../docs/SYSTEMS/FARMLAND.md
updated: 2026-10-16
---

# Rebel levy and improvised weapons, St George's Night 1343

Research note for board task R-2014 (EQ-12, epic R-2002). It decides which farm tools and plain weapons the Estonian rebel levy may carry in the game, and in which form, before any art is generated.

## Brief for Art / Dev / Quest

1. **The written sources do not list rebel weapons.** Wartberge and the Younger Rhymed Chronicle (Hoeneke, known through Russow) give numbers, places and killings (Padise, the Reval siege, Kanavere/Sõjamäe), not a kit list [1][2][3]. "Farmers armed with farm tools" is a **trope** of later retellings and of peasant-war imagery in general, not a 1343 fact. Treat every rebel weapon below as **plausible composite** unless marked otherwise.
2. **There is no archaeological signature of the 1343 rebel layer** [4]. What is attested is the everyday iron and wood of an Estonian farm: axes, spearheads, knives and sickles are common in Late Iron Age and medieval rural finds [5][6].
3. **Allowed:** oak club, iron-bound club, threshing flail (the farm tool, as found on the threshing floor), wooden hayfork, sickle, axe, plain spear. The looted crown or Order piece (spear, sword, kettle hat, shield) is the existing item at wear `w2`, carried by one man in a band, never a matched set.
4. **Excluded: the re-hafted (straightened) war scythe.** The earliest reference found to scythe blades remounted as weapons is from **1499**; hard evidence before about 1500 is lacking [7]. By the period rule (dated later: exclude) it is not in 1343 Reval. An unconverted scythe (`obj.scythe`), carried as a tool, stays allowed.
5. **Excluded forms:** the military flail (chain, iron or spiked head), spiked "morning star" clubs, iron three-tine pitchforks as rebel kit (iron forks are a later and costlier rural tool; the game's `obj.pitchfork` stays a farm prop), sickle-swords and any straightened sickle.
6. **Look:** worn, home-made, mended. Wear `w1` = a working tool in use; `w2` = an old tool, cracked, bound and grimy. Prestige is always `p1` (no rebel has a rich club).

## Findings

### What the sources say

| Source | What it gives for rebel arms | Evidence |
|--------|------------------------------|----------|
| Hermann von Wartberge, *Chronicon Livoniae* (c. 1378) [1] | Course of the rising and the Order's battles; no weapon list | attested (for events only) |
| Younger Livonian Rhymed Chronicle (Hoeneke), via Russow (1578) [2] | About 10,000 rebels at the siege of Reval; no weapon list | attested (for events only) |
| Project arms dossier [8] | "Axes, clubs, scythes, spears", bows; flagged as the chronicle "farm tools" trope | plausible composite |
| Lower Town finds [4] | No rebel layer; axes and scythes plausible from tool finds | plausible composite |

### Tool by tool

| Item | Form allowed in game | Not allowed | Evidence | Notes |
|------|----------------------|-------------|----------|-------|
| Oak club (*nui*) | Root-knob or thickened oak/ash billet, 0.7-0.9 m, bark partly off, hand-worn grip | Studs, spikes, metal head | plausible composite [8][9] | The watch dossier already lets an Estonian townsman carry a club as a civilian [9] |
| Iron-bound club | Same billet with one or two forged iron hoops or a few large nails at the head | Flanged mace head (that is a crown/Order weapon), spikes | plausible composite | Hoops are the smith's off-cuts; Kalev's camp forge can make them |
| Threshing flail | The farm flail: long hand staff (about 1.3 m) and short beater (about 0.6 m) joined by a leather or withy link | Chain, iron head, spikes, short "war flail" | plausible composite [10][11] | Western European tool attested c. 1325-35 (Luttrell Psalter) [10]; the game's FARMLAND already lays two flails on each threshing floor and rates the form plausible composite [11] |
| Wooden hayfork | Forked branch, two or three natural tines, peeled, 1.6-1.9 m | Forged iron tines (rebel kit), dung fork | plausible composite [6] | Wooden forks are the everyday farm form; iron tines cost a smith's work |
| Sickle | Toothed crescent on a short turned grip, as `obj.sickle` | Straightened sickle on a pole | attested as tool [5][6]; plausible composite as weapon | Same silhouette as the game's farm sickle |
| Re-hafted scythe | Not allowed | Any straightened scythe on a pole | dated later: exclude [7] | `docs/LOCATIONS/rebel_kings_camp.md` lists "scythe-blade on a pole" and a re-hafting quest; those rows conflict with this note and go to the canon keeper |
| Axe, spear | Existing items (`axe_peasant` since R-2009, `spear`) at `w2` | New rebel axe or spear meshes in this task | plausible composite [8] | Socketed spearheads are common in Estonian Late Iron Age finds [5] |
| Looted crown/Order item | Existing item at `w2`, one per band | A whole looted kit on one man | plausible composite [8] | |

## Production hooks

- **Art:** five new families, each `p1` x `w1`/`w2` under `assets/props/weapons/rebel/` (`club_oak`, `club_ironbound`, `threshing_flail`, `hayfork`, `sickle`), naming per [`EQUIPMENT_VARIANTS.md`](../../../docs/SYSTEMS/EQUIPMENT_VARIANTS.md#rebel-levy-weapons-r-2014). No scythe. Shipped 2026-10-17 (approved under P0-040).
- **Dev:** rebels (`harju_kings`, `black_cloaks`) already roll wear `w2` (R-2004); a rebel band mixes the five tools with one axe, spear or looted piece.
- **Quest / canon:** `quest.camp_field_forge` ("re-haft scythe-blades") and the camp crowd row "young recruit with a scythe-blade on a pole" need rewording (re-haft axes and spearheads, mend flails); canon keeper decision.

## Open questions

- Estonian-language ethnology on when the jointed threshing flail (*koot*) replaced beating with sticks in Harju; if it turns out to be later than 1343, the flail falls back to a single threshing stick.
- Primary-text pass on Wartberge's account of Kanavere for any weapon word.

## Sources

1. Hermann von Wartberge, *Chronicon Livoniae*, ed. E. Strehlke, *Scriptores rerum Prussicarum* II, Leipzig 1863 (Latin).
2. Balthasar Russow, *Chronica der Provintz Lyfflandt*, 1578, preserving the Younger Livonian Rhymed Chronicle of Bartholomäus Hoeneke (Low German).
3. "Jüriöö ülestõus", *Eesti Entsüklopeedia* (Estonian), http://entsyklopeedia.ee/artikkel/j%C3%BCri%C3%B6%C3%B6_%C3%BClest%C3%B5us2.
4. [`lower-town-weapon-finds-1340s.md`](lower-town-weapon-finds-1340s.md) - "Rebel farm weapons: no archaeological signature for 1343 uprising layer" (project dossier).
5. A. Mäesalu, published studies of Estonian medieval weapons (e.g. *BJAH* 2017, Papsaare macehead), with Late Iron Age weapon typology references (Estonian/English).
6. Estonian Open Air Museum, "Rehemaja" (traditional farm and tools), https://evm.ee/maaarhitektuur/maaehitusparand/traditsiooniline-taluarhitektuur/rehemaja (Estonian).
7. "'A desperat wepon': re-hafted scythes at Sedgemoor, in warfare and at the Tower of London", *The Antiquaries Journal* (Cambridge University Press) - "hard evidence of use before about 1500 has proved elusive"; earliest reference found 1499 (English).
8. [`arms-and-armour-livonia-1340s.md`](arms-and-armour-livonia-1340s.md) - Order versus rebel equipment table (project dossier).
9. [`watch-duty-and-town-defence.md`](watch-duty-and-town-defence.md) - tier D, civilian club or knife (project dossier).
10. *Luttrell Psalter*, British Library Add MS 42130, c. 1325-1335 - men threshing with flails.
11. [`FARMLAND.md`](../../../docs/SYSTEMS/FARMLAND.md) - threshing floor, flail rated plausible composite.
