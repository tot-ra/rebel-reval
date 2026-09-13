"""Kalev-only anatomy and costume pass; retains shared skin/wardrobe contracts."""
import math
import random
import bpy
from mathutils import Vector


def strand(a,name,points,width,mat,bone):
    vertices=[];faces=[]
    for i,point in enumerate(points):
        for k in range(3):
            t=math.tau*k/3
            vertices.append((point[0]+math.cos(t)*width,point[1]+math.sin(t)*width,point[2]))
    for i in range(len(points)-1):
        for k in range(3):q=i*3+k;faces.append((q,i*3+(k+1)%3,(i+1)*3+(k+1)%3,q+3))
    me=bpy.data.meshes.new(name);me.from_pydata(vertices,[],faces);me.update()
    uv=me.uv_layers.new(name='StrandUV')
    for loop in me.loops:uv.data[loop.index].uv=((loop.vertex_index%3)/3,(loop.vertex_index//3)/max(1,len(points)-1))
    ob=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(ob);a.finish(ob,name,mat,bone)


def sculpt_head(a, p, hz, s):
    # Adult cranial proportions, distinct jaw, temple, malar and muzzle planes.
    rows=[(.018,.027,.043,-.008),(.033,.050,.060,-.013),(.054,.072,.076,-.008),
          (.082,.084,.084,.002),(.108,.092,.089,.009),(.136,.098,.091,.012),
          (.159,.092,.093,.018),(.184,.094,.094,.020),(.214,.092,.091,.022),
          (.245,.079,.078,.025),(.269,.051,.052,.025),(.280,.033,.035,.025),(.289,.001,.002,.025)]
    def profile(z):
        i=next((i for i in range(len(rows)-1) if rows[i][0]<=z<=rows[i+1][0]),len(rows)-2 if z>rows[-1][0] else 0)
        t=max(0,min(1,(z-rows[i][0])/(rows[i+1][0]-rows[i][0])))
        return tuple(.5*((2*rows[i][k])+(-rows[max(0,i-1)][k]+rows[i+1][k])*t+(2*rows[max(0,i-1)][k]-5*rows[i][k]+4*rows[i+1][k]-rows[min(len(rows)-1,i+2)][k])*t*t+(-rows[max(0,i-1)][k]+3*rows[i][k]-3*rows[i+1][k]+rows[min(len(rows)-1,i+2)][k])*t*t*t) for k in (1,2,3))
    def gauss(x,z,cx,cz,wx,wz):return math.exp(-((x-cx)/wx)**2-((z-cz)/wz)**2)
    def surface(x,z):
        rx,ry,cy=profile(z)
        front=math.sqrt(max(0,1-(abs(x)/max(rx,.001))**2))
        y=cy-ry*front
        d=.023*gauss(x,z,0,.140,.014,.037)+.019*gauss(x,z,0,.115,.021,.013)
        d+=.010*gauss(x,z,0,.062,.033,.027)+.006*gauss(x,z,0,.090,.035,.021)
        for side in (-1,1):
            d+=.005*gauss(x,z,side*.038,.181,.029,.013) # brow ridge
            d+=.004*gauss(x,z,side*.064,.136,.022,.016) # zygoma
            d-=.005*gauss(x,z,side*.037,.161,.023,.012) # orbital recess
            d-=.005*gauss(x,z,side*.064,.101,.022,.025) # cheek hollow
            d-=.002*gauss(x,z,side*.024,.096,.006,.018) # nasolabial groove
        return y-front**3*d
    def xyz(x,z,offset=0):return (x*s,(surface(x,z)-offset)*s,hz+z*s)
    n=112; nz=65; vs=[];fs=[];uvs=[]
    for j in range(nz):
        z=.018+(.286-.018)*j/(nz-1);rx,ry,cy=profile(z)
        for i in range(n+1):
            theta=math.tau*i/n;x=rx*math.cos(theta)
            y=surface(x,z) if math.sin(theta)<0 else cy+ry*math.sin(theta)
            vs.append((x*s,y*s,hz+z*s));uvs.append((i/n,(z-.018)/.278))
    for j in range(nz-1):
        for i in range(n):
            q=j*(n+1)+i;fs.append((q,q+1,q+n+2,q+n+1))
    mesh=bpy.data.meshes.new('Kalev sculpt');mesh.from_pydata(vs,[],fs);mesh.update()
    uv=mesh.uv_layers.new(name='FaceUV')
    for loop in mesh.loops:uv.data[loop.index].uv=uvs[loop.vertex_index]
    ob=bpy.data.objects.new('Face',mesh);bpy.context.collection.objects.link(ob);a.finish(ob,'Face',p['skin'],'head')
    a.ring_mesh('Neck',[(hz-.09*s,.075*s,.062*s,{'chest':1}),(hz-.055*s,.058*s,.058*s,{'chest':.6,'head':.4}),(hz-.005*s,.054*s,.056*s,{'head':1}),(hz+.080*s,.039*s,.039*s,{'head':1})],p['skin'])
    for vertex in a.PARTS[-1].data.vertices: vertex.co.y += .018*s
    for side in (-1,1):
        x=side*.037;z=.162
        # Thin almond aperture follows the actual orbital surface at both corners.
        verts=[];faces=[];steps=32
        for band in range(13):
            t=band/12
            for k in range(steps+1):
                xx=x+(k/steps*2-1)*.0165
                arch=math.sin(math.pi*k/steps)
                zz=z+arch*(-.0034+(t)*.0082)
                yy=surface(xx,zz)-.0015-.003*arch*math.sin(math.pi*t)
                verts.append((xx*s,yy*s,hz+zz*s))
        for r in range(12):
            for k in range(steps):q=r*(steps+1)+k;faces.append((q,q+1,q+steps+2,q+steps+1))
        me=bpy.data.meshes.new('Eye aperture');me.from_pydata(verts,[],faces);me.update()
        o=bpy.data.objects.new('Eye',me);bpy.context.collection.objects.link(o)
        sclera=a.material('kalev_sclera','76766D',.36)
        a.finish(o,'Eye',sclera,'head')
        me.materials.append(p['iris']);me.materials.append(p['eye'])
        for face in me.polygons:
            centre=sum((me.vertices[i].co for i in face.vertices),Vector())/len(face.vertices)
            distance=((centre.x/s-x)**2+(centre.z/s-hz/s-z)**2)**.5
            face.material_index=2 if distance<.0021 else (1 if distance<.0052 else 0)
        for top in (False,True):
            pts=[]
            for k in range(13):
                xx=x+(k/12*2-1)*.017
                zz=z+math.sin(math.pi*k/12)*(.0050 if top else -.0036)
                pts.append(xyz(xx,zz,.0018))
            a.line('Eyelid',pts,.00115*s,p['skin'],'head')
        # Individual eyebrow hairs instead of extruded cartoon bars.
        for k in range(23):
            xx=x+(k/22*2-1)*.022;zz=.181+.004*math.sin(k/22*math.pi)
            strand(a,'Brow', [xyz(xx,zz,.0012),xyz(xx+side*.002,zz+.0028,.0015)],.00042*s,p['hair'],'head')
        # Ear helix with an inset concha; restrained tragus/lobe volumes.
        a.oval('Ear',(side*.098*s,.01*s,hz+.137*s),(.015*s,.013*s,.031*s),p['skin'],'head',24,16)
        a.oval('Ear concha',(side*.106*s,-.001*s,hz+.137*s),(.006*s,.003*s,.014*s),p['blush'],'head',16,12)
        pts=[(side*(.101+.009*math.cos(t))*s,(.001-.007*math.cos(t))*s,hz+(.137+.026*math.sin(t))*s) for t in [i*math.tau/20 for i in range(21)]]
        a.line('Ear helix',pts,.0023*s,p['skin'],'head')
        a.oval('Nostril',(side*.012*s,(surface(side*.012,.108)-.001)*s,hz+.108*s),(.004*s,.0017*s,.002*s),p['leather_dark'],'head',16,8)
    # Vermilion surfaces taper into the muzzle, without pipe-like lip edges.
    for upper in (True,False):
        vs=[];fs=[]
        for row in range(5):
            t=row/4
            for k in range(33):
                x=(k/32*2-1)*.026;f=max(0,1-(x/.026)**2)
                seam=.081+.0013*math.cos(x/.026*math.pi*2)
                z=seam+(1 if upper else -1)*f*t*(.003 if upper else .004)
                vs.append(xyz(x,z,.001+f*math.sin(math.pi*t)*.0018))
        for row in range(4):
            for k in range(32):q=row*33+k;fs.append((q,q+1,q+34,q+33) if upper else (q+33,q+34,q+1,q))
        me=bpy.data.meshes.new('Lip');me.from_pydata(vs,[],fs);me.update()
        ob=bpy.data.objects.new('Lip',me);bpy.context.collection.objects.link(ob);a.finish(ob,'Lip',p['blush'],'head')
    a.line('Mouth',[xyz(x,.081+.0013*math.cos(x/.026*math.pi*2),.0015) for x in [(-1+i/16)*.026 for i in range(33)]],.00025*s,p['blush'],'head')
    # Continuous scalp with irregular natural hairline and swept strand ridges.
    rng=random.Random(207)
    def hairline(t):
        front=max(0,-math.sin(t))
        return .145+.065*front**2-.027*max(0,math.sin(t))
    vs=[];fs=[]
    for row in range(23):
        t=row/22
        for k in range(97):
            angle=math.tau*k/96
            z=hairline(angle)*(1-t)+.291*t;rx,ry,cy=profile(min(z,.289))
            rx = 0 if row == 22 else rx;ry = 0 if row == 22 else ry
            wave=.0016*math.sin(angle*27+t*8)*math.sin(math.pi*t)
            vs.append(((rx+.003+wave)*math.cos(angle)*s,(cy+(ry+.003+wave)*math.sin(angle))*s,hz+z*s))
    for row in range(22):
        for k in range(96):q=row*97+k;fs.append((q,q+1,q+98,q+97))
    me=bpy.data.meshes.new('Groomed scalp');me.from_pydata(vs,[],fs);me.update()
    ob=bpy.data.objects.new('Hair back',me);bpy.context.collection.objects.link(ob);a.finish(ob,'Hair back',p['hair'],'head')
    for k in range(155):
        angle=k*math.tau/155+rng.uniform(-.018,.018)
        start=hairline(angle)+rng.uniform(-.003,.008)
        pts=[]
        for j in range(8):
            t=j/7;z=start+(.285-start)*t*.94;th=angle+t*.35
            rx,ry,cy=profile(z);off=.0025+.0015*math.sin(t*math.pi)
            pts.append(((rx+off)*math.cos(th)*s,(cy+(ry+off)*math.sin(th))*s,hz+z*s))
        strand(a,'Swept strand',pts,rng.uniform(.00020,.00042)*s,p['hair_light'] if k%9==0 else p['hair'],'head')
    # Stubble grows across jaw/cheek and upper lip with a feathered boundary.
    for k in range(750):
        z=rng.uniform(.029,.147);rx,_,_=profile(z);x=rng.uniform(-rx*.95,rx*.95)
        boundary=.075+.065*(abs(x)/.095)**1.3
        moustache=.086<z<.101 and abs(x)<.024 and abs(x)>.006
        if z>boundary and not moustache:continue
        length=rng.uniform(.0007,.0015)
        pts=[xyz(x,z,.001),xyz(x+rng.uniform(-.001,.001),z-length,.0016)]
        strand(a,'Cropped beard',pts,.00022*s,p['hair_light'] if k%13==0 else p['hair'],'head')


def refine_costume(a,p,hz,s):
    """Add compression folds and functional seams to independently skinned parts."""
    sp=a.RIG.data.bones['spine'].head_local.z
    c=a.RIG.data.bones['chest'].head_local.z
    h=a.RIG.data.bones['hips'].head_local.z
    leg_top=a.RIG.data.bones['upperleg.l'].head_local.z
    for ob in a.PARTS:
        kind=ob.name.split('.')[0]
        if kind == 'Mitten palm':
            ob.scale = (.83,.72,.90)
        if kind == 'Boot':
            for v in ob.data.vertices: v.co.z *= .70
            ob.location.z = .052*s
        elif kind == 'Boot cuff':
            ob.location.z -= .025*s
            for v in ob.data.vertices: v.co.z *= 1.12

        if kind in ('Wool tunic','Smith apron'):
            leg_groups={bone:ob.vertex_groups.get(bone) or ob.vertex_groups.new(name=bone) for bone in ('hips','upperleg.l','upperleg.r')}
            for vertex in ob.data.vertices:
                position=ob.matrix_world@vertex.co
                if position.z >= leg_top+.13*s: continue
                follow=max(0,min(1.0,(leg_top+.13*s-position.z)/(.115*s)))
                left=max(0,min(1,.5+position.x/(.035*s)))
                for group in ob.vertex_groups:group.remove([vertex.index])
                for bone,weight in {'hips':1-follow,'upperleg.l':follow*left,'upperleg.r':follow*(1-left)}.items():
                    if weight:leg_groups[bone].add([vertex.index],weight,'REPLACE')
            bpy.context.view_layer.objects.active=ob
            # Existing ring subdivision supplies enough cloth contour resolution.
            for v in ob.data.vertices:
                pos=ob.matrix_world@v.co
                if kind=='Wool tunic':
                    theta=math.atan2(pos.y,pos.x)
                    fold=.0035*math.sin(theta*13+pos.z*9)+.003*math.sin(theta*7-pos.z*17)
                    fold*=.35+.65*min(1,abs(pos.z-sp)/.18)
                    v.co.x+=math.cos(theta)*fold;v.co.y+=math.sin(theta)*fold
                elif kind=='Smith apron':
                    v.co.y+=.0025*math.sin(pos.x*69+pos.z*15)
    # Replace the very thick pale pocket tube with restrained dark stitching.
    for ob in list(a.PARTS):
        if ob.name.startswith('Pocket seam'):
            a.PARTS.remove(ob);bpy.data.objects.remove(ob,do_unlink=True)
    # Stitches down apron edges, following its actual curvature and skin weights.
    for side in (-1,1):
        for i in range(28):
            z=h-.065*s+(c-h+.047*s)*i/27
            t=max(0,min(1,(z-(h-.06*s))/(c-h+.06*s)))
            x=side*(.17-.07*t)*s;y=(-.172-.015*math.sin(math.pi*t)+.030)*s
            w=max(0,min(1,(z-sp)/max(c-sp,.01)))
            weights={'spine':1-w,'chest':w} if z>sp else {'hips':max(0,min(1,(sp-z)/.15)),'spine':1-max(0,min(1,(sp-z)/.15))}
            a.line('Pocket seam',[(x,y,z),(x,y,z+.004*s)],.00065*s,p['cream'],weights)
    # Fitted collar follows the raised tunic neckline.
    verts=[];faces=[]
    for z,rx,ry in [(hz-.11*s,.127*s,.095*s),(hz-.06*s,.104*s,.083*s),(hz-.03*s,.084*s,.075*s),(hz-.014*s,.077*s,.071*s)]:
        for i in range(64):
            t=i*math.tau/64;verts.append((rx*math.cos(t),ry*math.sin(t),z))
    for row in range(3):
        for i in range(64):faces.append((row*64+i,row*64+(i+1)%64,(row+1)*64+(i+1)%64,(row+1)*64+i))
    me=bpy.data.meshes.new('Fitted collar');me.from_pydata(verts,[],faces);me.update()
    ob=bpy.data.objects.new('Wool tunic',me);bpy.context.collection.objects.link(ob);a.finish(ob,'Wool tunic',p['crimson'],'chest')
    # Flexible ankle leather overlaps the shaft and toe through foot rotation.
    for side in ('l','r'):
        ankle=a.RIG.data.bones['foot.'+side].head_local
        a.oval('Boot ankle',(ankle.x,ankle.y-.015*s,.119*s),(.062*s,.078*s,.097*s),p['leather_dark'],'foot.'+side,20,12)
