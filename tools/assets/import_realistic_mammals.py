#!/usr/bin/env python3
"""Import licensed sculpted mammals without replacing their surfaces with primitives.

Sources are restored by the model URLs/hashes in assets/storybook/mammal_sources.json.
Stage originals at build/animal_redo/sources/<species>.glb. Run using Blender 5.2:
  blender -b --python tools/assets/import_realistic_mammals.py -- --only goat
Candidate GLBs and editable blends go to build/animal_redo/candidates. --publish
writes reviewed outputs to the existing runtime paths. No source mesh fallback.
"""
from __future__ import annotations
import argparse
import hashlib
import runpy
import shutil
import subprocess
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector, Euler

ROOT=Path(__file__).resolve().parents[2]
BUILD=ROOT/'build/animal_redo'
sys.path.insert(0,str(Path(__file__).parent))
from mammal_limb_anatomy import Limb, foot_path, pose_points

# Height includes ears/horns. Joint heights describe the actual source surfaces,
# in fractions of that height; feet are measured from each source mesh below.
CONFIG={
 'dog': dict(height=.54,front=(.72,.45,.16),back=(.75,.50,.29),fy=-.13,by=.28,head=(-.25,.76),tail=(.40,.62),body=.63,rotation=-math.pi/2),
 'forge_cat': dict(height=.40,front=(.68,.43,.15),back=(.77,.49,.27),fy=-.13,by=.23,head=(-.25,.69),tail=(.30,.72),body=.65),
 'sheep': dict(height=.77,front=(.73,.46,.18),back=(.78,.55,.31),fy=-.15,by=.29,head=(-.29,.79),tail=(.43,.73),body=.64),
 'goat': dict(height=.94,front=(.58,.37,.14),back=(.64,.43,.24),fy=-.12,by=.30,head=(-.27,.63),tail=(.41,.64),body=.53),
 'pig': dict(height=.63,front=(.72,.43,.19),back=(.78,.54,.31),fy=-.12,by=.28,head=(-.25,.63),tail=(.43,.74),body=.64),
 'boar': dict(height=.86,front=(.72,.46,.18),back=(.71,.47,.30),fy=-.08,by=.31,head=(-.25,.65),tail=(.44,.63),body=.65),
 'fox': dict(height=.53,front=(.70,.46,.15),back=(.76,.49,.30),fy=-.18,by=.13,head=(-.29,.79),tail=(.23,.65),body=.64,rotation=-math.pi/2),
 'hare': dict(height=.46,front=(.45,.29,.09),back=(.53,.31,.09),fy=-.20,by=.19,head=(-.24,.54),tail=(.37,.40),body=.42),
}


def ensure_lit_principled(material):
 tree=material.node_tree
 bs=tree.nodes.get('Principled BSDF')
 if bs:return bs
 output=next((n for n in tree.nodes if n.type=='OUTPUT_MATERIAL'),None)
 if output is None:output=tree.nodes.new('ShaderNodeOutputMaterial')
 albedo=None
 for node in tree.nodes:
  if node.type=='TEX_IMAGE' and node.image:
   albedo=node;break
  if node.type=='EMISSION' and node.inputs['Color'].links:
   src=node.inputs['Color'].links[0].from_node
   if src.type=='TEX_IMAGE':albedo=src;break
 bs=tree.nodes.new('ShaderNodeBsdfPrincipled');bs.name='Principled BSDF'
 if albedo:tree.links.new(albedo.outputs['Color'],bs.inputs['Base Color'])
 for link in list(output.inputs['Surface'].links):tree.links.remove(link)
 tree.links.new(bs.outputs['BSDF'],output.inputs['Surface'])
 return bs


def clear():
 bpy.ops.wm.read_factory_settings(use_empty=True)


def bounds(meshes):
 pts=[o.matrix_world@v.co for o in meshes for v in o.data.vertices]
 return (Vector(tuple(min(p[i] for p in pts) for i in range(3))),Vector(tuple(max(p[i] for p in pts) for i in range(3))))


def load_surface(species):
 cfg=CONFIG[species];path=BUILD/'sources'/f'{species}.glb'
 if not path.exists():raise FileNotFoundError(f'Restore licensed source: {path}')
 bpy.ops.import_scene.gltf(filepath=str(path),guess_original_bind_pose=False,disable_bone_shape=True)
 for o in bpy.context.scene.objects:
  if o.type=='ARMATURE':o.data.pose_position='REST'
 bpy.context.view_layer.update()
 meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
 if species=='fox' and cfg.get('anatomy_source'):
  for o in list(meshes):
   if not any(m and m.name in ('Skin','Eyeballs') for m in o.data.materials):
    bpy.data.objects.remove(o,do_unlink=True);meshes.remove(o)
 # Bake only the source transforms/rest skin. Preserve authored topology/UVs.
 deps=bpy.context.evaluated_depsgraph_get()
 for o in meshes:
  mat=o.matrix_world.copy();mesh=bpy.data.meshes.new_from_object(o.evaluated_get(deps),preserve_all_data_layers=True,depsgraph=deps)
  o.parent=None;o.animation_data_clear();o.modifiers.clear();o.data=mesh;o.data.transform(mat);o.matrix_world=Matrix.Identity(4);o.vertex_groups.clear()
 for o in list(bpy.context.scene.objects):
  if o not in meshes:bpy.data.objects.remove(o,do_unlink=True)
 for action in list(bpy.data.actions):bpy.data.actions.remove(action)
 if species=='fox':
  # Source exporter split one surface at the 16-bit index limit. Rejoin its
  # coincident chunk boundaries before decimation to avoid cracks everywhere.
  bpy.ops.object.select_all(action='DESELECT')
  for o in meshes:o.select_set(True)
  bpy.context.view_layer.objects.active=meshes[0];bpy.ops.object.join()
  meshes=[bpy.context.object]
  bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
  bpy.ops.mesh.remove_doubles(threshold=.000002);bpy.ops.object.mode_set(mode='OBJECT')

 rotation=Matrix.Rotation(cfg.get('rotation',0),4,'Z')
 for o in meshes:o.data.transform(rotation)
 lo,hi=bounds(meshes);scale=cfg['height']/(hi.z-lo.z);anchor=Vector(((lo.x+hi.x)/2,(lo.y+hi.y)/2,lo.z))
 total_tris=sum(len(p.vertices)-2 for o in meshes for p in o.data.polygons)
 for o in meshes:
  for v in o.data.vertices:v.co=(v.co-anchor)*scale
  for f in o.data.polygons:f.use_smooth=True
  tris=sum(len(p.vertices)-2 for p in o.data.polygons)
  if total_tris>48000:
   bpy.context.view_layer.objects.active=o
   dec=o.modifiers.new('Preserve sculpt silhouette','DECIMATE');dec.ratio=38000/total_tris
   bpy.ops.object.modifier_apply(modifier=dec.name)
 # Keep actual source maps and material response; scale textures, never UV-remesh.
 for image in bpy.data.images:
  if image.type=='IMAGE' and max(image.size)>1024:
   factor=1024/max(image.size);image.scale(round(image.size[0]*factor),round(image.size[1]*factor))
 for m in bpy.data.materials:
  if not m.use_nodes:m.use_nodes=True
  # Sketchfab game-ready coats can arrive as KHR_materials_unlit / Emission.
  # Keep the albedo map, but ship a dielectric so night lighting can darken them.
  bs=ensure_lit_principled(m)
  bs.inputs['Metallic'].default_value=0
  for link in list(bs.inputs['Metallic'].links):m.node_tree.links.remove(link)
  bs.inputs['Emission Strength'].default_value=0
  bs.inputs['Emission Color'].default_value=(0,0,0,1)
  for port in ('Emission Color','Roughness'):
   for link in list(bs.inputs[port].links):m.node_tree.links.remove(link)
  bs.inputs['Roughness'].default_value=.86
  for node in m.node_tree.nodes:
   if node.type=='NORMAL_MAP':node.inputs['Strength'].default_value=.4
  # Source models occasionally pack constant metallic into a color-map channel.
 if species=='fox':
  # Godot uses the primary UV for normal maps. Bake the source's separate
  # normal atlas into that UV instead of silently sampling the wrong atlas.
  o=meshes[0];m=o.data.materials[0];nodes=m.node_tree.nodes
  normal=next(n for n in nodes if n.type=='NORMAL_MAP')
  baked=bpy.data.images.new('Fox_Normal_PrimaryUV',width=1024,height=1024,alpha=False);baked.colorspace_settings.name='Non-Color'
  target=nodes.new('ShaderNodeTexImage');target.image=baked;nodes.active=target
  bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
  o.data.uv_layers.active_index=0;bpy.context.scene.render.engine='CYCLES';bpy.context.scene.cycles.samples=1
  bpy.ops.object.bake(type='NORMAL',normal_space='TANGENT',margin=8)
  for link in list(normal.inputs['Color'].links):m.node_tree.links.remove(link)
  m.node_tree.links.new(target.outputs['Color'],normal.inputs['Color']);normal.uv_map=o.data.uv_layers[0].name
  normal.inputs['Strength'].default_value=1;baked.pack()
 for o in meshes:
  o.name=f'{species}_surface'
  if species=='forge_cat':
   for m in o.data.materials:m.name='forge_cat_coat'
 return meshes


def measure_feet(meshes,cfg):
 lo,hi=bounds(meshes);h=cfg['height'];length=hi.y-lo.y
 verts=[v.co.copy() for o in meshes for v in o.data.vertices]
 feet={}
 for side,sign in [('L',1),('R',-1)]:
  for end,pred in [('F',cfg['fy']),('B',cfg['by'])]:
   y=pred*length
   pool=[p for p in verts if p.x*sign>.015*h and abs(p.y-y)<.14*length and p.z<.27*h]
   if not pool:raise ValueError(f'No {side+end} source foot near {y}')
   floor=min(p.z for p in pool)
   contact=[p for p in pool if p.z<floor+.032*h]
   # Robust contact centre, insensitive to dense digit or fur-card vertices.
   x=(min(p.x for p in contact)+max(p.x for p in contact))/2
   rear=max(p.y for p in contact);front=min(p.y for p in contact)
   feet[side+end]=(x,rear-(rear-front)*.20,floor+.035*h,front,rear)
 return feet,length


def skin_fallback(obj,rig):
 # Source shells can defeat heat diffusion. Use continuous anatomical masks:
 # the underside midline belongs to the trunk, never to opposite distal legs.
 if all(v.groups and sum(g.weight for g in v.groups)>.0001 for v in obj.data.vertices):return
 obj.vertex_groups.clear()
 h=CONFIG[rig['species']]['height']
 def smooth(a,b,x):
  t=max(0,min(1,(x-a)/(b-a)));return t*t*(3-2*t)
 for v in obj.data.vertices:
  p=v.co
  side='L' if p.x>=0 else 'R'
  fore=rig.data.bones['Leg.'+side+'F'].head_local
  rear=rig.data.bones['Leg.'+side+'B'].head_local
  df=abs(p.y-fore.y);db=abs(p.y-rear.y)
  family=side+('F' if df<db else 'B')
  limb_mix=(1-smooth(.28*h,.70*h,p.z))*max(smooth(.035*h,.16*h,abs(p.x)),1-smooth(.12*h,.28*h,p.z))
  # No competing front/rear palette across the flank: blend to the trunk in
  # the interval between limbs before switching the three-bone leg palette.
  limb_mix*=smooth(0,.55,abs(df-db)/max(df+db,.001))*smooth(0,.08*h,abs(p.x))
  entries=[]
  for name in ('Leg.','Shin.','Ankle.','Foot.'):
   bone=rig.data.bones[name+family];a=bone.head_local;e=bone.tail_local
   delta=e-a;t=max(0,min(1,(p-a).dot(delta)/max(delta.length_squared,1e-8)))
   entries.append((1/max((p-a-delta*t).length,.025*h)**2,bone.name))
  entries=sorted([e for e in entries if not e[1].startswith('Foot.')],reverse=True)[:2]+[next(e for e in entries if e[1].startswith('Foot.'))];total=sum(w for w,_ in entries)
  sole=1-smooth(.055*h,.13*h,p.z)
  weights=[((w/total*(1-sole)+ (sole if n.startswith('Foot.') else 0))*limb_mix,n) for w,n in entries]+[(1-limb_mix,'Body')]
  # Head and tail retain a smooth base transition outside the limb envelope.
  if limb_mix<.001:
   head=smooth(fore.y-.03*h,fore.y-.22*h,p.y)
   tail=smooth(rear.y+.08*h,rear.y+.28*h,p.y)
   weights=[(max(0,1-head-tail),'Body'),(head,'Head'),(tail,'Tail')]
  for w,n in weights:
   if w<=0:continue
   vg=obj.vertex_groups.get(n) or obj.vertex_groups.new(name=n);vg.add([v.index],w,'REPLACE')


def reachable_stride(limbs,stride,clearance):
 # Source legs have different rest flexion. Keep their measured bone lengths
 # and shorten the step if needed; expose that distance for runtime speed sync.
 for _ in range(35):
  try:
   for limb in limbs:
    for f in range(97):
     travel,lift,_=foot_path(f/96,stride,clearance)
     pose_points(limb,travel,lift)
   return stride
  except ValueError:stride*=.92
 raise ValueError('Source limb cannot execute a grounded stride')


def create_rig(meshes,species):
 cfg=CONFIG[species];h=cfg['height'];feet,length=measure_feet(meshes,cfg)
 skeleton=bpy.data.armatures.new('AnatomicalRig');rig=bpy.data.objects.new('AnatomicalRig',skeleton);bpy.context.collection.objects.link(rig)
 rig['species']=species
 bpy.context.view_layer.objects.active=rig;rig.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
 def bone(name,start,end,parent=None):
  b=skeleton.edit_bones.new(name);b.head=start;b.tail=end
  if parent:b.parent=skeleton.edit_bones[parent]
  return b
 bz=h*cfg['body']
 bone('Body',(0,0,bz),(0,0,bz+.13*h))
 hy,hz=cfg['head'];bone('Head',(0,hy*length,hz*h),(0,hy*length-.16*h,hz*h+.02*h),'Body')
 ty,tz=cfg['tail'];bone('Tail',(0,ty*length,tz*h),(0,ty*length+.14*h,tz*h-.03*h),'Body')
 limbs=[]
 for suffix,(x,y,z,front,rear) in feet.items():
  hind=suffix.endswith('B');hs=cfg['back' if hind else 'front']
  root_y=y+(.018*h if not hind else -.035*h)
  root=(x*.87,root_y,hs[0]*h)
  knee=(x,root_y+(-.17*h if hind else .095*h),hs[1]*h)
  ankle=(x,y+(.08*h if hind else .015*h),hs[2]*h)
  if species=='hare' and hind:ankle=(x,rear+.015*h,hs[2]*h)
  ball=(x,y,z);toe=(x,min(front,y-.035*h),z*.7)
  limb=Limb(suffix,(root,knee,ankle,ball,toe),.03*h,.035*h,.035*h,2 if species in ('sheep','goat','pig','boar') else 4,species in ('sheep','goat','pig','boar'))
  parent='Body'
  for i,n in enumerate(limb.bones):bone(n,limb.points[i],limb.points[i+1],parent);parent=n
  limbs.append(limb)
 bpy.ops.object.mode_set(mode='OBJECT')
 # Heat weights follow existing flesh continuity instead of transferring weights
 # from placeholder anatomy. Limit to four influences for portable Godot skinning.
 bpy.ops.object.select_all(action='DESELECT')
 for o in meshes:o.select_set(True)
 rig.select_set(True);bpy.context.view_layer.objects.active=rig
 bpy.ops.object.parent_set(type='ARMATURE_AUTO')
 for o in meshes:
  bpy.context.view_layer.objects.active=o
  skin_fallback(o,rig)
  bpy.ops.object.vertex_group_limit_total(limit=4)
  bpy.ops.object.vertex_group_normalize_all(lock_active=False)
  if any(not v.groups for v in o.data.vertices):raise ValueError(f'Unweighted source vertices in {species}')
 rig['species']=species;rig['source_surface_preserved']=True;rig['anatomy_revision']='sculpted-v3'
 return rig,limbs,bz


def animate(rig,limbs,species,bz):
 rig.animation_data_create();cfg=CONFIG[species];h=cfg['height']
 walk_stride=reachable_stride(limbs,bz*(.50 if species=='hare' else .48),bz*.075)
 run_stride=reachable_stride(limbs,bz*(.60 if species=='hare' else .65),bz*.11)
 rig['walk_reference_speed']=walk_stride/(.72 if species=='hare' else .68)
 rig['run_reference_speed']=run_stride/.58
 clips=['Idle','Walk','LookAround','Run','Graze','Alert']+(['Sleep','Groom','Stretch'] if species=='forge_cat' else [])
 for clip in clips:
  action=bpy.data.actions.new(clip);action.use_fake_user=True;rig.animation_data.action=action
  for f in range(49):
   phase=f/48;t=phase*math.tau
   for pb in rig.pose.bones:pb.rotation_mode='QUATERNION';pb.matrix_basis.identity()
   angle=.014*math.sin(t)
   if clip=='LookAround':angles=(.035*math.sin(t),0,.20*math.sin(t))
   elif clip=='Graze':angles=(.34*(1-math.cos(t))*.5,0,angle)
   elif clip=='Alert':angles=(-.08*(1-math.cos(t))*.5,0,angle)
   elif clip=='Groom':angles=(.22+.03*math.sin(t*2),0,.19)
   elif clip=='Sleep':angles=(.12+angle*.2,0,.04)
   elif clip=='Stretch':angles=(.12*(1-math.cos(t))*.5,0,0)
   else:angles=(angle,0,angle*.5)
   rig.pose.bones['Head'].rotation_quaternion=Euler(angles).to_quaternion()
   rig.pose.bones['Tail'].rotation_quaternion=Euler((.018*math.sin(t),.045*math.sin(t),0)).to_quaternion()
   drop= -.12 if clip=='Sleep' else -.07 if clip=='Groom' else -.025*(1-math.cos(t))*.5 if clip=='Stretch' else 0.0
   rig.pose.bones['Body'].location.y=drop
   poses={'Body':rig.data.bones['Body'].matrix_local@rig.pose.bones['Body'].matrix_basis}
   for limb in limbs:
    travel=lift=0
    if clip in ('Walk','Run'):
     run=clip=='Run';phases={'LB':0,'LF':.25,'RB':.5,'RF':.75} if not run else {'LF':0,'RB':0,'RF':.5,'LB':.5}
     if species=='hare':phases={'LB':0,'RB':.025,'LF':.46,'RF':.52}
     duty=.58 if run else .72 if species=='hare' else .68
     stride=run_stride if run else walk_stride
     travel,lift,_=foot_path(phase-phases[limb.suffix],stride,bz*(.11 if run else .075),duty)
    points=pose_points(limb,travel,lift,body_drop=drop)
    for i,n in enumerate(limb.bones):
     pb=rig.pose.bones[n];rest=pb.bone.matrix_local;start,end=map(Vector,points[i:i+2])
     rotation=(pb.bone.tail_local-pb.bone.head_local).rotation_difference(end-start).to_matrix().to_4x4()
     desired=Matrix.Translation(start)@rotation@rest.to_3x3().to_4x4()
     pb.matrix_basis=rest.inverted()@pb.parent.bone.matrix_local@poses[pb.parent.name].inverted()@desired;poses[n]=desired
   for pb in rig.pose.bones:
    pb.keyframe_insert('rotation_quaternion',frame=f,group=pb.name);pb.keyframe_insert('location',frame=f,group=pb.name)
  for layer in action.layers:
   for strip in layer.strips:
    for bag in strip.channelbags:
     for fc in bag.fcurves:
      for key in fc.keyframe_points:key.interpolation='LINEAR'
  rig.animation_data.action=None
 bpy.context.scene.render.fps=48
 for pb in rig.pose.bones:pb.matrix_basis.identity()


def build(species,out):
 manifest=json.loads((ROOT/'assets/storybook/mammal_sources.json').read_text())['models'][species]
 source=BUILD/'sources'/f'{species}.glb'
 if hashlib.sha256(source.read_bytes()).hexdigest()!=manifest['sha256']:raise ValueError(f'{species}: source checksum mismatch')
 if species=='rat':
  clear();runpy.run_path(str(Path(__file__).with_name('import_authored_rat.py')),run_name='__main__')
  subprocess.run(['/usr/bin/python3',str(Path(__file__).with_name('pack_authored_rat.py'))],check=True)
  out.mkdir(parents=True,exist_ok=True)
  if out.resolve()!=(BUILD/'candidates').resolve():shutil.copy2(BUILD/'candidates/rat.glb',out/'rat.glb')
  return
 clear();meshes=load_surface(species);rig,limbs,bz=create_rig(meshes,species);animate(rig,limbs,species,bz)
 rig['source_author']=manifest['author'];rig['source_url']=manifest['url'];rig['license']=manifest['license'];rig['source_sha256']=manifest['sha256']
 bpy.context.scene.frame_set(0);bpy.context.view_layer.update()
 out.mkdir(parents=True,exist_ok=True)
 bpy.ops.export_scene.gltf(filepath=str(out/f'{species}.glb'),export_format='GLB',export_animations=True,export_animation_mode='ACTIONS',export_skins=True,export_def_bones=False,export_extras=True,export_yup=True)
 bpy.ops.wm.save_as_mainfile(filepath=str(BUILD/'candidates'/f'{species}.blend'))
 (BUILD/'candidates'/f'{species}_rig.json').write_text(json.dumps({'body_height':bz,'limbs':{l.suffix:l.points for l in limbs}},indent=2))


def main():
 p=argparse.ArgumentParser();p.add_argument('--only',choices=list(CONFIG)+['rat']);p.add_argument('--publish',action='store_true');args=p.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
 out=ROOT/'assets/storybook' if args.publish else BUILD/'candidates';(BUILD/'candidates').mkdir(exist_ok=True)
 for species in [args.only] if args.only else [*CONFIG,'rat']:build(species,out)

if __name__=='__main__':main()
