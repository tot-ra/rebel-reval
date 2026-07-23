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
| **Macaulay Library (eBird / Cornell)** | Very good regional coverage | Research/personal use; no commercial redistribution license | **No** | Reference only, do not ship. |
| Tierstimmenarchiv, Naturalis, most museum archives | Good | Mostly CC BY-NC | **No** | Reject for shipping. |
| Paid royalty-free libs (BOOM, A Sound Effect, etc.) | Generic European, not species/region specific | Royalty-free commercial | Yes | Fallback if a species has no free clean Estonian take. |

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

### xeno-canto gaps (filled via Freesound CC0 in P0-122)

A full-catalog scan of xeno-canto (300+ takes per species) found **zero** recordings
under CC0 / CC BY / CC BY-SA for:

- `bird.great_cormorant` (*Phalacrocorax carbo*)
- `bird.white_tailed_eagle` (*Haliaeetus albicilla*)

For P0-122 these two species use documented Freesound CC0 gap fills listed in
`tools/audio/curated_bird_recordings.json`. Replace them with species-specific
Baltic field takes when a commercial license appears or a maintainer records one
(**P0-122b**).

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
   Rebuild it when better Baltic takes appear; gap species currently use documented
   Freesound CC0 fills (see **xeno-canto gaps** above).

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

## Post-download processing (separate task)

Raw xeno-canto takes are mono field recordings of varying gain and may carry faint wind
or distant traffic even at grade A. Before shipping: audition, trim to the cleanest
15-90 s window, high-pass to cut rumble, loudness-normalise, and export to the engine
format used elsewhere (`.mp3` with a `.import` sidecar, matching `sounds/*.mp3`). This
processing/curation is deliberately a follow-up task, not part of the raw fetch.
