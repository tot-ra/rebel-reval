#!/usr/bin/env python3
"""Unit tests for fauna GLB PBR inspection (P0-160)."""

from __future__ import annotations

import json
import struct
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / "tools"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

from fauna_glb_inspect import inspect_fauna_glb, validate_fauna_glb_pbr  # noqa: E402


def _write_minimal_glb(
    path: Path,
    *,
    with_normal: bool = True,
    with_roughness: bool = True,
) -> None:
    images = [{"bufferView": 0, "mimeType": "image/png", "name": "albedo"}]
    textures = [{"source": 0}]
    material = {
        "name": "body",
        "pbrMetallicRoughness": {"baseColorTexture": {"index": 0}, "metallicFactor": 0.0},
    }
    if with_normal:
        images.append({"bufferView": 1, "mimeType": "image/png", "name": "normal"})
        textures.append({"source": 1})
        material["normalTexture"] = {"index": 1}
    if with_roughness:
        images.append({"bufferView": 2, "mimeType": "image/png", "name": "roughness"})
        textures.append({"source": 2})
        material["pbrMetallicRoughness"]["metallicRoughnessTexture"] = {"index": 2}

  # 1x1 RGBA PNG
    png = (
        b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01"
        b"\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\nIDATx\x9cc\x00\x01"
        b"\x00\x00\x05\x00\x01\r\n-\xb4\x00\x00\x00\x00IEND\xaeB`\x82"
    )
    buffer_views = []
    bin_chunks = b""
    for index, _ in enumerate(images):
        buffer_views.append(
            {
                "buffer": 0,
                "byteOffset": len(bin_chunks),
                "byteLength": len(png),
            }
        )
        bin_chunks += png

    document = {
        "asset": {"version": "2.0"},
        "buffers": [{"byteLength": len(bin_chunks)}],
        "bufferViews": buffer_views,
        "images": images,
        "textures": textures,
        "materials": [material],
        "meshes": [
            {
                "primitives": [
                    {
                        "attributes": {"POSITION": 0},
                        "indices": 1,
                        "material": 0,
                    }
                ]
            }
        ],
        "accessors": [
            {
                "bufferView": len(buffer_views),
                "componentType": 5126,
                "count": 3,
                "type": "VEC3",
                "max": [1.0, 1.0, 1.0],
                "min": [0.0, 0.0, 0.0],
            },
            {
                "bufferView": len(buffer_views) + 1,
                "componentType": 5123,
                "count": 3,
                "type": "SCALAR",
            },
        ],
    }
    # Minimal geometry chunk appended after image bytes.
    positions = struct.pack("<9f", 0, 0, 0, 1, 0, 0, 0, 1, 0)
    indices = struct.pack("<3H", 0, 1, 2)
    pos_view = {"buffer": 0, "byteOffset": len(bin_chunks), "byteLength": len(positions)}
    bin_chunks += positions
    idx_view = {"buffer": 0, "byteOffset": len(bin_chunks), "byteLength": len(indices)}
    bin_chunks += indices
    document["bufferViews"].extend([pos_view, idx_view])
    document["buffers"][0]["byteLength"] = len(bin_chunks)

    json_bytes = json.dumps(document).encode("utf-8")
    json_pad = (4 - (len(json_bytes) % 4)) % 4
    json_bytes += b" " * json_pad
    bin_pad = (4 - (len(bin_chunks) % 4)) % 4
    bin_chunks += b"\x00" * bin_pad

    glb = b"glTF" + struct.pack("<I", 2)
    glb += struct.pack("<I", 12 + 8 + len(json_bytes) + 8 + len(bin_chunks))
    glb += struct.pack("<I", len(json_bytes)) + b"JSON" + json_bytes
    glb += struct.pack("<I", len(bin_chunks)) + b"BIN\x00" + bin_chunks
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(glb)


class FaunaGlbInspectTests(unittest.TestCase):
    def test_complete_contract_passes(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            glb = root / "assets/birds/mallard/standing.glb"
            _write_minimal_glb(glb)
            self.assertEqual(inspect_fauna_glb(glb), [])
            self.assertEqual(validate_fauna_glb_pbr(root=root), [])

    def test_missing_roughness_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            glb = root / "assets/birds/mallard/standing.glb"
            _write_minimal_glb(glb, with_roughness=False)
            errors = validate_fauna_glb_pbr(root=root)
            self.assertEqual(len(errors), 1)
            self.assertIn("missing metallicRoughnessTexture", errors[0])


if __name__ == "__main__":
    unittest.main()
