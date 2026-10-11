"""Build the sacred grove (hiis) dressing props with Blender (task R-1660).

Run from the repository root:
    blender --background --factory-startup --python tools/assets/build_sacred_grove_props.py -- [--preview]

Writes one Y-up GLB per prop under assets/props/environment/<stem>/<stem>.glb:
  hiis_cupmark_boulder  granite erratic with cup marks (lohukivi), 2.4 x 1.8 x 1.0 m,
                        a quarter of its height below ground
  hiis_offerings        rye loaf, wool hank, wax candle stubs, red thread knot, two
                        coins; origin at the bottom, set on top of a stone
  hiis_votive_band      linen and wool strips tied round the holy oak's bole, fitted
                        by raycast to the sacred_grove_ancient_oak bark (same frame)
  hiis_tar_torch        pine stake with a birch-bark and resin head (torvik)
  hiis_keeper_leanto    pole-and-bark lean-to of the grove keeper; open side +Z in Godot
  hiis_boundary_cairn   heap of field stones marking the edge of the hiis

Materials are flat colours; the site script swaps the named stone and bark
materials for the shared triplanar PBR sets (scenes/world/sites/hinterland_site.gd),
so no textures ship with these GLBs. Deterministic: fixed seeds, no time input.
Evidence (report.json, preview.png) goes to generated/blender/sacred_grove_props_v1/.
"""

from __future__ import annotations

import hashlib
import json
import math
import random
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector, noise
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[2]
ENV_DIR = ROOT / "assets" / "props" / "environment"
OAK_GLB = ENV_DIR / "sacred_grove_ancient_oak" / "sacred_grove_ancient_oak.glb"
EVIDENCE_DIR = ROOT / "generated" / "blender" / "sacred_grove_props_v1"
SEED = 1343
# Centre of the ancient oak's bole at chest height (measured on its GLB).
BOLE_AXIS = Vector((0.08, -0.14, 0.0))

# name -> (rgb, roughness). Names starting with "hiis_" are stable: the site
# script matches granite, fieldstone and the barks by name to swap in PBR.
PALETTE = {
	"hiis_granite": ((0.52, 0.49, 0.46), 0.9),
	"hiis_cup_soot": ((0.12, 0.11, 0.1), 1.0),
	"hiis_fieldstone": ((0.5, 0.48, 0.45), 0.92),
	"hiis_moss": ((0.18, 0.26, 0.1), 1.0),
	"hiis_pine_bark": ((0.33, 0.24, 0.17), 0.95),
	"hiis_spruce_bark": ((0.3, 0.22, 0.16), 0.95),
	"hiis_birch_bark": ((0.78, 0.75, 0.68), 0.85),
	"hiis_tar": ((0.05, 0.04, 0.03), 0.35),
	"hiis_spruce_bough": ((0.1, 0.17, 0.09), 1.0),
	"hiis_turf": ((0.23, 0.25, 0.13), 1.0),
	"hiis_linen": ((0.72, 0.69, 0.6), 0.9),
	"hiis_wool_red": ((0.55, 0.1, 0.07), 0.95),
	"hiis_wool_undyed": ((0.62, 0.58, 0.5), 0.95),
	"hiis_rye_crust": ((0.3, 0.18, 0.1), 0.8),
	"hiis_wax": ((0.88, 0.78, 0.5), 0.5),
	"hiis_silver": ((0.75, 0.75, 0.72), 0.3),
}


def mat(name: str) -> bpy.types.Material:
	m = bpy.data.materials.get(name)
	if m is None:
		m = bpy.data.materials.new(name)
		rgb, rough = PALETTE[name]
		m.use_nodes = True
		bsdf = m.node_tree.nodes["Principled BSDF"]
		bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
		bsdf.inputs["Roughness"].default_value = rough
		if name == "hiis_silver":
			bsdf.inputs["Metallic"].default_value = 1.0
		# Strips and bark slabs are single sheets: draw both faces (glTF doubleSided).
		m.use_backface_culling = False
		m.diffuse_color = (*rgb, 1.0)
	return m


def new_object(name: str, bm: bmesh.types.BMesh, material: str, collection) -> bpy.types.Object:
	mesh = bpy.data.meshes.new(name)
	bm.to_mesh(mesh)
	bm.free()
	mesh.materials.append(mat(material))
	for poly in mesh.polygons:
		poly.use_smooth = True
	obj = bpy.data.objects.new(name, mesh)
	collection.objects.link(obj)
	return obj


def cylinder(a: Vector, b: Vector, r0: float, r1: float, segs: int = 8) -> bmesh.types.BMesh:
	"""Tapered closed cylinder from a to b."""
	bm = bmesh.new()
	axis = b - a
	length = axis.length
	bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=r0, radius2=r1, depth=length)
	rot = Vector((0, 0, 1)).rotation_difference(axis.normalized())
	bmesh.ops.rotate(bm, verts=bm.verts, cent=Vector(), matrix=rot.to_matrix())
	bmesh.ops.translate(bm, verts=bm.verts, vec=(a + b) * 0.5)
	return bm


def rock(rng: random.Random, radius: float, flat: float, subdiv: int = 2) -> bmesh.types.BMesh:
	"""Lumpy, slightly flattened field stone centred on the origin."""
	bm = bmesh.new()
	bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=radius)
	off = Vector((rng.uniform(0, 100), rng.uniform(0, 100), rng.uniform(0, 100)))
	sx, sy = rng.uniform(0.85, 1.2), rng.uniform(0.8, 1.15)
	for v in bm.verts:
		n = noise.noise(v.co / radius * 1.3 + off)
		v.co *= 1.0 + 0.22 * n
		v.co.x *= sx
		v.co.y *= sy
		v.co.z *= flat
	return bm


def join(objs: list[bpy.types.Object], name: str) -> bpy.types.Object:
	bpy.ops.object.select_all(action="DESELECT")
	for o in objs:
		o.select_set(True)
	bpy.context.view_layer.objects.active = objs[0]
	bpy.ops.object.join()
	objs[0].name = name
	objs[0].data.name = name
	return objs[0]


# ---------------------------------------------------------------- props


def build_boulder(col) -> list[bpy.types.Object]:
	rng = random.Random(SEED + 1)
	bm = bmesh.new()
	bmesh.ops.create_icosphere(bm, subdivisions=4, radius=1.0)
	off = Vector((7.1, 3.3, 1.9))
	for v in bm.verts:
		big = noise.noise(v.co * 0.9 + off)
		small = noise.noise(v.co * 3.7 + off * 2.0)
		v.co *= 1.0 + 0.14 * big + 0.035 * small
		v.co.x *= 1.2
		v.co.y *= 0.9
		v.co.z *= 0.5
		# Glacier-worn top: flatten what stands above 0.32 (cups sit on it).
		if v.co.z > 0.32:
			v.co.z = 0.32 + (v.co.z - 0.32) * 0.35
	bmesh.ops.translate(bm, verts=bm.verts, vec=(0, 0, 0.22))
	stone = new_object("hiis_cupmark_boulder", bm, "hiis_granite", col)
	bpy.context.view_layer.update()
	# Cup marks: bowls cut by small spheres, the cut faces take the soot material.
	tree = BVHTree.FromObject(stone, bpy.context.evaluated_depsgraph_get())
	cups = []
	tries = 0
	while len(cups) < 7 and tries < 200:
		tries += 1
		p = Vector((rng.uniform(-0.6, 0.6), rng.uniform(-0.42, 0.42), 2.0))
		if any((p.xy - c.xy).length < 0.2 for c in cups):
			continue
		hit, normal, _i, _d = tree.ray_cast(p, Vector((0, 0, -1)))
		if hit is None or normal.z < 0.85:
			continue
		r = rng.uniform(0.055, 0.085)
		cups.append(Vector((hit.x, hit.y, hit.z + r * 0.45)))
		cbm = bmesh.new()
		bmesh.ops.create_uvsphere(cbm, u_segments=12, v_segments=8, radius=r)
		bmesh.ops.translate(cbm, verts=cbm.verts, vec=cups[-1])
		cutter = new_object("cup_%d" % len(cups), cbm, "hiis_cup_soot", col)
		mod = stone.modifiers.new("cup", "BOOLEAN")
		mod.operation = "DIFFERENCE"
		mod.solver = "EXACT"
		mod.material_mode = "TRANSFER"
		mod.object = cutter
		bpy.context.view_layer.objects.active = stone
		bpy.ops.object.modifier_apply(modifier=mod.name)
		bpy.data.objects.remove(cutter)
	return [stone]


def build_offerings(col) -> list[bpy.types.Object]:
	rng = random.Random(SEED + 2)
	parts = []
	# Round rye loaf, the crust split along the top.
	bm = bmesh.new()
	bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=10, radius=0.1)
	for v in bm.verts:
		v.co.z = max(v.co.z, -0.02) * 0.55
		v.co.z += 0.011 + 0.006 * noise.noise(v.co * 30.0)
	bmesh.ops.translate(bm, verts=bm.verts, vec=(-0.08, 0.02, 0))
	parts.append(new_object("loaf", bm, "hiis_rye_crust", col))
	# A twisted hank of undyed wool.
	bm = bmesh.new()
	ring_n, tube_n = 28, 6
	for i in range(ring_n):
		a = math.tau * i / ring_n
		for j in range(tube_n):
			b = math.tau * j / tube_n
			twist = b + a * 3.0
			rr = 0.016 * (1.0 + 0.25 * math.cos(twist * 2.0))
			x = (0.07 + rr * math.cos(twist)) * math.cos(a)
			y = (0.045 + rr * math.cos(twist)) * math.sin(a)
			bm.verts.new((x, y, 0.017 + rr * math.sin(twist)))
	bm.verts.ensure_lookup_table()
	for i in range(ring_n):
		for j in range(tube_n):
			a = i * tube_n + j
			b = i * tube_n + (j + 1) % tube_n
			c = ((i + 1) % ring_n) * tube_n + (j + 1) % tube_n
			d = ((i + 1) % ring_n) * tube_n + j
			bm.faces.new((bm.verts[a], bm.verts[b], bm.verts[c], bm.verts[d]))
	bmesh.ops.rotate(bm, verts=bm.verts, cent=Vector(), matrix=Vector((0, 0, 1)).rotation_difference(Vector((0.2, 0, 1)).normalized()).to_matrix())
	bmesh.ops.translate(bm, verts=bm.verts, vec=(0.12, 0.06, 0))
	parts.append(new_object("wool", bm, "hiis_wool_undyed", col))
	# Three wax candle stubs, burnt down to different heights.
	for k, (x, y) in enumerate(((0.02, -0.1), (0.07, -0.12), (0.045, -0.06))):
		h = rng.uniform(0.03, 0.065)
		parts.append(new_object("candle_%d" % k, cylinder(Vector((x, y, 0)), Vector((x, y, h)), 0.012, 0.011, 10), "hiis_wax", col))
		parts.append(new_object("wick_%d" % k, cylinder(Vector((x, y, h)), Vector((x, y, h + 0.008)), 0.0018, 0.0012, 4), "hiis_tar", col))
	# A knotted red thread.
	bm = bmesh.new()
	bmesh.ops.create_cone(bm, cap_ends=True, segments=8, radius1=0.011, radius2=0.011, depth=0.012)
	bmesh.ops.translate(bm, verts=bm.verts, vec=(-0.13, -0.09, 0.006))
	parts.append(new_object("knot", bm, "hiis_wool_red", col))
	parts.append(new_object("thread", cylinder(Vector((-0.13, -0.09, 0.004)), Vector((-0.02, -0.15, 0.003)), 0.003, 0.003, 4), "hiis_wool_red", col))
	# Two silver coins (pennies, artig) left in the crack.
	for k, (x, y) in enumerate(((0.14, -0.05), (0.16, -0.03))):
		parts.append(new_object("coin_%d" % k, cylinder(Vector((x, y, 0)), Vector((x, y, 0.0015)), 0.008, 0.008, 12), "hiis_silver", col))
	return [join(parts, "hiis_offerings")]


def build_votive_band(col) -> list[bpy.types.Object]:
	"""Strips tied round the oak bole, fitted to the authored oak's bark."""
	before = set(bpy.data.objects)
	bpy.ops.import_scene.gltf(filepath=str(OAK_GLB))
	imported = [o for o in bpy.data.objects if o not in before]
	bpy.context.view_layer.update()
	wood = next(o for o in imported if o.name.startswith("AncientOakWood"))
	tree = BVHTree.FromObject(wood, bpy.context.evaluated_depsgraph_get())
	rng = random.Random(SEED + 3)
	parts = []
	for band_i, (z, material, thick) in enumerate(((1.6, "hiis_linen", 0.07), (1.76, "hiis_wool_red", 0.02))):
		ring = []
		n = 72
		# Cast inward from outside: the first wall is the bark. The bole holds
		# inner shells (rays from the axis stop on them), and buttress flares or
		# a low bough can stand proud of it, so radii far over the median are
		# outliers and take the median instead.
		radii = []
		for i in range(n):
			a = math.tau * i / n
			d = Vector((math.cos(a), math.sin(a), 0))
			hit, _nrm, _idx, dist = tree.ray_cast(BOLE_AXIS + Vector((0, 0, z)) + d * 7.0, -d, 7.0)
			radii.append(7.0 - dist if hit is not None else None)
		known = sorted(r for r in radii if r is not None)
		fallback = known[len(known) // 2] if known else 1.5
		radii = [r if r is not None and r < fallback * 1.25 else fallback for r in radii]
		for i in range(n):
			a = math.tau * i / n
			d = Vector((math.cos(a), math.sin(a), 0))
			r = (radii[i - 1] + 2.0 * radii[i] + radii[(i + 1) % n]) * 0.25
			ring.append(BOLE_AXIS + Vector((0, 0, z)) + d * (r + 0.03))
		bm = bmesh.new()
		top = [bm.verts.new(p + Vector((0, 0, thick))) for p in ring]
		bot = [bm.verts.new(p - Vector((0, 0, thick))) for p in ring]
		for i in range(n):
			j = (i + 1) % n
			bm.faces.new((bot[i], bot[j], top[j], top[i]))
		parts.append(new_object("band_%d" % band_i, bm, material, col))
		if band_i == 0:
			band_ring = ring
	# Hanging ends: linen and wool strips, each tied on the linen band.
	strip_mats = ["hiis_linen", "hiis_wool_red", "hiis_linen", "hiis_wool_undyed"]
	for k in range(26):
		p = band_ring[(k * 72 // 26 + rng.randint(0, 2)) % 72]
		out = Vector((p.x - BOLE_AXIS.x, p.y - BOLE_AXIS.y, 0)).normalized()
		side = Vector((-out.y, out.x, 0))
		w = rng.uniform(0.05, 0.1)
		length = rng.uniform(0.45, 1.05)
		segs = 6
		bm = bmesh.new()
		rows = []
		for s in range(segs + 1):
			t = s / segs
			c = p + out * (0.01 + 0.06 * math.sin(t * 2.4)) + Vector((0, 0, -length * t)) + side * 0.03 * math.sin(t * 3.0 + k)
			twist = side * (w * 0.5) * (1.0 - 0.3 * t)
			rows.append((bm.verts.new(c - twist), bm.verts.new(c + twist)))
		for s in range(segs):
			bm.faces.new((rows[s][0], rows[s][1], rows[s + 1][1], rows[s + 1][0]))
		parts.append(new_object("strip_%d" % k, bm, strip_mats[k % len(strip_mats)], col))
	for o in imported:
		bpy.data.objects.remove(o)
	return [join(parts, "hiis_votive_band")]


def build_tar_torch(col) -> list[bpy.types.Object]:
	parts = []
	parts.append(new_object("stake", cylinder(Vector((0, 0, -0.3)), Vector((0.02, 0.01, 1.32)), 0.032, 0.026, 8), "hiis_pine_bark", col))
	# Birch-bark wrap, three bulging turns.
	for i in range(3):
		z = 1.3 + i * 0.075
		parts.append(new_object("wrap_%d" % i, cylinder(Vector((0.02, 0.01, z)), Vector((0.02, 0.01, z + 0.07)), 0.05 - i * 0.004, 0.047 - i * 0.004, 10), "hiis_birch_bark", col))
	parts.append(new_object("resin", cylinder(Vector((0.02, 0.01, 1.52)), Vector((0.02, 0.01, 1.6)), 0.046, 0.03, 10), "hiis_tar", col))
	rng = random.Random(SEED + 4)
	for i in range(4):
		bm = rock(rng, 0.08, 0.6)
		a = math.tau * i / 4 + 0.4
		bmesh.ops.translate(bm, verts=bm.verts, vec=(math.cos(a) * 0.1, math.sin(a) * 0.1, 0.02))
		parts.append(new_object("foot_%d" % i, bm, "hiis_fieldstone", col))
	return [join(parts, "hiis_tar_torch")]


def build_leanto(col) -> list[bpy.types.Object]:
	"""Blender -Y is the open front (glTF +Z)."""
	rng = random.Random(SEED + 5)
	parts = []
	ridge_z, depth, half = 1.85, 2.3, 1.6
	for x in (-half + 0.1, half - 0.1):
		parts.append(new_object("post", cylinder(Vector((x, 0, -0.2)), Vector((x, 0, ridge_z + 0.05)), 0.07, 0.06), "hiis_pine_bark", col))
		# The fork that holds the ridge.
		for s in (-1, 1):
			parts.append(new_object("fork", cylinder(Vector((x, 0, ridge_z - 0.1)), Vector((x + s * 0.12, 0, ridge_z + 0.18)), 0.035, 0.025, 6), "hiis_pine_bark", col))
	parts.append(new_object("ridge", cylinder(Vector((-half - 0.25, 0, ridge_z)), Vector((half + 0.25, 0, ridge_z)), 0.06, 0.05), "hiis_pine_bark", col))
	xs = [-half + i * (2 * half) / 9 for i in range(10)]
	for x in xs:
		parts.append(new_object("rafter", cylinder(Vector((x, -0.15, ridge_z + 0.12)), Vector((x + rng.uniform(-0.05, 0.05), depth, -0.05)), 0.04, 0.035, 6), "hiis_pine_bark", col))
	# Overlapping spruce-bark slabs laid down the slope, upper rows over lower.
	slope = Vector((0, depth + 0.15, -(ridge_z + 0.12))).normalized()
	slope_len = math.hypot(depth + 0.15, ridge_z + 0.12)
	normal = Vector((0, slope.z, -slope.y)) * -1.0
	rows, cols = 4, 8
	for r in range(rows):
		for c in range(cols):
			w = 2 * half / cols + 0.12
			l = slope_len / rows + 0.25
			center_t = (r + 0.5) * slope_len / rows
			x = -half + (c + 0.5) * 2 * half / cols + rng.uniform(-0.04, 0.04)
			base = Vector((x, -0.15, ridge_z + 0.12)) + slope * center_t + normal * (0.06 + 0.035 * (rows - r))
			bm = bmesh.new()
			bmesh.ops.create_cube(bm, size=1.0)
			bmesh.ops.scale(bm, verts=bm.verts, vec=(w, l, 0.025))
			for v in bm.verts:
				v.co.z += 0.02 * math.sin(v.co.x * 9.0)  # curled bark
			bmesh.ops.rotate(bm, verts=bm.verts, cent=Vector(), matrix=Vector((0, 1, 0)).rotation_difference(slope).to_matrix())
			bmesh.ops.translate(bm, verts=bm.verts, vec=base)
			parts.append(new_object("slab", bm, "hiis_spruce_bark", col))
	# Spruce boughs weighing the ridge and closing the two sides.
	for i in range(9):
		x = -half + i * (2 * half) / 8
		bm = bmesh.new()
		bmesh.ops.create_cone(bm, cap_ends=True, segments=6, radius1=0.22, radius2=0.02, depth=1.0)
		bmesh.ops.scale(bm, verts=bm.verts, vec=(1.0, 0.35, 1.0))
		bmesh.ops.rotate(bm, verts=bm.verts, cent=Vector(), matrix=Vector((0, 0, 1)).rotation_difference(slope).to_matrix())
		bmesh.ops.translate(bm, verts=bm.verts, vec=Vector((x, -0.1, ridge_z + 0.2)) + slope * 0.5 + normal * 0.22)
		parts.append(new_object("bough", bm, "hiis_spruce_bough", col))
	for x in (-half - 0.05, half + 0.05):
		for k in range(4):
			t = (k + 0.5) / 4
			p = Vector((x, -0.1, ridge_z)) + Vector((0, depth, -ridge_z)) * t
			bm = bmesh.new()
			bmesh.ops.create_cone(bm, cap_ends=True, segments=6, radius1=0.35 * (1.0 - t * 0.4), radius2=0.03, depth=ridge_z * (1.0 - t) + 0.4)
			bmesh.ops.scale(bm, verts=bm.verts, vec=(0.3, 1.0, 1.0))
			bmesh.ops.translate(bm, verts=bm.verts, vec=Vector((p.x, p.y, (ridge_z * (1.0 - t) + 0.4) * 0.5 - 0.05)))
			parts.append(new_object("side", bm, "hiis_spruce_bough", col))
	# Bough bed at the back, turf banked against the eave, a log seat in front.
	bm = bmesh.new()
	bmesh.ops.create_cube(bm, size=1.0)
	bmesh.ops.scale(bm, verts=bm.verts, vec=(2.6, 1.1, 0.18))
	bmesh.ops.translate(bm, verts=bm.verts, vec=(0, 1.15, 0.06))
	parts.append(new_object("bed", bm, "hiis_spruce_bough", col))
	bm = bmesh.new()
	bmesh.ops.create_cube(bm, size=1.0)
	bmesh.ops.scale(bm, verts=bm.verts, vec=(2 * half + 0.6, 0.6, 0.35))
	for v in bm.verts:
		v.co.z += 0.06 * noise.noise(v.co * 4.0)
	bmesh.ops.translate(bm, verts=bm.verts, vec=(0, depth + 0.1, 0.1))
	parts.append(new_object("turf", bm, "hiis_turf", col))
	parts.append(new_object("seat", cylinder(Vector((-0.75, -1.25, 0.14)), Vector((0.75, -1.3, 0.16)), 0.16, 0.14, 10), "hiis_pine_bark", col))
	return [join(parts, "hiis_keeper_leanto")]


def build_cairn(col) -> list[bpy.types.Object]:
	rng = random.Random(SEED + 6)
	parts = []
	layout = [(7, 0.52, 0.3, 0.12), (5, 0.28, 0.24, 0.36), (2, 0.1, 0.18, 0.55)]
	for count, ring_r, size, z in layout:
		for i in range(count):
			a = math.tau * i / count + rng.uniform(-0.2, 0.2) + z
			bm = rock(rng, size * rng.uniform(0.85, 1.15), 0.7)
			bmesh.ops.rotate(bm, verts=bm.verts, cent=Vector(), matrix=Vector((0, 0, 1)).rotation_difference(Vector((rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3), 1)).normalized()).to_matrix())
			bmesh.ops.translate(bm, verts=bm.verts, vec=(math.cos(a) * ring_r, math.sin(a) * ring_r, z))
			parts.append(new_object("stone", bm, "hiis_fieldstone" if rng.random() > 0.25 else "hiis_moss", col))
	return [join(parts, "hiis_boundary_cairn")]


BUILDERS = {
	"hiis_cupmark_boulder": build_boulder,
	"hiis_offerings": build_offerings,
	"hiis_votive_band": build_votive_band,
	"hiis_tar_torch": build_tar_torch,
	"hiis_keeper_leanto": build_leanto,
	"hiis_boundary_cairn": build_cairn,
}


def export(stem: str, objs: list[bpy.types.Object]) -> dict:
	out = ENV_DIR / stem / ("%s.glb" % stem)
	out.parent.mkdir(parents=True, exist_ok=True)
	bpy.ops.object.select_all(action="DESELECT")
	for o in objs:
		o.select_set(True)
	bpy.ops.export_scene.gltf(
		filepath=str(out),
		export_format="GLB",
		use_selection=True,
		export_apply=True,
		export_yup=True,
		export_materials="EXPORT",
		export_animations=False,
		export_cameras=False,
		export_lights=False,
	)
	tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objs)
	lo = Vector((min(v[0] for o in objs for v in o.bound_box), min(v[1] for o in objs for v in o.bound_box), min(v[2] for o in objs for v in o.bound_box)))
	hi = Vector((max(v[0] for o in objs for v in o.bound_box), max(v[1] for o in objs for v in o.bound_box), max(v[2] for o in objs for v in o.bound_box)))
	return {
		"glb": out.relative_to(ROOT).as_posix(),
		"triangles": tris,
		"size_m_blender_xyz": [round(hi.x - lo.x, 3), round(hi.y - lo.y, 3), round(hi.z - lo.z, 3)],
		"sha256": hashlib.sha256(out.read_bytes()).hexdigest(),
	}


def render_preview(groups: dict[str, list[bpy.types.Object]], path: Path) -> None:
	# Spread the props on a row and render with Workbench (material colours).
	x = 0.0
	spacing = {"hiis_votive_band": 4.5, "hiis_keeper_leanto": 4.5}
	for stem, objs in groups.items():
		w = spacing.get(stem, 2.6)
		x += w * 0.5
		for o in objs:
			o.location.x += x
			if stem == "hiis_offerings":
				o.scale = (4, 4, 4)
		x += w * 0.5
	scene = bpy.context.scene
	scene.render.engine = "BLENDER_WORKBENCH"
	scene.display.shading.color_type = "MATERIAL"
	scene.display.shading.light = "STUDIO"
	scene.render.resolution_x, scene.render.resolution_y = 1600, 600
	cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
	scene.collection.objects.link(cam)
	cam.location = (x * 0.5, -11.0, 4.0)
	cam.rotation_euler = (math.radians(75), 0, 0)
	cam.data.lens = 24
	scene.camera = cam
	scene.render.filepath = str(path)
	bpy.ops.render.render(write_still=True)


def main() -> None:
	bpy.ops.wm.read_factory_settings(use_empty=True)
	col = bpy.context.scene.collection
	groups, report = {}, {"generator": "build_sacred_grove_props", "seed": SEED, "props": {}}
	for stem, build in BUILDERS.items():
		objs = build(col)
		groups[stem] = objs
		bpy.context.view_layer.update()
		report["props"][stem] = export(stem, objs)
	EVIDENCE_DIR.mkdir(parents=True, exist_ok=True)
	if "--preview" in sys.argv:
		render_preview(groups, EVIDENCE_DIR / "preview.png")
	(EVIDENCE_DIR / "report.json").write_text(json.dumps(report, indent=2) + "\n")
	print(json.dumps(report, indent=2))


main()
