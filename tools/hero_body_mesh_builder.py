"""Low-level mesh primitives for generated hero body builders.

Keeps ring-loop tube geometry and skeleton frame math separate from the
character-specific assembly in the focused torso, head, limb, and garment
modules.
"""

from __future__ import annotations

import math
from collections.abc import Callable
from typing import TYPE_CHECKING

import bpy
from mathutils import Vector

if TYPE_CHECKING:
    pass

# Ring density per tube cross-section. 20 keeps limb and tunic silhouettes
# round at portrait distance; combined with smooth shading (build() sets
# use_smooth on every polygon) and one Catmull-Clark subdivision applied at
# build time the body no longer reads as faceted low-poly. It is also the
# headroom lever for the ADR 0016 tier budgets: the P0-144/P0-145 detail pass
# (sideburns, nape, nostrils, moustache, collar/hem trim) added ~8k tris per
# body, and 20 segments returns every spec under its frozen cap.
RING_SEGMENTS = 20

# Applying one subdivision level pulls box corners toward the limit surface;
# box() pre-scales its axes by this factor so hands, boots, and face features
# keep their authored footprint while gaining rounded corners.
BOX_SUBDIVISION_COMPENSATION = 1.22


def find_armature() -> bpy.types.Object:
    for obj in bpy.data.objects:
        if obj.type == "ARMATURE":
            return obj
    raise RuntimeError("no armature in imported scene")


# Materials whose corners receive a vertex tint. Skin takes the complexion
# zoning; hair and beard take a fibre breakup, without which a single flat
# colour over a smooth shell reads as painted wood. Eyes and lips stay flat.
VERTEX_TINT_MATERIALS = {"skin", "hair", "beard"}


# Colour attribute the head's tints are painted into. Blender's glTF exporter
# writes every colour attribute of a mesh to every primitive, so one shared
# layer is enough; see _promote_vertex_colors in generate_hero_body for why it
# still has to be moved into COLOR_0 afterwards.
TINT_LAYER = "Color"


def _apply_vertex_colors(
    obj: bpy.types.Object,
    material_names: list[str],
    tint_fn: Callable[[Vector, str], tuple],
) -> None:
    """Paint per-vertex RGBA tints on the final (subdivided) mesh.

    Deterministic: the tint is a pure function of vertex position, evaluated
    after the subdivision apply. Multiplied into the albedo by the material's
    Color Attribute node (see _wire_vertex_tint in generate_hero_body), so spec
    palettes keep working unchanged - white means "no change".
    """
    mesh = obj.data
    # POINT, not CORNER: the tint is a pure function of position, so per-vertex
    # is both correct and cheaper than per-corner.
    attribute = mesh.color_attributes.new(TINT_LAYER, "BYTE_COLOR", "POINT")
    mesh.color_attributes.active_color = attribute
    white = (1.0, 1.0, 1.0, 1.0)
    # A vertex can be shared by polygons of different materials (skin meets
    # hair along the hairline); the first tinted material touching it wins,
    # which keeps the seam continuous.
    owner: dict[int, str] = {}
    for polygon in mesh.polygons:
        material = (
            material_names[polygon.material_index]
            if polygon.material_index < len(material_names)
            else ""
        )
        if material not in VERTEX_TINT_MATERIALS:
            continue
        for vertex_index in polygon.vertices:
            owner.setdefault(vertex_index, material)
    for vertex_index in range(len(mesh.vertices)):
        material = owner.get(vertex_index)
        attribute.data[vertex_index].color = (
            white
            if material is None
            else tint_fn(mesh.vertices[vertex_index].co, material)
        )


def bone_head(armature: bpy.types.Object, name: str) -> Vector:
    bone = armature.data.bones.get(name)
    if bone is None:
        raise RuntimeError(f"missing bone {name}")
    return bone.head_local.copy()


class Frame:
    """Orthonormal body frame derived from the skeleton itself."""

    def __init__(self, armature: bpy.types.Object) -> None:
        hips = bone_head(armature, "hips")
        head = bone_head(armature, "head")
        foot = bone_head(armature, "foot.l")
        toes = bone_head(armature, "toes.l")
        self.up = (head - hips).normalized()
        forward = toes - foot
        forward -= self.up * forward.dot(self.up)
        self.forward = forward.normalized()
        self.left = self.up.cross(self.forward).normalized()

    def basis_for(self, axis: Vector) -> tuple[Vector, Vector]:
        """Two directions spanning the plane perpendicular to axis."""
        reference = self.up if abs(axis.dot(self.up)) < 0.9 else self.forward
        side = axis.cross(reference).normalized()
        return side, axis.cross(side).normalized()


class PartBuilder:
    """Accumulates ring-loop tube geometry with per-vertex bone weights.

    `bulk` multiplies every ring radius (mass carriers: torso, limbs); parts
    whose size is governed separately (the head group) pass bulk 1.0.
    """

    def __init__(
        self,
        name: str,
        frame: Frame,
        bulk: float = 1.0,
        subdivision: int = 1,
        segments: int = RING_SEGMENTS,
    ) -> None:
        self.name = name
        self.frame = frame
        self.bulk = bulk
        self.subdivision = subdivision
        # Cross-section vertex count. Feature-heavy parts (the head) can drop
        # this to fund sculpted detail elsewhere under the tier triangle cap.
        self.segments = segments
        # Optional position -> RGBA tint hook evaluated on the final subdivided
        # mesh (CORNER domain, exported as COLOR_0). Faces use it for skin
        # complexion zoning; see hero_body_head_builder.
        self.vertex_color_fn: Callable[[Vector, str], tuple] | None = None
        self.vertices: list[Vector] = []
        self.weights: list[dict[str, float]] = []
        self.faces: list[tuple[int, ...]] = []
        self.face_materials: list[str] = []
        self._last_ring: list[int] | None = None
        self._last_ring_material: str | None = None
        self._last_basis: tuple[Vector, Vector] | None = None

    def _add_vertex(self, position: Vector, weights: dict[str, float]) -> int:
        self.vertices.append(position)
        self.weights.append(weights)
        return len(self.vertices) - 1

    def start_tube(self) -> None:
        self._last_ring = None
        self._last_ring_material = None
        self._last_basis = None

    def ring(
        self,
        center: Vector,
        axis: Vector,
        radius_side: float,
        radius_forward: float,
        weights: dict[str, float],
        material: str,
        radius_back: float | None = None,
    ) -> list[int]:
        """Add one cross-section, bridged to the previous ring of this tube.

        `radius_back` makes the section egg-shaped instead of elliptical: the
        posterior half uses its own depth. Bodies need this wherever front and
        back masses differ - buttocks, chest, calf, skull - and the section
        stays closed and smooth because both halves meet at zero offset on the
        side axis.
        """
        side, forward = self._section_basis(axis.normalized())
        radius_side *= self.bulk
        radius_forward *= self.bulk
        radius_back = radius_forward if radius_back is None else radius_back * self.bulk
        indices: list[int] = []
        for step in range(self.segments):
            angle = math.tau * step / self.segments
            depth = math.sin(angle)
            offset = side * (math.cos(angle) * radius_side)
            offset += forward * (depth * (radius_forward if depth >= 0.0 else radius_back))
            indices.append(self._add_vertex(center + offset, weights))
        if self._last_ring is not None:
            for step in range(self.segments):
                next_step = (step + 1) % self.segments
                self.faces.append(
                    (
                        self._last_ring[step],
                        self._last_ring[next_step],
                        indices[next_step],
                        indices[step],
                    )
                )
                self.face_materials.append(self._last_ring_material or material)
        self._last_ring = indices
        self._last_ring_material = material
        return indices

    def _section_basis(self, axis: Vector) -> tuple[Vector, Vector]:
        """Oriented cross-section basis: (side, depth), depth facing forward.

        `Frame.basis_for` fixes only the plane, not the sign, and for a
        vertical axis its second vector happens to point at the character's
        back - which silently mirrors every front/back radius. The first ring
        of a tube therefore aligns depth with the body's forward direction, and
        later rings follow the previous ring so a bending limb cannot twist.
        Both vectors flip together, so ring winding is preserved.
        """
        side, depth = self.frame.basis_for(axis)
        if self._last_basis is None:
            flip = depth.dot(self.frame.forward) < 0.0
        else:
            flip = depth.dot(self._last_basis[1]) < 0.0
        if flip:
            side, depth = -side, -depth
        self._last_basis = (side, depth)
        return side, depth

    def cap(self, center: Vector, weights: dict[str, float], material: str) -> None:
        if self._last_ring is None:
            return
        apex = self._add_vertex(center, weights)
        for step in range(self.segments):
            next_step = (step + 1) % self.segments
            self.faces.append((self._last_ring[step], self._last_ring[next_step], apex))
            self.face_materials.append(material)

    def box(
        self,
        center: Vector,
        axis_x: Vector,
        axis_y: Vector,
        axis_z: Vector,
        weights: dict[str, float],
        material: str,
    ) -> None:
        if self.subdivision > 0:
            axis_x = axis_x * BOX_SUBDIVISION_COMPENSATION
            axis_y = axis_y * BOX_SUBDIVISION_COMPENSATION
            axis_z = axis_z * BOX_SUBDIVISION_COMPENSATION
        corners = []
        for sx in (-1.0, 1.0):
            for sy in (-1.0, 1.0):
                for sz in (-1.0, 1.0):
                    corners.append(
                        self._add_vertex(
                            center + axis_x * sx + axis_y * sy + axis_z * sz, weights
                        )
                    )
        quads = [
            (0, 1, 3, 2),
            (6, 7, 5, 4),
            (0, 2, 6, 4),
            (5, 7, 3, 1),
            (2, 3, 7, 6),
            (4, 5, 1, 0),
        ]
        for quad in quads:
            self.faces.append(tuple(corners[i] for i in quad))
            self.face_materials.append(material)

    def uv_sphere(
        self,
        center: Vector,
        radius: Vector,
        weights: dict[str, float],
        material: str,
        rings: int = 7,
        radius_back: float | None = None,
    ) -> None:
        up, forward, _left = self.frame.up, self.frame.forward, self.frame.left
        self.start_tube()
        self.cap_pending = None
        bottom = center - up * radius.z
        top = center + up * radius.z
        first = True
        for ring_index in range(1, rings):
            polar = math.pi * ring_index / rings
            ring_radius = math.sin(polar)
            height = -math.cos(polar)
            ring_center = center + up * (height * radius.z)
            indices = self.ring(
                ring_center,
                up,
                radius.x * ring_radius,
                radius.y * ring_radius,
                weights,
                material,
                radius_back=None if radius_back is None else radius_back * ring_radius,
            )
            if first:
                apex = self._add_vertex(bottom, weights)
                for step in range(self.segments):
                    next_step = (step + 1) % self.segments
                    self.faces.append((indices[next_step], indices[step], apex))
                    self.face_materials.append(material)
                first = False
        self.cap(top, weights, material)

    def build(
        self,
        armature: bpy.types.Object,
        material_factory: Callable[[str], bpy.types.Material],
    ) -> bpy.types.Object:
        mesh = bpy.data.meshes.new(self.name)
        mesh.from_pydata([v[:] for v in self.vertices], [], self.faces)
        mesh.update()

        materials = sorted(set(self.face_materials))
        material_slots = {}
        for slot, material_name in enumerate(materials):
            mesh.materials.append(material_factory(material_name))
            material_slots[material_name] = slot
        for polygon, material_name in zip(mesh.polygons, self.face_materials):
            polygon.material_index = material_slots[material_name]
        for polygon in mesh.polygons:
            polygon.use_smooth = True

        obj = bpy.data.objects.new(self.name, mesh)
        bpy.context.scene.collection.objects.link(obj)

        groups: dict[str, bpy.types.VertexGroup] = {}
        for index, weight_map in enumerate(self.weights):
            for bone_name, weight in weight_map.items():
                if weight <= 0.0:
                    continue
                group = groups.get(bone_name)
                if group is None:
                    group = obj.vertex_groups.new(name=bone_name)
                    groups[bone_name] = group
                group.add([index], weight, "REPLACE")

        # One applied Catmull-Clark level rounds box corners and smooths the
        # sparse longitudinal rings. Applied after vertex groups exist (their
        # weights interpolate through the apply, so deterministic skinning
        # survives) and before the armature modifier joins the stack.
        if self.subdivision > 0:
            bpy.context.view_layer.objects.active = obj
            subsurf = obj.modifiers.new("Subsurf", "SUBSURF")
            subsurf.levels = self.subdivision
            bpy.ops.object.modifier_apply(modifier=subsurf.name)

        # UVs for the procedural PBR texture sets (P0-144): angle-based smart
        # projection gives every generated part deterministic islands without
        # hand-authored seams, so cloth/leather/skin/hair detail maps can
        # actually land on the mesh.
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.smart_project(
            angle_limit=math.radians(66.0), island_margin=0.02, area_weight=True
        )
        # Consistent outward normals.
        bpy.ops.mesh.normals_make_consistent(inside=False)
        bpy.ops.object.mode_set(mode="OBJECT")

        if self.vertex_color_fn is not None:
            _apply_vertex_colors(obj, materials, self.vertex_color_fn)

        modifier = obj.modifiers.new("Armature", "ARMATURE")
        modifier.object = armature
        obj.parent = armature
        return obj
