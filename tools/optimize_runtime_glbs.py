#!/usr/bin/env python3
"""P0-183 size pass: URI-reference sibling textures instead of embedding them.

The Sacred Grove oak shipped with four painted maps packed into the GLB BIN.
Godot already extracted those PNGs beside the model. Rewriting the GLB to
URI-reference the same files drops the mesh payload below the landmark cap
without changing triangle counts or silhouette.

Usage:
    python3 tools/optimize_runtime_glbs.py
    python3 tools/optimize_runtime_glbs.py --check
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TOOLS = Path(__file__).resolve().parent
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))
OAK_GLB = (
    ROOT
    / "assets"
    / "props"
    / "environment"
    / "sacred_grove_ancient_oak"
    / "sacred_grove_ancient_oak.glb"
)
# Godot extract names: {glb_stem}_{image_name}.png
OAK_IMAGE_FILES = {
    "ancient_oak_bark_albedo": "sacred_grove_ancient_oak_ancient_oak_bark_albedo.png",
    "ancient_oak_bark_normal": "sacred_grove_ancient_oak_ancient_oak_bark_normal.png",
    "ancient_oak_leaf_albedo": "sacred_grove_ancient_oak_ancient_oak_leaf_albedo.png",
    "ancient_oak_heartwood_albedo": "sacred_grove_ancient_oak_ancient_oak_heartwood_albedo.png",
}

from share_character_textures import (  # noqa: E402
    _buffer_view_users,
    _compact_bin,
    _image_bytes,
    parse_glb,
    write_glb,
)


def _image_key(name: str) -> str | None:
    lowered = name.strip()
    for key in OAK_IMAGE_FILES:
        if lowered == key or lowered.endswith(key):
            return key
    return None


def externalize_oak_images(path: Path = OAK_GLB) -> dict[str, int]:
    """Replace oak BIN embeds with sibling PNG URIs. Idempotent."""
    if not path.is_file():
        raise FileNotFoundError(path)
    gltf, bin_data = parse_glb(path)
    users = _buffer_view_users(gltf)
    drop_views: set[int] = set()
    linked = 0
    already = 0
    written = 0
    for image in gltf.get("images") or []:
        name = str(image.get("name") or "")
        key = _image_key(name)
        if key is None:
            continue
        uri = OAK_IMAGE_FILES[key]
        dest = path.parent / uri
        if image.get("uri") == uri and "bufferView" not in image:
            already += 1
            continue
        blob = _image_bytes(gltf, bin_data, image)
        if blob is None:
            if image.get("uri") == uri:
                already += 1
            continue
        if not dest.is_file():
            dest.write_bytes(blob)
            written += 1
        view_index = image.get("bufferView")
        mime = str(image.get("mimeType") or "image/png")
        image.clear()
        image["name"] = name or key
        image["uri"] = uri
        image["mimeType"] = mime
        linked += 1
        if view_index is not None:
            still_needed = False
            for owner_kind, owner_index in users.get(int(view_index), []):
                if owner_kind == "image":
                    other = gltf["images"][owner_index]
                    if "bufferView" in other:
                        still_needed = True
                        break
                else:
                    still_needed = True
                    break
            if not still_needed:
                drop_views.add(int(view_index))
    if linked:
        bin_data = _compact_bin(gltf, bin_data, drop_views)
        write_glb(path, gltf, bin_data)
    return {
        "linked": linked,
        "already": already,
        "written": written,
        "bytes": path.stat().st_size,
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
    }


def oak_has_embedded_maps(path: Path = OAK_GLB) -> bool:
    gltf, _bin = parse_glb(path)
    for image in gltf.get("images") or []:
        if _image_key(str(image.get("name") or "")) is None:
            continue
        if "bufferView" in image:
            return True
        uri = image.get("uri")
        key = _image_key(str(image.get("name") or ""))
        if key and uri != OAK_IMAGE_FILES[key]:
            return True
    return False


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="exit 1 when the oak GLB still embeds its painted maps",
    )
    args = parser.parse_args(argv)
    if not OAK_GLB.is_file():
        print(f"missing {OAK_GLB.relative_to(ROOT).as_posix()}", file=sys.stderr)
        return 1
    if args.check:
        if oak_has_embedded_maps(OAK_GLB):
            print(
                "sacred grove oak still embeds painted maps; "
                "run python3 tools/optimize_runtime_glbs.py",
                file=sys.stderr,
            )
            return 1
        print("sacred grove oak textures are URI-referenced")
        return 0
    before = OAK_GLB.stat().st_size
    result = externalize_oak_images(OAK_GLB)
    after = int(result["bytes"])
    print(
        json.dumps(
            {
                "path": OAK_GLB.relative_to(ROOT).as_posix(),
                "bytes_before": before,
                "bytes_after": after,
                "linked": result["linked"],
                "already": result["already"],
                "written": result["written"],
                "sha256": result["sha256"],
            },
            indent=2,
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
