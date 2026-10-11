"""Original smith hammer and plain one-handed sword for the fresh grip socket."""
from pathlib import Path
import bpy,math
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3];OUT=ROOT/'assets/characters/kalev_fresh'
bpy.ops.wm.read_factory_settings(use_empty=True)

def mat(name,color,rough,metal):
    m=bpy.data.materials.new(name);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal;return m
steel=mat('fresh_forged_steel',(.28,.31,.32),.38,.92);edge=mat('fresh_ground_edge',(.48,.51,.52),.24,.94);wood=mat('fresh_ash_handle',(.18,.10,.045),.77,0);leather=mat('fresh_grip_leather',(.065,.029,.016),.78,0)

def cube(name,pos,size,material,bevel=.004):
    bpy.ops.mesh.primitive_cube_add(size=1,location=pos);o=bpy.context.object;o.name=name;o.scale=size;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(material)
    mod=o.modifiers.new('ForgedEdges','BEVEL');mod.width=bevel;mod.segments=3;bpy.ops.object.modifier_apply(modifier=mod.name)
    normal=o.modifiers.new('FaceNormals','WEIGHTED_NORMAL');bpy.ops.object.modifier_apply(modifier=normal.name)
    return o

def cylinder(name,pos,radius,depth,material):
    bpy.ops.mesh.primitive_cylinder_add(vertices=24,radius=radius,depth=depth,location=pos);o=bpy.context.object;o.name=name;o.data.materials.append(material)
    for p in o.data.polygons:p.use_smooth=True
    return o

def export(name,objects):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:o.select_set(True)
    (OUT / name).mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(OUT/f'{name}/{name}.glb'),export_format='GLB',use_selection=True,export_animations=False)
    for o in objects:bpy.data.objects.remove(o,do_unlink=True)

hammer=[cylinder('AshHaft',(0,0,.085),.015,.42,wood),cube('HammerFace',(-.004,0,.285),(.165,.065,.073),steel,.008),cylinder('HaftFerrule',(0,0,.232),.019,.035,steel)]
export('hammer',hammer)
# Lenticular cross section and taper form a blade, rather than a flat box.
verts=[]
for z,w,d in [(.16,.027,.006),(.62,.020,.004),(.85,.012,.003),(.96,0,.001)]:verts.extend([(-w,0,z),(0,-d,z),(w,0,z),(0,d,z)])
faces=[]
for j in range(3):
    for i in range(4):faces.append((j*4+i,j*4+(i+1)%4,(j+1)*4+(i+1)%4,(j+1)*4+i))
mesh=bpy.data.meshes.new('LenticularBlade');mesh.from_pydata(verts,[],faces);mesh.materials.append(edge);blade=bpy.data.objects.new('LenticularBlade',mesh);bpy.context.collection.objects.link(blade)
sword=[blade,cylinder('WrappedGrip',(0,0,.042),.017,.19,leather),cube('Crossguard',(0,0,.155),(.205,.023,.024),steel,.006),cylinder('Pommel',(0,0,-.071),.031,.029,steel)]
export('sword',sword)
