# Cultures and Languages across the journey nodes
**Status:** planned (design proposal, not implemented) · **Scope:** cross-cutting reference for all `loc.world_*` nodes, proposed and existing; no new systems · **Confidence:** the existence of each community in or near 1343 Livonia/Estonia is mostly `attested`; dialect detail, dress and crafts are `plausible composite`; anything marked unattested is stated as such.

Voice policy: dialogue is authored offline (no runtime LLM). Subtitles are in modern English. The language of a speaker is shown as a tag on the line (not as speech in another tongue) except for short flavour phrases. Spelling of Middle Low German (MLG) follows [names-address-and-oaths.md](../../history/dossiers/language/names-address-and-oaths.md): "Gode dagh", not High German. Estonian is rendered plainly, no modern slang.

## Table A: communities, language, writing, naming
| Community | Language / dialect | Writing | Naming conventions | Label |
|---|---|---|---|---|
| Harju Estonians | North Estonian (Harju) | Oral; names written phonetically by Germans | Forename plus *-poeg* patronymic or farm; no hereditary surname | `attested` (people), names `plausible composite` |
| Saaremaa islanders | Island Estonian (Saare dialect) | Oral | Same pattern; Christian names dominate after 1227 conquest | `attested`, details `plausible composite` |
| Sakala / Ugandi South-Estonian; proto-Setu / Võro | South-Estonian (Mulgi, Tartu, Võro-Setu forms) | Oral | Forename plus patronymic; Orthodox names among eastern groups | South-Estonian `attested`; "Setu" as a distinct 1343 group `plausible composite` |
| North-Viru Estonians | North-East Estonian (Viru) | Oral | As Harju | `attested` |
| Läänemaa Estonians | West-Estonian dialect | Oral | As Harju | `attested` |
| Estonian Swedes (Noarootsi, Vormsi, Pakri, Ruhnu, coast) | Old Estonian-Swedish dialects | Oral; Latin/MLG in charters | Swedish patronymic *-son/-dotter* (see [vitalienbruder.md](../CITIZENS/factions/vitalienbruder.md) for the style) | settlement `attested` from the 13th-14th c.; exact stretch/date `plausible composite` |
| Livs (Livonians proper) | Livonian (Finnic) | Oral | Forename plus clan/place | `attested` on Latvian side and north Courland coast; in Estonian nodes only as visitors, `plausible composite` |
| Finnish / Karelian traders | Finnish / Karelian | Oral; Swedish/Latin for contracts | Forename plus patronymic | `plausible composite` for 1343 Reval |
| Danish crown officials | Danish, Latin | Latin, Danish charters | Forename plus family byname (e.g. Preen, `plausible composite` for the viceroy) | `attested` (Danish rule) |
| Low-German Hanseatic burghers | Middle Low German | MLG, Latin for deeds | Forename plus toponymic/occupational byname (*Osenbrygghe*, *de Lapide*) | `attested` |
| Westphalian vassal knights | MLG with Westphalian colouring, Latin | Charters in Latin/MLG | *von* + place; Christian names (Heinrich, Dietrich) | `attested` (Westphalian/Rhenish settlers) |
| Livonian Order brothers | MLG, Latin liturgy; Rhenish/Westphalian origin | Latin rule book, MLG correspondence | Brother + forename + origin | `attested` |
| Latin clergy | Latin; MLG and Estonian in preaching | Latin | Monastic names (Brother Hermann) | `attested` |
| Cistercians (Padise) | Latin; MLG for stewards | Latin | Forename only in religion | `attested` (abbey founded 1305 for monks of Dünamünde; stone building from 1317) |
| Dominicans (Reval), Franciscans | Latin, MLG | Latin | | `attested` (St Catherine's priory in Reval since 1246) |
| Pskovians and Novgorodians | Old Russian (Pskov and Novgorod dialects) | Cyrillic birch-bark and parchment | Patronymic: *Anisia Ivanova doch* style (see [anisia_of_novgorod.md](../CHARACTERS/anisia_of_novgorod.md)) | `attested` |
| Votians, Izhorians | Votic, Izhorian (Finnic) | Oral | Forename plus clan | `attested` (Votia/Ingria); in nodes `plausible composite` |
| Gotland / Visby merchants | MLG, Gotlandic-Swedish | MLG/Latin | | `attested` as Baltic trade community |
| Lithuanians (background only) | Lithuanian | none in play | | `attested` as Order opponents; no playable presence |
| Jewish or other minority | none attested in 1343 Estonian towns | n/a | | `plausible composite` that individual transient merchants exist, but unattested; **do not depict a community** |

## Table B: dress, religion, crafts
Wardrobe tokens are proposed `asset.wardrobe.*` ids using the shared rig/MPFB approach ([CHARACTER_GENERATION.md](../CHARACTER_GENERATION.md)).

| Community | Dress and wardrobe tokens | Religion and calendar anchors | Crafts and art objects |
|---|---|---|---|
| Harju Estonians | `asset.wardrobe.harju_peasant`: wool kirtle, belted apron, bast shoes, plaited headband, bronze brooch | Baptised; hiis memory; St George's Night 23 Apr, Midsummer (St John, 24 Jun), Martinmas/*mardisant*, All Souls (*hingedepäev*) | Copper-alloy brooches, wooden spoons and bowls, linen, birch-bark vessels |
| Saaremaa islanders | `asset.wardrobe.saaremaa_islander`: heavier wool, sheepskin vest, pewter/bronze ornaments | Same; harsh sea calendar; reputation for raiding Danes | Boats, stone masonry (Pöide), dolomite carvings |
| Sakala / Ugandi / Setu-Võro | `asset.wardrobe.sakala_peasant`, `asset.wardrobe.setu_woman` (heavy silver-style breast chains; label `plausible composite`, Setu silver is later evidence) | Latin and Orthodox mix in the south-east (Orthodox ties `plausible composite`) | Log farms, wool textiles, birch-bark, silver (later) |
| North-Viru Estonians | `asset.wardrobe.viru_coast` | Christian; fishermen's customs | Boats, nets, tarred rope |
| Läänemaa Estonians | `asset.wardrobe.laane_islander` | Christian; bishop's rule | Salt, cloth, wood carving |
| Estonian Swedes | `asset.wardrobe.swedish_coast_man`, `swedish_coast_woman`: longer coat, knitted cap, kerchief | Christian; own Saint days (St Olav, St Lucy `plausible composite`) | Boats, carved fittings, stone-fenced farms |
| Livs | `asset.wardrobe.liv_fisher` | Christian (converted 13th c.) | Fish smoking, amber |
| Finnish/Karelian traders | `asset.wardrobe.finnic_trader`: fur cap, belted coat, birch-bark satchel | Christian/Orthodox mix | Furs, tar, birch-bark |
| Danish officials | `asset.wardrobe.danish_official`: layered robe, coif | Latin rite; royal festivals | Charters, seals |
| Hanseatic burghers | `asset.wardrobe.burgher_male/female`: mid-calf tunic, hose, fur collar, keys | Latin rite; guild saint days; Corpus Christi `plausible composite` | Brass, pewter, cloth, brick, painted chests |
| Westphalian knights | `asset.wardrobe.knight_vassal`: mail, surcoat with arms (invented arms) | Latin; knightly saints | Arms, horse harness |
| Order brothers | `asset.wardrobe.order_brother`: white mantle with black cross, chain mail, kettle helm | Order rule, daily offices | Fortress masonry, armour |
| Latin clergy and orders | `asset.wardrobe.cistercian_white`, `dominican_black_white`, `franciscan_grey` | Liturgical year: [liturgical-calendar-spring-1343.md](../../history/dossiers/religion/liturgical-calendar-spring-1343.md) | Manuscripts, reliquaries, stained glass |
| Pskov/Novgorod Russians | `asset.wardrobe.rus_trader`: long caftan, fur hat, boots | Orthodox: Easter on its own date, icons | Icons (egg tempera), birch-bark letters, silverwork; *(not Pechory, Petseri 1473)* |
| Votians/Izhorians | `asset.wardrobe.votic_peasant` | Orthodox with pagan layer | Textile patterns, bronze |
| Gotland merchants | `asset.wardrobe.gotland_merchant` | Latin | Pewter, cloth, salt |

## Table C: nodes and the player's ears
| Community | Where they appear | How the player hears it |
|---|---|---|
| Harju Estonians | [harju_village.md](./harju_village.md), [sacred_grove.md](./sacred_grove.md), [rebel_kings_camp.md](./rebel_kings_camp.md), [kanavere_bog.md](./kanavere_bog.md), [sojamae.md](./sojamae.md) | Plain Estonian; the Apprentice understands by default |
| Saaremaa islanders | [saaremaa.md](./saaremaa.md), [poide_castle.md](./poide_castle.md) | Estonian tagged "island dialect"; subtitle note, no gate |
| South-Estonian / Setu | [viljandi_fellin.md](./viljandi_fellin.md), [otepaa_vastseliina_frontier.md](./otepaa_vastseliina_frontier.md), [soomaa_flood_refuge.md](./soomaa_flood_refuge.md), [tartu_dorpat.md](./tartu_dorpat.md) | Estonian with "southern" tag; unfamiliar rhythm, partial comprehension tag |
| North-Viru Estonians | [rakvere_wesenberg.md](./rakvere_wesenberg.md), [baltic_klint_coast.md](./baltic_klint_coast.md) | Plain Estonian |
| Läänemaa Estonians and Swedes | [haapsalu_laanemaa.md](./haapsalu_laanemaa.md), [baltic_klint_coast.md](./baltic_klint_coast.md) | Swedish lines tagged; short phrases only |
| Livs, Finnish traders | [parnu.md](./parnu.md) (harbour) | Single-word flavour, translated in subtitle |
| Danish officials | Reval (existing), [rakvere_wesenberg.md](./rakvere_wesenberg.md), [narva_peipus_east.md](./narva_peipus_east.md) | Latin formulae and plain subtitled Danish |
| Hanseatic burghers | Reval, [parnu.md](./parnu.md), [tartu_dorpat.md](./tartu_dorpat.md) | MLG with "Gode dagh" and similar |
| Westphalian knights, Order brothers | [paide_castle.md](./paide_castle.md), [padise_monastery.md](./padise_monastery.md) (Cistercian, not Order), [viljandi_fellin.md](./viljandi_fellin.md), [poide_castle.md](./poide_castle.md) | MLG, clipped command speech, Latin prayers |
| Latin clergy | [padise_monastery.md](./padise_monastery.md), [tartu_dorpat.md](./tartu_dorpat.md), [haapsalu_laanemaa.md](./haapsalu_laanemaa.md) | Latin chant, short quoted formulae |
| Pskov/Novgorod, Votians | [narva_peipus_east.md](./narva_peipus_east.md), [otepaa_vastseliina_frontier.md](./otepaa_vastseliina_frontier.md) | Russian tagged lines, bells distinct from Latin |
| Gotland merchants | [parnu.md](./parnu.md), Reval harbour | MLG with Gotlandic accent tag |
| Lithuanians | none (background) | Mentioned only |

## Language gating mechanics (restating CANON only)
Source: [CANON.md](../CANON.md), "Spirit world and the clairvoyant apprentice": *Language comprehension* is `invented` as a game skill; the languages themselves (Middle Low German, Estonian, Russian) are `attested`.
- The CANON language list is **Middle Low German, Estonian, Russian**. Latin, Swedish, Danish, Finnish and Livonian appear in dialogue as flavour phrases only; any full comprehension rule for them is **not defined** in CANON and is not proposed here.
- Where the skill matters, it is a **dialogue-option gate** in authored scenes, not a translation engine. Nothing in this page adds a new system, stat, or UI.
- Dialogue stays authored and offline ([AGENTS.md](../../AGENTS.md)). No free-text chat, no runtime LLM.
- Proposed content labels for authors only: `lang.estonian`, `lang.mlg`, `lang.russian` as tags on lines. Whether these become runtime ids is for the dialogue task, not this page.
- Registers follow the dossier: MLG for civic and commercial, Latin for church and charters, Estonian for labour and hinterland.

## Risks and open questions
- Setu, Võro and Seto identity formed later; use only "south-eastern Estonians" in dialogue and in-world labels.
- Estonian Swedes: avoid stereotype; keep them as fishermen, farmers and shipwrights. Their stretch of the north coast is `plausible composite`.
- Orthodox south-east vs Latin Dorpat: keep sectarian conflict as local colour, not a morality score (AGENTS.md out-of-scope).
- Jewish communities: unattested in 1343 Estonia; do not depict.
- Sensitivity: massacres (Sõjamäe, Paide) and ethnic hierarchy (Deutsch vs Undeutsch) must be shown through individuals, not caricature.
- Open question: should Swedish and Danish be fully understood by the Apprentice, or gated like Russian?

## Sources
[names-address-and-oaths.md](../../history/dossiers/language/names-address-and-oaths.md), [estonian-forenames-harju-1340s.md](../../history/dossiers/language/estonian-forenames-harju-1340s.md), [estonian-and-german-populations.md](../../history/dossiers/people/estonian-and-german-populations.md), [rural-smoke-dwelling-and-farmstead-1343.md](../../history/dossiers/architecture/rural-smoke-dwelling-and-farmstead-1343.md), [CANON.md](../CANON.md), [TOURIST_LANDMARKS.md](../TOURIST_LANDMARKS.md). Verification tasks: confirm Setu/Orthodox presence before 1400; confirm Estonian Swede date for Harju-Viru coast.
