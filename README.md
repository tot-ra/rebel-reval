# Reval Rebel

**Reval Rebel** is a compact 2D narrative action RPG about a blacksmith whose work keeps returning in other people's hands.

It is April 1343. Reval—present-day Tallinn—is days away from the St. George's Night Uprising. Kalev, a lower-town smith, accepts commissions from people on every side of the coming conflict. He can do honest work, hide a useful feature, or introduce a flaw. By night, each object returns as protection, evidence, betrayal, or a means of escape.

The uprising cannot be prevented. Its local cost—and Kalev's responsibility for it—can change.

![In-game prototype of Reval](./img/Screenshot%202025-08-26%20at%2016.42.48.png)

> Reval Rebel is in pre-production with an early playable Godot prototype. See [`TODO.md`](./TODO.md) for the executable roadmap and [`docs/SETUP.md`](./docs/SETUP.md) to run it.

## The heart of the game

> Can a craftsman remain innocent when every object he makes becomes someone else's instrument of power?

Three ideas guide the project:

- **Every tool is a choice.** Forging is narrative problem-solving, not inventory busywork. A commission has a customer, a hidden purpose, and a small number of meaningful modifications.
- **The city remembers through people.** Consequences appear in named characters, changed spaces, patrols, prices, and dialogue—not in a universal rebel-versus-ruler morality meter.
- **History is fixed; responsibility is not.** The uprising still happens. The player changes who survives, who trusts whom, what evidence remains, and how Kalev is remembered.

## How it plays

Each story cycle follows the same promise:

1. **Take a commission** from someone with a concrete need.
2. **Investigate** who benefits and what the customer is hiding.
3. **Forge** the object honestly, alter it, or sabotage it when Kalev has the knowledge and materials.
4. **Face the consequence** in a compact night mission, confrontation, or escape.
5. **Return to the aftermath** as people, places, supplies, and patrols react.
6. **Reflect at Hingepuu**, which gives the choice emotional weight without grading it.

Time advances through authored story phases rather than a continuously simulated clock. Dialogue is written and deterministic. Combat is small and direct: Kalev's hammer, guard/parry, dodge, and one equipped forge technique. Stealth comes from patrol avoidance and authored alternate routes, not a large stealth simulation.

## The campaign

| | First campaign |
|---|---|
| **Length** | 5–7 hours |
| **Place** | The forge and one dense Lower Town district |
| **Structure** | Five day/night cycles and eight substantial quests |
| **Finale** | One compact encounter at Viru Gate |
| **Endings** | Open, Seal, or Break, with separate outcomes for people and places |
| **Replay value** | Discovering branches and consequences, not procedural runs |

The story begins when Captain Henning brings Kalev a seized spearhead bearing his maker's mark. Kalev's apprentice is missing, rejected iron has disappeared, and the forge ledger can implicate more than one person. Later commissions—a brewery fitting, a gate chain, warehouse tools, shackles—return during St. George's Night. Kalev never defeats an army; he decides whom the gate protects, and for how long.

The vertical slice covers the prologue and **A Bitter Brew** in four reusable spaces. It must prove that one forging choice changes a night encounter, the following phase, and at least two character reactions before the campaign expands.

## Characters

<p align="center">
  <img src="./img/user__idle.gif" width="112" alt="Prototype pixel art of Kalev">
  <img src="./characters/rebels/kaja_lahekivi.png" width="112" alt="Prototype pixel art of Kaja">
  <img src="./characters/metsik_cult/ellen_luik.png" width="112" alt="Prototype pixel art of Ellen">
</p>

The campaign follows seven core characters: [Kalev](./docs/CHARACTERS/kalev.md), [Mart](./docs/CHARACTERS/mart.md), [Aita](./docs/CHARACTERS/aita.md), [Kaja](./docs/CHARACTERS/kaja.md), [Captain Henning](./docs/CHARACTERS/henning.md), [Jürgen Witte](./docs/CHARACTERS/jurgen.md), and [Ellen Luik](./docs/CHARACTERS/ellen.md).

Their motivations, secrets, relationships, voices, and possible outcomes live in the [character briefs](./docs/CHARACTERS/README.md), where they can evolve without turning this page into a design database.

The sprites above are preserved prototype character art. They are not a commitment to the old frame-by-frame pixel pipeline; the production target is still being proven through the art-direction gate.

## World and tone

Reval is a Danish-ruled, German-elite city with overlapping legal, religious, and linguistic communities. Danish authority, the Livonian Order, merchants, clergy, local converts, rural rebels, urban radicals, and old-faith believers are not clean moral teams.

The game begins shortly before the uprising of 23 April 1343. Rural violence and the siege of Reval remain historical pressure around the authored story. An uprising inside the walls is treated as alternate history. Folklore is rare and ambiguous; fragmentary beliefs are not presented as a complete fantasy religion.

Named people, events, institutions, buildings, and beliefs are marked as `attested`, `plausible composite`, `folklore`, or `invented`. The working timeline and terminology live in [`docs/CANON.md`](./docs/CANON.md).

## Visual direction

Gameplay uses a fixed-camera, three-quarter view on an orthogonal 2D plane. The current comparison target is clean-painted low-resolution art with restrained digital-woodcut accents, a limited Baltic palette, and readable silhouettes. Architecture draws from medieval Reval; candlelight, icy blues, earth tones, and mossy greens shape the mood.

Production characters are intended to share a modular cutout rig rather than require bespoke frame-by-frame animation. Earlier pixel sprites remain useful prototypes and visual history. Exact scale, palette, pivots, shadows, and readability rules are tracked in [`docs/ART_BIBLE.md`](./docs/ART_BIBLE.md).

## Scope

The first campaign includes:

- Kalev, his forge, one Lower Town district, and seven core characters;
- the commission → investigation → modification → consequence → reflection loop;
- a small hammer combat model and no more than three forge techniques;
- authored dialogue, explicit consequence state, and one ambiguous folklore quest;
- three ending families with character-level variations.

It does **not** include:

- an open world, seamless Reval, or playable campaigns in other cities;
- runtime LLM dialogue, generated quests, or procedural runs;
- party control, army battles, tower capture, survival simulation, or a broad faction sandbox;
- sprawling crafting trees, randomized loot, weapon families, or a blacksmith rhythm minigame;
- a complete pagan magic system or the legacy 21-element and NATURAL-aspects systems.

Ideas outside this boundary are reference material, not promised features. A major addition must replace comparable scope, be recorded in an ADR, and receive a verifiable `TODO.md` entry before implementation.

## Development status

The repository currently has:

- a Godot 4.7 project with a main menu, player movement, scene transitions, prototype rooms, and placeholder UI;
- documented headless import and playable-room smoke checks;
- a small repository-owned GDScript test harness;
- schemas and Python validation for authored content;
- CI checks for the engine pin, content, tests, imports, and desktop export smoke.

Production dialogue, quests, combat, inventory, narrative forging, phase state, consequence state, and save/load are not playable yet. The next work is deliberately ordered in [`TODO.md`](./TODO.md); legacy documents do not silently expand that scope.

## Run the project

Install the pinned Godot version from [`.godot-version`](./.godot-version), then open [`project.godot`](./project.godot) in the editor and press **F5**. Platform-specific setup and headless commands are in [`docs/SETUP.md`](./docs/SETUP.md).

Useful repository checks:

```bash
godot --headless --script tools/run_godot_tests.gd
python3 tools/validate_content.py content/examples/valid content/examples/support
python3 tools/validate_asset_sources.py
python3 tools/generate_active_docs_report.py --check
```

## Project guide

| Document | Purpose |
|---|---|
| [`TODO.md`](./TODO.md) | Ordered, executable work |
| [`AGENTS.md`](./AGENTS.md) | Repository map, commands, constraints, and task contract |
| [`docs/CANON.md`](./docs/CANON.md) | Timeline, terminology, names, and historical confidence |
| [`docs/CHARACTERS/`](./docs/CHARACTERS/README.md) | Active cast briefs and relationships |
| [`docs/ART_BIBLE.md`](./docs/ART_BIBLE.md) | Visual target, scale, palette, and readability rules |
| [`docs/SETUP.md`](./docs/SETUP.md) | Editor installation, import, startup, tests, and export |
| [`docs/adr/`](./docs/adr/) | Product and technical decisions |
| [`assets/SOURCES.csv`](./assets/SOURCES.csv) | Asset provenance, rights, and approval metadata |

Root design documents, much of `story/`, and the older faction and location indexes are preserved as research and legacy material. They become active only after reconciliation with this README and a strict task in [`TODO.md`](./TODO.md).
