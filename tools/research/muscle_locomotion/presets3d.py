"""3D bodies. Left side and centre line only; creature3d.expand mirrors the right side."""
from dataclasses import dataclass, asdict
import math
from creature3d import Bone, Dof, Creature3D

X, Y, Z = (1, 0, 0), (0, 1, 0), (0, 0, 1)

@dataclass
class Body3D:
    size: float = 1.0
    mass_mult: float = 1.0
    strength: float = 1.0
    load: float = 0.0
    belly: float = 0.0

    def ctx(self):
        return [math.log(self.size), math.log(self.mass_mult), math.log(self.strength), self.load, self.belly]

def human(body=None, **kw):
    """Adult human, 75 kg at nominal: pelvis, 3-axis lumbar spine, torso (head included), arms, legs."""
    b = body or Body3D(**kw)
    k = b.size
    def dof(axis, rng, torque, arm):
        return Dof(axis, rng, torque * b.strength * k ** 3, arm * k)
    def bone(name, parent, direction, L, m, **kw):
        kw["radius"] = kw.pop("radius", 0.04) * k
        if "offset" in kw: kw["offset"] = tuple(v * k for v in kw["offset"])
        if "extra_mass" in kw: kw["extra_mass"] = [(t, tuple(v * k for v in o), mm) for t, o, mm in kw["extra_mass"]]
        return Bone(name, parent, direction, L * k, m * b.mass_mult * k ** 3, **kw)
    total = 75.0 * b.mass_mult * k ** 3
    extra = []
    if b.belly: extra.append((0.3, (0.14 * k, 0, 0), b.belly * total))
    if b.load: extra.append((0.6, (0.0, 0, 0), b.load * total))
    B = [
        bone("pelvis", None, Z, 0.20, 12.0, radius=0.10),
        bone("torso", "pelvis", Z, 0.38, 24.0, radius=0.12, extra_mass=extra,
             dofs=[dof(Y, (-20, 30), 160, 0.06), dof(X, (-15, 15), 140, 0.06), dof(Z, (-20, 20), 100, 0.06)]),
    ]
    for side in ("L",):
        B += [
            bone("thigh_L", "pelvis", (0, 0, -1), 0.43, 8.0, radius=0.06, t=0.0, offset=(0, 0.09, 0), side="L",
                 dofs=[dof(Y, (-100, 30), 220, 0.06), dof(X, (-20, 45), 150, 0.05), dof(Z, (-30, 30), 80, 0.04)]),
            bone("shank_L", "thigh_L", (0, 0, -1), 0.43, 3.6, radius=0.04, side="L", dofs=[dof(Y, (0, 140), 180, 0.05)]),
            bone("foot_L", "shank_L", X, 0.24, 1.2, offset=(-0.06, 0, 0), side="L", foot=True, box=(0.03 * k, 0.045 * k),
                 dofs=[dof(Y, (-30, 45), 120, 0.05), dof(X, (-20, 20), 80, 0.04)]),
            bone("arm_L", "torso", (0, 0, -1), 0.30, 2.0, radius=0.04, t=0.92, offset=(0, 0.20, 0), side="L",
                 dofs=[dof(Y, (-150, 60), 60, 0.04), dof(X, (-10, 90), 60, 0.04), dof(Z, (-60, 60), 30, 0.03)]),
            bone("forearm_L", "arm_L", (0, 0, -1), 0.27, 1.5, radius=0.035, side="L", dofs=[dof(Y, (-140, 0), 50, 0.035)]),
        ]
    return Creature3D("human", B, stand_height=(0.43 + 0.43 + 0.03) * k, fall_frac=0.62, max_tilt_deg=45, body=asdict(b))
