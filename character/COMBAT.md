# ⚔️ Combat Mechanics

Combat in Reval is a brutal and tactical affair, blending visceral melee, calculated ranged attacks, and the world-shaping power of **[spellforging](MAGIC-ELEMENTS.md)**. A successful warrior must master not only their weapon but also the flow of battle, knowing when to press the attack, when to defend, and when to unleash their inner power.

## 🎯 Core Combat Concepts

-   **Stamina Management:** Every action in combat—attacking, dodging, blocking, and sprinting—consumes stamina. Managing your stamina is crucial. Exhausting it will leave you winded and vulnerable to a devastating counter-attack.
-   **Attack & Defense:** Combat revolves around a system of light attacks, heavy attacks, blocks, and dodges.
    -   **Light Attacks:** Fast but do less damage. Good for interrupting weaker foes.
    -   **Heavy Attacks:** Slow but powerful. Can break an enemy's guard but leave you open if you miss.
    -   **Blocking:** Using a weapon or shield to absorb incoming damage. Reduces stamina. A perfectly timed block can create a parry opportunity.
    -   **Dodging:** A quick maneuver to evade an attack entirely. Consumes a significant amount of stamina.
-   **Poise & Stagger:** Both the player and enemies have a hidden "poise" meter. Heavier armor increases poise. Taking hits drains poise. Once poise is depleted, the character is staggered, interrupting their action and leaving them open to a critical hit.

---

## 🛡️ Weapon Types

The armories of 14th-century Estonia are diverse, reflecting the clash of cultures and technologies. Weapons are categorized by their type and the skills required to wield them effectively.

### 🗡️ Melee Weapons

**One-Handed Weapons:** Can be wielded with a shield or in conjunction with a free hand for casting.
-   **Swords:** Versatile weapons that balance speed and damage. Effective against lightly armored foes.
    -   *Stats:* Damage: 18-25 | Speed: Fast | Guard Break: Low
    -   *Primary Aspect(s): Affection, Tenacity*
-   **Axes:** Slower than swords but deal more damage and are excellent at splintering wooden shields.
    -   *Stats:* Damage: 22-30 | Speed: Medium | Guard Break: Medium
    -   *Primary Aspect(s): Tenacity*
-   **Maces & Hammers:** Blunt weapons that are devastating against heavily armored opponents, crushing plate and bone.
    -   *Stats:* Damage: 25-35 | Speed: Slow | Guard Break: High
    -   *Primary Aspect(s): Tenacity*
-   **Daggers:** Very fast, with low base damage but a high critical hit multiplier, especially on backstabs.
    -   *Stats:* Damage: 10-15 | Speed: Very Fast | Guard Break: Very Low | Critical Multiplier: 3x
    -   *Primary Aspect(s): Affection, Awareness*

**Two-Handed Weapons:** Slower and prevent the use of a shield, but offer superior reach and raw power.
-   **Greatswords:** Large, sweeping blades that can hit multiple enemies at once.
    -   *Stats:* Damage: 35-45 | Speed: Slow | Guard Break: Medium | Special: Cleave (hits 2 enemies)
    -   *Primary Aspect(s): Tenacity, Nature*
-   **Greataxes:** Capable of immense damage and can easily break enemy guards, but are slow and difficult to recover if you miss.
    -   *Stats:* Damage: 40-55 | Speed: Very Slow | Guard Break: High
    -   *Primary Aspect(s): Tenacity*
-   **Polearms (Spears & Halberds):** Offer the best reach of any melee weapon, allowing you to keep enemies at a distance.
    -   *Stats:* Damage: 30-40 | Speed: Slow | Guard Break: Low | Range: Longest
    -   *Primary Aspect(s): Nature, Affection*

### 🏹 Ranged Weapons

-   **Bows:**
    -   **Description:** Require dexterity and precision. Can be used to pick off enemies from a distance or apply status effects with special arrows.
    -   **Crafting & Use:** While a smith can forge arrowheads, crafting a powerful bow requires the skill of a bowyer, using woods like yew or ash. Special arrows (fire, bodkin, broadhead) can be crafted at the forge.
    -   *Stats:* Damage: 20-30 | Range: Long | Rate of Fire: Fast
    -   *Primary Aspect(s): Affection*
-   **Crossbows:**
    -   **Description:** Slower to reload than bows but offer much greater power and require less strength to use effectively. Their bolts can punch through heavy armor.
    -   **Crafting & Use:** A smith's skills are essential for crafting the steel prod and complex trigger mechanism of a crossbow. The wooden stock can be purchased or crafted with basic woodworking skills.
    -   *Stats:* Damage: 40-50 | Range: Very Long | Rate of Fire: Very Slow | Special: Armor Piercing
    -   *Primary Aspect(s): Awareness, Tenacity*

### 🛡️ Shields

-   **Description:** A vital tool for survival. Shields can be used to block incoming attacks at the cost of stamina.
-   **Crafting & Use:** As a smith, Kalev can craft a variety of shields. This involves shaping a wooden core, covering it with leather or canvas, and forging a metal boss and rim for reinforcement. The type of shield determines its effectiveness and weight.
-   **Light Shields (Bucklers):** Offer minimal protection but are excellent for parrying, creating opportunities for a riposte.
    -   *Stats:* Defense: 15% | Stability: Low | Parry Window: Large
    -   *Primary Aspect(s): Affection*
-   **Medium Shields (Kite Shields):** A balance of protection and mobility, effective against a wide range of attacks.
    -   *Stats:* Defense: 25% | Stability: Medium | Parry Window: Medium
    -   *Primary Aspect(s): Nature*
-   **Greatshields (Tower Shields):** Provide the ultimate protection and can withstand even the heaviest blows, but they are extremely heavy and will significantly slow you down.
    -   *Stats:* Defense: 40% | Stability: High | Parry Window: Small
    -   *Primary Aspect(s): Nature, Tenacity*

### 🔥 Gunpowder & Incendiaries: The Devil's Breath

These technologies are new, terrifying, and unreliable in 1343. They are rare, expensive, and just as dangerous to the wielder as they are to the target. Their effectiveness is measured by a unique set of attributes: Damage, Accuracy, Reload Speed, Reliability (Misfire Chance), and a Fear Factor that can cause enemies to flee or stagger.

-   **Handgonne:** A primitive firearm. It is slow to reload, wildly inaccurate, and has a chance to misfire. However, a successful shot can tear through any armor and instill fear in all who witness its thunderous roar.
    -   *Stats:* Damage: 80-100 | Range: Medium | Rate of Fire: Extremely Slow | Misfire Chance: 15% | Fear Factor: High
    -   *Primary Aspect(s): Awareness, Nature*
    -   *Acquisition:* Can be acquired through service to the Livonian Order, as Master Burchard von Dreileben may grant access to the Order's limited supply.
-   **Fire Lance:** A polearm with a gunpowder-filled tube attached. It spews a short-range burst of flame and shrapnel, causing panic and terror. It's a one-shot weapon that's difficult to reload in combat, but its psychological impact is immense.
    -   *Stats:* Damage: 50 (cone) | Range: Short | Rate of Fire: One-Shot | Area of Effect: 5m cone | Fear Factor: Very High
    -   *Primary Aspect(s): Tenacity, Unity*
    -   *Acquisition:* A rare weapon that can sometimes be purchased on the black market from smugglers like "Ironhand" Störtebeker.
-   **Grenades:** Ceramic pots filled with black powder and a fuse. Can be thrown to create a small explosion, stunning and damaging enemies in a small area. Very rare and dangerous to handle.
    -   *Stats:* Damage: 40 (AoE) | Range: Short (Thrown) | Rate of Fire: Single Use | Area of Effect: 3m radius
    -   *Primary Aspect(s): Affection, Tenacity*
    -   *Acquisition:* Can occasionally be bought from the pirate captain "Ironhand" Störtebeker or acquired through quests for the Novgorodian merchant, Яна Подаяльная.
-   **Greek Fire Siphon:** A truly exotic and terrifying weapon, a remnant of Byzantine ingenuity. It's a handheld device that projects a stream of liquid fire. The fire sticks to surfaces and is difficult to extinguish. The weapon is extremely rare, prone to malfunction, and consumes its special fuel rapidly.
    -   *Stats:* Damage: 15/sec (DoT) | Range: Short (Stream) | Rate of Fire: Continuous (3s) | Area of Effect: Lingering ground fire
    -   *Primary Aspect(s): Light, Awareness*
    -   *Acquisition:* An exotic technology that can only be procured by the well-connected Novgorodian merchant, Яна Подаяльная, for those who serve her interests.
