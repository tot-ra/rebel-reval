# Medieval pack horse v2

This bundle reproduces the clean replacement for the artifacted runtime horse.

## Decision

- Recreated at the user's request on 2026-07-28 because the previous image-to-3D source included a cart/background and produced visible geometry artifacts.
- The v2 source contains one isolated, fully visible horse without scenery, tack, or a second subject.
- Runtime target: `assets/animals/medieval/medieval_pack_horse.glb`.

## Generation

- Leonardo generation: `75f25481-f8bb-4444-a5e0-91fa16942436`.
- Local Hunyuan3D prompt: `1c7ce801-247e-49bd-8431-40618411eb73`.
- Cleanup seed: `208744234`.
- Reference SHA-256: `f1ecd1ed7cc4bac429b0e8faa905535d68e1738e120ab8acf32ff075db069d07`.
- Candidate SHA-256: `f5aeaee2a6f701588042138db01145546632561eaf096941d93d5ca5157fcd3d`.

The reference prompt requested a photorealistic compact northern-European dark-bay horse in a neutral square stance, with all four legs and hooves visible, isolated on a plain studio background. Negative constraints excluded carts, fences, scenery, tack, fused or missing limbs, stylization, and cropped anatomy.

## Production result

Run from the repository root:

```bash
blender -b --factory-startup --python generated/comfyui/pack_horse_v2/production/build_pack_horse_v2.py
```

The production pass removes four microscopic detached islands, creates one watertight manifold component, retains equine detail with a high-resolution voxel remesh, normalizes to 2.35 x 1.65 x 0.78 m (length x height x width), unwraps UVs, and exports a 1024 px dark-bay material with one anatomical `COLOR_0` mask.

- Runtime SHA-256: `387cf0f0175d03a332475265315f3c7854cfd364c2ba424cb8cb0973910f352c`.
- Albedo SHA-256: `68d23b92250a954c636a65a5fb6e994bb6f1897fb31593de3c5a180d18c565e7`.
- Topology: 12,000 triangles, one component, zero boundary/non-manifold edges.
- Ground contact: Y = 0 in Godot.
