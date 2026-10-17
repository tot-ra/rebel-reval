"""Shared motion shapes for realistic humans (R-2211).

Every realistic body GLB used to embed the same 76 clips: 4.6 MB each, 263 MB
over 57 files, although only 37 distinct sets exist (outfit variants of one body
are byte-identical, and the clips differ between bodies only by rest-pose fit).
Body GLBs now ship without clips. This tool cuts the clips into one "shape" GLB
per group of bodies whose tracks agree within tolerance, and writes the manifest
`HumanMotionLibrary` (scripts/characters/human_motion_library.gd) reads:

    assets/characters/realistic/shared/motion/<shape>.glb   armature + clips
    assets/characters/realistic/shared/motion/shapes.json   {"bodies": {body: shape}}

Input is a directory of full body exports (default build/realistic_humans/
motion_sources/<body>.glb, written by build_human.py). Every track that equals
its bone's rest transform is dropped, which is what Godot's
`animation/remove_immutable_tracks` import step did at runtime anyway, so the
shipped pose is unchanged. The body GLBs themselves are stripped of animations.

    python3 tools/assets/realistic_humans/shared_motion.py [--sources DIR] [body ...]
    docs/SYSTEMS/HUMAN_MOTION_LIBRARY.md
"""
from pathlib import Path
import argparse
import json
import struct

import numpy as np

ROOT = Path(__file__).resolve().parents[3]
REALISTIC = ROOT / "assets/characters/realistic"
MOTION_DIR = REALISTIC / "shared/motion"
MANIFEST = MOTION_DIR / "shapes.json"
SOURCES = ROOT / "build/realistic_humans/motion_sources"

# Bodies whose clips agree within these limits share one shape. Citizen outfit
# variants agree to 0.1 deg / 2 mm; different builds and the heroes do not.
ROT_TOLERANCE_DEG = 0.5
POS_TOLERANCE_M = 0.003
# Rest comparison for dropping constant tracks (float noise from baking).
REST_TOLERANCE = 1e-4
# 1 - |dot| of two quaternions; 3e-7 is about 0.1 deg, above float32 noise (6e-8).
ROTATION_REST_SLACK = 3e-7
# IK / roll controls carry no skin weights, so they never decide whether two bodies match.
CONTROL_MARKERS = ("IK", "control-")
REST_DEFAULT = {"translation": [0, 0, 0], "rotation": [0, 0, 0, 1], "scale": [1, 1, 1]}
COMPONENTS = {"SCALAR": 1, "VEC3": 3, "VEC4": 4}


def read_glb(path):
    data = path.read_bytes()
    json_len, _ = struct.unpack("<II", data[12:20])
    doc = json.loads(data[20:20 + json_len])
    offset = 20 + json_len
    bin_len, _ = struct.unpack("<II", data[offset:offset + 8])
    return doc, data[offset + 8:offset + 8 + bin_len]


def write_glb(path, doc, blob):
    text = json.dumps(doc, separators=(",", ":")).encode()
    text += b" " * (-len(text) % 4)
    blob += b"\0" * (-len(blob) % 4)
    total = 12 + 8 + len(text) + 8 + len(blob)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(
        struct.pack("<III", 0x46546C67, 2, total)
        + struct.pack("<II", len(text), 0x4E4F534A) + text
        + struct.pack("<II", len(blob), 0x004E4942) + blob)


def accessor(doc, blob, index):
    acc = doc["accessors"][index]
    view = doc["bufferViews"][acc["bufferView"]]
    width = COMPONENTS[acc["type"]]
    return np.frombuffer(blob, dtype="<f4", count=acc["count"] * width,
                         offset=view.get("byteOffset", 0) + acc.get("byteOffset", 0)).reshape(acc["count"], width)


def compact(doc, blob):
    """Drop accessors/bufferViews nothing references and repack the binary."""
    used_acc = set()
    for mesh in doc.get("meshes", []):
        for prim in mesh["primitives"]:
            used_acc.update(prim["attributes"].values())
            if "indices" in prim:
                used_acc.add(prim["indices"])
            for target in prim.get("targets", []):
                used_acc.update(target.values())
    for skin in doc.get("skins", []):
        if "inverseBindMatrices" in skin:
            used_acc.add(skin["inverseBindMatrices"])
    for anim in doc.get("animations", []):
        for sampler in anim["samplers"]:
            used_acc.update((sampler["input"], sampler["output"]))
    acc_map = {old: new for new, old in enumerate(sorted(used_acc))}
    accessors = [doc["accessors"][old] for old in sorted(used_acc)]
    used_bv = {a["bufferView"] for a in accessors if "bufferView" in a}
    # Morph targets (face blend shapes) are sparse accessors with their own views.
    for a in accessors:
        if "sparse" in a:
            used_bv.update((a["sparse"]["indices"]["bufferView"], a["sparse"]["values"]["bufferView"]))
    used_bv.update(img["bufferView"] for img in doc.get("images", []) if "bufferView" in img)
    bv_map = {old: new for new, old in enumerate(sorted(used_bv))}
    views, out = [], bytearray()
    for old in sorted(used_bv):
        view = dict(doc["bufferViews"][old])
        start = view.get("byteOffset", 0)
        out += b"\0" * (-len(out) % 4)
        view["byteOffset"] = len(out)
        out += blob[start:start + view["byteLength"]]
        views.append(view)
    for a in accessors:
        if "bufferView" in a:
            a["bufferView"] = bv_map[a["bufferView"]]
        if "sparse" in a:
            for part in ("indices", "values"):
                a["sparse"][part]["bufferView"] = bv_map[a["sparse"][part]["bufferView"]]
    for img in doc.get("images", []):
        if "bufferView" in img:
            img["bufferView"] = bv_map[img["bufferView"]]
    for mesh in doc.get("meshes", []):
        for prim in mesh["primitives"]:
            prim["attributes"] = {k: acc_map[v] for k, v in prim["attributes"].items()}
            if "indices" in prim:
                prim["indices"] = acc_map[prim["indices"]]
            if "targets" in prim:
                prim["targets"] = [{k: acc_map[v] for k, v in t.items()} for t in prim["targets"]]
    for skin in doc.get("skins", []):
        if "inverseBindMatrices" in skin:
            skin["inverseBindMatrices"] = acc_map[skin["inverseBindMatrices"]]
    for anim in doc.get("animations", []):
        for sampler in anim["samplers"]:
            sampler["input"], sampler["output"] = acc_map[sampler["input"]], acc_map[sampler["output"]]
    doc["accessors"], doc["bufferViews"] = accessors, views
    doc["buffers"] = [{"byteLength": len(out)}]
    return bytes(out)


def strip_animations(path):
    """Remove the embedded clips from a body GLB in place; bytes saved."""
    doc, blob = read_glb(path)
    if not doc.get("animations"):
        return 0
    before = path.stat().st_size
    doc.pop("animations")
    write_glb(path, doc, compact(doc, blob))
    return before - path.stat().st_size


def at_rest(values, rest, kind):
    rest = np.array(rest, dtype=np.float32)
    if kind == "rotation":  # q and -q are the same rotation
        return bool((np.abs((values * rest).sum(1)) > 1 - ROTATION_REST_SLACK).all())
    return bool((np.abs(values - rest) < REST_TOLERANCE).all())


def drop_rest_tracks(doc, blob):
    """Drop every channel that holds its node's rest transform for the whole clip."""
    for anim in doc["animations"]:
        def reach(channel):
            return accessor(doc, blob, anim["samplers"][channel["sampler"]]["input"])[-1, 0]

        kept, dropped = [], []
        for channel in anim["channels"]:
            node = doc["nodes"][channel["target"]["node"]]
            kind = channel["target"]["path"]
            values = accessor(doc, blob, anim["samplers"][channel["sampler"]]["output"])
            (dropped if at_rest(values, node.get(kind, REST_DEFAULT[kind]), kind) else kept).append(channel)
        longest = max(reach(c) for c in anim["channels"])
        if max((reach(c) for c in kept), default=0) < longest:
            # A clip's length is its longest track; keep one full-length key set.
            kept.append(next(c for c in dropped if reach(c) == longest))
        used = sorted({c["sampler"] for c in kept})
        remap = {old: new for new, old in enumerate(used)}
        # Blender writes an identical key-time accessor per channel; share one per distinct time set.
        times = {}
        for old in used:
            sampler = anim["samplers"][old]
            key = accessor(doc, blob, sampler["input"]).tobytes()
            sampler["input"] = times.setdefault(key, sampler["input"])
        anim["samplers"] = [anim["samplers"][old] for old in used]
        anim["channels"] = [dict(c, sampler=remap[c["sampler"]]) for c in kept]


def anchor_mesh(doc, blob):
    """A 1 mm triangle skinned to joint 0, appended to the binary; returns the new blob."""
    parts = [
        ("POSITION", 5126, "VEC3", struct.pack("<9f", 0, 0, 0, 0.001, 0, 0, 0, 0.001, 0)),
        ("NORMAL", 5126, "VEC3", struct.pack("<9f", 0, 0, 1, 0, 0, 1, 0, 0, 1)),
        ("JOINTS_0", 5121, "VEC4", bytes(12)),
        ("WEIGHTS_0", 5126, "VEC4", struct.pack("<4f", 1, 0, 0, 0) * 3),
    ]
    attributes = {}
    blob = bytearray(blob)
    for name, component, kind, payload in parts:
        blob += b"\0" * (-len(blob) % 4)
        doc["bufferViews"].append({"buffer": 0, "byteOffset": len(blob), "byteLength": len(payload)})
        blob += payload
        acc = {"bufferView": len(doc["bufferViews"]) - 1, "componentType": component, "count": 3, "type": kind}
        if name == "POSITION":
            acc.update(min=[0, 0, 0], max=[0.001, 0.001, 0])
        doc["accessors"].append(acc)
        attributes[name] = len(doc["accessors"]) - 1
    doc["meshes"] = [{"name": "MotionAnchor", "primitives": [{"attributes": attributes, "mode": 4}]}]
    return bytes(blob)


def write_shape(source, destination):
    """Armature + clips plus a one-triangle skinned mesh.

    Godot only builds a Skeleton3D (and so bone tracks) for a skin that a mesh
    node uses, so a tiny skinned triangle anchors the skeleton.
    """
    doc, blob = read_glb(source)
    anchor = next(n for n in doc["nodes"] if "mesh" in n and "skin" in n)
    for node in doc["nodes"]:
        if node is not anchor:
            node.pop("mesh", None)
            node.pop("skin", None)
    anchor["mesh"] = 0
    anchor["skin"], doc["skins"] = 0, [doc["skins"][anchor["skin"]]]
    # Joint 0 of the kept skin must be a real bone; the anchor triangle is weighted to it.
    blob = anchor_mesh(doc, blob)
    for key in ("materials", "textures", "images", "samplers"):
        doc.pop(key, None)
    drop_rest_tracks(doc, blob)
    write_glb(destination, doc, compact(doc, blob))


def pose_tracks(path):
    """{(clip, bone, kind): values} for translation and rotation channels."""
    doc, blob = read_glb(path)
    tracks = {}
    for anim in doc["animations"]:
        for channel in anim["channels"]:
            kind = channel["target"]["path"]
            if kind != "scale":
                values = accessor(doc, blob, anim["samplers"][channel["sampler"]]["output"])
                tracks[(anim["name"], doc["nodes"][channel["target"]["node"]]["name"], kind)] = values
    return tracks


def same_shape(a, b):
    if a.keys() != b.keys():
        return False
    for key, values in a.items():
        other = b[key]
        if values.shape != other.shape:
            return False
        if key[2] == "rotation":
            dots = np.abs((values * other).sum(1)).clip(0, 1)
            if np.degrees(2 * np.arccos(dots)).max() > ROT_TOLERANCE_DEG:
                return False
        elif not any(m in key[1] for m in CONTROL_MARKERS) and np.abs(values - other).max() > POS_TOLERANCE_M:
            return False
    return True


def cluster(sources):
    """Greedy grouping in name order: body -> name of the first body it matches."""
    reps, assignment = [], {}
    for path in sorted(sources):
        tracks = pose_tracks(path)
        for rep_name, rep_tracks in reps:
            if same_shape(rep_tracks, tracks):
                assignment[path.stem] = rep_name
                break
        else:
            reps.append((path.stem, tracks))
            assignment[path.stem] = path.stem
    return assignment


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--sources", type=Path, default=SOURCES,
                        help="directory of <body>.glb full exports that still carry their clips")
    parser.add_argument("bodies", nargs="*", help="limit to these bodies (default: every source present)")
    args = parser.parse_args()
    sources = [p for p in sorted(args.sources.glob("*.glb")) if not args.bodies or p.stem in args.bodies]
    if not sources:
        raise SystemExit(f"no motion sources in {args.sources}; run build_human.py first")
    bodies = json.loads(MANIFEST.read_text())["bodies"] if MANIFEST.exists() else {}
    bodies.update(cluster(sources))
    by_name = {p.stem: p for p in sources}
    for shape in sorted(set(bodies.values())):
        if shape in by_name:
            write_shape(by_name[shape], MOTION_DIR / f"{shape}.glb")
    MANIFEST.write_text(json.dumps({"bodies": dict(sorted(bodies.items()))}, indent=1) + "\n")
    live = set(bodies.values())
    for old in MOTION_DIR.glob("*.glb"):
        if old.stem not in live:
            old.unlink()
            Path(f"{old}.import").unlink(missing_ok=True)
    saved = sum(strip_animations(path) for path in sorted(REALISTIC.glob("*/*.glb")))
    shapes = sorted(MOTION_DIR.glob("*.glb"))
    print(f"{len(bodies)} bodies -> {len(shapes)} shapes, {sum(p.stat().st_size for p in shapes) / 1e6:.1f} MB; "
          f"stripped embedded clips from body GLBs, saved {saved / 1e6:.1f} MB")


if __name__ == "__main__":
    main()
