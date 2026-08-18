#!/usr/bin/env python3
"""Orientation contract for the domestic fowl gait GLBs.

Godot turns ambient actors with `look_at`, so a walking bird travels along its
own -Z. The reviewed source meshes do not satisfy that on their own: both fowl
were authored facing +Z and the greylag goose is stored upside down.
`tools/assets/build_bird_gaits.py` bakes the corrective rotation, and these
checks keep a rebuild from silently shipping a bird that walks backwards or
stands on its head again.
"""

from __future__ import annotations

import json
import struct
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

GAIT_MODELS = {
    "chicken": ROOT / "assets" / "birds" / "chicken" / "walking.glb",
    "mallard": ROOT / "assets" / "birds" / "mallard" / "walking.glb",
    "greylag_goose": ROOT / "assets" / "birds" / "greylag_goose" / "walking.glb",
}
# Authored leg/foot material slots, used to prove the bird is not standing on its
# head. The hen ships a single merged material and therefore has no entry here.
FOOT_MATERIALS = {
    "mallard": ("mallard_feet",),
    "greylag_goose": ("greylag_goose_leg", "greylag_goose_foot"),
}
COMPONENT_FORMATS = {5120: "b", 5121: "B", 5122: "h", 5123: "H", 5125: "I", 5126: "f"}
TYPE_COUNTS = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}
# Share of the tallest vertices treated as "the head end" of the bird.
HEAD_SAMPLE_SHARE = 0.05


def _load_glb(path: Path) -> tuple[dict, bytes, int]:
    payload = path.read_bytes()
    if payload[:4] != b"glTF":
        raise ValueError(f"{path}: not a binary glTF file")
    offset = 12
    document: dict | None = None
    binary_start = 0
    while offset + 8 <= len(payload):
        length, kind = struct.unpack_from("<II", payload, offset)
        body = offset + 8
        if kind == 0x4E4F534A:
            document = json.loads(payload[body : body + length])
        elif kind == 0x004E4942:
            binary_start = body
        offset = body + length
    if document is None:
        raise ValueError(f"{path}: missing JSON chunk")
    return document, payload, binary_start


def _read_positions(document: dict, payload: bytes, binary_start: int, accessor_index: int):
    accessor = document["accessors"][accessor_index]
    view = document["bufferViews"][accessor["bufferView"]]
    component = COMPONENT_FORMATS[accessor["componentType"]]
    count = TYPE_COUNTS[accessor["type"]]
    offset = binary_start + view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
    values = struct.unpack_from("<" + component * accessor["count"] * count, payload, offset)
    return [values[index : index + count] for index in range(0, len(values), count)]


def _vertices(path: Path) -> list[tuple[float, float, float]]:
    document, payload, binary_start = _load_glb(path)
    points: list[tuple[float, float, float]] = []
    for mesh in document["meshes"]:
        for primitive in mesh["primitives"]:
            points.extend(
                _read_positions(document, payload, binary_start, primitive["attributes"]["POSITION"])
            )
    return points


def _material_heights(path: Path, material_names: tuple) -> list[float]:
    document, payload, binary_start = _load_glb(path)
    wanted = {
        index
        for index, material in enumerate(document.get("materials", []))
        if material.get("name") in material_names
    }
    heights: list[float] = []
    for mesh in document["meshes"]:
        for primitive in mesh["primitives"]:
            if primitive.get("material") not in wanted:
                continue
            heights.extend(
                point[1]
                for point in _read_positions(
                    document, payload, binary_start, primitive["attributes"]["POSITION"]
                )
            )
    return heights


class BirdGaitOrientationTest(unittest.TestCase):
    def test_gait_models_stand_on_the_ground_plane(self) -> None:
        for species, path in GAIT_MODELS.items():
            with self.subTest(species=species):
                self.assertTrue(path.exists(), f"{species} gait model is missing")
                heights = [point[1] for point in _vertices(path)]
                self.assertAlmostEqual(
                    min(heights),
                    0.0,
                    places=3,
                    msg=f"{species} feet must rest on Y=0",
                )
                self.assertGreater(max(heights), 0.1, f"{species} must have vertical extent")

    def test_gait_models_face_the_godot_walk_direction(self) -> None:
        # A standing bird carries its head above everything else, so the tallest
        # vertices identify the head end without needing per-species materials.
        for species, path in GAIT_MODELS.items():
            with self.subTest(species=species):
                points = sorted(_vertices(path), key=lambda point: point[1], reverse=True)
                sample = points[: max(1, int(len(points) * HEAD_SAMPLE_SHARE))]
                head_z = sum(point[2] for point in sample) / len(sample)
                self.assertLess(
                    head_z,
                    0.0,
                    f"{species} head must point along -Z or the bird walks backwards",
                )

    def test_authored_feet_stay_under_the_body(self) -> None:
        # The facing check alone cannot see an upside-down bird, because the feet
        # then sit where the head belongs. Anchor on the authored foot slots.
        for species, material_names in FOOT_MATERIALS.items():
            with self.subTest(species=species):
                path = GAIT_MODELS[species]
                model_top = max(point[1] for point in _vertices(path))
                foot_heights = _material_heights(path, material_names)
                self.assertTrue(foot_heights, f"{species} foot material slot is missing")
                self.assertLess(
                    max(foot_heights),
                    model_top * 0.4,
                    f"{species} feet must stay in the lower body, not above it",
                )

    def test_gait_reports_record_the_applied_orientation(self) -> None:
        reports = ROOT / "generated" / "bird_gaits_v1" / "reports"
        for species in GAIT_MODELS:
            with self.subTest(species=species):
                report = json.loads((reports / f"{species}.json").read_text(encoding="utf-8"))
                self.assertTrue(report["faces_gltf_minus_z"])
                self.assertIn(report["orient_axis"], {"X", "Y", "Z"})
                for count in report["leg_vertex_counts"].values():
                    self.assertGreaterEqual(count, 8, f"{species} leg bones need real weights")


if __name__ == "__main__":
    unittest.main()
