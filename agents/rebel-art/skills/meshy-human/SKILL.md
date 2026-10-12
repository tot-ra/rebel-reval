---
name: meshy-human
description: Turn a character card into a photoreal, rigged, animatable human - Chroma reference image, bald inpaint, Meshy image-to-3D, then rig on the shared HumanMotionRig with separate eyes and hair borrowed from the character's MPFB build.
---

# Meshy human: card to rigged 3D character

Status: experimental pipeline (first run: Aita, 2026-10-12). The production human pipeline is still MPFB ([ADR 0022](../../../../docs/adr/0022-realistic-human-characters.md), `tools/assets/realistic_humans/`). Use this skill when a character needs a likeness MPFB cannot reach. Shipping a result into `assets/` needs a board task that names the files, plus `assets/SOURCES.csv` rows.

## What you get

One GLB on the 71-bone `HumanMotionRig` plus `eye.l` / `eye.r`, with all 76 shared clips:

- `Body` - the Meshy surface, about 50k triangles, bound in its own A-pose.
- `Eye_l`, `Eye_r` - MPFB eyeballs on their own bones, so the eyes can look around.
- `Hair` - an MPFB hair mesh fitted to the Meshy skull and weighted to `head`, so it can be swapped.

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
- **Fixing a near-miss:** img2img (`LoadImage` → `VAEEncode` → `KSampler`) at denoise 0.5-0.6 keeps the pose *and* the body, so it cannot fix a wrong build. Use about 0.75 to change the body while the pose survives, or start new seeds.
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

## 4. Rig, eyes, hair

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
  --glb build/<char>_meshy/rig/<char>_meshy_rigged.glb --out build/<char>_meshy/rig/preview \
  --clips Idle,Walking_A,Sit_Chair_Idle,1H_Melee_Attack_Chop
```

The script loads the exported GLB, so the export round-trip is checked as well. Check:

- **Clips.** No sheets or fragments between hands and hips in any clip. If there are any, run with `--debug-blend` and render the `is_arm` colour layer.
- **Head.** Both eyeballs show through the lids and turn in `head_eyes.png`.
- **Hair.** Hair clears the scalp in `head_back.png`.
- **Report.** `report.json` lists 73 bones, 76 actions, and the `Body`, `Eye_l`, `Eye_r` and `Hair` meshes.

## Known limits

- **Eyelid rims.** The rims are jagged (decimation after the cut) and there are no lashes. Fit the donor lashes or cut on a cleaner retopology.
- **Baked texture faults.** Meshy bakes concept lighting and blotches into the albedo, for example the knees and upper chest on Aita. Only the hands are corrected.
- **Hair.** Donor hair is an MPFB card mesh that is only box-fitted, so check the fringe over the eyes. Hair colour comes from the donor material.
- **Deformation.** Linear blend skinning at hips and armpits is MPFB-donor quality, with no corrective shapes. There are no face blendshapes, so the face cannot talk or blink.
