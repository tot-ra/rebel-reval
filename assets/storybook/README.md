# Storybook model inventory

The storybook catalogue holds mammals, birds and two rigid props (sword, hammer). The seven procedural storybook humans (Mart, Aita, Ellen, watchman, Henning, Jurgen, Kaja), their 21 fitted wearables, the shield and `storybook_character.gd` were deleted: nothing in the game loaded them, since every live human uses the realistic MPFB bodies (ADR 0022). Sections below that mention humans are historical. Each runtime GLB lives in its own folder (`assets/storybook/<id>/<id>.glb`) with Godot sidecars colocated beside it. Shared rig scripts, the bird plumage shader, mammal source manifest, and fitted equipment stay at the catalogue root.

The hen is derived from the licensed authored `assets/animals/hendrik_reyneke/chicken/chicken.glb`, preserving its sculpt, UVs and PBR maps while adding a 16-bone articulated rig and eight named animations. Rebuild **only the hen** with:

```sh
blender -b --python-exit-code 1 --python tools/assets/import_authored_birds.py -- --only hen --publish
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --editor --import
python3 tools/verify_storybook_models.py
```

The four other storybook birds still use the earlier procedural models (the gull's bill and wing texture read poorly in close-ups; see docs/reports/animal_placement_plan.md). They have **not** been brought to high realism; the per-person storybook wearable bundles for those seven characters have **not** been consolidated. Do not use the legacy `build_storybook_models.py --birds-only` command to rebuild the hen: that generator deliberately excludes it. Review reference captures in `docs/reports/images/authored_birds/`.

## Legacy catalogue notes

# Grounded stylized models and equipment

Twenty-one animated models in the maintainer's revised **grounded stylized realism** direction. The original soft storybook look is superseded. Human heads and eyes are smaller, sleeves and trousers deform continuously, and mammal legs now have knees/hocks and feet. The pig, dog and sheep have substantially lower body centres and shorter legs.

Magicka and Hades guide strong silhouettes, distinct material regions and adult character proportions; no game geometry, textures or character designs were copied. The legacy `storybook/` path stays stable. P0-206 integrates the set into the existing live character, fauna and bird adapters.

| Models | Motion |
| --- | --- |
| Mart, Aita, Ellen, watchman, Henning, Jurgen, Kaja | 76 shared clips each; Mart retains the shorter arm chain |
| Forge cat, sheep, dog, pig, goat, boar, fox, hare, rat | Idle, Walk, Run, LookAround, Graze, Alert |
| Robin, hooded crow, gull, hen, duck | Idle, Walk, Hop, Peck, TakeOff, Fly, Glide, Land |

The forge cat additionally carries Sleep, Groom and Stretch; its adapter maps the existing sleep/lick/stretch routine names onto these clips.

Birds have separate shoulder and wing-tip joints. Wings fold at rest and extend during flight. TakeOff/Land are transitions; Fly/Glide loop. The endpoint poses match across the full flight sequence.

## Rebuild and verify

The four procedural birds (excluding the authored hen) have a naturalistic revision under **P0-207**, following the
maintainer's Witcher 3 realism reference. Continuous bodies, species pigmentation,
keratin bills, scaled toes, curved feather vanes and overlapping upper/underwing
coverts replace the original sphere-and-tube construction. Each keeps the nine-bone
rig and eight named clips for the procedural birds. Resting wings compact and unfold into the existing
flight cycle. The mallard has a lower stance.

Rebuild just the four legacy procedural birds with `blender -b -t 6 --python-exit-code 1 --python
tools/assets/build_storybook_models.py -- --birds-only`. Their portable GLBs embed
256×512 feather maps; `tools/assets/bird_model_import.gd` installs the packaged
`bird_plumage.gdshader` to preserve linear vertex pigmentation under Compatibility
and linear renderers. Material sections share one skeleton. See the
[bird review](../../docs/reports/bird_realism_2026-09-12.md) for captures and limits.

Blender 5.2.0 LTS and Godot 4.7.1 were used locally.

```sh
blender -b -t 6 --python-exit-code 1 --python tools/assets/build_storybook_models.py -- --render
# Wait for Blender to finish before importing, testing or capturing.
godot --headless --path . --editor --import
python3 tools/verify_storybook_models.py
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_storybook_models,test_storybook_live_integration
python3 tools/validate_asset_sources.py
```

`--only mart` rebuilds one model and its fitted wearables (and refreshes the shared rigid props). `--gallery-only` renders existing exports. Editable body/prop `.blend` files, the assembled studio and movies live in ignored `build/storybook/`; the generator creates `.gdignore` there. Fitted wearable GLBs can also be imported into the corresponding body Blender file for editing.

Original project-authored geometry and fauna motion are project-authored. Human motion/skeleton derives from the retargeted KayKit CC0 rig; see the [license](../characters/shared/KAYKIT_CC0_LICENSE.txt) and [provenance manifest](../SOURCES.csv). See the [verification report](../../docs/reports/storybook_models_2026-09-10.md).

The set supports modular equipment in both live actor scenes and the review scene. Sources are split into the main assembly, `tools/assets/storybook_anatomy.py` for faces/limbs/species, and `tools/assets/storybook_equipment.py` for fitted wardrobe. Human hands retain the existing hand bone attachment contract; individual fingers are modeled but are not independently rigged. Cloth uses skinning rather than cloth simulation. Optimized LODs, close-up material polish and complete combat contact/weapon timing approval remain production work. Existing inventory item scene references changed; item IDs, combat stats, map content and save schema did not.

## Mammal realism (P0-209)

The cat, sheep, dog, pig, goat, boar, fox, hare and rat now use continuous
anatomical skin, tapered limbs, cupped ears, seated eyes, individual toes or split
hooves, and baked 1024² albedo/normal/roughness coats. Sparse guard hairs add
silhouette detail; sheep fleece is a continuous textured surface. Witcher 3
guides the requested realism; all geometry and textures are original project art.

Rebuild only these animals with:

```sh
blender -b --python tools/assets/build_storybook_models.py -- --mammals-only
python3 tools/verify_storybook_models.py --mammals-only
```

`tools/assets/import_realistic_mammals.py` replaces the rejected primitive surface builder. Nine mammals and two cattle coats now retain licensed source meshes and UVs. [mammal_sources.json](mammal_sources.json) records every author, CC BY 4.0 link, source checksum and staging path. Download the matching source GLBs before rebuilding; the importer refuses missing or mismatched sources. Original source bulk stays outside Git; the runtime GLBs are self-contained.

The dog uses 3Dima’s shaggy dog as a generic village animal, without claiming a historically attested breed. A Labrador candidate was discarded. The hare uses Dakota.Hinkle’s rabbit as a lagomorph proxy and still needs a species-exact hare sculpt. The cat source is Meshy-generated and fox source has Tripo identifiers; those origins are recorded rather than described as hand-sculpted work.

## Horse

The Hunyuan3D-derived pack horse (dog-shaped, flat legs) was deleted on 2026-10-08, along with its duplicate `assets/animals/medieval/medieval_horse.*`. The new horse is project-authored: `tools/assets/build_horse_source.py` lofts the anatomy (trunk, neck, head, limb segments, joints), welds it with a voxel remesh and writes a bay coat into `COLOR_0` (black points, a star, one white hind sock) plus separate mane, forelock, tail, ear and eye shells. `import_realistic_mammals.py --only horse --publish` then rigs it with the shared measured limb chains and the six mammal clips. The loader (`MapViewMedievalAnimalModels`) switches `vertex_color_use_as_albedo` and `vertex_color_is_srgb` on for it. Wither 1.6 units, 2.2 with ears.

```sh
blender -b --python-exit-code 1 --python tools/assets/build_horse_source.py -- [--preview DIR]
blender -b --python-exit-code 1 --python tools/assets/import_realistic_mammals.py -- --only horse --publish
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --editor --import
python3 tools/verify_storybook_models.py
```

Known limits: a rigid cannon and pastern (the shared rig bends only the shoulder, elbow and carpus, and the stifle, hock), no hoof-feather or tack, one coat.

## Cattle

The rejected procedural cow is replaced by two licensed sculpts on the shared mammal rig and six clips: iRahulRajput's *Brown Cow 3d model* (`cow/`, canonical path) and 3Dima's *Realistic Holstein Cow* (`cow_holstein/`). Both are CC BY 4.0 and credited in the in-game Credits screen (`python3 tools/generate_credits.py`). The pied coat is a generic village phenotype, not a claim that Holsteins lived in medieval Reval. Both stand 1.50 world units tall beside the 1.65-unit horse. `MedievalAnimalModels.model_path()` picks the coat from each placement's stable seed, so a pen mixes both coats and every cow keeps its coat across reloads.

```sh
blender -b --python-exit-code 1 --python tools/assets/import_realistic_mammals.py -- --only cow --publish
blender -b --python-exit-code 1 --python tools/assets/import_realistic_mammals.py -- --only cow_holstein --publish
```

Eight models use measured limb chains with forelimb elbows and hindlimb stifle/hock articulation. Source foot surfaces remain intact. The rat retains Nestaeric’s authored rig and motions, with original clip durations and measured playback speeds. Its source motion has some foot slip; it is not a perfect contact-locked gait. Cat routines retain their existing clip names.

The dog's `Run` clip (played at runtime as its trot) uses the `run_gait` settings in `tools/assets/import_realistic_mammals.py`. It is a springy diagonal trot. The hind paw lands slightly before its diagonal forepaw. The trunk sinks at mid-stance and rolls onto the loaded pair. The foreleg root glides like a scapula to lengthen reach, and swing paws fold at the carpus/hock. The head nods and the tail wags. At least two paws stay planted in every frame, and the exported `run_reference_speed` matches the new stride. Before/after frames: [dog_run_trot_before_after.png](../../docs/reports/images/dog_run_trot_before_after.png). Other species keep the previous generic trot.

The prior P0-209/209a procedural models were rejected by the maintainer. P0-209b is a replacement implementation, with actual Godot still and motion captures in [the animal report](../../docs/reports/animal_realism_2026-09-12.md). These assets do not claim finished AAA fidelity.
