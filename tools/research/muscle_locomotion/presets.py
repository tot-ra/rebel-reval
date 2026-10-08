"""Parametric bodies. A species is data: bone lengths, masses, muscle strengths, joint ranges.

Body parameters (all relative to the nominal 75 kg human or 25 kg dog):
  size       length scale of every bone (dwarf 0.6, tall 1.15, cat 0.55, horse 2.0)
  mass_mult  mass relative to size**3 times the nominal mass (1.0 normal, 1.6 obese)
  strength   muscle strength relative to size**3 times the nominal strength
             (muscle torque scales with size**3, mass does not buy strength)
  load       extra carried mass as a fraction of body mass, on the trunk (armour, a rider's pack)
  belly      extra mass as a fraction of body mass, hung forward of the trunk
"""
from dataclasses import dataclass, asdict
import math
from creature import Bone, Creature

@dataclass
class Body:
    size: float = 1.0
    mass_mult: float = 1.0
    strength: float = 1.0
    load: float = 0.0
    belly: float = 0.0

    def ctx(self):
        """Controller context: the body as numbers the network can see."""
        return [math.log(self.size), math.log(self.mass_mult), math.log(self.strength), self.load, self.belly]

def _bone(b, name, parent, L, ang, m, **kw):
    k = b.size
    torque = kw.pop("torque", 50.0) * b.strength * k ** 3
    arm = kw.pop("arm", 0.04) * k
    radius = kw.pop("radius") * k
    return Bone(name, parent, L * k, ang, m * b.mass_mult * k ** 3, radius=radius, torque=torque, arm=arm, **kw)

def biped(body=None, **kw):
    """Adult human-ish, 75 kg at nominal, sagittal plane. Arms and head are folded into the torso mass."""
    b = body or Body(**kw)
    total = 75.0 * b.mass_mult * b.size ** 3
    extra = []
    if b.belly:
        extra.append((0.35, 0.16 * b.size, b.belly * total))
    if b.load:
        extra.append((0.6, 0.0, b.load * total))
    torso_m = 49.0 - 0.0
    B = [_bone(b, "torso", None, 0.55, -90, torso_m, radius=0.09, extra_mass=extra)]
    for side in ("L", "R"):
        B += [
            _bone(b, f"thigh{side}", "torso", 0.43, 90, 8.0, radius=0.06, t=0.0, jrange=(-100, 30), torque=220, arm=0.06),
            _bone(b, f"shank{side}", f"thigh{side}", 0.43, 90, 3.6, radius=0.04, t=1.0, jrange=(0, 140), torque=180, arm=0.05),
            _bone(b, f"foot{side}", f"shank{side}", 0.22, 0, 1.2, radius=0.045, t=1.0, jrange=(-30, 45), torque=120, arm=0.05, foot=True),
        ]
    stand = (0.43 + 0.43 + 0.045) * b.size
    return Creature("biped", B, stand_height=stand, fall_frac=0.74, root_pitch_ok=30, proprio=True,
                    w_height=1.0, w_pitch=2.0, start_speed=0.6, f_range=(0.6, 2.0), w_air=2.0, air_target=0.38, symmetric=True,
                    w_lead=3.0, w_exc=2.0, w_clear=1.0, w_alt=1.5, body=asdict(b))

def quadruped(body=None, **kw):
    """Dog-ish, 25 kg at nominal. Root = pelvis; the trunk runs forward to the shoulders."""
    b = body or Body(**kw)
    total = 25.0 * b.mass_mult * b.size ** 3
    extra = [(1.0, 0.0, 3.0 * b.mass_mult * b.size ** 3)]
    if b.belly:
        extra.append((0.5, -0.09 * b.size, b.belly * total))
    if b.load:
        extra.append((0.5, 0.1 * b.size, b.load * total))
    B = [_bone(b, "trunk", None, 0.60, 0, 12.0, radius=0.09, extra_mass=extra)]
    for side in ("L", "R"):
        B += [
            _bone(b, f"femur{side}", "trunk", 0.22, 60, 1.6, radius=0.05, t=0.0, jrange=(-60, 60), torque=45, arm=0.04),
            _bone(b, f"tibia{side}", f"femur{side}", 0.22, 115, 0.8, radius=0.025, t=1.0, jrange=(-70, 70), torque=35, arm=0.03),
            _bone(b, f"hindfoot{side}", f"tibia{side}", 0.18, 80, 0.3, radius=0.035, t=1.0, jrange=(-60, 60), torque=25, arm=0.025, foot=True),
            _bone(b, f"humerus{side}", "trunk", 0.20, 110, 1.4, radius=0.05, t=1.0, jrange=(-60, 60), torque=45, arm=0.04),
            _bone(b, f"radius{side}", f"humerus{side}", 0.22, 85, 0.7, radius=0.025, t=1.0, jrange=(-70, 70), torque=35, arm=0.03),
            _bone(b, f"forefoot{side}", f"radius{side}", 0.16, 70, 0.3, radius=0.035, t=1.0, jrange=(-60, 60), torque=25, arm=0.025, foot=True),
        ]
    return Creature("quadruped", B, stand_height=0.55 * b.size, fall_frac=0.55, root_pitch_ok=40, proprio=True,
                    w_height=0.5, w_pitch=1.0, start_speed=0.5, f_range=(0.8, 3.5), w_air=1.0, air_target=0.4, body=asdict(b))
