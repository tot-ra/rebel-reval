"""Shaded 3D rendering of simulated creatures (MuJoCo software renderer) and GIF assembly.

Needs an OpenGL software backend: `apt-get install libosmesa6`, then run with MUJOCO_GL=osmesa
(set automatically below if unset).
"""
import os, re
os.environ.setdefault("MUJOCO_GL", "osmesa")
os.environ.setdefault("PYOPENGL_PLATFORM", "osmesa")
import numpy as np
import mujoco
from PIL import Image, ImageDraw

_VISUAL = """
  <visual><headlight ambient="0.5 0.5 0.5" diffuse="0.55 0.55 0.55" specular="0.05 0.05 0.05"/><global offwidth="1280" offheight="720"/></visual>
  <asset>
    <texture name="sky" type="skybox" builtin="gradient" rgb1="0.62 0.78 0.95" rgb2="0.93 0.95 0.98" width="64" height="64"/>
    <texture name="grid" type="2d" builtin="checker" rgb1="0.80 0.78 0.70" rgb2="0.66 0.64 0.57" width="256" height="256"/>
    <material name="grid" texture="grid" texrepeat="24 24" reflectance="0.0"/>
  </asset>"""

def add_visuals(xml: str) -> str:
    xml = re.sub(r"(<mujoco[^>]*>)", r"\1" + _VISUAL.replace("\\", "\\\\"), xml, count=1)
    xml = xml.replace('<geom name="floor"', '<geom name="floor" material="grid"')
    xml = xml.replace("<worldbody>", '<worldbody>\n    <light pos="2 -3 5" dir="-0.3 0.5 -1" directional="true" diffuse="0.6 0.6 0.6" castshadow="false"/>', 1)
    return xml

LEFT = (0.22, 0.42, 0.80, 1); RIGHT = (0.92, 0.52, 0.18, 1); CENTRE = (0.50, 0.52, 0.58, 1)
FOOT = (0.18, 0.18, 0.2, 1); BELLY = (0.86, 0.68, 0.5, 1); LOAD = (0.35, 0.37, 0.42, 1)

def colour(model):
    for g in range(model.ngeom):
        n = mujoco.mj_id2name(model, mujoco.mjtObj.mjOBJ_GEOM, g) or ""
        if n == "floor":
            continue
        if n.startswith("x_"):
            model.geom_rgba[g] = LOAD
            model.geom_size[g][0] = min(model.geom_size[g][0], 0.16)    # shown smaller than the mass it stands for
            continue
        base = n[2:]
        c = LEFT if base.endswith("L") else RIGHT if base.endswith("R") else CENTRE
        if "foot" in base:
            c = tuple(0.5 * a + 0.5 * b for a, b in zip(c, FOOT))
        model.geom_rgba[g] = c

class Scene:
    """One creature model with a tracking camera."""
    def __init__(self, xml, width=320, height=240):
        self.model = mujoco.MjModel.from_xml_string(add_visuals(xml))
        colour(self.model)
        self.data = mujoco.MjData(self.model)
        self.r = mujoco.Renderer(self.model, height, width)
        self.cam = mujoco.MjvCamera()
        self.cam.type = mujoco.mjtCamera.mjCAMERA_FREE

    def close(self):
        self.r.close()

    def frame(self, qpos, look, dist=3.0, azimuth=60.0, elevation=-12.0, lookz=0.7):
        self.data.qpos[:] = qpos
        mujoco.mj_forward(self.model, self.data)
        self.cam.lookat[:] = (look[0], look[1], lookz)
        self.cam.distance = dist; self.cam.azimuth = azimuth; self.cam.elevation = elevation
        self.r.update_scene(self.data, camera=self.cam)
        return self.r.render()

def caption(img, text, sub=None):
    im = Image.fromarray(img); dr = ImageDraw.Draw(im)
    dr.rectangle([0, 0, im.width, 15 if sub is None else 27], fill=(255, 255, 255))
    dr.text((4, 2), text, fill=(20, 20, 20))
    if sub: dr.text((4, 14), sub, fill=(70, 70, 70))
    return np.asarray(im)

def grid(frames, cols):
    rows = [np.concatenate(frames[i:i + cols], axis=1) for i in range(0, len(frames), cols)]
    return np.concatenate(rows, axis=0)

def save_gif(images, path, fps=25, colors=96):
    ims = [Image.fromarray(a).convert("P", palette=Image.ADAPTIVE, colors=colors) for a in images]
    ims[0].save(path, save_all=True, append_images=ims[1:], duration=int(1000 / fps), loop=0, optimize=True, disposal=1)
