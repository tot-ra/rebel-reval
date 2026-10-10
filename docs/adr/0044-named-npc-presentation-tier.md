# ADR 0044: Named NPC presentation tier, portrait avatars, "!" marker and faction identity

- **Status:** Proposed (2026-10-10, task **R-1561**, epic **R-1560**). Maintainer approval required before NPC-5 (R-1565) and NPC-7 (R-1567) art work starts. Record the approval here as `Accepted (date, maintainer: "...")`.
- **Amends:** the tier table and "Art rule (binding)" in [`cast_faction_promotion.md`](../cast_faction_promotion.md), the "Character fidelity tiers" table in [`ART_BIBLE.md`](../ART_BIBLE.md). Builds on [ADR 0016](./0016-tiered-character-fidelity.md) (tiers on one rig), [ADR 0022](./0022-realistic-human-characters.md) (MPFB humans), [ADR 0034](./0034-cutscene-mode-and-cinematic-prologue.md) (cutscenes), [ADR 0041](./0041-spirit-sight-auras-and-soul-lights.md) (spirit sight). Does not change the asset freeze P0-040 or the eight launch factions (ADR 0008).

## Context

The maintainer decided on 2026-10-10 (epic R-1560) that the politically and professionally notable people described in `characters/**` (about 90 sheets, 98 concept portraits) appear in Reval as **named NPCs**: each with a custom 3D model built from its portrait that holds up in close-ups and cutscenes, an overhead `!` marker that separates them from the census crowd, a readable faction, and the portrait as the dialogue avatar.

Four standing rules block that:

1. `cast_faction_promotion.md` reserves Tier 0 (hero) for the seven slice-core characters and puts every new promotion in Tier 1 (56k triangles, 1024 px, shared skin shader). Tier 1 has no close-up requirement.
2. The same page says `characters/**` portraits are "inspiration only". Since 2026-10-07 those portraits are AI-generated painted jpgs (commit `815a7d0b`), not the frozen 128 px pixel PNGs. NPC-6 (R-1566) already crops them into `assets/characters/portraits/npc/` with `assets/SOURCES.csv` rows marked "candidate - pending art approval per ADR 0044".
3. Census residents (`cit.<district>.<building>.<nn>`, [`CITIZENS.md`](../SYSTEMS/CITIZENS.md)) already populate the city and their deep cards already use `char.<slug>`. A named NPC must not create a second copy of the same person or a clashing ID.
4. AGENTS.md: a scope change needs an equivalent-cost removal named explicitly.

## Decision

### 1. Fidelity: a new Tier 1C "cinematic named NPC"

Tier 0 stays reserved for the seven slice-core characters. Named NPCs get a separate tier, **1C**, so the hero budget, the count of close-up-ready actors on screen, and the lint rules can be tracked apart.

| LOD | Used when | Triangle cap | Texture cap | Shader set |
|---|---|---:|---:|---|
| 1C-LOD0 | dialogue, cutscene, camera within 6 m | 60,000 (Tier 0 cap) | 2048 px head (skin, normal, roughness), 1024 px body and garments | Tier 0 `full_pbr_skin_hair_eyes`: skin with subsurface tint, eye with cornea/iris, card hair and beard |
| 1C-LOD1 | 6-25 m | 20,000 | 1024 px | Tier 1 `shared_skin_plus_pbr_swaps` |
| 1C-LOD2 | beyond 25 m, crowds | 12,000 (Tier 2 cap) | 512 px | Tier 2 `crowd_simplified_pbr`, never instanced (named NPCs stay individual actors) |

- **Body:** MPFB recipe per NPC (ADR 0022) with face shape, skin, hair and beard matched to the portrait; garments per the faction rules in section 4. The 2026-10-07 portrait is the reference sheet for the model.
- **Bones:** the shared skeleton only (ADR 0016). Faces animate with shape keys (at most 32: visemes, blink, brow, jaw), no extra deform bones.
- **Runtime budget:** at most 4 Tier 1C actors at LOD0 at once (dialogue partner plus cutscene cast); the rest drop to LOD1.
- **Enforcement:** NPC-7 adds `fidelity_tier: "1C"` with these LOD caps to `tools/character_fidelity_tiers.py` and `tools/verify_asset_lint.py`. Until then a Tier 1C GLB must pass the Tier 0 cap.
- **Tier 1** stays for promoted cast without a custom portrait model (fallback during the rollout). **Tier 2** stays for census residents and ambient sheets.

### 2. Portraits: 2026-10-07 jpgs become runtime dialogue avatars

- The AI-generated painted portraits `characters/**/img/*.jpg` dated 2026-10-07 or later are approved as **runtime dialogue avatars** and as the **reference for 3D models**.
- `characters/` stays a source folder (it has a `.gdignore`). Runtime copies are produced only by `tools/assets/import_npc_portraits.py` into `assets/characters/portraits/npc/<slug>.png` (square head-and-shoulders crop, 256 px max, sRGB). Each file needs an `assets/SOURCES.csv` row naming the source jpg, its SHA-256, the tool (OpenAI image generation, model version as recorded) and an approval value. On acceptance of this ADR the rows move from `candidate` to `approved - ADR 0044 dialogue avatar`, one row at a time after a visual check (no anachronistic clothing, no text artefacts, face matches the brief).
- The legacy 128 px pixel PNGs and GIFs stay **frozen** (P0-040): never imported, never shipped, not replaced.
- A portrait never stands in for the 3D model in the world. A named NPC without a 1C model uses Tier 1 until its character task lands.

### 3. The named-NPC marker

A world-space glyph above the head, drawn by the UI layer (not graded by world bloom), visible within 25 m with line of sight, faded with distance, hidden when occluded.

| State | Glyph | Meaning |
|---|---|---|
| `available` | `!` | named NPC with an interaction the player has not used (first implementation, NPC-4 R-1564) |
| `quest_ready` | `?` | a quest step can be turned in (future, quest tasks) |
| `spoken` | grey `!`, smaller | talked to, nothing new |
| `none` | no glyph | hostile, hidden (Black Cloaks cell members off duty), in combat, or asleep indoors |

- **State carries shape, not colour.** Each state differs in glyph and size; colour only reinforces it. The glyph is parchment white with a dark `#171B2A` outline in every faction (section 4 adds a separate faction chip).
- **Hidden in dialogue, cutscenes (ADR 0034), spirit sight and spirit duels.** In spirit sight (ADR 0041) a named NPC is recognised by its aura (authored light levels) instead; the marker returns when sight is turned off.
- The state is computed from data (registry plus `memory.*` and quest state), never stored separately in the save.

### 4. Faction visual identity

Every named NPC shows its faction through three channels: a **palette** (primary and secondary), an **emblem** (one simple shape, readable at 64 px), and **one clothing accent** placed where it reads at gameplay distance. The marker carries a small **faction chip**: the emblem shape filled with the primary colour under the glyph. The info panel shows the same chip with the faction name. Shape is always the main channel, so two factions never differ by colour alone.

| Faction | Primary / secondary | Emblem | Clothing accent | Canon |
|---|---|---|---|---|
| Danish Crown `faction.danish_crown` | `#A8323A` red / `#E8E2D0` white | white cross on red | red cloak lining or tabard with white cross | `plausible` (Dannebrog use attested later in the 14th c.) |
| Livonian Order `faction.livonian_order` | `#E8E2D0` white / `#1E1E22` black | black cross | white mantle (knights), grey (half-brothers), black cross on the left shoulder | `attested` |
| Hanseatic guilds `faction.hanseatic_guilds` | `#B8443A` brick red / `#D8CBA8` linen | cog ship | fine dyed wool with a fur-trimmed hood and a seal purse at the belt | `plausible` (emblem is a project invention) |
| Harju Kings `faction.harju_kings` | `#4052B5` rebel indigo / `#9C8A6A` undyed wool | oak leaf | woven indigo-patterned belt over undyed wool | `invented` |
| Black Cloaks `faction.black_cloaks` | `#2A2A30` charcoal / `#6E6A60` ash | knotted cord | black hooded cloak; the emblem is hidden in public and shown only to allies and in the info panel once revealed | `invented` |
| Cult of Metsik `faction.cult_of_metsik` | `#5E6B3A` moss / `#C9A85C` rye straw | rye sheaf | straw or birch-bark ornament on the hat or belt | `folklore` |
| Pskov / Novgorod `faction.pskov_novgorod` | `#7A2E2E` madder / `#C9A24A` gold | three-bar cross | long kaftan with standing collar, fur cap | `plausible` |
| Vitalienbrüder `faction.vitalienbruder` | `#3E5566` sea-faded blue / `#1C1C1C` tar | none (outlaws): a broken ring chip | tarred cap and mismatched looted pieces | `invented` (name is anachronistic, already accepted in the launch set) |
| Blackheads (candidate seat) | `#1C1C22` black / `#C9A24A` gold | lance with pennant (St Maurice) | black chaperon with gold trim | `plausible` (brotherhood records begin later); never a caricatured head |
| Ösel-Wiek (candidate) | `#2E4A7A` blue / `#E0D6B8` white | crozier | bishop's livery sleeve in blue | `invented` |
| Dorpat (adapt) | `#A8323A` red / `#D0D0D0` silver | crossed key and sword | red-and-silver hood | `attested` (Tartu arms; colours `plausible`) |

- Hero crimson `#D9364D` stays reserved for Kalev and priority reads; no faction uses it.
- Clergy and NPCs without a ledger seat get no chip.
- Census residents keep their plain clothes; faction accents are for named NPCs (and later for faction-identified crowd variants by a separate task).
- Hues above are starting values; NPC-5 (R-1565) may retune them for contrast under the ADR 0018 grade, but must keep the emblem shapes and the shape-first rule.

### 5. Named NPC vs census resident

- A named NPC has the stable ID `char.<slug>` and one row in the named-NPC registry (NPC-2 R-1562).
- It links to the census by an optional `census_id` with one of two modes:
  - `replaces`: the named NPC **is** that census resident. The census spawner skips the resident at runtime and the named NPC uses the resident's home, household and timetable unless the registry overrides them. Use when the census already contains the person (same name, trade, building).
  - `extra`: no census row; the registry gives a home building or anchor and a schedule. Use for visitors, envoys, and people the census does not list.
- **The census is never edited** for named NPCs. Runtime memory uses `memory.*` keys (CITIZENS.md rule).
- **ID collisions:** census deep cards also use `char.<slug>`. If a deep card exists for the same person, the registry links it (`replaces` with its `census_id`); if the slug belongs to a different person, the named NPC takes a new slug. The NPC-2 validator rejects a registry slug that equals a deep card slug without that link, and a census resident linked by two named NPCs.
- The seven slice-core characters keep their existing IDs and Tier 0.

### 6. Scope offset (AGENTS.md scope-change rule)

Removed scope of equivalent cost:

- **Famous off-stage figures R-1234..R-1256** (23 sheets in `characters/famous/`: Albert of Saxony through William of Ockham) lose the "textures, 3D model, in-game install" deliverables. They stay **portrait + mention**: the portrait may appear in journal or letter UI, the figure is named in dialogue only, never spawned. That removes 23 custom models, their textures and installs, which is more than the marker, faction identity and Tier 1C upgrade added here.
- **Sergius of Radonezh R-1264** is **rejected** as a named NPC and quest giver (anachronistic agency in 1343 Reval). No model, no spawn; mention only if research supports it.
- NPC-9 (R-1569) rewrites those task descriptions and the R-1221 definition of done to match.

## Alternatives

- **Extend Tier 0 to all named NPCs.** Simplest rule, but Tier 0 then means about 70 actors instead of seven, hides the close-up count, and gives no distance LOD requirement. Rejected.
- **Keep named NPCs at Tier 1.** Cheapest, but fails the maintainer's close-up requirement (1024 px faces, shared skin shader). Rejected.
- **Portraits stay inspiration only; render avatars from the 3D model.** Consistent with the old rule but leaves dialogue without faces until every model exists. Rejected; avatars ship first, models follow per character.
- **Colour-only faction tint on the marker.** Fails colour-blind players and the ART_BIBLE grayscale/squint check. Rejected for the emblem chip.
- **Named NPCs as census edits.** Breaks the census as static content and its regeneration checks. Rejected for the registry link.

## Consequences

- NPC-2 to NPC-8 are unblocked once this ADR is accepted; NPC-5 and NPC-7 must cite the tables above.
- `tools/character_fidelity_tiers.py` and `tools/verify_asset_lint.py` gain a 1C tier with LOD caps (NPC-7).
- Each Tier 1C model costs MPFB authoring plus a 2048 px head set, so the rollout is one character at a time in the wave order of `cast_faction_promotion.md` (epic rule).
- Portrait provenance rows move to `approved` one by one; a portrait that fails its visual check stays `candidate` and is not shown.
- Faction colours become a binding art input; the ART_BIBLE character table records the 1C row.
- 23 famous tasks shrink to portrait + mention, R-1264 is rejected.
