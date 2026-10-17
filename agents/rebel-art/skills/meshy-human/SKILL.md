---
name: meshy-human
description: Turn a character card into a photoreal, rigged, animatable human - Chroma reference image, bald inpaint, Meshy image-to-3D, then rig on the shared HumanMotionRig with separate eyes and hair borrowed from the character's MPFB build.
---

# Meshy human: card to rigged 3D character

Status: experimental pipeline (first run: Aita, 2026-10-12; shipped as Aita's body in R-1868). The production human pipeline is still MPFB ([ADR 0022](../../../../docs/adr/0022-realistic-human-characters.md), `tools/assets/realistic_humans/`). Use this skill when a character needs a likeness MPFB cannot reach. Shipping a result into `assets/` needs a board task that names the files, plus `assets/SOURCES.csv` rows.

## What you get

Two routes from the same Meshy scan. Prefer **A (conform)**; B is the older fallback.

- **A. Conformed MPFB** (`conform_mpfb_to_meshy.py`, step 4): the character's MPFB body, rig, weights, 76 clips, eyes, lashes, brows, teeth and face shape keys (`blink`, `jaw_open`, `smile`, `brow_up`, `frown`, `pucker`), with its surface moved onto the Meshy shape and the Meshy albedo baked into the MPFB UVs. Armpits deform like MPFB, the face can blink and talk, and every MPFB wearable fitted to that body (headscarf, gown) still fits. Optional `--headcloth` wearable instead of hair.
- **B. Raw Meshy rig** (`rig_meshy_human.py`, step 4b): one GLB on the 75-bone `HumanMotionRig` plus `eye.l` / `eye.r`. `Body` is the Meshy surface (about 50k triangles) bound in its own pose, `Eye_l` / `Eye_r` are MPFB eyeballs on their own bones, `Hair` is an MPFB hair mesh fitted to the Meshy skull. No face shape keys, and the scan topology stretches at the armpits.

## Inputs

- Character card in `docs/CHARACTERS/<char>.md` (age, build, skin, eyes, hair).
- The character's MPFB build `assets/characters/realistic/<char>/<char>.glb`, used as the donor for rig, clips, weights and eyes. If there is none, build one first with `tools/assets/realistic_humans/rebuild.sh`, or use the closest body type.
- Optional hair donor: any MPFB GLB with the wanted hair, e.g. `kaja.glb` for `braid01`.

## Storage rule

Nude references, Meshy GLBs and rigged nude bodies stay in `build/<char>_meshy/` (gitignored). Never put them in `docs/`, `assets/`, or `generated/`, which is not ignored. Commit only scripts, workflows and docs.

## 1. Reference image (ComfyUI, Chroma1-HD)

Template: `tools/assets/meshy_human/comfy/chroma_base_body.json`. Fill in `{AGE_SEX_ORIGIN}`, `{BUILD_AND_SKIN}`, `{FACE_AND_HAIR}` and `{CHAR}` from the card. One image at 1216x1216 takes about 7-8 minutes on this Mac. `comfyui_run_workflow` times out, so queue it directly:

```bash
curl -s -X POST localhost:8188/prompt -H 'Content-Type: application/json' -d "{\"prompt\": $(cat wf.json)}"
curl -s localhost:8188/history/<prompt_id>   # poll until "outputs" appears
curl -s -o out.png "localhost:8188/view?filename=<file>&type=output"
```

Rules:

- **Pose: T-pose arms, 45° legs.** Use horizontal arms at shoulder height with open armpits, palms forward and five spread fingers. Legs form an inverted V with a gap between the thighs. A narrow A-pose (Aita v1) let Meshy fuse the inner arm to the torso, and the skin stretched into triangular "wings" in every clip. The T-pose belongs in the prompt only, never in the Meshy T-pose toggle (step 3).
- **Use a square latent (1216x1216).** In a portrait frame the outstretched hands get cropped.
- **Describe the stance with concrete measures, not angles.** "Feet about one metre apart, daylight visible between the thighs, legs together / narrow stance in the negative" worked. "Each leg 22 degrees out" was ignored: 3 of 3 seeds came out with the feet together.
- **Describe the build without muscle words.** "Strong muscular arms from hard labour" turned every wide-stance seed into a gaunt bodybuilder with hollow cheeks. Write "soft, medium weight, sturdy". The negative prompt carries "muscular, bodybuilder, visible abs, low body fat" and also "obese, fat rolls". Seed variance on weight is huge.
- **Hair-free and flat light go in the prompt, not post.** Use "completely hairless, shaved bald head" plus hair words in the negative prompt. Then step 2 is often a no-op, but always check the scalp and pubic area. Use flat shadowless lighting: Meshy bakes every shadow into the albedo, and deep eye shadows read as sunken eyes on the model.
- **Arms must clear the body and the hands must not touch the thighs.** Meshy fuses touching parts, and the rig step has to cut them apart again: you get holes in the thigh and torn fingertips.
- Do not describe flushed or red hands or skin. Chroma paints them literally and Meshy bakes it into the albedo.
- **Fixing a near-miss:** img2img (`LoadImage` → `VAEEncode` → `KSampler`) at denoise 0.5-0.6 keeps the pose *and* the body, so it cannot fix a wrong build. Even 0.75 kept Aita v3 s1219's lean, ribbed build and its side light (v4), so a wrong build needs new seeds, not img2img.
- **Seed variance beats wording.** With the v4 wording ("soft, sturdy, medium-weight ... working mother") 3 new seeds gave one true 45-degree stance (s7307), two narrower ones, and builds from slim to soft. Queue 3-4 seeds in one go; each takes about 8 minutes.
- **Picking a seed.** Generate 3+ seeds and let the user pick. Build a contact sheet and a face crop for each one. Reject a seed if a hand is cropped, the thighs touch, or the face is gaunt. Check `/history` and `/view` on the server. Some installs write to a different `output/` dir than you expect.

## 2. Bald inpaint (hair becomes a separate mesh)

```bash
python3 tools/assets/meshy_human/hair_mask.py --image build/<char>_meshy/<char>_base_body.png \
  --hair x0,y0,x1,y1 --face x0,y0,x1,y1 [--braid x0,y0,x1,y1] \
  --out build/<char>_meshy/<char>_hair_mask.png --preview build/<char>_meshy/mask_preview.png
```

Look at the preview: the face ellipse must keep the eyes and brows. Upload the image and the mask (`curl -F image=@f -F overwrite=true localhost:8188/upload/image`), then run `comfy/chroma_inpaint_bald.json` (`SetLatentNoiseMask`, denoise 0.92, `ImageCompositeMasked` keeps the body pixels exact). Expect two passes: widen the mask (side strands, temples, braid remnant) and rerun on the first result.

## 3. Meshy image-to-3D

`meshy_generate_3d` with `image=<bald png>`, `texture=true`, `pbr=true`, `format=glb`. **One image, no T-pose option, no multi-image.** Those options go through a third-party step with stricter NSFW filters and usually fail. Plain image-to-3D on a paid plan accepts nude or underwear bodies. Move the output from `generated/meshy/` into `build/<char>_meshy/`. If the call times out, see the art playbook (the task keeps running, do not resubmit).

## 4. Conform the MPFB body to the scan (route A)

```bash
B=/Applications/Blender.app/Contents/MacOS/Blender
$B -b --factory-startup --python tools/assets/meshy_human/conform_mpfb_to_meshy.py -- \
  --meshy build/<char>_meshy/<task>.glb \
  --donor assets/characters/realistic/<char>/<char>.glb \
  [--headcloth assets/characters/realistic/<char>/headscarf/headscarf.glb | --keep-hair] \
  [--keep-brows] [--tex 2048] [--equalise 1.0] [--seam-radius 0.006] [--no-cleanup] \
  [--debug-blend build/<char>_meshy/conform/debug.blend] \
  --out build/<char>_meshy/conform/<char>_conformed.glb
```

What it does, and why:

1. **Scale and stance.** The scan stands wide, so it is shorter than the donor at rest. The script scales the scan to the height of the donor *posed in the same stance*, alternating fit and rescale until the height settles (2-3 passes).
2. **Limb fit by flesh axis.** For each upper/lower arm and leg it measures the limb axis as a line through cross-section centroids, on the scan and on the posed donor skin, and turns the bone by the difference until the residual is under 0.3 degrees. Aiming a bone straight at the scan axis misses by about 10 degrees on the thigh (MPFB bone axis is not the flesh axis, and hip skinning bends the thigh). Surface-point PCA on a short thick segment picks its width, not its length. Feet are reset to flat soles.
3. **Head fit.** Meshy guesses the head pose from a front image. Aita v4 came out with the head tilted back and 6 cm behind the MPFB posture while the torso matched, so every face feature sat 2-3 cm too high and the jaw opened on the chin. A rigid ICP (Kabsch) of the donor skull to the scan head sets tilt and depth: the turn goes into the `head` bone pose, the shift into the displacement (blended by `head` weight). Height comes from the **eye line painted on the scan albedo**, not the skull: a bald Meshy cranium sits about 2 cm lower than MPFB's, while eye-to-mouth matches within a few mm. If no eye line is found (an unpainted scan), the log warns and keeps the skull-fit height.
4. **Project.** Every MPFB skin vertex casts along its normal (then nearest point) onto the scan; hits farther than `--max-dist` (4.5 cm) or facing away are rejected and filled from neighbours. The log prints the hit rate and median offset per body part: expect 85-100 % hits on limbs and torso, about 75 % on the head and 50-60 % on hands and feet (smooth-only parts), with offsets of a few mm to 3 cm. A limb far below that means the limb fit failed; a head below 60 % means the head fit failed.
5. **Keep MPFB features.** The displacement is split into a smooth field and the detail. Hands, lips, nose and ears get only the smooth part. **Lids move rigidly with their eyeball** (constant offset inside 1.4 cm of the eye centre, blended out by 2.8 cm): the scan brow ridge sat up to 1 cm deeper than MPFB's and dragged the upper lid behind the eyeball, which then poked through and blink no longer closed it. Eyeballs and lashes take the mean offset of the lid margin, not the nearest skin vertex (often the socket wall behind the eye).
6. **Cavities.** Mouth bag, nostril and ear-canal vertices (a short ray along the normal hits the head itself) are not projected and not baked; they take the local offset of the skin around them. Otherwise the mouth bag pokes out through a chin that the scan sets deeper, and it gets face skin baked onto it.
7. **Bake.** Cycles bakes the scan albedo (as emission, so no lighting leaks) onto a conformed copy with MPFB UVs. Texels the bake misses are filled from the donor albedo tinted to the scan skin colour; the log reports the share (about 60 % of the whole map is normal, the rest is empty UV space). The lids get that tinted donor skin through a soft UV mask, because the scan paints its eye whites and iris there.
8. **Face clean-up (optional, R-1874).** The bake leaves scan seams and stretched texels around the nose, nostrils and mouth (dark nostril patches, pale lower lip). `blend_donor_face.py DONOR.png SCAN.png OUT.png` blends the donor MPFB face albedo, tinted to the scan skin from a ring around the mask and slightly smoothed, over that nose/mouth ellipse (1024 px MPFB UVs, constants at the top of the script) with a soft mask that skips the eyes. Brows, lids and the rest of the scan are untouched. Get the donor PNG with `git show <commit>:assets/characters/realistic/<char>/textures/<char>_skin_albedo.png`. The ellipse is tuned for Aita; check other characters on a face crop first.
7b. **Cleanup** (skip with `--no-cleanup`). A second emission bake carries a scan colour attribute: R is the distance to the nearest Meshy atlas seam (glTF import splits vertices at UV seams, so island edges are open boundaries), G is coverage. Then, in the MPFB UVs:
   - **Coverage un-mix.** Cycles averages missed samples in as black, which drew the dark outlines around donor-filled patches. Baked colour is divided by coverage.
   - **Equalise** (`--equalise`, 0..1, default 1). Low-frequency colour (sigma about 1.5 % of the map) is pulled to the tinted donor albedo. This removes Meshy's concept lighting: the pale breasts are washed out (desaturated), not only bright, so it works per channel. Scan colour variation larger than about 3 cm is lost.
   - **Seam inpaint.** Texels within `--seam-radius` (6 mm) of a scan seam, and the edge between scan colour and donor fill, are refilled from the clean texels around them (normalised blur). The edge is taken only inside skin faces, not at MPFB island borders.
   - **Stretch.** Per face, the bake ray hits are compared with the skin face; where one small scan patch is smeared over a larger area (smaller singular value under 0.55, the brows in front of a deeper scan brow ridge), texels are inpainted from the unstretched bake with the donor's fine luminance detail. Donor colour is not used: Aita's photo face brought orange blotches.
   - **Lips.** Mask = red texels of the donor albedo near the mouth, plus skin within 5-8 mm of the mouth cavity and not past its corners (the donor albedo only colours the inner lips). Lips take the colour of the reddest baked lip texels at low frequency, so the pale lower lip matches the upper. Redder-than-skin texels around the lips are recoloured to nearby skin.
   - `<out>_textures/cleanup_masks.png` holds the masks (R seam, G fill edge, B stretch, A lips), and the log prints their share (Aita v4: seam 13.5 %, fill edge 3.8 %, stretch 3.7 %, lips 0.16 %).
8. **Back to rest.** The posed offset is carried to the rest pose with each vertex's inverse skinning matrix and added to **every** shape key, so blink, smile and jaw still work. The head shift is *not* carried: the head stays over its joint in the MPFB posture and only the shape moves. Teeth and kept hair move with the nearest skin vertex. The headcloth keeps its donor fit and only the vertices the new body swallowed are pushed 4 mm out (following the skull detail would slide the brim over the eyes).
9. The MPFB brow mesh is dropped unless `--keep-brows`: the scan albedo already paints brows, about 1 cm lower, and both read as double brows.
10. Exports the GLB with all clips and writes `<out>.report.json` (meshes, shape keys, 76 actions, 75 bones) and `<out>_textures/skin_albedo.png`.

A donor GLB copied outside `assets/characters/realistic/<char>/` (for example a `build/.../mpfb_backup/` copy after step 4c replaced the shipped body) loses the shared textures it references as `../makehuman/` and `../textiles/`: the eyes render white and the lashes vanish. Symlink those two folders next to the copy's parent first.

Test the mechanics without credits: pose the donor itself into the scan stance, inflate it 6 mm and use that as `--meshy`. Every part should land at about 4-8 mm, and the lid offsets in the log near 0. This test cannot catch head-pose or feature-height errors (the donor face matches itself), so always check the face renders of a real scan.

## 4c. Dress the conformed body and install it (route A)

The conformed GLB is nude and has the headcloth baked in. The shipped body needs the same mesh set as the MPFB build (`Clothing_Braies`, `Hair_Scalp`; wearables hide regions by name and refuse to equip when a covered mesh is missing) and every wearable refitted to the new shape:

```bash
python3 -c "from PIL import Image; Image.open('build/<char>_meshy/conform/<char>_conformed_textures/skin_albedo.png').convert('RGB').resize((1024, 1024), Image.LANCZOS).save('build/<char>_meshy/conform/<char>_skin_albedo_rgb.png')"
A=assets/characters/realistic/<char>
$B -b --factory-startup --python tools/assets/meshy_human/fit_wearables_to_conform.py -- \
  --donor $A/<char>.glb --conformed build/<char>_meshy/conform/<char>_conformed.glb \
  --albedo build/<char>_meshy/conform/<char>_skin_albedo_rgb.png \
  --wearable $A/work_gown/work_gown.glb --wearable $A/waist_apron/waist_apron.glb --wearable $A/boots/boots.glb \
  --wearable-keep $A/headscarf/headscarf.glb --out-dir $A     # or a build/ dir to preview first
```

- The donor must be the MPFB build the conform step used (`git show HEAD:` or `rebuild.sh <char>` if it was already replaced). Re-running in place is safe: the offsets are then zero and the cloth is only pushed out again.
- Every body vertex has a known rest offset (conformed minus donor). Cloth takes an inverse-distance blend of the offsets of its 24 nearest body vertices, then is pushed 3 mm out of the body and of the inner layers. List inner layers first (gown before apron).
- `--wearable-keep` (headcloths) moves only by the outward part of the offset: following the lower scan cranium slides the brim over the eyes, but the larger scan ears poked through the hood until it did.
- The GLBs reference the shared texture files (`textures/`, `../makehuman/`, `../textiles/`) like the MPFB build; embedding them grew the outfit from 1.5 to 18 MB and the body over the 10 MiB LFS line. Named NPC skin maps are 1024 px (`verify_asset_lint.py` tier budget).
- `fit.report.json` lists the median offset and push-out count per layer. On Aita the boots pushed out about 2.7k vertices (the scan foot is larger); check the feet in the Walking plate.
- Preview with the outfit: `render_rigged_preview.py --glb $A/<char>.glb --wearables <glb>,<glb>`. Then the engine plates (`tools/capture_realistic_character.gd`, see `docs/CHARACTER_GENERATION.md`), a `tests/godot/test_realistic_<char>.gd` like `test_realistic_aita.gd`, and refreshed `assets/SOURCES.csv` rows (SHA-256, scan task, seed).

## 4d. Re-drape the headcloth on the conformed head (route A)

The donor headcloth from step 4 / 4c is fitted to the MPFB skull. `drape_headcloth.py` replaces it with a widow's linen headcloth built on the conformed head:

```bash
$B -b --factory-startup --python tools/assets/meshy_human/drape_headcloth.py -- \
  --body build/<char>_meshy/conform/<char>_conformed.glb \
  --out build/<char>_meshy/headcloth/<char>_draped.glb \
  [--wearable-out build/<char>_meshy/headcloth/headscarf/headscarf.glb] \
  [--ease 0.007] [--volume 0.014] [--hairline 0.05] [--jaw -0.085] [--nape -0.175] [--folds 0.009]
```

- **Shape.** Columns round the head: a shell `--ease` off the outermost skull surface down to ear level, then a straight fall from the widest point of the skull. Each column ends on the face line: the hairline over the brow (`--hairline` above the eye centres), the jaw beside the face, the nape at the back (heights relative to the eyes). `--volume` adds fullness over the back of the skull for the hair knotted underneath. Outward-only folds grow towards the hem.
- **Ears.** The radius field is dilated and blurred so the cloth bridges the ear instead of following it. Two things failed first: a nearest-point push-out (it follows the normal of the ear's back face and folds the cloth into the gap behind the ear) and a relax pass that keeps the built radius (it cannot round the convex crease over the widest point, which read as a ledge at ear level). Clearance is a ray test from the head centre (horizontal from the head axis below it).
- **No cloth sim.** Blender cloth with a pinned crown and the head and torso as colliders crumpled the free hem against the ear and the upper back. The hanging profile drapes well enough at game distance.
- **Skinning.** Only `head` and `chest` (written before the rig had a `neck` bone; the cloth still follows head and chest only), from the nearest head/torso skin vertices, smoothed, and pure `head` above the jaw. No arm bone moves the cloth, so a raised arm cannot drag a tail with it.
- **Material.** Reuses the old cloth's linen material and texel density (UV units per metre).
- `--wearable-out` writes the cloth alone on the same rig without clips, like the MPFB wearables. Installing it as `assets/characters/realistic/<char>/headscarf/headscarf.glb` needs a board task and refreshed `assets/SOURCES.csv` rows.

Check with the step 5 renders on `<char>_draped.glb`: the brim sits on the hairline in `face_rest.png`, nothing pokes through in `head_back.png`, and the hem is clear of the arm in `armpit_Cheer.png`.

## 4b. Raw Meshy rig, eyes, hair (route B)

```bash
B=/Applications/Blender.app/Contents/MacOS/Blender
$B -b --factory-startup --python tools/assets/meshy_human/rig_meshy_human.py -- \
  --meshy build/<char>_meshy/<task>.glb \
  --donor assets/characters/realistic/<char>/<char>.glb \
  [--hair-donor assets/characters/realistic/kaja/kaja.glb | --hair none] \
  [--iris-tint 0.42,0.52,0.40] [--debug-blend build/<char>_meshy/rig/seg.blend] \
  --out build/<char>_meshy/rig/<char>_meshy_rigged.glb
```

What it does, and why:

1. Scales the Meshy mesh to the donor height and puts the feet on the donor ground.
2. Finds both eyes on the texture with a front ray grid (sclera, pupil, iris colour) and cuts the eyelid openings.
3. Decimates to `--target-tris` (50k).
4. Rotates the donor upper arms onto the Meshy arms. The fit is found by slicing for the gap between arm and torso.
5. Labels arm against body vertices: closest posed donor surface with a normal check, majority smoothing on welded positions (Meshy splits vertices at UV seams), and small-island flips. Then it transfers donor weights per label and deletes the arm/body bridge faces below the armpit.
6. **Binds in the A-pose**: applies the pose as rest and rewrites only the `upperarm.*` keys of every clip (`Q^-1 @ basis`). Exported clips stay identical, and the runtime ignores rest for animated bones (`combat_roll_clip.gd` reads rest only for untracked bones). Inverse-skinning the body to the donor T-pose was tried first; it tore the arms.
7. Seats the donor eyeballs behind the lids on new `eye.l` / `eye.r` bones (children of `head`) and retints the iris.
8. Maps the donor or `--hair-donor` hair from cranium box to cranium box and shrinkwraps strands out of the scalp.
9. Gives the hands the forearm chroma while keeping their luminance.
10. Writes edited textures to `<out>_textures/`. Editing packed glTF images in place is lost on export.
11. Exports the GLB with all clips and writes `<out>.report.json`.

## 5. Verify

```bash
$B -b --factory-startup --python tools/assets/meshy_human/render_rigged_preview.py -- \
  --glb build/<char>_meshy/conform/<char>_conformed.glb --out build/<char>_meshy/conform/preview \
  --clips Idle,Walking_A --arms-up-clip Cheer --face-keys blink,smile,jaw_open
```

The script loads the exported GLB, so the export round-trip is checked as well. `--arms-up-clip` renders the frame with the highest hands plus an armpit close-up; `--face-keys` renders the face at rest and with each key at 1.0. Check:

- **Clips.** No sheets or fragments between hands and hips in any clip; no triangular "wings" in `armpit_Cheer.png`.
- **Face.** The lids close fully in `face_blink.png`, the mouth opens at the painted lips (not below them) in `face_jaw_open.png`, no red mouth bag shows on the chin, no grey eyeball shows in front of the lids, and the baked face has no seams or patches. The headcloth shadows the eyes in these renders; for a lit eye check render the head with the garments hidden.
- **Head.** Both eyeballs show through the lids. Hair or headcloth clears the scalp in `head_back.png`.
- **Report.** Route A (after step 4c, the installed body also has `Clothing_Braies` and `Hair_Scalp`): 75 bones, 76 actions, the `Anatomy_*` meshes (no `Anatomy_Head_Brows` unless `--keep-brows`) and the six face keys. Route B: 77 bones, 76 actions, `Body`, `Eye_l`, `Eye_r`, `Hair`.

## Known limits

Route A (conform), from the Aita v4 run (seed s7307, Meshy task `01a13051`):

- **Meshy albedo after cleanup (step 7b).** The dark outlines and seam margins are gone, the breasts are much less pale, and both lips share one colour. What remains: a jagged lighting edge under the breasts is painted *inside* a scan island, not at a seam, so the seam mask misses it. Equalising softens it but it still shows in `armpit_Cheer.png`. The seam band (about 13 % of texels) is slightly softer than the rest. A faint lip-paint smudge stays at one mouth corner, and the dark nostril paint is untouched.
- **Brows.** The stretch inpaint removes the parallel streaks, but the scan brow stays soft and smeared. With the MPFB brow mesh dropped, the brows are only that soft paint; use `--keep-brows` if they read too weak.
- **Synthetic test.** On the inflated-donor test the cleanup is close to identity: mean error against the donor albedo goes from 0.0091 to 0.0100 overall, 0.019 to 0.013 in the seam band, and 0.085 to 0.067 on the lips.
- **Headcloth.** Steps 4 and 4c keep the donor's MPFB-fit headscarf: a stiff hood with a visor-like brim that does not follow the new skull, a bump over the larger ears, and tails that cut into the raised arm in `armpit_Cheer.png`. Step 4d replaces it with a cloth draped on the conformed head (Aita v4: brim on the hairline, ears bridged, 0 cloth vertices inside the arms or torso in any Idle, Walking_A or Cheer frame, against up to 22 and 79 for the donor fit). Limits of 4d: a smooth procedural drape, not a simulated one (no tucks or knot at the nape), a plain cut hem with no rolled edge, the folds are a fixed pattern. Aita's shipped `headscarf/headscarf.glb` is the 4d output (installed 2026-10-12).
- **Posture.** The rest pose keeps the MPFB head posture, not the scan's; the scan's head-back stance is treated as a pose, not as shape.
- **Iris colour** is the donor's; there is no iris retint in route A yet.
- **Deformation** is MPFB linear blend skinning at hips and armpits, with no corrective shapes.

Route B (raw Meshy rig):

- **Eyelid rims.** The rims are jagged (decimation after the cut) and there are no lashes. Fit the donor lashes or cut on a cleaner retopology.
- **Baked texture faults.** Meshy bakes concept lighting and blotches into the albedo, for example the knees and upper chest on Aita. Only the hands are corrected.
- **Hair.** Donor hair is an MPFB card mesh that is only box-fitted, so check the fringe over the eyes. Hair colour comes from the donor material.
- **Deformation.** The scan topology stretches at the armpits, and there are no face blendshapes, so the face cannot talk or blink. Use route A.

## Rig changes

Rebuilding a conformed character (`rebuild.sh <char>`) replaces it with its MPFB body. When the rig changes and the scan is no longer at hand, carry the shipped shape over instead: copy the rebuilt MPFB character and the shipped one (`git archive HEAD assets/characters/realistic/<char>`) under `build/<char>_graft/{mpfb,shipped}/` with `makehuman` and `textiles` symlinks next to them and a `.gdignore` in `build/<char>_graft/` (otherwise Godot imports the shared textures through the symlinks and rewrites their `.import` files), then

```bash
$B -b --factory-startup --python tools/assets/meshy_human/graft_conformed_shape.py -- \
  --rebuilt build/<char>_graft/mpfb/<char>/<char>.glb --shipped build/<char>_graft/shipped/<char>/<char>.glb \
  --out build/<char>_graft/<char>_conformed.glb
git checkout HEAD -- assets/characters/realistic/<char>/textures/     # the scan albedo
```

and run step 4c (`--donor` the rebuilt MPFB body, `--conformed` the graft, `--albedo` the restored skin albedo) and step 4d on the graft. Vertices are matched by MPFB UV across the skin regions (a rig change can move border vertices between regions); the script stops if more than 1 % of a mesh has no exact UV match. Aita was carried to the 75-bone rig this way (ADR 0056).
