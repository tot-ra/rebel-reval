"""Torso assembly for the generated hero body."""

from __future__ import annotations

import math

from mathutils import Vector

from hero_body_anatomy_builder import torso_profile
from hero_body_context import BodyContext, blend_weights
from hero_body_mesh_builder import PartBuilder


def build_torso_layers(context: BodyContext, shape: dict, features: dict) -> list[PartBuilder]:
    """Stable mesh boundaries allow outfits to replace cloth without replacing skin."""
    base_features = dict(features, outerwear="none", pauldrons=False)
    torso = build_torso(context, shape, base_features)
    torso.name = "Clothing_Torso"
    parts = [torso]
    if features["outerwear"] != "none":
        outerwear = PartBuilder("Clothing_Outerwear", context.frame, bulk=shape["bulk"])
        _add_outerwear(outerwear, context, shape, features["outerwear"])
        parts.append(outerwear)
    if features["pauldrons"]:
        armor = PartBuilder("Clothing_Armor", context.frame, bulk=shape["bulk"])
        _add_pauldrons(armor, context, features)
        parts.append(armor)
    return parts


def _apron_panel(
    part: PartBuilder, context: BodyContext, shape: dict,
    material: str = "leather", hem_fraction: float = 0.59,
) -> None:
    """A supported, curved leather panel; subdividing a single box made a diamond."""
    up, forward, left = context.frame.up, context.frame.forward, context.frame.left
    scale = context.scale
    sections = torso_profile(context, shape)
    rows = []
    # Top bib -> waist -> skirt. Closely spaced boundary rows preserve the cut
    # through subdivision, and spine/chest weights bend the bib with the wearer.
    top = context.chest_height + up * 0.11 * scale
    rows.extend([
        (top, .086 * shape["chest_breadth"], sections[4][2] + .033, {"chest": 1.0}),
        (top - up * .012 * scale, .087 * shape["chest_breadth"], sections[4][2] + .034, {"chest": 1.0}),
        (context.chest_height, .103 * shape["chest_breadth"], sections[4][2] + .035, blend_weights("spine", "chest", .65)),
        (context.waist, .122 * shape["belly"], sections[2][2] + .040, blend_weights("hips", "spine", .7)),
        (context.hips + up * .025 * scale, .140 * shape["belly"], sections[1][2] + .037, {"hips": 1.0}),
        (context.hips - up * .05 * scale, .147 * shape["belly"], sections[1][2] + .039, {"hips": 1.0}),
        (context.hips.lerp(context.knee_center, hem_fraction * .68), .148 * shape["belly"], sections[1][2] + .044, {"hips": 1.0}),
        (context.hips.lerp(context.knee_center, hem_fraction - .02), .141 * shape["belly"], sections[1][2] + .045, {"hips": 1.0}),
        (context.hips.lerp(context.knee_center, hem_fraction), .138 * shape["belly"], sections[1][2] + .045, {"hips": 1.0}),
    ])
    across = [-1.0, -.94, -.66, -.33, 0.0, .33, .66, .94, 1.0]
    grids = []
    for back in (False, True):
        grid = []
        for row, (center, width, depth, weights) in enumerate(rows):
            strip = []
            for x in across:
                # Gentle drape and two broad folds, not a board or micro noise.
                fold = .005 * math.cos(x * math.pi * 3) * min(row / 4, 1.0)
                point = center + left * x * width * scale
                point += forward * (depth * shape["bulk"] - .025 * x*x + fold - (.004 if back else 0)) * scale
                strip.append(part._add_vertex(point, weights))
            grid.append(strip)
        grids.append(grid)
    def face(indices, surface_material=material):
        part.faces.append(tuple(indices))
        part.face_materials.append(surface_material)
    for side, grid in enumerate(grids):
        for y in range(len(rows)-1):
            for x in range(len(across)-1):
                quad = [grid[y][x], grid[y][x+1], grid[y+1][x+1], grid[y+1][x]]
                face(quad if side == 0 else quad[::-1], "trim" if x in (0, len(across)-2) or y == len(rows)-2 else material)
    a,b = grids
    for y in range(len(rows)-1):
        for x in (0,len(across)-1):
            face([a[y][x], a[y+1][x], b[y+1][x], b[y][x]])
    for y in (0,len(rows)-1):
        for x in range(len(across)-1):
            face([a[y][x], b[y][x], b[y][x+1], a[y][x+1]])
    # Existing leather straps, with close support rings to retain their width.
    for side in (-1,1):
        part.start_tube()
        for center in (top - up * .015 * scale, top, context.shoulder_line, context.shoulder_line + up * .012 * scale):
            part.ring(center + left * side * .071 * scale + forward * (sections[4][2]+.045) * scale,
                      up, .012*scale, .005*scale, {"chest":1.0}, "trim")


def build_torso(context: BodyContext, shape: dict, features: dict) -> PartBuilder:
    frame = context.frame
    up, forward, left = frame.up, frame.forward, frame.left
    scale = context.scale
    hips = context.hips
    neck_base = context.neck_base
    shoulder_line = context.shoulder_line
    belly = shape["belly"]
    chest_breadth = shape["chest_breadth"]

    torso = PartBuilder("Hero_Torso", frame, bulk=shape["bulk"])
    if features["anatomical_layers"]:
        # The anatomical builder owns skin and limbs. This builder contributes
        # only fitted torso clothing and role-specific outerwear above it.
        _add_anatomical_clothing(torso, context, shape, features)
        _add_outerwear(torso, context, shape, features["outerwear"])
        _add_pauldrons(torso, context, features)
        return torso
    torso.start_tube()
    # Pelvis cap; hidden under a long tunic skirt, visible with a short one.
    torso.ring(
        context.crotch,
        up,
        0.095 * scale * belly,
        0.078 * scale * belly,
        {"hips": 1.0},
        "pants",
    )
    torso.cap(context.crotch - up * 0.005 * scale, {"hips": 1.0}, "pants")
    torso.start_tube()
    if features["tunic_length"] == "long":
        # Long tunic hem flares over the thighs like the legacy sprite silhouette.
        torso.ring(
            context.knee_center + up * 0.04 * scale,
            up,
            0.175 * scale,
            0.108 * scale,
            {"hips": 1.0},
            "tunic",
        )
        torso.ring(
            context.mid_thigh,
            up,
            0.160 * scale,
            0.112 * scale,
            {"hips": 1.0},
            "tunic",
        )
    else:
        # Short tunic ends in a hip-length hem; the thighs stay pants-covered.
        torso.ring(
            hips - up * 0.10 * scale,
            up,
            0.152 * scale * belly,
            0.112 * scale * belly,
            {"hips": 1.0},
            "tunic",
        )
    torso.ring(
        hips - up * 0.03 * scale,
        up,
        0.143 * scale * belly,
        0.104 * scale * belly,
        {"hips": 1.0},
        "tunic",
    )
    torso.ring(
        hips + up * 0.02,
        up,
        0.130 * scale * belly,
        0.100 * scale * belly,
        {"hips": 1.0},
        "belt",
    )
    torso.ring(
        context.waist,
        up,
        0.118 * scale * belly,
        0.092 * scale * belly,
        blend_weights("hips", "spine", 0.5),
        "tunic",
    )
    torso.ring(
        context.chest_height,
        up,
        0.172 * scale * chest_breadth,
        0.110 * scale,
        blend_weights("spine", "chest", 0.6),
        "tunic",
    )
    torso.ring(
        shoulder_line,
        up,
        0.196 * scale * chest_breadth,
        0.104 * scale,
        {"chest": 1.0},
        "tunic",
    )
    torso.ring(
        neck_base,
        up,
        0.062 * scale,
        0.056 * scale,
        {"chest": 1.0},
        "tunic",
    )
    torso.cap(neck_base + up * 0.02, {"chest": 1.0}, "tunic")

    _add_outerwear(torso, context, shape, features["outerwear"])

    # Deltoid bulges follow the upper arm so the shoulder joint stays covered
    # when the arms swing.
    for suffix, shoulder in (("l", context.shoulder_l), ("r", context.shoulder_r)):
        torso.uv_sphere(
            shoulder + up * 0.012 * scale,
            Vector((0.082 * scale, 0.074 * scale, 0.078 * scale)),
            {f"upperarm.{suffix}": 1.0},
            "tunic",
            rings=9,
        )
    _add_pauldrons(torso, context, features)
    return torso


def _add_pauldrons(
    torso: PartBuilder, context: BodyContext, features: dict
) -> None:
    """Flattened steel domes riding the deltoids.

    Rank armour has to survive on the anatomical bodies too - it used to be
    reachable only on the legacy path, so captains and sergeants shipped
    without the plates their specs ask for.
    """
    if not features["pauldrons"]:
        return
    up = context.frame.up
    scale = context.scale
    for suffix, shoulder in (("l", context.shoulder_l), ("r", context.shoulder_r)):
        outward = shoulder - context.neck_base
        outward -= up * outward.dot(up)
        outward = outward.normalized()
        torso.uv_sphere(
            shoulder + up * 0.034 * scale + outward * 0.028 * scale,
            Vector((0.096 * scale, 0.082 * scale, 0.056 * scale)),
            {f"upperarm.{suffix}": 1.0},
            "armor",
            rings=9,
        )


def _add_anatomical_clothing(
    torso: PartBuilder, context: BodyContext, shape: dict, features: dict
) -> None:
    """Build a fitted tunic or mail shell outside the anatomical skin.

    A small radial clearance prevents z-fighting while preserving ribcage,
    waist, and pelvic landmarks. Profession/rank outerwear is added afterward
    by the existing role-specific builder, keeping clothing independent from
    the body envelope.
    """
    up = context.frame.up
    scale = context.scale
    belly = shape["belly"]
    material = "mail" if features["armor_style"] == "mail" else "tunic"
    # Worn clearance over the skin envelope. Cloth follows the body it covers -
    # including the shoulder girdle - because both read the same profile.
    clearance = 0.011

    torso.start_tube()
    if features["tunic_length"] == "long":
        torso.ring(
            context.knee_center + up * 0.04 * scale,
            up,
            0.168 * scale,
            0.111 * scale,
            {"hips": 1.0},
            material,
        )
        torso.ring(
            context.mid_thigh,
            up,
            0.157 * scale,
            0.113 * scale,
            {"hips": 1.0},
            material,
        )
    else:
        torso.ring(
            context.hips - up * 0.13 * scale,
            up,
            0.151 * scale * belly,
            0.111 * scale * belly,
            {"hips": 1.0},
            material,
        )
        # Bound hem edging: the bridge between this ring and the next reads as
        # a narrow trim band, so the tunic ends in a finished edge instead of
        # a cut tube.
        torso.ring(
            context.hips - up * 0.118 * scale,
            up,
            (0.150 * belly + 0.002) * scale,
            (0.110 * belly + 0.002) * scale,
            {"hips": 1.0},
            "trim",
        )
    # Skip the profile's crotch section: the hem above already closes the
    # garment below the hips, and the pelvis belongs to the skin layer.
    for index, (center, side_radius, front_radius, back_radius, weights) in enumerate(
        torso_profile(context, shape)[1:]
    ):
        torso.ring(
            center,
            up,
            (side_radius + clearance) * scale,
            (front_radius + clearance) * scale,
            weights,
            material,
            radius_back=(back_radius + clearance) * scale,
        )
        if index == 0:
            # Belt sits on the pelvis, breaking the tunic's vertical run and
            # marking the waist that the outerwear and pouches hang from.
            torso.ring(
                context.hips + up * 0.022 * scale,
                up,
                (0.140 * belly + clearance) * scale,
                (0.100 * belly + clearance) * scale,
                {"hips": 1.0},
                "belt",
                radius_back=(0.124 * belly + clearance) * scale,
            )
    torso.cap(context.neck_base + up * 0.038 * scale, {"chest": 1.0}, material)

    # Collar edging: a trim band around the neck opening. Without it the tunic
    # ends as a bare tube intersection against the neck skin.
    neck_section = torso_profile(context, shape)[-1]
    collar_clearance = clearance + 0.005
    torso.start_tube()
    torso.ring(
        neck_section[0] - up * 0.004 * scale,
        up,
        (neck_section[1] + collar_clearance) * scale,
        (neck_section[2] + collar_clearance) * scale,
        {"chest": 1.0},
        "trim",
        radius_back=(neck_section[3] + collar_clearance) * scale,
    )
    torso.cap(neck_section[0] + up * 0.006 * scale, {"chest": 1.0}, "trim")


def _worn_depth(context: BodyContext, shape: dict, section: int) -> float:
    """Front depth of the outermost worn layer at one torso section.

    Outerwear panels are flat boxes; they only read as clothing if they clear
    the tunic beneath them by roughly their own thickness, whatever girth the
    spec asks for.
    """
    return torso_profile(context, shape)[section][2] + 0.020


def _add_outerwear(
    torso: PartBuilder, context: BodyContext, shape: dict, style: str
) -> None:
    """Add role-specific clothing as skinned geometry on the shared body.

    These layers are intentionally generated into each named character GLB:
    their proportions and weights therefore follow that body's skeleton in
    locomotion, combat and social animations instead of floating as props.
    """
    if style == "none":
        return

    frame = context.frame
    up, forward, left = frame.up, frame.forward, frame.left
    scale = context.scale
    belly = shape["belly"]
    chest_breadth = shape["chest_breadth"]
    # Where the outermost worn layer sits at each landmark. Measured from the
    # body profile rather than assumed: a fixed depth buried the innkeeper's
    # apron inside his own belly.
    hip_front = _worn_depth(context, shape, 1)
    chest_front = _worn_depth(context, shape, 4)
    shoulder_front = _worn_depth(context, shape, 6)

    if style == "apron":
        _apron_panel(torso, context, shape)
        return

    if style in ("vest", "surcoat"):
        # Sleeveless wool/leather layer. The centre opening and edging create a
        # readable garment rather than another uniformly coloured torso shell.
        # Worn over the tunic on the same profile, so it reads as a garment on
        # a body from every angle - authored radii used to leave the front of
        # the vest sunk inside the tunic while its sides stuck out.
        sections = torso_profile(context, shape)
        outer = 0.022
        torso.start_tube()
        hem_height = context.hips - up * (0.10 if style == "vest" else 0.22) * scale
        torso.ring(
            hem_height,
            up,
            (0.151 * belly + outer) * scale,
            (0.113 * belly + outer) * scale,
            {"hips": 1.0},
            "outerwear",
            radius_back=(0.125 * belly + outer) * scale,
        )
        for center, side_radius, front_radius, back_radius, weights in sections[1:6]:
            torso.ring(
                center,
                up,
                (side_radius + outer) * scale,
                (front_radius + outer) * scale,
                weights,
                "outerwear",
                radius_back=(back_radius + outer) * scale,
            )
        # A sleeveless layer stops at the collarbone with a wide neck opening.
        torso.ring(
            context.neck_base - up * 0.035 * scale,
            up,
            0.086 * scale,
            0.078 * scale,
            {"chest": 1.0},
            "outerwear",
        )
        torso.cap(context.neck_base - up * 0.01 * scale, {"chest": 1.0}, "outerwear")
        trim_center = (
            context.hips.lerp(context.shoulder_line, 0.55)
            + forward * (chest_front + outer) * scale
        )
        for side in (-1.0, 1.0):
            torso.box(
                trim_center + left * side * 0.018 * scale,
                left * 0.008 * scale,
                forward * 0.008 * scale,
                up * 0.285 * scale,
                blend_weights("spine", "chest", 0.5),
                "trim",
            )
        if style == "surcoat":
            torso.box(
                context.hips + up * 0.025 * scale + forward * (hip_front + outer) * scale,
                left * 0.158 * scale,
                forward * 0.014 * scale,
                up * 0.026 * scale,
                {"hips": 1.0},
                "trim",
            )
        return

    if style == "kirtle":
        # Use the same supported cloth cut as the work apron rather than
        # subdivided boxes that collapse into detached diamond-shaped patches.
        _apron_panel(torso, context, shape, material="outerwear", hem_fraction=0.90)
