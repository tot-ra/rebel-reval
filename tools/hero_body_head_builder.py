"""Head and facial-feature assembly for generated rigged characters.

The head is a ring profile, not a stack of balls: chin, jaw, cheek, eye line,
brow, cranium and crown are cross-sections with independent side, front and
back radii. Hair and beard reuse that same profile at a small offset, so they
sit on the head instead of hovering beside it, and a hairline appears
naturally where the offset surface crosses back inside the skull.

Facial realism follows the scan/sculpt practice documented in
docs/reports/face_realism_research.md: a landmark displacement pass
(`_FaceSculpt`) pushes the bare profile into craniofacial form - recessed eye
sockets, brow ridge, cheekbones, nasolabial mounds, chin boss, temple hollows -
and every feature is then seated on the sculpted surface (`_surface_z`), never
glued on at a fixed depth. Eyes are a layered construction (sclera sphere,
iris, pupil, limbal ring, transparent cornea, lid shells, caruncle) and lips
are tubes following the mouth arc with a dark vermillion seam, per the AAA
references. Skin complexion (periorbital shadow, nose/cheek warmth, stubble)
is painted as deterministic vertex colors, standing in for the zoned albedo
textures and subsurface scattering our GL Compatibility renderer cannot run.
"""

from __future__ import annotations

import math

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


def eye_offset(context: BodyContext, face: dict) -> float:
    """Half the distance between the pupils, in world units."""
    return 0.038 * context.scale * face["eye_spacing"]


class _FaceSculpt:
    """Landmark displacement fields that turn the ring profile into a face.

    Every field is a 2D Gaussian on the face plane in normalized authoring
    units (x lateral, h above head_center), applied along `forward` (fwd) or
    laterally outward (lat). The same fields are evaluated both when moving
    skin vertices and when seating features, so eyeballs, lips and brows rest
    exactly on the sculpted surface. All sculpted vertices keep their authored
    `{"head": 1.0}` weights, so the animation contract is untouched.
    """

    def __init__(self, context: BodyContext, shape: dict, face: dict) -> None:
        self.context = context
        self.shape = shape
        self.face = face
        ex = 0.038 * face["eye_spacing"]
        eh = EYE_HEIGHT
        bh = BROW_HEIGHT * face["brow_height"]
        jw = face["jaw_width"]
        fields: list[tuple[str, float, float, float, float, float]] = []
        for s in (1.0, -1.0):
            # Eye socket: the single most important recess on a face. Wide and
            # shallow rather than deep and tight - a tight pit leaves a visible
            # trench around the lid shells instead of flowing into them.
            fields.append(("fwd", s * ex, eh + 0.004, 0.038, 0.030, -0.0080))
            # Zygomatic cheekbone, out and forward.
            fields.append(("lat", s * (ex + 0.017), -0.020, 0.020, 0.020, 0.005))
            fields.append(("fwd", s * (ex + 0.017), -0.020, 0.022, 0.020, 0.004))
            # Under-eye bag transition into the cheek.
            fields.append(("fwd", s * ex, eh - 0.018, 0.014, 0.010, 0.002))
            # Jaw angle: mass at the back of the jaw, scaled by the spec.
            fields.append(("fwd", s * 0.062 * jw, -0.088, 0.018, 0.020, 0.003))
            fields.append(("lat", s * 0.060 * jw, -0.088, 0.018, 0.020, 0.004))
            # Nasolabial mound flanking the mouth corners.
            fields.append(("fwd", s * 0.030, -0.048, 0.016, 0.020, 0.0022))
            # Temple hollow behind the brow tail.
            fields.append(("fwd", s * 0.066, 0.048, 0.022, 0.026, -0.004))
        # Brow ridge: a wide, shallow bar above both sockets.
        fields.append(("fwd", 0.0, bh + 0.002, 0.058, 0.014, 0.004))
        # Glabella / nasion between the brows.
        fields.append(("fwd", 0.0, bh - 0.014, 0.013, 0.012, 0.0035))
        # Chin boss and the mental crease above it.
        fields.append(("fwd", 0.0, -0.112, 0.024, 0.016, 0.0045))
        fields.append(("fwd", 0.0, -0.094, 0.020, 0.005, -0.0025))
        # Nose dorsum root blending the nose tube into the brow.
        fields.append(("fwd", 0.0, -0.030, 0.012, 0.018, 0.002))
        self.fields = fields

    def _gaussian(self, x: float, h: float, cx: float, ch: float, sx: float, sh: float) -> float:
        dx = (x - cx) / sx
        dh = (h - ch) / sh
        return math.exp(-0.5 * (dx * dx + dh * dh))

    def forward_delta(self, x: float, h: float) -> float:
        """Net forward displacement at a normalized face-plane point."""
        total = 0.0
        for kind, cx, ch, sx, sh, amp in self.fields:
            if kind == "fwd":
                total += amp * self._gaussian(x, h, cx, ch, sx, sh)
        return total

    def apply(self, part: PartBuilder, indices: list[int]) -> None:
        """Displace authored skin vertices through the landmark fields."""
        frame = self.context.frame
        scale = self.context.scale
        lift = scale * self.shape["head_scale"] * self.face["length"]
        head_center = self.context.head_center
        for index in indices:
            rel = part.vertices[index] - head_center
            x = rel.dot(frame.left) / scale
            h = rel.dot(frame.up) / lift
            f = rel.dot(frame.forward) / scale
            # Face fields fade out toward the silhouette and the back of the
            # skull, so hairline and neck vertices stay on the clean profile.
            fade = min(max((f + 0.010) / 0.030, 0.0), 1.0)
            if fade <= 0.0:
                continue
            fwd = 0.0
            lat = 0.0
            for kind, cx, ch, sx, sh, amp in self.fields:
                g = self._gaussian(x, h, cx, ch, sx, sh) * fade
                if kind == "fwd":
                    fwd += amp * g
                else:
                    lat += amp * g
            outward = 1.0 if x >= 0.0 else -1.0
            part.vertices[index] = (
                part.vertices[index]
                + frame.forward * fwd * scale
                + frame.left * (lat * outward) * scale
            )


def _surface_z(
    context: BodyContext,
    shape: dict,
    face: dict,
    sculpt: _FaceSculpt,
    x_norm: float,
    h_norm: float,
) -> float:
    """Forward depth of the sculpted skin surface at a face-plane point.

    Interpolates the section profile (side/front radii against height) and
    adds the sculpt displacement, so features follow cheekbone and socket
    curvature on any spec instead of sitting on the bare ellipse.
    """
    scale = context.scale
    lift = scale * shape["head_scale"] * face["length"]
    heights = [section[0] for section in HEAD_SECTIONS]
    clamped_h = min(max(h_norm, heights[0]), heights[-1])
    lower = 0
    while lower < len(heights) - 2 and heights[lower + 1] < clamped_h:
        lower += 1
    upper = lower + 1
    span = heights[upper] - heights[lower]
    t = (clamped_h - heights[lower]) / span if span > 0.0 else 0.0
    side_r = 0.0
    front_r = 0.0
    for index, weight in ((lower, 1.0 - t), (upper, t)):
        width = face["width"] if index >= JAW_SECTIONS else face["jaw_width"]
        side_r += HEAD_SECTIONS[index][1] * scale * width * weight
        front_r += HEAD_SECTIONS[index][2] * scale * face["depth"] * weight
    ratio = min(abs(x_norm * scale) / side_r, 1.0) if side_r > 0.0 else 1.0
    z = front_r * math.sqrt(max(1.0 - ratio * ratio, 0.0))
    return z + sculpt.forward_delta(x_norm, h_norm) * scale


def _feature_point(
    context: BodyContext,
    shape: dict,
    face: dict,
    sculpt: _FaceSculpt,
    h_norm: float,
    x_norm: float,
    proud: float = 0.0,
) -> Vector:
    """A point on the sculpted face surface, `proud` units further forward."""
    frame = context.frame
    scale = context.scale
    lift = scale * shape["head_scale"] * face["length"]
    return (
        context.head_center
        + frame.up * h_norm * lift
        + frame.left * x_norm * scale
        + frame.forward * (_surface_z(context, shape, face, sculpt, x_norm, h_norm) + proud)
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
    # 14 segments instead of the global 20: the sculpt pass, the lens-built eyes
    # and the lid/lash tubes spend the saved triangles where the close camera
    # actually looks, and one applied subdivision doubles the effective ring
    # density anyway. Raising this pushes Tier-1 named NPCs over their 56k cap.
    head_part = PartBuilder("Character_Head", frame, bulk=shape["head_scale"], segments=14)
    sculpt = _FaceSculpt(context, shape, face)
    sections = head_profile(context, shape, face)

    skin_indices: list[int] = []
    head_part.start_tube()
    for center, side_radius, front_radius, back_radius in sections:
        skin_indices += head_part.ring(
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
    # Sculpt the bare profile into craniofacial form before any feature is
    # placed: sockets, cheekbones, brow ridge and chin are part of the skin
    # surface, so nothing glued on later can read as a separate ball.
    sculpt.apply(head_part, skin_indices)

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

    _add_ears(head_part, context, shape, face, sculpt)
    _add_nose(head_part, context, shape, face)
    _add_eyes(head_part, context, shape, face, sculpt)
    _add_mouth(head_part, context, shape, face, sculpt)
    _add_hair(head_part, context, shape, features["hair_style"], face)
    _add_beard(head_part, context, shape, features["beard_style"], face)
    head_part.vertex_color_fn = _complexion(context, shape, face)
    return head_part


def _add_ears(
    head_part: PartBuilder,
    context: BodyContext,
    shape: dict,
    face: dict,
    sculpt: _FaceSculpt,
) -> None:
    """Concha mass plus a helix rim arc and a lobe.

    A bare ellipsoid reads as a fungus; the rim tube around its upper-back
    edge is what makes the silhouette an ear in profile and three-quarter
    views.
    """
    frame = context.frame
    scale = context.scale
    for side in (1.0, -1.0):
        center = face_point(context, shape, face, -0.006, -0.042) + (
            frame.left * side * 0.100 * scale * face["width"]
        )
        head_part.uv_sphere(
            center,
            Vector((0.014 * scale, 0.021 * scale, 0.030 * scale)),
            {"head": 1.0},
            "skin",
            rings=6,
        )
        # Helix: an arc - not a ring - over the upper-back edge of the concha.
        # It has to stay inside the concha silhouette, otherwise the rim floats
        # off as a separate hoop instead of reading as the fold of an ear.
        rim_center = center + frame.left * side * 0.005 * scale
        points = []
        for step in range(6):
            theta = math.radians(108.0 - step * 40.0)
            points.append(
                rim_center
                + frame.up * (0.024 * scale * math.sin(theta))
                + frame.forward * (0.013 * scale * math.cos(theta))
            )
        head_part.start_tube()
        for index, point in enumerate(points):
            if index + 1 < len(points):
                tangent = (points[index + 1] - point).normalized()
            else:
                tangent = (point - points[index - 1]).normalized()
            radius = (0.0040 - 0.0016 * index / (len(points) - 1)) * scale
            head_part.ring(point, tangent, radius, radius, {"head": 1.0}, "skin")
        head_part.cap(points[-1], {"head": 1.0}, "skin")
        head_part.start_tube()
        first = points[0]
        tangent = (points[1] - first).normalized()
        radius = 0.0040 * scale
        head_part.ring(first, tangent, radius, radius, {"head": 1.0}, "skin")
        head_part.cap(first + tangent * (-0.004 * scale), {"head": 1.0}, "skin")
        # Earlobe below the concha.
        head_part.uv_sphere(
            center + frame.up * (-0.028 * scale) + frame.forward * 0.002 * scale,
            Vector((0.009 * scale, 0.009 * scale, 0.012 * scale)),
            {"head": 1.0},
            "skin",
            rings=5,
        )


def _add_nose(
    head_part: PartBuilder, context: BodyContext, shape: dict, face: dict
) -> None:
    """Bridged nose with alae (wings) and a columella.

    The tube supplies the dorsum and tip; the wings keep it from reading as a
    wedge, and the near-black nostril beads under the wings supply the cavity
    shadow a real nose always carries.
    """
    frame = context.frame
    up = frame.up
    scale = context.scale
    nose = face["nose_length"]

    # Kept deliberately narrow and shallow: an over-wide, over-deep tube reads
    # as a wedge stuck to the midface, which is the classic procedural-nose
    # failure. Width at the alae is roughly the eye spacing, as in life.
    # Protrusion is the knob that matters: a real nose stands out roughly an
    # eighth of the head's depth, and anything near a quarter reads as a wedge
    # bolted to the midface however well the wings are shaped.
    head_part.start_tube()
    for height, depth, side_radius, depth_radius in (
        (BROW_HEIGHT * face["brow_height"] - 0.006, 0.088, 0.0090, 0.014),
        (-0.012, 0.090 + 0.004 * nose, 0.0105, 0.019),
        (-0.032, 0.092 + 0.007 * nose, 0.0140, 0.0235),
        (-0.046, 0.089 + 0.005 * nose, 0.0165, 0.021),
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
        face_point(context, shape, face, -0.055, 0.078), {"head": 1.0}, "skin"
    )
    # Alae: soft wings flanking the tip, blending into the nasolabial mounds.
    # Nose width at the wings matches the gap between the inner eye corners.
    for side in (1.0, -1.0):
        head_part.uv_sphere(
            face_point(context, shape, face, -0.043, 0.086 + 0.005 * nose)
            + frame.left * side * 0.0110 * scale,
            Vector((0.0072 * scale, 0.0072 * scale, 0.0062 * scale)),
            {"head": 1.0},
            "skin",
            rings=5,
        )
    # Columella: the column between the nostrils under the tip.
    head_part.uv_sphere(
        face_point(context, shape, face, -0.051, 0.082 + 0.004 * nose),
        Vector((0.0040 * scale, 0.0050 * scale, 0.0038 * scale)),
        {"head": 1.0},
        "skin",
        rings=5,
    )
    # Nostrils: two small shadowed beads tucked under the wings. They are meant
    # to be barely visible from the front - only their shadow should register.
    for side in (1.0, -1.0):
        head_part.uv_sphere(
            face_point(context, shape, face, -0.050, 0.078 + 0.005 * nose)
            + frame.left * side * 0.0090 * scale,
            Vector((0.0046 * scale, 0.0060 * scale, 0.0038 * scale)),
            {"head": 1.0},
            "pupil",
            rings=4,
        )


def _add_eyes(
    head_part: PartBuilder,
    context: BodyContext,
    shape: dict,
    face: dict,
    sculpt: _FaceSculpt,
) -> None:
    """Layered eye assembly seated in the sculpted socket.

    Built as a lens, not a ball. An exposed eyeball sphere with lid spheres
    stacked above and below it reads as a bug eye between two beads no matter
    how the radii are tuned: the lid shells always show their own round
    silhouette against the cheek. Instead the sclera is a flattened ellipsoid
    sunk into the socket, and the lids are tapered tubes that ride its rim, so
    the eye opening is an almond bounded by two lid folds - which is what the
    silhouette of a real eye actually is.

    Stack, front to back: lid tubes and lash line -> cornea -> pupil -> limbal
    ring -> iris -> sclera lens. The limbal ring and the corneal highlight do
    most of the realism work (docs/reports/face_realism_research.md).
    """
    frame = context.frame
    scale = context.scale
    offset_norm = 0.038 * face["eye_spacing"]
    offset_world = eye_offset(context, face)

    # Lens half-extents: lateral, forward bulge, vertical.
    lens_u = 0.0180 * scale
    lens_f = 0.0092 * scale
    lens_h = 0.0092 * scale
    # Aperture rim: upper lid sits higher than the lower, as in life.
    rim_u = 0.0172 * scale
    upper_h = 0.0078 * scale
    lower_h = 0.0064 * scale
    # Canthal tilt: the outer corner rides above the inner one. Without it the
    # eye reads as a horizontal slot stamped into the face.
    tilt = 0.075

    for side in (1.0, -1.0):
        surface = _surface_z(
            context, shape, face, sculpt, side * offset_norm, EYE_HEIGHT
        )
        # Anchor is the lens centre, sunk so the lens front sits just proud of
        # the socket skin and the lid tubes stand proud of the lens.
        anchor = (
            context.head_center
            + frame.up * EYE_HEIGHT * scale * shape["head_scale"] * face["length"]
            + frame.left * side * offset_world
            + frame.forward * (surface - 0.0078 * scale)
        )

        def place(u: float, h: float, f: float) -> Vector:
            """Point in eye-local coordinates: u outward, h up, f forward."""
            return (
                anchor
                + frame.left * side * u
                + frame.up * (h + tilt * u)
                + frame.forward * f
            )

        head_part.uv_sphere(
            place(0.0, 0.0, 0.0),
            Vector((lens_u, lens_f, lens_h)),
            {"head": 1.0},
            "eye_white",
            rings=7,
        )
        # Iris and pupil: flattened beads on the lens front, the iris a little
        # proud so the eye keeps a corneal bulge in profile. Iris diameter is
        # roughly half the eye opening width, as in life.
        head_part.uv_sphere(
            place(0.0, 0.0, 0.0072 * scale),
            Vector((0.0072 * scale, 0.0026 * scale, 0.0072 * scale)),
            {"head": 1.0},
            "eyes",
            rings=5,
        )
        head_part.uv_sphere(
            place(0.0, 0.0, 0.0086 * scale),
            Vector((0.0030 * scale, 0.0013 * scale, 0.0030 * scale)),
            {"head": 1.0},
            "pupil",
            rings=4,
        )
        # Limbal ring: the dark band at the iris edge. Real eyes always have
        # it; without it the iris bleeds into the sclera and reads doll-like.
        # Narrow on purpose - a thick ring turns into a cartoon outline.
        head_part.start_tube()
        for depth, radius in ((0.0082, 0.0066), (0.0074, 0.0076)):
            head_part.ring(
                place(0.0, 0.0, depth * scale),
                frame.forward,
                radius * scale,
                radius * scale,
                {"head": 1.0},
                "pupil",
            )
        # Cornea: transparent bulge over the iris supplying the wet highlight.
        head_part.uv_sphere(
            place(0.0, 0.0, 0.0048 * scale),
            Vector((0.0090 * scale, 0.0056 * scale, 0.0090 * scale)),
            {"head": 1.0},
            "cornea",
            rings=5,
        )

        def rim_point(angle: float, height: float, proud: float) -> Vector:
            """A point on the lens surface at aperture-rim latitude."""
            u = rim_u * math.cos(angle)
            h = height * math.sin(angle)
            inside = 1.0 - (u / lens_u) ** 2 - (h / lens_h) ** 2
            f = lens_f * math.sqrt(max(inside, 0.0)) + proud
            return place(u, h, f)

        # Lid tubes. The upper lid is heavier and overhangs the lens; the lower
        # is a thin ledge. Both taper to nothing at the canthi, which is what
        # turns the elliptical opening into an almond.
        for height, radii, proud in (
            (upper_h, (0.0009, 0.0021, 0.0026, 0.0021, 0.0009), 0.0012),
            (-lower_h, (0.0007, 0.0012, 0.0014, 0.0012, 0.0007), 0.0007),
        ):
            angles = [math.radians(a) for a in (178.0, 135.0, 90.0, 45.0, 2.0)]
            points = [rim_point(a, height, proud * scale) for a in angles]
            head_part.start_tube()
            for index, point in enumerate(points):
                if index + 1 < len(points):
                    tangent = (points[index + 1] - point).normalized()
                else:
                    tangent = (point - points[index - 1]).normalized()
                head_part.ring(
                    point,
                    tangent,
                    radii[index] * scale,
                    radii[index] * scale,
                    {"head": 1.0},
                    "skin",
                )
            head_part.cap(points[-1], {"head": 1.0}, "skin")
            head_part.start_tube()
            first = points[0]
            tangent = (points[1] - first).normalized()
            head_part.ring(
                first,
                tangent,
                radii[0] * scale,
                radii[0] * scale,
                {"head": 1.0},
                "skin",
            )
            head_part.cap(first - tangent * 0.0012 * scale, {"head": 1.0}, "skin")

        # Lash line: a dark thread just inside the upper lid. It is the single
        # strongest "this is an eye" cue we can afford, and it hides the seam
        # where the lid tube meets the lens.
        angles = [math.radians(a) for a in (172.0, 130.0, 90.0, 50.0, 8.0)]
        points = [rim_point(a, upper_h * 0.86, 0.0011 * scale) for a in angles]
        head_part.start_tube()
        for index, point in enumerate(points):
            if index + 1 < len(points):
                tangent = (points[index + 1] - point).normalized()
            else:
                tangent = (point - points[index - 1]).normalized()
            radius = (0.0009 - 0.0004 * abs(index - 2) / 2.0) * scale
            head_part.ring(
                point, tangent, radius, radius, {"head": 1.0}, "lip_seam"
            )
        head_part.cap(points[-1], {"head": 1.0}, "lip_seam")
        head_part.start_tube()
        first = points[0]
        tangent = (points[1] - first).normalized()
        head_part.ring(
            first, tangent, 0.0005 * scale, 0.0005 * scale, {"head": 1.0}, "lip_seam"
        )
        head_part.cap(first - tangent * 0.0010 * scale, {"head": 1.0}, "lip_seam")

        # Caruncle: the small pink mass at the inner canthus.
        head_part.uv_sphere(
            place(-rim_u * 0.94, 0.0, 0.0026 * scale),
            Vector((0.0026 * scale, 0.0024 * scale, 0.0030 * scale)),
            {"head": 1.0},
            "lips",
            rings=4,
        )
        _add_brow(head_part, context, shape, face, sculpt, side)


def _add_brow(
    head_part: PartBuilder,
    context: BodyContext,
    shape: dict,
    face: dict,
    sculpt: _FaceSculpt,
    side: float,
) -> None:
    """Eyebrow as a tapered tube following the brow ridge arc.

    Replaces the old floating box: the tube hugs the sculpted surface from the
    glabella to the temple, which is what anchors it visually to the skull.
    """
    scale = context.scale
    brow_height = BROW_HEIGHT * face["brow_height"]
    ex = 0.038 * face["eye_spacing"]
    fractions = (0.0, 0.28, 0.58, 0.82, 1.0)
    points = []
    for t in fractions:
        x_norm = side * (0.010 + t * (ex + 0.010))
        # Inner head low, arch peak around 60%, tail settling toward the temple.
        h_norm = brow_height - 0.002 + 0.010 * (1.0 - ((t - 0.60) / 0.68) ** 2)
        points.append(
            _feature_point(context, shape, face, sculpt, h_norm, x_norm, 0.0012 * scale)
        )
    head_part.start_tube()
    for index, point in enumerate(points):
        if index + 1 < len(points):
            tangent = (points[index + 1] - point).normalized()
        else:
            tangent = (point - points[index - 1]).normalized()
        radius = (0.0042 - 0.0020 * fractions[index]) * scale
        head_part.ring(point, tangent, radius, radius, {"head": 1.0}, "hair")
    head_part.cap(points[-1], {"head": 1.0}, "hair")
    head_part.start_tube()
    first = points[0]
    tangent = (points[1] - first).normalized()
    head_part.ring(
        first, tangent, 0.0042 * scale, 0.0042 * scale, {"head": 1.0}, "hair"
    )
    head_part.cap(first - tangent * 0.003 * scale, {"head": 1.0}, "hair")


def _add_mouth(
    head_part: PartBuilder,
    context: BodyContext,
    shape: dict,
    face: dict,
    sculpt: _FaceSculpt,
) -> None:
    """Lips as tubes along the mouth arc with a dark vermillion seam.

    The upper lip carries a cupid's bow (fuller lobes beside a dipped center),
    the lower lip is fuller in the middle, and the thin dark seam between them
    is what reads as a closed mouth at dialogue distance. Neutral geometry on
    purpose: dialogue and attack clips move the whole head, so the rest pose
    must not bake an expression.
    """
    frame = context.frame
    scale = context.scale
    # Mouth width tracks the interpupillary distance, as in life; a narrow
    # mouth is what made the earlier lips read as a pursed bud.
    half_width = 0.032 * face["jaw_width"]

    def lip_tube(
        fractions: tuple[float, ...],
        radii: tuple[float, ...],
        h_center: float,
        corner_drop: float,
        forward_ratio: float,
        material: str,
    ) -> None:
        points = []
        for fraction in fractions:
            x_norm = fraction * half_width
            h_norm = h_center - corner_drop * fraction * fraction
            surface = _surface_z(context, shape, face, sculpt, x_norm, h_norm)
            points.append(
                context.head_center
                + frame.up * h_norm * scale * shape["head_scale"] * face["length"]
                + frame.left * x_norm * scale
                + frame.forward * surface
            )
        head_part.start_tube()
        for index, point in enumerate(points):
            if index + 1 < len(points):
                tangent = (points[index + 1] - point).normalized()
            else:
                tangent = (point - points[index - 1]).normalized()
            radius = radii[index] * scale
            head_part.ring(
                point
                + frame.forward * (radius * forward_ratio),
                tangent,
                radius,
                radius * 0.9,
                {"head": 1.0},
                material,
                radius,
            )
        head_part.cap(points[-1], {"head": 1.0}, material)
        head_part.start_tube()
        first = points[0]
        tangent = (points[1] - first).normalized()
        first_radius = radii[0] * scale
        head_part.ring(
            first + frame.forward * (first_radius * forward_ratio),
            tangent,
            first_radius,
            first_radius * 0.9,
            {"head": 1.0},
            material,
            first_radius,
        )
        head_part.cap(first - tangent * 0.002 * scale, {"head": 1.0}, material)

    fractions = (-1.0, -0.62, -0.28, 0.0, 0.28, 0.62, 1.0)
    # The two lip tubes are spaced closer than the sum of their radii on
    # purpose: they have to merge into one mouth mass. Spaced apart they read
    # as two sausages pasted on the face, which is what this replaced.
    # Upper lip: dipped center between two fuller lobes (cupid's bow).
    lip_tube(
        fractions,
        (0.0014, 0.0031, 0.0040, 0.0029, 0.0040, 0.0031, 0.0014),
        MOUTH_HEIGHT + 0.0032,
        0.0028,
        0.26,
        "lips",
    )
    # Lower lip: fuller and softer, set slightly further back.
    lip_tube(
        fractions,
        (0.0012, 0.0033, 0.0043, 0.0047, 0.0043, 0.0033, 0.0012),
        MOUTH_HEIGHT - 0.0042,
        0.0022,
        0.22,
        "lips",
    )
    # Vermillion seam: the dark line where the lips meet. It must sit proud of
    # both tubes, otherwise it is swallowed and the mouth loses its closure.
    lip_tube(
        (-1.0, -0.5, 0.0, 0.5, 1.0),
        (0.0008, 0.0011, 0.0012, 0.0011, 0.0008),
        MOUTH_HEIGHT - 0.0002,
        0.0024,
        0.45,
        "lip_seam",
    )


def _complexion(
    context: BodyContext, shape: dict, face: dict
) -> "callable[[Vector, str], tuple]":
    """Deterministic skin-zone tints, evaluated per vertex on the final mesh.

    Stands in for the zoned albedo textures and SSS of the AAA references:
    periorbital shadow, warm nose/cheeks/ears, a stubble mask governed by the
    spec's `face.stubble` knob, neck shade and a faint luminance breakup. All
    values hover near white so the spec's palette skin tone stays in charge.
    """
    frame = context.frame
    scale = context.scale
    lift = scale * shape["head_scale"] * face["length"]
    head_center = context.head_center
    ex = 0.038 * face["eye_spacing"]
    stubble = float(face.get("stubble", 0.55))
    jw = face["jaw_width"]

    def gauss(x: float, h: float, cx: float, ch: float, sx: float, sh: float) -> float:
        dx = (x - cx) / sx
        dh = (h - ch) / sh
        return math.exp(-0.5 * (dx * dx + dh * dh))

    def noise(v: Vector) -> float:
        qx = int(v.x * 4000.0)
        qy = int(v.y * 4000.0)
        qz = int(v.z * 4000.0)
        hashed = (qx * 73856093) ^ (qy * 19349663) ^ (qz * 83492791)
        return ((hashed & 0xFFFF) / 0xFFFF) * 2.0 - 1.0

    def fibre(position: Vector) -> float:
        """Breakup correlated along a strand and varying across it.

        Plain per-vertex noise on hair reads as salt and pepper. Quantising
        finely across the head and coarsely along the strand direction makes
        the variation run in fibres instead, which is what stops a smooth hair
        shell from looking like a carved and painted block.
        """
        rel = position - head_center
        # Strands are separated by azimuth around the skull and run down it, so
        # quantise the angle finely and the height coarsely. Quantising world
        # axes instead produced horizontal bands, which read as terracing.
        strand = int(math.atan2(rel.dot(frame.left), rel.dot(frame.forward)) * 26.0)
        run = int(rel.dot(frame.up) * 55.0 / max(scale, 1e-6))
        hashed = (strand * 73856093) ^ (run * 19349663)
        return ((hashed & 0xFFFF) / 0xFFFF) * 2.0 - 1.0

    def tint(position: Vector, material: str = "skin") -> tuple:
        if material in ("hair", "beard"):
            level = 1.0 + 0.16 * fibre(position) + 0.05 * noise(position)
            level = min(max(level, 0.0), 1.0)
            # Slightly cooler where darker, as real hair shadows between clumps.
            return (level, level * (1.0 - 0.02 * (1.0 - level)), level * 0.98, 1.0)
        rel = position - head_center
        x = rel.dot(frame.left) / scale
        h = rel.dot(frame.up) / lift
        f = rel.dot(frame.forward) / scale
        r = g = b = 1.0
        front = min(max((f + 0.010) / 0.030, 0.0), 1.0)
        if front > 0.0:
            # Periorbital shadow: cooler and darker around each eye.
            for side in (1.0, -1.0):
                orbital = gauss(x, h, side * ex, EYE_HEIGHT + 0.002, 0.024, 0.020) * front
                r *= 1.0 - 0.090 * orbital
                g *= 1.0 - 0.120 * orbital
                b *= 1.0 - 0.110 * orbital
                # Cheek warmth below and outboard of the socket.
                cheek = gauss(x, h, side * (ex + 0.014), -0.032, 0.022, 0.020) * front
                r *= 1.0 + 0.070 * cheek
                b *= 1.0 - 0.065 * cheek
            # Nose tip warmth - the reddest point of a face.
            nose = gauss(x, h, 0.0, -0.040, 0.014, 0.026) * front
            r *= 1.0 + 0.080 * nose
            b *= 1.0 - 0.075 * nose
            # Slight redness around the mouth.
            mouth = gauss(x, h, 0.0, MOUTH_HEIGHT, 0.030, 0.016) * front
            r *= 1.0 + 0.035 * mouth
            b *= 1.0 - 0.030 * mouth
            # Stubble: jaw band plus upper-lip patch, spec-controlled.
            if stubble > 0.0:
                band = min(max((h + 0.140) / 0.020, 0.0), 1.0) * min(
                    max((-0.036 - h) / 0.020, 0.0), 1.0
                )
                width_mask = min(max((0.080 * jw - abs(x)) / 0.020, 0.0), 1.0)
                lip_patch = gauss(x, h, 0.0, -0.056, 0.020, 0.008)
                mask = min(band * width_mask + lip_patch, 1.0) * front * stubble
                darken = 1.0 - 0.20 * mask
                r *= darken
                g *= 1.0 - 0.175 * mask
                b *= 1.0 - 0.140 * mask
        # Ear warmth: the thin cartilage flushes red under light.
        ear = gauss(abs(x), h, 0.102, -0.008, 0.016, 0.026)
        r *= 1.0 + 0.060 * ear
        b *= 1.0 - 0.045 * ear
        # Forehead reads a touch lighter, the neck falls into shade.
        if h > 0.050:
            lift_amount = min((h - 0.050) / 0.030, 1.0) * 0.020
            r *= 1.0 + lift_amount
            g *= 1.0 + lift_amount
            b *= 1.0 + lift_amount
        if h < -0.120:
            shade = min((-0.120 - h) / 0.020, 1.0) * 0.055
            r *= 1.0 - shade
            g *= 1.0 - shade
            b *= 1.0 - shade
        # Faint deterministic luminance breakup so large flats never band.
        variation = 1.0 + 0.018 * noise(position)
        return (
            min(max(r * variation, 0.0), 1.0),
            min(max(g * variation, 0.0), 1.0),
            min(max(b * variation, 0.0), 1.0),
            1.0,
        )

    return tint


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
