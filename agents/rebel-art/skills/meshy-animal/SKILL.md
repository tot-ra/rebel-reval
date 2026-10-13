---
name: meshy-animal
description: Turn a species card into a photoreal animal or bird - Leonardo reference image, Meshy image-to-3D, then decimate and skin the scan onto the existing runtime rig (donor GLB keeps bones and clips).
---

# Meshy animal: reference image to rigged runtime model

Status: experimental pipeline (first run: mallard `assets/birds/duck/duck.glb`, 2026-10-13). Sibling of [`meshy-human`](../meshy-human/SKILL.md), simpler because animals keep their old rig. Shipping a result into `assets/` needs a board task naming the files and refreshed `assets/SOURCES.csv` rows.

## Idea

The runtime drives animals by bone names and named clips, not by the mesh. So: keep the donor GLB's armature and actions, move the joints onto the scan, replace the mesh. Birds use the 9-bone `StorybookRig` (Body, Head, Leg.L/R, Tail, Wing.L/R, WingTip.L/R) and eight clips (Idle Walk Hop Peck Fly Glide TakeOff Land).

## 1. Reference image (Leonardo, Nano Banana)

`leonardo_generate_image`, model `gemini-2.5-flash-image`, **1248x832** (square sizes are rejected, see the art playbook), 2 images. Prompt: one animal, species Latin name, standing, **limbs/wings spread in a symmetric T-pose**, seen from the front and slightly above, separated feathers/legs, flat shadowless light, pure white background, full body in frame. Spread wings and a gap between the legs matter: Meshy fuses touching parts and you cannot weight them apart afterwards. Pick the image by eye (no cropped wing tip, head toward the camera).

## 2. Meshy

`meshy_generate_3d` with `image=<jpg>`, `texture=true`, `pbr=true`, `format=glb`. Move the GLB from `generated/meshy/` to `build/<animal>_meshy/` (gitignored). The mallard scan came out true to the photo, about 520k triangles, 1.9 m span, facing -Y in Blender after glTF import.

## 3. Rig onto the donor

```bash
B=/Applications/Blender.app/Contents/MacOS/Blender
$B -b --factory-startup --python tools/assets/meshy_animal/rig_meshy_bird.py -- \
  --meshy build/<animal>_meshy/<task>.glb --donor assets/animals/<animal>/<animal>.glb \
  --landmarks tools/assets/meshy_animal/<animal>_landmarks.json --out build/<animal>_meshy/<animal>_rigged.glb
```

It puts the feet on z=0, decimates to 30k triangles (UVs survive), moves each bone head/tail to the landmark JSON (translation only, so the donor clips still read the same local axes), writes analytic smoothstep weights (wings by |x| and height, head by height, legs by low z, tail by y), caps textures at 1024 px and exports with all actions. **Tune `<animal>_landmarks.json`, not the script**: probe the scan first (z-profile of x/y extents) and set joints from that.

### Folded wings

The donor ground clips (Idle Walk Peck Hop) hold the wings in one fold made for a thin wing. A scan wing is a broad fan and sticks out in that fold. The `fold` block of the landmarks JSON (`roll`, `yaw`, `tip` in degrees for the left wing, mirrored for the right; `scale` squashes the fan in bone space) replaces only the keys that sit on the donor fold, so Fly, Glide and the transitions keep their values. Choose the numbers by posing the wing in Blender and scoring its 99th-percentile extents against the flank (x about 0.29, z up to 0.62 for the mallard), then confirm on front, side and back renders of Idle.

## 4. Verify

- `render_preview.py --glb ... --out build/<animal>_meshy/prev --clips Fly,Walk` renders front and side per clip. Check: wings flap as one piece, no skin web between wing and body, head does not drag the breast, legs lift cleanly.
- Install over the shipped GLB, run `Godot --headless --path . --import`, then `tools/godot_render.sh --script tools/capture_bird_model_review.gd -- --output=<png>` (plate), `run_godot_tests.gd -- --filter=test_medieval_animal_models`, `python3 tools/verify_asset_lint.py`.
- Keep the `.glb.import` sidecar: its import script (`tools/assets/bird_model_import.gd`) swaps in the plumage shader.

## Known limits

- Linear blend skinning with position-derived weights: stretching at the wing root in extreme Fly frames.
- Meshy bakes soft lighting into the albedo; eyes and bill are painted, no separate meshes.
- Species other than birds need their own donor and landmarks file (quadrupeds: legs by quadrant, spine chain).
