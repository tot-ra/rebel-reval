# Reval Rebel

![Reval Rebel concept banner](./img/banner.jpg)

**Reval Rebel** is a compact 2D narrative action RPG about complicity, responsibility, and the uses of skilled work. It is set in semi-fictional Reval, present-day Tallinn, during the final days before the St. George's Night Uprising of 1343.

The player is **Kalev**, a lower-town smith. By day, he accepts commissions, investigates who will use his work, and decides whether to alter what he forges. By night, those objects return as weapons, protection, evidence, betrayal, or a means of escape. The uprising cannot be prevented, but its local cost and Kalev's responsibility can change.

![](img/Screenshot%202025-08-26%20at%2016.42.48.png)

> This README is the current product source of truth. [`TODO.md`](./TODO.md) contains only executable work. Older design documents are research or legacy concepts until explicitly reconciled with this README.

## Product vision

### Central dramatic question

Can a craftsman remain innocent when every object he makes becomes someone else's instrument of power?

### Player promise

Every important object forged by the player returns later with a visible human or mechanical consequence.

### Game pillars

1. **Every tool is a choice**
   - Forging is narrative problem-solving, not a generic crafting inventory.
   - Each major commission has a customer, a hidden purpose, and two or three possible modifications.

2. **The city remembers through people**
   - Consequences appear through named characters, changed spaces, patrols, prices, and dialogue.
   - There is no universal rebel-versus-ruler morality bar.

3. **History is fixed, responsibility is not**
   - The historical pressure and major events remain recognizable.
   - The player changes who survives, who trusts whom, what evidence remains, and how Kalev is remembered.

## Target game

- **Genre:** authored narrative action RPG.
- **Target length:** 5-7 hours for the first complete campaign.
- **Structure:** one Lower Town district, five authored day/night cycles, one gate finale, and three ending families with character-level variants.
- **Exploration:** small connected rooms and streets, not an open world.
- **Dialogue:** deterministic, authored, and knowledge-based. No random percentage checks.
- **Combat:** small real-time encounters built around Kalev's hammer, guard/parry, dodge, and one equipped forge technique.
- **Stealth:** patrol avoidance and alternate routes where authored. No systemic crouch, sound propagation, or takedown simulation.
- **Supernatural content:** rare, culturally grounded, and initially ambiguous.
- **Replayability:** branch discovery and consequences, not procedural runs, permadeath, or meta-progression.

## Core gameplay loop

1. **Commission** - Kalev receives a concrete order from a named person.
2. **Investigation** - he learns who benefits, what the object will do, and what the customer is hiding.
3. **Forging choice** - he performs honest work, introduces a subtle defect, or adds a secret feature when knowledge and materials allow it.
4. **Night consequence** - the commissioned object changes a short mission, confrontation, or escape.
5. **Human aftermath** - locations, relationships, dialogue, supplies, and patrol behavior change.
6. **Reflection** - Hingepuu presents the emotional cost without absolving or scoring the player.

Time advances through explicit story phases after major actions. It is not a continuously simulated clock.

## Product decisions

### Engine

The default engine is **Godot 4.7 with typed GDScript**. The pinned editor version is recorded in [`.godot-version`](./.godot-version) and [`docs/SETUP.md`](./docs/SETUP.md).

Godot is retained because the repository already contains Godot scenes, navigation, imports, and scripts; it is suitable for compact 2D production; and its text-based resources support review by coding agents. Unity, Unreal, RPG Maker, and a custom web engine do not solve the project's primary problem, which is scope and production coherence.

The engine may be reconsidered only if the P0 comparison room fails documented reliability, readability, performance, or agent-editability criteria.

### Perspective

The target perspective is **fixed-camera 2D three-quarter top-down on an orthogonal gameplay plane**, not true isometric.

- The art may look isometric, but movement, collision, and navigation remain orthogonal.
- Characters use four movement directions. East/west may be mirrored when equipment asymmetry does not make that visibly wrong.
- Spaces are composed as small reusable rooms and streets.
- Foreground roofs and walls fade only where readability requires it.

This is a deliberate migration from the current diamond-isometric TileSet and eight-direction frame-animation assumptions. Existing maps and animations are prototypes until the P0 comparison room determines what can be retained.

### Visual style

The target is **low-resolution digital woodcut cutouts with a limited palette**, influenced by Baltic woodcuts, illuminated manuscripts, stained glass, earth tones, candlelight, icy blues, and mossy greens.

Strict pixel art is not the production target. The existing assets mix pixel sprites, high-resolution portraits and UI, painterly backgrounds, rendered props, and generated images without one grid, palette, outline, or lighting model. AI image tools also produce inconsistent frame-by-frame pixel animation.

The production approach is:

- freeze internal resolution, camera zoom, screen-space character height, floor projection, palette, pivots, shadows, and outline rules before creating production assets;
- use one shared `Skeleton2D` paper-doll rig with modular body, head, hair, clothing, cloak, weapon, and faction layers;
- reuse transform-based idle, walk, forge, attack, guard, hit, and fall animations;
- derive portraits from approved character sheets rather than unrelated prompts;
- reserve generated high-detail images for reviewed static portraits, chapter cards, and marketing;
- retain prompts, model/version, seed or source URL, license, edits, and approval state for every shipped asset;
- review anatomy, hands, weapons, heraldry, writing, clothing, and cultural symbols manually.

### Narrative systems

- The former 15+ faction simulation is reduced to named actors under three dramatic pressures: **Authority**, **Rebellion**, and **Community**.
- The former Hope/Fear/Chaos and 140-NPC allegiance model is replaced by explicit consequence flags and three district pressures: **Suspicion**, **Solidarity**, and **Scarcity**, each from 0 to 3.
- The former 21-element spell system is reduced to three possible forge techniques: **Iron**, **Ember**, and **Root**. Each must have one combat use and one narrative or environmental use.
- The former seven NATURAL aspects are reduced to three convictions: **Duty**, **Fury**, and **Mercy**. They unlock authored options and never create random dialogue checks.
- Inventory is a six-slot quest/tool pouch, coin, and three material grades. There is no encumbrance, junk loot, randomized item tier, or broad vendor economy.
- Hingepuu is a reusable reflection screen with three voices and visual scars, nails, shoots, or cut branches. It is not a second explorable game.
- NPC placement may have one day and one night variant when required by the story. There are no full simulated schedules.

## Scope boundaries

### Included in the first campaign

- Kalev as a fixed protagonist and working smith.
- The forge as home, workbench, social hub, and source of main missions.
- One dense Lower Town district.
- Commission, investigation, modification, consequence, and reflection.
- Seven core characters.
- Eight substantial quests across five cycles.
- One Viru Gate finale.
- Three ending families with individual character outcomes.
- A small hammer combat model and two or three forge techniques.
- One ambiguous folklore quest after the mundane political story works.

### Explicitly excluded from the first campaign

- Open-world or seamless Reval.
- True isometric simulation or conversion to 3D.
- Runtime LLM calls, free-text NPC conversations, or generated quests.
- Roguelike runs, procedural levels, permadeath, or meta-progression.
- Party control, combat followers, army command, or large field battles.
- Systemic tower capture, tower counterattacks, or repeated tower dungeons.
- More than one playable district before the vertical slice passes its gate.
- Castle building, ships, fishing, haggling, rhythm rituals, and physics brawling.
- A temperature or hammer-timing blacksmith simulation.
- Survival needs, farming, seasons, weather simulation, and random bloody moons.
- Handgonnes, grenades, broad weapon families, randomized loot, and crafting trees.
- Playable Dorpat, Riga, Saaremaa, Pskov, Sweden, or Novgorod maps.
- A multi-year war campaign or plague minigame.

Ideas outside this scope are reference material, not implicit future commitments. A new major system must replace equivalent scope and receive a written decision.

## Historical and lore guardrails

- The playable story starts in April 1343, shortly before the uprising.
- Reval is presented as a Danish-ruled, German-elite, legally, religiously, and linguistically layered city.
- Danish authority, the Livonian Order, German burghers, clergy, local converts, and Christianity are not one faction.
- Rural rebels, urban radicals, old-faith believers, and ordinary Estonians are not one moral alignment.
- The historical uprising begins in the countryside and leads toward the siege or blockade of Reval. An uprising inside the walls must be identified as alternate history.
- The four rebel kings are elected after the outbreak. Their negotiation and deaths at Paide belong after St. George's Night.
- The old 1219 opening is not canon. Lembitu died in 1217 and cannot fight Valdemar II at Lyndanisse in 1219. `Volkhv` must not be presented as the attested title of an Estonian religious figure.
- Taara, sacred groves, rituals, and folklore must reflect fragmentary evidence instead of inventing a complete uniform pre-Christian religion.
- Christianity includes sincere charity, local converts, political clergy, frightened laypeople, and reform-minded believers.
- Pagan or cultural resistance includes protectors, opportunists, frightened families, and extremists.
- The old plague-as-divine-justice ending and child-transmission reveal are not canon.
- Named historical people, dated buildings, weapons, institutions, and events require a source note labeled `attested`, `plausible composite`, `folklore`, or `invented for the game`.

## Main cast

### Kalev - the smith

- **Public want:** keep his forge, protect Mart, and remain useful enough that every side leaves him alone.
- **Private need:** admit that skilled neutrality is still a political choice.
- **Contradiction:** he condemns violence but takes pride when powerful people depend on his weapons.
- **Gameplay identity:** reads workmanship, recognizes forged objects, alters commissions, repairs mechanisms, and fights with the hammer he uses to create.
- **Arc:** observer -> accomplice -> accountable actor. The player chooses what responsibility he accepts, not whether he becomes a superhero.

### Mart - the apprentice, age 16

- **Want:** prove he is not a child and turn the forge into a weapon for liberation.
- **Fear:** Kalev's caution is cowardice and will outlive every chance for change.
- **Secret:** he passed rejected spearheads bearing Kalev's maker mark to the Black Cloaks.
- **Function:** inciting incident, emotional stake, and a mirror of Kalev's younger certainty.
- **Possible outcomes:** disciplined organizer, frightened informer, dead martyr, or survivor who rejects Kalev.

### Aita - alewife, healer, and Kalev's older sister

- **Want:** keep the lower town fed and medically safe through the coming violence.
- **Fear:** rulers and rebels will both sacrifice ordinary people for symbols.
- **Contradiction:** she performs Christian respectability publicly while preserving household rites and remedies privately.
- **Function:** community perspective, evidence-based investigation, and a personal challenge to Kalev's excuses.

### Kaja - bilingual courier

- **Want:** build a coalition broad enough to prevent indiscriminate slaughter.
- **Fear:** each side will treat her mixed background as proof of betrayal.
- **Contradiction:** she manipulates people for a humane goal and withholds information that could save them.
- **Function:** connects rural discontent to the city and proposes covert uses for Kalev's commissions.
- **Possible outcomes:** trusted organizer, ruthless operator, exposed fugitive, or departure from Reval.

### Captain Henning - commander of the Viru watch

Captain Henning is a fictional composite.

- **Want:** prevent a massacre and preserve the authority that gives him the means to do it.
- **Fear:** the Order will replace the city watch if he appears weak.
- **Contradiction:** he can show individual mercy while building a system of collective punishment.
- **Function:** recurring antagonist and legitimate argument for order. He commissions locks, chains, and patrol equipment.
- **Possible outcomes:** exposed corruption, atrocity, restrained final response, or a sealed city.

### Jürgen Witte - Hanseatic amber merchant

Jürgen Witte replaces the placeholder name `Jürgen von League`, subject to historical naming review.

- **Want:** keep the harbor open and convert instability into control of debt and supply.
- **Fear:** war will make contracts meaningless and empower armed men over merchants.
- **Contradiction:** he prevents shortages when relief is profitable and manufactures scarcity when it is not.
- **Function:** material supplier, economic temptation, and proof that power is not limited to weapons.

### Ellen Luik - baptized midwife and keeper of old songs

Ellen enters after the vertical slice.

- **Want:** preserve people and memory rather than restore a fantasy pagan state.
- **Fear:** young radicals will turn fragmentary traditions into justification for revenge.
- **Contradiction:** she encourages ambiguous supernatural belief because it gives frightened people courage.
- **Function:** grounds Hingepuu and folklore in lived tradition while leaving the reality of magic uncertain.

## Campaign outline

### Prologue - The Maker's Mark

Kalev repairs a plough and a watchman's buckle while the player learns movement, interaction, and commissions. Captain Henning then presents a seized spearhead bearing Kalev's maker mark. Mart is missing and rejected iron blanks are gone. Henning gives Kalev until the next inspection to identify who received the iron. The player preserves, alters, or destroys the forge ledger.

### Cycle 1 - A Bitter Brew

Sickness in the lower town is blamed on Aita's ale and alleged witchcraft. Evidence points to contaminated water, but Henning's neglected cistern and possible rebel sabotage complicate responsibility. Jürgen offers clean imported water under a predatory exclusive contract. Kalev forges brewery bands, tampers with an inspection seal, or builds a feature into Aita's detention-cart lock. The forged choice changes who is arrested and what evidence survives.

### Cycle 2 - The Bell and the Chain

Henning commissions a reinforced gate chain and alarm-bell fitting. Kaja asks for a silent weak link; Mart wants a catastrophic failure that may kill the gate crew. Investigation reveals patrols, workers, and the gate key. The modification changes the finale's layout and Henning's suspicion.

### Cycle 3 - Bread and Iron

Merchants hoard grain while rural roads become unsafe. Jürgen offers iron and Mart's safety if Kalev enforces warehouse claims. Aita asks for tools to open the granary without causing a riot. Kaja needs the shipment for rural rebels. One named family bears the visible cost of the player's decision.

### Cycle 4 - The Price of a Name

Henning identifies Mart's contact and privately offers an exchange: Kalev forges shackles and names the network, or shares Mart's sentence. Kaja proposes a false list containing one genuine violent extremist. Ellen explains the maker mark's meaning to the old community without confirming a magical bloodline. Hingepuu reflects accumulated Duty, Fury, and Mercy.

### Finale - St. George's Night

Fires and bells announce the rural uprising as refugees and armed groups converge on Viru Gate. The gate chain, alarm fitting, warehouse decision, relationships, and Mart's state all return. Kalev does not defeat an army; he decides whom the gate protects and for how long during one compact encounter.

Ending families:

1. **Open** - aid the rebels, ranging from controlled entry to massacre depending on restraint and supplies.
2. **Seal** - aid authority, ranging from civilian refuge to collective punishment depending on evidence and Henning's trust.
3. **Break** - destroy both sides' control long enough to evacuate civilians, at the cost of Kalev's forge, name, and political influence.

The epilogue records Mart, Aita, Kaja, Henning, Jürgen, Ellen, the forge, and the district separately. There is no universal good/bad ending score.

## Quest design rules

Every substantial quest contains:

- one named person with a concrete want;
- one object or mechanism Kalev understands as a smith;
- one investigable contradiction;
- one irreversible choice without a clearly dominant reward;
- at least two completion methods, without forcing every quest to support every play style;
- one visible consequence in a later scene;
- one dialogue or epilogue callback;
- no filler collection count, anonymous reputation reward, or generic monster contract.

## Vertical slice

### Goal

Prove the commission-to-consequence loop in 30-45 minutes before expanding the game.

### Included content

- forge interior;
- one lower-town street and well;
- Aita's brewery;
- one watch checkpoint or detention yard reused for the night encounter;
- Kalev, Mart, Aita, Kaja, Henning, and Jürgen;
- the prologue and `A Bitter Brew`;
- one Hingepuu reflection;
- one encounter with watchman and sergeant archetypes;
- one manual save slot and autosaves at phase transitions;
- three outcomes that change the brewery, Aita, Mart, and patrol barks.

### Hard content budget

- 4 playable spaces from one modular environment kit.
- 6 speaking characters using one shared cutout rig.
- 2 enemy archetypes.
- 1 player weapon: the smith's hammer.
- 5 actions: interact, light attack, charged attack, guard/parry, and dodge.
- 1 forge technique: Iron, used to brace or jam a mechanism.
- At most 2,500 reviewed words of dialogue.
- At most 12 minutes of unique music using reusable stems and ambience.
- At most 3 visible quest items in the pouch.

### Acceptance gate

The slice passes only when:

- a new player completes it without developer explanation;
- a forge choice materially changes the night encounter;
- at least one combat and one non-combat resolution reuse the same quest state;
- the following phase visibly changes a location and two NPC reactions;
- save/reload preserves quest branch, modification, character states, and phase;
- keyboard/mouse and gamepad both work;
- headless import, tests, content validation, and export smoke checks produce no critical errors;
- every shipped asset has source, rights, and approval metadata;
- five external players can explain the relation between forging and consequences;
- at least four of those players say the choice was difficult for narrative reasons rather than unclear UI.

No campaign expansion begins before this gate passes.

## AI-agent-first production model

AI agents are expected to implement much of the code and draft much of the content, but only through bounded tasks, structured data, reproducible assets, and automatic validation. Runtime generative AI is not required.

### Repository sources of truth

The intended production documents are:

- `README.md` - product vision, scope, story, and production decisions;
- `TODO.md` - executable tasks only;
- `AGENTS.md` - repository map, commands, conventions, and agent rules;
- `docs/CANON.md` - timeline, terminology, historical confidence, names, and pronunciation;
- `docs/ART_BIBLE.md` - projection, dimensions, palette, rig, lighting, UI, and negative examples;
- `docs/WRITING_GUIDE.md` - voices, languages, branch limits, register, and quest template;
- `docs/ARCHITECTURE.md` - state ownership, content schemas, saves, and scene boundaries;
- `docs/DECISIONS/` - short architecture and product decision records;
- `content/` - canonical machine-readable dialogue, quests, characters, items, and barks;
- `assets/SOURCES.csv` - provenance and rights for runtime assets.

Until these files are created, this README overrides conflicting legacy documents.

### Content model

- Stable IDs use forms such as `quest.bitter_brew`, `char.aita`, and `flag.aita_detained`.
- Dialogue, quests, barks, characters, items, commissions, and locations use documented JSON schemas.
- Godot consumes validated JSON; Python validates it in CI.
- Conditions and effects are declarative and allowlisted. Content cannot embed arbitrary GDScript.
- Quest transitions and side effects are explicit.
- Canonical facts are separate from dialogue prose.
- A dialogue node has no more than four player responses.
- AI-generated drafts require continuity, historical, tone, gameplay, and human approval before receiving `approved` status.
- Runtime barks come from authored pools selected by phase and state. Gameplay has no network dependency.

### Runtime architecture

The intended minimal foundation is:

- `GameState` autoload for phase, pressures, facts, relationships, player state, settings, and save snapshots;
- `ContentDB` autoload for validated read-only content;
- `SceneRouter` autoload for transitions and stable spawn IDs;
- `DialogueRunner` for conditions, choices, effects, and UI signals;
- `QuestManager` for validated state transitions;
- `Interactable` components for prompts and actions;
- `Health`, `Hitbox`, and `Hurtbox` components for combat;
- `ForgeCommission` for producing one explicit item-modification record.

Code uses typed GDScript, typed signals, small reusable scenes, and composition. Agents do not hand-edit giant city `.tscn` files unless a level-specific task includes visual verification. Frameworks and event buses are not introduced without at least two proven call sites.

### Asset pipeline

1. Approve projection, silhouettes, palette, and scale.
2. Build one layered human rig and clothing kit.
3. Reuse idle, walk, attack, guard, hit, fall, interact, and forge animations.
4. Produce modular layers rather than flattened bespoke sprite sheets.
5. Validate dimensions, pivots, names, palette, alpha bounds, and source records automatically.
6. Derive portraits from approved character sheets.
7. Store generation prompts and metadata in the source manifest.
8. Human-review anatomy and historical or cultural details.
9. Enforce lossless runtime textures and import presets by asset class.

### Agent task contract

Every delegated task states:

- player-facing goal;
- files allowed to change;
- dependencies and stable IDs;
- explicit constraints and non-goals;
- deliverable;
- exact verification command or observable result;
- screenshot or expected state for visual work;
- required canon, localization, source-manifest, or documentation updates.

Tasks such as `improve combat`, `add NPCs`, or `make the city alive` are invalid because they are not independently verifiable.

## Definition of done

A production task is complete only when:

- behavior is player-visible and satisfies its verification condition;
- automated tests or validators cover state transitions and failures;
- a clean clone can run it using documented commands;
- keyboard/mouse and gamepad paths are checked where relevant;
- save/load around the behavior is verified;
- active documentation and stable IDs are updated;
- new assets have source, rights, and approval metadata;
- visual changes include screenshots or captured states;
- no unrelated system or speculative abstraction was added;
- a second human or agent reviews correctness, simplicity, and scope.

## Current repository state

The repository currently contains substantial pre-production material but only an early prototype:

- about 270 Markdown files;
- about 480 PNG files;
- 37 Godot scenes;
- 159 MP3 files;
- about 346 lines of GDScript;
- a main menu, player movement, scene transitions, three large city scenes, a forge scene, simple NPC navigation, and placeholder UI.

Not yet implemented as production systems:

- dialogue;
- quests and journal;
- combat;
- inventory;
- narrative forging;
- story phases;
- consequence state;
- save/load;
- content validation;
- automated import, test, or export checks.

Known production risks:

- most concepts exist only in prose;
- many scenes are empty or near-empty placeholders;
- active visuals conflict in projection, resolution, style, and animation method;
- only 9 Aseprite source files exist for hundreds of raster assets;
- asset provenance and commercial rights are not fully recorded;
- legacy documentation contains contradictions and many broken local links;
- the active HUD still represents superseded systems;
- the music directory is much larger than the intended runtime soundtrack.

## Legacy reference material

The following documents contain useful research and ideas but may conflict with this README:

- [Original game pillars](./GAME-PILLARS.md)
- [Original gameplay design](./GAMEPLAY.md)
- [Original night gameplay](./GAMEPLAY-NIGHT.md)
- [Original story](./story/STORY.md) (superseded multi-act outline; plague-justice epilogue archived separately)
- [Archived plague-justice epilogue](./story/archive/plague_justice_epilogue.md) (non-canon)
- [Original quests](./QUESTS.md)
- [Original character build](./character/BUILD.md)
- [Original combat design](./character/COMBAT.md)
- [Original magic design](./character/MAGIC-ELEMENTS.md)
- [Original psyche design](./character/PSYCHE.md)
- [Factions and character archive](./characters/README.md)
- [Locations and scene archive](./scenes/README.md)
- [Historical research](./history/HISTORY.md)
- [Bestiary archive](./assets/bestiary/README.md)
- [Discarded minigame ideas](./MINI_GAMES.md)
- [Untriaged ideas](./RANDOM-IDEAS.md)

Do not implement a legacy concept unless it is first reconciled with this README and added as a strict task in [`TODO.md`](./TODO.md).
