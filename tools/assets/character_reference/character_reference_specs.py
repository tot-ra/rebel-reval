"""Canon-derived modeling-reference specs for the slice-core cast.

Why this file exists: the P0-214 Kalev reference pack was authored ad hoc in chat,
so the prompt skeleton that actually produced usable Hunyuan3D multiview input was
not reusable. Keeping the skeleton in one template function and only varying a
per-character subject block makes every later pack reproducible and reviewable as
a diff, and keeps the "front and back must be the same person at the same camera
scale" contract from drifting per character.

Only `docs/CHARACTERS/*.md` and `docs/CANON.md` feed these specs. No existing
character mesh, sprite, portrait or screenshot is an input.
"""

from __future__ import annotations

from dataclasses import dataclass, field

# Shared framing contract. Every plate in every pack must agree on these words,
# because Hunyuan3D multiview reconstruction fails when the front and back plates
# disagree on stature, foot spacing, crown/sole position or lighting.
_CAMERA = (
    "Straight-on orthographic camera, no perspective distortion, entire figure "
    "including feet and head visible, fills 90 percent of canvas height. Clean "
    "uniform middle-gray background, broad flat diffuse studio lighting, no floor "
    "horizon, no cast shadows, no painted drama."
)
_FIDELITY = (
    "Render like an exceptionally detailed physically based digital double for a "
    "Witcher-3-class realistic game; real human anatomy and skin texture, NOT "
    "cartoon, NOT stylized, NOT illustration, NOT a toy or clay mannequin."
)
_POSE = (
    "Anatomically correct relaxed A pose with straight elbows, arms 35 degrees "
    "away from torso, palms facing forward and fingers naturally separated; feet "
    "parallel shoulder width apart; balanced symmetric stance."
)


@dataclass
class CharacterSpec:
    """One reviewable reference pack.

    `base_layer` is the modeling base, not costume. It must be the minimum
    period-correct garment that still lets a modeler read the body, because the
    wardrobe is authored as separate fitted layers over an independent body.
    """

    ident: str
    display: str
    char_id: str
    role: str
    confidence: str
    brief_doc: str
    summary: str
    anatomy: str
    face: str
    base_layer: str
    excluded_wardrobe: str
    wardrobe_plan: str
    material_file: str
    material_prompt: str
    notes: list[str] = field(default_factory=list)

    # ---- prompt assembly -------------------------------------------------

    def front_prompt(self) -> str:
        return (
            "Create a completely original photorealistic AAA historical RPG character "
            "modeling reference, full-body single FRONT view. This is a fresh design, do "
            f"not use any prior conversation images or models as visual references. Subject: {self.summary} "
            f"{self.anatomy} {self.face} Not based on any existing actor, celebrity or game "
            f"character. Modeling base body: {self.base_layer} NO {self.excluded_wardrobe}, "
            "because separate wardrobe will be modeled over the independent body. "
            f"{_POSE} {_CAMERA} {_FIDELITY} A single figure only, no insets, text, panels or "
            "watermark. Portrait aspect ratio."
        )

    def back_prompt(self) -> str:
        return (
            "Create the exact REAR orthographic view of this newly designed original "
            f"person for matching 3D reconstruction. Same person, exact anatomy, stature, "
            "pose, camera scale, foot spacing, hair and lighting, and the same "
            f"{self.base_layer.rstrip('.')} Turn the body 180 degrees so only the BACK is seen. "
            f"{self.back_focus()} Arms remain straight in the same relaxed A pose 25-35 degrees "
            "away from torso; preserve hand placement and finger spacing, show backs of hands "
            "from behind. Full body fills the exact same frame height with feet and crown at the "
            "same image positions as the reference. Neutral uniform gray backdrop with no floor "
            "line or cast shadow. AAA photoreal game character reference, not stylized. No front "
            "view, no inset, no text, no extra objects, no new clothing."
        )

    def back_focus(self) -> str:
        return (
            "Show the back, shoulders, arms and legs with the same realistic skin and "
            "the back of the hair exactly as established in the front plate, bare feet."
        )

    def face_prompt(self) -> str:
        return (
            "Create a matching photorealistic close-up FRONT orthographic head texture "
            f"reference of THIS EXACT original person, the newly designed {self.display}. "
            f"{self.face} Preserve the same hair and facial identity as the full-body plate. "
            "Frame from full crown to clavicles with ears visible, head fills most of the "
            "portrait canvas. Camera perfectly straight front, neutral expression, mouth "
            "closed, eyes straight ahead. Broad extremely flat neutral diffuse studio light, "
            "minimal shadow, no artistic color grading, uniform medium gray background. Real "
            "skin pores, subtle wrinkles, natural lips and individual hairs. This will be "
            "projected onto the matching 3D head, so preserve all face proportions and "
            "symmetry from the reference. No inset or text, no extra people, no clothing or "
            "armour. A digital double reference photograph, not illustration, no stylization."
        )

    def prompts(self) -> dict[str, str]:
        return {
            "front": self.front_prompt(),
            "back": self.back_prompt(),
            "face": self.face_prompt(),
            self.material_file.removesuffix(".png"): self.material_prompt,
        }

    def brief_markdown(self, task_id: str) -> str:
        notes = "".join(f"\n- {line}" for line in self.notes)
        return (
            f"# {self.display} design reference - {task_id}\n\n"
            f"**Stable ID:** `{self.char_id}` | **Role:** {self.role} | "
            f"**Confidence:** `{self.confidence}` | **Brief:** [{self.brief_doc}]"
            f"(../../../../docs/CHARACTERS/{self.brief_doc})\n\n"
            f"{self.summary} {self.anatomy} {self.face}\n\n"
            "The body is independent from wardrobe. The plates show only the modeling base "
            f"layer ({self.base_layer.rstrip('.')}) so a modeler can read anatomy; "
            f"{self.wardrobe_plan} Design construction must support changing individual pieces. "
            "The Witcher 3 guides material and anatomical realism, not copied identity or game "
            "assets.\n\n"
            "No existing mesh, sprite, portrait, screenshot or anatomy-generator output is an "
            "input. Only the shared animation/skeleton and runtime API contracts may be reused "
            "for compatibility. These references are authored from the canon character brief "
            "text alone. This is a reviewable reference pack, not an approved runtime asset."
            f"{notes}\n"
        )


SPECS: list[CharacterSpec] = [
    CharacterSpec(
        ident="mart",
        display="Mart",
        char_id="char.mart",
        role="Apprentice; inciting incident and emotional stake",
        confidence="invented",
        brief_doc="mart.md",
        summary=(
            "Mart, a 16-year-old Estonian blacksmith's apprentice in 1343 Reval, an "
            "adolescent boy who is strong from forge work but not yet physically finished, "
            "realistic 7.4 heads tall, 172 cm and still growing."
        ),
        anatomy=(
            "Lean adolescent build: narrow shoulders that have not filled out, flat hard "
            "torso with visible collarbones and a shallow ribcage, wiry forearms and a "
            "disproportionately developed grip from bellows and striking work, knobbly "
            "elbows and knees, hands and feet slightly too large for the frame, thin legs. "
            "Small pale old burn scars scattered on both forearms. No adult chest mass and "
            "no bodybuilder definition."
        ),
        face=(
            "Young unweathered face with sharp cheekbones and a stubborn set jaw, wide-set "
            "grey-blue eyes, straight narrow nose, thin mouth, faint acne on the forehead, "
            "only sparse patchy soft beard growth on the jaw and upper lip. Ash-blond to "
            "light brown hair, collar length, unevenly home-cut, tucked behind the ears."
        ),
        base_layer=(
            "bare torso and arms, modest opaque natural off-white linen knee-length braies "
            "secured at the waist, bare feet."
        ),
        excluded_wardrobe="tunic, apron, boots, belt accessories, armour or weapon",
        wardrobe_plan=(
            "a coarse wool apprentice tunic, soot-stained linen shirt, short leather work "
            "apron, hose and boots are separate fitted layers."
        ),
        material_file="wool_twill.png",
        material_prompt=(
            "A seamless square physically based material base-color texture of coarse "
            "undyed medieval wool twill cloth, woven from unbleached grey-brown sheep "
            "fleece, viewed exactly perpendicular to the flat cloth surface. Clear 2/1 "
            "diagonal twill weave with individual slightly irregular handspun yarns, faint "
            "natural colour variation between fleece batches, light pilling and a few tiny "
            "vegetable-matter flecks. Flat neutral diffuse light with minimal directional "
            "shading and no glare. Uniform weave scale throughout, fills the entire frame "
            "edge to edge, periodic seamless tiling edges. A texture material scan for a "
            "realistic historical RPG, NOT a garment, no person, no seams, no hems, no "
            "borders, no illustration, no text. Square aspect ratio."
        ),
        notes=[
            "Do not age him into a young adult; the 16-year-old silhouette is the point of "
            "the character next to Kalev.",
            "Do not collapse him with `char.martin_cloaks` or `char.mart_weaver`.",
        ],
    ),
    CharacterSpec(
        ident="aita",
        display="Aita",
        char_id="char.aita",
        role="Alewife and healer; community perspective and moral challenger",
        confidence="invented",
        brief_doc="aita.md",
        summary=(
            "Aita, a 48-year-old Estonian alewife and healer in 1343 Reval, Kalev's older "
            "sister, a heavy-working woman who hauls barrels and water every day, realistic "
            "7.4 heads tall, 166 cm."
        ),
        anatomy=(
            "Sturdy strong working woman's body: broad shoulders and a thick well-muscled "
            "upper back from carrying, thick capable forearms and heavy wrists, full natural "
            "bust, soft rounded belly, wide strong hips, solid heavy thighs and calves, "
            "broad flat feet. Weathered reddened forearms and hands with short nails. "
            "Genuinely strong and genuinely middle-aged, neither slim nor a caricature."
        ),
        face=(
            "Broad open bone-tired face with deep smile lines, a heavy brow, dark shadows "
            "under warm brown deep-set eyes, strong straight nose, full mouth, slight "
            "jowls. Dark brown hair heavily greyed at the temples, centre-parted and pinned "
            "back into a low coil, a few loose strands at the hairline."
        ),
        base_layer=(
            "a plain undyed coarse linen sleeveless knee-length chemise that follows the "
            "body closely enough to read its volumes, bare arms, bare feet."
        ),
        excluded_wardrobe="gown, overdress, apron, coif, headscarf, belt, shoes or jewellery",
        wardrobe_plan=(
            "the wool gown, brewer's apron, linen coif and shoes are separate fitted layers."
        ),
        material_file="linen_plainweave.png",
        material_prompt=(
            "A seamless square physically based material base-color texture of coarse "
            "undyed medieval linen plainweave cloth, unbleached warm off-white flax with a "
            "faint grey-beige cast, viewed exactly perpendicular to the flat cloth surface. "
            "Clear simple over-under plain weave with visibly irregular handspun flax "
            "threads, occasional thicker slub yarns, subtle wear softening and a few faint "
            "pale water stains. Flat neutral diffuse light with minimal directional shading "
            "and no glare. Uniform weave scale throughout, fills the entire frame edge to "
            "edge, periodic seamless tiling edges. A texture material scan for a realistic "
            "historical RPG, NOT a garment, no person, no seams, no hems, no borders, no "
            "illustration, no text. Square aspect ratio."
        ),
        notes=[
            "She is Kalev's older sister; keep a plausible family resemblance in the brow, "
            "nose and jaw without copying his face.",
            "Strength and fatigue must both read. Do not slim her into a generic RPG healer.",
        ],
    ),
    CharacterSpec(
        ident="kaja",
        display="Kaja",
        char_id="char.kaja",
        role="Bilingual courier; rebellion liaison and strategic manipulator",
        confidence="invented",
        brief_doc="kaja.md",
        summary=(
            "Kaja, a 26-year-old bilingual courier in 1343 Reval who walks long rural "
            "routes between the countryside and the city, of mixed Estonian and German "
            "background, realistic 7.7 heads tall, 170 cm."
        ),
        anatomy=(
            "Lean hard-travelled athletic body: flat strong shoulders and a straight "
            "carried spine, low body fat with visible but not exaggerated abdominal and "
            "shoulder definition, small natural bust, narrow hips, wiry forearms, and "
            "notably developed calves and ankles from constant walking. Weather-tanned "
            "face, neck, forearms and lower legs against paler covered skin."
        ),
        face=(
            "Sharp watchful intelligent face with high cheekbones and a narrow jaw, alert "
            "deep-set hazel eyes, thin straight nose, small controlled mouth, a thin old "
            "pale scar splitting the left eyebrow. Dark brown hair in one thick braid "
            "pinned up off the neck, fine escaped strands at the temples."
        ),
        base_layer=(
            "a plain undyed linen short-sleeved knee-length chemise that follows the body "
            "closely enough to read its volumes, bare lower arms, bare feet."
        ),
        excluded_wardrobe=(
            "cloak, hood, gown, travel bag, satchel, belt, boots, armour or weapon"
        ),
        wardrobe_plan=(
            "the oiled wool travel cloak and hood, plain gown, courier satchel, belt and "
            "walking boots are separate fitted layers."
        ),
        material_file="wool_broadcloth.png",
        material_prompt=(
            "A seamless square physically based material base-color texture of oiled dark "
            "medieval wool broadcloth for a travelling cloak, deep desaturated brown-grey "
            "undyed to woad-overdyed fleece, viewed exactly perpendicular to the flat cloth "
            "surface. Densely fulled and lightly napped surface where the weave is only "
            "partly visible through the felted fibres, faint uneven lanolin sheen, subtle "
            "rain-darkened patches and light abrasion. Flat neutral diffuse light with "
            "minimal directional shading and no glare. Uniform scale throughout, fills the "
            "entire frame edge to edge, periodic seamless tiling edges. A texture material "
            "scan for a realistic historical RPG, NOT a garment, no person, no seams, no "
            "hems, no borders, no illustration, no text. Square aspect ratio."
        ),
        notes=[
            "Her mixed background should read as ordinary and unremarkable, not as an "
            "exotic marker.",
            "Competence and control, not glamour. No leading-lady styling or modern makeup.",
        ],
    ),
    CharacterSpec(
        ident="henning",
        display="Captain Henning",
        char_id="char.henning",
        role="Commander of the Viru Watch; recurring antagonist",
        confidence="plausible composite",
        brief_doc="henning.md",
        summary=(
            "Captain Henning, a 51-year-old German career soldier commanding the Viru Watch "
            "in 1343 Reval, a large heavy man worn down by decades of service, realistic "
            "7.6 heads tall, 180 cm."
        ),
        anatomy=(
            "Heavy soldier's frame going to seed: thick short neck, broad deep barrel "
            "chest, wide square shoulders, heavy solid arms with real mass under a softened "
            "surface, a thickened waist and belly over old muscle, heavy thighs, and a "
            "slight forward head carriage and rounded upper back from years under armour "
            "weight. An old long pale scar along the outside of the right forearm. Not fat, "
            "not lean, not a bodybuilder."
        ),
        face=(
            "Square heavy exhausted face with a hard jaw, deep brow and nasolabial lines, "
            "grey pouches under pale blue deep-set eyes, a nose plainly broken and badly "
            "reset, thin mouth, broken capillaries on the cheeks. Short iron-grey hair "
            "receding at the temples and a close-cropped grey beard."
        ),
        base_layer=(
            "bare torso and arms, modest opaque natural off-white linen knee-length braies "
            "secured at the waist, bare feet."
        ),
        excluded_wardrobe=(
            "gambeson, mail, helmet, surcoat, cloak, boots, belt accessories or weapon"
        ),
        wardrobe_plan=(
            "the quilted gambeson, mail shirt, watch surcoat, helmet, belt and boots are "
            "separate fitted layers."
        ),
        material_file="gambeson_quilt.png",
        material_prompt=(
            "A seamless square physically based material base-color texture of a quilted "
            "medieval linen gambeson panel, dirty unbleached natural linen over dense tow "
            "padding, viewed exactly perpendicular to the flat quilted surface. Even "
            "parallel vertical quilted channels roughly two fingers wide with visible "
            "irregular hand running-stitch lines, padding bulging softly between the "
            "stitched seams, ground-in grime and sweat staining concentrated along the "
            "stitch lines, faint rust transfer marks. Flat neutral diffuse light with "
            "minimal directional shading and no glare. Uniform channel scale throughout, "
            "fills the entire frame edge to edge, periodic seamless tiling edges. A texture "
            "material scan for a realistic historical RPG, NOT a garment, no person, no "
            "collar, no hems, no borders, no illustration, no text. Square aspect ratio."
        ),
        notes=[
            "He must look like a legitimate argument for order, not a thug. Weariness and "
            "competence, not sneering villainy.",
            "Keep him visibly German and visibly a long-serving officer, without heraldry "
            "on the base plate.",
        ],
    ),
    CharacterSpec(
        ident="jurgen",
        display="Jurgen Witte",
        char_id="char.jurgen",
        role="Hanseatic amber merchant; economic temptation and material supplier",
        confidence="plausible composite",
        brief_doc="jurgen.md",
        summary=(
            "Jurgen Witte, a 45-year-old Hanseatic amber merchant in 1343 Reval, a "
            "prosperous sedentary indoor man who has never done physical labour, realistic "
            "7.6 heads tall, 175 cm."
        ),
        anatomy=(
            "Soft well-fed merchant's body: sloping rounded shoulders, a full round chest "
            "and a pronounced comfortable belly, thin unmuscled upper arms and forearms, "
            "soft smooth hands with clean trimmed nails and no calluses, narrow weak "
            "calves, small high-arched feet. Uniformly pale indoor skin with no work tan "
            "line. Plainly wealthy and plainly unfit, without grotesque caricature."
        ),
        face=(
            "Fleshy well-fed shrewd face with full cheeks and faint jowls, heavy relaxed "
            "eyelids over cool pale grey eyes, a small straight nose, full lips with a thin "
            "controlled smile line, a weak chin. Light brown hair neatly cut level with the "
            "jaw with a straight fringe, clean-shaven with a faint shaving shadow."
        ),
        base_layer=(
            "bare torso and arms, modest opaque finely woven bleached linen knee-length "
            "braies secured at the waist, bare feet."
        ),
        excluded_wardrobe=(
            "gown, houppelande, fur trim, hat, hose, shoes, purse, rings or chain of office"
        ),
        wardrobe_plan=(
            "the fine madder-red wool gown, fur-trimmed overgown, chaperon hat, hose, shoes "
            "and merchant's purse are separate fitted layers."
        ),
        material_file="wool_broadcloth_madder.png",
        material_prompt=(
            "A seamless square physically based material base-color texture of expensive "
            "fine medieval fulled wool broadcloth dyed deep rich madder red, viewed exactly "
            "perpendicular to the flat cloth surface. Very dense evenly fulled high-quality "
            "cloth with a smooth short even nap, the fine weave only faintly readable "
            "through the felted surface, deep saturated but plausible plant-dye colour with "
            "slight natural unevenness, soft matte sheen, almost no wear. Flat neutral "
            "diffuse light with minimal directional shading and no glare. Uniform scale "
            "throughout, fills the entire frame edge to edge, periodic seamless tiling "
            "edges. A texture material scan for a realistic historical RPG, NOT a garment, "
            "no person, no seams, no hems, no trim, no borders, no illustration, no text. "
            "Square aspect ratio."
        ),
        notes=[
            "Canon spells him Jurgen Witte (Jürgen). The folder uses the ASCII ident "
            "`jurgen` so paths stay portable across tools and CI.",
            "Read as suave and transactional, not as a comic glutton.",
        ],
    ),
    CharacterSpec(
        ident="ellen",
        display="Ellen Luik",
        char_id="char.ellen",
        role="Midwife and keeper of old songs; folklore perspective",
        confidence="plausible composite",
        brief_doc="ellen.md",
        summary=(
            "Ellen Luik, a 62-year-old Estonian midwife and keeper of old songs in 1343 "
            "Reval, a small spare old woman whose hands are still completely steady, "
            "realistic 7.2 heads tall, 158 cm."
        ),
        anatomy=(
            "Thin aged but not frail body: bony shoulders and prominent clavicles, a slight "
            "fixed stoop in the upper back, loosened skin on the upper arms, flat chest, "
            "thin waist with a small soft lower belly, narrow hips, thin shanks with visible "
            "tendons, and strong working hands with prominent knuckles, thickened joints and "
            "raised veins. Sun-spotted forearms, backs of hands and temples. Old, capable, "
            "and not a bent witch caricature."
        ),
        face=(
            "Narrow deeply lined calm face with sunken cheeks and a fine papery skin "
            "texture, hooded pale grey eyes under thin sparse brows, a sharp thin nose, thin "
            "lips, a strong small chin. Thin white hair pulled straight back into a small "
            "tight low knot, scalp faintly visible at the parting."
        ),
        base_layer=(
            "a plain undyed coarse linen short-sleeved knee-length chemise that follows the "
            "body closely enough to read its volumes, bare lower arms, bare feet."
        ),
        excluded_wardrobe=(
            "gown, overdress, apron, headscarf, kerchief, wimple, shawl, belt, shoes or "
            "amulets"
        ),
        wardrobe_plan=(
            "the striped folk wool gown, linen headscarf, shawl and shoes are separate "
            "fitted layers."
        ),
        material_file="wool_folk_twill.png",
        material_prompt=(
            "A seamless square physically based material base-color texture of handwoven "
            "medieval Estonian folk wool twill cloth, viewed exactly perpendicular to the "
            "flat cloth surface. Warm grey-brown base with narrow irregular woven weft "
            "stripes in muted natural dyes, soft weld yellow and pale woad blue-grey, "
            "clearly handspun uneven yarns, visible diagonal twill, faint sun fading and "
            "light wear. Restrained plausible plant-dye colours, not bright modern "
            "pigments. Flat neutral diffuse light with minimal directional shading and no "
            "glare. Uniform weave and stripe scale throughout, fills the entire frame edge "
            "to edge, periodic seamless tiling edges. A texture material scan for a "
            "realistic historical RPG, NOT a garment, no person, no seams, no hems, no "
            "tablet-woven bands, no borders, no illustration, no text. Square aspect ratio."
        ),
        notes=[
            "Ellen enters after the vertical slice; this pack exists so her design is "
            "reviewable early, not so she can be built now.",
            "Precise and unsentimental. Avoid mystic staging, no ritual props or glowing "
            "features.",
        ],
    ),
]


SPEC_BY_IDENT = {spec.ident: spec for spec in SPECS}
