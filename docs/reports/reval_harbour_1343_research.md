# Reval harbour geography and visual reconstruction for 1343

Recorded: 2026-07-21  
Scope: inactive `reval_harbor_north` and `reval_harbor_east` prototypes  
Confidence: conservative reconstruction, not a measured plan of the 1343 shoreline

## Decision

- Keep the merchant landing immediately below the medieval Coastal Gate. This is the shortest and best-supported gate-to-harbour relationship, but the exact 1343 waterline and landing structures remain uncertain.
- Interpret the fishing map as the Kalamaja/Kalarand shore north-west of the walled town, not as an eastern urban harbour and not as Pirita/Kose. The file and map IDs remain unchanged because transitions and developer saves already reference them.
- Do not add a Pirita monastery, Pirita harbour, or Kose riverbank to the Reval harbour pair. The initiative for St Bridget's convent belongs to about 1400, with construction beginning after 1417. A Pirita River location in a 1343 game would need to be a separate rural river-mouth reconstruction with no later convent silhouette. Reviewed material does not establish it as Reval's principal fishing harbour.
- Treat `Trade Harbour`, `Fishing Harbour`, and `Merchant Landing` as gameplay labels rather than attested administrative names.

## Evidence and limits

1. Reppo and Kadakas place the medieval Coastal Gate on a sandstone rise roughly 5-8 m above the historical harbour ground. They support a low northern wall/gate by the mid-fourteenth century and a probable 1311-1340 gate tower. The first written reference to the gate is later, in 1359, and the first barbican remains uncertain. This supports a clear gate-to-lowland descent, not Fat Margaret or a later fortified harbour frontage.
2. Roio et al. document a ship wrecked east of the Hanseatic town around the second quarter of the fourteenth century and stress how much the shore later moved and was filled. It proves maritime use, but not an exact quay line or a formally separated east fishing district.
3. The Lootsi Street cog demonstrates that large Baltic cargo vessels were present in Tallinn's fourteenth-century maritime environment. It does not prove that four ships were moored simultaneously to four permanent stone piers. Merchant vessels in these maps therefore sit in open water as a readable roadstead composition.
4. Tallinn's official visitor material describes Kalamaja as a former medieval fishing village outside the Old Town. Later summaries place fishermen and boat-related trades there from the fourteenth century; the first commonly cited notice of Kalarand fishermen is 1352, nine years after the game date. For 1343, Kalamaja is therefore a strong bounded reconstruction, not a day-specific attested settlement plan.
5. Pirita Convent's own history places the founding initiative around 1400, the arrival of Bridgettine advisers in 1407, the start of construction after the 1417 quarry permit, and consecration in 1436. None of this fabric belongs in a 1343 environment.

## Map translation

### Coastal Gate merchant landing (`reval_harbor_north`)

- One main stone/pebble descent from the gate to low, wet cargo ground.
- Broken sand and mud shoreline instead of a straight dressed-stone quay.
- Two short timber/rubble landings instead of four regular long stone piers.
- Scattered plank warehouses, sheds, fenced cargo yards, rope ground, carts, barrels, and one reversible crane marker.
- Four merchant cogs remain as a developer-readable roadstead, but are not claimed as an attested vessel count.

### Kalamaja fishing shore (`reval_harbor_east` stable legacy ID)

- Located conceptually west of the merchant landing, on the fishing shore outside the city.
- Three short timber beach landings, six small working boats, fish/salt sheds, net yards, huts, and a boatwright work area.
- Sand, mud, reed margins, and lightly developed grass replace broad paving and warehouse rows.
- No direct Workers' District or Viru road transition remains. The former link was topologically false and has moved to the separate Viru Gate Foreland map.

### Gameplay decision (2026-07-21): walkable timber landings

Player report: harbour "pierce"/pier looked like a landing but could not be walked.

Decision:

1. Author short landings as walkable `timber_floor` decks, not blocking `wall` masses. Open water remains impassable.
2. Moored working boats stay on water cells beside the deck tips so the player can walk up to them from the pier.
3. Large merchant cogs stay in the roadstead as scenery. Do not treat them as boardable ships. Approachable craft at the merchant landing are the small boats at the jetty tips.
4. Do not invent a boarding mechanic for deep-water vessels in this pass.

### Gameplay decision (2026-07-21): Coastal Gate outer face

Player report: Coastal Gate Landing had a weird house with a wall in it.

Decision:

1. Do not author the outer Great Coastal Gate as one `house` footprint covering the throat. That meshes as a roofed shed with the `gate_arch` punched through it.
2. Split the stable west ID `great_coast_gate` and a new east flank `great_coast_gate_east` around the walkable `coast_gate_arch`, matching the north_quarter / Karja gate pattern.
3. Keep cargo-yard fences outside shed footprints (`cargo_shed_west` sits inside the yard, not on the north fence line).

### Off-limits boundary treatment

- Water and dense southern woodland pockets are explicit excluded areas.
- The playable edge alternates forest floor, mixed/spruce tree scatter, scrub, reeds, fences, and work structures, preventing one thin tree row from revealing a generic empty plane.
- The view-only woodland continuation uses a deep multi-band forest backdrop beyond authored terrain. It never changes collision or navigation.

### Kalamaja district-life dressing (P4-028a)

- Three net yards (`drying_nets_west`, `drying_nets_mid`, `drying_nets_east`) now use `fishing_nets` and `fish_drying_rack` instead of barrel placeholders.
- `smoke_shed_west` yard carries a `smoke_rack`; fisher and net sheds carry `fish_splitting_table` work slabs.
- `salt_shed_east` carries a `salt_pile`; `boatwright_shed` carries a `boat_timber_stack` beside the existing cart.
- Fence-adjacent net-yard clutter reuses `fishing_nets` at west, mid, and east yard gates without blocking pier decks or moored boats.

## Sources

- Monika Reppo and Villu Kadakas, [Excavations at the Great Coastal Gate of Tallinn](../../history/AVE2019_15_Reppo-Kadakas.pdf).
- Maili Roio et al., [Medieval ship finds east of Tallinn](../../history/AVE2015_15_Roiojt_Kadriorg.pdf).
- Estonian Maritime Museum, [Wreck of the Lootsi cog](https://meremuuseum.ee/en/wreck-of-the-lootsi-cog/).
- Visit Tallinn, [Kalamaja](https://www.visittallinn.ee/eng/visitor/see-do/neighbourhoods/kalamaja).
- Pirita Convent, [History](https://www.piritaklooster.ee/history/?lang=en).

## Historical review status

The placement choice is evidence-led and more conservative than the previous east-harbour/Pirita alternatives. Exact shoreline curves, structure counts, vessel counts, plot boundaries, and the built/open ratios remain reviewable reconstruction. Keep both maps inactive until the broader historical audit receives human sign-off.
