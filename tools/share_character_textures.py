#!/usr/bin/env python3
"""Share palette-neutral character PBR maps across bodies and LODs.

Generated humanoids use five material families. Palette lives in glTF
``baseColorFactor`` / material parameters, so the grayscale albedo, tangent
normal, and packed AO/roughness maps are identical across characters and LOD
GLBs. Embedding a fresh copy in every GLB made Godot extract
``<body>_hero_tex_*.png`` sidecars on each import.

This module is the generator and import contract:

1. Write one canonical PNG set under ``assets/characters/shared/textures/``.
2. Rewrite runtime character GLBs so ``images[]`` use relative URIs instead of
   BIN ``bufferView`` embeds.
3. Leave genuinely distinct maps embedded (hash mismatch for the same glTF
   image name). KayKit build-input stays untouched.
4. A single-body export must not rewrite maps other bodies already share.
   Linking keeps the canonical PNG unless ``--regenerate-shared`` is set.
5. Delete extracted per-body sidecars only after the GLB no longer embeds them,
   so a later Godot import cannot recreate the copies.

Usage::

    python3 tools/share_character_textures.py --apply
    python3 tools/share_character_textures.py --verify
    python3 tools/share_character_textures.py --link assets/characters/shared/heroic_humanoid.glb
    python3 tools/share_character_textures.py --link <glb> --regenerate-shared
"""

from __future__ import annotations

import argparse
import hashlib
import json
import struct
import sys
from collections import defaultdict
from io import BytesIO
from pathlib import Path

try:
    from PIL import Image
except ImportError:  # pragma: no cover - fail closed: encoding-only cannot be proven
    Image = None

ROOT = Path(__file__).resolve().parents[1]
SHARED = ROOT / "assets" / "characters" / "shared"
TEXTURE_DIR = SHARED / "textures"
TEXTURE_URI_PREFIX = "textures/"
SKIP_GLB_NAMES = frozenset({"kaykit_barbarian.glb"})
FAMILY_TOKEN = "hero_tex_"


class SharedTextureMismatch(RuntimeError):
    """Harvested embed pixels differ from the committed shared PNG."""


def parse_glb(path: Path) -> tuple[dict, bytes]:
    data = path.read_bytes()
    if data[:4] != b"glTF":
        raise ValueError(f"{path}: not a GLB")
    json_len = struct.unpack_from("<I", data, 12)[0]
    gltf = json.loads(data[20 : 20 + json_len])
    bin_off = 20 + json_len + 8
    bin_len = struct.unpack_from("<I", data, 20 + json_len)[0]
    return gltf, data[bin_off : bin_off + bin_len]


def write_glb(path: Path, gltf: dict, bin_data: bytes) -> None:
    json_bytes = json.dumps(gltf, separators=(",", ":"), ensure_ascii=True).encode("utf-8")
    json_bytes += b" " * ((-len(json_bytes)) % 4)
    payload = bytes(bin_data)
    payload += b"\x00" * ((-len(payload)) % 4)
    total = 12 + 8 + len(json_bytes) + 8 + len(payload)
    path.write_bytes(
        b"glTF"
        + struct.pack("<II", 2, total)
        + struct.pack("<I", len(json_bytes))
        + b"JSON"
        + json_bytes
        + struct.pack("<I", len(payload))
        + b"BIN\x00"
        + payload
    )


def is_shared_image_name(name: str) -> bool:
    return name.startswith(FAMILY_TOKEN) or f"_{FAMILY_TOKEN}" in name


def canonical_stem(image_name: str) -> str | None:
    """Return the shared file stem for a glTF image name, or None if unique."""
    if not image_name:
        return None
    if image_name.startswith(FAMILY_TOKEN):
        return image_name
    marker = f"_{FAMILY_TOKEN}"
    if marker in image_name:
        return FAMILY_TOKEN + image_name.split(marker, 1)[1]
    return None


def canonical_uri(stem: str) -> str:
    return f"{TEXTURE_URI_PREFIX}{stem}.png"


def canonical_path(stem: str, *, root: Path = ROOT) -> Path:
    return root / "assets" / "characters" / "shared" / "textures" / f"{stem}.png"


def iter_runtime_character_glbs(*, root: Path = ROOT) -> list[Path]:
    shared = root / "assets" / "characters" / "shared"
    if not shared.is_dir():
        return []
    paths = []
    for path in sorted(shared.glob("*.glb")):
        if path.name in SKIP_GLB_NAMES:
            continue
        paths.append(path)
    return paths


def _image_bytes(gltf: dict, bin_data: bytes, image: dict) -> bytes | None:
    if "bufferView" not in image:
        uri = image.get("uri")
        if isinstance(uri, str) and not uri.startswith("data:"):
            return None
        return None
    view = gltf["bufferViews"][image["bufferView"]]
    start = int(view.get("byteOffset", 0))
    length = int(view["byteLength"])
    return bytes(bin_data[start : start + length])


def harvest_shared_images(
    glbs: list[Path],
) -> tuple[dict[str, bytes], set[str]]:
    """Return (stem -> png bytes, stems that have conflicting embedded hashes).

    Only BIN embeds vote. URI references already point at the canonical files
    and must not look like a second variant during a generator rebuild.
    """
    hashes: dict[str, set[str]] = defaultdict(set)
    payloads: dict[str, bytes] = {}
    for path in glbs:
        gltf, bin_data = parse_glb(path)
        for image in gltf.get("images", []):
            name = str(image.get("name") or "")
            stem = canonical_stem(name)
            if stem is None:
                continue
            blob = _image_bytes(gltf, bin_data, image)
            if blob is None:
                continue
            digest = hashlib.sha256(blob).hexdigest()
            hashes[stem].add(digest)
            payloads.setdefault(stem, blob)
    conflicts = {stem for stem, found in hashes.items() if len(found) > 1}
    return payloads, conflicts


def _png_rgba(blob: bytes) -> tuple[tuple[int, int], bytes] | None:
    """Decode PNG pixels as RGBA, or None when Pillow is missing or the blob is invalid."""
    if Image is None:
        return None
    try:
        with Image.open(BytesIO(blob)) as image:
            converted = image.convert("RGBA")
            return converted.size, converted.tobytes()
    except Exception:
        return None


def _channel_means(size: tuple[int, int], pixels: bytes) -> tuple[float, float, float]:
    count = size[0] * size[1]
    if count == 0:
        return (0.0, 0.0, 0.0)
    view = memoryview(pixels)
    return (
        sum(view[0::4]) / count,
        sum(view[1::4]) / count,
        sum(view[2::4]) / count,
    )


def describe_png_delta(canonical: bytes, harvested: bytes) -> str:
    """Human-readable why an export disagrees with the committed PNG."""
    canon = _png_rgba(canonical)
    harvest = _png_rgba(harvested)
    if canon is None or harvest is None:
        return "undecodable PNG or Pillow missing (treated as pixel mismatch)"
    canon_size, canon_px = canon
    harvest_size, harvest_px = harvest
    if canon_size != harvest_size:
        return (
            f"size {canon_size[0]}x{canon_size[1]} vs "
            f"{harvest_size[0]}x{harvest_size[1]}"
        )
    if canon_px == harvest_px:
        return "encoding-only"
    before = _channel_means(canon_size, canon_px)
    after = _channel_means(harvest_size, harvest_px)
    return (
        "pixel mismatch RGB mean "
        f"({before[0]:.1f},{before[1]:.1f},{before[2]:.1f}) -> "
        f"({after[0]:.1f},{after[1]:.1f},{after[2]:.1f})"
    )


def is_encoding_only_png(canonical: bytes, harvested: bytes) -> bool:
    """True when bytes differ but decoded pixels match. Fail closed without Pillow."""
    if canonical == harvested:
        return True
    canon = _png_rgba(canonical)
    harvest = _png_rgba(harvested)
    if canon is None or harvest is None:
        return False
    return canon == harvest


def reconcile_canonical_textures(
    payloads: dict[str, bytes],
    conflicts: set[str],
    *,
    root: Path = ROOT,
    regenerate_shared: bool = False,
) -> list[Path]:
    """Seed missing shared PNGs. Refuse to overwrite real pixel changes."""
    written: list[Path] = []
    mismatches: list[str] = []
    texture_dir = root / "assets" / "characters" / "shared" / "textures"
    texture_dir.mkdir(parents=True, exist_ok=True)
    for stem, blob in sorted(payloads.items()):
        if stem in conflicts:
            continue
        path = canonical_path(stem, root=root)
        if not path.is_file():
            path.write_bytes(blob)
            write_import_sidecar(path)
            written.append(path)
            continue
        current = path.read_bytes()
        if current == blob or is_encoding_only_png(current, blob):
            continue
        try:
            rel = path.relative_to(root).as_posix()
        except ValueError:
            rel = path.as_posix()
        detail = describe_png_delta(current, blob)
        if regenerate_shared:
            path.write_bytes(blob)
            write_import_sidecar(path)
            written.append(path)
            continue
        mismatches.append(f"{rel}: {detail}")
    if mismatches:
        raise SharedTextureMismatch(
            "exported maps differ from canonical shared textures:\n"
            + "\n".join(f"  - {line}" for line in mismatches)
            + "\nKeep the committed files, or pass --regenerate-shared to adopt the export."
        )
    return written


def link_exported_character_glb(
    path: Path, *, root: Path = ROOT, regenerate_shared: bool = False
) -> dict[str, int]:
    """Post-process one Blender export: keep canonical maps, then URI-link.

    WHY: other bodies already URI-reference the shared PNGs. Overwriting them
    from one machine's Blender/NumPy export silently changes every character.
    Encoding-only PNG differences still link; real pixel drift fails unless
    ``regenerate_shared`` is set.
    """
    path = path if path.is_absolute() else root / path
    payloads, conflicts = harvest_shared_images([path])
    written = reconcile_canonical_textures(
        payloads, conflicts, root=root, regenerate_shared=regenerate_shared
    )
    result = link_glb_to_shared_textures(
        path, payloads=payloads, conflicts=conflicts, root=root
    )
    result["canonical"] = len(written)
    return result


def _map_kind(stem: str) -> str:
    if stem.endswith("_albedo"):
        return "albedo"
    if stem.endswith("_normal"):
        return "normal"
    return "orm"


def write_import_sidecar(png_path: Path) -> None:
    """Lock Godot texture import to the extracted-sidecar settings.

    Albedo stays lossless (current extracted sidecars are uncompressed). Normal
    and packed ORM keep VRAM compression and roughness filtering so gameplay
    and closeup response do not change.
    """
    rel = png_path.as_posix()
    if "assets/" in rel:
        rel = "res://" + rel[rel.index("assets/") :]
    else:
        rel = "res://" + png_path.name
    stem = png_path.stem
    kind = _map_kind(stem)
    family = "cloth"
    for token in ("skin", "cloth", "leather", "hair", "metal"):
        if f"_{token}_" in f"_{stem}_" or stem.startswith(f"hero_tex_{token}_"):
            family = token
            break
    normal_res = rel.replace(png_path.name, f"hero_tex_{family}_normal.png")
    if kind == "albedo":
        body = f"""[remap]

importer="texture"
type="CompressedTexture2D"

[deps]

source_file="{rel}"

[params]

compress/mode=0
compress/high_quality=false
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=true
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=1
"""
    elif kind == "normal":
        body = f"""[remap]

importer="texture"
type="CompressedTexture2D"

[deps]

source_file="{rel}"

[params]

compress/mode=2
compress/high_quality=false
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map=1
compress/channel_pack=0
mipmaps/generate=true
mipmaps/limit=-1
roughness/mode=1
roughness/src_normal="{rel}"
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=0
"""
    else:
        body = f"""[remap]

importer="texture"
type="CompressedTexture2D"

[deps]

source_file="{rel}"

[params]

compress/mode=2
compress/high_quality=false
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=true
mipmaps/limit=-1
roughness/mode=8
roughness/src_normal="{normal_res}"
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=0
"""
    png_path.with_suffix(".png.import").write_text(body, encoding="utf-8")


def write_canonical_textures(
    payloads: dict[str, bytes],
    conflicts: set[str],
    *,
    root: Path = ROOT,
    regenerate_shared: bool = True,
) -> list[Path]:
    """Write harvested embeds to the shared texture directory.

    Default ``regenerate_shared=True`` keeps the historical --apply seed/overwrite
    behaviour. Single-body linking uses ``reconcile_canonical_textures`` instead.
    """
    return reconcile_canonical_textures(
        payloads, conflicts, root=root, regenerate_shared=regenerate_shared
    )


def _compact_bin(gltf: dict, bin_data: bytes, drop_views: set[int]) -> bytes:
    views = gltf.get("bufferViews") or []
    kept = [index for index in range(len(views)) if index not in drop_views]
    view_map = {old: new for new, old in enumerate(kept)}
    chunks: list[bytes] = []
    offset = 0
    new_views: list[dict] = []
    for old_index in kept:
        view = dict(views[old_index])
        start = int(view.get("byteOffset", 0))
        data = bin_data[start : start + int(view["byteLength"])]
        padding = (-len(data)) % 4
        view["byteOffset"] = offset
        view["buffer"] = 0
        new_views.append(view)
        chunks.append(data + b"\x00" * padding)
        offset += len(data) + padding
    gltf["bufferViews"] = new_views

    def remap_view(container: dict, key: str = "bufferView") -> None:
        if key in container and container[key] in view_map:
            container[key] = view_map[container[key]]

    for accessor in gltf.get("accessors") or []:
        remap_view(accessor)
        sparse = accessor.get("sparse")
        if isinstance(sparse, dict):
            if "indices" in sparse:
                remap_view(sparse["indices"])
            if "values" in sparse:
                remap_view(sparse["values"])
    for image in gltf.get("images") or []:
        if "bufferView" in image:
            remap_view(image)
    payload = b"".join(chunks)
    gltf["buffers"] = [{"byteLength": len(payload)}]
    return payload


def _buffer_view_users(gltf: dict) -> dict[int, list[tuple[str, int]]]:
    users: dict[int, list[tuple[str, int]]] = defaultdict(list)
    for index, accessor in enumerate(gltf.get("accessors") or []):
        view = accessor.get("bufferView")
        if view is not None:
            users[int(view)].append(("accessor", index))
        sparse = accessor.get("sparse") or {}
        for key in ("indices", "values"):
            block = sparse.get(key) or {}
            if "bufferView" in block:
                users[int(block["bufferView"])].append((f"sparse.{key}", index))
    for index, image in enumerate(gltf.get("images") or []):
        if "bufferView" in image:
            users[int(image["bufferView"])].append(("image", index))
    return users


def link_glb_to_shared_textures(
    path: Path,
    *,
    payloads: dict[str, bytes] | None = None,
    conflicts: set[str] | None = None,
    root: Path = ROOT,
) -> dict[str, int]:
    """Replace shareable embedded images with canonical URIs. Idempotent."""
    gltf, bin_data = parse_glb(path)
    conflicts = conflicts or set()
    users = _buffer_view_users(gltf)
    drop_views: set[int] = set()
    linked = 0
    kept_distinct = 0
    already = 0
    for image in gltf.get("images") or []:
        name = str(image.get("name") or "")
        stem = canonical_stem(name)
        if stem is None:
            continue
        if stem in conflicts:
            kept_distinct += 1
            continue
        uri = canonical_uri(stem)
        if image.get("uri") == uri and "bufferView" not in image:
            already += 1
            continue
        blob = _image_bytes(gltf, bin_data, image)
        if payloads is not None and stem in payloads and blob is not None:
            if hashlib.sha256(blob).hexdigest() != hashlib.sha256(payloads[stem]).hexdigest():
                kept_distinct += 1
                continue
        view_index = image.get("bufferView")
        image.clear()
        image["name"] = name or stem
        image["uri"] = uri
        image["mimeType"] = "image/png"
        linked += 1
        if view_index is not None:
            # Drop the view only when nothing else still needs the BIN slice.
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
        "distinct": kept_distinct,
    }


def extracted_sidecar_paths(*, root: Path = ROOT) -> list[Path]:
    shared = root / "assets" / "characters" / "shared"
    return sorted(
        path
        for path in shared.glob("*_hero_tex_*.png")
        if path.parent == shared
    )


def prune_extracted_sidecars(*, root: Path = ROOT) -> list[Path]:
    removed: list[Path] = []
    for path in extracted_sidecar_paths(root=root):
        sidecar = path.with_suffix(path.suffix + ".import")
        path.unlink(missing_ok=True)
        sidecar.unlink(missing_ok=True)
        removed.append(path)
    return removed


def verify_repository(*, root: Path = ROOT) -> list[str]:
    errors: list[str] = []
    glbs = iter_runtime_character_glbs(root=root)
    if not glbs:
        return ["no runtime character GLBs found"]
    payloads, conflicts = harvest_shared_images(glbs)
    texture_dir = root / "assets" / "characters" / "shared" / "textures"
    for stem in sorted(payloads):
        if stem in conflicts:
            continue
        path = canonical_path(stem, root=root)
        if not path.is_file():
            errors.append(f"missing shared texture: {path.relative_to(root).as_posix()}")
            continue
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        expected = hashlib.sha256(payloads[stem]).hexdigest()
        if digest != expected and stem not in conflicts:
            # URI GLBs harvest from the file itself, so this only fires when a
            # leftover embed disagrees with the canonical PNG.
            pass
    for path in glbs:
        gltf, _bin = parse_glb(path)
        for image in gltf.get("images") or []:
            name = str(image.get("name") or "")
            stem = canonical_stem(name)
            if stem is None:
                continue
            if stem in conflicts:
                if "bufferView" not in image:
                    errors.append(
                        f"{path.name}: distinct map {name} must stay embedded"
                    )
                continue
            uri = image.get("uri")
            expected = canonical_uri(stem)
            if uri != expected or "bufferView" in image:
                errors.append(
                    f"{path.name}: {name} must URI-reference {expected}, got {image}"
                )
            else:
                file_path = path.parent / uri
                if not file_path.is_file():
                    errors.append(
                        f"{path.name}: missing shared file {uri}"
                    )
    leftovers = extracted_sidecar_paths(root=root)
    if leftovers:
        errors.append(
            "extracted per-body texture sidecars remain: "
            + ", ".join(path.name for path in leftovers[:8])
            + ("..." if len(leftovers) > 8 else "")
        )
    if not texture_dir.is_dir() or not any(texture_dir.glob("hero_tex_*.png")):
        errors.append("shared texture directory is empty")
    return errors


def apply_repository(
    *, root: Path = ROOT, prune: bool = True, regenerate_shared: bool = False
) -> dict[str, int]:
    glbs = iter_runtime_character_glbs(root=root)
    payloads, conflicts = harvest_shared_images(glbs)
    written = reconcile_canonical_textures(
        payloads, conflicts, root=root, regenerate_shared=regenerate_shared
    )
    linked = 0
    distinct = 0
    already = 0
    for path in glbs:
        result = link_glb_to_shared_textures(
            path, payloads=payloads, conflicts=conflicts, root=root
        )
        linked += result["linked"]
        distinct += result["distinct"]
        already += result["already"]
    removed = prune_extracted_sidecars(root=root) if prune else []
    return {
        "glbs": len(glbs),
        "canonical": len(written),
        "conflicts": len(conflicts),
        "linked": linked,
        "already": already,
        "distinct": distinct,
        "pruned": len(removed),
    }


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--apply",
        action="store_true",
        help="write canonical textures, rewrite runtime GLBs, prune extracted sidecars",
    )
    parser.add_argument(
        "--verify",
        action="store_true",
        help="fail if runtime GLBs still embed shareable maps or sidecars remain",
    )
    parser.add_argument(
        "--link",
        type=Path,
        help="rewrite one GLB after a generator export (canonical files must exist or are created)",
    )
    parser.add_argument(
        "--keep-extracted",
        action="store_true",
        help="with --apply, leave Godot-extracted per-body PNGs in place",
    )
    parser.add_argument(
        "--regenerate-shared",
        action="store_true",
        help="overwrite canonical shared PNGs when an export's pixels differ",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    if args.link is not None:
        path = args.link if args.link.is_absolute() else ROOT / args.link
        try:
            result = link_exported_character_glb(
                path, root=ROOT, regenerate_shared=args.regenerate_shared
            )
        except SharedTextureMismatch as exc:
            print(f"FAIL: {exc}")
            return 1
        print(
            f"linked {path.name}: {result['linked']} images "
            f"({result['already']} already shared, {result['distinct']} distinct)"
        )
        return 0
    if args.verify:
        errors = verify_repository(root=ROOT)
        if errors:
            print("FAIL: shared character texture contract:")
            for line in errors:
                print(f"  - {line}")
            return 1
        print("OK: character GLBs reference shared family textures")
        return 0
    if args.apply:
        try:
            result = apply_repository(
                root=ROOT,
                prune=not args.keep_extracted,
                regenerate_shared=args.regenerate_shared,
            )
        except SharedTextureMismatch as exc:
            print(f"FAIL: {exc}")
            return 1
        print(
            "shared character textures: "
            f"{result['canonical']} canonical files, "
            f"{result['glbs']} glbs, linked={result['linked']}, "
            f"already={result['already']}, distinct={result['distinct']}, "
            f"conflicts={result['conflicts']}, pruned={result['pruned']}"
        )
        errors = verify_repository(root=ROOT)
        if errors:
            print("FAIL after apply:")
            for line in errors:
                print(f"  - {line}")
            return 1
        return 0
    _parser().print_help()
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
