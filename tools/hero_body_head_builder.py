"""Head and facial-feature assembly for generated rigged characters.

The head is a ring profile, not a stack of balls: chin, jaw, cheek, eye line,
brow, cranium and crown are cross-sections with independent side, front and
back radii. Hair and beard reuse that same profile at a small offset, so they
sit on the head instead of hovering beside it, and a hairline appears
naturally where the offset surface crosses back inside the skull.
"""

from __future__ import annotations

from mathutils import Vector

from hero_body_context import BodyContext, blend_weights
from hero_body_mesh_builder import PartBuilder

# Cross-sections as (height above head_center, side, front, back), in the same
# authoring units as every other builder (stature 1.76, pre-scale). `side` is
# multiplied by face width, depth radii by face depth, and the lower four
# sections additionally by jaw width.
HEAD_SECTIONS = [
    (-0.130, 0.034, 0.050, 0.036),
    (-0.108, 0.060, 0.084, 0.070),
    (-0.082, 0.082, 0.098, 0.090),
    (-0.048, 0.098, 0.106, 0.106),
    (-0.016, 0.108, 0.112, 0.122),
    (0.024, 0.112, 0.108, 0.132),
    (0.066, 0.109, 0.100, 0.132),
    (0.106, 0.093, 0.086, 0.108),
    (0.136, 0.060, 0.056, 0.068),
]
JAW_SECTIONS = 4
CROWN_HEIGHT = 0.152

# Face landmarks, as (height above head_center) - shared by the features and by
# the hair and beard so a spec's proportions move them together.
EYE_HEIGHT = -0.008
BROW_HEIGHT = 0.022
MOUTH_HEIGHT = -0.070


def head_profile(context: BodyContext, shape: dict, face: dict) -> list[tuple]:
    """Return (center, side, front, back) for every head cross-section."""
    up = context.frame.up
    scale = context.scale
    lift = scale * shape["head_scale"]
    sections = []
    for index, (height, side, front, back) in enumerate(HEAD_SECTIONS):
        width = face["width"] if index >= JAW_SECTIONS else face["jaw_width"]
        sections.append(
            (
                context.head_center + up * height * lift * face["length"],
                side * scale * width,
                front * scale * face["depth"],
                back * scale * face["depth"],
            )
        )
    return sections


def face_point(
    context: BodyContext, shape: dict, face: dict, height: float, depth: float
) -> Vector:
    """A point on the facial mid-plane: `height` above head_center, `depth` out."""
    frame = context.frame
    scale = context.scale
    return (
        context.head_center
        + frame.up * height * scale * shape["head_scale"] * face["length"]
        + frame.forward * depth * scale * face["depth"]
    )


def build_head(
    context: BodyContext, shape: dict, face: dict, features: dict
) -> PartBuilder:
    frame = context.frame
    up = frame.up
    scale = context.scale
    head = context.head
    neck_base = context.neck_base

    # Named characters alter the facial mesh, never the head bone. Attachments,
    # hit reactions and all retargeted clips therefore keep a stable contract.
    head_part = PartBuilder("Character_Head", frame, bulk=shape["head_scale"])
    sections = head_profile(context, shape, face)

    head_part.start_tube()
    for center, side_radius, front_radius, back_radius in sections:
        head_part.ring(
            center, up, side_radius, front_radius, {"head": 1.0}, "skin", back_radius
        )
    head_part.cap(
        face_point(context, shape, face, CROWN_HEIGHT, 0.0), {"head": 1.0}, "skin"
    )
    head_part.start_tube()
    first_center, first_side, first_front, first_back = sections[0]
    head_part.ring(
        first_center, up, first_side, first_front, {"head": 1.0}, "skin", first_back
    )
    head_part.cap(
        face_point(context, shape, face, -0.148, 0.0), {"head": 1.0}, "skin"
    )

    head_part.start_tube()
    head_part.ring(
        neck_base,
        up,
        0.056 * scale,
        0.052 * scale,
        blend_weights("chest", "head", 0.35),
        "skin",
    )
    head_part.ring(
        head + up * 0.045 * scale,
        up,
        0.058 * scale,
        0.054 * scale,
        {"head": 1.0},
        "skin",
    )
    head_part.cap(head + up * 0.065 * scale, {"head": 1.0}, "skin")

    _add_ears(head_part, context, shape, face)
    _add_brow_and_nose(head_part, context, shape, face)
    _add_eyes(head_part, context, shape, face)
    _add_mouth(head_part, context, shape, face)
    _add_hair(head_part, context, shape, features["hair_style"], face)
    _add_beard(head_part, context, shape, features["beard_style"], face)
    return head_part


def _add_ears(
    head_part: PartBuilder, context: BodyContext, shape: dict, face: dict
) -> None:
    frame = context.frame
    scale = context.scale
    for side in (1.0, -1.0):
        center = face_point(context, shape, face, -0.006, -0.042) + (
            frame.left * side * 0.100 * scale * face["width"]
        )
        head_part.uv_sphere(
            center,
            Vector((0.019 * scale, 0.024 * scale, 0.032 * scale)),
            {"head": 1.0},
            "skin",
            rings=7,
        )


def eye_offset(context: BodyContext, face: dict) -> float:
    """Half the distance between the pupils, in world units."""
    return 0.038 * context.scale * face["eye_spacing"]


def _surface_depth(context: BodyContext, face: dict, section: int, offset: float) -> float:
    """How far forward the face plane lies `offset` out from the mid-line.

    Features placed at a fixed depth protrude at the sides of the head, which
    is what made the eyes bulge out past the cheekbone. Following the section
    ellipse instead keeps them seated wherever the spec puts them.
    """
    _height, side, front, _back = HEAD_SECTIONS[section]
    half_width = side * context.scale * face["width"]
    if half_width <= 0.0:
        return 0.0
    ratio = min(abs(offset) / half_width, 1.0)
    return front * (1.0 - ratio * ratio) ** 0.5


def _add_brow_and_nose(
    head_part: PartBuilder, context: BodyContext, shape: dict, face: dict
) -> None:
    """Brow arches and a bridged nose.

    The arches are skin, not a painted dark bar: the shadow they drop is what
    seats the eyes in sockets under the game's directional light. One arch per
    eye follows the skull's curve, where a single wide ridge became a shelf.
    """
    frame = context.frame
    up = frame.up
    scale = context.scale
    brow_height = BROW_HEIGHT * face["brow_height"]
    offset = eye_offset(context, face)
    brow_depth = _surface_depth(context, face, 5, offset)

    for side in (1.0, -1.0):
        head_part.uv_sphere(
            face_point(context, shape, face, brow_height - 0.004, brow_depth - 0.012)
            + frame.left * side * offset,
            Vector((0.038 * scale * face["width"], 0.026 * scale, 0.012 * scale)),
            {"head": 1.0},
            "skin",
            rings=8,
        )
    # Glabella: the small bridge of bone between the arches.
    head_part.uv_sphere(
        face_point(context, shape, face, brow_height - 0.004, brow_depth - 0.004),
        Vector((0.024 * scale * face["width"], 0.026 * scale, 0.014 * scale)),
        {"head": 1.0},
        "skin",
        rings=7,
    )

    nose = face["nose_length"]
    head_part.start_tube()
    for height, depth, side_radius, depth_radius in (
        (brow_height - 0.004, 0.092, 0.014, 0.022),
        (-0.014, 0.098 + 0.008 * nose, 0.017, 0.030),
        (-0.036, 0.100 + 0.014 * nose, 0.023, 0.036),
        (-0.052, 0.094 + 0.010 * nose, 0.026, 0.032),
    ):
        head_part.ring(
            face_point(context, shape, face, height, depth),
            up,
            side_radius * scale,
            depth_radius * scale,
            {"head": 1.0},
            "skin",
        )
    head_part.cap(
        face_point(context, shape, face, -0.064, 0.070), {"head": 1.0}, "skin"
    )
    # Nostrils: two small shadowed beads tucked under the nose wings. The lip
    # tone doubles as a dark cavity color, so the nose stops reading as a
    # featureless wedge in close-ups.
    for side in (1.0, -1.0):
        head_part.uv_sphere(
            face_point(context, shape, face, -0.056, 0.084 + 0.010 * nose)
            + frame.left * side * 0.014 * scale,
            Vector((0.0075 * scale, 0.009 * scale, 0.006 * scale)),
            {"head": 1.0},
            "lips",
            rings=5,
        )


def _add_eyes(
    head_part: PartBuilder, context: BodyContext, shape: dict, face: dict
) -> None:
    """Eyes seated in the face plane, with only the lid overhanging.

    Full spheres stuck on the surface were the single largest reason these
    faces read as grotesque; so was burying them until they vanished. The
    eyeball breaks the surface by roughly its own highlight's worth.
    """
    frame = context.frame
    scale = context.scale
    offset_distance = eye_offset(context, face)
    # Seat the eyeball just behind the local face plane so only its front cap
    # emerges, whatever width or eye spacing the spec asks for.
    eye_depth = _surface_depth(context, face, 4, offset_distance) - 0.015
    for side in (1.0, -1.0):
        offset = frame.left * side * offset_distance
        eye_center = face_point(context, shape, face, EYE_HEIGHT, eye_depth) + offset
        head_part.uv_sphere(
            eye_center,
            Vector((0.021 * scale, 0.018 * scale, 0.014 * scale)),
            {"head": 1.0},
            "eye_white",
            rings=8,
        )
        # A wide iris: a small dark bead in a large white reads as a stare.
        head_part.uv_sphere(
            eye_center + frame.forward * 0.010 * scale,
            Vector((0.0125 * scale, 0.010 * scale, 0.011 * scale)),
            {"head": 1.0},
            "eyes",
            rings=7,
        )
        # Upper lid only: it clips the top of the eyeball and casts the line
        # that makes the eye read as open rather than as a bead.
        head_part.uv_sphere(
            eye_center + frame.up * 0.018 * scale - frame.forward * 0.004 * scale,
            Vector((0.028 * scale, 0.021 * scale, 0.012 * scale)),
            {"head": 1.0},
            "skin",
            rings=7,
        )
        head_part.box(
            eye_center
            + frame.up * 0.030 * scale * face["brow_height"]
            + frame.forward * 0.006 * scale,
            frame.left * 0.020 * scale,
            frame.forward * 0.005 * scale,
            frame.up * 0.004 * scale,
            {"head": 1.0},
            "hair",
        )


def _add_mouth(
    head_part: PartBuilder, context: BodyContext, shape: dict, face: dict
) -> None:
    """Two shallow lips.

    Kept as neutral geometry so dialogue and attack animations move the whole
    head without a frozen painted expression.
    """
    scale = context.scale
    width = 0.026 * scale * face["jaw_width"]
    # Lips ride the jaw section's own surface, so a beard drawn on that same
    # profile cannot swallow the mouth, and they stay shallow enough to read as
    # a mouth rather than as two pieces of fruit.
    depth = _surface_depth(context, face, 3, 0.0) - 0.011
    head_part.uv_sphere(
        face_point(context, shape, face, MOUTH_HEIGHT + 0.006, depth),
        Vector((width, 0.016 * scale, 0.007 * scale)),
        {"head": 1.0},
        "lips",
        rings=7,
    )
    head_part.uv_sphere(
        face_point(context, shape, face, MOUTH_HEIGHT - 0.008, depth - 0.002),
        Vector((width * 0.92, 0.016 * scale, 0.008 * scale)),
        {"head": 1.0},
        "lips",
        rings=7,
    )


def _add_hair(
    head_part: PartBuilder,
    context: BodyContext,
    shape: dict,
    style: str,
    face: dict,
) -> None:
    if style == "bald":
        return

    frame = context.frame
    up, forward = frame.up, frame.forward
    scale = context.scale
    sections = head_profile(context, shape, face)

    # Hair is the head profile pushed out and back. Where the pushed surface
    # falls inside the skull - the lower forehead - no hair shows, which is
    # what draws the hairline; the back and sides stay covered throughout.
    # Per-section (side, front, back) factors on the skull profile. Below 1.0
    # the hair hides inside the head, above it the hair shows; the crossing is
    # the hairline, and starting fully inside at the eye line means the bottom
    # edge of the hair is never a visible rim.
    # The jump across the hairline section has to be decisive: two surfaces
    # crossing at a shallow angle speckle against each other along the seam.
    # The bottom edge sits between the eye-line and brow sections; the nape
    # patch below supplies the downward continuation at the center back, so
    # the shell itself must not descend to the neck (that read as a swim cap).
    if style == "short":
        factors = (
            (0.96, 0.92, 0.96),
            (1.05, 1.03, 1.07),
            (1.06, 1.05, 1.08),
            (1.08, 1.07, 1.10),
            (1.16, 1.13, 1.18),
        )
    else:
        factors = (
            (0.98, 0.95, 0.99),
            (1.08, 1.07, 1.11),
            (1.09, 1.08, 1.12),
            (1.12, 1.11, 1.15),
            (1.22, 1.17, 1.26),
        )
    head_part.start_tube()
    for (side_factor, front_factor, back_factor), index in zip(
        factors, (4, 5, 6, 7, 8)
    ):
        center, side_radius, front_radius, back_radius = sections[index]
        head_part.ring(
            center - forward * 0.004 * scale,
            up,
            side_radius * side_factor,
            front_radius * front_factor,
            {"head": 1.0},
            "hair",
            back_radius * back_factor,
        )
    head_part.cap(
        face_point(context, shape, face, CROWN_HEIGHT + 0.010, -0.008),
        {"head": 1.0},
        "hair",
    )

    if style in ("short", "full"):
        # Sideburns in front of the ears: they connect the scalp shell to the
        # beard line, which breaks the "bathing cap" read the plain tube had.
        for side in (1.0, -1.0):
            head_part.uv_sphere(
                face_point(context, shape, face, -0.012, -0.008)
                + frame.left * side * 0.094 * scale * face["width"],
                Vector((0.018 * scale, 0.014 * scale, 0.040 * scale)),
                {"head": 1.0},
                "hair",
                rings=7,
            )
        # Nape taper: short hair continues down the back of the neck at the
        # center only. The ears stay clear and the silhouette reads as a
        # tapered haircut instead of a cap pulled down to the neck.
        head_part.uv_sphere(
            face_point(context, shape, face, 0.010, -0.116),
            Vector((0.060 * scale * face["width"], 0.028 * scale, 0.072 * scale)),
            {"head": 1.0},
            "hair",
            rings=8,
        )

    if style == "ponytail":
        tail_base = face_point(context, shape, face, 0.070, -0.130)
        head_part.start_tube()
        for center, radius in (
            (tail_base, 0.032),
            (tail_base - forward * 0.028 * scale - up * 0.100 * scale, 0.027),
            (tail_base - forward * 0.036 * scale - up * 0.200 * scale, 0.019),
        ):
            head_part.ring(
                center,
                up,
                radius * scale,
                radius * 0.94 * scale,
                {"head": 1.0},
                "hair",
            )
        head_part.cap(
            tail_base - forward * 0.040 * scale - up * 0.245 * scale,
            {"head": 1.0},
            "hair",
        )
    elif style == "bun":
        head_part.uv_sphere(
            face_point(context, shape, face, 0.112, -0.118),
            Vector((0.052 * scale, 0.050 * scale, 0.048 * scale)),
            {"head": 1.0},
            "hair",
            rings=9,
        )
    elif style == "long":
        # Hair falling behind the ears: it keeps the head's own width at the
        # top and tapers below the jaw, instead of hanging as a flat slab.
        head_part.start_tube()
        for center, side_radius, front_radius, back_radius, weights in (
            (
                face_point(context, shape, face, 0.070, -0.030),
                0.104,
                0.040,
                0.126,
                {"head": 1.0},
            ),
            (
                face_point(context, shape, face, -0.020, -0.040),
                0.108,
                0.046,
                0.128,
                {"head": 1.0},
            ),
            (
                face_point(context, shape, face, -0.110, -0.052),
                0.094,
                0.044,
                0.112,
                {"head": 1.0},
            ),
            (
                context.neck_base - forward * 0.050 * scale,
                0.072,
                0.038,
                0.086,
                blend_weights("chest", "head", 0.5),
            ),
        ):
            head_part.ring(
                center,
                up,
                side_radius * scale,
                front_radius * scale,
                weights,
                "hair",
                back_radius * scale,
            )
        head_part.cap(
            context.neck_base - forward * 0.048 * scale - up * 0.040 * scale,
            {"head": 1.0},
            "hair",
        )


def _add_beard(
    head_part: PartBuilder,
    context: BodyContext,
    shape: dict,
    style: str,
    face: dict,
) -> None:
    if style == "none":
        return

    frame = context.frame
    up = frame.up
    scale = context.scale
    sections = head_profile(context, shape, face)

    # The beard follows the jaw sections outward, so it is a beard on a jaw
    # rather than a ball in front of a chin. `full` climbs onto the cheeks and
    # hangs below the chin; `short` stops at the jaw line.
    volume = 0.011 if style == "full" else 0.007
    top_section = 4 if style == "full" else 3
    head_part.start_tube()
    for index in range(top_section, -1, -1):
        center, side_radius, front_radius, back_radius = sections[index]
        # The topmost section is tucked inside the skin: the beard then
        # emerges along the jaw where the two surfaces cross, instead of
        # ending on a hard horizontal edge across the cheeks.
        grow = volume * (-0.9 if index == top_section else 1.0) * scale
        head_part.ring(
            center,
            up,
            side_radius + grow,
            front_radius + grow,
            {"head": 1.0},
            "beard",
            # The back of the band dives deep inside the skull. Without this
            # shrink the beard ring wraps the whole lower head and reads as a
            # dark hair band on the back of the head in every profile view.
            back_radius * 0.72,
        )
    hang = -0.168 if style == "full" else -0.146
    head_part.cap(
        face_point(context, shape, face, hang, 0.026), {"head": 1.0}, "beard"
    )

    # Moustache bridging nose to beard, so the mouth stays readable. Short
    # beards keep a slimmer moustache instead of none at all.
    moustache = 1.0 if style == "full" else 0.72
    head_part.uv_sphere(
        face_point(context, shape, face, MOUTH_HEIGHT + 0.020, 0.086),
        Vector(
            (
                0.040 * scale * face["jaw_width"] * moustache,
                0.022 * scale * moustache,
                0.012 * scale,
            )
        ),
        {"head": 1.0},
        "beard",
        rings=7,
    )
