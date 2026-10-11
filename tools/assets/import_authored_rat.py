"""Preserve and adapt Nestaeric’s CC BY 4.0 rat source; see mammal_sources.json."""
import bpy,json,math,numpy as np
from pathlib import Path
from mathutils import Matrix,Vector
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'build/animal_redo/candidates';OUT.mkdir(exist_ok=True)
SOURCE=ROOT/'build/animal_redo/sources/rat.glb'
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(SOURCE),guess_original_bind_pose=False,bone_heuristic='BLENDER',disable_bone_shape=True)
scene=bpy.context.scene;scene.render.fps=60
# Import actions were created against original 24fps. Keep authored seconds.
scene.render.fps=24
arm=next(o for o in scene.objects if o.type=='ARMATURE')
meshes=[o for o in scene.objects if o.type=='MESH' and any(m.type=='ARMATURE' for m in o.modifiers)]
used=set()
for o in meshes:
 for v in o.data.vertices:
  for g in v.groups:
   if g.weight>1e-8:used.add(o.vertex_groups[g.group].name)
keep=set(used)
for n in used:
 b=arm.data.bones[n]
 while b.parent:b=b.parent;keep.add(b.name)
bpy.context.view_layer.objects.active=arm;arm.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
for b in list(arm.data.edit_bones):
 if b.name not in keep:arm.data.edit_bones.remove(b)
bpy.ops.object.mode_set(mode='OBJECT')
for o in meshes:
 for g in list(o.vertex_groups):
  if g.name not in keep:o.vertex_groups.remove(g)
# Six aliases retain complete authored loops. No start/stop clips.
mapping={'Idle':'idle_A1','Walk':'walk_A1','Run':'run_A1','LookAround':'idle_A2','Graze':'idle_A3','Alert':'idle_A2'}
source_actions={a.name:a for a in bpy.data.actions}
for t in list(arm.animation_data.nla_tracks):arm.animation_data.nla_tracks.remove(t)
arm.animation_data.action=None
newactions=[]
for alias,original in mapping.items():
 action=source_actions['Mammals|'+original].copy();action.name=alias;action['source_clip']='Mammals|'+original
 for layer in action.layers:
  for strip in layer.strips:
   bag=strip.channelbag(action.slots[0])
   for fc in list(bag.fcurves):
    if fc.data_path.startswith('pose.bones['):
     bone=fc.data_path.split('"')[1]
     if bone not in keep:bag.fcurves.remove(fc)
 for layer in action.layers:
  for strip in layer.strips:
   for fc in strip.channelbag(action.slots[0]).fcurves:
    for kp in fc.keyframe_points:
     kp.co.x*=2.5;kp.handle_left.x*=2.5;kp.handle_right.x*=2.5
 action.use_fake_user=True;newactions.append(action)
 track=arm.animation_data.nla_tracks.new();track.name=alias;strip=track.strips.new(alias,0,action);track.mute=True
scene.render.fps=60
for action in list(bpy.data.actions):
 if action not in newactions:bpy.data.actions.remove(action)
# Preserve mesh-space and armature-space relationship; scale one parent uniformly.
wrapper=bpy.data.objects.new('Rat_Source',None);scene.collection.objects.link(wrapper)
for o in list(scene.objects):
 if o!=wrapper and o.parent is None:o.parent=wrapper

def evaluate():
 deps=bpy.context.evaluated_depsgraph_get();out=[]
 for o in meshes:
  ev=o.evaluated_get(deps);me=ev.to_mesh();coords=np.empty(len(me.vertices)*3);me.vertices.foreach_get('co',coords);m=np.array(o.matrix_world);out.append(coords.reshape(-1,3)@m[:3,:3].T+m[:3,3]);ev.to_mesh_clear()
 return np.concatenate(out)
arm.data.pose_position='REST';bpy.context.view_layer.update();pts=evaluate();lo=pts.min(axis=0);hi=pts.max(axis=0)
scale=.42/(hi[1]-lo[1]);wrapper.scale=(scale,)*3;bpy.context.view_layer.update();pts=evaluate();rest_low=pts.min(axis=0);wrapper.location.z=-float(rest_low[2]);bpy.context.view_layer.update();pts=evaluate();rest_bounds=[pts.min(axis=0).tolist(),pts.max(axis=0).tolist()]
arm.data.pose_position='POSE'
wrapper['source_author']='Nestaeric';wrapper['source_url']='https://sketchfab.com/3d-models/black-rat-free-download-3db3acb4140d4de8bd62a171212bad9c';wrapper['license']='CC-BY-4.0';wrapper['source_path']='build/animal_redo/sources/rat.glb';wrapper['build_script']='tools/assets/import_authored_rat.py';wrapper['source_clip_aliases']=json.dumps(mapping);wrapper['source_import_fix']='guess_original_bind_pose=False';wrapper['forward']='Blender -Y; glTF/Godot +Z';wrapper['overall_rest_length_m']=.42
# Rat fur and skin are dielectric. Calm source specular noise consistently with other candidates.
for o in meshes:
 for material in o.data.materials:
  nodes=material.node_tree.nodes;links=material.node_tree.links
  shader=next(n for n in nodes if n.type=='BSDF_PRINCIPLED')
  for socket,value in [('Metallic',0.0),('Roughness',.82),('Specular IOR Level',.3)]:
   for link in list(shader.inputs[socket].links):links.remove(link)
   shader.inputs[socket].default_value=value
  for n in nodes:
   if n.type=='NORMAL_MAP':n.inputs['Strength'].default_value=.35
  if material.name=='blackrat_eyes':shader.inputs['Roughness'].default_value=.23
# Bake the fur's separate normal UV mapping into its primary UV set for Godot compatibility.
fur=next(o for o in meshes if any('fur' in m.name for m in o.data.materials));material=fur.data.materials[0];nodes=material.node_tree.nodes
normal=next(n for n in nodes if n.type=='NORMAL_MAP')
baked=bpy.data.images.new('Rat_Fur_Normal_PrimaryUV',width=1024,height=1024,alpha=False);baked.colorspace_settings.name='Non-Color'
target=nodes.new('ShaderNodeTexImage');target.image=baked;nodes.active=target
for o in scene.objects:o.select_set(False)
fur.select_set(True);bpy.context.view_layer.objects.active=fur
fur.data.uv_layers.active_index=0;scene.render.engine='CYCLES';scene.cycles.samples=1
bpy.ops.object.bake(type='NORMAL',normal_space='TANGENT',margin=8)
for link in list(normal.inputs['Color'].links):material.node_tree.links.remove(link)
material.node_tree.links.new(target.outputs['Color'],normal.inputs['Color']);normal.uv_map=fur.data.uv_layers[0].name
# Remove disconnected source map nodes, keeping only shader dependencies.
for material in {m for o in meshes for m in o.data.materials}:
 nodes=material.node_tree.nodes;needed=set();stack=[n for n in nodes if n.type=='OUTPUT_MATERIAL']
 while stack:
  n=stack.pop()
  if n in needed:continue
  needed.add(n)
  stack.extend(link.from_node for inp in n.inputs for link in inp.links)
 for n in list(nodes):
  if n not in needed:nodes.remove(n)

# Resize only maps that materials actually use and pack pixels as PNG.
images=set()
for o in meshes:
 for material in o.data.materials:
  for node in material.node_tree.nodes:
   if node.type=='TEX_IMAGE' and node.image:images.add(node.image)
for image in images:
 if max(image.size)>1024:image.scale(1024,1024)
 image.file_format='PNG';image.pack()
for image in list(bpy.data.images):
 if image not in images:bpy.data.images.remove(image)
# Keep source alpha-mask threshold and all texture UV sets.
for material in bpy.data.materials:
 if material.name=='blackrat_fur':material['source_alpha_cutoff']=.6811449330131292
# Evaluate authored foot motion in candidate metres. Toe/hand groups identify only extremities.
footsets={}
for foot,prefixes in {'LF':['Fore_Finger.L.','Fore_Hand.L.'],'RF':['Fore_Finger.R.','Fore_Hand.R.'],'LB':['Leg_Toe.L.'],'RB':['Leg_Toe.R.']}.items():
 groups=[]
 for o in meshes:
  ids={g.index for g in o.vertex_groups if any(g.name.startswith(p) for p in prefixes)}
  vi=[v.index for v in o.data.vertices if sum(g.weight for g in v.groups if g.group in ids)>.7]
  if vi:groups.append((o,vi))
 footsets[foot]=groups
measure={}
for alias in ['Walk','Run']:
 action=next(a for a in newactions if a.name==alias);arm.animation_data.action=action;arm.animation_data.action_slot=action.slots[0]
 duration=(action.frame_range[1]-action.frame_range[0])/scene.render.fps;curves={f:[] for f in footsets}
 for phase in np.linspace(0,1,121):
  frame=action.frame_range[0]+phase*(action.frame_range[1]-action.frame_range[0]);scene.frame_set(int(frame),subframe=float(frame%1));deps=bpy.context.evaluated_depsgraph_get()
  for foot,sets in footsets.items():
   coords=[]
   for o,ids in sets:
    ev=o.evaluated_get(deps);me=ev.to_mesh();m=np.array(o.matrix_world);co=np.array([me.vertices[i].co[:] for i in ids]);coords.append(co@m[:3,:3].T+m[:3,3]);ev.to_mesh_clear()
   points=np.concatenate(coords);curves[foot].append([float(np.mean(points[:,1])),float(np.percentile(points[:,2],10))])
 perfoot={};allvel=[]
 for foot,points in curves.items():
  a=np.array(points);v=np.diff(a[:,0])/(duration/120);z=(a[:-1,1]+a[1:,1])/2;contact=(z<np.quantile(z,.35))&(v>0)
  vel=v[contact];allvel.extend(vel.tolist());perfoot[foot]={'contact_speed_mps':float(np.median(vel)) if len(vel) else None,'sole_z_min_m':float(a[:,1].min()),'sole_z_max_m':float(a[:,1].max()),'stance_samples':int(contact.sum())}
 speed=float(np.median(allvel));measure[alias]={'duration_seconds':duration,'reference_speed_mps':speed,'distance_per_clip_m':speed*duration,'feet':perfoot}
 wrapper[alias.lower()+'_reference_speed_mps']=speed
idle=next(a for a in newactions if a.name=='Idle');arm.animation_data.action=idle;arm.animation_data.action_slot=idle.slots[0];scene.frame_set(0)
# Delete unused datablocks after all imports, but preserve six source-derived actions.
for material in list(bpy.data.materials):
 if material.users==0:bpy.data.materials.remove(material)
for o in meshes:o.select_set(True)
arm.select_set(True)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'rat.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'rat.glb'),export_format='GLB',export_animations=True,export_animation_mode='NLA_TRACKS',export_extras=True,export_image_format='AUTO',export_force_sampling=True)
report={'source_triangles':31358,'kept_weighted_bones':len(used),'bones_with_ancestors':len(keep),'source_scale_multiplier':scale,'rest_bounds_m':rest_bounds,'clip_aliases':mapping,'motion':measure,'source_credit':dict(wrapper.items())}
(OUT/'rat_rig.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
