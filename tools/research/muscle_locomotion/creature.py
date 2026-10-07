"""Creature description -> MuJoCo model.

A creature is a graph of rigid, non-stretching bones joined by hinge joints,
plus muscles. A muscle is a straight line between two attachment points on two
different bones. It can only pull (contract); its length range is set by the
joint limits of the joints it crosses, so it cannot over-stretch or over-contract.
Antagonist pairs make a joint move both ways. In this prototype a muscle is a
"fixed tendon": its length is a linear function of the joint angles it crosses
(constant moment arm = what a wrapped muscle gives), which is exactly the
min/max-length line the design describes, and allows biarticular muscles. Mass can be added anywhere
(a belly, a heavy head) via `extra_mass`.

Planar (sagittal-plane) prototype: x forward, z up, all hinges about y.
Absolute bone angle theta: direction = (cos t, 0, -sin t); 0=forward, 90=down,
-90=up, 180=backward. Joint angle 0 is the rest pose.
"""
from __future__ import annotations
import json, math
from dataclasses import dataclass, field, asdict

@dataclass
class Bone:
    name: str
    parent: str | None
    length: float
    angle: float              # absolute rest angle, degrees
    mass: float
    radius: float = 0.04
    t: float = 1.0            # attachment fraction along the parent bone (0 = parent origin)
    jrange: tuple = (-60.0, 60.0)   # joint limits relative to rest (degrees); unused for root
    torque: float = 50.0      # peak muscle torque at this joint (N*m)
    arm: float = 0.04         # muscle moment arm (m)
    foot: bool = False        # senses ground contact
    extra_mass: list = field(default_factory=list)   # [(fraction_along_bone, offset_normal_m, mass_kg)]

@dataclass
class Creature:
    name: str
    bones: list
    stand_height: float       # root origin height when standing (m)
    fall_frac: float          # root height below this fraction of the standing height = fallen
    root_pitch_ok: float = 55.0   # degrees of root tilt from rest allowed
    notes: str = ""
    proprio: bool = False         # extra sensors: forward speed, height error, all joint angles
    w_height: float = 0.0         # cost weight: pelvis sagging below 85% of standing height
    w_pitch: float = 0.0          # cost weight: trunk tilt (radians)
    w_effort: float = 0.5         # cost weight: mean squared muscle activation
    body: dict = field(default_factory=dict)   # body parameters the creature was built from
    start_speed: float = 0.0      # initial forward speed as a fraction of the target speed

    @property
    def ctx(self):
        b = self.body
        import math
        return [math.log(b.get("size", 1.0)), math.log(b.get("mass_mult", 1.0)), math.log(b.get("strength", 1.0)),
                b.get("load", 0.0), b.get("belly", 0.0)]

    def to_json(self):
        return json.dumps(asdict(self), indent=1)

SIDE = 2.0

def _dir(theta):
    t = math.radians(theta)
    return (math.cos(t), -math.sin(t))   # (x, z)

def _normal(theta):
    t = math.radians(theta)
    return (math.sin(t), math.cos(t))

def build_mjcf(c: Creature, timestep=0.002):
    by = {b.name: b for b in c.bones}
    root = c.bones[0]
    children = {b.name: [] for b in c.bones}
    for b in c.bones[1:]:
        children[b.parent].append(b)
    muscles, tendons = [], []

    def frame_alpha(b):          # absolute rotation of body frame
        return 0.0 if b is root else b.angle

    def pt(b, s, off):           # point on bone b at distance s along it, offset off along its normal, in b's frame
        d = _dir(b.angle - frame_alpha(b)); n = _normal(b.angle - frame_alpha(b))
        return (s * d[0] + off * n[0], 0.0, s * d[1] + off * n[1])

    def body_xml(b, ind):
        p = by.get(b.parent)
        pos = (0, 0, c.stand_height) if b is root else (lambda q: (q[0], 0, q[2]))(pt(p, b.t * p.length, 0))
        euler = 0.0 if b is root else (b.angle - frame_alpha(p))
        s = "  " * ind
        x = f'{s}<body name="{b.name}" pos="{pos[0]:.5f} 0 {pos[2]:.5f}" euler="0 {euler:.4f} 0">\n'
        if b is root:
            x += f'{s}  <joint name="root_x" type="slide" axis="1 0 0" damping="0"/>\n'
            x += f'{s}  <joint name="root_z" type="slide" axis="0 0 1" damping="0"/>\n'
            x += f'{s}  <joint name="root_pitch" type="hinge" axis="0 1 0" damping="0"/>\n'
        else:
            lo, hi = b.jrange
            x += f'{s}  <joint name="j_{b.name}" type="hinge" axis="0 1 0" range="{lo} {hi}" damping="1.5" armature="0.01" limited="true"/>\n'
        a = pt(b, 0, 0); e = pt(b, b.length, 0)
        em = sum(m[2] for m in b.extra_mass)
        x += f'{s}  <geom name="g_{b.name}" type="capsule" fromto="{a[0]:.5f} 0 {a[2]:.5f} {e[0]:.5f} 0 {e[2]:.5f}" size="{b.radius}" mass="{b.mass:.4f}"/>\n'
        for k, (fr, off, m) in enumerate(b.extra_mass):
            q = pt(b, fr * b.length, off)
            x += f'{s}  <geom name="x_{b.name}_{k}" type="sphere" pos="{q[0]:.5f} 0 {q[2]:.5f}" size="{max(0.03, (m/ 400)**(1/3)):.4f}" mass="{m:.4f}" contype="0" conaffinity="0"/>\n'
        if b.foot:
            x += f'{s}  <site name="foot_{b.name}" pos="{e[0]:.5f} 0 {e[2]:.5f}" size="0.01"/>\n'
        for ch in children[b.name]:
            x += body_xml(ch, ind + 1)
        x += f'{s}</body>\n'
        return x

    body = body_xml(root, 2)
    ten, act = "", ""
    for b in c.bones[1:]:
        for tag in ("a", "b"):
            n = f"m_{b.name}_{tag}"
            coef = b.arm if tag == "a" else -b.arm
            ten += f'    <fixed name="t_{n}"><joint joint="j_{b.name}" coef="{coef}"/></fixed>\n'
            force = b.torque / b.arm
            act += f'    <muscle name="{n}" tendon="t_{n}" force="{force:.1f}" lengthrange="0.01 0.5" timeconst="0.01 0.04" range="0.75 1.05"/>\n'
    return f'''<mujoco model="{c.name}">
  <compiler angle="degree" inertiafromgeom="true" autolimits="true"/>
  <option timestep="{timestep}" gravity="0 0 -9.81" integrator="implicitfast"/>
  <default><geom contype="1" conaffinity="0" friction="1.1 0.005 0.0001" solref="0.004 1" solimp="0.95 0.99 0.001"/></default>
  <worldbody>
    <geom name="floor" type="plane" size="200 2 0.1" contype="1" conaffinity="1" friction="1.1 0.005 0.0001" pos="0 0 0"/>
{body}  </worldbody>
  <tendon>
{ten}  </tendon>
  <actuator>
{act}  </actuator>
</mujoco>'''
