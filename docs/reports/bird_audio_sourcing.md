# Bird song sourcing for ambient audio (feeds P0-105)

Goal: obtain clean, commercially usable field recordings of the **30 approved bird
species** ([`docs/FLORA_FAUNA.md`](../FLORA_FAUNA.md) bird ledger / catalog
[`scripts/map/view3d/map_view_bird_species.gd`](../../scripts/map/view3d/map_view_bird_species.gd)),
recorded in or near the Estonian / north-Baltic region, for use as ambient
song and call cues.

Clip length target: **15-90 s** per usable take. Not multi-minute loops (too long,
heavy, repetitive) and not sub-5 s snippets (too short to sound natural). The
script default filter is `len:15-90`.

## Sources evaluated

| Source | Estonian coverage | License model | Commercial OK? | Verdict |
|---|---|---|---|---|
| **xeno-canto.org** | Excellent - filter by `cnt:Estonia`, thousands of recordings, per-recording quality grade A-E | Per recording: CC0, CC BY, CC BY-SA, **and** CC BY-NC(-SA/-ND) | **Only** the CC0 / BY / BY-SA subset | **Primary source.** Filter per recording. |
| **freesound.org** | Some European recordings, not Estonia-tagged reliably | Per sound: CC0, CC BY, CC BY-SA, CC BY-NC | Only CC0 / BY / BY-SA | Secondary / gap filler. |
| **Macaulay Library (eBird / Cornell)** | Very good regional coverage incl. Baltic birds | Free for research/education; **commercial use requires a paid license** via Cornell's ticketing system and the "Commercially requestable media" filter | **Yes, with fee and contract** | Not a free source. Viable paid fallback for gap species (cormorant, white-tailed eagle) when xeno-canto has zero CC0/BY/BY-SA takes. |
| **loodusheli.ee** ("Kõrv loodusesse", Univ. of Tartu Natural History Museum) | Best available - recorded *in Estonia* by Estonian naturalists, incl. species soundscapes by biotope/season | Per species page: **CC BY-NC 3.0 EE** (<http://creativecommons.org/licenses/by-nc/3.0/ee/>); page footer also identifies TÜ loodusmuuseum | **No** for commercial use under the published NC terms; written permission or a separate commercial grant is required | Regional provenance confirmed for both P0-122f gap species; do not download/register until permission is documented. |
| **eElurikkus / PlutoF / "Minu loodusheli"** | Growing Estonian sound-observation corpus (Legulus, PlutoF GO, citizen science) | Occurrence metadata is open; **audio file copyright stays with each recordist**. The GBIF "My naturesounds" export is CC0, but that covers the dataset metadata - not a blanket license on every attached sound file | **Per file only** | Search <https://elurikkus.ee/app/occurrences/search?class=Aves&file_types=Audio> and ask recordists (or `kessy.abarenkov@ut.ee` / `info@elurikkus.ut.ee`) about commercial terms. |
| **Veljo Runnel** (naturesoundscapes.eu, Bandcamp) | **Best Estonian songbird coverage** - most breeding songbirds, Matsalu wetlands, Padakõrve, etc. | Bandcamp albums are **all rights reserved**; not CC | **No, not as-is** | High-priority **paid or permission** contact: `veljo.runnel@ut.ee`. Could replace most `*.song` species and several calls in one negotiation. |
| **iNaturalist** | Sparse but Estonia-tagged sound observations exist | Default upload license is CC BY-NC; some users choose CC0 or CC BY per observation | **Only CC0 / BY rows** | Manual gap filler. Filter by country, taxon, and license on each observation page. |
| **Wikimedia Commons** (`Category:Audio files of Aves`, country subcategories) | Thin per-species catalog; some Swedish/Finnish/European clips | Per file: usually CC BY or CC BY-SA | **Yes** (BY/BY-SA) | Already used for `great_cormorant` (P0-122 gap fill). Worth spot-checking before widening use - catalog is incomplete and not region-tagged reliably. |
| **Tierstimmenarchiv** (Museum für Naturkunde Berlin) | Good European birds incl. Baltic-relevant species | Majority all-rights-reserved; a **CC BY-SA subset** is published (see Coding da Vinci export) | **Only the CC BY-SA subset** | Secondary scrape target. Commercial bulk use: `e-medien@zlb.de`. |
| Tierstimmenarchiv peers (Naturalis, most museum archives) | Good | Mostly CC BY-NC | **No** | Reject for shipping unless permission granted. |
| **freesound.org (Estonia-tagged)** | A few Estonian dawn-chorus / ambience recordings (e.g. jgrzinich Varessaare 2021) | Often **CC BY-NC** for the recordings that are actually from Estonia | **No** for NC rows | Confirms the regional pattern: Estonian material on freesound tends to be NC, not CC0/BY. |
| Paid royalty-free libs (BOOM Seasons of Earth Europe, A Sound Effect "European Birds", etc.) | European ambience and some isolated species; **not a 30-species Baltic catalog** | Royalty-free commercial | Yes | Paid fallback. BOOM "Seasons of Earth" bundles are dawn-chorus ambience, not per-species isolated calls. Useful for background beds, not for the species-ID catalog in P0-105. |

### License rule for this project

Ship only recordings whose license is one of:

- **CC0** (public domain dedication) - no attribution required, ideal.
- **CC BY 4.0/3.0** - attribution required in credits.
- **CC BY-SA 4.0/3.0** - attribution + share-alike. Usable but the share-alike
  obligation only touches the audio asset itself, not game code; still prefer CC0/BY.

Reject anything containing `-NC` (non-commercial) or `-ND` (no-derivatives, blocks
trimming/looping). The download script enforces this automatically and records the
license of every downloaded file in a manifest for the credits/license report
(needed for P6-008 release license report).

### xeno-canto gaps (closed under P0-122b with maintainer-recorded interim calls)

A full-catalog scan of xeno-canto (300+ takes per species) found **zero** recordings
under CC0 / CC BY / CC BY-SA for:

- `bird.great_cormorant` (*Phalacrocorax carbo*)
- `bird.white_tailed_eagle` (*Haliaeetus albicilla*)

**P0-122c** (freesound.org, 2026-07-24) also found no commercial Baltic clip for either
species. **P0-122b** shipped deterministic maintainer-recorded procedural calls from
`tools/audio/generate_gap_bird_clips.py` until **P0-122e** (2026-07-24) replaced both with
north-European iNaturalist field takes.

| Runtime ID | Interim source | License | Follow-up |
|---|---|---|---|
| `great_cormorant` | `tools/audio/generate_gap_bird_clips.py` (`MR122b01`) | CC0 1.0 | **Replaced in P0-122e** (iNaturalist `367008`, Germany) |
| `white_tailed_eagle` | `tools/audio/generate_gap_bird_clips.py` (`MR122b02`) | CC0 1.0 | **Replaced in P0-122e** (iNaturalist `803125`, Germany) |

### iNaturalist scan (P0-122e, 2026-07-24)

After **P0-122c** found no freesound.org Baltic clip, **P0-122e** searched the public
iNaturalist API for `has[]=sounds` observations on both gap species with CC0 / CC BY /
CC BY-SA sound licenses and a 15-90 s duration window. Lithuania held short eagle takes
(4-6 s) only; no Estonia-tagged commercial clip met the length bar for either species.
The selected replacements are species-specific north-European field recordings:

| Runtime ID | Source | License | Region | Length | Observation |
|---|---|---|---|---|---|
| `great_cormorant` | iNaturalist sound `367008` (jeremybarker) | CC0 1.0 | Friedrichshafen, Germany | 21 s | [108097119](https://www.inaturalist.org/observations/108097119) |
| `white_tailed_eagle` | iNaturalist sound `803125` (emilvus) | CC BY 4.0 | Brandenburg, Germany | 26 s | [180952096](https://www.inaturalist.org/observations/180952096) |

**P0-122e outcome:** procedural maintainer gap calls removed; `fetch_bird_songs.py` now
downloads `source: inaturalist` rows and `verify_curated_bird_recordings.py` rejects
`generate_gap_bird_clips.py` maintainer placeholders. Follow-up: negotiate Estonian or
Baltic-state replacements when loodusheli.ee / PlutoF permission lands (**P0-122f**).

Legacy gap fills (removed in P0-122b):

| Runtime ID | Former fill | Why removed |
|---|---|---|
| `great_cormorant` | Wikimedia Commons India call | Non-Baltic region; replaced by maintainer interim |
| `white_tailed_eagle` | xeno-canto `H. leucogaster` stand-in | Wrong species; replaced by maintainer interim |

### freesound.org scan (P0-122c, 2026-07-24)

After the 2026-07-24 xeno-canto commercial re-scan returned zero CC0 / CC BY /
CC BY-SA takes for either gap species, **P0-122c** searched freesound.org with the
same 15-90 s window and commercial-friendly license filters (CC0 / CC BY only;
NC rows are noted but rejected).

| Query | CC0 / CC BY hits (15-90 s) | Result |
|---|---|---|
| `Phalacrocorax carbo` | 0 | No species-tagged commercial clip |
| `great cormorant` | 0 | No species-tagged commercial clip |
| `cormorant call` | 2 (Soundholder FS425374, FS425375) | Colony ambient (nest / wing rustle); species and region not documented as *P. carbo* or Baltic; does not meet the P0-122b bar for a species-specific north-Baltic field call |
| `Haliaeetus albicilla` | 0 | No commercial clip |
| `white tailed eagle` | 1 (newlocknew FS713743) | Listed under the CC BY filter but the sound page carries **CC BY-NC 4.0**; 16.5 s zoo take (Ekaterinburg, Russia), not a Baltic field recording |

**P0-122c outcome:** no freesound.org clip satisfies a Baltic field-take bar. **P0-122b**
closed with maintainer-recorded interim procedural calls; **P0-122e** replaced both with
north-European iNaturalist field takes (Germany) when no 15-90 s Baltic clip was available.
**P0-122f** remains open for Estonian or Baltic-state permission-based replacements.

## The core finding: no free source of genuinely Estonian recordings exists

Every route was checked and the result is consistent, so this is a real constraint
rather than an incomplete search:

| Route | Estonian material? | Commercially licensed? |
|---|---|---|
| xeno-canto | Yes, thousands | **No** - xeno-canto's *default upload license is CC BY-NC-SA*, so the commercial subset is near-empty for Estonia |
| loodusheli.ee | Yes, the best regional material | **No** - the species pages publish **CC BY-NC 3.0 EE**, which excludes commercial use unless the rightsholder grants separate permission |
| freesound.org | Barely | Some CC0/BY, but Estonian rows tend to be NC |
| Macaulay Library | Yes | **Paid license only** (commercial ticketing, not free) |
| eElurikkus / PlutoF | Yes, growing | **Per-recordist** - metadata open, audio rights vary |
| Veljo Runnel | Yes, best songbirds | **All rights reserved** - negotiate |

Evidence from our own run: `sounds/birds/manifest.csv` holds 30/30 species but
**zero recordings from Estonia**. `--widen-baltic` drifted far past the Baltic
(Sweden 12, France 6, Netherlands 3, Finland 3, India 2, USA/Mongolia/Kazakhstan/
Germany 1 each), and licenses are 28x CC BY-SA, 1x CC BY, 1x CC BY-SA 3.0 - no CC0.

Consequence: **genuinely Estonian audio requires either written permission or our own
recordings.** Only these three paths are real:

1. **Request permission** (unlocks the large Estonian NC/reserved pools). NC licensing
   does not stop the rightsholder from granting us separate commercial terms.
   Named contacts found on loodusheli.ee and related Estonian biodiversity infra:
   - Tartu University Natural History Museum - `loodusmuuseum@ut.ee`
   - PlutoF / eElurikkus data team - `kessy.abarenkov@ut.ee`, `info@elurikkus.ut.ee`
   - Veljo Runnel (Estonian songbird specialist) - `veljo.runnel@ut.ee`
   - Estonian Fund for Nature (Eestimaa Looduse Fond) - `elf@elfond.ee`
   - Estonian Ornithological Society (EOÜ) - `eva-liisa.orula@eoy.ee` (coordinates sound-observation projects)
   - individual xeno-canto recordists, who are named on every recording page;
     Estonian contributors are the priority.
   Underlying loodusheli.ee data sits in **PlutoF** (University of Tartu biodiversity
   platform), which supports per-record licensing, so some records may already carry
   usable terms - worth asking about explicitly.
2. **Record ourselves in Estonia.** A spring dawn chorus session covers most of the
   nine `*.song` species with perfect regional fit and unencumbered rights.
3. **Fennoscandian fallback.** Sweden/Finland xeno-canto takes under CC0/BY/BY-SA are
   ecologically defensible (shared avifauna and song dialects across the Gulf of
   Finland) and need no permission. Far-flung takes (India, Mongolia, Kazakhstan, USA)
   are **not** defensible and should be replaced.
4. **Paid commercial license.** Macaulay Library accepts commercial game requests via
   Cornell's ticketing system (filter "Commercially requestable media"). Useful for
   P0-122b gap species when free Baltic takes do not exist.

## AI-generated bird sounds (research, 2026-07-24)

**Short answer:** AI can help **clean, validate, or augment** field recordings for ML
pipelines, but it is **not yet a reliable substitute** for shipping species-specific,
regionally authentic ambient cues in a commercial game. Stick to licensed field
recordings (or negotiated Estonian permissions) for P0-105.

### What exists today

| Approach | Species control | Production ready? | Fit for Rebel-reval |
|---|---|---|---|
| **BirdDiff** (diffusion, arXiv:2509.00318, 2025) | 12 training species; ~70% top-1 on a classifier trained on the same 12 species | Research only - no maintained open-source release | **No.** Wrong scale (12 vs 30), no Baltic dialect data, no license story. |
| **AudioLDM / AudioLDM2** (general text-to-audio) | Prompt-based ("European robin song"); weak fine-grained control | Usable as a tool, not as a catalog | **No for shipping.** Sounds plausible at a glance but species accuracy is unreliable; BirdCLEF 2026 experiments show synthetic enrichment can **hurt** from-scratch classifiers once real data is available. |
| **BirdGen** (GitHub hobby project) | Procedural synthetic training set, not real species | Demo / research | **No.** |
| **Perch 2.0 / BirdNET / NatureLM-audio** | Classify ~10k-15k species | Mature for **identification** and QA | **Yes, as QA only** - verify a sourced clip is the right species before processing; not a generator. |
| **BioSEN / Earth Species biodenoising** (2025-2026) | Denoise existing vocalizations | Research / tooling | **Maybe, downstream** - could clean noisy NC recordings **after** permission, or our own Estonian field takes; not a generation shortcut. |
| **DeepFilterNet** | Speech denoiser adapted to wildlife | Open-source CLI | **Caution** - tuned for human speech; can smear weak bird harmonics. Prefer bioacoustic-specific denoisers for field material. |
| **General SFX AI** (ElevenLabs SFX, Stable Audio, etc.) | "Bird chirping" generic prompts | Consumer tools | **No** - generic ambience only; fails the species catalog contract in `map_view_bird_species.gd`. |

### Why not ship AI-generated calls as primary assets

1. **Species fidelity** - Even BirdDiff, the strongest 2025 bioacoustic generator, misclassifies ~30% of its own outputs on in-distribution species. Our catalog needs 30 distinct, player-audible profiles (9 songs + 21 calls/drums).
2. **Regional dialect** - Estonian thrush nightingale (*L. luscinia*) and Gulf-of-Finland song dialects are not represented in general models trained on global xeno-canto / iNaturalist pools.
3. **Licensing** - Model weights may be open, but **training data** (xeno-canto NC majority) does not grant commercial redistribution rights on synthetic outputs. Treat AI-generated bird audio as legally ambiguous until counsel reviews the specific model license and training corpus.
4. **Player trust** - P0-105 is an ambience system tied to `bird.*` IDs and district spawn weights. Wrong-species or "plastic" timbre breaks the fauna contract documented in `docs/FLORA_FAUNA.md`.

### Practical AI uses that *do* help this pipeline

| Use | When | Tooling |
|---|---|---|
| **Species QA** on downloaded takes | Before `process_bird_clips.py` | Perch 2.0 or BirdNET on the trimmed window - flag mismatches for manual swap |
| **Denoising** | After permission or own field session | BioSEN / Earth Species biodenoising on noisy but otherwise correct Estonian NC takes |
| **Gap-fill research** | P0-122b only | Macaulay Library commercial license search + Perch QA, **not** raw AudioLDM output |
| **Future watch** | Post-vertical-slice | Species-conditioned diffusion (BirdDiff-class) if a maintainer fine-tunes on **licensed** Baltic recordings |

### Recommendation

| Priority | Action |
|---|---|
| 1 | Keep xeno-canto CC0/BY/BY-SA + Fennoscandian widen as the free baseline (current P0-122 manifest). |
| 2 | Open a **single permission bundle** to loodusheli.ee / Veljo Runnel / PlutoF for Estonian replacements. |
| 3 | Quote Macaulay Library commercial clips for the two P0-122b gap species if permission is slow. |
| 4 | Use Perch/BirdNET as automated QA, not generation. |
| 5 | Defer AI synthesis to a future task only if a model is fine-tuned on **our own** or **explicitly licensed** Baltic corpus. |

## "Song" vs "call"

Only part of the catalog actually *sings*. The catalog cue names already encode this
(`*.song` vs `*.call`). For the melodic dawn-chorus ambience prioritise the songbirds;
the rest contribute characteristic calls (gull laughs, corvid caws, woodpecker drum,
owl hoot at night). Both are wanted, but if sourcing time is limited, get the `*.song`
species first.

Genuine song (9): barn swallow, skylark, yellowhammer, common chaffinch, great tit,
European robin, common blackbird, song thrush, common nightingale.

## Species -> scientific name map (for queries)

The game ships the **thrush nightingale** (*Luscinia luscinia*), which is the species
actually present in Estonia, not the western nightingale *L. megarhynchos*.

| Runtime ID | Scientific name | Cue type |
|---|---|---|
| bird.herring_gull | Larus argentatus | call |
| bird.common_gull | Larus canus | call |
| bird.common_tern | Sterna hirundo | call |
| bird.mute_swan | Cygnus olor | call |
| bird.mallard | Anas platyrhynchos | call |
| bird.greylag_goose | Anser anser | call |
| bird.great_cormorant | Phalacrocorax carbo | call |
| bird.grey_heron | Ardea cinerea | call |
| bird.northern_lapwing | Vanellus vanellus | call |
| bird.common_snipe | Gallinago gallinago | call (drumming) |
| bird.white_tailed_eagle | Haliaeetus albicilla | call |
| bird.osprey | Pandion haliaetus | call |
| bird.common_buzzard | Buteo buteo | call |
| bird.common_kestrel | Falco tinnunculus | call |
| bird.tawny_owl | Strix aluco | call (night) |
| bird.house_sparrow | Passer domesticus | call/chatter |
| bird.hooded_crow | Corvus cornix | call |
| bird.rook | Corvus frugilegus | call |
| bird.western_jackdaw | Coloeus monedula | call |
| bird.eurasian_magpie | Pica pica | call |
| bird.barn_swallow | Hirundo rustica | **song** |
| bird.skylark | Alauda arvensis | **song** |
| bird.yellowhammer | Emberiza citrinella | **song** |
| bird.common_chaffinch | Fringilla coelebs | **song** |
| bird.great_tit | Parus major | **song** |
| bird.european_robin | Erithacus rubecula | **song** |
| bird.common_blackbird | Turdus merula | **song** |
| bird.song_thrush | Turdus philomelos | **song** |
| bird.common_nightingale | Luscinia luscinia | **song** |
| bird.great_spotted_woodpecker | Dendrocopos major | call/drumming |

## How to download

xeno-canto retired its open API v2; **API v3 requires a free API key**. Steps:

1. Register a free account at <https://xeno-canto.org/> and copy the API key from your
   account page (<https://xeno-canto.org/explore/api>).
2. Export it: `export XC_API_KEY=...`
3. Run the helper:

   ```sh
   python3 tools/audio/build_curated_bird_manifest.py --widen-baltic
   python3 tools/audio/fetch_bird_songs.py --curated tools/audio/curated_bird_recordings.json
   python3 tools/verify_bird_audio_manifest.py
   ```

   The committed `tools/audio/curated_bird_recordings.json` is the reproducible source map.
   Rebuild it when better Baltic takes appear; gap species use the documented fills in
   **xeno-canto gaps** above until **P0-122b** lands.

   Useful flags: `--songbirds-only` (only the 9 `*.song` species first),
   `--widen-baltic` (also accept Latvia/Lithuania/Finland/Sweden if Estonia is thin
   for a species), `--min-quality B`, `--len 10-120`, `--dry-run` (list without
   downloading), `--scrape` (no API key; uses explore search with `lic:by` /
   `lic:by-sa` / `lic:zero` tags before falling back to species-page walks).

   Without an API key:

   ```sh
   python3 tools/audio/fetch_bird_songs.py --scrape --widen-baltic --per-species 1
   python3 tools/verify_bird_audio_manifest.py
   ```

Human-browsable equivalent for spot checks, e.g. nightingale:
<https://xeno-canto.org/explore?query=Luscinia%20luscinia%20cnt:estonia%20q:A%20len:15-90>

## Post-download processing (P0-123)

Raw xeno-canto takes are mono field recordings of varying gain and may carry faint wind
or distant traffic even at grade A. Before shipping they are trimmed to the 15-90 s
window when needed, high-pass filtered to cut rumble, loudness-normalised, and exported
to ``call.mp3`` / ``song.mp3`` beside each raw source with Godot ``.import`` sidecars.

```sh
python3 tools/audio/process_bird_clips.py
python3 tools/audio/sync_bird_sources.py
/Applications/Godot.app/Contents/MacOS/Godot --headless --editor --quit
python3 tools/verify_bird_audio_clips.py
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_bird_audio_clips
```

Provenance for every processed cue is recorded in ``sounds/birds/processed_manifest.csv``,
linking each catalog cue back to the P0-122 source clip and license row.

### P0-122f research attempt (2026-08-01 follow-up)

Loodusheli pages confirm Estonian field recordings for both gap species:

- `great_cormorant` / *Phalacrocorax carbo*: [Kormoran](http://loodusheli.ee/ET/loomaliigid/linnud/taxonid=448&speciesid=482), credited to Veljo Runnel, Rõngu vald, Valguta polder, 2012-10-28.
- `white_tailed_eagle` / *Haliaeetus albicilla*: [Merikotkas](http://loodusheli.ee/ET/loomaliigid/linnud/taxonid=302&speciesid=576).

The pages expose Estonian provenance and an explicit **CC BY-NC 3.0 EE** link, but no CC0, CC BY, CC BY-SA, or commercial permission. The HTTPS endpoint also currently fails certificate validation (`www.loodusheli.ee` certificate expired), so no audio was downloaded. The existing Germany iNaturalist clips remain the only verified commercial fallback. P0-122f is blocked until the University of Tartu Natural History Museum / recordist grants written permission, a record-level commercial license is published, or maintainers supply new Estonian/Baltic field takes with provenance. Do not replace the curated rows based on metadata presence alone.

A Baltic-state Commons spot check on 2026-08-01 did not clear that blocker. Lithuania search results for [Great Cormorant](https://commons.wikimedia.org/wiki/File:Great_Cormorant-Mindaugas_Urbonas-1.jpg) and Latvia search results for [white-tailed eagle](https://commons.wikimedia.org/wiki/File:Kurzemes_Zoo_Park_-_panoramio_-_---%3DXEON%3D---_(1).jpg) were photographs, not field audio. The searchable eagle audio result, [De-Seeadler.ogg](https://commons.wikimedia.org/wiki/File:De-Seeadler.ogg), is a German pronunciation recording rather than a species call. This is an evidence boundary, not proof that no Baltic recording exists: no candidate was registered because neither a qualifying field take nor its commercial permission was verified.

### P0-122f evidence boundary (2026-08-02)

A second focused check did not produce a shippable Baltic replacement:

- The existing [Kormoran](http://loodusheli.ee/ET/loomaliigid/linnud/taxonid=448&speciesid=482) and [Merikotkas](http://loodusheli.ee/ET/loomaliigid/linnud/taxonid=302&speciesid=576) pages still expose CC BY-NC 3.0 EE, not a commercial-compatible grant. The expired HTTPS certificate also prevents unattended source retrieval.
- The public xeno-canto Estonia queries for [great cormorant](https://xeno-canto.org/explore?query=species%3APhalacrocorax+carbo+cnt%3AEstonia) and [white-tailed eagle](https://xeno-canto.org/explore?query=species%3AHaliaeetus+albicilla+cnt%3AEstonia) are currently protected by an Anubis challenge, so they cannot supply independently verifiable record-level license evidence in this run.
- Wikimedia Commons API category requests returned HTTP 403. The browsable [Phalacrocorax audio category](https://commons.wikimedia.org/wiki/Category:Audio_files_of_Phalacrocoracidae) exposes only one family-level file entry and no verified Estonian/Baltic field take; the earlier [De-Seeadler.ogg](https://commons.wikimedia.org/wiki/File:De-Seeadler.ogg) result remains a German pronunciation recording, not a species call.
- The Tavily search returned ecological/species pages but no candidate audio record with a CC0, CC BY, CC BY-SA, or written commercial grant. No candidate was downloaded, registered, or substituted.

The reproducible checks remain green against the existing fallback:
`python3 tools/audio/verify_curated_bird_recordings.py`, `python3 tools/verify_bird_audio_manifest.py`, and `python3 tools/verify_bird_audio_clips.py`; the curated dry-run still resolves 30 records without downloading. This is an evidence boundary, not proof that no qualifying Baltic recording exists. The next unblock is a human permission request to the University of Tartu Natural History Museum / Veljo Runnel or a recordist with the exact commercial grant and attribution terms recorded in the curated manifest.

### P0-122f human outreach packet (ready to send)

The following request is intentionally prepared as a human action rather than an
automatic download. Send it to `loodusmuuseum@ut.ee`, with `veljo.runnel@ut.ee` copied
when the Kormoran record is the target. For PlutoF/eElurikkus records, also copy
`kessy.abarenkov@ut.ee` or `info@elurikkus.ut.ee` and address the named recordist.
Do not attach or register an audio file until the rightsholder replies with the
permission fields below.

**Subject:** Commercial permission request for two Estonian bird recordings in a game

> Dear University of Tartu Natural History Museum / recordist,
>
> We are preparing *Rebel-reval*, a commercial historical game set in Reval in 1343.
> We would like to use one or both of the following Estonian field recordings as
> species-specific ambient audio:
>
> - Great cormorant (*Phalacrocorax carbo*):
>   <http://loodusheli.ee/ET/loomaliigid/linnud/taxonid=448&speciesid=482>
> - White-tailed eagle (*Haliaeetus albicilla*):
>   <http://loodusheli.ee/ET/loomaliigid/linnud/taxonid=302&speciesid=576>
>
> Could the copyright holder grant us a written, non-exclusive commercial license for
> the exact record(s), including permission to reproduce, store, trim, loudness-normalise,
> loop or otherwise technically edit the recording for the game's ambient cues, and to
> distribute the resulting game on digital and physical platforms worldwide, including
> updates, trailers, and promotional materials? The license should be perpetual for
> copies already released, or state its exact term if it is time-limited. A paid license
> is acceptable; please state the fee and any reporting or renewal requirements.
>
> Please confirm the following for each approved record:
>
> 1. exact record URL or stable record ID;
> 2. species, recordist, recording date, location, and duration;
> 3. name and authority of the copyright holder or licensor;
> 4. the applicable license text or a direct link to the commercial grant;
> 5. whether the grant covers the edits and distribution described above;
> 6. required attribution wording and where it must appear; and
> 7. whether any separate consent is needed from the recordist, institution, or other
>    rights holder.
>
> Please reply in writing with the permission attached to the exact record(s). We will
> preserve the reply and the original record URL in our asset provenance log. We will
> not use the recording if the only applicable term is CC BY-NC 3.0 EE or another
> non-commercial/no-derivatives license.
>
> Kind regards,
> [maintainer name and contact]

#### Outreach response log

Record a reply here before touching `tools/audio/curated_bird_recordings.json`:

| Record | Contacted | Reply date | Rightsholder | Commercial grant / license URL | Edits and distribution approved | Attribution | Evidence path | Decision |
|---|---|---|---|---|---|---|---|---|
| `great_cormorant` | not contacted; published source reviewed 2026-08-02 | - | TÜ loodusmuuseum; recording credited to Veljo Runnel | [CC BY-NC 3.0 EE](http://creativecommons.org/licenses/by-nc/3.0/ee/); no commercial grant | **No** - NC term does not permit commercial game distribution or the requested edit scope | BY attribution is required, but approved wording is not published | [`docs/reports/evidence/p0_122f/great_cormorant_permission.md`](evidence/p0_122f/great_cormorant_permission.md) | **blocked** - written commercial permission and duration are missing |
| `white_tailed_eagle` | pending | - | - | - | - | - | - | blocked |

A positive reply must be retained as an exportable message or signed document and
linked from `Evidence path`. Only then may the relevant curated row be replaced and
the three bird-audio verifiers be run. If a reply grants permission for only one
record, keep the other German iNaturalist fallback unchanged and log the partial result.
