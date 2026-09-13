"""Build an original fitted character from the new Hunyuan sculpt and references.

Blender 5.2. The only legacy input is the geometry-stripped CC0 motion rig.
Coordinates here are metres, Blender Z up, character front toward -Y.
"""
from pathlib import Path
import argparse, json, math, sys
import bpy, bmesh, numpy as np
from mathutils import Vector, Matrix
from mathutils.kdtree import KDTree

ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'assets/characters/kalev_rebuild'
WORK=ROOT/'build/kalev_rebuild'
REF=OUT/'reference'
HEIGHT=1.82


def activate(obj):
    bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj


def material(name,color,rough=.8,metal=0):
    mat=bpy.data.materials.new(name);mat.diffuse_color=(*color,1);mat.use_nodes=True
    p=mat.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal
    return mat


def surface_material(name,color,rough=.8,metal=0):
    mat=material('fresh_'+name,color,rough,metal)
    nodes=mat.node_tree.nodes;links=mat.node_tree.links;p=nodes.get('Principled BSDF')
    uv=nodes.new('ShaderNodeTexCoord');mapping=nodes.new('ShaderNodeMapping');mapping.inputs['Scale'].default_value=(12,12,12) if name=='mail' else (4,4,4);links.new(uv.outputs['UV'],mapping.inputs['Vector'])
    for channel in ('albedo','normal'):
        tex=nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(OUT/f'materials/{name}_{channel}.png'),check_existing=True);links.new(mapping.outputs[0],tex.inputs['Vector'])
        if channel=='normal':
            tex.image.colorspace_settings.name='Non-Color';normal=nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.25;links.new(tex.outputs['Color'],normal.inputs['Color']);links.new(normal.outputs[0],p.inputs['Normal'])
        else:links.new(tex.outputs['Color'],p.inputs['Base Color'])
    return mat


def texture_material(name,view,rough):
    mat=material(name,(.5,.35,.25),rough)
    nodes=mat.node_tree.nodes;image=nodes.new('ShaderNodeTexImage')
    # Bake the projection sampler's edge extension to a portable material atlas.
    # Reference plates remain immutable; this is a generated runtime texture.
    reference=bpy.data.images.load(str(REF/f'{view}.png'),check_existing=True)
    rgba=np.empty(len(reference.pixels),dtype=np.float32);reference.pixels.foreach_get(rgba)
    rgba=rgba.reshape(-1,4);nearest=projection_edge_map(view).reshape(-1)
    nearest=np.where(nearest>=0,nearest,np.arange(len(nearest)))
    atlas=bpy.data.images.new('fresh_projection_'+view,width=reference.size[0],height=reference.size[1],alpha=False)
    atlas.pixels.foreach_set(rgba[nearest].reshape(-1));atlas.filepath_raw=str(OUT/f'materials/skin_projection_{view}.png');atlas.file_format='PNG';atlas.save()
    image.image=atlas
    mat.node_tree.links.new(image.outputs['Color'],nodes.get('Principled BSDF').inputs['Base Color'])
    return mat


def segment_distance(p,a,b):
    v=b-a;t=max(0,min(1,(p-a).dot(v)/v.length_squared));return (p-a-v*t).length


# Anatomical landmarks from the NEW reference. A-pose before binding.
A={
    'hips':((0,0,.94),(0,0,1.11)),
    'spine':((0,0,1.11),(0,0,1.34)),
    'chest':((0,0,1.34),(0,0,1.51)),
    'head':((0,0,1.53),(0,0,1.80)),
}
for side,sign in [('l',1),('r',-1)]:
    A.update({
        f'upperarm.{side}':((sign*.21,0,1.455),(sign*.30,0,1.185)),
        f'lowerarm.{side}':((sign*.30,0,1.185),(sign*.387,-.004,.957)),
        f'wrist.{side}':((sign*.387,-.004,.957),(sign*.404,-.006,.914)),
        f'hand.{side}':((sign*.404,-.006,.914),(sign*.434,-.006,.799)),
        f'upperleg.{side}':((sign*.12,0,.94),(sign*.137,-.012,.535)),
        f'lowerleg.{side}':((sign*.137,-.012,.535),(sign*.161,.015,.107)),
        f'foot.{side}':((sign*.161,.015,.107),(sign*.161,-.10,.035)),
        f'toes.{side}':((sign*.161,-.10,.035),(sign*.161,-.20,.027)),
    })
A={k:tuple(Vector(v) for v in points) for k,points in A.items()}


def skin_weights(p):
    x,y,z=p;side='l' if x>0 else 'r';ax=abs(x)
    def blend_candidates(candidates):
        distances=sorted((segment_distance(p,*A[k]),k) for k in candidates)[:3]
        scale=.060
        values=[(k,math.exp(-((d-distances[0][0])/scale)**2)) for d,k in distances]
        total=sum(v for _,v in values)
        return [(k,v/total) for k,v in values]
    arm_start=.17 if z>1.37 else .20+.33*(1.28-z)
    if z>.78 and ax>arm_start:
        arm=blend_candidates([f'{b}.{side}' for b in ('upperarm','lowerarm','wrist','hand')])
        torso=blend_candidates(['hips','spine','chest','head'])
        t=max(0,min(1,(ax-.17)/.065)) if z>1.37 else 1.0;t=t*t*(3-2*t)
        mixed=arm if t>=1 else [(k,w*t) for k,w in arm]+[(k,w*(1-t)) for k,w in torso]
        mixed=sorted(mixed,key=lambda a:a[1],reverse=True)[:4];total=sum(w for _,w in mixed)
        return [(k,w/total) for k,w in mixed if w>.0001]
    if z>1.48:return blend_candidates(['head','chest'])
    if z>.935:return blend_candidates(['hips','spine','chest'])
    candidates=[f'{b}.{side}' for b in ('upperleg','lowerleg','foot','toes')]
    if z>.83:candidates+=['hips']
    return blend_candidates(candidates)


def rig_fit(rig):
    old={b.name:(b.head_local.copy(),b.tail_local.copy()) for b in rig.data.bones}
    target={k:(a.copy(),b.copy()) for k,(a,b) in A.items()}
    # Use a T-pose bind so the existing motion deltas retain their meaning.
    for side,sign in [('l',1),('r',-1)]:
        cursor=Vector((sign*.21,0,1.455))
        for part in ('upperarm','lowerarm','wrist','hand'):
            name=f'{part}.{side}';length=(A[name][1]-A[name][0]).length
            tail=cursor+Vector((sign*length,0,0));target[name]=(cursor.copy(),tail.copy());cursor=tail
        hand=target[f'hand.{side}'];p=hand[0]+(hand[1]-hand[0])*.48
        target[f'handslot.{side}']=(p,p+Vector((0,-.10,0)))
    target['root']=(Vector((0,0,0)),Vector((0,0,.30)))
    activate(rig);bpy.ops.object.mode_set(mode='EDIT')
    for b in rig.data.edit_bones:
        b.use_connect=False
        if b.name in target:
            h,t=target[b.name];b.head=h;b.tail=t
        else:
            # Non-deforming animation controls stay in the skeleton for clip compatibility.
            b.head=old[b.name][0]*1.22;b.tail=old[b.name][1]*1.22
    bpy.ops.object.mode_set(mode='OBJECT')
    for track in rig.animation_data.nla_tracks:track.mute=True
    rig.animation_data.action=None
    for pb in rig.pose.bones:pb.matrix_basis=Matrix.Identity(4)
    return target


def author_relaxed_idle(rig):
    """Original restrained idle for the new adult anatomy; other clips retained."""
    old=bpy.data.actions.get('Idle')
    if old:bpy.data.actions.remove(old)
    idle=bpy.data.actions.new('Idle');rig.animation_data.action=idle
    for frame in (0,18,36,54,72):
        breath=math.sin(frame/72*math.tau)
        for pb in rig.pose.bones:
            pb.rotation_mode='QUATERNION';pb.matrix_basis=Matrix.Identity(4)
            if pb.name.startswith('upperarm.'):
                sign=1 if pb.name.endswith('.l') else -1
                rest=rig.data.bones[pb.name].matrix_local.to_3x3()
                pb.rotation_quaternion=(rest.transposed()@Matrix.Rotation(math.radians(sign*(71+.4*breath)),3,'Y')@rest).to_quaternion()
            elif pb.name=='chest':
                pb.scale=(1+.002*breath,1+.003*breath,1+.002*breath)
            for prop in ('location','rotation_quaternion','scale'):pb.keyframe_insert(data_path=prop,frame=frame,group=pb.name)
    idle.use_fake_user=True
    rig.animation_data.action=None
    for pb in rig.pose.bones:pb.matrix_basis=Matrix.Identity(4)


def author_locomotion(rig):
    """Original restrained walk/run cycles fitted to this adult body."""
    for clip,frames,leg_angle,arm_angle,knee_lift,bounce in [('Walking_A',32,22,15,38,.014),('Running_B',22,34,23,70,.030)]:
        old=bpy.data.actions.get(clip)
        if old:bpy.data.actions.remove(old)
        action=bpy.data.actions.new(clip);action.use_fake_user=True;rig.animation_data.action=action
        for frame in range(0,frames+1,2):
            phase=frame/frames*math.tau
            for pb in rig.pose.bones:
                pb.rotation_mode='QUATERNION';pb.matrix_basis=Matrix.Identity(4)
                rest=rig.data.bones[pb.name].matrix_local.to_3x3();world=Matrix.Identity(3)
                side=1 if pb.name.endswith('.l') else -1
                swing=math.sin(phase+(0 if side==1 else math.pi))
                if pb.name.startswith('upperleg.'):world=Matrix.Rotation(math.radians(leg_angle*swing),3,'X')
                elif pb.name.startswith('lowerleg.'):world=Matrix.Rotation(math.radians(knee_lift*max(0,-swing)),3,'X')
                elif pb.name.startswith('upperarm.'):world=Matrix.Rotation(math.radians(-arm_angle*swing),3,'X')@Matrix.Rotation(math.radians(side*77),3,'Y')
                elif pb.name.startswith('lowerarm.'):world=Matrix.Rotation(math.radians(-12 if clip=='Walking_A' else -35),3,'X')
                elif pb.name=='hips':pb.location.z=bounce*(1-math.cos(phase*2))*.5
                pb.rotation_quaternion=(rest.transposed()@world@rest).to_quaternion()
                for prop in ('location','rotation_quaternion','scale'):pb.keyframe_insert(data_path=prop,frame=frame,group=pb.name)
        rig.animation_data.action=None
    for pb in rig.pose.bones:pb.matrix_basis=Matrix.Identity(4)


def a_to_t(p,weights,target):
    result=Vector((0,0,0))
    for name,w in weights:
        if any(name.startswith(part) for part in ('upperarm.','lowerarm.','wrist.','hand.')):
            ah,at=A[name];th,tt=target[name]
            rot=(at-ah).rotation_difference(tt-th)
            result+=(th+rot@(p-ah))*w
        else:result+=p*w
    return result


def anatomical_weights(sculpt, rig):
    """Blender heat binding on a temporary A-pose rig; no old mesh input."""
    data=rig.data.copy();temp=bpy.data.objects.new('FreshAnatomicalBind',data);bpy.context.collection.objects.link(temp)
    activate(temp);bpy.ops.object.mode_set(mode='EDIT')
    for bone in data.edit_bones:
        bone.use_connect=False
        bone.use_deform=bone.name in A
        if bone.name in A:bone.head,bone.tail=A[bone.name]
    bpy.ops.object.mode_set(mode='OBJECT')
    bpy.ops.object.select_all(action='DESELECT');sculpt.select_set(True);temp.select_set(True);bpy.context.view_layer.objects.active=temp
    bpy.ops.object.parent_set(type='ARMATURE_AUTO')
    group_names={g.index:g.name for g in sculpt.vertex_groups}
    for name in A:
        attr=sculpt.data.attributes.new('skin_'+name,'FLOAT','POINT')
        for v in sculpt.data.vertices:
            attr.data[v.index].value=next((g.weight for g in v.groups if group_names[g.group]==name),0.0)
    empty=sum(not v.groups for v in sculpt.data.vertices)
    assert empty==0,('Automatic skinning left unweighted vertices',empty)
    sculpt.parent=None;sculpt.modifiers.clear();sculpt.vertex_groups.clear()
    bpy.data.objects.remove(temp,do_unlink=True)
    activate(sculpt)


def bind(obj,rig,target):
    for name in A:obj.vertex_groups.new(name=name)
    source_normals=obj.data.attributes.get('source_normal')
    bind_positions=obj.data.attributes.get('bind_position')
    smooth_normals=[]
    for v in obj.data.vertices:
        inherited=[(name,obj.data.attributes['skin_'+name].data[v.index].value) for name in A if obj.data.attributes.get('skin_'+name)]
        inherited=sorted([(name,w) for name,w in inherited if w>.00001],key=lambda pair:pair[1],reverse=True)[:4]
        total=sum(w for _,w in inherited)
        weights=[("hips",1.0)] if obj.name=="Wearable_SmithApron" and v.co.z<1.06 else ([(name,w/total) for name,w in inherited] if total else skin_weights(Vector(bind_positions.data[v.index].vector) if bind_positions else v.co))
        for bone,w in weights:obj.vertex_groups[bone].add([v.index],w,'REPLACE')
        normal=Vector(source_normals.data[v.index].vector) if source_normals else v.normal.copy()
        smooth_normals.append((a_to_t(v.co+normal,weights,target)-a_to_t(v.co,weights,target)).normalized())
        v.co=a_to_t(v.co,weights,target)
    obj.data.update()
    obj.data.normals_split_custom_set_from_vertices(smooth_normals)
    if source_normals:obj.data.attributes.remove(source_normals)
    if bind_positions:obj.data.attributes.remove(bind_positions)
    for attr in list(obj.data.attributes):
        if attr.name.startswith('skin_'):obj.data.attributes.remove(attr)
    arm=obj.modifiers.new('SharedMotionSkin','ARMATURE');arm.object=rig;obj.parent=rig


def split_surface(source,name,predicate,offset=0,mat=None):
    """Keep original surface UVs; clothes are separately fitted and skinned."""
    mesh=source.data;faces=[f for f in mesh.polygons if predicate(f.center)]
    used=sorted({i for f in faces for i in f.vertices});index={v:i for i,v in enumerate(used)}
    vertices=[tuple(mesh.vertices[i].co+mesh.vertices[i].normal*offset) for i in used]
    result=bpy.data.meshes.new(name);result.from_pydata(vertices,[],[[index[i] for i in f.vertices] for f in faces]);result.update()
    obj=bpy.data.objects.new(name,result);bpy.context.collection.objects.link(obj)
    normals=result.attributes.new('source_normal','FLOAT_VECTOR','POINT')
    bind_positions=result.attributes.new('bind_position','FLOAT_VECTOR','POINT')
    for new_index,old_index in enumerate(used):
        normals.data[new_index].vector=mesh.vertices[old_index].normal
        bind_positions.data[new_index].vector=mesh.vertices[old_index].co
    for attr in mesh.attributes:
        if attr.name.startswith('skin_'):
            copied=result.attributes.new(attr.name,'FLOAT','POINT')
            for ni,oi in enumerate(used):copied.data[ni].value=attr.data[oi].value
    uv=result.uv_layers.new(name='UVMap')
    for out_face,in_face in zip(result.polygons,faces):
        out_face.use_smooth=True;out_face.material_index=0 if mat else in_face.material_index
        for a,b in zip(out_face.loop_indices,in_face.loop_indices):uv.data[a].uv=mesh.uv_layers.active.data[b].uv
    if mat:result.materials.append(mat)
    else:
        for m in mesh.materials:result.materials.append(m)
    return obj


def inherit_nearest_skin(obj, source):
    tree=KDTree(len(source.data.vertices))
    for v in source.data.vertices:tree.insert(v.co,v.index)
    tree.balance()
    attrs={name:obj.data.attributes.new('skin_'+name,'FLOAT','POINT') for name in A}
    for v in obj.data.vertices:
        nearest=tree.find_n(v.co,4);denominator=sum(1/max(d,.002)**2 for _,_,d in nearest)
        for name,attr in attrs.items():
            original=source.data.attributes['skin_'+name]
            attr.data[v.index].value=sum(original.data[i].value/max(d,.002)**2 for _,i,d in nearest)/denominator
            if obj.name.startswith('Hem_') and any(name.startswith(prefix) for prefix in ('upperarm','lowerarm','wrist','hand','head')):attr.data[v.index].value=0


def body_region(p):
    x,y,z=p
    if z>1.49:return 'Anatomy_Head'
    if abs(x)>(.213 if z>1.26 else .246) and z>.76:
        return 'Anatomy_Hands' if z<1.045 else 'Anatomy_Arms'
    if z>1.07:return 'Anatomy_Torso'
    if z>.54:return 'Clothing_Braies'
    if z<.13:return 'Anatomy_Feet'
    if z<.335:return 'Anatomy_Calves'
    return 'Anatomy_Legs'


def remove_reconstruction_background(obj):
    """Trim generated backdrop sheets against the NEW photo's body silhouette.

    Read colour evidence to constrain 3D geometry; the reference bitmap itself
    is never modified. Neutral studio background has almost no chroma.
    """
    image=bpy.data.images.load(str(REF/'front.png'),check_existing=True)
    pixels=np.empty(len(image.pixels),dtype=np.float32);image.pixels.foreach_get(pixels)
    rgb=pixels.reshape(image.size[1],image.size[0],4)[:,:,:3]
    mask=(rgb.max(axis=2)-rgb.min(axis=2))>.047
    # A small tolerance accommodates reconstruction/reference silhouette drift.
    expanded=mask.copy()
    radius=12
    for shift in range(1,radius+1):
        expanded[shift:]|=mask[:-shift];expanded[:-shift]|=mask[shift:]
    mask=expanded.copy()
    for shift in range(1,radius+1):
        expanded[:,shift:]|=mask[:,:-shift];expanded[:,:-shift]|=mask[:,shift:]
    bm=bmesh.new();bm.from_mesh(obj.data)
    remove=[]
    for v in bm.verts:
        px=round(504+v.co.x*(1422/HEIGHT));py=round(1535-(1444-v.co.z*(1422/HEIGHT)))
        if px<0 or px>=1024 or py<0 or py>=1536 or not expanded[py,px] or (abs(v.co.x)>.30 and v.co.z<.80):remove.append(v)
    print('BACKGROUND_VERTICES_REMOVED',len(remove),flush=True)
    bmesh.ops.delete(bm,geom=remove,context='VERTS')
    # Reject backdrop triangles whose corners survived along separate limbs.
    bad_faces=[]
    for face in bm.faces:
        p=face.calc_center_median();px=round(504+p.x*(1422/HEIGHT));py=round(1535-(1444-p.z*(1422/HEIGHT)))
        if px<0 or px>=1024 or py<0 or py>=1536 or not expanded[py,px]:bad_faces.append(face)
    bmesh.ops.delete(bm,geom=bad_faces,context='FACES')
    # Keep large side boundaries open for the offline Poisson reconstruction.
    # Capping a long concave strip directly produces inward-facing patches.
    boundary=[e for e in bm.edges if e.is_boundary]
    if boundary:
        patches=bmesh.ops.holes_fill(bm,edges=boundary,sides=24)['faces']
        bmesh.ops.triangulate(bm,faces=patches)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(obj.data);bm.free();obj.data.update();obj.data.validate(clean_customdata=True)
    activate(obj)
    smooth=obj.modifiers.new('ReconstructionSurfaceRelax','SMOOTH');smooth.factor=.3;smooth.iterations=2;bpy.ops.object.modifier_apply(modifier=smooth.name)


def projection_edge_map(view):
    image=bpy.data.images.load(str(REF/f'{view}.png'),check_existing=True)
    pixels=np.empty(len(image.pixels),dtype=np.float32);image.pixels.foreach_get(pixels)
    rgb=pixels.reshape(image.size[1],image.size[0],4)[:,:,:3]
    value=rgb.max(axis=2);chroma=value-rgb.min(axis=2)
    valid=(chroma>.085)|(value<.30)|(value>.62)
    nearest=np.arange(valid.size,dtype=np.int32).reshape(valid.shape)
    nearest[~valid]=-1
    # Extend only the UV sampling coordinates into the neutral backdrop margin.
    # No raster reference is edited; this avoids projecting grey onto the skin.
    for _ in range(96):
        previous=nearest.copy()
        for dy,dx in ((1,0),(-1,0),(0,1),(0,-1)):
            shifted=np.roll(previous,(dy,dx),(0,1))
            take=(nearest<0)&(shifted>=0);nearest[take]=shifted[take]
    return nearest


def projected_uv(obj):
    """Projection uses only the newly generated original front/back/head plates."""
    mesh=obj.data;mesh.materials.clear();uv=mesh.uv_layers.new(name='UVMap')
    edge_maps=[projection_edge_map(v) for v in ('front','back','face')]
    mats=[texture_material('fresh_skin_front','front',.72),texture_material('fresh_skin_back','back',.72),texture_material('fresh_face','face',.62)]
    for mat in mats:mesh.materials.append(mat)
    for f in mesh.polygons:
        back=f.normal.y>0
        face=f.center.z>1.555 and not back
        f.material_index=2 if face else (1 if back else 0);f.use_smooth=True
        for li in f.loop_indices:
            p=mesh.vertices[mesh.loops[li].vertex_index].co
            # Full-body reference crown 22, sole 1444, centre 504.
            px=504+p.x*(1422/HEIGHT)
            py=1444-p.z*(1422/HEIGHT)
            if back:px=512-p.x*(1408/HEIGHT);py=1430-p.z*(1408/HEIGHT)
            if face:
                # Head-only plate aligned to crown, eye line and chin.
                px=512+(px-503)*5.35
                py=39+(py-23)*5.30
            uv.data[li].uv=(px/1024,1-py/1536)


def export(path,objects,animations=False):
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:obj.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_animations=animations,export_animation_mode='ACTIONS',export_nla_strips=True,export_force_sampling=True,export_frame_range=False,export_anim_single_armature=True,export_image_format='JPEG' if animations else 'AUTO',export_jpeg_quality=95,export_all_influences=False,export_apply=False)


def simple_mesh(name,verts,faces,mat):
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
    obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj);obj.data.materials.append(mat)
    uv=mesh.uv_layers.new(name='UVMap')
    for f in mesh.polygons:
        f.use_smooth=True
        for i in f.loop_indices:
            p=mesh.vertices[mesh.loops[i].vertex_index].co;uv.data[i].uv=(p.x,p.z)
    return obj


def tunic_skirt(name,mat,hem):
    rows=16;segments=64;verts=[];faces=[]
    for j in range(rows+1):
        t=j/rows;z=1.11+(hem-1.11)*t
        rx=.235+.008*t;ry=.202+.012*t
        for i in range(segments):
            angle=i*math.tau/segments
            fold=(.002+.005*t)*math.cos(angle*13+t*2)
            verts.append(((rx+fold)*math.cos(angle),(ry+fold)*math.sin(angle),z+.004*math.cos(angle*4)*t))
    for j in range(rows):
        for i in range(segments):
            a=j*segments+i;b=j*segments+(i+1)%segments
            faces.append((a,a+segments,b+segments,b))
    obj=simple_mesh(name,verts,faces,mat)
    # Quad panels carry their own cylindrical garment UV, not skin projection.
    uv=obj.data.uv_layers.active
    for face in obj.data.polygons:
        for li in face.loop_indices:
            index=obj.data.loops[li].vertex_index;row=index//segments;column=index%segments
            uv.data[li].uv=(column/segments,row/rows*.25)
    return obj


def apron(mat):
    verts=[];faces=[];rows=22;cols=18
    for row in range(rows+1):
        z=1.36-row/rows*.78
        width=.115 if z>1.15 else .218
        for col in range(cols+1):
            t=col/cols*2-1;x=t*width
            y=-.20-.020*(1-t*t)+.005*math.sin(t*13+z*9)
            if z<1.05:y-=.025
            verts.append((x,y,z))
    for r in range(rows):
        for c in range(cols):
            i=r*(cols+1)+c;faces.append((i,i+cols+1,i+cols+2,i+1))
    obj=simple_mesh('Wearable_SmithApron',verts,faces,mat)
    sol=obj.modifiers.new('LeatherThickness','SOLIDIFY');sol.thickness=.003;activate(obj);bpy.ops.object.modifier_apply(modifier=sol.name)
    return obj


def tube(name,points,radius,mat,sides=10):
    dense=[]
    for start,end in zip(points,points[1:]):
        start,end=Vector(start),Vector(end);steps=max(1,math.ceil((end-start).length/.025))
        dense.extend(start.lerp(end,i/steps) for i in range(steps))
    points=dense+[Vector(points[-1])]
    verts=[];faces=[]
    for i,p in enumerate(points):
        p=Vector(p);d=Vector(points[min(i+1,len(points)-1)])-Vector(points[max(i-1,0)])
        u=d.normalized().cross(Vector((0,0,1)))
        if u.length<.01:u=Vector((1,0,0))
        u.normalize();v=d.normalized().cross(u)
        for j in range(sides):verts.append(tuple(p+radius*(u*math.cos(j*math.tau/sides)+v*math.sin(j*math.tau/sides))))
    for i in range(len(points)-1):
        for j in range(sides):
            a=i*sides+j;b=i*sides+(j+1)%sides;faces.append((a,b,b+sides,a+sides))
    return simple_mesh(name,verts,faces,mat)


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--source');parser.add_argument('--prepare-only',action='store_true');parser.add_argument('--points-output');args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    bpy.context.preferences.filepaths.save_version=0
    OUT.mkdir(parents=True,exist_ok=True);(OUT/'source').mkdir(exist_ok=True);(OUT/'source/.gdignore').touch()
    bpy.ops.wm.open_mainfile(filepath=str(WORK/'motion.blend'))
    rig=next(o for o in bpy.data.objects if o.type=='ARMATURE');rig.name='KalevMotionRig'
    target=rig_fit(rig)
    author_relaxed_idle(rig)
    author_locomotion(rig)
    before=set(bpy.data.objects)
    source=Path(args.source) if args.source else REF/'sculpt.glb'
    bpy.ops.import_scene.gltf(filepath=str(source))
    imported=[o for o in bpy.data.objects if o not in before and o.type=='MESH']
    for o in imported:o.select_set(True)
    bpy.context.view_layer.objects.active=imported[0]
    if len(imported)>1:bpy.ops.object.join()
    sculpt=imported[0];sculpt.name='FreshSculpt'
    bm=bmesh.new();bm.from_mesh(sculpt.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.00001);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(sculpt.data);bm.free()
    for face in sculpt.data.polygons:face.use_smooth=True
    sculpt.data.normals_split_custom_set_from_vertices([(0,0,0)]*len(sculpt.data.vertices))
    activate(sculpt);bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
    low=min(v.co.z for v in sculpt.data.vertices);high=max(v.co.z for v in sculpt.data.vertices)
    # The native Hunyuan GLB uses Y-up and is converted by the glTF importer.
    scale=HEIGHT/(high-low)
    for v in sculpt.data.vertices:v.co=(v.co-Vector((0,0,low)))*scale
    sculpt.data.update()
    if args.source:remove_reconstruction_background(sculpt)
    print('SCULPT_BOUNDS',[[min(v.co[i] for v in sculpt.data.vertices),max(v.co[i] for v in sculpt.data.vertices)] for i in range(3)],flush=True)
    sculpt.data.validate(clean_customdata=True)
    triangle_count=sum(len(p.vertices)-2 for p in sculpt.data.polygons)
    if triangle_count>52000:
        mod=sculpt.modifiers.new('GameMeshReduction','DECIMATE');mod.ratio=51900/triangle_count;mod.use_collapse_triangulate=True;bpy.ops.object.modifier_apply(modifier=mod.name)
    # Preserve the normalized sculpt as an independent, compact rebuild input.
    for face in sculpt.data.polygons:face.use_smooth=True
    export(REF/'sculpt.glb',[sculpt])
    if args.points_output:
        with Path(args.points_output).open('w') as stream:
            stream.write('ply\nformat ascii 1.0\nelement vertex '+str(len(sculpt.data.vertices))+'\nproperty float x\nproperty float y\nproperty float z\nproperty float nx\nproperty float ny\nproperty float nz\nend_header\n')
            for v in sculpt.data.vertices:stream.write(' '.join(str(x) for x in (*v.co,*v.normal))+'\n')
    if args.prepare_only:
        bpy.ops.wm.save_as_mainfile(filepath=str(WORK/'sculpt_preview.blend'));return
    projected_uv(sculpt);sculpt.data.update()
    anatomical_weights(sculpt,rig)
    bodies=[]
    for region in ('Anatomy_Head','Anatomy_Torso','Anatomy_Arms','Anatomy_Hands','Clothing_Braies','Anatomy_Legs','Anatomy_Calves','Anatomy_Feet'):
        bodies.append(split_surface(sculpt,region,lambda p,r=region:body_region(p)==r))
    linen=surface_material('linen',(.49,.43,.32),.92)
    wool=surface_material('wool',(.11,.16,.145),.94)
    leather=surface_material('leather',(.16,.075,.035),.70)
    mail=surface_material('mail',(.22,.24,.245),.49,.76)
    hose=surface_material('hose',(.095,.11,.085),.94)
    bootmat=surface_material('boot_leather',(.075,.042,.023),.67)
    garments={}
    for name,mat,offset in [('linen_shirt',linen,.018),('wool_tunic',wool,.030),('mail_shirt',mail,.044)]:
        def shirt(p):
            x,y,z=p
            return z<1.54 and z>1.025 and (abs(x)<.235 or z>1.045)
        obj=split_surface(sculpt,'Wearable_'+name,shirt,offset,mat)
        smooth=obj.modifiers.new('TailoredEase','SMOOTH');smooth.factor=.7;smooth.iterations=12;activate(obj);bpy.ops.object.modifier_apply(modifier=smooth.name)
        garments[name]=[obj,tunic_skirt('Hem_'+name,mat,.87 if name=='linen_shirt' else .80)]
        garments[name].append(tube('Collar_'+name,[(.087*math.cos(i*math.tau/48),.075*math.sin(i*math.tau/48),1.535) for i in range(49)],.008,mat))
    garments['smith_apron']=[apron(leather)]
    # Neck strap and waist belt are part of the removable apron, not anatomy.
    garments['smith_apron'].append(tube('ApronNeckStrap',[(-.085,-.225,1.34),(-.096,-.14,1.48),(0,.078,1.485),(.096,-.14,1.48),(.085,-.225,1.34)],.009,leather))
    garments['smith_apron'].append(tube('ApronWaistBelt',[(.215*math.cos(i*math.tau/64),.174*math.sin(i*math.tau/64),1.065) for i in range(65)],.018,leather))
    garments['hose']=[split_surface(sculpt,'Wearable_Hose',lambda p:p.z<1.073 and p.z>.115 and body_region(p) in ('Clothing_Braies','Anatomy_Legs','Anatomy_Calves','Anatomy_Feet'),.012,hose)]
    garments['boots']=[split_surface(sculpt,'Wearable_Boots',lambda p:p.z<.335,.022,bootmat)]
    activate(garments['boots'][0]);boot_smooth=garments['boots'][0].modifiers.new('RoundLeatherToebox','SMOOTH');boot_smooth.factor=.7;boot_smooth.iterations=15;bpy.ops.object.modifier_apply(modifier=boot_smooth.name)
    for obj in [o for g in garments.values() for o in g]:
        if not obj.data.attributes.get('skin_hips'):inherit_nearest_skin(obj,sculpt)
        count=sum(len(p.vertices)-2 for p in obj.data.polygons)
        if count>7000:
            activate(obj);reduce=obj.modifiers.new('GarmentBudget','DECIMATE');reduce.ratio=6500/count;reduce.use_collapse_triangulate=True;bpy.ops.object.modifier_apply(modifier=reduce.name)
    for obj in bodies+[o for g in garments.values() for o in g]:bind(obj,rig,target)
    bpy.data.objects.remove(sculpt,do_unlink=True)
    for o in bpy.data.objects:
        if o.type=='EMPTY':bpy.data.objects.remove(o,do_unlink=True)
    # Blender's imported action slots retain the original target; ACTIONS mode
    # exports every compatible skeletal action while garments carry only binds.
    rig.data.pose_position='POSE'
    export(OUT/'kalev_fresh.glb',[rig]+bodies,animations=True)
    for name,objects in garments.items():export(OUT/f'{name}.glb',[rig]+objects)
    for objects in garments.values():
        for o in objects:o.hide_render=True;o.hide_set(True)
    rig.data.pose_position='POSE'
    bpy.data.orphans_purge(do_local_ids=True,do_linked_ids=True,do_recursive=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'source/kalev_fresh.blend'),compress=True)
    bpy.ops.file.make_paths_relative()
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'source/kalev_fresh.blend'),compress=True)
    stats={'body_triangles':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in bodies),'garments':{k:sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in v) for k,v in garments.items()},'animations':len(bpy.data.actions),'height_m':HEIGHT,'source':str(source),'input_policy':'Only new imagegen references/Hunyuan sculpt; geometry-stripped KayKit CC0 skeleton and clips.'}
    (OUT/'build_manifest.json').write_text(json.dumps(stats,indent=2));print(json.dumps(stats),flush=True)


if __name__=='__main__':main()
