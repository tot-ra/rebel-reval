# Baltic water realism (P0-222)

Date: 2026-09-24

Reference: [Three.js Water Pro](https://docs.threejswaterpro.com/) (FFT JONSWAP cascades, choppiness, standing waves, Jacobian foam, crest SSS, multi-point buoyancy).

## Decision

The project renderer is GL Compatibility. A WebGPU FFT and an infinite clipmap are not portable here. P0-222 ports the part that makes Water Pro stop looking like a sine sheet:

- Swell (~9 m and ~6 m) and wind waves displace the existing 1/3-cell water grid.
- Horizontal chop peaks crests. Sheltered `water` uses standing ratio 0.42 and chop 0.55. Deep water uses chop 1.05 and standing 0.08. Rivers stay at chop 0.35.
- Ripples remain in the detail normal. Capillary wavelengths alias on this grid.
- Deep-water `wave_height` is 0.12 world units (~0.10 m) before weather, so the isometric camera can read the swell. Storms still scale that height through the existing wind/rain multipliers.
- Boat heave samples the same four traveling trains. Multi-point hulls and harbor standing on the hull are P0-225.

Follow-ups: P0-223 crest foam, P0-224 subsurface glow, P0-225 multi-point buoyancy, P0-226 wind-turned swell, P0-227 fresnel/underwater without a planar reflection pass.
