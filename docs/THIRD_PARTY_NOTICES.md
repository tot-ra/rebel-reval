# Third-Party Notices (Vertical Slice)

This document lists non-original assets and embedded third-party data shipped in the
vertical-slice export. Maintainer-authored music, SFX, meshes, and procedural visuals are
covered by the project AGPLv3 license and are intentionally omitted here.

Per-recording wildlife attributions live in [`CREDITS.md`](../CREDITS.md) at the repository
root; that file is also bundled in desktop exports.

## notice.font.noto_sans

**Component:** Noto Sans Regular (`assets/fonts/NotoSans-Regular.ttf`)

**Copyright:** The Noto Fonts project (Google LLC and contributors)

**License:** SIL Open Font License 1.1. Full text: `assets/fonts/NotoSans-OFL-1.1.txt`

**Use:** UI and dialogue glyph coverage per `docs/FONTS.md`.

## notice.rig.kaykit_adventures

**Component:** KayKit Character Pack Adventures skeleton layout and animation clips
(`assets/characters/shared/kaykit_barbarian.glb` and extracted texture)

**Copyright:** Kay Lousberg

**License:** CC0 1.0. Full text: `assets/characters/shared/KAYKIT_CC0_LICENSE.txt`

**Use:** Retargeted motion data for the shared heroic rig. Visible character meshes are
generated in-repo and do not ship KayKit visual identity.

## notice.sky.nasa_lunar_albedo

**Component:** Lunar near-side albedo mosaic (`assets/sky/lunar_albedo_nearside.png`)

**Copyright:** NASA / Lunar Reconnaissance Orbiter Camera (LROC) Science Visualization Studio

**License:** Public domain (US Government work / NASA imagery)

**Source:** https://svs.gsfc.nasa.gov/5001

**Use:** Celestial moon disk albedo in `SkyWeather3D`.

## notice.code.d3_celestial_stars

**Component:** Hipparcos star positions, magnitudes, and B-V color indices compiled into
`scripts/map/view3d/estonia_star_catalog*.gd`

**Copyright:** Olaf Frohn (d3-celestial project)

**License:** BSD 3-Clause. Full text:
`scripts/map/view3d/third_party/d3_celestial_BSD_3_CLAUSE.txt`

**Source data:** https://github.com/ofrohn/d3-celestial/blob/master/data/stars.6.json

**Use:** Night-sky star field above medieval Reval with J2000 precession to 1343.

## notice.code.tidewater

**Component:** Tidewater water, ocean and atmosphere shader techniques ported in the WS task pack
(`tools/bake_ocean_fft.py`, `tools/bake_atmosphere_luts.py`,
`scripts/map/view3d/atmosphere_common.gdshaderinc` and later WS ports)

**Copyright:** Copyright (c) 2026 DRG Software Solutions LLC

**Source:** https://github.com/dgreenheck/tidewater

**License:** MIT. Full text:

```text
MIT License

Copyright (c) 2026 DRG Software Solutions LLC

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

**Use:** Ocean FFT spectrum and Hillaire atmosphere parameterisation ported into the project's
offline bakes and shaders. Ported blocks carry a `Ported from Tidewater (MIT), see
notice.code.tidewater` comment.

## notice.audio.bird_recordings

**Component:** Ambient bird song and call clips under `sounds/birds/`

**Attribution:** See the **Bird sounds** section of [`CREDITS.md`](../CREDITS.md).

**Licenses:** CC0 1.0, CC BY 4.0, and CC BY-SA 3.0/4.0 as listed per species.

**Sources:** xeno-canto.org and iNaturalist.org field recordings curated under P0-122.

## notice.audio.insect_recordings

**Component:** Ambient Orthoptera stridulation clips under `sounds/insects/`

**Attribution:** See the **Insect ambience (Orthoptera)** section of [`CREDITS.md`](../CREDITS.md).

**Licenses:** CC BY-SA 4.0 as listed per species.

**Sources:** eBiodiversity / elurikkus.ee (PlutoF), University of Tartu.
