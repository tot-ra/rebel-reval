"""Ship each fitted citizen layer once per body shape (task R-2212).

Variants of one body shape (sex, stage, build) share one MPFB body, so most layers come
out identical for every outfit. `layer_fit.json` says which outfit's file stands for which
(citizen_bodies.layer_body); this tool moves the legacy per-body files into
assets/characters/realistic/shapes/<layer_body>/layers/ and drops the duplicates.

    python3 tools/assets/realistic_humans/share_layers.py --measure   # rewrite layer_fit.json
    python3 tools/assets/realistic_humans/share_layers.py --apply     # move + delete duplicates
    python3 tools/assets/realistic_humans/share_layers.py --check     # exit 1 on a bad layout

`--check` fails when a body's layer file is missing, when a file sits outside the
layout the fit table prescribes, or when two layer files of one layer and shape carry
identical vertex positions.
"""
import argparse
import collections
import hashlib
import json
import os
import re
import struct
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(ROOT / "tools"))
import citizen_bodies as cb  # noqa: E402
import share_character_textures as share  # noqa: E402

REALISTIC = ROOT / "assets/characters/realistic"
BODY = re.compile(r"citizen_[mf]_[a-z]+_[a-z]+?(_[bcd])?$")


def geometry_hash(path):
    """Hash of every POSITION accessor: equal for refits of the same body, whatever the node names."""
    raw = path.read_bytes()
    length = struct.unpack_from("<I", raw, 12)[0]
    doc = json.loads(raw[20:20 + length])
    blob = 20 + length + 8
    digest = hashlib.md5()
    for mesh in doc["meshes"]:
        for primitive in mesh["primitives"]:
            accessor = doc["accessors"][primitive["attributes"]["POSITION"]]
            view = doc["bufferViews"][accessor["bufferView"]]
            start = blob + view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
            digest.update(raw[start:start + accessor["count"] * 12])
    return digest.hexdigest()


def legacy_files():
    return sorted(p for p in REALISTIC.glob("citizen_*/layers/*.glb") if BODY.fullmatch(p.parent.parent.name))


def shape_files():
    return sorted((REALISTIC / cb.SHAPES_DIR).glob("*/layers/*.glb"))


def measure():
    """Rewrite layer_fit.json: within a shape, outfits whose layer geometry is equal merge."""
    seen = collections.defaultdict(lambda: collections.defaultdict(dict))  # shape -> layer -> outfit -> hash
    for path in legacy_files() + shape_files():
        sex, stage, build, outfit = cb.parse_body(path.parent.parent.name)
        seen[f"{sex}_{stage}_{build}"][path.stem][outfit] = geometry_hash(path)
    fit = {}
    for shape, layers in sorted(seen.items()):
        fit[shape] = {}
        for layer, hashes in sorted(layers.items()):
            first = {}
            for outfit, digest in sorted(hashes.items()):
                first.setdefault(digest, outfit)
            fit[shape][layer] = {o: first[d] for o, d in sorted(hashes.items())}
    cb.LAYER_FIT_PATH.write_text(json.dumps(fit, indent=1, sort_keys=True) + "\n")
    print("wrote", cb.LAYER_FIT_PATH.relative_to(ROOT))


def relink_textures(path, old_dir):
    """Keep the textile URIs pointing at the same PNGs after the file moved."""
    gltf, blob = share.parse_glb(path)
    for image in gltf.get("images", []):
        uri = image.get("uri")
        if uri and not uri.startswith("data:"):
            target = (old_dir / uri).resolve()
            image["uri"] = Path(os.path.relpath(target, path.parent)).as_posix()
    share.write_glb(path, gltf, blob)


def apply():
    keep = {}
    moved = removed = 0
    for path in legacy_files():
        owner = path.parent.parent.name
        parsed = cb.parse_body(owner)
        canon = cb.layer_body(*parsed, path.stem)
        dest = REALISTIC / cb.SHAPES_DIR / canon / "layers" / path.name
        if canon == owner:
            keep[dest] = (path, owner)
            continue
        sibling = REALISTIC / canon / "layers" / path.name
        if geometry_hash(path) != geometry_hash(sibling):
            raise SystemExit(f"{path} differs from {sibling}; rerun --measure")
        path.unlink()
        path.with_name(path.name + ".import").unlink(missing_ok=True)
        removed += 1
    for dest, (path, _) in sorted(keep.items()):
        dest.parent.mkdir(parents=True, exist_ok=True)
        old_dir = path.parent
        path.replace(dest)
        # The importer regenerates the sidecar (new path, new uid) on the next --import.
        path.with_name(path.name + ".import").unlink(missing_ok=True)
        relink_textures(dest, old_dir)
        moved += 1
    for folder in REALISTIC.glob("citizen_*/layers"):
        if not any(folder.iterdir()):
            folder.rmdir()
    print(f"moved {moved}, removed {removed} duplicates")


def check():
    problems = []
    for path in legacy_files():
        problems.append(f"legacy per-body layer left behind: {path.relative_to(ROOT)}")
    seen = collections.defaultdict(list)
    for path in shape_files():
        owner = path.parent.parent.name
        parsed = cb.parse_body(owner)
        if parsed is None or cb.layer_body(*parsed, path.stem) != owner:
            problems.append(f"{path.relative_to(ROOT)} is not the file the fit table prescribes")
        seen[(parsed[:3] if parsed else owner, path.stem, geometry_hash(path))].append(owner)
    for key, owners in seen.items():
        if len(owners) > 1:
            problems.append(f"identical {key[1]} geometry of shape {key[0]} in {owners}")
    for body in sorted(p.name for p in REALISTIC.glob("citizen_*") if p.is_dir() and BODY.fullmatch(p.name)):
        parsed = cb.parse_body(body)
        for layer in cb.layers_of(parsed[0], parsed[1], parsed[3]):
            if not (ROOT / cb.layer_path(body, layer)).is_file():
                problems.append(f"{body} has no {layer} layer file")
    for problem in problems:
        print(problem)
    print(f"{len(shape_files())} shared layer files; {len(problems)} problems")
    return 1 if problems else 0


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--measure", action="store_true")
    group.add_argument("--apply", action="store_true")
    group.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if args.measure:
        measure()
    elif args.apply:
        apply()
    else:
        sys.exit(check())
