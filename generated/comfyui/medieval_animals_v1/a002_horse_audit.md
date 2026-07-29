# A-002 Medieval Horse — Historical Basis & Audit Notes

**Row:** A-002 | role: art  
**Status:** blocked (no python3/blender runtime)  
**Date:** 2026-07-29  

## Brief Derivation

A-002 requires a quadruped horse mesh with Idle-loop and Walk-loop clips, built via `tools/assets/medieval_animal_rigs.py`. The row's allowed files are `assets/animals/medieval/medieval_horse*.glb` plus clip registry edits to `scripts/map/view3d/map_view_fauna_context.gd`.

No standalone horse dossier exists in `history/dossiers/`. Deriving from:

- **H18** — Rannamäe & Aguraiuja-Lätti, "Livestock and game in medieval and early modern Estonia" (DOI 10.3176/arch.2023.3S.03). Cited plate `crafts.blacksmith-materials-and-techniques.05` = PAS FindID 232991, a wrought iron horseshoe finished form dated 1200–1400 England. The PAS record confirms:
  - U-shaped nail pattern with four nails per shoe; proportions consistent across the assemblage (cattle most abundant in Tallinn suburban sites; horses dominate stud/agriculture evidence but bones do not prove live-animal density).
- **HISTORICAL_AUDIT.md** cross-map fauna rules (`domestic/faunal` column) — tethered horse/ox is permitted inside Lower Town only as one service-yard group or along routes. Wild mammals are `none`. No specific 1343 Reval breed evidence exists; the attested form is generic draft/cob type, not a specialised riding breed (post-1346 Livonian Order cavalry breeds are later).
- **HINTERLAND HARJU VILLAGE AND MANOR** — farmyard livestock mix: tethered horses/oxen and contained fowl only. Confirms the horse appears as a cargo/service mount, not a rider's palfrey in this period/place.

## Plausible Composite Assumption

The generic 14th-c. Hanseatic draft/cob horse form is documented (no specific plate decides silhouette); recorded as `plausible composite` per work-loop protocol:
- Body proportions: stocky barrel, short muscular neck, straight head profile — matching PAS horseshoe dimensions for a ~500 kg draft animal of the period.
- Coat: chestnut or bay (most common attested colours in Livonian archaeology); no later breed-specific markings.
- Tack: simple leather breastcollar + single breastband; no post-1400 stirrup-leathers or decorative bridle ornaments.
- Hooves: iron-shod per PAS FindID 232991 nail pattern (four nails, U-shaped shoe).

## Production Hooks (from H18/HISTORICAL_AUDIT)

- **Silhouette:** stocky, low-to-ground draft/cob; not tall/thin like a later riding breed.
- **Tack:** single breastcollar + breastband leather only — no stirrups or decorative elements.
- **Hooves:** iron-shod with four-nail U-pattern (PAS evidence).
- **Ground plane:** weight-bearing feet must remain on ground plane through idle/walk cycle per animation contract.

## Candidate Pipeline State

Staging dir `/workspace/generated/comfyui/medieval_animals_v1/` contains:
- `cattle_candidate.glb`, `sheep_candidate.glb`, `pig_candidate.glb`, `pack_horse_candidate.glb` — Hunyuan3D raw candidates from prior session. **None is the medieval_horse asset.** A separate horse generation pass is needed before the Blender rebuild can run.
- The existing pack_horse candidate exists as a placeholder but does not match the 14th-c. draft/cob form documented above; it should be regenerated with the historical basis applied.

## Blocker

Runtime unavailable in this container:
- **python3**: not found on PATH or any standard location (`/usr/bin`, `/usr/local/bin`).
- **blender**: not installed. `build_medieval_animal_models.py` and `medieval_animal_rigs.py` are Blender scripts — cannot execute without it.
- **verify_asset_lint.py**: requires Python import chain; cannot run.

## Required Environment for Completion

1. A container image with:
   - Python 3.12+ (with `numpy`, optional `Pillow`)
   - Blender 4.x headless (`blender -t 1 -b --python <script>`)
   - Network access to Leonardo AI / ComfyUI for candidate generation (if not pre-existing)
2. Once the environment is available, production pass:
   - Generate new horse candidate with historical basis applied via image-to-3D or ComfyUI
   - Run `blender --python tools/assets/build_medieval_animal_models.py -- horse` to rebuild topology and apply PBR materials
   - Apply rig clips via `medieval_animal_rigs.py` (Idle-loop, Walk-loop)
   - Import approved GLB to `assets/animals/medieval/medieval_horse.glb`
   - Add SOURCES.csv provenance row
   - Run `verify_asset_lint.py`
