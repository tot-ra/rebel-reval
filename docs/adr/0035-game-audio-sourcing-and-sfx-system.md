# ADR 0035: Game audio sourcing and the sound-effects system (RFC)

- **Status:** Proposed (RFC, 2026-10-07). Nothing here is implemented. No audio code, catalog schema, or bulk asset import may land until a maintainer marks this ADR Accepted.
- **Scope:** Every non-music sound in the game: ambience, weather, animals, water, crowds, footsteps, impacts, weapons, vocal efforts, UI, magic. Music stays with [`music/README.md`](../../music/README.md) and `scripts/global/music_director.gd`.
- **Amends:** the asset freeze ([`AGENTS.md`](../../AGENTS.md#scope)) only in that it names an allowed audio pipeline. It does not touch the visual freeze.
- **Does not supersede:** ADR 0003 (offline authored content, no runtime LLM; this ADR also forbids runtime audio generation), [`ASSET_STORAGE_POLICY.md`](../ASSET_STORAGE_POLICY.md), [`reports/bird_audio_sourcing.md`](../reports/bird_audio_sourcing.md) (still the bird-species source of truth).
- **Feeds:** a future `docs/SYSTEMS/AUDIO.md` (`Status: planned` until code lands).

## Summary

We need thousands of short sounds across roughly 15 categories, with enough variation that nothing audibly repeats, and every file must be safe to ship commercially. This RFC proposes:

1. **Three sourcing tiers**: licensed recordings first, own recordings second, AI generation for what recordings cannot supply (magic, spirits, gap-filling variations).
2. **A strict license gate**: a short allowlist of licenses and tools, a denylist, and a provenance row for every file.
3. **A small data-driven runtime** on Godot's built-in audio: a JSON sound catalog, variation pools, surface resolution, layered ambience, extra buses. No Wwise or FMOD.
4. **Phased delivery**, vertical-slice first (forge and Lower Town), each phase independently verifiable.

## Context

### What exists today

- Buses `Music`, `SFX`, `Voice` in `audio/default_bus_layout.tres`; volume settings in `scripts/settings/audio_bus_service.gd`.
- `sounds/` holds 34 bird species and ~25 insect species (xeno-canto, per-file license rows in `manifest.csv`), plus `water/`, `weather/`, and three ad-hoc clips (`door.mp3`, `walk_wood.mp3`, `walking_on_mud_stable_audio_3.mp3`). The wood and mud steps and the door are AI-generated (Stable Audio) and logged in `assets/SOURCES.csv` as maintainer AI generation.
- Sound is wired point by point (`sky_weather_roof_audio.gd`, `nunnatorn_audio_controller.gd`, world item pickup feedback). There is no shared way to say "play a footstep on this surface" or "this district sounds like a market at noon".

### What is missing

Surface-aware footsteps, weapon and armour impacts, animal sounds beyond birds and insects, crowd and city beds, rain/hail/thunder variety, vocal efforts, UI sounds, and any rule for avoiding repetition. There is also no written license policy for non-bird audio.

### What the research says (summary; full list in References)

- **Variation matters more than fidelity.** Production tools avoid repeats with shuffle/"bag" selection: one Wwise example uses 15 wood-footstep variations and avoids the last 10 played. Godot's `AudioStreamRandomizer` provides the same idea (random stream plus pitch and volume jitter).
- **Ambience is layered**: a quiet base bed, a mid-ground layer, and sporadic one-shots triggered randomly or by game state. Fixed-interval distinctive events near a loop point expose the loop. Ghost of Tsushima and Dying Light 2 talks describe region/time/weather-driven ambience and automatic placement for small teams.
- **Footstep perception**: listeners classify surface *type* (solid, aggregate, liquid, hybrid) accurately and distinguish materials inside one type poorly (Turchet, Nordahl, Serafin). So cover surface types first.
- **Soundscape heuristics**: do not let every triggered sound play at once; keep important cues audible (Pires, Alves, Roque on "healthy soundscape").
- **AI audio models are good for texture, weak for time-structured and multi-source sound**, and their licenses are a minefield: AudioLDM 2 (CC-BY-NC-SA), TangoFlux (research only), MMAudio weights (CC-BY-NC) are non-commercial; HunyuanVideo-Foley excludes the EU, UK and South Korea. Stable Audio 3 (official weights, Stability AI Community License) and ElevenLabs paid plans permit commercial use.

Caveat on evidence: license statements below come largely from secondary sources and must be re-verified against the primary text at acquisition time (see License gate).

## Goals and non-goals

**Goals**

- Cover every situation in the table under *Coverage matrix* at shipped quality for the vertical slice, then widen per act.
- No audible repetition in ordinary play: pools with anti-repeat, pitch/volume jitter, layered ambience.
- Every shipped audio file has a provenance row and a passing license check.
- Runtime stays deterministic where gameplay depends on it (ADR 0003 spirit): sound selection may use a seeded RNG owned by the audio layer; it never affects game state.

**Non-goals**

- Runtime audio generation, runtime LLM/TTS, or free-text voice.
- Music (separate pipeline).
- Wwise/FMOD adoption, physically based sound synthesis, wave-based acoustic simulation (see Alternatives).
- Full voice-over production. NPC and protagonist voice are tracked separately (Open question 3).
- Any change to the visual asset freeze.

## Decision

### 1. Sourcing tiers

| Tier | Source | Use for | Rule |
|------|--------|---------|------|
| **A. Licensed recordings** | Sonniss GameAudioGDC bundles; Freesound **CC0** (CC-BY allowed with credits); xeno-canto per `bird_audio_sourcing.md`; one or two paid commercial libraries chosen by the maintainer (a medieval-life library such as Boom Library "Medieval Life", a crowd/walla library such as Epic Stock Media "Public Spaces") | Weather, water, animals, crowds, city beds, weapon/armour Foley, base footsteps | Default choice. Real recordings beat generation for long stable beds and animals. |
| **B. Own recordings** | Maintainer or contractor Foley session: chainmail, gambeson, leather, cloth, forge tools, anvil, wood and gravel steps, doors, barrels, carts | Signature sounds the world needs and libraries do not match; period-specific props | One session covers many categories. Record to the specification in Appendix A. |
| **C. AI generation** | Stable Audio 3 (official weights) locally, or ElevenLabs Sound Effects on a **paid** plan | Magic, spirit-world, impossible or stylised sounds; extra variations of an existing Tier A/B sound; placeholders while Tier A/B is pending | Never the only source for animals or crowds. Tier C placeholders must be replaceable by ID without code changes. |

Reference/inspiration only, never shipped: BBC Sound Effects archive (RemArc, non-commercial), any CC-BY-NC material, YouTube or game rips.

### 2. License gate

A file may enter `sounds/` only if its row in `assets/SOURCES.csv` passes `tools/` validation (to be extended in Phase 0) with:

**Allowlist:** CC0; CC-BY (credit added to `docs/THIRD_PARTY_NOTICES.md` and the in-game credits); CC-BY-SA only for xeno-canto bird material already accepted by `bird_audio_sourcing.md`, pending legal review (Open question 1); commercial royalty-free libraries with a stored copy of the license and purchase record; Sonniss GDC bundles with a stored copy of the license for the exact bundle year; own recordings (rights assigned); AI output from allowlisted tools used on a qualifying plan.

**Denylist:** CC-BY-NC and any NC/ND variant; BBC RemArc; free-tier ElevenLabs output; AI models with non-commercial weights (AudioLDM 2, TangoFlux, MMAudio, unverified mirrors of Stable Audio weights); audio from games, films, or streaming; anything whose license cannot be saved as a document.

**Required provenance columns** (extends the existing `SOURCES.csv` header: `asset_id, path, creator_or_tool, model_version, prompt_or_url, seed, license, edits, approval`): `prompt_or_url` must be the exact source URL or purchase record; `license` must name the SPDX-style identifier or library license name and version/year; AI rows must record model, version, prompt, seed, plan/tier, and generation date. A tier-C file generated on a free plan is `quarantine`, not `approved`.

**Re-verification:** the person approving a source reads the primary license text and stores a copy under `docs/reports/audio_licenses/<source>/` (small text/PDF). Secondary summaries (including this RFC) are not approval.

**Store disclosure:** shipping any AI-generated audio requires an AI-use disclosure on Steam; the audio provenance table is the evidence base.

### 3. Runtime architecture

Stays inside Godot's audio server. New code is small and data-driven; no event bus.

**Catalog** (`content/audio/sfx_catalog.json`, validated by `tools/validate_content.py`; schema `schemas/sfx_catalog.schema.json`). Stable IDs such as `sfx.footstep.wood.walk`, `sfx.weapon.sword.hit.flesh`, `amb.reval_east.day`. Each entry: `bus`, `streams` (paths, pool), `volume_db`, `pitch_jitter`, `volume_jitter_db`, `no_repeat` (default last N), `max_voices`, `cooldown_ms`, `spatial` (2D/3D, attenuation), `source_ids` (provenance rows), `tier`.

**Playback**: `SfxPlayer` helper (not an autoload event bus) builds an `AudioStreamRandomizer` from a catalog entry and plays it on `AudioStreamPlayer` or `AudioStreamPlayer3D`. Pool of players with voice limits per `max_voices` group. Callers say `SfxPlayer.play(&"sfx.footstep.wood.walk", position)`; they never reference files.

**Surfaces**: `SurfaceResolver` maps a raycast hit, tile, or map-blueprint material to a surface type from the shared vocabulary `wood, stone, dirt, mud, grass, gravel, sand, snow, water_shallow, water_deep, metal, cloth/carpet`. Footsteps are triggered by animation foot-contact events or movement distance, never by timers inside the sound. First cut covers six types (wood, stone, dirt/mud, grass, gravel/sand, shallow water), then widens.

**Ambience**: `AmbienceController` blends layers selected by district, time of day (`TIME_AND_PHASES`), weather, and interior/exterior:

1. **Bed**: 1-3 quiet looping streams (city hum, forest, harbour).
2. **Mid layer**: looping or long streams at different lengths (crowd walla density by time/market).
3. **Spot one-shots**: random with min/max interval, 3D position around the listener, anti-repeat (roosters, cart, bell, distant hammer, birds, dog).
4. **Weather overlay**: rain intensity levels, wind, thunder with distance delay, hail.

Crossfades reuse the pattern in `music_director.gd`. A soundscape budget (maximum simultaneous spot sounds per layer) keeps cues audible.

**Buses**: add `Ambience`, `Weather`, `Footsteps`, `Combat`, `UI` as children of `SFX`; `Voice` stays. Each is exposed in settings only if a task justifies it (default: one SFX slider, plus Music and Voice). Ducking: `Ambience`/`Weather` duck under `Voice` (dialogue) and `Combat` using the built-in compressor with sidechain.

**Space**: reverb zones via `Area3D` bus override (interior/cathedral/forge) in Phase 5; occlusion is a project-owned raycast plus low-pass on a dedicated bus (Godot has none built in), also Phase 5 and only if the slice needs it.

**Determinism and saves**: audio selection uses its own RNG, seeded per session; no game state depends on it. Nothing in the catalog is saved. Ambient timers resume from scratch on load.

**Performance**: streams are compressed (Ogg Vorbis for beds and one-shots; short UI sounds may stay WAV); loops authored seamless; bank loads are per-district. Budget set in Phase 0 via `tools/run_performance_report.sh`.

### 4. Coverage matrix

Target counts are proposals for the slice; maintainers may change them. "Var." is distinct recordings per pool.

| Situation | Examples | Tier | Var. target (slice) | Notes |
|-----------|----------|------|---------------------|-------|
| Weather | Rain light/heavy, hail, thunder near/far, wind (open/street/interior leak), storm | A (libraries, Freesound CC0) | 3-4 loops per intensity, 6 thunders | Loops; thunder is a one-shot with distance delay |
| Water | River, sea shore, harbour lap, creek, drips, splash | A, existing `sounds/water` | 2-3 loops per type, 6 splashes | Day/night variants by layering insects/birds, not separate loops |
| Birds | 30 approved species | A (xeno-canto) | existing | Governed by `bird_audio_sourcing.md` |
| Insects | Crickets, grasshoppers, bees, flies | A (xeno-canto, Freesound CC0) | existing, add bee/fly | Night/day gating |
| Domestic animals | Cow, hen, rooster, duck, goose, pig, horse, sheep, cat, dog | A (libraries), CC0 gaps | 4-6 per animal and state | Rooster at dawn spot-trigger; dog alert/bark |
| City beds | Street hum, market, harbour, cathedral square, forge yard, night town | A + B | 2-3 beds per district class | Mixed with spot layer |
| Crowd | Walla low/med/high, cheer, panic, murmur at church | A (walla library) | 3 densities x 2 moods | Walla must stay unintelligible |
| Footsteps | Per surface x gait (walk, run, sneak), shoe type later | A + B, C for fill-in | 8 per surface x gait | Anti-repeat last N; start with 6 surfaces |
| Cloth/armour/gear | Gambeson, chainmail, leather, belt, pouch | B first, A fallback | 6 per type | Layer under footsteps |
| Forge and crafts | Hammer, anvil, quench, bellows, file, saw | B + A | 6-8 per action | Signature hub sounds |
| Weapons | Swing, draw, parry, clash, hit flesh/armour/wood/shield | A + B, C for stylised accents | 5 per weapon x material | Combat bus; priority over ambience |
| Object impacts | Drop, break, door, chest, barrel, cart | A + B | 4-6 per material | Reuses the surface vocabulary |
| Vocal efforts | Grunts, pain, death, breath, shouts (not speech) | Open question 3 | 6 per emotion per voice | Not AI-cloned real voices |
| Magic and spirit world | Aspect casts, spirit duel, whispers, drones | **C** (Stable Audio 3 / ElevenLabs paid) plus A layers | 4-6 per cast | Safest place for generation |
| UI | Menu, confirm, journal, pickup | A or C | 3 per action | Short; WAV allowed |
| Generic situational | Stingers for discovery, danger, quest update | A or C | 3 per type | Sparse use |

### 5. AI generation rules (Tier C)

- Allowed tools: official Stable Audio 3 weights (accept the Community License on the official repository; commercial use is under the revenue threshold, re-check if revenue crosses it); ElevenLabs Sound Effects on a paid plan (outputs generated on the free plan are quarantined and regenerated).
- Forbidden for shipping: non-commercial research models and unverified mirrors (see denylist).
- Every generated file is post-processed (trim, normalise, loop-check, high-pass for rumble, loudness target) and logged with model, version, prompt, seed, plan, date.
- Prefer generating *variations of a known-good recorded sound* over generating from scratch; reject outputs with audible artefacts, spurious voices, or unstable timing.
- Disclose AI audio on the store page and in credits per platform rules.

### 6. Phased delivery

Each phase is a separate task created with `tasks.create` after Acceptance. Proposed phases (IDs assigned at creation):

| Phase | Deliverable | Verification |
|-------|-------------|--------------|
| **0. Policy and tooling** | `schemas/sfx_catalog.schema.json`, catalog validator, `SOURCES.csv` audio checks (license gate), `docs/reports/audio_licenses/`, `docs/SYSTEMS/AUDIO.md` (planned), budget for libraries/session | `python3 tools/validate_content.py`, `tools/validate_asset_sources.py`, unit tests for the gate |
| **1. Core runtime** | `SfxPlayer`, buses, `sfx_catalog.json` seeded with existing sounds, settings wiring | `tests/godot/test_sfx_catalog.gd`, `test_sfx_player_no_repeat.gd` |
| **2. Slice pilot** | Forge + Lower Town: 6 footstep surfaces, doors, forge sounds, city bed + spot layer, rain | Headless catalog coverage test; captured session log of triggered IDs; maintainer listening review |
| **3. Combat and gear** | Weapons, impacts, armour/cloth, vocal efforts | Test: every combat event ID resolves; loudness report |
| **4. Fauna and crowds** | Domestic animals, crowd densities, market/harbour/church beds | Coverage test per district; per-category variation counts met |
| **5. Space** | Reverb zones, optional occlusion, ducking tuning | Listening review, performance report within budget |
| **6. Act expansion** | Per act: districts, creatures, magic | Per-act coverage matrix |

## Alternatives considered

1. **Adopt Wwise or FMOD.** Industry standard, rich authoring (random containers, switches, spatial). Rejected for now: the Godot Wwise integration we found is a community GDExtension last updated for Wwise 2023.1 / Godot 4.2, we found no FMOD integration, and the engine is pinned to Godot 4.7. Revisit if the catalog approach hits a wall.
2. **Fully procedural/physically based sound** (FoleyAutomatic-style modal synthesis, Farnell's Pure Data approach). Compelling for impacts, but research code is not production tooling for our engine, and listening studies suggest recorded samples with variation are enough for surface classification.
3. **All-AI generation.** Fastest and cheapest per sound, but weak at long beds and animals, the model-license landscape is hazardous, and Valve requires disclosure and proof of rights. Rejected as the primary source; accepted for Tier C.
4. **Library-only, no own recordings.** Lowest effort, but period-specific props and a distinctive forge identity are unlikely to match stock. Own recordings are a bounded cost for the signature sounds.
5. **Hire a sound designer or outsource the whole layer.** Highest quality and legal clarity, highest cost. Not excluded: Tier B session and Tier A purchases can be contracted. The catalog design is the same either way.

## Consequences

- Positive: one policy for all non-music audio; repetition handled in data; every sound traceable; AI used where it is strongest.
- Cost: a licensed-library budget (amount to be set by the maintainer; no prices are assumed here), one Foley session, and listening review time.
- Risk: license facts in this RFC are mostly secondary-source; wrong reading of a license is the largest risk, hence the stored-license rule.
- Risk: xeno-canto CC-BY-SA and share-alike on audio embedded in a shipped game is not settled here (Open question 1).
- Risk: large audio volume; follow `ASSET_STORAGE_POLICY.md` (LFS at 10 MiB; district-scoped banks).
- Scope-change rule: see *Scope offset*.

## Scope offset (required by AGENTS.md)

Equivalent-cost scope proposed to be removed or deferred, **pending maintainer confirmation**:

- Freeze further bird-species expansion beyond the 30 approved (`P0-105` gap-species sourcing and the paid Macaulay/Veljo Runnel acquisitions stay as optional follow-ups).
- Defer per-district bespoke ambience for Act 2 and Act 3 districts until after the vertical slice passes.
- Defer UI sound polish beyond a single base set.

## Open questions

1. **xeno-canto CC-BY-SA**: does share-alike propagate to a game that bundles the recordings? Needs a legal read. If yes, keep birds in separately extractable files, document, or replace with CC0/BY/paid material.
2. **Budget**: which paid libraries and how much, and whether to contract a Foley session.
3. **Voice**: protagonist and NPC vocal efforts and barks. Options: licensed vocal-effort packs, hired voice actors, or AI voices under a licence that covers voice rights. Never clone a real person's voice without a written release.
4. **AI disclosure and platform**: confirm store wording once the audio set is known.
5. **Sonniss licence text**: store the exact bundle licence for the year used; confirm the AI-training clause does not affect our use (we do not train models).
6. **Loudness standard** for the mix (target LUFS per bus).

## Verification of this ADR

- `python3 tools/docs_index.py --check` and `python3 tools/generate_active_docs_report.py --check` pass.
- Acceptance: maintainer edits Status to Accepted, answers Open questions 2 and 3, and confirms the scope offset. Implementation tasks are then created per phase.

## Appendix A: own-recording specification (Tier B)

- 24-bit / 48 kHz WAV, close-mic cardioid or dynamic mic 15-30 cm from the source, quiet room (soft furnishings) plus 30 s of room tone per setup.
- Record 10-15 takes per action; keep takes that differ in intensity and timing, not near-duplicates.
- Safety first: dull practice blades, no live edges on armour tests.
- Per surface: walk, run, sneak, scuff, turn, land; two shoe types if available.
- Deliver unedited masters (LFS) plus edited single hits; log recordist, date, location, gear.

## References

**Papers and books**
- van den Doel, Kry, Pai, *FoleyAutomatic*, SIGGRAPH 2001: <https://www.cs.mcgill.ca/~kry/pubs/foleyautomatic/foleyautomatic.pdf>
- Farnell, *Designing Sound*, MIT Press, 2010; interview: <https://designingsound.org/2012/01/18/procedural-audio-interview-with-andy-farnell/>; course: <https://sopi.aalto.fi/teaching/pa>
- *Sound Synthesis, Propagation, and Rendering: A Survey*: <https://arxiv.org/pdf/2011.05538>
- Turchet, footstep synthesizer (2016): <https://www.eecs.qmul.ac.uk/~josh/documents/2016/turchet%20-%202016.pdf>; Nordahl et al., IEEE TVCG 2011: <https://vbn.aau.dk/ws/files/58485705/NORDAHL_IEEE_TVCG_VOL_17_NO._9_SEPTEMBER_2011.pdf>; Serafin, Turchet, Nordahl: <https://vbn.aau.dk/ws/files/18424996/serafin_turchet_nordahl.pdf>
- *Neural Synthesis of Footsteps Sound Effects with GANs*: <https://arxiv.org/pdf/2110.09605>
- AudioLDM: <https://arxiv.org/pdf/2301.12503>; AudioLDM 2: <https://arxiv.org/pdf/2308.05734>; Make-An-Audio 2: <https://arxiv.org/pdf/2305.18474>; AudioLCM: <https://arxiv.org/pdf/2406.00356>; *Taming Data and Transformers for Audio Generation*: <https://arxiv.org/pdf/2406.19388>
- FSD50K: <https://arxiv.org/pdf/2010.00475>
- Raghuvanshi, Snyder, *Parametric Wave Field Coding for Precomputed Sound Propagation*, ACM TOG 2014: <https://www.microsoft.com/en-us/research/publication/parametric-wave-field-coding-precomputed-sound-propagation/>
- Schafer, *The Soundscape* (1977); Collins, *Game Sound*, MIT Press, 2008; Pires, Alves, Roque, dynamic soundscape heuristics, Audio Mostly 2014; Oliva (2012); Aalborg thesis on FPS acoustic ecology: <https://vbn.aau.dk/en/publications/the-acoustic-ecology-of-the-first-person-shooter>
- Historical soundscape reconstruction: *Aural Histories: Medieval Coventry*: <https://pub.ioa.org.uk/events/aural-histories-echoes-of-medieval-coventry>

**Industry talks and practice**
- Ghost of Tsushima ambience (GDC): <https://gdcvault.com/play/1026976/Big-World-Small-Team-Designing>; interview: <https://www.asoundeffect.com/?p=494381>
- Dying Light 2 open-world audio (GDC): <https://gdcvault.com/play/1029272/Open-World-Audio-in-Dying>
- Spider-Man city soundscape (GDC): <https://gdcvault.com/play/1026097/Designing-the-Bustling-Soundscape-of>
- Shadow of Mordor (GDC): <https://gdconf.com/news/hear_how_shadow_of_mordor_and_>
- Layering and loops: <https://splice.com/blog/audio-soundscape-for-video-games>, <https://bugnet.io/blog/how-to-design-ambient-sound-layers>, walla: <https://sounddesign.irpr.agency/guides/what-is-walla-and-loop-group/>
- Wwise random containers and switches: <https://www.audiokinetic.com/learn/videos/UH7OEm_g9Mg/>
- Godot audio streams: <https://docs.godotengine.org/en/stable/tutorials/audio/audio_streams.html>; Wwise Godot integration: <https://github.com/alessandrofama/wwise-godot-integration>

**Licenses and legal (verify primary text before use)**
- Stable Audio 3 Small SFX (official): <https://huggingface.co/stabilityai/stable-audio-3-small-sfx>; Stability announcement: <https://stability.ai/news-updates/meet-stable-audio-3-the-model-family-built-for-artistic-experimentation-with-open-weight-models>
- ElevenLabs sound effects terms: <https://elevenlabs.io/sound-effects-terms>; commercial page: <https://elevenlabs.io/sound-effects/commercial>
- Sonniss GDC bundle coverage: <https://gamefromscratch.com/sonniss-27-5gb-sound-effect-giveaway-at-gdc-2024/>, <https://rekkerd.org/sonniss-releases-gdc-2026-game-audio-bundle/>
- Freesound API: <https://freesound.org/docs/api/overview.html>; generative AI position: <https://blog.freesound.org/?p=2082>
- BBC Sound Effects archive (non-commercial RemArc): <https://musictech.com/news/music/the-bbc-sound-effects-archive-over-33000-free-samples>
- HunyuanVideo-Foley license: <https://github.com/Tencent-Hunyuan/HunyuanVideo-Foley>
- Valve and AI content: <https://www.clydeco.com/insights/2025/07/ai-generated-content-in-gaming>
- Libraries: Boom Library Medieval Life <https://www.boomlibrary.com/?p=782>; Epic Stock Media Public Spaces <https://epicstockmedia.com/product/public-spaces-crowds-walla-and-everyday-ambiences/>
