# TODO

Format: `- [ ] ID | deps: ID,ID or none | deliverable: concrete artifact or behavior | verify: objective completion check`

## P0 - Product, canon, and reproducible baseline

- [x] P0-001 | deps: none | deliverable: consistent `Reval Rebel` title in `project.godot`, README, window, and export metadata | verify: repository search finds no active `Rebel Revel` product title
- [x] P0-002 | deps: none | deliverable: root `AGENTS.md` with repository map, commands, conventions, scope constraints, and definition of done | verify: file contains named sections for repository map, setup, import, startup, tests, validation, export, scope constraints, task contract, and definition of done
- [x] P0-003 | deps: none | deliverable: ADR retaining Godot 4.x and listing measurable migration triggers | verify: ADR records status, context, decision, alternatives, and consequences
- [x] P0-004 | deps: none | deliverable: ADR selecting orthogonal three-quarter perspective as the target pending the comparison spike | verify: ADR defines movement directions, projection, collision plane, and decision gate
- [x] P0-005 | deps: none | deliverable: ADR selecting authored offline dialogue and prohibiting runtime LLM dependencies | verify: ADR defines deterministic offline behavior and content approval requirements
- [x] P0-006 | deps: none | deliverable: legacy-status header on conflicting design documents | verify: each legacy document linked by README is labeled `reference`, `superseded`, or `archive`
- [x] P0-007 | deps: P0-002 | deliverable: documented scope-change rule requiring equivalent scope removal and a written decision | verify: rule appears in `AGENTS.md` and names the approval artifact
- [x] P0-008 | deps: none | deliverable: `docs/CANON.md` with April-May 1343 timeline, terminology, names, pronunciation, and confidence labels | verify: every canon entry supports `attested`, `plausible composite`, `folklore`, or `invented`
- [x] P0-009 | deps: P0-008 | deliverable: historical audit of slice characters, buildings, weapons, religions, institutions, and events | verify: every reviewed claim has a source note and confidence label
- [x] P0-010 | deps: P0-008 | deliverable: implementation-ready scene outline for `The Maker's Mark` playable prologue | verify: outline defines locations, characters, interactions, tutorial beats, ledger branches, state effects, and exit condition
- [x] P0-011 | deps: none | deliverable: archived plague-justice epilogue marked non-canon | verify: active story index and README do not present the epilogue as planned content
- [ ] P0-012 | deps: P0-008 | deliverable: resolved canon for Kalev's parents, siblings, partner, children, home, and relationship to Mart | verify: no active document introduces contradictory family facts
- [ ] P0-013 | deps: P0-008,P0-012 | deliverable: approved briefs for Kalev, Mart, Aita, Kaja, Henning, and Jürgen | verify: each brief defines want, fear, contradiction, secret or withheld fact, relationships, voice, and possible outcomes
- [ ] P0-014 | deps: P0-008 | deliverable: font and diacritic decision covering Estonian, Low German names, and Latin text | verify: a test scene renders the required character set without missing glyphs
- [ ] P0-015 | deps: P0-003 | deliverable: pinned Godot version and installation instructions | verify: documented version matches project and CI configuration
- [ ] P0-016 | deps: P0-015 | deliverable: documented commands for headless import, startup, tests, content validation, and export | verify: each command is copy-pasteable from a clean shell
- [ ] P0-017 | deps: P0-015,P0-016 | deliverable: clean-clone import and startup baseline | verify: pinned Godot imports the repository and reaches one playable room without parser or missing-resource errors
- [ ] P0-018 | deps: P0-017 | deliverable: scene inventory classifying every `.tscn` as `working`, `partial`, `placeholder`, or `archive` | verify: inventory count equals repository `.tscn` count
- [ ] P0-019 | deps: P0-017 | deliverable: known-runtime-defects report with reproduction steps and severity | verify: every observed critical or high defect has a reproducible entry
- [ ] P0-020 | deps: P0-017 | deliverable: player script without movement debug logging | verify: normal movement produces no per-frame player velocity output
- [ ] P0-021 | deps: P0-017 | deliverable: separate health and stamina behavior | verify: movement drains stamina only and idling never heals or restores the wrong resource
- [ ] P0-022 | deps: P0-017 | deliverable: stable scene and spawn IDs replacing hard-coded scene dictionaries and `Doors/door_<tag>` paths | verify: automated transition test loads every active destination and spawn
- [ ] P0-023 | deps: P0-017 | deliverable: audited Godot import sidecars and cache policy | verify: clean clone regenerates caches while preserving required import settings
- [x] P0-024 | deps: none | deliverable: repository without tracked `.DS_Store` files and with ignore coverage | verify: `git ls-files '*.DS_Store'` returns no paths
- [ ] P0-025 | deps: none | deliverable: Git LFS or external-storage policy for approved large binary sources | verify: policy defines tracked formats, size threshold, retrieval, and failure behavior
- [x] P0-026 | deps: P0-002 | deliverable: temporary freeze notice for new assets using the current isometric, pixel-frame, or superseded HUD pipeline | verify: `AGENTS.md` contains an explicit prohibition linked to P0-040 and lists the blocked asset classes
- [ ] P0-027 | deps: none | deliverable: art and audio inventory classified as `approved`, `prototype`, `unknown rights`, `inconsistent`, or `archive` | verify: every imported runtime image and audio file has one classification
- [ ] P0-028 | deps: P0-027 | deliverable: `assets/SOURCES.csv` with asset ID, path, creator or tool, model/version, prompt or URL, seed, license, edits, and approval | verify: schema validation passes and every active runtime asset has one row
- [ ] P0-029 | deps: P0-028 | deliverable: quarantine for assets with unknown origin or commercial rights | verify: Godot does not import quarantined assets
- [ ] P0-030 | deps: P0-018,P0-027 | deliverable: active runtime folders containing only slice candidates and required shared assets | verify: inventory reports no archived or unclassified asset in the active import path
- [ ] P0-031 | deps: none | deliverable: generated report of broken active Markdown links, duplicate character names, contradictory dates, and missing references | verify: report command exits nonzero for a seeded invalid fixture and zero for clean active docs
- [ ] P0-032 | deps: P0-006,P0-031 | deliverable: archived speculative locations and NPC documents outside approved scope | verify: active documentation contains no unresolved link to archived speculative content
- [ ] P0-033 | deps: P0-017,P0-026 | deliverable: one comparison-room greybox with movement, collision, Y-sort, doorway, foreground fade, six NPC bodies, dialogue interaction, and combat exchange | verify: all listed behaviors run in one scene
- [ ] P0-034 | deps: P0-018,P0-033 | deliverable: migration matrix for current TileSets, maps, collisions, animations, HUD, and assets | verify: every slice-relevant current artifact is marked `retain`, `convert`, or `archive`
- [ ] P0-035 | deps: P0-033 | deliverable: current diamond-isometric/eight-direction and proposed orthogonal/four-direction variants of the same room | verify: both variants contain equivalent navigation, interaction, and combat content
- [ ] P0-036 | deps: P0-035 | deliverable: pixel, digital-woodcut, and clean-painted visual targets using the same composition | verify: all three are reviewed at identical camera framing and gameplay scale
- [ ] P0-037 | deps: P0-036 | deliverable: shared cutout rig with idle, four-direction walk, forge strike, hammer attack, guard, hit, and fall | verify: one rig plays every required animation without frame-specific character redraws
- [ ] P0-038 | deps: P0-035,P0-037 | deliverable: comparison report for import time, frame time, texture memory, navigation defects, animation reuse, and NPC-variant production time | verify: report contains repeatable procedure, hardware, raw measurements, and result
- [ ] P0-039 | deps: P0-036,P0-037 | deliverable: blind gameplay-scale readability test with at least five participants | verify: results record silhouette, interaction, depth, and motion recognition per target
- [ ] P0-040 | deps: P0-034,P0-038,P0-039 | deliverable: approved engine, perspective, and visual-style decision plus `docs/ART_BIBLE.md` | verify: decision freezes internal resolution, zoom, character height, projection, pivots, shadows, outlines, value hierarchy, and day/night palettes
- [ ] P0-041 | deps: P0-040 | deliverable: removed or replaced HUD elements for NATURAL aspects, 21 elements, and ruler/rebel balance | verify: active slice UI contains none of the superseded systems

## P1 - Tested runtime and content foundation

- [ ] P1-001 | deps: P0-015,P0-016,P0-017 | deliverable: CI workflow for clean import, parser/startup, tests, validation, active links, manifest coverage, and desktop export smoke | verify: CI passes on clean main and fails on seeded parser, link, and manifest errors
- [ ] P1-002 | deps: P1-001 | deliverable: one documented Godot test framework or minimal headless harness | verify: one command discovers tests, reports failures, and returns correct exit codes
- [ ] P1-003 | deps: P0-008,P0-013 | deliverable: JSON schemas and examples for characters, dialogue, barks, quests, items, commissions, and locations | verify: valid examples pass and seeded invalid examples fail schema validation
- [ ] P1-004 | deps: P1-003 | deliverable: Python content validator for schemas, references, reachability, duplicate IDs, unsupported conditions, and missing assets | verify: validator tests cover every failure class and CI invokes it
- [ ] P1-005 | deps: P1-003,P1-004 | deliverable: typed read-only `ContentDB` loading validated slice JSON | verify: lookup tests return known records and reject missing or malformed IDs
- [ ] P1-006 | deps: P1-002 | deliverable: typed versioned `GameState` model | verify: tests cover default state, facts, relationships, pressures, phase, player state, and forged records
- [ ] P1-007 | deps: P1-006 | deliverable: atomic one-slot manual save and phase-boundary autosave with one backup | verify: round-trip tests preserve all state and interrupted writes retain a loadable backup
- [ ] P1-008 | deps: P1-007 | deliverable: save validation and migration harness | verify: tests cover truncated data, wrong types, unknown versions, and every released fixture
- [ ] P1-009 | deps: P1-006 | deliverable: debug state inspector with deterministic reset and branch/phase jump | verify: a developer reaches every slice phase and valid branch without replaying earlier content
- [ ] P1-010 | deps: P1-005,P1-006 | deliverable: allowlisted declarative condition and effect evaluator | verify: tests cover all operators and reject arbitrary script expressions
- [ ] P1-011 | deps: P1-010 | deliverable: `DialogueRunner` supporting choices, conditions, effects, once-only lines, and phase barks | verify: content-only test dialogue changes state and the next conversation without custom NPC code
- [ ] P1-012 | deps: P0-014,P1-011 | deliverable: dialogue UI with speaker, portrait, text, choices, continue, skip, backlog, and disabled-choice reason | verify: keyboard, mouse, and gamepad complete a branching dialogue at all supported text scales
- [ ] P1-013 | deps: P1-012 | deliverable: dialogue settings for text speed, font size, contrast, subtitle background, and reduced motion | verify: settings persist across restart and affect the dialogue test scene
- [ ] P1-014 | deps: P1-012 | deliverable: pseudo-localization and dialogue overflow test | verify: expanded pseudo-localized strings fit or scroll without clipping at target resolutions
- [ ] P1-015 | deps: P1-005,P1-006,P1-010 | deliverable: `QuestManager` with explicit validated quest transitions | verify: tests traverse every valid slice transition and reject invalid transitions
- [ ] P1-016 | deps: P1-015 | deliverable: journal showing current objective and discovered evidence without hidden outcomes | verify: journal updates from quest state and persists through save/load
- [ ] P1-017 | deps: P1-006,P1-015 | deliverable: authored morning, investigation, night, and reflection phase transitions | verify: phase tests update participating NPC placement, props, barks, patrols, and music hooks
- [ ] P1-018 | deps: P0-022,P1-006 | deliverable: reusable `Interactable` with stable ID, prompt, focus highlight, and callback | verify: keyboard and gamepad activate three different interactable types in a test scene
- [ ] P1-019 | deps: P1-005,P1-006,P1-010 | deliverable: `ForgeCommission` flow displaying customer, object, known purpose, materials, and discovered leverage | verify: one content-defined commission opens and resolves without quest-specific UI code
- [ ] P1-020 | deps: P1-019 | deliverable: honest, subtle-defect, and secret-feature modification support gated by facts or materials | verify: tests confirm unavailable options stay locked and chosen modification creates one explicit forged record
- [ ] P1-021 | deps: P1-020 | deliverable: generic mechanism response to a forged modification | verify: changing content/state alters mechanism behavior without quest-specific branching code
- [ ] P1-022 | deps: P1-019,P0-040 | deliverable: forge feedback for heat, hammer rhythm, quench, maker stamp, and object reveal | verify: automated scene trace emits the five feedback events in order and the forge scene exposes no temperature, strike-accuracy, or timing-score state
- [ ] P1-023 | deps: P0-021,P1-002 | deliverable: coherent player movement and action state machine with input buffering | verify: automated input test finds no stuck state across movement, attack, guard, dodge, hit, and recovery
- [ ] P1-024 | deps: P1-023 | deliverable: hammer light attack, charged attack, guard/parry, dodge, and Iron technique | verify: combat test demonstrates damage, stamina costs, invulnerability, parry, and Iron behavior
- [ ] P1-025 | deps: P1-024 | deliverable: shared watchman and sergeant enemy state machine | verify: both archetypes patrol, detect, telegraph, attack, react, and disengage without duplicated controller code
- [ ] P1-026 | deps: P1-015,P1-025 | deliverable: authored surrender, escape, or bypass outcome support | verify: one encounter resolves without killing and updates the same quest state used by combat
- [ ] P1-027 | deps: P1-024,P1-025 | deliverable: combat reset checkpoint after failure | verify: player retries the encounter without replaying completed dialogue or corrupting quest state
- [ ] P1-028 | deps: P1-024 | deliverable: remappable keyboard/mouse and gamepad actions with focus navigation | verify: all slice actions can be rebound and completed on both input methods
- [ ] P1-029 | deps: P0-040,P1-001 | deliverable: automated asset lint for dimensions, names, layers, pivots, alpha bounds, and source-manifest rows | verify: valid fixture passes and one seeded error per rule fails CI
- [ ] P1-030 | deps: P1-001,P1-024,P1-025 | deliverable: repeatable performance scene and report command | verify: command reports frame time, memory, actor count, and target hardware metadata

## P2 - Vertical-slice production

- [ ] P2-001 | deps: P0-010,P0-013,P1-003 | deliverable: final prologue branch map and state table before prose | verify: every node has entry conditions, effects, exit, and reachable outcome
- [ ] P2-002 | deps: P0-009,P0-013,P1-003 | deliverable: final `A Bitter Brew` branch map and state table before prose | verify: map contains investigation evidence, three forging options, combat and non-combat resolution, and three aftermath states
- [ ] P2-003 | deps: P0-040,P1-029 | deliverable: modular environment kit for forge, street/well, brewery, and checkpoint | verify: four spaces are assembled without bespoke projection or scale exceptions
- [ ] P2-004 | deps: P0-037,P0-040,P1-029 | deliverable: approved layered game models and portraits for Kalev, Mart, Aita, Kaja, Henning, and Jürgen | verify: all six use the shared rig, pass asset lint, and match art-bible silhouette and palette rules
- [ ] P2-005 | deps: P1-025,P2-004 | deliverable: approved watchman and sergeant visual variants | verify: both are distinguishable at gameplay scale without relying on color alone
- [ ] P2-006 | deps: P2-001,P1-011,P1-015,P1-017,P1-018,P1-019,P1-023 | deliverable: playable `The Maker's Mark` tutorial | verify: new game teaches movement, interaction, commission, maker-mark incident, and all three ledger outcomes
- [ ] P2-007 | deps: P2-002,P2-003,P2-004,P2-005,P1-011,P1-015,P1-017,P1-021,P1-026 | deliverable: playable daytime `A Bitter Brew` investigation | verify: player can inspect well, brewery, merchant supply, and checkpoint and produce the expected evidence states
- [ ] P2-008 | deps: P2-007,P1-022 | deliverable: playable `A Bitter Brew` commission with honest, defective, and secret-feature results | verify: each result creates the expected forged record and communicates it audiovisually
- [ ] P2-009 | deps: P2-008,P1-024,P1-025,P1-026,P1-027 | deliverable: playable night consequence with combat and non-combat routes | verify: forged record changes encounter behavior and every route reaches a valid aftermath
- [ ] P2-010 | deps: P2-009,P1-017 | deliverable: three visible `A Bitter Brew` aftermath states | verify: brewery state, Aita state, Mart reaction, and patrol barks differ according to outcome
- [ ] P2-011 | deps: P0-013,P1-011,P1-017 | deliverable: Hingepuu reflection screen with Duty, Fury, Mercy, and visual consequence marks | verify: reflection reacts to prior state, applies one allowlisted effect, and provides equivalent plain-text information
- [ ] P2-012 | deps: P2-006,P2-007,P2-008,P2-009,P2-010,P2-011 | deliverable: complete 30-45 minute vertical-slice flow | verify: new game reaches all three aftermath outcomes without debug intervention
- [ ] P2-013 | deps: P2-012 | deliverable: slice dialogue reduced to at most 2,500 approved words | verify: generated word-count report excludes IDs/metadata and reports 2,500 or fewer spoken/displayed words
- [ ] P2-014 | deps: P2-012 | deliverable: slice soundtrack reduced to at most 12 minutes of unique approved music | verify: manifest reports duration, reuse, streaming settings, and rights for every included track
- [ ] P2-015 | deps: P2-012 | deliverable: quest/tool pouch displaying at most three slice quest items | verify: every branch completes without exceeding three visible quest-item slots
- [ ] P2-016 | deps: P2-012,P1-007,P1-008 | deliverable: save/reload coverage at every phase and branch boundary | verify: automated matrix preserves quest, modification, characters, pressures, player state, and phase
- [ ] P2-017 | deps: P2-012,P1-028 | deliverable: end-to-end keyboard/mouse and gamepad completion | verify: recorded test runs complete every required action without input fallback

## P3 - Slice validation, accessibility, performance, and release

- [ ] P3-001 | deps: P2-012 | deliverable: automated traversal of every valid slice branch and deliberate invalid state | verify: traversal report shows all intended endings reachable and all invalid transitions rejected
- [ ] P3-002 | deps: P2-012 | deliverable: first external playtest round with at least five players focused on comprehension | verify: report records completion time, missed evidence, unclear prompts, deaths, and explanation of the core loop
- [ ] P3-003 | deps: P3-002 | deliverable: fixes for comprehension blockers discovered in round one | verify: every critical/high finding is fixed or explicitly rejected with rationale
- [ ] P3-004 | deps: P3-003 | deliverable: second external playtest round with at least five players focused on choice impact | verify: report records branch distribution, noticed consequences, character understanding, and perceived choice quality
- [ ] P3-005 | deps: P3-004 | deliverable: removal or rewrite of choices that differ only in wording or reward | verify: branch review finds a distinct state or consequence for every retained major choice
- [ ] P3-006 | deps: P3-005 | deliverable: third external playtest round with at least five players focused on usability and polish | verify: report shows no unresolved critical usability issue
- [ ] P3-007 | deps: P1-012,P1-013,P1-028,P2-012 | deliverable: accessibility options for remapping, hold/toggle, text speed, scalable text, subtitle background, focus contrast, screenshake, and reduced flashing | verify: accessibility checklist passes at supported resolutions and on both input methods
- [ ] P3-008 | deps: P3-007 | deliverable: information design with no required color-only, audio-only, or prior-history dependency | verify: accessibility review completes slice with color removed, audio muted, and no external historical explanation
- [ ] P3-009 | deps: P2-014 | deliverable: approved forge, town, tension, night, and consequence music stems with runtime streaming | verify: runtime loads only approved tracks and music memory remains within recorded budget
- [ ] P3-010 | deps: P2-012 | deliverable: normalized forge, footsteps, UI, combat, gate, crowd, and environment sound families with concurrency limits | verify: loudness report passes and stress scene produces no uncontrolled sound stacking
- [ ] P3-011 | deps: P1-030,P2-012 | deliverable: optimized slice meeting the explicit minimum-hardware target | verify: busiest scene sustains the recorded frame-time and memory budgets with headroom
- [ ] P3-012 | deps: P1-001,P2-012,P3-007,P3-011 | deliverable: tested desktop export set and honest supported-platform declaration | verify: each declared platform installs, starts, saves, loads, and exits without critical error
- [ ] P3-013 | deps: P0-028,P2-012 | deliverable: third-party notices and final slice asset/license report | verify: every exported non-original asset maps to a notice and approved manifest row
- [ ] P3-014 | deps: P3-001,P3-006,P3-008,P3-012,P3-013 | deliverable: signed vertical-slice gate report containing every acceptance criterion copied from README | verify: report records pass evidence for each criterion, including at least five players explaining forge-to-consequence and at least four rating the major choice difficult for narrative rather than UI reasons
- [ ] P3-015 | deps: P3-014 | deliverable: tagged vertical-slice release with frozen compatible save and content schema versions | verify: release tag rebuilds from clean clone and loads its published save fixture

## P4 - First complete campaign after slice approval

- [ ] P4-001 | deps: P3-014 | deliverable: approved branch map and state table for `The Bell and the Chain` | verify: map reuses commission, mechanism, gate, patrol, and consequence systems without a new major framework
- [ ] P4-002 | deps: P4-001 | deliverable: playable and playtested `The Bell and the Chain` cycle | verify: gate-chain modification changes finale-ready state and the cycle passes its branch matrix
- [ ] P4-003 | deps: P4-002 | deliverable: approved branch map and state table for `Bread and Iron` | verify: map reuses evidence, supplier, inventory, and location-state systems within campaign budgets
- [ ] P4-004 | deps: P4-003 | deliverable: playable and playtested `Bread and Iron` cycle | verify: one named family receives a visible consequence in every valid outcome
- [ ] P4-005 | deps: P4-004 | deliverable: approved branch map and state table for `The Price of a Name` | verify: map reuses relationships, detention, false evidence, and Hingepuu without a new major system
- [ ] P4-006 | deps: P4-005 | deliverable: playable and playtested `The Price of a Name` cycle | verify: Mart, Kaja, Henning, and Kalev receive causally consistent state changes in every branch
- [ ] P4-007 | deps: P4-006 | deliverable: one approved ambiguous folklore quest introducing Ellen, Ember or Root | verify: quest remains understandable without literal magic and introduces no second-game subsystem
- [ ] P4-008 | deps: P4-002,P4-004,P4-006,P4-007 | deliverable: Viru Gate finale reusing all earlier forged objects and character states | verify: Open, Seal, and Break ending families are reachable through visible prior decisions
- [ ] P4-009 | deps: P4-008 | deliverable: character-level epilogue for Mart, Aita, Kaja, Henning, Jürgen, Ellen, forge, and district | verify: automated matrix finds no impossible combination, missing core character, or universal morality score
- [ ] P4-010 | deps: P4-009 | deliverable: campaign content-budget report | verify: release remains within one district, seven core characters, eight substantial quests, five cycles, one finale, and approved dialogue/audio budgets
- [ ] P4-011 | deps: P4-010 | deliverable: automated full-campaign branch traversal and save compatibility suite | verify: every intended ending is reachable and every published save fixture loads or migrates
- [ ] P4-012 | deps: P4-011 | deliverable: external full-campaign playtest and critical/high issue closure | verify: report contains completion, comprehension, pacing, combat, choice, and continuity results with no unresolved critical/high issue
- [ ] P4-013 | deps: P4-012 | deliverable: first complete campaign release candidate | verify: clean-clone CI, supported-platform smoke tests, license report, accessibility checklist, and campaign acceptance matrix all pass
