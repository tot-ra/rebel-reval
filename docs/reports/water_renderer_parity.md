# Compatibility vs Metal water renderer parity (R-932)

**Date:** 2026-09-28
**Board:** R-932 (investigation only)
**Shipping renderer:** GL Compatibility
**Capture path:** Mobile / Metal (`tools/godot_render.sh --rendering-method mobile --rendering-driver metal`)
**GPU recapture:** skipped. Godot `--editor` already held the shared worktree. Causes are pinned from the existing WS-07 / WS-13e plates plus `tools/probe_water_renderer_parity.py`.

## Player-facing goal

Tuning water on a Metal plate must hold on the shipping Compatibility renderer. Today it does not: the same harbour shelf is a grey sky sheet on Metal and a transmissive teal bed on Compatibility, Compatibility sunset grows an oil-slick rainbow, and Compatibility under-water frames hide the crib.

## Evidence plates

Existing A/B packet (no new files):

| Symptom | Metal | Compatibility |
|---|---|---|
| Bed vs sky, caustics off | `docs/reports/images/ws07_metal_clear_noon_off.png` | `docs/reports/images/ws07_opengl3_clear_noon_off.png` |
| Caustic net, clear noon | `ws07_metal_clear_noon.png` | `ws07_opengl3_clear_noon.png` |
| Sunset mottle | `ws07_metal_clear_sunset.png` | `ws07_opengl3_clear_sunset.png` and `ws07_opengl3_clear_sunset_off.png` |
| Under-water crib | `ws13e_harbor_east_under_horizontal_metal.png` | `ws13e_harbor_east_under_horizontal_gl.png` |

`python3 tools/probe_water_renderer_parity.py --check` reprints the numbers below and fails if the split disappears or the shader tokens the follow-ups must change are gone.

Water-crop is the lower-middle 50 percent of each 1280x720 WS-07 plate (`y 0.42-0.92`, `x 0.08-0.92`).

| Pair | Metric | Metal | Compatibility | Ratio |
|---|---|---:|---:|---:|
| Clear noon, caustics off | water-crop chroma | 50.4 | 79.0 | 1.57 |
| Clear noon, caustics off | water-crop B-R | -28.1 | -41.7 | more sand, not more sky |
| Clear noon on vs off | mean abs RGB | 0.83 | 3.03 | 3.63 |
| Clear sunset on vs off | mean abs RGB | (no Metal off) | 0.58 | not a caustic |
| Clear sunset | water-crop chroma | 39.0 | 72.8 | 1.87 |
| Clear sunset | water-crop hf chroma | 0.59 | 1.01 | iridescent field |
| Clear night | water-crop luma | 13.6 | 4.0 | Compatibility nearly black |
| Harbor East under-horizontal | full-frame chroma / hf | crib readable | 126.6 / 0.24 | flat teal + limb |

The probe's noon on-off ratio (3.63) is the same family as the task's 2.47 / 0.84 (~2.9). Crop bounds differ; the direction does not.

## What the plates actually show

**Finding 1, noon off.** Compatibility water is a transmissive teal film. The underwater sand contour and the stones sitting on the shelf are readable. Metal water is an opaque grey-blue sheet the same hue as the sky. The land is also paler on Metal. This is not a small grade difference. Metal is sky-reflection dominated. Compatibility shows the shader's transmitted ALBEDO (layered sand/teal bed).

**Finding 1, caustics.** The 3x stronger Compatibility net is a consequence of that mix. `_bed_caustic_gain` multiplies `seabed` before the sky mix. A more visible bed makes the same tile delta read louder. The off plates already split, so the tiles themselves are not the primary cause.

**Finding 2, sunset.** Compatibility sunset (caustics on or off) is an oil-slick of green / pink / blue swirls over the whole water, including deep water. Metal sunset is a smooth grey-blue sheet. GL sunset `|on-off|` is 0.58, so the mottle is not the WS-07 net. The swirl follows the seabed-layer / refraction field, then picks up sunset chroma.

**Finding 3, under-water.** Compatibility `under_horizontal` is the water underside: a flat teal sea plus a chromatic Snell's-window limb at the top of the frame. No crib, piles, or bed. Metal at the same authored pose shows the crib on the basin sand. This matches `_uw_window()`'s RGB fringe (`uw.fringe`) and the `seen_from_below` / `hits_surface` path, not a missing mesh.

**Extra, night.** Compatibility night water-crop luma is ~4 against Metal ~14. Recorded here so the lighting follow-up does not treat it as a new surprise.

## Causes

The WS-01 raw-to-NDC helper is already shared (`_view_position` in `map_view_water.gdshader`). Compatibility maps `raw * 2 - 1`; Mobile/Metal uses `raw` as NDC Z. Reverse Z (near = 1, empty = 0) is documented in `underwater_pass.gdshader`. That split is **not** the remaining bed/sky bug. If it were, Metal would still reconstruct a teal-opaque column the way the pre-WS-01 Metal strip did. The current Metal plates are sky sheets, not teal-opaque columns.

### 1. Bed vs sky: ALBEDO vs Mobile IBL, not NDC

`fragment()` writes a fully composited ALBEDO (Beer-Lambert bed + `sky_reflection_weight` of at least 0.34). Custom `light()` then adds Lambert diffuse (`LIGHT_COLOR * n_dot_l / PI`) and GGX glints. The comment on `SPECULAR` is explicit: with a custom `light()`, `SPECULAR` only scales **ambient and reflection-probe** specular.

Compatibility IBL / reflection probes are weak or absent. The pixel the player sees is close to that ALBEDO, so the sand/teal bed wins.

Mobile/Metal runs a real environment/probe path on top of the same ALBEDO. Probe specular plus a brighter `sky_view_lut` sample (HDR ViewportTexture, no Compatibility sRGB round-trip) greys the sea toward the sky. The same 0.34 Fresnel mix then reads as an opaque sky sheet.

Secondary push on Compatibility: `hint_screen_texture` is an 8-bit sRGB color buffer with `filter_linear_mipmap`. `floor_color` is more chromatic than Metal's linear HDR copy, and `bed_detail_visibility` lets that chroma into the shelf.

Ruled out as primary:

- Caustic RG8 sRGB decode. Off plates already split. `caustics_tiles` has no `source_color`, which can still bias the *on* delta, but it is not why the off plates disagree.
- FFT foam sRGB. Already restored by `_compat_stored_alpha()` (WS-06b / R-907). These WS-07 shelf plates are not a storm foam case.
- Tonemap/AgX alone. Noon luma of the two water crops is close (174 vs 176). The split is chroma and B-R, not exposure.

### 2. Sunset rainbow: 8-bit screen mips plus sunset LUT chroma

The mottle lives in the same ALBEDO. At sunset the layered bed / refracted `floor_color` field is still there, and Compatibility then:

- mip-filters an 8-bit sRGB `hint_screen_texture` (classic chromatic sparkle when a texel mixes sand, shade, and sky)
- samples `sky_view_lut` **without** `source_color` (the sky kernel pre-encodes for Compatibility ViewportTexture reads; water is a spatial shader on the same texture, but sunset is high chroma and any leftover decode error becomes an oil slick)
- keeps `sky_reflection_weight` high because the gameplay camera is grazing

Metal's HDR screen copy and stronger probe fill hide the same field. Caustics off does not remove it (`|on-off|` 0.58).

This is the same family as the CloudShadowPass lesson (`hint_screen_texture` on Compatibility is an 8-bit / default buffer, not the Mobile HDR copy) and the WS-06b foam-alpha lesson (Compatibility sRGB-decodes 8-bit data that Metal leaves linear).

### 3. Under-water crib: empty depth or underside fill on the overlay

`UnderwaterPass` is a fullscreen spatial quad (`depth_test_disabled`) drawn after water. It classifies sky as `raw_depth <= 0.000001` and, when the eye ray meets the surface before the scene, redraws `_uw_window()` / `_uw_below_color()` (chromatic limb + teal TIR). That is exactly the Compatibility plate.

Two bindings explain a whole-frame underside with no crib:

1. `hint_depth_texture` on that overlay is empty / default on Compatibility (every pixel is sky). Looking slightly up, `hits_surface` is true and the pass replaces the crib. Looking level, sky + max medium also drops the crib.
2. If the pass fails to composite, the water mesh `seen_from_below` branch (`camera_world.y < water_world_position.y`) fills the FOV with the same window. `FRONT_FACING` is already rejected in the water shader for this reason; the camera-height test still draws the underside when the lens is under the rest plane.

The crib **does** render on Compatibility overviews (`ws13e_*_overview_gl.png`). The mesh is not missing. Do not restyle `map_view_pier_crib_builder.gd` from the under-horizontal GL frames. That decision stays with R-929 / the QA playbook.

`hint_screen_texture` on the pass is copied before the transparent pass, so it cannot see the water surface. That is intended. It should still hold the opaque crib. On Compatibility it currently does not reach the pixel.

## Proposed fix tasks

Shader edits were out of scope for R-932. Two follow-up rows own the code:

1. **R-1067 surface mix (findings 1, 2, and the night luma gap).** Make Compatibility and Metal show the same bed-vs-sky mix on the WS-07 noon and sunset shelf. Likely work: treat `hint_screen_texture` as sRGB on Compatibility (restore like `_compat_stored_alpha`, or drop mips), keep sky-view LUT sampling in one color space on both backends, and stop Mobile probe specular from greying ALBEDO that already contains the sky mix. Pick Compatibility (shipping) as the visual target unless a named review says otherwise. Recapture the WS-07 noon/sunset/night pairs after the change.
2. **R-1068 underwater overlay (finding 3).** Make `UnderwaterPass` read the same opaque depth and color the water shader sees on Compatibility, so a Harbor East / Saaremaa `under_horizontal` GL plate shows the crib. Do not change crib geometry. Recapture `ws13e_*_under_horizontal_gl.png` (and the WS-13 north-harbour set if the pose is shared).

## R-1068 implementation (2026-09-28)

Code landed; GPU recapture skipped while Godot `--editor` held the shared worktree.

- Clip-space overlay no longer uses `blend_mix` (same CloudShadowPass lesson: mix+ALPHA did not replace the water underside on Compatibility).
- Scene reconstruction uses the water shader's `_view_position` helper. Compatibility near is OpenGL NDC z = -1 (raw 0), not reverse-Z +1.
- Empty/default overlay depth on Compatibility is not treated as sky. A dummy opaque hit at `COMPAT_EMPTY_DEPTH_HIT_SCALE` (1.5) times the vertical water column keeps Snell's window when looking up and keeps `hint_screen_texture` (crib) on a level landing look.
- Screen sampler is LOD 0 only; Compatibility decodes 8-bit screen RGB with `_compat_stored_alpha`.

Old `ws13e_*_under_horizontal_gl.png` plates still show the flat teal band. Recapture is **R-1087**.

A third row is not required. Night luma is the same lighting path as R-1067.

## Verify for this investigation

```bash
python3 tools/probe_water_renderer_parity.py --check
```

Expected: exit 0, JSON dump of the table above, `CHECK OK`. New GPU plates are the follow-up rows' job.

## Out of scope

- Changing `map_view_water.gdshader`, `underwater_pass.gdshader`, or lighting in this commit
- Restyling pier cribs or the basin bed
- Declaring Metal or Compatibility "wrong" as art direction (that is the surface-mix row's first decision)
