# Reval Rebel

Indie Action RPG withg rogue-like elements in semi-fictional 14th-century Estonia. Features rogue-like game elements, AI-NPCs, 2d (hex-isometric) views.

A moody, atmospheric feel that blends Hanseatic trade, Baltic folklore, and early Christianity with a touch of gallows humor. 

Inspired by Hades, Fallout, Disco Elysium, Skyrim, Conan the Cimmerian, Rome 42 AD.

Current state: `Drafting game design document & concept art`

![](./img/intro-preview.png)


## 📖 Core Narrative
The year is 1342. A fragile peace hangs over Reval, but the air is thick with resentment. The St. George's Night Uprising is a spark waiting to ignite.

"Reval Rebel" casts you as __Kalev__, a smith from the lower town who stands at the crossroads of history. You want nothing more than to be left alone, but the city itself is a powder keg. Estonian peasants whisper of rebellion, Hanseatic merchants tighten their grip, and the knights of the Livonian Order watch over all with an iron fist. You are dragged into the simmering conflict when a secret is entrusted to you—a plan, a weapon, a truth—that could either start the uprising or crush it before it begins.  

Caught between the ruthless Livonian Order, the scheming merchants, and the ancient, chaotic power of the land itself, you must decide where your loyalties lie. Your choices will determine not if the rebellion happens, but how.

Will you become the hero your people whisper about — a new "Kalevipoeg", or will you forge your own path to order and civilization through the chaos, using your wits and your hammer to survive? The choices you make will determine whether the rebellion becomes a footnote in history or the dawn of a new era.

- [HERO ABILITIES](./assets/player/)
- [NPC FACTIONS](./assets/characters/)
- [LOCATIONS](./scenes/)
- [STORYLINE](./STORY.md)
- [BESTIARY](./assets/bestiary/)
- [HISTORICAL CONTEXT](./HISTORY.md)


## 🧙 Gameplay Mechanics

### The Living City: A World That Remembers
Your actions don't just complete quests; they ripple through the city of Reval, changing the world around you. The city's state is tracked through three interconnected meters, which are interpreted differently depending on your allegiance.

- **Rebel Morale (Hope):** Represents the confidence and boldness of the Estonian rebels and their sympathizers.
- Increases with: Public acts of defiance, successful sabotage against the rulers, distributing aid to the poor.
- Effects: More NPCs offer you shelter or information. Rebel graffiti appears on walls. Bards sing coded songs of rebellion. For rulers, this meter represents a rising tide of insurrection that must be stamped out.
- **Civic Order (Fear):** Reflects the grip and control of the ruling factions.
- Increases with: Public arrests, successful counter-insurgency missions, displays of military power.
- Effects: More guards patrol the streets. Harsher curfews are enforced. NPCs become tight-lipped and suspicious of rebel activity. For rebels, this meter represents a rising tide of oppression.
- **Chaos**: Measures the level of open conflict and instability in the city.
- Increases with: Starting riots, pitting factions against each other, large-scale destruction.
- Effects: Faction skirmishes break out in the streets. Looting opportunities arise. The city's elite may hire mercenaries, creating new, dangerous foes. The Undercity becomes a hotbed of frantic activity.

These meters are not mutually exclusive. A city can be both hopeful and chaotic, leading to a full-blown, bloody revolution. Or it can be fearful and chaotic, descending into a brutal, lawless free-for-all. Your actions as Kalev directly shape the kind of rebellion that unfolds.

### The Gameplay Loop: A Rebel's Day
The game operates on a dynamic day/night cycle, where each phase offers different opportunities and dangers, creating a core loop of preparation, action, and consequence. This loop remains consistent across both phases of the game, but the stakes and mission types will change dramatically.

- Day (The Smith's Mask): By day, you are Kalev the smith. The city is under the watchful eye of the Livonian Order.
- Crafting & Commerce: Fulfill orders for townsfolk and even the overlords to earn coin and gather intelligence. Crafting a perfect horseshoe for a knight's warhorse might reveal weaknesses in their patrols.
- Information Gathering: The streets are alive with gossip. Talk to merchants, beggars, and priests. Overhear conversations, bribe officials, and piece together the city's secrets.
- Preparation: Use your earnings and materials to upgrade your forge, craft better gear, or set up traps and dead-drops for your nighttime activities.

- Night (The Shadow of Conflict): When the sun sets, the city's true allegiances are revealed and the real work begins, whether for rebellion or for control.
- Missions & Covert Ops: Undertake quests for your chosen faction.
    - **Rebel Path:** Sabotage a Hanseatic crane, replace a knight's banner with a pig's head, or lead a jailbreak from the city dungeon.
    - **Ruler Path:** Infiltrate a rebel safe house, intercept a secret message from Pskov, or lead a night patrol to capture a key agitator.
- Exploration & Rituals: Explore forbidden areas like the Undercity or venture into the sacred groves to perform rituals that grant you new powers. The city's layout might change at night, with new paths opening and old ones becoming more dangerous.
- Action & Combat: Engage in fast-paced, top-down combat inspired by games like *Nox*. Use your smith's hammer, crafted weapons, and faction-granted abilities to overcome patrols, rival agents, and things that lurk in the dark.

### Fight Mechanics: The Art of Battle
Combat in "Reval Rebel" is designed to be deliberate and tactical, rewarding careful positioning and resource management.

-   **Core Combat Loop (Stamina-Based):** Every action in combat—attacking, dodging, blocking, and sprinting—consumes Stamina. Stamina regenerates over time, but running out leaves you vulnerable. This system encourages a thoughtful rhythm of offense and defense, preventing players from simply spamming attacks.
-   **Poise & Stagger System:** Both Kalev and his enemies possess a hidden "Poise" meter. Taking successive hits depletes this meter. Once broken, the character is staggered, interrupting their action and leaving them open to a devastating critical hit or a powerful follow-up attack. Heavier weapons are more effective at breaking poise.
-   **Weapon Archetypes:** Kalev can wield a variety of weapons, each with a unique moveset, attack speed, and damage type.
    -   **Smith's Hammer (Blunt):** Slow, heavy swings that excel at breaking enemy poise and shattering armor.
    -   **Short Sword (Slashing):** Fast, fluid attacks that allow for quick combos and high mobility.
    -   **Axe (Slashing/Blunt):** A balanced weapon that can cleave through multiple unarmored foes or deliver a powerful overhead chop.
    -   **Spear (Piercing):** Offers superior range, allowing you to poke at enemies from a safe distance. Effective against armored targets.
-   **Damage Calculation:** The damage dealt is determined by a combination of your weapon's power, your abilities, and the enemy's defenses. A simplified formula is:
    `Final Damage = (Base Weapon Damage + Ability Damage) * (1 - (Target's Armor Value / 100))`

### The Grudge System: Turning Failure into Vengeance
Defeat in "Reval Rebel" is not an end, but a new beginning. When Kalev is defeated, he doesn't just respawn. He awakens with a **Grudge**, a new, personal objective aimed at the person or faction that defeated him. This system transforms failure from a frustrating setback into a narrative and gameplay opportunity.

- How Grudges are Generated: A Grudge is generated whenever you are defeated in combat. The nature of the Grudge depends on who defeated you and where (e.g., defeated by a named knight, captured by the city guard).
- Grudge Mechanics: A Grudge appears as a unique quest. The target of your Grudge becomes a more significant presence in the world, and the Grudge unlocks unique gameplay paths to resolve the conflict.
- Resolving a Grudge: Completing a Grudge quest yields significant rewards, including unique loot, faction standing, and a major boost to the **Hope** meter.

### World-Impacting Abilities: Leaving Your Mark
Certain high-tier abilities, particularly faction ultimates, are designed to have a permanent or semi-permanent impact on the game world. These actions are significant and will cause major shifts in faction power, NPC behavior, and the physical environment. For example, the Pagan Cult's `Heart of the Forest` can create a permanent "Pagan Scar" on a city district, altering its appearance and the balance of power within it.

### Core Feature: AI-Driven NPCs
To create a truly living and unpredictable world, every NPC in Reval, from the highest-ranking knight to the lowliest beggar, is controlled by an independent AI model. This system moves beyond traditional, scripted behavior, allowing for emergent narratives and a deeply reactive game world.

- Dynamic Goals & Schedules: Each NPC has their own set of goals, fears, and relationships. A merchant's primary goal is profit, but he might also fear the Livonian Order and have a secret sympathy for the rebellion. These motivations dictate their daily schedules and how they react to the player and the changing state of the city.
- Reactive Dialogue: NPC conversations are not chosen from a pre-written tree. Instead, their responses are generated in real-time based on:
- Your Actions: If you've been seen brawling in the streets, NPCs will comment on it. If you've been generous, they'll thank you.
- The City State: In a city gripped by **Fear**, NPCs will be tight-lipped and suspicious. In a city filled with **Hope**, they will be more open and willing to share information.
- Their Personal Relationship with You: An NPC you've helped will greet you warmly, while one you've wronged will be hostile or dismissive.
- Emergent Behavior: Because NPCs are not on fixed scripts, they can react to events in unpredictable ways. A riot might cause a merchant to hire extra guards, or a food shortage might lead a normally law-abiding citizen to steal. This creates a world that feels alive and constantly evolving.
- Integration with Gameplay Systems: The AI-driven NPCs are the engine that drives the "Living City." Your attempts to manipulate the **Hope**, **Fear**, and **Chaos** meters are essentially attempts to influence the collective mood and behavior of the city's AI inhabitants.



## 🎨 Visual Style
Color Palette: Earth tones, candlelight glow, icy blues and mossy greens.
Style: Inspired by Baltic woodcut art, stained-glass motifs, and illuminated manuscripts, but with surreal twists.
Architecture: Gothic and Hanseatic, but slowly overtaken by creeping pagan symbols.

## 🎻 Music & Sound
Soundtrack: Blend of medieval Baltic folk (kantele, runosong) with ambient electronics and minimalistic ritual drums.
Dynamic Sound Design: Pagan areas filled with whispers and wind chimes; Christian zones echo with choirs and bells.
