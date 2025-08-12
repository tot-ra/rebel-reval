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



### The Gameplay Loop: A Rebel's Day
The game operates on a dynamic day/night cycle, where each phase offers different opportunities and dangers, creating a core loop of preparation, action, and consequence. This loop remains consistent across both phases of the game, but the stakes and mission types will change dramatically.

#### Day (The Smith's Mask)
By day, you are Kalev the smith. The city is under the watchful eye of the Livonian Order.
- Crafting & Commerce: Fulfill orders for townsfolk and even the overlords to earn coin and gather intelligence. Crafting a perfect horseshoe for a knight's warhorse might reveal weaknesses in their patrols.
- Information Gathering: The streets are alive with gossip. Talk to merchants, beggars, and priests. Overhear conversations, bribe officials, and piece together the city's secrets.
- Preparation: Use your earnings and materials to upgrade your forge, craft better gear, or set up traps and dead-drops for your nighttime activities.

#### Night (The Shadow of Conflict)
When the sun sets, the city's true allegiances are revealed and the real work begins, whether for rebellion or for control.
- [THE SIEGE OF REVAL](./GAMEPLAY-NIGHT.md)
- Missions & Covert Ops: Undertake quests for your chosen faction.
    - **Rebel Path:** Sabotage a Hanseatic crane, replace a knight's banner with a pig's head, or lead a jailbreak from the city dungeon.
    - **Ruler Path:** Infiltrate a rebel safe house, intercept a secret message from Pskov, or lead a night patrol to capture a key agitator.
- Exploration & Rituals: Explore forbidden areas like the Undercity or venture into the sacred groves to perform rituals that grant you new powers. The city's layout might change at night, with new paths opening and old ones becoming more dangerous.
- Action & Combat: Engage in fast-paced, top-down combat inspired by games like *Nox*. Use your smith's hammer, crafted weapons, and faction-granted abilities to overcome patrols, rival agents, and things that lurk in the dark.

- **Bloody moon**. At random, night can impact werewolves to become 2x stronger.
