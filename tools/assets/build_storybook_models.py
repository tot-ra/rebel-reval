#!/usr/bin/env python3
"""Original grounded stylized candidates; run with Blender -b --python this_file.

Meshes are authored here. Humans retain the project's retargeted CC0 motion.
Outputs: assets/storybook/*.glb; editable sources and plates in build/storybook.
Rebuilds retain existing runtime model paths. Dimensions are Blender metres.
"""
from __future__ import annotations
import argparse
import json
import math
from pathlib import Path
import sys

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
sys.path.insert(0, str(Path(__file__).parent))
OUT = ROOT / 'assets/storybook'
BUILD = ROOT / 'build/storybook'
PARTS = []
RIG = None
from storybook_anatomy import HUMANS as LEGACY_HUMANS, BIRDS, MAMMALS, human_head, limb
from realistic_mammals import mammal
# Kalev's live body is maintained by kalev_rebuild; do not regenerate the
# retired storybook duplicate during a full batch rebuild.
HUMANS = tuple(name for name in LEGACY_HUMANS if name != 'kalev')
# Hen uses the existing licensed chicken sculpt, rigged by import_authored_birds.py.
BIRDS = tuple(name for name in BIRDS if name != 'hen')
MODELS = (*HUMANS, *MAMMALS, *BIRDS)


def material(name, color, roughness=.78, metal=0):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    rgb = tuple(int(color[i:i+2], 16) / 255 for i in (0, 2, 4))
    linear = tuple(v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4 for v in rgb)
    bsdf = m.node_tree.nodes['Principled BSDF']
    bsdf.inputs['Base Color'].default_value = (*linear, 1)
    bsdf.inputs['Roughness'].default_value = roughness
    bsdf.inputs['Metallic'].default_value = metal
    m.diffuse_color = (*linear, 1)
    return m


def palette():
    return {k: material(k, c, r, m) for k, c, r, m in [
        ('skin', 'BC8D70', .72, 0), ('blush', '9E705F', .8, 0),
        ('dark', '252936', .5, 0), ('cream', 'E9D8B4', .9, 0),
        ('ivory', 'F1E5CD', .85, 0), ('eye', '33302C', .25, 0),
        ('iris', '738875', .4, 0), ('glint', 'FFF1D3', .3, 0),
        ('hair', '604438', .85, 0), ('hair_light', '896044', .85, 0),
        ('crimson', '9B343E', .94, 0), ('teal', '346860', .94, 0),
        ('leather', '8C593B', .76, 0), ('leather_dark', '4F3930', .83, 0),
        ('brass', 'C39451', .4, .65), ('hose', '484958', .95, 0),
        ('ginger', 'BC7D49', .92, 0), ('stripe', '81553F', .94, 0),
        ('pink', 'B97970', .8, 0), ('wool', 'DFD1B5', .98, 0),
        ('hoof', '514945', .8, 0), ('robin', 'CB7547', .9, 0),
        ('brown', '7E7561', .92, 0), ('wing', '635D51', .92, 0),
        ('crow', '3B414B', .85, 0), ('grey', '8C9190', .95, 0),
        ('sage', '72835E', .94, 0), ('blue', '486884', .94, 0),
        ('silver_hair', 'C1B5A3', .9, 0), ('gold', 'D0A449', .75, 0),
        ('steel', '82939E', .55, .65), ('mail', '65737D', .7, .45),
    ]}


def finish(obj, name, mat, weights):
    obj.name = name
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    for p in obj.data.polygons:
        p.use_smooth = True
    if isinstance(weights, str):
        weights = {weights: 1.0}
    for bone, weight in weights.items():
        obj.vertex_groups.new(name=bone).add(list(range(len(obj.data.vertices))), weight, 'REPLACE')
    PARTS.append(obj)
    return obj


def oval(name, loc, scale, mat, bone, segments=24, rings=16):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=loc)
    obj = bpy.context.object
    obj.scale = scale
    return finish(obj, name, mat, bone)


def segment(name, start, end, radius, mat, bone, end_radius=None):
    start, end = Vector(start), Vector(end)
    mid = (start + end) / 2
    if end_radius is None:
        obj = oval(name, mid, (radius, radius, (end-start).length / 2 + radius * .25), mat, bone)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=20, radius1=radius, radius2=end_radius,
                                       depth=(end-start).length, location=mid)
        obj = finish(bpy.context.object, name, mat, bone)
        bevel = obj.modifiers.new('Soft edges', 'BEVEL')
        bevel.width = min(radius, end_radius) * .35
        bevel.segments = 3
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=bevel.name)
    obj.rotation_euler = (end-start).to_track_quat('Z', 'Y').to_euler()
    return obj


def line(name, points, width, mat, bone):
    curve = bpy.data.curves.new(name, 'CURVE')
    curve.dimensions = '3D'
    curve.bevel_depth = width
    curve.bevel_resolution = 2
    curve.resolution_u = 3 if mat.name.startswith('kalev_') else 10
    if mat.name.startswith('kalev_'): curve.bevel_resolution = 0
    spl = curve.splines.new('BEZIER')
    spl.bezier_points.add(len(points)-1)
    for p, xyz in zip(spl.bezier_points, points):
        p.co = xyz
        p.handle_left_type = p.handle_right_type = 'AUTO'
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.convert(target='MESH')
    return finish(bpy.context.object, name, mat, bone)


def ring_mesh(name, rows, mat):
    """Closed ring surface, smoothly weighted across the torso joints."""
    n = 32
    verts, faces = [], []
    for z, rx, ry, _weights in rows:
        verts.extend((rx*math.cos(i*math.tau/n), ry*math.sin(i*math.tau/n), z) for i in range(n))
    for row in range(len(rows)-1):
        for i in range(n):
            j = row*n+i
            faces.append((j, row*n+(i+1)%n, (row+1)*n+(i+1)%n, j+n))
    faces.extend([tuple(reversed(range(n))), tuple((len(rows)-1)*n+i for i in range(n))])
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    finish(obj, name, mat, {})
    for r, row in enumerate(rows):
        for bone, weight in row[3].items():
            g = obj.vertex_groups.get(bone) or obj.vertex_groups.new(name=bone)
            g.add(list(range(r*n, (r+1)*n)), weight, 'REPLACE')
    sub = obj.modifiers.new('Tailored silhouette', 'SUBSURF')
    sub.levels = 1
    bpy.ops.object.modifier_apply(modifier=sub.name)
    return obj


def reset():
    global PARTS, RIG
    bpy.ops.wm.read_factory_settings(use_empty=True)
    PARTS = []
    RIG = None


def bind_join(modular=False):
    groups = {}
    for obj in PARTS:
        name = obj.name.split('.')[0]
        group = 'StorybookMesh'
        if modular:
            if name.startswith(('Hair ', 'Swept ', 'Braid', 'Bun')): group = 'Hair_Scalp'
            elif name in ('Sideburn', 'Cropped beard'): group = 'Hair_Beard'
            elif name == 'Wool tunic': group = 'Clothing_Torso'
            elif name in ('upperarm', 'lowerarm'): group = 'Clothing_Sleeve'
            elif name == 'Linen cuff': group = 'Clothing_Cuffs'
            elif name in ('upperleg', 'lowerleg'): group = 'Clothing_Legs'
            elif name.startswith('Boot'): group = 'Clothing_Feet'
            elif name in ('Belt','Apprentice apron','Smith apron','Apron strap','Apron rivet','Pocket seam','Kirtle','Hem stitch'): group='Clothing_Outerwear'
            elif name in ('Mitten palm','Thumb','Finger'): group='Anatomy_Hands'
            else: group='Character_Head'
        groups.setdefault(group, []).append(obj)
    result = []
    for name, objects in groups.items():
        bpy.ops.object.select_all(action='DESELECT')
        for obj in objects: obj.select_set(True)
        bpy.context.view_layer.objects.active = objects[0]
        bpy.ops.object.join()
        obj = bpy.context.object
        obj.name = name
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        obj.parent = RIG
        mod = obj.modifiers.new('Storybook skin', 'ARMATURE')
        mod.object = RIG
        result.append(obj)
    return result


def human(name, p):
    global RIG
    import build_heroic_humanoid_glb as retarget
    from character_specs import spec as character_spec
    from copy import deepcopy
    source_name = 'hero' if name in ('kalev','watchman') else name
    selected = deepcopy(character_spec(source_name))
    # Shorten the actual arm chain and every translation track, not the display.
    if name == 'mart': selected['proportions']['arm_length'] = .92
    selected['skeleton_intermediate'] = f'build/storybook/{name}_skeleton.glb'
    original = retarget.character_spec
    try:
        retarget.character_spec = lambda _: selected
        retarget.build(source_name)
    finally:
        retarget.character_spec = original
    bpy.ops.import_scene.gltf(filepath=str(ROOT / selected['skeleton_intermediate']))
    for o in list(bpy.data.objects):
        if o.type == 'MESH':
            bpy.data.objects.remove(o, do_unlink=True)
    RIG = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
    RIG.animation_data.action = None
    for track in RIG.animation_data.nla_tracks:
        track.mute = True
    for pb in RIG.pose.bones:
        pb.matrix_basis.identity()
    bpy.context.view_layer.update()
    def head(b):
        return RIG.data.bones[b].head_local.copy()
    hz = head('head').z
    s = hz / 1.461
    young = name == 'mart'
    shirt = p[{'kalev':'crimson','mart':'teal','aita':'sage','ellen':'blue','watchman':'blue','henning':'crimson','jurgen':'sage','kaja':'teal'}[name]]
    woman = name in ('aita','ellen','kaja')
    # Rounded, fitted wool tunic: continuous torso rather than stacked balls.
    h, c, sp = head('hips').z, head('chest').z, head('spine').z
    ring_mesh('Wool tunic', [
        (h-.11*s,.255*s,.172*s,{'hips':1}),
        (h-.08*s,.255*s,.172*s,{'hips':1}),
        (sp-.06*s,.185*s,.131*s,{'hips':.45,'spine':.55}),
        (sp+.09*s,.22*s,.155*s,{'spine':.7,'chest':.3}),
        (c-.04*s,.247*s,.148*s,{'chest':1}),
        (c+.065*s,.18*s,.124*s,{'chest':1}),
        (hz-.09*s,.10*s,.078*s,{'chest':1}),
        (hz-.045*s,.064*s,.064*s,{'chest':1}),
    ], shirt)
    if name == 'kalev':
        from kalev_realism import sculpt_head
        sculpt_head(sys.modules[__name__], p, hz, s)
    else:
        human_head(sys.modules[__name__], name, p, hz, s)
    if woman:
        skirt=ring_mesh('Kirtle',[(.23*s,.34*s,.29*s,{'hips':1}),(.27*s,.34*s,.29*s,{'hips':1}),
            (h+.04*s,.30*s,.25*s,{'hips':1}),(sp+.04*s,.205*s,.158*s,{'hips':.4,'spine':.6}),
            (sp+.055*s,.205*s,.158*s,{'hips':.4,'spine':.6})],shirt)
        # Drape follows the left/right thighs below the waist instead of
        # remaining a rigid bucket while the legs walk through its sides.
        skirt.vertex_groups.clear()
        groups={b:skirt.vertex_groups.new(name=b) for b in ('hips','upperleg.l','upperleg.r')}
        for vertex in skirt.data.vertices:
            follow=.70*max(0,min(1,(sp-.10*s-vertex.co.z)/(.50*s)))
            left=max(0,min(1,.5+vertex.co.x/(.12*s)))
            for bone,weight in {'hips':1-follow,'upperleg.l':follow*left,'upperleg.r':follow*(1-left)}.items():
                if weight:groups[bone].add([vertex.index],weight,'REPLACE')
    for side in ('l','r'):
        limb(sys.modules[__name__], 'upperarm.'+side,
             [head(n+side) for n in ('upperarm.','lowerarm.','wrist.')],
             [v*s for v in (.082,.084,.061,.062,.043)],shirt,['upperarm.'+side,'lowerarm.'+side])
        limb(sys.modules[__name__], 'upperleg.'+side,
             [head(n+side) for n in ('upperleg.','lowerleg.','foot.')],
             [v*s for v in (.098,.102,.067,.074,.050)],p['hose'],['upperleg.'+side,'lowerleg.'+side])
        wrist=head('wrist.'+side)
        segment('Linen cuff', wrist, head('hand.'+side), .056*s, p['cream'], 'wrist.'+side)
        handp=head('hand.'+side)
        oval('Mitten palm',handp,(.043*s,.031*s,.061*s),p['skin'],'hand.'+side)
        oval('Thumb',handp+Vector((-.04*s if side=='l' else .04*s,-.019*s,.011*s)),(.018*s,.018*s,.035*s),p['skin'],'hand.'+side)
        for finger in range(4):
            fp=handp+Vector(((finger-1.5)*.018*s,-.008*s,-.045*s))
            segment('Finger',fp,fp+Vector((0,-.017*s,-.039*s)),.009*s,p['skin'],'hand.'+side,.007*s)
        ankle=head('foot.'+side)
        oval('Boot', (ankle.x,-.050*s,.066*s),(.072*s,.13*s,.068*s),p['leather_dark'],'foot.'+side)
        oval('Boot cuff',(ankle.x,ankle.y,ankle.z+.07*s),(.07*s,.069*s,.095*s),p['leather'],'lowerleg.'+side)
    ring_mesh('Belt',[(sp-.025*s,.194*s,.146*s,{'spine':1}),(sp+.019*s,.196*s,.147*s,{'spine':1})],p['leather_dark'])
    # Curved apron panel follows the front of the fitted tunic.
    rows=[]
    for zz, width, yy, weight in [
        (h-.095*s,.173*s,-.171*s,{'hips':1}),
        (h-.06*s,.173*s,-.171*s,{'hips':1}),
        (sp-.06*s,.145*s,-.16*s,{'hips':.45,'spine':.55}),
        (sp+.09*s,.125*s,-.18*s,{'spine':.7,'chest':.3}),
        (c-.04*s,.106*s,-.173*s,{'chest':1}),
        (c+.005*s,.106*s,-.169*s,{'chest':1}),
    ]:
        rows.append((zz,width,yy,weight))
    verts=[]
    for zz,w,yy,_weight in rows:
        for j in range(9):
            x=(j/8*2-1)*w
            verts.append((x,yy+.035*s*(x/w)**2,zz))
    faces=[(r*9+j,r*9+j+1,(r+1)*9+j+1,(r+1)*9+j) for r in range(len(rows)-1) for j in range(8)]
    mesh=bpy.data.meshes.new('Apron'); mesh.from_pydata(verts,[],faces); mesh.update()
    obj=bpy.data.objects.new('Apron',mesh); bpy.context.collection.objects.link(obj)
    bpy.ops.object.select_all(action='DESELECT'); obj.select_set(True); bpy.context.view_layer.objects.active=obj
    finish(obj,'Apprentice apron' if young else 'Smith apron',p['leather'],{})
    for r, row in enumerate(rows):
        for bone, weight in row[3].items():
            g=obj.vertex_groups.get(bone) or obj.vertex_groups.new(name=bone)
            g.add(list(range(r*9,(r+1)*9)),weight,'REPLACE')
    sol=obj.modifiers.new('Leather thickness','SOLIDIFY'); sol.thickness=.008*s
    bpy.ops.object.modifier_apply(modifier=sol.name)
    for side in (-1,1):
        line('Apron strap',[(side*.085*s,-.177*s,c),(side*.105*s,-.109*s,c+.1*s),(side*.099*s,.085*s,c+.07*s)],.014*s,p['leather'], 'chest')
        oval('Apron rivet',(side*.086*s,-.178*s,c-.006*s),(.009*s,.005*s,.009*s),p['brass'],'chest',12,8)
    # Pocket and stitched hem are readable construction details, not noise.
    line('Pocket seam',[(-.075*s,-.18*s,sp+.015*s),(-.065*s,-.18*s,sp-.04*s),(.065*s,-.18*s,sp-.04*s),(.075*s,-.18*s,sp+.015*s)],.004*s,p['cream'],'spine')
    if name not in ('kalev','mart'):
        # Only smiths wear a work apron.
        # The kirtle is the outer garment; a short smith apron would intersect
        # its full skirt. Keep the belt, and omit apron panels and fasteners.
        for obj in list(PARTS):
            if obj.name.startswith(('Smith apron','Apprentice apron','Apron strap','Apron rivet','Pocket seam')):
                PARTS.remove(obj)
                bpy.data.objects.remove(obj,do_unlink=True)
    breadth={'kalev':1.06,'mart':.92,'aita':.98,'ellen':.90,'watchman':1.02,'henning':1.03,'jurgen':1.10,'kaja':.94}[name]
    for obj in PARTS:
        if obj.name.split('.')[0] in ('Wool tunic','Kirtle','Belt','Smith apron','Apprentice apron','Pocket seam'):
            obj.scale.x *= breadth
    if name == 'kalev':
        from kalev_realism import refine_costume
        from kalev_realism_materials import unwrap
        refine_costume(sys.modules[__name__], p, hz, s)
        unwrap(PARTS)
    mesh = bind_join(modular=True)
    relax_idle_arms()
    return mesh


def relax_idle_arms():
    """Fit two resting gestures to this tunic; preserve the shared clip names.

    The inherited relaxed elbows sit behind the wider storybook torso.
    A fixed shoulder rotation brings forearms forward without moving handslots
    independently. All other motion data remains untouched.
    """
    for action in list(bpy.data.actions):
        if action.name not in ("Idle", "Interact"):
            continue
        RIG.animation_data.action = action
        bpy.context.scene.frame_set(int(action.frame_range[0]))
        corrections = {}
        for side, sign in (("l", 1), ("r", -1)):
            pb = RIG.pose.bones["upperarm." + side]
            elbow = RIG.pose.bones["lowerarm." + side].head
            desired = Vector((sign * .15, -.06, -.28)).normalized()
            delta = (elbow-pb.head).normalized().rotation_difference(desired)
            base = (pb.matrix @ pb.matrix_basis.inverted()).to_quaternion()
            corrections[pb.name] = base.inverted() @ delta @ base
        samples = []
        for frame in range(int(action.frame_range[0]), int(action.frame_range[1])+1):
            bpy.context.scene.frame_set(frame)
            samples.append((frame, {n: corrections[n] @ RIG.pose.bones[n].rotation_quaternion.copy() for n in corrections}))
        for frame, values in samples:
            for name, rotation in values.items():
                pb = RIG.pose.bones[name]
                pb.rotation_quaternion = rotation
                pb.keyframe_insert("rotation_quaternion", frame=frame, group=name)
    RIG.animation_data.action = None


def make_rig(specs):
    global RIG
    bpy.ops.object.armature_add(enter_editmode=True)
    RIG=bpy.context.object; RIG.name='StorybookRig'
    RIG.data.edit_bones.remove(RIG.data.edit_bones[0])
    for name, start, end, parent in specs:
        bone=RIG.data.edit_bones.new(name); bone.head=start; bone.tail=end
        if name.startswith('Wing'): bone.align_roll(Vector((0,0,1)))
        if parent:
            bone.parent=RIG.data.edit_bones[parent]
    bpy.ops.object.mode_set(mode='OBJECT')


def fauna(name,p):
    if name in BIRDS:
        from storybook_birds import build
        return build(sys.modules[__name__], name, p)
    return mammal(sys.modules[__name__],name,p)


def animate_fauna(bird):
    """Loop endpoints match; cycles are in-place and root identity stays stable."""
    RIG.animation_data_create()
    clips=['Idle','Walk','Hop','Fly','Peck','TakeOff','Glide','Land'] if bird else ['Idle','Walk','LookAround','Run','Graze','Alert']
    if RIG.get('species') == 'forge_cat': clips += ['Sleep','Groom','Stretch']
    for clip in clips:
        action=bpy.data.actions.new(clip)
        RIG.animation_data.action=action
        for frame in range(1,50,3):
            t=(frame-1)/48*math.tau
            for b in RIG.pose.bones:
                b.rotation_mode='XYZ'; b.rotation_euler=(0,0,0); b.location=(0,0,0); b.scale=(1,1,1)
            if bird:
                for side,sign in (('L',1),('R',-1)):
                    RIG.pose.bones['Wing.'+side].rotation_euler.z=sign*1.52
                    RIG.pose.bones['WingTip.'+side].rotation_euler.z=0
                    RIG.pose.bones['Wing.'+side].rotation_euler.x=0
                    RIG.pose.bones['Wing.'+side].rotation_euler.y=-sign*1.4
                    RIG.pose.bones['WingTip.'+side].rotation_euler.x=0
                    RIG.pose.bones['Wing.'+side].scale=(.72,.58,1)
            head=RIG.pose.bones['Head']
            head.rotation_euler.z=.09*math.sin(t)
            if clip=='Idle':
                RIG.pose.bones['Body'].location.y=.005*math.sin(t)
                RIG.pose.bones['Tail'].rotation_euler.y=.12*math.sin(t)
            elif clip=='Walk' and bird:
                RIG.pose.bones['Leg.L'].rotation_euler.x=.22*math.sin(t*2)
                RIG.pose.bones['Leg.R'].rotation_euler.x=-.22*math.sin(t*2)
                RIG.pose.bones['Body'].location.y=.004*(1-math.cos(t*4))
                head.rotation_euler.x=.06*math.sin(t*2)
            elif clip in ('Walk','Run'):
                for i,n in enumerate(['Leg.LF','Leg.RF','Leg.LB','Leg.RB']):
                    phase=t*(2 if clip=='Run' else 1)+(math.pi if i in (1,2) else 0)
                    RIG.pose.bones[n].rotation_euler.x=(.44 if clip=='Run' else .24)*math.sin(phase)
                    RIG.pose.bones[n.replace('Leg.','Shin.')].rotation_euler.x=-.40*max(0,math.sin(phase))
                    RIG.pose.bones[n.replace('Leg.','Foot.')].rotation_euler.x=.14*math.sin(phase)
                RIG.pose.bones['Body'].location.y=.009*(1-math.cos(2*t))
                RIG.pose.bones['Tail'].rotation_euler.y=.22*math.sin(t)
            elif clip=='LookAround':
                head.rotation_euler.z=.42*math.sin(t)
                head.rotation_euler.x=.1*math.sin(2*t)
            elif clip=='Graze':
                head.rotation_euler.x=.72*(1-math.cos(t))/2
                RIG.pose.bones['Body'].rotation_euler.x=.04*(1-math.cos(t))/2
            elif clip=='Alert':
                head.rotation_euler.x=-.22*(1-math.cos(t))/2
                head.rotation_euler.z=.18*math.sin(t)
                RIG.pose.bones['Tail'].rotation_euler.y=.12*math.sin(2*t)
            elif clip in ('Sleep','Groom','Stretch'):
                body=RIG.pose.bones['Body']
                if clip=='Sleep':
                    body.location.y=-.11+.002*math.sin(t)
                    head.rotation_euler.x=.20
                    for suffix in ('LF','RF','LB','RB'):
                        RIG.pose.bones['Leg.'+suffix].rotation_euler.x=.70 if suffix.endswith('F') else -.70
                        RIG.pose.bones['Shin.'+suffix].rotation_euler.x=-1.10 if suffix.endswith('F') else 1.10
                elif clip=='Groom':
                    head.rotation_euler.x=.3+.20*math.sin(t*2)
                    head.rotation_euler.z=.26
                    RIG.pose.bones['Leg.LF'].rotation_euler.x=-.85
                    RIG.pose.bones['Shin.LF'].rotation_euler.x=-.70
                else:
                    stretch=(1-math.cos(t))/2
                    body.rotation_euler.x=-.18*stretch
                    body.location.y=-.025*stretch
                    head.rotation_euler.x=.25*stretch
                    for suffix in ('LF','RF'):
                        RIG.pose.bones['Leg.'+suffix].rotation_euler.x=-.55*stretch
            elif clip=='Hop':
                RIG.pose.bones['Body'].location.y=.07*(1-math.cos(t))/2
                for n in ('Leg.L','Leg.R'):
                    RIG.pose.bones[n].rotation_euler.x=.25*math.sin(t)
            elif clip=='Peck':
                head.rotation_euler.x=.65*(1-math.cos(t))/2
            elif clip in ('Fly','TakeOff','Glide','Land'):
                progress=(frame-1)/48
                extension=1.0
                if clip=='TakeOff': extension=progress*progress*(3-2*progress)
                elif clip=='Land': extension=1-progress*progress*(3-2*progress)
                flap=.62*math.sin(t*2)
                if clip=='Glide': flap=.045*math.sin(t)
                for side,sign in (('L',1),('R',-1)):
                    wing=RIG.pose.bones['Wing.'+side]
                    tip=RIG.pose.bones['WingTip.'+side]
                    wing.rotation_euler.z=sign*1.52*(1-extension)
                    wing.rotation_euler.y=-sign*1.4*(1-extension)
                    wing.rotation_euler.x=extension*(.12+flap)
                    tip.rotation_euler.z=0
                    tip.rotation_euler.x=extension*(.10+.20*math.sin(t*2-.5))
                    wing.scale=(.72+.28*extension,.58+.42*extension,1)
                RIG.pose.bones['Body'].location.y=.38*extension
                head.rotation_euler.x=-.10*extension
                for n in ('Leg.L','Leg.R'):
                    RIG.pose.bones[n].rotation_euler.x=-.95*extension
            for b in RIG.pose.bones:
                b.keyframe_insert('rotation_euler',frame=frame,group=b.name)
                b.keyframe_insert('location',frame=frame,group=b.name)
                if bird:
                    b.keyframe_insert('scale',frame=frame,group=b.name)
        action.use_fake_user=True
        RIG.animation_data.action=None
    bpy.context.scene.render.fps=24


def export(name):
    RIG.animation_data.action=None
    for pb in RIG.pose.bones:
        pb.matrix_basis.identity()
    bpy.context.scene.frame_set(1)
    bird_colors = dict(export_vertex_color='NAME', export_vertex_color_name='Plumage', export_all_vertex_colors=False) if name in BIRDS else {}
    bpy.ops.export_scene.gltf(filepath=str(OUT/f'{name}.glb'),export_format='GLB',
        export_animations=True,export_animation_mode='ACTIONS',export_skins=True,
        export_def_bones=False,export_yup=True, **bird_colors)
    # Blender source opens in the same default outfit as the runtime wrapper.
    if name in ('aita','ellen','kaja'):
        for obj in bpy.data.objects:
            if obj.name == 'Clothing_Legs':
                obj.hide_render=True
                obj.hide_set(True)
    bpy.ops.wm.save_as_mainfile(filepath=str(BUILD/f'{name}.blend'))


def studio():
    scene=bpy.context.scene
    scene.render.engine='CYCLES'; scene.cycles.samples=24
    scene.cycles.use_denoising=True
    scene.world=bpy.data.worlds.new('Storybook studio')
    scene.world.use_nodes=True
    scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.12,.15,.20,1)
    scene.world.node_tree.nodes['Background'].inputs[1].default_value=.35
    for name,loc,power,size,color in [
        ('Warm key',(-3,-5,7),1050,5,(1,.84,.67)),
        ('Soft fill',(5,-1,5),800,4,(.68,.82,1)),
        ('Rim',(1,4,6),1250,3,(1,.9,.74))]:
        bpy.ops.object.light_add(type='AREA',location=loc)
        o=bpy.context.object; o.name=name; o.data.energy=power; o.data.shape='DISK'; o.data.size=size; o.data.color=color
        o.rotation_euler=(Vector((0,0,.8))-o.location).to_track_quat('-Z','Y').to_euler()
    scene.view_settings.view_transform='AgX'
    scene.render.resolution_x=1800; scene.render.resolution_y=1100; scene.render.resolution_percentage=100
    return scene


def gallery():
    reset(); scene=studio()
    ground=material('Studio slate','485565',1)
    bpy.ops.mesh.primitive_plane_add(size=200); bpy.context.object.data.materials.append(ground)
    entries=[(name,((i%6-2.5)*1.65,(1.5-i//6)*1.8,0),1.0 if name in HUMANS else (2.1 if name in ('robin','rat') else 1.3)) for i,name in enumerate(MODELS)]
    for name,loc,scale in entries:
        before=set(bpy.data.objects)
        before_actions=set(bpy.data.actions)
        bpy.ops.import_scene.gltf(filepath=str(OUT/f'{name}.glb'))
        imported=set(bpy.data.objects)-before
        root=bpy.data.objects.new(name+' display',None); bpy.context.collection.objects.link(root)
        for o in imported:
            if name in ('aita','ellen','kaja') and o.name.startswith('Clothing_Legs'):
                o.hide_render=True
            if o.parent not in imported:
                o.parent=root
            if o.type=='ARMATURE':
                o.animation_data.action=None
                for t in o.animation_data.nla_tracks:t.mute=True
                idle=next((a for a in set(bpy.data.actions)-before_actions if a.name=='Idle' or a.name.startswith('Idle.')),None)
                if idle:
                    o.animation_data.action=idle
        root.location=loc; root.scale=(scale,)*3; root.rotation_euler.z=-.14
    bpy.context.scene.frame_set(1)
    bpy.ops.object.camera_add(location=(4,-10,6.4))
    camera=bpy.context.object; camera.rotation_euler=(Vector((.1,-.15,1.15))-camera.location).to_track_quat('-Z','Y').to_euler()
    camera.data.type='ORTHO'; camera.data.ortho_scale=12.5; scene.camera=camera
    scene.render.filepath=str(BUILD/'storybook_lineup.png')
    bpy.ops.wm.save_as_mainfile(filepath=str(BUILD/'lineup.blend'))
    bpy.ops.render.render(write_still=True)


def main():
    args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
    parser=argparse.ArgumentParser()
    parser.add_argument('--only',choices=MODELS)
    parser.add_argument('--mammals-only',action='store_true')
    parser.add_argument('--birds-only',action='store_true',help='Rebuild four legacy procedural birds (authored hen excluded)')
    parser.add_argument('--render',action='store_true')
    parser.add_argument('--gallery-only',action='store_true')
    opts=parser.parse_args(args)
    OUT.mkdir(parents=True,exist_ok=True); BUILD.mkdir(parents=True,exist_ok=True)
    (BUILD/'.gdignore').touch()
    if not opts.gallery_only:
        for name in ([opts.only] if opts.only else BIRDS if opts.birds_only else MAMMALS if opts.mammals_only else MODELS):
            if name in MAMMALS:
                from import_realistic_mammals import build as import_mammal
                import_mammal(name,OUT)
                continue
            reset(); p=palette()
            if name == 'kalev':
                from kalev_realism_materials import palette as realism_palette
                p=realism_palette(p)
            human(name,p) if name in HUMANS else fauna(name,p)
            export(name)
            if name in HUMANS:
                from storybook_equipment import build_wearables
                build_wearables(sys.modules[__name__], name, p)
        if not opts.birds_only and not opts.mammals_only and not opts.only:
            from storybook_equipment import build_props
            build_props(sys.modules[__name__])
    if opts.render or opts.gallery_only:gallery()

if __name__=='__main__':main()
