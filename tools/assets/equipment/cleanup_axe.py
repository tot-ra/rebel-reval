"""Turn a raw Meshy axe-head scan into a hafted, game-ready axe variant GLB.

Pipeline and conventions: docs/SYSTEMS/EQUIPMENT_VARIANTS.md (task R-2009).
A spear head sits ON its pole, so cleanup_equipment.py builds the pole under
the scan. An axe head sits ON the haft through its eye, side-on, so it needs
its own orientation and a haft that passes through the eye. This script reuses
the shared helpers of cleanup_equipment.py (import, scan material, ORM bake,
decimate, export) by executing that file without its trailing main() call.

    B=/Applications/Blender.app/Contents/MacOS/Blender
    $B -b --factory-startup --python tools/assets/equipment/cleanup_axe.py -- \\
        --manifest tools/assets/equipment/items/axe_peasant_p1_w1.json

The reference is a cheek view of the head, no eye drawn (image generators put
the eye on the wrong face: eye and fan outline together make an adze, not an
axe). The edge runs along the haft, the cheeks face sideways, the blade points
forward (Godot +Z); the script scales the head to `head_len_m`, widens the
blade (`edge_stretch`) and thins the cheeks toward the edge (`edge_thin`), then
builds an oval haft that passes through the poll and shows a stub above it.
"""

from __future__ import annotations

import json
import math
from pathlib import Path

import bpy
import numpy as np
from mathutils import Matrix

_HERE = Path(__file__).resolve().parent
_src = (_HERE / "cleanup_equipment.py").read_text()
# The shared file ends with a bare main() call; everything above it is helpers.
exec(compile(_src.rsplit("\nmain()", 1)[0], str(_HERE / "cleanup_equipment.py"), "exec"))


def _orient_head(head: bpy.types.Object, scan: dict) -> float:
    """Cheek view -> hafted pose; returns the poll's top height above the eye centre.

    The reference is a cheek view (no eye drawn: the generators draw the hole on
    the wrong face). Raw X runs poll to edge, raw Y is the cheek thickness, raw Z
    the edge length. Result (Blender, Godot = x, z, -y): edge length up the haft
    (+Z), cheek normal sideways (X), blade forward (Blender -Y = Godot +Z), eye
    centre on the origin so the haft through it stands at x=y=0."""
    co = _co(head)
    lo, hi = co.min(0), co.max(0)
    mid_x = (lo[0] + hi[0]) / 2
    # The blade end of the outline is the taller one along raw Z, not the poll block.
    blade_pos = np.ptp(co[co[:, 0] > mid_x][:, 2]) > np.ptp(co[co[:, 0] < mid_x][:, 2])
    # new = M @ old; the sign keeps det +1 (no mirroring): blade +X -> -Y needs c=+1, blade -X -> +Y needs c=-1.
    m = Matrix(((0, 1, 0, 0), (-1, 0, 0, 0), (0, 0, 1, 0), (0, 0, 0, 1))) if blade_pos else Matrix(((0, -1, 0, 0), (1, 0, 0, 0), (0, 0, 1, 0), (0, 0, 0, 1)))
    head.data.transform(m)
    co = _co(head)
    k = float(scan["head_len_m"]) / float(np.ptp(co[:, 1]))
    head.data.transform(Matrix.Diagonal((k, k, k, 1.0)))
    co = _co(head)
    poll_y = co[:, 1].max()  # poll end at +Y
    length = float(np.ptp(co[:, 1]))
    eye_y = poll_y - float(scan["eye_from_poll"]) * length
    poll = co[co[:, 1] > poll_y - float(scan.get("poll_depth", 0.22)) * length]
    eye_z = (poll[:, 2].min() + poll[:, 2].max()) / 2
    poll_top = float(poll[:, 2].max() - eye_z)
    head.data.transform(Matrix.Translation((-(co[:, 0].min() + co[:, 0].max()) / 2, -eye_y, -eye_z)))
    # Shape the slab into an axe: widen the blade along the haft and thin the cheeks
    # toward the edge. u runs 0 at the eye to 1 at the edge; the poll block stays put.
    co = _co(head)
    u = np.clip(-co[:, 1] / max(-co[:, 1].min(), 1e-6), 0.0, 1.0)
    stretch = 1.0 + (float(scan.get("edge_stretch", 1.0)) - 1.0) * u
    taper = 1.0 - float(scan.get("edge_thin", 0.7)) * u * u
    co[:, 2] *= stretch
    co[:, 0] *= taper
    head.data.vertices.foreach_set("co", co.ravel())
    head.data.update()
    return poll_top


def _build_haft(head: bpy.types.Object, spec: dict, poll_top: float, name: str) -> tuple[bpy.types.Object, float]:
    """Oval haft: thick at the grip, slim through the eye; returns (haft, head centre height)."""
    length = float(spec["length_m"])  # butt to the eye centre
    stub = float(spec.get("stub_m", 0.015))  # haft end showing above the poll
    butt_r = float(spec["butt_radius_m"])
    eye_r = float(spec["eye_radius_m"])
    oval = float(spec.get("oval", 1.25))  # long axis along the blade, as hafts are cut
    seg = int(spec.get("segments", 12))
    rings = int(spec.get("rings", 8))
    uv_repeat = float(spec.get("uv_repeat_m", 0.5))
    top = length + poll_top + stub
    verts, faces = [], []
    for r in range(rings + 1):
        t = r / rings
        z = t * top
        # Swell under the hand, then slim to the eye so the iron seats on it.
        grip = 1.0 + 0.07 * math.sin(min(z / (0.4 * length), 1.0) * math.pi)
        if z <= 0.4 * length:
            radius = butt_r * grip
        elif z <= length:
            radius = butt_r + (eye_r - butt_r) * (z - 0.4 * length) / (0.6 * length)
        else:
            radius = eye_r
        for s in range(seg):
            a = s / seg * math.tau
            verts.append((radius * math.cos(a), -radius * oval * math.sin(a), z))
    for r in range(rings):
        for s in range(seg):
            a, b = r * seg + s, r * seg + (s + 1) % seg
            faces.append((a, b, b + seg, a + seg))
    butt = len(verts)
    verts.append((0.0, 0.0, -butt_r * 0.3))  # rounded butt end
    for s in range(seg):
        faces.append((butt, (s + 1) % seg, s))
    cap = len(verts)
    verts.append((0.0, 0.0, top + eye_r * 0.3))  # rounded top end
    last = rings * seg
    for s in range(seg):
        faces.append((cap, last + s, last + (s + 1) % seg))
    mesh = bpy.data.meshes.new(f"{name}_haft")
    mesh.from_pydata(verts, [], faces)
    uv = mesh.uv_layers.new(name="UVMap")
    for poly in mesh.polygons:
        cols = [(math.atan2(verts[v][1], verts[v][0]) / math.tau) % 1.0 for v in poly.vertices]
        for li, vi in zip(poly.loop_indices, poly.vertices):
            x, y, z = verts[vi]
            u = (math.atan2(y, x) / math.tau) % 1.0
            if len(cols) == 4 and max(cols) - min(cols) > 0.5 and u < 0.5:
                u += 1.0  # seam: the last column wraps to u=1
            uv.data[li].uv = (u, z / uv_repeat)
    mesh.update()
    haft = bpy.data.objects.new(f"{name}_haft", mesh)
    bpy.context.scene.collection.objects.link(haft)
    bpy.ops.object.select_all(action="DESELECT")
    haft.select_set(True)
    bpy.context.view_layer.objects.active = haft
    bpy.ops.object.shade_smooth()
    haft.data.materials.append(_texture_material(f"{name}_haft", spec))
    head.data.transform(Matrix.Translation((0, 0, length)))
    head.data.update()
    return haft, length


def main() -> None:
    m = json.loads(Path(_args().manifest).read_text())
    name = m["variant"]
    head = _import(ROOT / m["raw"])
    scan = m["scan"]
    poll_top = _orient_head(head, scan)
    _scan_material(head, scan, int(m.get("tex", 1024)), name)
    haft, lift = _build_haft(head, m["haft"], poll_top, name)
    bpy.ops.object.select_all(action="DESELECT")
    for o in (head, haft):
        o.select_set(True)
    bpy.context.view_layer.objects.active = head
    bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = obj.data.name = name
    top = float(_co(obj)[:, 2].max())
    bottom = float(_co(obj)[:, 2].min())
    pivot = float(m.get("pivot_from_base_m", 0.0))  # the grip hand, measured up from the butt
    obj.data.transform(Matrix.Translation((0, 0, -pivot)))
    obj.data.update()
    sockets = dict(m.get("sockets", {}))
    sockets.setdefault("socket_grip", [0.0, 0.0, 0.0])
    sockets.setdefault("socket_butt", [0.0, round(bottom - pivot, 3), 0.0])
    sockets.setdefault("socket_tip", [0.0, round(top - pivot, 3), 0.0])
    # The edge: forward (Godot +Z) of the eye, where the cut lands.
    co = _co(obj)
    edge_z = float(-co[:, 1].min())
    sockets.setdefault("socket_edge", [0.0, round(lift - pivot, 3), round(edge_z, 3)])
    empties = []
    for sname, (gx, gy, gz) in sorted(sockets.items()):
        e = bpy.data.objects.new(sname, None)
        e.location = (gx, -gz, gy)
        bpy.context.scene.collection.objects.link(e)
        empties.append(e)
    _decimate(obj, int(m.get("tris", 0)))
    out = ROOT / m["out"]
    _export(out, [obj, *empties])
    lod0 = _tris(obj)
    lod1 = 0
    if m.get("lod1_tris"):
        _decimate(obj, int(m["lod1_tris"]))
        lod1 = _tris(obj)
        _export(ROOT / "build" / "equipment" / f"{name}_lod1.glb", [obj, *empties])
    co = _co(obj)
    lo, hi = co.min(0), co.max(0)
    print("EQUIPMENT " + json.dumps({
        "variant": name,
        "out": m["out"],
        "lod0_tris": lod0,
        "lod1_tris": lod1,
        "godot_size_xyz": [round(float(hi[0] - lo[0]), 3), round(float(hi[2] - lo[2]), 3), round(float(hi[1] - lo[1]), 3)],
        "head_lift_m": round(lift, 3),
        "sockets": sockets,
        "images": [(i.name, i.size[0]) for i in bpy.data.images if i.size[0] > 0 and i.users],
    }))


main()
