#!/usr/bin/env python3
"""Tests for shared character texture URIs and distinct-map preservation."""

from __future__ import annotations

import hashlib
import struct
import sys
import tempfile
import unittest
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / "tools"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

from share_character_textures import (  # noqa: E402
    apply_repository,
    canonical_stem,
    link_glb_to_shared_textures,
    parse_glb,
    verify_repository,
    write_glb,
)


def _png(width: int, height: int, rgb: tuple[int, int, int]) -> bytes:
    def chunk(chunk_type: bytes, data: bytes) -> bytes:
        return (
            struct.pack(">I", len(data))
            + chunk_type
            + data
            + struct.pack(">I", zlib.crc32(chunk_type + data) & 0xFFFFFFFF)
        )

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    raw = b"".join(b"\x00" + (bytes(rgb) * width) for _ in range(height))
    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", ihdr)
        + chunk(b"IDAT", zlib.compress(raw, 9))
        + chunk(b"IEND", b"")
    )


def _write_glb_with_image(path: Path, image_name: str, png: bytes, mesh_pad: bytes) -> None:
    image_offset = len(mesh_pad)
    bin_chunk = mesh_pad + png
    document = {
        "asset": {"version": "2.0"},
        "buffers": [{"byteLength": len(bin_chunk)}],
        "bufferViews": [
            {"buffer": 0, "byteOffset": 0, "byteLength": len(mesh_pad)},
            {"buffer": 0, "byteOffset": image_offset, "byteLength": len(png)},
        ],
        "accessors": [
            {
                "bufferView": 0,
                "componentType": 5126,
                "count": 3,
                "type": "VEC3",
            }
        ],
        "images": [
            {
                "bufferView": 1,
                "mimeType": "image/png",
                "name": image_name,
            }
        ],
        "textures": [{"source": 0}],
        "materials": [
            {
                "name": "hero_tunic",
                "pbrMetallicRoughness": {
                    "baseColorFactor": [0.4, 0.2, 0.1, 1.0],
                    "baseColorTexture": {"index": 0},
                },
            }
        ],
        "meshes": [{"primitives": [{"attributes": {"POSITION": 0}, "material": 0}]}],
    }
    write_glb(path, document, bin_chunk)


class ShareCharacterTexturesTest(unittest.TestCase):
    def test_canonical_stem_strips_body_prefix(self) -> None:
        self.assertEqual(canonical_stem("hero_tex_cloth_albedo"), "hero_tex_cloth_albedo")
        self.assertEqual(
            canonical_stem("aita_hero_tex_cloth_ao-hero_tex_cloth_roughness"),
            "hero_tex_cloth_ao-hero_tex_cloth_roughness",
        )
        self.assertIsNone(canonical_stem("barbarian_texture"))

    def test_apply_rewrites_identical_embeds_and_keeps_distinct_maps(self) -> None:
        shared_png = _png(4, 4, (200, 180, 160))
        distinct_png = _png(4, 4, (10, 20, 30))
        pad = b"\x00" * 64
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            shared = root / "assets" / "characters" / "shared"
            shared.mkdir(parents=True)
            body_a = shared / "hero.glb"
            body_b = shared / "mart.glb"
            unique = shared / "odd.glb"
            _write_glb_with_image(body_a, "hero_tex_skin_albedo", shared_png, pad)
            _write_glb_with_image(body_b, "hero_tex_skin_albedo", shared_png, pad)
            _write_glb_with_image(unique, "hero_tex_skin_albedo", distinct_png, pad)
            # Two bodies share bytes; the third is a distinct AO/albedo and must
            # stay embedded so a later import cannot flatten unique maps.
            # Harvest sees a conflict on this stem, so nothing is shared.
            result = apply_repository(root=root, prune=True)
            self.assertEqual(result["conflicts"], 1)
            self.assertEqual(result["canonical"], 0)
            for glb in (body_a, body_b, unique):
                gltf, _bin = parse_glb(glb)
                self.assertIn("bufferView", gltf["images"][0])

            # Same bytes across bodies: share and prune extracted copies.
            unique.unlink()
            extracted = shared / "hero_hero_tex_skin_albedo.png"
            extracted.write_bytes(shared_png)
            extracted.with_suffix(".png.import").write_text("x", encoding="utf-8")
            result = apply_repository(root=root, prune=True)
            self.assertEqual(result["conflicts"], 0)
            self.assertEqual(result["canonical"], 1)
            self.assertFalse(extracted.is_file())
            canonical = shared / "textures" / "hero_tex_skin_albedo.png"
            self.assertTrue(canonical.is_file())
            self.assertEqual(hashlib.sha256(canonical.read_bytes()).digest(), hashlib.sha256(shared_png).digest())
            for glb in (body_a, body_b):
                gltf, bin_data = parse_glb(glb)
                image = gltf["images"][0]
                self.assertEqual(image["uri"], "textures/hero_tex_skin_albedo.png")
                self.assertNotIn("bufferView", image)
                self.assertEqual(gltf["accessors"][0]["bufferView"], 0)
                view = gltf["bufferViews"][0]
                self.assertEqual(bin_data[view["byteOffset"] : view["byteOffset"] + view["byteLength"]], pad)
            self.assertEqual(verify_repository(root=root), [])

    def test_link_is_idempotent(self) -> None:
        png = _png(2, 2, (128, 128, 128))
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "body.glb"
            _write_glb_with_image(path, "hero_tex_cloth_normal", png, b"\x01" * 32)
            textures = Path(tmp) / "textures"
            textures.mkdir()
            (textures / "hero_tex_cloth_normal.png").write_bytes(png)
            first = link_glb_to_shared_textures(path, payloads={"hero_tex_cloth_normal": png})
            second = link_glb_to_shared_textures(path, payloads={"hero_tex_cloth_normal": png})
            self.assertEqual(first["linked"], 1)
            self.assertEqual(second["already"], 1)
            self.assertEqual(second["linked"], 0)


if __name__ == "__main__":
    unittest.main()
