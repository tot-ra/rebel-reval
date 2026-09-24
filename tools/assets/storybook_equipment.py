"""Fitted wardrobe and rigid props for the storybook shared-rig candidates.

Called by build_storybook_models.py inside Blender. Runtime mounting remains
SharedCharacterRig + CharacterWearable, not a separate equipment system.
"""
import math
from pathlib import Path
import bpy
from mathutils import Vector


def selected_export(a, objects, path, skin=True):
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects: obj.select_set(True)
    if skin: a.RIG.select_set(True)
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(path), export_format='GLB', use_selection=True,
        export_animations=False, export_skins=skin, export_def_bones=False, export_yup=True)


def wearable_resource(a, name, kind, slot, covered):
    folder=a.OUT/'equipment'
    names=', '.join('&"'+p+'"' for p in covered)
    (folder/f'{name}_{kind}.tres').write_text(f'''[gd_resource type="Resource" script_class="CharacterWearable" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/characters/character_wearable.gd" id="1"]
[ext_resource type="PackedScene" path="res://assets/storybook/equipment/{name}_{kind}.glb" id="2"]

[resource]
script = ExtResource("1")
stable_id = &"wearable.storybook.{name}.{kind}"
slot = "{slot}"
fitted_body = "{name}"
scene = ExtResource("2")
covered_meshes = Array[StringName]([{names}])
''')


def build_wearables(a, name, p):
    bodies=[o for o in bpy.data.objects if o.type=='MESH']
    head=a.RIG.data.bones['head'].head_local
    hz=head.z; s=hz/1.461
    h=a.RIG.data.bones['hips'].head_local.z
    sp=a.RIG.data.bones['spine'].head_local.z
    c=a.RIG.data.bones['chest'].head_local.z
    a.RIG.animation_data.action=None
    for pb in a.RIG.pose.bones: pb.matrix_basis.identity()
    for kind in ('mail','helmet','cape'):
        a.PARTS=[]
        if kind=='mail':
            for obj in bodies:
                if obj.name not in ('Clothing_Torso','Clothing_Sleeve','Clothing_Cuffs'): continue
                dup=obj.copy(); dup.data=obj.data.copy(); bpy.context.collection.objects.link(dup)
                dup.name='Mail_'+obj.name
                dup.parent=None
                dup.modifiers.clear()
                dup.data.materials.clear();dup.data.materials.append(p['mail'])
                for face in dup.data.polygons:face.material_index=0
                a.PARTS.append(dup)
            # Readable links at torso scale. Small ring geometry is budgeted.
            for row in range(0 if name == 'kalev' else 7):
                z=sp+.025*s+row*.032*s
                w=min(1.0,max(0.0,(z-sp)/(c-sp)))
                for col in range(9):
                    x=(col-4)*.036*s+(row%2)*.012*s
                    y=-.161*s+.04*s*(x/(.23*s))**2
                    bpy.ops.mesh.primitive_torus_add(major_segments=10,minor_segments=4,
                        location=(x,y,z),rotation=(math.pi/2,0,0),major_radius=.015*s,minor_radius=.003*s)
                    a.finish(bpy.context.object,'Mail link',p['steel'],{'spine':1-w,'chest':w})
            slot='torso'; covered=['Clothing_Torso','Clothing_Sleeve','Clothing_Cuffs','Clothing_Outerwear']
        elif kind=='helmet':
            # Kettle hat: round crown, broad brim, no face-concealing visor.
            obj=a.oval('Kettle crown',(0,0,hz+.242*s),(.111*s,.105*s,.072*s),p['steel'],'head',32,16)
            # Remove the lower hemisphere to keep face clearance.
            import bmesh
            bm=bmesh.new();bm.from_mesh(obj.data)
            bmesh.ops.delete(bm,geom=[v for v in bm.verts if v.co.z < -.005*s],context='VERTS')
            bm.to_mesh(obj.data);bm.free()
            a.oval('Kettle brim',(0,0,hz+.238*s),(.150*s,.137*s,.012*s),p['steel'],'head',32,8)
            a.line('Brim seam',[(.150*s*math.cos(i*math.tau/16),.137*s*math.sin(i*math.tau/16),hz+.239*s) for i in range(17)],.007*s,p['leather_dark'],'head')
            slot='head';covered=['Hair_Scalp']
        else:
            rows=[(c+.09*s,.14*s,.10*s,{'chest':1}),
                  (c-.03*s,.25*s,.18*s,{'chest':1}),
                  (sp,.25*s,.19*s,{'spine':1}),
                  (h-.16*s,.26*s,.23*s,{'hips':1})]
            verts=[]
            for z,w,y,_ in rows:
                for j in range(13):
                    x=(j/12*2-1)*w
                    verts.append((x,y+.016*s*math.cos(j*math.pi/2),z))
            faces=[(r*13+j,r*13+j+1,(r+1)*13+j+1,(r+1)*13+j) for r in range(3) for j in range(12)]
            mesh=bpy.data.meshes.new('Cape');mesh.from_pydata(verts,[],faces);mesh.update()
            obj=bpy.data.objects.new('Cape',mesh);bpy.context.collection.objects.link(obj)
            bpy.context.view_layer.objects.active=obj;obj.select_set(True)
            a.finish(obj,'Wool cape',p['crimson'] if name!='kalev' else p['blue'],{})
            for r, row in enumerate(rows):
                for bone,weight in row[3].items():
                    vg=obj.vertex_groups.get(bone) or obj.vertex_groups.new(name=bone)
                    vg.add(list(range(r*13,(r+1)*13)),weight,'REPLACE')
            sol=obj.modifiers.new('Wool thickness','SOLIDIFY');sol.thickness=.008*s
            bpy.ops.object.modifier_apply(modifier=sol.name)
            slot='back';covered=[]
        if name == 'kalev':
            from kalev_realism_materials import unwrap
            unwrap(a.PARTS)
        objects=a.bind_join()
        objects[0].name='Wearable_'+kind
        selected_export(a,objects,a.OUT/'equipment'/f'{name}_{kind}.glb')
        wearable_resource(a,name,kind,slot,covered)
        for obj in objects:bpy.data.objects.remove(obj,do_unlink=True)
    # Thin wrapper uses the real runtime rig, with neutral proportions.
        (a.OUT / name).mkdir(parents=True, exist_ok=True)
    (a.OUT/name/f'{name}.tscn').write_text(f'''[gd_scene load_steps=5 format=3]

[ext_resource type="Script" path="res://assets/storybook/storybook_character.gd" id="1"]
[ext_resource type="PackedScene" path="res://assets/storybook/{name}/{name}.glb" id="2"]

[ext_resource type="Script" path="res://assets/characters/shared/character_variant.gd" id="3"]

[sub_resource type="Resource" id="Variant"]
script = ExtResource("3")
stable_id = &"char.{name}"

[node name="Storybook_{name}" type="Node3D"]
script = ExtResource("1")
variant = SubResource("Variant")
model_scale = Vector3(1, 1, 1)
use_anatomical_muscles = false

[node name="Model" type="Node3D" parent="."]

[node name="ImportedHumanoid" parent="Model" instance=ExtResource("2")]
''')


def build_props(a):
    for kind in ('sword','shield','hammer'):
        a.reset();p=a.palette()
        if kind=='sword':
            a.segment('Leather grip',(0,0,-.09),(0,0,.07),.024,p['leather_dark'],{})
            a.oval('Pommel',(0,0,-.115),(.044,.025,.043),p['steel'],{})
            a.segment('Crossguard',(-.15,0,.09),(.15,0,.09),.021,p['steel'],{})
            # Faceted lenticular blade, with an actual pointed tip.
            verts=[(-.036,0,.12),(0,-.012,.12),(.036,0,.12),(0,.012,.12),
                   (-.029,0,.64),(0,-.009,.64),(.029,0,.64),(0,.009,.64),(0,0,.78)]
            faces=[(i,(i+1)%4,(i+1)%4+4,i+4) for i in range(4)]+[(i+4,(i+1)%4+4,8) for i in range(4)]+[(3,2,1,0)]
            mesh=bpy.data.meshes.new('Blade');mesh.from_pydata(verts,[],faces);mesh.update()
            obj=bpy.data.objects.new('Blade',mesh);bpy.context.collection.objects.link(obj)
            a.finish(obj,'Blade',p['steel'],{})
        elif kind=='hammer':
            a.segment('Ash handle',(0,0,-.13),(0,0,.3),.025,p['leather'],{})
            bpy.ops.mesh.primitive_cube_add(location=(0,0,.26));obj=bpy.context.object;obj.scale=(.13,.065,.062)
            a.finish(obj,'Hammer head',p['steel'],{})
            bevel=obj.modifiers.new('Forged edges','BEVEL');bevel.width=.02;bevel.segments=3
            bpy.context.view_layer.objects.active=obj;bpy.ops.object.modifier_apply(modifier=bevel.name)
        else:
            # Curved heater shield; origin is the left-hand grip.
            outline=[(-.22,.27),(-.21,-.06),(-.12,-.25),(0,-.34),(.12,-.25),(.21,-.06),(.22,.27)]
            verts=[(x,-.075+.018*(x/.22)**2,z) for x,z in outline]+[(0,-.115,.025)]
            faces=[(i,(i+1)%7,7) for i in range(7)]
            mesh=bpy.data.meshes.new('Shield');mesh.from_pydata(verts,[],faces);mesh.update()
            obj=bpy.data.objects.new('Shield',mesh);bpy.context.collection.objects.link(obj)
            a.finish(obj,'Painted wood shield',p['blue'],{})
            bpy.context.view_layer.objects.active=obj
            sol=obj.modifiers.new('Wood backing','SOLIDIFY');sol.thickness=.027
            bpy.ops.object.modifier_apply(modifier=sol.name)
            a.line('Leather rim',[(x,-.08+.018*(x/.22)**2,z) for x,z in outline+[outline[0]]],.014,p['leather'],{})
            a.line('Grip',[(0,-.04,-.085),(0,.015,-.07),(0,.015,.07),(0,-.04,.085)],.022,p['leather_dark'],{})
            a.line('Gold stripe',[(0,-.12,-.21),(0,-.12,.21)],.018,p['gold'],{})
        objects=list(a.PARTS)
        selected_export(a,objects,a.OUT/'equipment'/f'{kind}.glb',skin=False)
        bpy.ops.wm.save_as_mainfile(filepath=str(a.BUILD/f'{kind}.blend'))
        angle=math.pi/2 if kind=='sword' else (-math.pi/2 if kind=='hammer' else 0)
        (a.OUT/'equipment'/f'{kind}.tscn').write_text(f'''[gd_scene load_steps=2 format=3]

[ext_resource type="PackedScene" path="res://assets/storybook/equipment/{kind}.glb" id="1"]

[node name="{kind}" type="Node3D"]
rotation = Vector3(0, 0, {angle})

[node name="Visual" parent="." instance=ExtResource("1")]
''')
