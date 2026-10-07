from creature import Bone, Creature

def biped(belly=0.0):
    """Adult human-ish, 75 kg, sagittal plane. Arms/head folded into the torso mass."""
    eb = [(0.35, 0.16, belly)] if belly else []
    B = [
        Bone("torso", None, 0.55, -90, 49.0 - belly, radius=0.09, extra_mass=eb),
    ]
    for side in ("L", "R"):
        B += [
            Bone(f"thigh{side}", "torso", 0.43, 90, 8.0, radius=0.06, t=0.0, jrange=(-100, 30), torque=220, arm=0.06),
            Bone(f"shank{side}", f"thigh{side}", 0.43, 90, 3.6, radius=0.04, t=1.0, jrange=(0, 140), torque=180, arm=0.05),
            Bone(f"foot{side}", f"shank{side}", 0.22, 0, 1.2, radius=0.045, t=1.0, jrange=(-30, 45), torque=120, arm=0.05, foot=True),
        ]
    return Creature("biped", B, stand_height=0.43 + 0.43 + 0.045, fall_height=0.55, root_pitch_ok=45)

def quadruped(belly=0.0):
    """Dog-ish, 25 kg. Root = pelvis; trunk runs forward to the shoulders."""
    eb = [(0.5, -0.09, belly)] if belly else []
    B = [Bone("trunk", None, 0.60, 0, 12.0 - belly, radius=0.09, extra_mass=eb + [(1.0, 0.0, 3.0)])]
    for side in ("L", "R"):
        B += [
            Bone(f"femur{side}", "trunk", 0.22, 60, 1.6, radius=0.05, t=0.0, jrange=(-60, 60), torque=45, arm=0.04),
            Bone(f"tibia{side}", f"femur{side}", 0.22, 115, 0.8, radius=0.025, t=1.0, jrange=(-70, 70), torque=35, arm=0.03),
            Bone(f"hindfoot{side}", f"tibia{side}", 0.18, 80, 0.3, radius=0.035, t=1.0, jrange=(-60, 60), torque=25, arm=0.025, foot=True),
            Bone(f"humerus{side}", "trunk", 0.20, 110, 1.4, radius=0.05, t=1.0, jrange=(-60, 60), torque=45, arm=0.04),
            Bone(f"radius{side}", f"humerus{side}", 0.22, 85, 0.7, radius=0.025, t=1.0, jrange=(-70, 70), torque=35, arm=0.03),
            Bone(f"forefoot{side}", f"radius{side}", 0.16, 70, 0.3, radius=0.035, t=1.0, jrange=(-60, 60), torque=25, arm=0.025, foot=True),
        ]
    return Creature("quadruped", B, stand_height=0.55, fall_height=0.3, root_pitch_ok=40)
