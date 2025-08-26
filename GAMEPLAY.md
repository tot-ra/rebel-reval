# 🧙 Gameplay Mechanics

### The Living City: A World That Remembers
Your actions don't just complete quests; they ripple through the city of Reval, changing the world around you. The city's state is tracked through three interconnected meters, which are interpreted differently depending on your allegiance.

- **Rebel Morale (Hope):** Represents the confidence and boldness of the Estonian rebels and their sympathizers.
- Increases with: Public acts of defiance, successful sabotage against the rulers, distributing aid to the poor.
- Effects: More NPCs offer you shelter or information. Rebel graffiti appears on walls. Bards sing coded songs of rebellion. For rulers, this meter represents a rising tide of insurrection that must be stamped out.
- **Civic Order (Fear):** Reflects the grip and control of the ruling factions.
- Increases with: Public arrests, successful counter-insurgency missions, displays of military power.
- Effects: More guards patrol the streets. Harsher curfews are enforced. NPCs become tight-lipped and suspicious of rebel activity. For rebels, this meter represents a rising tide of oppression.

The city's state is a constant tug-of-war between Hope and Fear. Your actions as Kalev directly determine whether the populace feels emboldened enough to rise up or cowed enough to remain subservient.

### The Balance of Power
Chapter 1 is a strategic race against time. The goal is to shift the **Balance of Power** in your favor before the historical St. George's Night Uprising on April 23, 1343. This is represented by a single, dynamic meter that visualizes the struggle for control of Reval.

Completing quests for factions usually either increases faction power or reduces power of its enemies
**User's goal in chapter 1 is to reach**

```
<-- Chaos metric                                     Order metric   -->
<-- [ REBEL CONTROL ] -- | -- [ NEUTRAL ] -- | -- [ RULER CONTROL ] -->
[=======================|===================|=======================]
^                       ^                   ^                       ^
Power Uprising        Tenuous Peace       Order                 Desperation Uprising
(Chapter 2 Trigger) (Starting State)    (Ruler dominance)       (Chapter 2 Trigger)
```

Chaos = SUM(Rebels power) / SUM(Rebels power + Order power)
Order = SUM(Order power) / SUM(Rebels power + Order power)

#### Victory Conditions (Chapter 1)
To win Chapter 1, you must shift the Balance of Power decisively in your faction's favor. This is achieved through a combination of controlling strategic locations (towers) and winning the support of the populace (NPCs).

- **Towers:** There are **35 towers and gates** along the city wall. Controlling a majority of these (e.g., **18**) provides a significant strategic advantage. Each controlled tower offers benefits like revealing enemy movements, acting as a safe house, or reducing enemy patrols in the quarter.

- **NPC Allegiance:** The city is home to over **140 potential NPCs** in various locations. Each NPC has an allegiance score:
    - **-1:** Loyal to the Rulers
    - **0:** Neutral
    - **+1:** Sympathetic to the Rebels
    
    The **Balance of Power** meter is a direct reflection of the sum of all NPC allegiance scores. To trigger the "Power Uprising" as a rebel, you must reach a high positive score (e.g., +50). To win as a ruler, you must achieve a significant negative score (e.g., -50). Certain **influential NPCs** (like guild masters or clergy) hold more weight, with allegiance scores of +5 or -5, making them high-priority targets for persuasion.



### The Gameplay Loop: A Rebel's Day
The game operates on a dynamic day/night cycle, where each phase offers different opportunities and dangers, creating a core loop of preparation, action, and consequence. This loop remains consistent across both phases of the game, but the stakes and mission types will change dramatically.

#### The Inner World (The Soul's Journey)
Your actions in the physical world create ripples in your psyche. During sleep or meditation, you can travel to the **[Hingepuu (Soul Tree)](skills/GAMEPLAY-PSYCHE.md)**, your inner world. Here you will confront the consequences of your choices, commune with the archetypes of your soul, and tend to your **Seven Hearths** to grow your power. This inner journey is crucial for unlocking your full potential and understanding your place in the conflict.

#### Day (The Smith's Mask)
By day, you are Kalev the smith. The city is under the watchful eye of the Livonian Order.
- Crafting & Commerce: Fulfill orders for townsfolk and even the overlords to earn coin and gather intelligence. Crafting a perfect horseshoe for a knight's warhorse might reveal weaknesses in their patrols.
- Information Gathering: The streets are alive with gossip. Talk to merchants, beggars, and priests. Overhear conversations, bribe officials, and piece together the city's secrets.
- **Persuasion & Allegiance**: During the day, you can move through the city's quarters, visiting the homes and workplaces of its citizens. From the blacksmith in the east quarter to the wealthy merchant in the north, many inhabitants of Reval have their own stories, problems, and potential allegiances. By engaging with them and completing quests, you can persuade them to support your cause, whether it be for the rebels or the rulers. Each person you sway will shift the **Balance of Power**, bringing you one step closer to your goal.
- Preparation: Use your earnings and materials to upgrade your forge, craft better gear, or set up traps and dead-drops for your nighttime activities.

#### Night (The Shadow of Conflict)
When the sun sets, the city's true allegiances are revealed and the real work begins. The night is a time for covert operations, sabotage, and combat. Battles can erupt on the city streets, or you can fight for control of the city's many towers. Each tower under your faction's control provides a strategic advantage, such as reduced enemy patrols in the surrounding area or a safe haven for your allies.
- [GAMEPLAY-NIGHT](./GAMEPLAY-NIGHT.md)
- Missions & Covert Ops: Undertake quests for your chosen faction.
    - **Rebel Path:** Sabotage a Hanseatic crane, replace a knight's banner with a pig's head, or lead a jailbreak from the city dungeon.
    - **Ruler Path:** Infiltrate a rebel safe house, intercept a secret message from Pskov, or lead a night patrol to capture a key agitator.
- Exploration & Rituals: Explore forbidden areas like the Undercity or venture into the sacred groves to perform rituals that grant you new powers. The city's layout might change at night, with new paths opening and old ones becoming more dangerous.
- Action & Combat: Engage in fast-paced, top-down combat inspired by games like *Nox*. Use your smith's hammer, crafted weapons, and faction-granted abilities to overcome patrols, rival agents, and things that lurk in the dark.

- **Bloody moon**. At random, night can impact werewolves to become 2x stronger.
