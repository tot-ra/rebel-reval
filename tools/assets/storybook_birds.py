"""Original naturalistic bird geometry, feather UVs and baked portable PBR maps.

Blender metres: +Y tail, -Y bill, +Z up. Existing nine-bone/8-clip contract.
Feather surfaces are curved vanes, not ellipsoids; no reference pixels are used.
"""
import math
import bpy
import numpy as np
from mathutils import Vector


SPECIES = {
    'robin': dict(k=1., body=(.092,.142,.115), head=(0,-.098,.367),
                  head_size=(.060,.065,.062), coat='71634B', wing='514735',
                  tail=.145, bill=.039, leg='705746'),
    'hooded_crow': dict(k=1.65, body=(.088,.179,.110), head=(0,-.123,.381),
                        head_size=(.055,.072,.058), coat='9A9B94', wing='252A2D',
                        tail=.206, bill=.082, leg='363739'),
    'gull': dict(k=1.85, body=(.087,.180,.098), head=(0,-.141,.390),
                head_size=(.049,.069,.057), coat='D9DAD2', wing='939CA3',
                tail=.151, bill=.072, leg='BC9490'),
    'hen': dict(k=1.6, body=(.108,.158,.128), head=(0,-.119,.409),
               head_size=(.043,.057,.051), coat='915E34', wing='695039',
               tail=.160, bill=.041, leg='B59A60'),
    'duck': dict(k=1.85, body=(.100,.201,.100), head=(0,-.143,.380),
                head_size=(.052,.073,.063), coat='AAA99D', wing='655F53',
                tail=.116, bill=.088, leg='B97935'),
}


def linear(hex_color):
    rgb = [int(hex_color[i:i+2], 16)/255 for i in (0,2,4)]
    return np.array([v/12.92 if v <= .04045 else ((v+.055)/1.055)**2.4 for v in rgb])


def detail_maps():
    """A neutral vane tile: rachis, swept barbs, fine barbules. Embedded in GLB."""
    width, height = 256, 512
    u, v = np.meshgrid(np.linspace(-1,1,width), np.linspace(0,1,height))
    phase = v*math.tau*100 - np.abs(u)*20 + .35*np.sin(v*37)
    barb = np.sin(phase)
    shaft = np.exp(-(u/.028)**2)
    heightfield = .30*barb + .7*shaft + .055*np.sin(phase*3.1)
    dy, dx = np.gradient(heightfield)
    normal = np.stack((-dx*.4, -dy*.4, np.ones_like(u)),axis=-1)
    normal /= np.linalg.norm(normal,axis=-1,keepdims=True)
    albedo = .93 + .016*barb + .018*shaft - .025*np.abs(u)**3
    rough = .78-.10*shaft+.025*barb
    def image(name, data, noncolor=False):
        result = bpy.data.images.new(name, width=width, height=height, alpha=True)
        if noncolor: result.colorspace_settings.name='Non-Color'
        rgba = np.ones((height,width,4),dtype=np.float32)
        rgba[:,:,:3] = data if data.ndim == 3 else data[:,:,None]
        result.pixels.foreach_set(rgba.ravel())
        result.pack()
        return result
    return image('Bird_Vane_Albedo',albedo), image('Bird_Vane_Normal',normal*.5+.5,True), image('Bird_Vane_Roughness',rough,True)


def materials(api):
    albedo, normal, roughness = detail_maps()
    feather = api.material('Bird plumage', 'FFFFFF', .78)
    nodes, links = feather.node_tree.nodes, feather.node_tree.links
    bsdf = nodes['Principled BSDF']
    for img, socket in ((albedo,'Base Color'),(roughness,'Roughness')):
        node = nodes.new('ShaderNodeTexImage'); node.image=img
        links.new(node.outputs['Color'],bsdf.inputs[socket])
    node = nodes.new('ShaderNodeTexImage'); node.image=normal
    norm = nodes.new('ShaderNodeNormalMap'); norm.inputs['Strength'].default_value=.42
    links.new(node.outputs['Color'],norm.inputs['Color'])
    links.new(norm.outputs['Normal'],bsdf.inputs['Normal'])
    # glTF exports the active colour attribute independently of the material.
    # Explicit multiply also makes the editable Blender source match Godot.
    color = nodes.new('ShaderNodeVertexColor'); color.layer_name='Plumage'
    mix = nodes.new('ShaderNodeMixRGB'); mix.blend_type='MULTIPLY'; mix.inputs[0].default_value=1
    texture = next(n for n in nodes if n.type=='TEX_IMAGE' and n.image==albedo)
    links.new(texture.outputs['Color'],mix.inputs[1]); links.new(color.outputs['Color'],mix.inputs[2])
    links.new(mix.outputs[0],bsdf.inputs['Base Color'])
    # EXPORT vertex colour multiplies base texture; export uses this recognized chain.
    result = dict(feather=feather, bill=api.material('Bird keratin','FFFFFF',.39),
                leg=api.material('Bird scales','FFFFFF',.69),
                eye=api.material('Bird cornea','141313',.12),
                iris=api.material('Bird iris','FFFFFF',.4),
                fleshy=api.material('Bird bare skin','FFFFFF',.66))
    for key, mat in result.items():
        mat.use_backface_culling=True
        if key in ('feather', 'eye'): continue
        color = mat.node_tree.nodes.new('ShaderNodeVertexColor'); color.layer_name='Plumage'
        mat.node_tree.links.new(color.outputs['Color'],mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'])
    return result


def paint(obj, color):
    layer = obj.data.color_attributes.new(name='Plumage',type='FLOAT_COLOR',domain='POINT')
    for vertex in obj.data.vertices:
        rgb = color(vertex.co) if callable(color) else linear(color)
        layer.data[vertex.index].color=(*rgb,1)
    obj.data.color_attributes.active_color=layer


def mesh(api, name, verts, faces, uvs, mat, bone, color):
    data=bpy.data.meshes.new(name); data.from_pydata(verts,[],faces); data.update()
    obj=bpy.data.objects.new(name,data); bpy.context.collection.objects.link(obj)
    bpy.ops.object.select_all(action='DESELECT'); obj.select_set(True); bpy.context.view_layer.objects.active=obj
    api.finish(obj,name,mat,bone)
    uv=data.uv_layers.new(name='FeatherUV')
    for loop in data.loops: uv.data[loop.index].uv=uvs[loop.vertex_index]
    paint(obj,color)
    return obj


def feather(api, name, start, end, width, mat, bone, color, normal=(0,0,1), camber=.06, tip_color=None):
    """Asymmetric closed vane with a raised central shaft and softly split edge."""
    start,end=Vector(start),Vector(end)
    if bone.startswith('Wing'):
        side=1 if start.x>0 else -1
        scale=SPECIES[api.RIG['species']]['k']
        start.x-=side*.025*scale
        end.x-=side*.025*scale
        start.y-=.055*scale
        end.y-=.055*scale
    axis=end-start; normal=Vector(normal).normalized()
    cross=axis.normalized().cross(normal).normalized()
    verts=[]; uv=[]; faces=[]
    rows=7; columns=5
    for lower in (False,True):
        for j in range(rows):
            t=(0,.14,.36,.60,.80,.95,1)[j]
            # Full-width roots overlap under the next tract, avoiding a row of
            # exposed spikes along the leading edge. Only the distal tip tapers.
            breadth=max(.015,math.sin(math.pi*(t*.80+.20))**.50)*(1-.30*t)
            for i,s in enumerate((-1.,-.45,0.,.45,1.)):
                edge=1-.055*math.sin(j*2.6)**8 if abs(s)==1 else 1
                skew=.77 if s<0 else 1.0
                point=start+axis*t+cross*(s*width*breadth*skew*edge)
                point+=normal*(width*camber*(1-s*s)*math.sin(math.pi*t)-(.00035 if lower else 0))
                verts.append(point); uv.append(((s+1)*.5,t))
        offset=rows*columns if lower else 0
        for j in range(rows-1):
            for i in range(columns-1):
                a=offset+j*columns+i
                face=(a,a+1,a+1+columns,a+columns)
                faces.append(tuple(reversed(face)) if lower else face)
    n=rows*columns
    for j in range(rows-1):
        for i in (0,columns-1):
            a=j*columns+i; b=a+columns
            faces.append((a,b,b+n,a+n))
    base=linear(color)
    obj=mesh(api,name,verts,faces,uv,mat,bone,color)
    # Subtle vane edge bleaching and distinct pale terminal mirrors on gulls.
    layer=obj.data.color_attributes['Plumage']
    for i,item in enumerate(layer.data):
        t=uv[i][1]; u=uv[i][0]
        c=base*(.94+.09*math.sin(t*2.7)+.055*abs(u-.5))
        if tip_color and t>.86: c=linear(tip_color)
        item.color=(*c,1)
    return obj


def build(api,name,palette):
    spec=SPECIES[name]; k=spec['k']; mats=materials(api)
    def V(value):
        x,y,z=value
        if name=='duck': z-=min(.045,max(0,z-.03)*.55)
        return (float(x)*k,float(y)*k,float(z)*k)
    api.make_rig([('Body',V((0,0,.16)),V((0,0,.31)),None),
        ('Head',V((0,-.08,.34)),V((0,-.08,.47)),'Body'),
        ('Wing.L',V((.075,-.055,.29)),V((.245,-.055,.29)),'Body'),
        ('Wing.R',V((-.075,-.055,.29)),V((-.245,-.055,.29)),'Body'),
        ('WingTip.L',V((.245,-.055,.29)),V((.485,-.030,.29)),'Wing.L'),
        ('WingTip.R',V((-.245,-.055,.29)),V((-.485,-.030,.29)),'Wing.R'),
        ('Tail',V((0,.11,.23)),V((0,.3,.2)),'Body'),
        ('Leg.L',V((.055,-.016,.18)),V((.055,-.016,.04)),'Body'),
        ('Leg.R',V((-.055,-.016,.18)),V((-.055,-.016,.04)),'Body')])
    api.RIG['species']=name
    def oval(n,loc,scale,mat,color,bone,segments=24,rings=16):
        obj=api.oval(n,V(loc),tuple(value*k for value in scale),mats[mat],bone,segments,rings)
        obj.data.uv_layers.active.name='FeatherUV'
        paint(obj,color)
        return obj
    def line(n,points,width,mat,color,bone):
        obj=api.line(n,[V(x) for x in points],width*k,mats[mat],bone)
        mod=obj.modifiers.new('Small keratin curve budget','DECIMATE'); mod.ratio=.45
        bpy.context.view_layer.objects.active=obj
        bpy.ops.object.modifier_apply(modifier=mod.name)
        paint(obj,color)
        return obj
    # Fuse the torso, nape and skull before skinning, removing the toy-like sphere seams.
    body=oval('Bird body',(0,0,.254),spec['body'],'feather',spec['coat'],'Body',40,28)
    neck=oval('Bird neck',(0,-.091,.326),(.059,.074,.105 if name=='hen' else .085),'feather',spec['coat'],'Body',32,24)
    skull=oval('Bird skull',spec['head'],spec['head_size'],'feather',spec['coat'],'Head',32,24)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in (body,neck,skull): obj.select_set(True); api.PARTS.remove(obj)
    bpy.context.view_layer.objects.active=body; bpy.ops.object.join()
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    remesh=body.modifiers.new('Continuous bird anatomy','REMESH'); remesh.mode='VOXEL'; remesh.voxel_size=.0045*k
    bpy.ops.object.modifier_apply(modifier=remesh.name)
    smooth=body.modifiers.new('Plumage surface','SMOOTH'); smooth.factor=1.3; smooth.iterations=5
    bpy.ops.object.modifier_apply(modifier=smooth.name)
    decimate=body.modifiers.new('Body budget','DECIMATE'); decimate.ratio=.42
    bpy.ops.object.modifier_apply(modifier=decimate.name)
    body.vertex_groups.clear()
    for bn in ('Body','Head'): body.vertex_groups.new(name=bn)
    for vert in body.data.vertices:
        z=vert.co.z/k+(.045 if name=='duck' else 0); y=vert.co.y/k
        head=max(0,min(1,(z-.31)/.045))*max(0,min(1,(-y+.015)/.065))
        body.vertex_groups['Body'].add([vert.index],1-head,'REPLACE')
        body.vertex_groups['Head'].add([vert.index],head,'REPLACE')
    for poly in body.data.polygons: poly.use_smooth=True
    for attribute in list(body.data.color_attributes):
        body.data.color_attributes.remove(attribute)
    def body_color(co):
        x,y,z=co/k
        if name=='duck': z+=.045
        base=linear(spec['coat'])
        if name=='robin':
            orange=max(0,min(1,(-y-.069)/.025))*max(0,min(1,(z-.207)/.029))*max(0,min(1,(.407-z)/.029))
            cream=max(0,min(1,(.221-z)/.044))
            base=base*(1-cream)+linear('C1B6A0')*cream
            base=base*(1-orange)+linear('B6632E')*orange
        elif name=='hooded_crow':
            hood=max(0,min(1,(z-.313)/.045)) if y<-.047 else 0
            bib=max(0,min(1,(-y-.13)/.016))*max(0,min(1,(z-.22)/.075))
            dark=max(hood,bib)
            base=base*(1-dark)+linear('23292D')*dark
        elif name=='gull':
            mantle=max(0,min(1,(z-.301)/.035))*max(0,min(1,(y+.067)/.033))
            base=base*(1-mantle)+linear(spec['wing'])*mantle
        elif name=='duck':
            head=max(0,min(1,(z-.323)/.019))*max(0,min(1,(-y-.058)/.035))
            chest=max(0,min(1,(-y-.07)/.05))*(1-head)
            base=base*(1-chest)+linear('61402E')*chest
            base=base*(1-head)+linear('244D3B')*head
            collar=max(0,1-abs(z-.329)/.007) if y<-.062 else 0
            base=base*(1-collar)+linear('DAD6C7')*collar
        elif name=='hen':
            neck=max(0,min(1,(z-.305)/.09))
            base=base*(1-neck)+linear('B58146')*neck
        # Low contrast directional contour feather mottling, not high-frequency dirt.
        return base*(.98+.015*math.sin(z*470+y*170+math.sin(x*160)*.5))
    paint(body,body_color)
    for old_uv in list(body.data.uv_layers): body.data.uv_layers.remove(old_uv)
    uv=body.data.uv_layers.new(name='FeatherUV')
    for poly in body.data.polygons:
        for index in poly.loop_indices:
            co=body.data.vertices[body.data.loops[index].vertex_index].co/k
            uv.data[index].uv=(math.atan2(co.x,co.y)/math.tau+.5,co.z*6)
    api.PARTS.append(body)
    # Eyeballs are seated in tiny lids on the side of the skull, never button eyes.
    hx,hy,hz=spec['head']; sx,sy,sz=spec['head_size']
    for side in (-1,1):
        eye=(side*sx*.89,hy-sy*.40,hz+sz*.21)
        oval('Orbital skin',eye,(.007,.009,.008),'fleshy','9C6D55' if name=='hen' else spec['wing'],'Head')
        iris_color='B6A66B' if name=='gull' else ('B78536' if name=='hen' else '423527')
        eye=(eye[0]+side*.001,eye[1]-.001,eye[2])
        oval('Iris',eye,(.0068,.0072,.0068),'iris',iris_color,'Head')
        oval('Cornea',(eye[0]+side*.004,eye[1]-.002,eye[2]),(.0035,.0044,.0045),'eye','FFFFFF','Head')
    # Keratin upper/lower bill, tapered curved tip and visible mouth seam.
    root_y=hy-sy*.78; bill_z=hz-.016; length=spec['bill']
    bill_color='B4A24A' if name=='duck' else ('CBAD53' if name=='gull' else ('9E895E' if name=='hen' else '343330'))
    for lower in (False,True):
        verts=[]; uvs=[]; faces=[]
        for row in range(9):
            t=row/8
            width=(.023 if name=='duck' else (.014 if name=='hooded_crow' else .011))*(1-t)**(.18 if name=='duck' else .8)+.0006
            depth=(.005 if name=='duck' else .010)*(1-t)**.6+.0007
            for j in range(9):
                angle=j/8*math.pi
                z=bill_z+(-.002-depth*.6*math.sin(angle) if lower else depth*math.sin(angle))-.008*t*t
                verts.append(V((width*math.cos(angle),root_y-length*t,z))); uvs.append((j/8,t))
        for row in range(8):
            for j in range(8):
                a=row*9+j; f=(a,a+9,a+10,a+1)
                faces.append(f if lower else tuple(reversed(f)))
        mesh(api,'Lower mandible' if lower else 'Upper mandible',verts,faces,uvs,mats['bill'],'Head',bill_color)
    for side in (-1,1):
        oval('Nostril',(side*(.018 if name=='duck' else .008),root_y-length*.26,bill_z+.005),(.0015,.004,.0018),'eye','FFFFFF','Head',16,8)
        if name=='gull':
            oval('Bill gonys marking',(side*.004,root_y-length*.69,bill_z-.006),(.003,.009,.003),'fleshy','9D492F','Head',16,8)
    # Spread wing architecture: short covert rows cover the roots of long remiges.
    for side in (-1,1):
        arm='Wing.L' if side==1 else 'Wing.R'; hand='WingTip.L' if side==1 else 'WingTip.R'
        # The layered feather tract has volume; vanes emerge from a continuous
        # bed of down and lesser coverts, rather than floating like a comb.
        oval('Shoulder feather tract',(side*.148,-.010,.280),(.096,.066,.012),'feather',spec['wing'],arm,24,12)
        oval('Hand feather tract',(side*.335,-.016,.278),(.105,.045,.009),'feather',spec['wing'],hand,24,12)
        for i in range(10):
            t=i/9
            start=(side*(.257+.205*t),.005+.015*t,.290)
            # Outer primaries lengthen/span outward; taper the distal wing into a tip.
            end=(side*(.31+.29*t),.185-.097*t,.278-.007*t)
            if name=='gull': end=(side*(.32+.35*t),.192-.14*t,.280)
            color=('292E32' if name in ('gull','hooded_crow') else spec['wing'])
            feather(api,'Primary %s %02d'%(side,i),V(start),V(end),(.018 if name=='gull' else .021)*k,mats['feather'],hand,color,
                    tip_color='D9DBD5' if name=='gull' and i in (7,8,9) else None)
        for i in range(11):
            x=.104+i*.0155
            color='D4D5CE' if name=='gull' else spec['wing']
            if name=='duck' and 3<=i<=8: color='334B71'
            feather(api,'Secondary %s %02d'%(side,i),V((side*x,.012,.288)),V((side*(x+.038),.172,.277)),.019*k,mats['feather'],arm,color)
        for row in range(3):
            for i in range(18):
                x=.103+i*.020
                bone=arm if x<.265 else hand
                start=(side*x,.004+row*.024,.304-row*.005)
                end=(side*(x+.022),.076+row*.028,.296-row*.005)
                feather(api,'Covert',V(start),V(end),.016*k,mats['feather'],bone,spec['wing'])
        for row in range(2):
            for i in range(18):
                x=.103+i*.020
                bone=arm if x<.265 else hand
                start=(side*x,.005+row*.035,.264-row*.002)
                end=(side*(x+.026),.091+row*.038,.263-row*.002)
                feather(api,'Underwing covert',V(start),V(end),.020*k,mats['feather'],bone,spec['wing'],normal=(0,0,-1))
        # Alula at the leading edge/wrist keeps the wing from reading as a paddle.
        for i in range(3):
            feather(api,'Alula',V((side*.248,-.025,.300)),V((side*(.29+i*.020),-.041,.299)),.010*k,mats['feather'],hand,spec['wing'])
    # Tail rectrices fan from the rump, individual flattened feathers with visible shafts.
    for i in range(12):
        spread=(i-5.5)/5.5
        end=(spread*.062,.145+spec['tail']*(1-.1*abs(spread)),.215+(.14 if name=='hen' else -.025))
        feather(api,'Tail rectrix',V((spread*.027,.110,.24)),V(end),.022*k,mats['feather'],'Tail',spec['wing'])
    # Tarsal scales, flexed toes, hind toe and hooked claws; webbing spans toes.
    for side in (-1,1):
        bone='Leg.L' if side==1 else 'Leg.R'
        x=side*.055; leg=spec['leg']; ankle=.052 if name=='duck' else .041
        line('Tarsometatarsus',[(x,.015,.165),(x,.019,.088),(x,-.006,ankle)],.0058,'leg',leg,bone)
        for i in range(8):
            z=ankle+i*.006
            oval('Tarsal scute',(x,-.010+i*.001,z),(.0062,.003,.0021),'leg',leg,bone,12,8)
        for toe in (-1,0,1):
            tx=x+toe*.023; ty=-.090+abs(toe)*.014
            line('Toe',[(x,-.006,ankle),(x+toe*.013,-.038,.022),(tx,ty,.014)],.0034,'leg',leg,bone)
            line('Claw',[(tx,ty,.016),(tx+toe*.002,ty-.011,.013),(tx+toe*.003,ty-.015,.008)],.0017,'bill','3F3933',bone)
        if name not in ('duck','gull'):
            line('Hind toe',[(x,-.002,ankle),(x-side*.014,.036,.018),(x-side*.023,.045,.012)],.003,'leg',leg,bone)
            line('Hind claw',[(x-side*.023,.045,.012),(x-side*.026,.052,.009)],.0016,'bill','3F3933',bone)
        else:
            verts=[V((x,-.006,ankle)),V((x-.025,-.073,.016)),V((x,-.096,.014)),V((x+.025,-.073,.016))]
            mesh(api,'Interdigital web',verts,[(0,1,2),(0,2,3),(2,1,0),(3,2,0)],[(.5,0),(0,1),(.5,1),(1,1)],mats['leg'],bone,leg)
    if name=='hen':
        for i in range(5):
            oval('Comb',(0,hy-.025+i*.014,hz+.045+(.012 if i in (1,2) else 0)),(.006,.014,.022),'fleshy','A33F32','Head',12,8)
        for side in (-1,1): oval('Wattle',(side*.009,hy-.045,hz-.040),(.006,.014,.024),'fleshy','963D32','Head',16,12)
    result=api.bind_join()
    # Blender 5.2's glTF exporter loses named vertex colours after the first
    # material in a multi-material mesh. Split material surfaces while retaining
    # the shared skeleton; draw-call count is identical to separate surfaces.
    bpy.context.view_layer.objects.active=result[0]
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.separate(type='MATERIAL')
    bpy.ops.object.mode_set(mode='OBJECT')
    for obj in bpy.context.selected_objects:
        obj.name='Bird '+obj.data.materials[0].name
    api.animate_fauna(True)
    return result
