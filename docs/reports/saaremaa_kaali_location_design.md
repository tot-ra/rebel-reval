# Saaremaa location design: the Kaali crater coast

**Map:** [`content/maps/world_saaremaa.rrmap`](../../content/maps/world_saaremaa.rrmap)
**Scene:** `scenes/world_travel/world_saaremaa.tscn`
**Scope:** `prototype`, `active=false`, `release=false` - developer global-map node, not a shipping level.

## Why the previous map failed

The 50x28 source held two brushwood camps, one shed and a signal fire on an
undressed bog field. Three problems followed from that:

1. **No identity.** Nothing on it was Saaremaa. The same three objects could have
   been Kanavere, Sõjamäe or Paide, and two of the ten global nodes already were.
2. **No reason to stop.** It was a corridor between the Reval ferry and Pöide with
   no interactable geography, so it read as a loading screen with grass.
3. **Void edges.** The map declared no `surroundings`, so the 3D view continued the
   playable rectangle into empty space instead of sea or woodland.

## What the location is now

**The north coast of Ösel in the summer of 1343, from the ferry beach inland to the
Kaali crater.** It is deliberately *not* a castle: Pöide is the castle, authored as
its own map, and Kuressaare/Maasilinna masonry is off-map or later. This map is the
ground the rising stands on - where it lands, where it musters, what it burned, and
what it swears by.

`docs/data/landmark_integrations.json` already reserved this map for
`beat.landmark.estonia.kaali_meteorite_craters` under `event.act3.saaremaa_campaign`,
with the beat *"folklore links fire from the sky to omen-reading before battles"*.
That beat is now authored geography rather than a text pop-up.

### Zones

| Zone | Cells | Reads as | Carries |
|---|---|---|---|
| Ferry bay and pier | x0-20, y8-29 | Sheltered western bay with a timber landing | `ferry_to_reval`; moored boat, rope coil, salt |
| Fishing hamlet | x20-48, y12-31 | Dune boat sheds, two smoke cottages, barn, well | Island civilians who are not rebels |
| Alvar pasture | x20-37, y32-45 | Dry grass, limestone pavement, kiviaed field walls, sheep | The island's economy and its signature silhouette |
| Muster camp | x40-60, y30-50 | Brushwood shelters, field forge, Metsik banner | Staging for the march on Pöide |
| Burnt manor | x8-28, y40-50 | Ash field, three roofless shells | The July killings, as consequence not spectacle |
| **Kaali crater** | x53-87, y24-50 | Mossy outer slope, bare inner slope, shallows, standing water, enclosing bank | The unique landmark and the ritual centre |
| Strait landing | x88-104, y28-46 | East beach and second pier | `ferry_to_parnu` toward the mainland |
| South wood | y51-60 | Pine belt | Screens the Pöide road; `surroundings south woodland` |

Area went from 1,400 to 6,240 cells (**4.5x**). Sea now occupies the north, west and
east margins, `surroundings north water east water west water south woodland` removes
the void, and every water body is excluded from navigation while both pier decks are
cut out of those exclusions so the ferry doors stay walkable.

### Why the crater is authored with terrain, not elevation

The view layer returns a fixed water recess for any water cell before authored
elevation is applied, and `elevation_area` profiles are discs that overwrite each
other rather than accumulate - so a rim ring is not expressible and a dug bowl would
push the lake surface above its own shore. The crater is therefore built from four
concentric octagons (mossy slope, mud slope, shallows, standing water), a low
`ditch_edge` enclosure bank with one gap on the north, and a juniper/pine rim. Scale
is compressed: the real crater is ~110 m across, this one ~30 m, sized as a walkable
ritual bowl. If a ring-shaped elevation primitive is ever added, the rampart bank is
the record to replace.

## Narrative integration

The island is Act 3. Its problem is not that the Order is strong here - the Order's
garrison is a day's march east at Pöide and will lose. Its problem is **what kind of
victory it is**: Pöide surrendered on terms and was massacred anyway, and
`docs/CANON.md` keeps that betrayal attested. This map exists to make the player
complicit in, or opposed to, the decision *before* it is taken, and to give the
betrayal a place it was sworn against.

Three constituencies share the ground and want different things:

- **The crater priesthood** (Cult of Metsik) reads omens for the campaign. Their
  authority is the reason the muster holds together, and their price is a sacrifice.
- **The muster** wants Pöide's iron and Pöide's grain, and does not much care what is
  promised to get them.
- **The hamlet** wants the ferry to keep running. Fishermen with a German buyer in
  Reval are not natural rebels, and the burnt manor shows what happens to neighbours
  who chose wrong.

## Quest seeds

Numbered for the backlog; all are `invented` on `attested` ground and none of them
require the map to become active.

1. **The omen before Pöide** (main-path gate). The muster will not march until the
   crater reads favourably. The player attends the reading. The priesthood asks for
   an offering the player must supply - and the honest options are all bad: the
   captured German bailiff sheltering in the hamlet, the ferryman's mare, or the
   player's own forged blade. What is given decides which faction stands with the
   player at Pöide. Delivers `beat.landmark.estonia.kaali_meteorite_craters`.
2. **Siege iron** (craft, ties to the smithy pillar). `docs/CANON.md` promotes
   "Saaremaa / Pöide climax with player-forged siege iron" as invented-on-attested and
   scoped to local cost. The camp forge lacks stock; the burnt manor's ash field still
   holds the lord's fittings, hinges and window bars. Salvaging them arms the assault
   but means digging up the house the island burned, in front of people who burned it.
3. **The oath at the stone** (consequence hook for Pöide). The rebel captain will
   swear safe passage to Pöide's garrison at the offering stone if the player asks
   for it. Whether the oath is sworn here changes who breaks and who refuses at the
   massacre, rather than changing whether it happens.
4. **The ferry that keeps running** (faction/economy). The hamlet still ships salt
   fish to Reval. Cutting the ferry starves the Order's island contacts and also the
   island; keeping it open leaves an informant route the player may or may not close.
   Touches `beat.landmark.estonia.angla_windmill_hill` ("grain prices affect ferry
   traffic to Reval") without needing a windmill on the map.
5. **The bailiff in the net store** (moral, small). A German manor servant survived
   July and is hidden by the fishermen who worked for him. He is the offering the
   priesthood would prefer. Resolving him quietly, loudly, or by handing him over
   feeds quest 1 and quest 3.

## Evidence bounds

**Attested:** the July 1343 Ösel rising, the killing of the German lords and burning
of their houses, the march on and fall of Pöide, Kaali as a long-lived cult site with
a stone enclosure, and the alvar landscape of thin soil, limestone pavement, juniper
and dry-laid `kiviaed` field walls.

**Reconstructed:** every specific building, camp, boundary wall, road and crater band
placement below map scale, and all five quest seeds.

**Deliberately absent:** Kuressaare and Maasilinna masonry, any church (the island's
Christian fabric belongs to Pöide and Karja), windmills (post-medieval on Saaremaa),
and stone-built manor architecture - the burnt shells stay low and rubble-walled.

## Follow-ups

- Populate the map with routines/NPCs once Act 3 leaves greybox; nothing here spawns
  actors yet.
- Keep both committed evidence captures current when the map geometry changes: the
  2D audit plate under `images/map_audit/` and the day 3D plate under `images/view3d/`.
- Consider a ring-capable elevation primitive; the crater is the first record that
  would use it.
