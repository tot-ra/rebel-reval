# Storybook model inventory

The storybook catalogue now contains seven human models, nine mammals and five birds. Each runtime GLB lives in its own folder (`assets/storybook/<id>/<id>.glb`) with Godot sidecars colocated beside it. Shared rig scripts, the bird plumage shader, mammal source manifest, and fitted equipment stay at the catalogue root.

The hen is derived from the licensed authored `assets/animals/hendrik_reyneke/chicken/chicken.glb`, preserving its sculpt, UVs and PBR maps while adding a 16-bone articulated rig and eight named animations. Rebuild **only the hen** with:

```sh
blender -b --python-exit-code 1 --python tools/assets/import_authored_birds.py -- --only hen --publish
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --editor --import
python3 tools/verify_storybook_models.py
```

The four other storybook birds and seven storybook humans still use the earlier procedural models. They have **not** been brought to high realism; the per-person storybook wearable bundles for those seven characters have **not** been consolidated. Do not use the legacy `build_storybook_models.py --birds-only` command to rebuild the hen: that generator deliberately excludes it. Review reference captures in `docs/reports/images/authored_birds/`.

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

## Kalev realism revision (P0-210)

The maintainer’s 2026-09-12 direction moves Kalev toward naturalistic RPG fidelity. His live body now has a sculpted face with small inset eyes, a tapered neck, groomed scalp/stubble, separate textile/leather materials with portable albedo/normal/roughness maps, fitted collar and boots, and a tunic hem that follows the thighs. Mail, helmet and cape are rebuilt against the unchanged skeleton. The 76 clips and clothing/weapon APIs above remain compatible. This is a more detailed procedural model, still below The Witcher 3’s finished character fidelity; facial animation, independently rigged fingers and cloth simulation are not supplied by this pass.

Historical P0-210 notes and captures are retained in [the Kalev report](../../docs/reports/kalev_realism_2026-09-12.md). That generator and its storybook output were superseded by `kalev_fresh`; do not run the former `--only kalev` rebuild command.

## Live game

Run `godot --path .` and choose Start. Kalev and Mart in the forge, the forge cat, named cast scenes and Aita’s demo actor now use the new bodies. The hammer and sword inventory items mount the new grip-oriented props while retaining their stable IDs and combat profiles. Health rings, facing, interactions and routines use the existing runtime APIs.

The shared animal loader supplies pig, sheep, goat, dog, cat, rat, fox, hare, boar, hen, duck, cow and horse to existing prop and ambient placements. Bird flight uses the new skinned robin, crow, gull and mallard with Fly/Glide transitions. Mallard ground/flight size is consistent. Greylag goose and unrepresented species/cast retain their authored models. No new maps or animal spawn locations are activated.

## Try the models

```sh
godot --path . scenes/debug/storybook_showcase.tscn
```

Choose Everyone, People, Animals or Birds. Select a subject and clip; 1–4 switch group motions; Space pauses; drag rotates the camera and the wheel zooms. Focus frames the selected model. Selecting a subject hidden by the category reveals Everyone.

The **Case** menu demonstrates civilian idle, forge work, travel, sword and shield, animal grazing, and animal alert. Cases replace equipment through the existing wardrobe API and restore covered clothing when removing armour.

For people, try **Work clothes / Mail armour**, **Empty hand / Hammer / Sword**, **Helmet**, **Cape** and **Shield** while animations play. The flight button runs takeoff → flapping flight → glide → landing. Restarting or manually choosing another clip resets the birds' display positions.

## Modding a human

Every human exports separate `Clothing_Torso`, `Clothing_Sleeve`, `Clothing_Cuffs`, `Clothing_Outerwear`, `Clothing_Legs`, `Clothing_Feet`, `Hair_Scalp`, `Character_Head`, and `Anatomy_Hands` mesh sections. Bearded bodies also have `Hair_Beard`. Clothing is replaced through the project's existing `CharacterWearable` and `CharacterWardrobe`, and props use the existing `SharedCharacterRig` attachment API.

```gdscript
var person := preload("res://assets/storybook/mart/mart.tscn").instantiate() as SharedCharacterRig
add_child(person)
person.equip_wearable(preload("res://assets/storybook/equipment/mart_mail.tres"))
person.equip_wearable(preload("res://assets/storybook/equipment/mart_helmet.tres"))
person.equip_wearable(preload("res://assets/storybook/equipment/mart_cape.tres"))
person.equip(&"right_hand", preload("res://assets/storybook/equipment/sword.tscn"))
person.equip(&"left_hand", preload("res://assets/storybook/equipment/shield.tscn"))
person.play_animation(&"sword_attack")
# Restore work clothes; removal also restores covered meshes.
person.unequip_wearable(&"torso")
```

To add your own clothing or armor:

1. Rebuild, then open `build/storybook/<person>.blend`. Fit the new garment to that body's rest pose and retain its skeleton and inverse bind transforms.
2. Export a skinned GLB with the same bone names and ordering, without its own animation library. The live body drives the garment.
3. Copy that person's `equipment/<person>_mail.tres`. Give it a new stable ID, set the correct `fitted_body`, scene, slot and authored `covered_meshes` prefixes. Do not reuse Mart's fitted armor on a differently proportioned adult; mismatches are rejected without removing the current outfit.
4. Verify idle, walk, run, attack and guard on the intended body. For cloth extending past joints, author suitable skin weights and clearance; rigid binding cannot substitute for cloth deformation.

To add a weapon or shield, author its origin at the grip, then create a thin scene with its grip orientation. Copy `equipment/sword.tscn`, `hammer.tscn` or `shield.tscn` as the starting example. Mount using `right_hand` / `left_hand` (the `handslot.r` / `handslot.l` bones), or the existing `head` / `back` slots for rigid props. Model transforms are local to the grip. Check the held pose instead of guessing a universal world-axis orientation.

There are 21 fitted storybook wearables: mail, kettle helmet and cape for each of the seven remaining storybook humans; plus three rigid props. Kalev uses his separate fresh-rig wardrobe. `storybook_character.gd` disables absent replacement LODs and prevents loading older production bodies with matching names. It also hides fully covered hose under Aita/Ellen/Kaja’s long kirtles and restores it under mail, respecting the existing wardrobe coverage union for custom leg layers. Attachment and wearable binding remain inherited. Future optimized LODs must be authored for this same set. The editable women’s Blender files open with the covered hose hidden; reveal that mesh when fitting trousers or armour.

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

`tools/assets/import_realistic_mammals.py` replaces the rejected primitive surface builder. Nine mammals now retain licensed source meshes and UVs. [mammal_sources.json](mammal_sources.json) records every author, CC BY 4.0 link, source checksum and staging path. Download the matching source GLBs before rebuilding; the importer refuses missing or mismatched sources. Original source bulk stays outside Git; the runtime GLBs are self-contained.

The dog uses 3Dima’s shaggy dog as a generic village animal, without claiming a historically attested breed. A Labrador candidate was discarded. The hare uses Dakota.Hinkle’s rabbit as a lagomorph proxy and still needs a species-exact hare sculpt. The cat source is Meshy-generated and fox source has Tripo identifiers; those origins are recorded rather than described as hand-sculpted work.

Eight models use measured limb chains with forelimb elbows and hindlimb stifle/hock articulation. Source foot surfaces remain intact. The rat retains Nestaeric’s authored rig and motions, with original clip durations and measured playback speeds. Its source motion has some foot slip; it is not a perfect contact-locked gait. Cat routines retain their existing clip names.

The prior P0-209/209a procedural models were rejected by the maintainer. P0-209b is a replacement implementation, with actual Godot still and motion captures in [the animal report](../../docs/reports/animal_realism_2026-09-12.md). These assets do not claim finished AAA fidelity.
