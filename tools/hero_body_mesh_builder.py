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

# Ring density per tube cross-section. 24 keeps limb and tunic silhouettes
# round at portrait distance; combined with smooth shading (build() sets
# use_smooth on every polygon) and one Catmull-Clark subdivision applied at
# build time the body no longer reads as faceted low-poly.
RING_SEGMENTS = 24

# Applying one subdivision level pulls box corners toward the limit surface;
# box() pre-scales its axes by this factor so hands, boots, and face features
# keep their authored footprint while gaining rounded corners.
BOX_SUBDIVISION_COMPENSATION = 1.22


def find_armature() -> bpy.types.Object:
    for obj in bpy.data.objects:
        if obj.type == "ARMATURE":
            return obj
    raise RuntimeError("no armature in imported scene")


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
        self, name: str, frame: Frame, bulk: float = 1.0, subdivision: int = 1
    ) -> None:
        self.name = name
        self.frame = frame
        self.bulk = bulk
        self.subdivision = subdivision
        self.vertices: list[Vector] = []
        self.weights: list[dict[str, float]] = []
        self.faces: list[tuple[int, ...]] = []
        self.face_materials: list[str] = []
        self._last_ring: list[int] | None = None
        self._last_ring_material: str | None = None

    def _add_vertex(self, position: Vector, weights: dict[str, float]) -> int:
        self.vertices.append(position)
        self.weights.append(weights)
        return len(self.vertices) - 1

    def start_tube(self) -> None:
        self._last_ring = None
        self._last_ring_material = None

    def ring(
        self,
        center: Vector,
        axis: Vector,
        radius_side: float,
        radius_forward: float,
        weights: dict[str, float],
        material: str,
    ) -> list[int]:
        side, forward = self.frame.basis_for(axis.normalized())
        radius_side *= self.bulk
        radius_forward *= self.bulk
        indices: list[int] = []
        for step in range(RING_SEGMENTS):
            angle = math.tau * step / RING_SEGMENTS
            offset = side * (math.cos(angle) * radius_side)
            offset += forward * (math.sin(angle) * radius_forward)
            indices.append(self._add_vertex(center + offset, weights))
        if self._last_ring is not None:
            for step in range(RING_SEGMENTS):
                next_step = (step + 1) % RING_SEGMENTS
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

    def cap(self, center: Vector, weights: dict[str, float], material: str) -> None:
        if self._last_ring is None:
            return
        apex = self._add_vertex(center, weights)
        for step in range(RING_SEGMENTS):
            next_step = (step + 1) % RING_SEGMENTS
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
            )
            if first:
                apex = self._add_vertex(bottom, weights)
                for step in range(RING_SEGMENTS):
                    next_step = (step + 1) % RING_SEGMENTS
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

        modifier = obj.modifiers.new("Armature", "ARMATURE")
        modifier.object = armature
        obj.parent = armature

        # Consistent outward normals.
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.mesh.normals_make_consistent(inside=False)
        bpy.ops.object.mode_set(mode="OBJECT")
        return obj
