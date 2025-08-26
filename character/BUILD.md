

See [PSYCHE](./PSYCHE.md) to better understand background of the character build system.

### NATURAL character build system

### Character Progression

At the start of the game, each of the seven NATURAL aspects (Nature, Affection, Tenacity, Unity, Resonance, Awareness, Light) begins with a base value of 5 points.

**Initial Point Allocation:**
- The player receives **10 additional points** to distribute among the seven aspects as they see fit during character creation.
- A single aspect can have a maximum of **10 points** at the start of the game (5 base + 5 player-allocated).

**Leveling Up:**
- Upon leveling up, the player receives **1 Aspect Point**.
- This point can be invested in any of the seven aspects to increase its value by one.
- Aspects can be leveled up to a maximum of **50 points**.
- Leveling up is achieved by gaining experience points through completing quests, winning battles, and discovering new locations.

#### ![](../assets/UI/character-hud/el-1.png) Nature
- **Core Stats:**
    - **Vitality:** Determines the character's raw health pool. Each point in Vitality adds +10 Health Points.
    - **Stability:** Governs resistance to being staggered or knocked down. Each point adds +2% to the Stability rating, reducing the chance of being interrupted by enemy attacks.
    - **Endurance:** Defines the character's stamina pool, used for sprinting, dodging, and power attacks. Each point adds +5 Stamina Points.
- **Gameplay:** In a land ravaged by conflict, a strong constitution is the bedrock of survival. High Vitality allows a warrior to withstand the brutal blows of a knight's mace and endure the harsh Estonian winters. Stability ensures one can hold their ground in a shield wall against a cavalry charge, while Endurance allows for forced marches through dense forests and swamps to outmaneuver the enemy.
- **Physical Influence:** Governs health pool, resistance to being knocked down.
- **Mental Influence:** Increases the power of `Earth` and `Metal` Elements. Increases duration of defensive spells.

#### ![](../assets/UI/character-hud/el-2.png) Affection
- **Core Stats:**
    - **Agility:** Increases movement speed and the effectiveness of dodges. Each point adds +1% to movement speed and dodge distance.
    - **Dexterity:** Boosts attack speed with light weapons and accuracy with ranged weapons. Each point adds +1% to attack speed and reduces weapon sway by 2%.
    - **Reaction Speed:** Determines the window for parrying and countering attacks. Each point increases the parry window by a small fraction of a second.
- **Gameplay:** The ability to move swiftly and strike precisely is crucial for a rebel fighting against better-equipped foes. Agility allows for dodging a Livonian sergeant's telegraphed attack, while Dexterity is key to landing a critical shot with a bow from the cover of the woods. High Reaction Speed can mean the difference between parrying a sword strike and feeling its bite.
- **Physical Influence:** Governs attack speed, dodge chance, and ranged accuracy.
- **Mental Influence:** Increases the power of `Water` and `Air` Elements. Reduces spell casting time.

#### ![](../assets/UI/character-hud/el-3.png) Tenacity
- **Core Stats:**
    - **Strength:** Increases damage with heavy weapons and the ability to wield heavier gear. Each point adds +2 to base melee damage.
    - **Raw Power:** Governs the ability to break through enemy blocks and guards. Each point adds +2% to guard break chance.
    - **Intimidation:** Affects dialogue choices and can cause weaker enemies to hesitate or flee in combat. Each point increases the chance of a successful intimidation check by 2%.
- **Gameplay:** In the brutal reality of the uprising, sheer force is often the only language the oppressors understand. Strength determines the might behind a peasant axe, capable of cleaving through a vassal's leather armor. Raw Power fuels the ability to break through a shield gate, while Intimidation can cause a wavering Hanseatic militiaman to lose his nerve and flee.
- **Physical Influence:** Governs melee damage, ability to break guards.
- **Mental Influence:** Increases the power of `Fire` and `Beast` Elements. Increases raw damage of offensive spells.

#### ![](../assets/UI/character-hud/el-4.png) Unity
- **Core Stats:**
    - **Charisma:** Improves prices with merchants and unlocks unique dialogue options. Each point provides a 1% discount with traders.
    - **Empathy:** Increases the effectiveness of companion characters and the potency of beneficial "shout" abilities. Each point adds +2% to companion damage and shout effectiveness.
    - **Healing Power:** Boosts the amount of health recovered from items and healing spells. Each point increases healing effectiveness by 2%.
- **Gameplay:** An uprising is built on trust and fellowship. Charisma can inspire fellow peasants to take up arms and rally them when morale falters. Empathy allows a leader to understand the needs and fears of their people, forging unbreakable bonds. In the aftermath of a skirmish, Healing Power, whether through poultices or prayer, is vital to mend the wounded and preserve the strength of the rebellion.
- **Physical Influence:** Governs effectiveness of ally-affecting shouts.
- **Mental Influence:** Increases the power of `Life` and `Hope` Elements. Increases potency of healing/support spells.

#### ![](../assets/UI/character-hud/el-5.png) Resonance
- **Core Stats:**
    - **Persuasion:** Increases the chance of success in dialogue checks to convince NPCs. Each point adds +2% to the success chance of persuasion attempts.
    - **Deception:** Increases the chance of success in dialogue checks to lie or mislead NPCs. Each point adds +2% to the success chance of deception attempts.
    - **Leadership:** Determines the number of followers you can command and their overall effectiveness in combat. Each point increases the follower limit and their combat stats by 1%.
- **Gameplay:** The rebellion is a war fought not just with swords, but with words. Persuasion is needed to convince a skeptical village elder to join the cause or a Swedish bailiff to offer aid. Deception can be used to lure a patrol of knights into an ambush or spread disinformation within the walls of Reval. True Leadership turns a disorganized mob into a disciplined fighting force, capable of executing complex strategies.
- **Physical Influence:** Governs effectiveness of intimidation/rally cries.
- **Mental Influence:** Increases the power of `Deception` and `Dominion` Elements. Increases potency of crowd control spells.

#### ![](../assets/UI/character-hud/el-6.png) Awareness
- **Core Stats:**
    - **Perception:** Governs the ability to detect traps, hidden items, and enemy weaknesses. Each point increases the detection range by 0.5 meters.
    - **Wisdom:** Increases the amount of experience gained from all sources. Each point adds +1% to experience gain.
    - **Spell Cooldown:** Reduces the cooldown time for all spells and abilities. Each point reduces cooldowns by 0.5%.
- **Gameplay:** In a land where betrayal is common and the enemy is everywhere, keen senses are essential. High Perception can spot a hidden tripwire on a forest path or notice the glint of an archer's helm in the distance. Wisdom, born from experience, helps in making sound tactical decisions, like choosing the right time to attack or when to retreat. For those who wield the old magic, it also governs the ability to channel power more frequently.
- **Physical Influence:** Governs ability to spot traps, critical hit chance.
- **Mental Influence:** Increases the power of `Mind` and `Time` Elements. Reduces spell cooldowns.

#### ![](../assets/UI/character-hud/el-7.png) Light
- **Core Stats:**
    - **Faith:** Increases the power of divine magic and resistance to demonic or unholy attacks. Each point adds +2% to divine spell power.
    - **Spirit:** Determines the size of the "Willpower" (mana) pool. Each point adds +10 Willpower.
    - **Elemental Connection:** Boosts the damage and effectiveness of all elemental magic (Earth, Fire, Water, Air, etc.). Each point adds +1% to elemental damage.
- **Gameplay:** In the darkest of times, it is faith that sustains the rebellion. This is not just belief in the Christian God, but also in the old ways and the spirits of the land. A strong Spirit provides the willpower to resist the psychological warfare of the Church and the Order. A deep Elemental Connection allows a character to draw upon the ancient powers of the land, weaving potent spells that can turn the tide of battle.
- **Physical Influence:** Governs "Willpower" (mana) pool.
- **Mental Influence:** Increases the power of `Faith` and `Spirit` Elements. Unlocks 4-Element spellforging.


![alt text](../assets/UI/character-hud/background.png)

![alt text](../assets/UI/character-hud/character-zoomed.png)
