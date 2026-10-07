> **Legacy status:** `reference`  
> **Reason:** Expanded faction and NPC roster returns to the production plan under [ADR 0017](../docs/adr/0017-legacy-design-reintroduction.md); sheets here are seeds until promoted into `docs/CHARACTERS/`.  
> **Scope reconciliation:** [ADR 0008](../docs/adr/0008-three-act-campaign-and-faction-scope.md), [ADR 0017](../docs/adr/0017-legacy-design-reintroduction.md), [`docs/LEGACY_REINTRODUCTION.md`](../docs/LEGACY_REINTRODUCTION.md)  
> **Reactivating via ADR 0017:** eight launch factions plus bishopric / Blackheads / Lizard Union / Lithuania / Golden Horde candidates; named NPC hooks for act production.  
> **Still out as primary frame:** mandatory early ruler/rebel join menu (allegiance still emerges from play).  
> **Art note:** portraits and pixel sheets are inspiration; new shared-rig models required.  
> **Current source of truth:** [`README.md`](../README.md) and `docs/CHARACTERS/` for active briefs; promotion order and faction-candidate decisions are in [`docs/cast_faction_promotion.md`](../docs/cast_faction_promotion.md) (P7-009).

## ⚔️ Factions
You can ally, betray, or infiltrate these political forces. Your actions will determine the fate of Reval and the future of Estonia. Each faction offers unique quests, abilities, and endings.

**USER MUST CHOOSE TO JOIN EITHER RULERS OR REBELS**

### Ruling Factions

These factions represent the established, foreign powers ruling over Reval. 
They represent civilization, Christianity, stability, power, hierarchy, and advanced resources, but at the cost of natives freedom.

### 1. **The Danish Crown** 🇩🇰 
-   **Core Value:** Legacy
-   **Ideal:** To uphold their ancestral claim and the divine right of kings, providing stability as the legitimate rulers.
-   **Shadow:** Their obsession with legacy makes them out of touch, willing to tax their subjects into ruin to maintain a fading glory.
-   **Core NPC:** [Viceroy Konrad Preen](denmark/viceroy_konrad_preen.md)
-   **Presence:** [Toompea Castle](../scenes/revel_west_toompea/domberg/domberg.md)

### 2. **The Hanseic Big League** 🇪🇺
-   **Core Value:** Prosperity
-   **Ideal:** To build a world of opportunity and wealth through trade, connecting cultures and funding innovation.
-   **Shadow:** Their pursuit of profit becomes all-consuming greed, where human lives and traditions are exploited for coin.
-   **Core NPC:** [Jürgen von League](hansa/jurgen_von_league.md)
-   **Presence:** [St. Olaf's Guild Hall](../../scenes/lower_town/st_olafs_guild_hall.md), [Reval Harbor](../../scenes/lower_town/harbor.md)


### 3. **The Livonian Order** ✠ 
-   **Core Value:** Order
-   **Ideal:** To create a stable, pious society under a single faith and a strong rule of law.
-   **Shadow:** Their pursuit of order becomes brutal fanaticism, justifying massacres and cultural destruction in the name of God. Their banner is the black cross of the Teutonic Order on a white field, a symbol of their military might and holy purpose.
-   **Core NPCs:** 
    - [Master Burchard von Dreileben](order/master_burchard_von_dreileben.md)
    - [Brother Goswin von Herike](order/brother_goswin_von_herike.md)
    - [Arnd von Herke](arnd_von_herke.md)
-   **Presence:** [Toompea Castle](../scenes/revel_west_toompea/domberg/domberg.md), [The Cathedral of Saint Mary](../scenes/revel_west_toompea/cathedral_of_saint_mary/cathedral_of_saint_mary.md), [Viljandi Castle](../../scenes/world/viljandi_castle.md), [Padise Monastery](../scenes/world/padise/padise_monastery.md). Wesenberg is a mentioned location without a specific scene.


### The Bishopric Factions ✝️

These factions represent the ecclesiastical princes of the Livonian Confederation, ruling their territories as sovereign states. They wield both spiritual and temporal power, often finding themselves in conflict with the Livonian Order and other factions.

#### 4. **The Archbishopric of Riga** ⛪️
-   **Core Value:** Faith
-   **Ideal:** To guide the souls of Livonia towards salvation, maintaining the church as the moral and spiritual center of the land.
-   **Shadow:** Their piety can become a mask for ambition, using their spiritual authority to amass wealth and political power.
-   **Core NPC:** [README](bishopric_riga/)
-   **Presence:** [Riga Cathedral](../../scenes/world/riga/riga_cathedral.md)

#### 5. **The Bishopric of Dorpat** 📚
-   **Core Value:** Knowledge
-   **Ideal:** To be a beacon of learning and theology, preserving ancient wisdom and fostering education in a savage land.
-   **Shadow:** Their pursuit of knowledge can lead to arrogance and isolation, viewing the struggles of the common folk as beneath their notice.
- NPCs
	- [Prince-Bishop Johann I von Vifhusen](bishopric_dorpat/prince_bishop_johann.md)
	* [Voivode Grigori of Pskov](bishopric_dorpat/voivode_grigori.md)
	* [Meelis of Otepää](bishopric_dorpat/meelis_of_otepaa.md)
	* [Sir Matthias von Löwenwolde](bishopric_dorpat/sir_matthias_von_lowenwolde.md)
	* [Klaus von Rutenberg](bishopric_dorpat/klaus_von_rutenberg.md)
	* [Brother Andreas](bishopric_dorpat/brother_andreas.md)
-   **Presence:** [Dorpat Cathedral](../../scenes/world/dorpat/dorpat_cathedral.md)

#### 6 **The Bishopric of Ösel-Wiek** 🌊
-   **Core Value:** Independence
-   **Ideal:** To safeguard their flock and their lands from the ambitions of larger powers, maintaining a delicate balance of diplomacy and defense.
-   **Shadow:** Their desire for independence can turn into paranoia and treachery, making them unreliable allies in the fight against greater threats.
-   **Core NPC:** [hermann_osenbrugge](bishopric_osel_wiek/hermann_osenbrugge.md)
-   **Presence:** [Haapsalu Castle](../../scenes/world/osel_wiek/haapsalu_castle.md)


### The Rebel Factions ✊🏻
-   **Core Value:** Freedom
-   **Ideal:** To rule their own lands, free from foreign masters.
-   **Shadow:** Their fight for freedom can become violent xenophobia, leading to the slaughter of any and all outsiders.

These factions represent the native Estonian resistance. 
They represent rebellion, decentralization, grassroot nature powers, flexibility.
They are outgunned and outmaneuvered, but they have the support of the people and a deep connection to the land itself.

#### 7. [**The Harju Kings** ✊](./characters/rebels/)
-   **Motivation:** Freedom. The main, rural-based military force of the uprising, born in the fields of Harju County. They are farmers and villagers who have taken up arms against their oppressors. They are the heart of the rebellion's military power, fighting in open battles.
-   **Core NPCs:** 
    - [Lembit Helme](rebels/lembit_helme.md)
    - [Kaja Lahekivi](rebels/kaja_lahekivi.md)
    - [Jüri Ratnik](rebels/juri_ratnik.md)
    - [Urmas Laar](rebels/urmas_laar.md)
-   **Presence:** [Harju Village](../../scenes/world/harju_village.md), [The Rebel Kings' Camp](../../scenes/events/rebel_kings.md), [Pärnu](../../scenes/events/pernau.md).



#### 8. **The Black Cloaks** 🐦
-   **Motivation:** Liberation from the inside. Radicals / terrorists. The urban guerilla arm of the rebellion within Reval's walls. Composed of smiths, artisans, and the city's underclass, they specialize in stealth, sabotage, intelligence, and street-level warfare.
-   **Core NPC:** [martin_the_blacksmith](rebels/martin_the_blacksmith.md)
-   **Presence:** [The Smith's Forge](../../scenes/lower_town/the_smiths_forge.md), [Reval Market](../../scenes/lower_town/market.md), [Reval Harbor](../../scenes/lower_town/harbor.md).



#### 9 **The Cult of Metsik** 🍀
-   **Motivation:** The Old Ways. A secretive cult of forest-dwellers who worship the ancient Estonian gods. They see the Christian invaders as a plague upon the land and believe that the uprising is a chance to restore the old ways. Their magic is powerful and chaotic, drawn from the sacred groves and the spirits of the earth.
-   **Core NPC:** [Ellen Luik](metsik_cult/ellen_luik.md)
-   **Presence:** [The Sacred Grove](../../scenes/world/sacred_grove.md). The Sacred Lake on Saaremaa is a mentioned location within the [Saaremaa event](../../scenes/events/saaremaa.md).

### The Neutral Factions

These factions are not directly involved in the conflict between the Rulers and the Rebels, but they have their own agendas and can be powerful allies or dangerous enemies.

#### 10. **The Republic of Novgorod** 🌞
-   **Core Value:** Opportunity
-   **Ideal:** To expand their influence and trade through shrewd alliances and military might, seizing the chances that chaos provides.
-   **Shadow:** Their pragmatism is a mask for ruthless opportunism; they are mercenaries who will betray any ally for a better deal.
-   **Core NPCs:** 
    - [Яна Подаяльная](novgorod/jana_podajalnaja.md)
    - [Goytan](novgorod/goytan.md)
    - [Prokhor of Gorodets](novgorod/prokhor_of_gorodets.md)
    - [Sergius of Radonezh](novgorod/radonezhski.md)
-   **Presence:** [Reval Market](../../scenes/lower_town/market.md), [St. Olaf's Guild Hall](../../scenes/lower_town/st_olafs_guild_hall.md).

#### 11. **The Republic of Pskov** 🐆
-   **Core Value:** Independence
-   **Ideal:** To forge their own path, free from the shadows of both Novgorod and the Livonian Order.
-   **Shadow:** Their fierce desire for independence can lead to isolationism and paranoia, making them mistrustful of potential allies.
-   **Core NPC:** [Михаил Коловрат](pskov/mihail_kolovrat.md)
-   **Presence:** [Reval Market](../../scenes/lower_town/market.md), hidden camps in the surrounding forests.

#### 11. **The Brotherhood of Blackheads**
-   **Motivation:** The Long Game & Prosperity. A guild of unmarried merchants, ship-owners, and foreigners. The Brotherhood is aiming to create an independent Reval under their control.
-   **Core NPCs:** 
    - ["Mart the Weaver"](blackhead/mart_the_weaver.md)
    - [Johann von Minden](blackhead/johann_von_minden.md)
    - [Hinrik the Cartographer](blackhead/hinrik_the_cartographer.md)
-   **Presence:** [St. Olaf's Guild Hall](../../scenes/lower_town/st_olafs_guild_hall.md). The House of the Blackheads is a mentioned location without a specific scene.


#### 12. **The Vitalienbrüder** 🏴‍☠️
-   **Motivation:** Plunder and chaos. The remnants of a once-powerful pirate brotherhood, now reduced to a scattered band of raiders and mercenaries. They have no loyalty to any flag and are interested only in profiting from the chaos of the uprising. They are masters of naval combat and can be hired to attack shipping, smuggle goods, or create diversions.
-   **Core NPC:** ["Ironhand" Störtebeker](pirates/ironhand_stortebeker.md)
-   **Presence:** [Paldiski](../../scenes/events/paldiski.md), [Reval Harbor](../../scenes/lower_town/harbor.md).

#### 13. **The Lizard Union** 🦎
-   **Motivation:** Ambition. A clandestine fraternity of disaffected Prussian and German-Baltic nobles, wealthy merchants, and disillusioned knights. They see the uprising as an opportunity to dismantle the power of the Livonian Order and seize control for themselves.
-   **Core NPC:** [Nikolaus von Danzig](lizard_union/nikolaus_von_danzig.md)
-   **Presence:** [Reval Market](../../scenes/lower_town/market.md), [The Serpent's Coil (Hidden Cellar)](../../scenes/lower_town/serpents_coil.md).

#### 14. **The Grand Duchy of Lithuania** 🇱🇹
-   **Core Value:** Defiance
-   **Ideal:** To preserve their pagan traditions and forge a powerful, independent empire in the face of crusading knights and rival powers.
-   **Shadow:** Their fierce independence can manifest as brutal expansionism, viewing their neighbors as potential conquests rather than allies.
-   **Core NPC:** [Algirdas](famous/algirdas.md)
-   **Presence:** [The Sacred Grove](../../scenes/world/sacred_grove.md)

#### 15. **The Golden Horde** ურდოს
-   **Core Value:** Dominion
-   **Ideal:** To maintain the vast, multicultural "Pax Mongolica," a world of open trade and swift justice under the unquestioned authority of the Khan.
-   **Shadow:** Their rule is one of brutal extraction and intimidation; they are distant overlords who demand tribute and punish defiance with overwhelming force.
-   **Core NPC:** [Jani Beg Khan](famous/jani_beg_khan.md)
-   **Presence:** [Reval Market](../../scenes/lower_town/market.md)

## All files in this folder

<!-- docs-index:start (generated by tools/docs_index.py; do not edit) -->

#### `bishopric_dorpat/`

- [Bishopric of Dorpat](bishopric_dorpat/README.md)

#### `bishopric_osel_wiek/`

- [Bishopric of Ösel–Wiek](bishopric_osel_wiek/README.md)

#### `clergy/`

- [Brother Alcuin](clergy/brother_alcuin/brother_alcuin.md)
- [Priest's Emissary](clergy/emissary.md)

#### `denmark/`

- [Town Guard Captain](denmark/town_guard/captain.md)

#### `famous/`

- [Albert of Saxony](famous/albert_of_saxony.md)
- [Ambrogio Lorenzetti (c. 1290–1348)](famous/ambrogio_lorenzetti.md)
- [Andrei Rublev (c. 1360-1370 - c. 1427/1430)](famous/andrei_rublev.md)
- [Berthold Schwarz](famous/berthold_schwarz.md)
- [Giovanni Boccaccio](famous/giovanni_boccaccio.md)
- [Giovanni Dondi dell'Orologio](famous/giovanni_dondi_dell_orologio.md)
- [Guillaume de Machaut](famous/guillaume_de_machaut.md)
- [Ibn Battuta](famous/ibn_battuta.md)
- [Jean Buridan](famous/jean_buridan.md)
- [John Mandeville (Author) (fl. 14th Century)](famous/john_mandeville.md)
- [Levi ben Gershon (Gersonides) (1288–1344)](famous/levi_ben_gershon.md)
- [Magnus IV Eriksson](famous/magnus_iv_eriksson.md)
- [Nicole Oresme](famous/nicole_oresme.md)
- [Peter of Denmark](famous/peter_of_denmark.md)
- [Petrarch (Francesco Petrarca)](famous/petrarch.md)
- [(Prince) Ivan of Pskov](famous/prince_ivan_of_pskov.md)
- [Richard Rolle](famous/richard_rolle.md)
- [Semyon Ivanovich (Simeon the Proud)](famous/semyon_ivanovich.md)
- [Theophanes the Greek (b. c. 1330)](famous/theophanes_the_greek.md)
- [Thomas Bradwardine (c. 1300–1349)](famous/thomas_bradwardine.md)
- [Valdemar IV Atterdag](famous/valdemar_iv_atterdag.md)
- [William of Ockham](famous/william_of_ockham.md)

#### `forge_folk/`

- [Young Apprentice Juhan](forge_folk/juhan/juhan.md)
- [Old Toomas](forge_folk/old_toomas/old_toomas.md)

#### `hansa/`

- [Bjorn](hansa/bjorn/bjorn.md)
- [Ivar](hansa/ivar/ivar.md)

#### `lizard_union/`

- [The Lizard Union 🦎](lizard_union/README.md)

#### `merchants/`

- [Dietrich](merchants/dietrich/dietrich.md)
- [Wealthy Merchant's Wife](merchants/merchants_wife.md)

#### `metsik_cult/`

- [The Metsik Pagan Cult](metsik_cult/README.md)

#### `order/`

- [Rulers](order/README.md.md)
- [Livonian Order Squire](order/squire.md)

#### `peasants/`

- [Disgruntled Farmer](peasants/disgruntled_farmer.md)
- [Farmer with a Broken Plow](peasants/farmer_broken_plow.md)

#### `rebels/`

- [Black Cloak Forger](rebels/black_cloaks/forger.md)
- [The Mute Harpist](rebels/black_cloaks/harpist/mute_harpist.md)
- [Black Cloak Healer](rebels/black_cloaks/healer.md)
- [Mysterious Woman in a Black Cloak](rebels/black_cloaks/mysterious_woman.md)
- [Black Cloak Scout](rebels/black_cloaks/scout.md)
- [Black Cloak Strategist](rebels/black_cloaks/strategist.md)
- [Black Cloak Weapons Master](rebels/black_cloaks/weapons_master.md)

#### `streets/`

- [Child with a Toy Sword](streets/child_sword/child_sword.md)
- [Gossip-Mongering Neighbor](streets/gossip_neighbor/gossip_neighbor.md)
- [Traveling Peddler](streets/peddler/peddler.md)
- [Runaway Serf](streets/runaway_serf/runaway_serf.md)

#### `workers_quarter/`

- [Albrecht](workers_quarter/albrecht/albrecht.md)
- [Old Elga](workers_quarter/elga/elga.md)
- [Elsa](workers_quarter/elsa/elsa.md)
- [Erik](workers_quarter/erik/erik.md)
- [Friedrich](workers_quarter/friedrich/friedrich.md)
- [Greta](workers_quarter/greta/greta.md)
- [Gustav](workers_quarter/gustav/gustav.md)
- [Hendrik](workers_quarter/hendrik/hendrik.md)
- [Hinrik](workers_quarter/hinrik/hinrik.md)
- [Ingrid](workers_quarter/ingrid/ingrid.md)
- [Jaan](workers_quarter/jaan/jaan.md)
- [Kael](workers_quarter/kael/kael.md)
- [Kaspar](workers_quarter/kaspar/kaspar.md)
- [Katrin](workers_quarter/katrin/katrin.md)
- [Knut](workers_quarter/knut/knut.md)
- [Lars](workers_quarter/lars/lars.md)
- [Lembit](workers_quarter/lembit/lembit.md)
- [Liina](workers_quarter/liina/liina.md)
- [Marek](workers_quarter/marek/marek.md)
- [Markus](workers_quarter/markus/markus.md)
- [Niklas](workers_quarter/niklas/niklas.md)
- [Nikolaus](workers_quarter/nikolaus/nikolaus.md)
- [Otto](workers_quarter/otto/otto.md)
- [Peeter](workers_quarter/peeter/peeter.md)
- [Rein](workers_quarter/rein/rein.md)
- [Sten](workers_quarter/sten/sten.md)
- [Tomas](workers_quarter/tomas/tomas.md)
- [Valentin](workers_quarter/valentin/valentin.md)
- [Walter](workers_quarter/walter/walter.md)

<!-- docs-index:end -->
