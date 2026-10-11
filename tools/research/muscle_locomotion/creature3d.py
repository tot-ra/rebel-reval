"""3D creature description -> MuJoCo model.

World/creature frame at rest: x forward, y left, z up. A bone has a rest direction (unit vector
in that frame), a length, a mass and an attach point on its parent. A joint is up to three hinges
in series (degrees of freedom), each with its own limits and an antagonist muscle pair.
Only the left side and the midline are written down; the right side is mirrored automatically.
"""
from __future__ import annotations
import math
from dataclasses import dataclass, field
import numpy as np

@dataclass
class Dof:
    axis: tuple              # hinge axis in the creature frame at rest
    rng: tuple               # joint limits relative to rest (degrees)
    torque: float            # peak muscle torque (N*m)
    arm: float = 0.04        # muscle moment arm (m)

@dataclass
class Bone:
    name: str
    parent: str | None
    direction: tuple         # rest direction of the bone, creature frame
    length: float
    mass: float
    radius: float = 0.04
    t: float = 1.0           # attach point along the parent bone (0 = parent origin, 1 = parent end)
    offset: tuple = (0.0, 0.0, 0.0)   # extra attach offset, creature frame
    dofs: list = field(default_factory=list)
    side: str = "C"          # "L", "R" or "C" (centre line)
    foot: bool = False
    box: tuple | None = None # (half_height, half_width) -> a box foot instead of a capsule
    extra_mass: list = field(default_factory=list)   # [(t_along, (ox,oy,oz), kg)]

@dataclass
class Creature3D:
    name: str
    bones: list              # left + centre only; mirrored by `expand`
    stand_height: float      # nominal root height at rest
    fall_frac: float = 0.62
    max_tilt_deg: float = 55.0
    body: dict = field(default_factory=dict)

def mirror_vec(v):
    return (v[0], -v[1], v[2])

def mirror_axis(a):             # axial vector under reflection through the y = 0 plane
    return (-a[0], a[1], -a[2])

def expand(c: Creature3D):
    """Generate the right side from the left side. Returns the full bone list, parents first."""
    out = []
    for b in c.bones:
        out.append(b)
        if b.side == "L":
            r = Bone(b.name.replace("_L", "_R"), None if b.parent is None else (b.parent.replace("_L", "_R") if b.parent.endswith("_L") else b.parent),
                     mirror_vec(b.direction), b.length, b.mass, b.radius, b.t, mirror_vec(b.offset),
                     [Dof(mirror_axis(d.axis), d.rng, d.torque, d.arm) for d in b.dofs], "R", b.foot, b.box,
                     [(t, mirror_vec(o), m) for t, o, m in b.extra_mass])
            out.append(r)
    names = [b.name for b in out]
    order = []
    placed = set()
    def place(b):
        if b.name in placed: return
        if b.parent and b.parent not in placed:
            place(out[names.index(b.parent)])
        placed.add(b.name); order.append(b)
    for b in out: place(b)
    return order

def _rot_from_dir(d):
    """Rest rotation (local -> creature frame): local z along the bone, local x as close to forward as possible."""
    z = np.array(d, float); z /= np.linalg.norm(z)
    ref = np.array([1.0, 0, 0])
    if abs(z @ ref) > 0.95:
        ref = np.array([0, 0, 1.0])
    x = ref - (ref @ z) * z; x /= np.linalg.norm(x)
    y = np.cross(z, x)
    return np.stack([x, y, z], axis=1)

def _quat(R):
    w = math.sqrt(max(0.0, 1 + R[0, 0] + R[1, 1] + R[2, 2])) / 2
    if w > 1e-6:
        return (w, (R[2, 1] - R[1, 2]) / (4 * w), (R[0, 2] - R[2, 0]) / (4 * w), (R[1, 0] - R[0, 1]) / (4 * w))
    # 180 degree rotation fallback
    i = int(np.argmax(np.diag(R)))
    q = np.zeros(4)
    j, k = (i + 1) % 3, (i + 2) % 3
    s = math.sqrt(R[i, i] - R[j, j] - R[k, k] + 1) / 2
    q[1 + i] = s
    q[0] = (R[k, j] - R[j, k]) / (4 * s)
    q[1 + j] = (R[j, i] + R[i, j]) / (4 * s)
    q[1 + k] = (R[k, i] + R[i, k]) / (4 * s)
    return tuple(q)

def build_mjcf(c: Creature3D, bones=None, timestep=0.002, damping_scale=1.0):
    bones = bones or expand(c)
    size = c.body.get("size", 1.0) if c.body else 1.0
    damp = 1.5 * size ** 4.5 * damping_scale
    arma = 0.01 * size ** 5
    by = {b.name: b for b in bones}
    R = {}; origin = {}
    kids = {b.name: [] for b in bones}
    for b in bones:
        R[b.name] = _rot_from_dir(b.direction)
        if b.parent is None:
            origin[b.name] = np.zeros(3)
        else:
            p = by[b.parent]
            origin[b.name] = origin[p.name] + np.array(p.direction) / np.linalg.norm(p.direction) * p.length * b.t + np.array(b.offset)
            kids[p.name].append(b)
    root = bones[0]

    def body_xml(b, ind):
        s = "  " * ind
        if b.parent is None:
            pos = (0, 0, c.stand_height); quat = _quat(R[b.name])
        else:
            P = by[b.parent]
            pos = R[P.name].T @ (origin[b.name] - origin[P.name]); quat = _quat(R[P.name].T @ R[b.name])
        x = f'{s}<body name="{b.name}" pos="{pos[0]:.5f} {pos[1]:.5f} {pos[2]:.5f}" quat="{quat[0]:.6f} {quat[1]:.6f} {quat[2]:.6f} {quat[3]:.6f}">\n'
        if b.parent is None:
            x += f'{s}  <freejoint name="root"/>\n'
        for k, d in enumerate(b.dofs):
            ax = R[b.name].T @ np.array(d.axis, float)
            lo, hi = d.rng
            x += (f'{s}  <joint name="j_{b.name}_{k}" type="hinge" axis="{ax[0]:.5f} {ax[1]:.5f} {ax[2]:.5f}" '
                  f'range="{lo} {hi}" limited="true" damping="{damp:.5f}" armature="{arma:.6f}"/>\n')
        if b.box:
            hh, hw = b.box
            x += (f'{s}  <geom name="g_{b.name}" type="box" pos="0 0 {b.length / 2:.5f}" size="{hh:.4f} {hw:.4f} {b.length / 2:.5f}" mass="{b.mass:.4f}"/>\n')
        else:
            x += f'{s}  <geom name="g_{b.name}" type="capsule" fromto="0 0 0 0 0 {b.length:.5f}" size="{b.radius}" mass="{b.mass:.4f}"/>\n'
        for i, (ta, off, m) in enumerate(b.extra_mass):
            q = R[b.name].T @ (np.array(b.direction) / np.linalg.norm(b.direction) * b.length * ta + np.array(off))
            x += (f'{s}  <geom name="x_{b.name}_{i}" type="sphere" pos="{q[0]:.5f} {q[1]:.5f} {q[2]:.5f}" '
                  f'size="{max(0.03, (m / 400) ** (1 / 3)):.4f}" mass="{m:.4f}" contype="0" conaffinity="0"/>\n')
        for ch in kids[b.name]:
            x += body_xml(ch, ind + 1)
        return x + f'{s}</body>\n'

    ten, act = "", ""
    for b in bones:
        for k, d in enumerate(b.dofs):
            for tag, sgn in (("a", 1), ("b", -1)):
                n = f"m_{b.name}_{k}_{tag}"
                ten += f'    <fixed name="t_{n}"><joint joint="j_{b.name}_{k}" coef="{sgn * d.arm}"/></fixed>\n'
                act += (f'    <muscle name="{n}" tendon="t_{n}" force="{d.torque / d.arm:.1f}" '
                        f'lengthrange="0.01 0.5" timeconst="0.01 0.04" range="0.75 1.05"/>\n')
    return f'''<mujoco model="{c.name}">
  <compiler angle="degree" inertiafromgeom="true" autolimits="true"/>
  <option timestep="{timestep}" gravity="0 0 -9.81" integrator="implicitfast"/>
  <default><geom contype="1" conaffinity="0" friction="1.1 0.005 0.0001" solref="0.004 1" solimp="0.95 0.99 0.001"/></default>
  <worldbody>
    <geom name="floor" type="plane" size="400 400 0.1" contype="1" conaffinity="1" friction="1.1 0.005 0.0001"/>
{body_xml(root, 2)}  </worldbody>
  <tendon>
{ten}  </tendon>
  <actuator>
{act}  </actuator>
</mujoco>'''
