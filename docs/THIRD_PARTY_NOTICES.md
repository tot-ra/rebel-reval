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

## notice.data.openstreetmap_reval

**Component:** Trimmed OpenStreetMap extract of Tallinn Old Town (`tools/city/data/osm_reval_extract.json`) and the city plan derived from it (`content/world/reval_city/plan.json`, `height.json`, `splat.png`)

**Copyright:** © OpenStreetMap contributors

**License:** Open Database License (ODbL) 1.0, https://opendatacommons.org/licenses/odbl/1-0/ . The extract and the derived plan are made available under the ODbL; see https://www.openstreetmap.org/copyright

**Use:** Street lines, plot footprints, surviving tower positions, wall fragments and cliff lines for the seamless Reval city ([ADR 0031](adr/0031-continuous-reval-city-plan.md)); 1343 corrections are layered on top.

## notice.data.openstreetmap_paide

**Component:** Trimmed OpenStreetMap extract of Paide (`tools/city/data/osm_paide_extract.json`) and the regional site plan derived from it (`content/world/paide/plan.json`, `height.json`, `splat.png`, `roads.png`, `minimap.png`)

**Copyright:** © OpenStreetMap contributors

**License:** Open Database License (ODbL) 1.0, https://opendatacommons.org/licenses/odbl/1-0/ . The extract and the derived plan are made available under the ODbL; see https://www.openstreetmap.org/copyright

**Use:** Position of the Paide castle keep for the regional site ([ADR 0042](adr/0042-regional-site-plans.md)); everything else in the plan is authored for 1343.

## notice.data.openstreetmap_padise

**Component:** Trimmed OpenStreetMap extract of Padise (`tools/city/data/osm_padise_extract.json`) and the regional site plan derived from it (`content/world/padise/plan.json`, `height.json`, `splat.png`, `roads.png`, `minimap.png`)

**Copyright:** © OpenStreetMap contributors

**License:** Open Database License (ODbL) 1.0, https://opendatacommons.org/licenses/odbl/1-0/ . The extract and the derived plan are made available under the ODbL; see https://www.openstreetmap.org/copyright

**Use:** Positions of the monastery ruin, the Kloostri river, the river crossing, the road lines and the mill site, traced into the Padise regional site ([ADR 0042](adr/0042-regional-site-plans.md)); the buildings and land use are authored for 1343.

## notice.data.openstreetmap_hinterland

**Component:** Trimmed OpenStreetMap extracts of Rebala, the Pirita valley at Vaskjala and Kostivere (`tools/city/data/osm_harju_extract.json`, `osm_rebel_kings_extract.json`, `osm_sacred_grove_extract.json`) and the regional site plans derived from them (`content/world/{harju,rebel_kings,sacred_grove}/plan.json`, `height.json`, `splat.png`, `roads.png`, `minimap.png`)

**Copyright:** © OpenStreetMap contributors

**License:** Open Database License (ODbL) 1.0, https://opendatacommons.org/licenses/odbl/1-0/ . The extracts and the derived plans are made available under the ODbL; see https://www.openstreetmap.org/copyright

**Use:** The Pirita and Jõelähtme river courses, traced into the rebel kings' camp and sacred grove sites ([ADR 0042](adr/0042-regional-site-plans.md)); everything else in the three plans is authored for 1343.

## notice.data.eudem

**Component:** EU-DEM v1.1 elevation samples (`tools/city/data/eudem25m_reval.json`, `tools/city/data/eudem25m_paide.json`, `tools/city/data/eudem25m_padise.json`, `tools/city/data/eudem25m_harju.json`, `tools/city/data/eudem25m_rebel_kings.json`, `tools/city/data/eudem25m_sacred_grove.json`), fetched through OpenTopoData

**Copyright:** Produced using Copernicus data and information funded by the European Union - EU-DEM layers

**License:** Free use with attribution (Copernicus data policy)

**Use:** Terrain trend for the city and regional site heightfields; Toompea, the hill ways, the shore, the castle mounds and the ditches are authored on top.
