"""Grounded anatomical forms for the original Reval model studies.

All dimensions in metres. No reference-game geometry or textures are used.
"""
import math
import bpy
from mathutils import Vector

HUMANS = ('kalev','mart','aita','ellen','watchman','henning','jurgen','kaja')
BIRDS = ('robin','hooded_crow','gull','hen','duck')
MAMMALS = ('forge_cat','sheep','dog','pig','goat','boar','fox','hare','rat')


def human_head(a, name, p, hz, s):
    """Ring-sculpted cranial vault, cheek planes and jaw; small inset eyes."""
    woman=name in ('aita','ellen','kaja')
    old=name in ('aita','henning')
    hair=p['silver_hair'] if old else p['hair_light'] if name in ('mart','ellen','kaja') else p['hair']
    wide=.95 if woman else (1.05 if name in ('kalev','jurgen') else 1.0)
    # Chin to crown = 0.263*s, versus the previous 0.51*s sphere.
    rows=[(.027,.040,.054,-.008),(.045,.068,.073,-.012),(.080,.086,.082,-.012),
          (.115,.098,.087,-.006),(.151,.096,.088,0),(.182,.097,.09,.004),
          (.218,.095,.089,.011),(.250,.078,.075,.016),(.278,.038,.045,.017),(.290,.004,.008,.016)]
    # Interpolate profile densely so facial displacement has real surface area.
    coarse=rows;rows=[]
    for aa,bb in zip(coarse,coarse[1:]):
        for j in range(4):rows.append(tuple(x+(y-x)*j/4 for x,y in zip(aa,bb)))
    rows.append(coarse[-1])
    def radius_at(z):
        for aa,bb in zip(coarse,coarse[1:]):
            if aa[0]<=z<=bb[0]:
                t=(z-aa[0])/(bb[0]-aa[0]);return tuple(x+(y-x)*t for x,y in zip(aa[1:],bb[1:]))
        return coarse[-1][1:] if z>coarse[-1][0] else coarse[0][1:]
    def surface(x,z):
        rx,ry,cy=radius_at(z)
        cosine=min(1,abs(x/(rx*wide)))**(1/.85)
        front=math.sqrt(max(0,1-cosine*cosine))
        y=cy-ry*front
        y-=front**8*(.032*math.exp(-((x/.018)**2+((z-.129)/.045)**2))+.018*math.exp(-((x/.020)**2+((z-.117)/.016)**2)))
        y+=front**8*.005*math.exp(-((abs(x)-.04)/.023)**2-((z-.164)/.019)**2)
        return y
    n=64; verts=[]
    for z,rx,ry,cy in rows:
        for i in range(n):
            t=i*math.tau/n
            # Squarer jaw and a restrained flat front; no spherical cheeks.
            x=math.copysign(abs(math.cos(t))**.85,math.cos(t))*rx*wide
            y=math.sin(t)*ry+cy
            if math.sin(t)<0:
                front=(-math.sin(t))**8
                # Integrated bridge, tip, cheekbone and chin volumes.
                y-=front*(.032*math.exp(-((x/.018)**2+((z-.129)/.045)**2))
                    +.018*math.exp(-((x/.020)**2+((z-.117)/.016)**2)))
                y+=front*.005*math.exp(-((abs(x)-.04)/.023)**2-((z-.164)/.019)**2)
            verts.append((x*s,y*s,hz+z*s))
    faces=[(r*n+i,r*n+(i+1)%n,(r+1)*n+(i+1)%n,(r+1)*n+i) for r in range(len(rows)-1) for i in range(n)]
    faces.extend([tuple(reversed(range(n))),tuple((len(rows)-1)*n+i for i in range(n))])
    mesh=bpy.data.meshes.new('Anatomical face');mesh.from_pydata(verts,[],faces);mesh.update()
    obj=bpy.data.objects.new('Face',mesh);bpy.context.collection.objects.link(obj)
    a.finish(obj,'Face',p['skin'],'head')
    a.oval('Neck',(0,.01*s,hz+.01*s),(.052*s,.053*s,.075*s),p['skin'],'head')
    def O(n,loc,sc,mat):
        if n in ('Nostril wing','Nostril'):
            loc=(loc[0],surface(loc[0],loc[2])-.002,loc[2])
        return a.oval(n,(loc[0]*s,loc[1]*s,hz+loc[2]*s),tuple(v*s for v in sc),p[mat],'head',20,12)
    def L(n,points,w,mat):
        if n in ('Upper lip','Lower lip','Mouth'):
            points=[(x,surface(x,z)-.0025,z) for x,y,z in points]
        return a.line(n,[(x*s,y*s,hz+z*s) for x,y,z in points],w*s,p[mat],'head')
    # Sculpted bridge flows into the nose tip; nostril wings remain subtle.
    for side in (-1,1):
        x=side*.041
        O('Ear',(side*.098*wide,.007,.137),(.016,.017,.031),'skin')
        O('Ear concha',(side*.108*wide,-.006,.137),(.006,.005,.018),'blush')
        O('Nostril wing',(side*.015,-.099,.112),(.009,.011,.009),'skin')
        O('Nostril',(side*.012,-.108,.109),(.004,.003,.003),'leather_dark')
        O('Warm sclera',(x,-.085,.163),(.021,.006,.008),'cream')
        O('Iris',(x,-.090,.163),(.007,.003,.007),'iris')
        O('Pupil',(x,-.0925,.163),(.0035,.0015,.004),'eye')
        # Upper lids + brow ridges occlude the white; no toy-like glint disks.
        L('Upper eyelid',[(x-side*.021,-.083,.163),(x,-.092,.170),(x+side*.021,-.080,.163)],.003,'skin')
        L('Lower eyelid',[(x-side*.019,-.083,.162),(x,-.09,.157),(x+side*.019,-.080,.162)],.002,'skin')
        L('Brow ridge',[(x-side*.023,-.081,.182),(x,-.089,.187),(x+side*.026,-.07,.181)],.003,'skin')
        L('Brow',[(x-side*.022,-.084,.186),(x,-.09,.190),(x+side*.024,-.073,.184)],.003,'hair')
        if old:
            L('Eye crease',[(x+side*.023,-.074,.16),(x+side*.032,-.065,.155)],.0013,'blush')
    L('Upper lip',[(-.027,-.087,.086),(-.010,-.096,.090),(0,-.095,.087),(.010,-.096,.090),(.027,-.087,.086)],.0018,'blush')
    L('Mouth',[(-.026,-.089,.083),(0,-.098,.082),(.026,-.089,.083)],.0018,'leather_dark')
    L('Lower lip',[(-.020,-.09,.080),(0,-.096,.077),(.020,-.09,.080)],.0015,'blush')
    # Hair and beard are continuous shells seated on the cranial surface.
    def shell(label, heights, front_only=False):
        vs=[];fs=[]; steps=64
        for z in heights:
            rx,ry,cy=radius_at(z)
            for i in range(steps+1):
                t=(math.pi+math.pi*i/steps) if front_only else math.tau*i/steps
                x=math.copysign(abs(math.cos(t))**.85,math.cos(t))*rx*wide
                y=surface(x,z) if math.sin(t)<0 else math.sin(t)*ry+cy
                # Offset along each radial direction; consistent with face profile.
                vs.append(((x+.004*math.cos(t))*s,(y+.004*math.sin(t))*s,hz+z*s))
        for r in range(len(heights)-1):
            for i in range(steps):
                q=r*(steps+1)+i;fs.append((q,q+1,q+steps+2,q+steps+1))
        me=bpy.data.meshes.new(label);me.from_pydata(vs,[],fs);me.update()
        ob=bpy.data.objects.new(label,me);bpy.context.collection.objects.link(ob)
        a.finish(ob,label,hair,'head')
    shell('Hair back',[.210,.220,.235,.250,.265,.278,.287,.290])
    for i in range(9):
        x=(i-4)*.017
        points=[]
        for j in range(7):
            z=.214+j*.011;xx=x*(1-j*.09)
            points.append((xx*s,(surface(xx,z)-.0048)*s,hz+z*s))
        a.line('Swept ridge',points,.0009*s,hair,'head')
    if name in ('kalev','watchman','jurgen','henning'):
        shell('Cropped beard',[.028,.04,.05,.06,.07],True)
    if woman:
        if name=='aita':a.oval('Bun',(0,.101*s,hz+.215*s),(.047*s,.039*s,.042*s),hair,'head')
        else:
            for side in (-1,1):
                for i in range(7):
                    a.oval('Braid',(side*.09*s,.045*s,hz+(.15-i*.018)*s),(.017*s,.022*s,.02*s),hair,'head',12,8)


# Body centre, forward head, head height, trunk ellipsoid, head ellipsoid,
# lateral stance, fore/back attachment, knee and ankle heights, coat.
SPECS={
 'forge_cat':(.29,-.29,.43,(.13,.28,.16),(.095,.105,.10),.095,-.17,.18,.15,.042,'ginger'),
 'sheep':(.46,-.41,.60,(.24,.42,.255),(.10,.18,.13),.15,-.24,.26,.17,.045,'wool'),
 'dog':(.40,-.37,.59,(.16,.37,.21),(.11,.135,.13),.11,-.23,.24,.20,.05,'brown'),
 'pig':(.34,-.44,.38,(.27,.46,.255),(.18,.23,.17),.17,-.26,.29,.135,.043,'pink'),
 'goat':(.49,-.36,.69,(.18,.35,.23),(.09,.16,.14),.12,-.22,.22,.23,.045,'cream'),
 'boar':(.44,-.43,.47,(.26,.48,.30),(.18,.27,.18),.17,-.26,.29,.18,.05,'stripe'),
 'fox':(.32,-.32,.48,(.12,.31,.155),(.085,.13,.095),.075,-.20,.20,.16,.035,'ginger'),
 'hare':(.22,-.22,.34,(.115,.22,.15),(.085,.10,.10),.07,-.12,.13,.10,.035,'brown'),
 'rat':(.095,-.15,.12,(.061,.16,.069),(.045,.082,.050),.039,-.075,.09,.046,.017,'grey'),
}


def mammal(a,name,p):
    bz,hy,hz,body,head,stance,fy,by,kz,az,color=SPECS[name]
    hoof=name in ('sheep','pig','goat','boar')
    small=name=='rat'
    coat=p[color]; specs=[('Body',(0,0,bz),(0,0,bz+.15),None),('Head',(0,hy+.10,hz-.04),(0,hy,hz+.08),'Body'),('Tail',(0,body[1]*.80,bz),(0,body[1]+.13,bz+.08),'Body')]
    legs=[]
    for side,sign in [('L',1),('R',-1)]:
        for end,y in [('F',fy),('B',by)]:
            suffix=side+end; x=sign*stance
            top=(x,y,bz-.035)
            knee=(x,y+(.055 if end=='F' else -.065)*(0.4 if small else 1),kz)
            ankle=(x,y+(.018 if end=='F' else .07)*(0.4 if small else 1),az)
            toe=(x,ankle[1]-(.035 if not small else .015),az*.55)
            specs.extend([(f'Leg.{suffix}',top,knee,'Body'),(f'Shin.{suffix}',knee,ankle,f'Leg.{suffix}'),(f'Foot.{suffix}',ankle,toe,f'Shin.{suffix}')])
            legs.append((suffix,top,knee,ankle,toe))
    a.make_rig(specs)
    a.RIG['species']=name
    a.oval('Trunk',(0,.02,bz),body,coat,'Body',32,20)
    if name in ('dog','fox','goat','forge_cat'):
        a.segment('Neck',(0,fy,bz+.055),(0,hy+.055,hz-.025),head[0]*.93,coat,{'Body':.35,'Head':.65})
    a.oval('Head',(0,hy,hz),head,p['leather_dark'] if name=='sheep' else coat,'Head',24,16)
    eye_size=.007 if small else (.010 if hoof else .013)
    for side in (-1,1):
        ex=side*head[0]*.79; ey=hy-head[1]*.62; ez=hz+head[2]*.24
        a.oval('Eye',(ex,ey,ez),(eye_size,eye_size*.55,eye_size*.73),p['eye'],'Head',16,10)
        # Ears attach behind the eyes, with species-specific silhouettes.
        if name=='dog':
            o=a.oval('Ear',(side*.11,hy+.025,hz-.01),(.039,.058,.105),p['stripe'],'Head');o.rotation_euler.y=side*.2
        elif name in ('sheep','goat'):
            o=a.oval('Ear',(side*.13,hy+.025,hz+.04),(.095,.036,.028),coat,'Head');o.rotation_euler.y=side*.15
        elif name=='rat':a.oval('Ear',(side*.038,hy+.01,hz+.045),(.022,.013,.025),p['pink'],'Head')
        else:
            height=.235 if name=='hare' else (.105 if name in ('pig','boar') else .13)
            x=side*head[0]*.69
            a.segment('Ear',(x,hy+.035,hz+head[2]*.50),(x*1.25,hy+.065,hz+head[2]*.50+height),.046 if name!='hare' else .027,coat,'Head',.003)
            a.segment('Ear lining',(x,hy+.001,hz+head[2]*.66),(x*1.23,hy+.042,hz+head[2]*.50+height*.83),.023 if name!='hare' else .013,p['blush'],'Head',.002)
    if name in ('pig','boar'):
        a.segment('Muzzle',(0,hy-.09,hz-.045),(0,hy-.28,hz-.055),.125,coat,'Head',.075)
        a.oval('Snout disc',(0,hy-.285,hz-.055),(.08,.026,.052),p['blush'] if name=='pig' else p['leather_dark'],'Head')
        for side in (-1,1):
            a.oval('Nostril',(side*.029,hy-.31,hz-.05),(.012,.006,.009),p['dark'],'Head',12,8)
            if name=='boar':a.line('Tusk',[(side*.095,hy-.19,hz-.10),(side*.13,hy-.24,hz-.04),(side*.12,hy-.24,hz+.015)],.012,p['ivory'],'Head')
        if name=='pig':a.line('Curled tail',[(0,by+.1,bz),(.04,by+.18,bz+.025),(.045,by+.17,bz+.08),(0,by+.14,bz+.08),(0,by+.16,bz+.04)],.012,coat,'Tail')
        else:
            a.line('Tail',[(0,by+.1,bz),(0,by+.25,bz-.03),(.03,by+.3,bz-.11)],.015,coat,'Tail')
            for i in range(8):a.segment('Bristle',(0,-.15+i*.075,bz+body[2]*.88),(0,-.12+i*.075,bz+body[2]+.045),.018,p['leather_dark'],'Body',.001)
    elif name in ('dog','fox'):
        length=.15 if name=='dog' else .14
        a.segment('Muzzle',(0,hy-.07,hz-.022),(0,hy-head[1]-length*.55,hz-.045),.071 if name=='dog' else .050,p['cream'],'Head',.036 if name=='dog' else .024)
        a.oval('Nose',(0,hy-head[1]-length*.55,hz-.035),(.035 if name=='dog' else .025,.023,.019),p['dark'],'Head')
        a.oval('Chest',(0,fy-.07,bz+.02),(.105,.06,.14),p['cream'],'Body')
        points=[(0,body[1]*.8,bz),(.02,body[1]+.12,bz-.035),(.05,body[1]+.32,bz-.10)]
        a.line('Tail',points,.055 if name=='fox' else .027,coat,'Tail')
        if name=='fox':a.segment('Tail tip',points[-1],(.06,body[1]+.45,bz-.09),.054,p['cream'],'Tail',.006)
    elif name in ('sheep','goat'):
        a.oval('Muzzle',(0,hy-.145,hz-.065),(.073,.07,.067),p['leather_dark'],'Head')
        if name=='sheep':
            for j in range(10):
                yy=-.32+j*.071
                for i in range(16):
                    t=i*math.tau/16+(j%2)*.13
                    shift=.009*math.sin(i*11+j*3)
                    a.oval('Fleece',((.233+shift)*math.cos(t),yy+shift,bz+(.249+shift)*math.sin(t)),(.043,.052,.043),p['wool'] if (i+j)%3 else p['cream'],'Body',12,8)
        else:
            for side in (-1,1):
                a.segment('Horn base',(side*.061,hy+.02,hz+.11),(side*.07,hy+.08,hz+.23),.023,p['hoof'],'Head',.014)
                a.segment('Horn tip',(side*.07,hy+.08,hz+.23),(side*.065,hy+.16,hz+.29),.014,p['hoof'],'Head',.001)
            a.segment('Beard',(0,hy-.10,hz-.11),(0,hy-.09,hz-.22),.035,p['leather_dark'],'Head',.005)
        a.oval('Tail',(0,body[1],bz),(.04,.09,.044),coat,'Tail')
    elif name=='forge_cat':
        for side in (-1,1):
            a.oval('Muzzle',(side*.029,hy-.087,hz-.037),(.038,.031,.028),p['cream'],'Head')
            for j in range(2):a.line('Whisker',[(side*.04,hy-.107,hz-.037),(side*.10,hy-.10,hz-.03-j*.02),(side*.15,hy-.07,hz-.023-j*.028)],.0011,p['cream'],'Head')
        a.oval('Nose',(0,hy-.119,hz-.023),(.011,.007,.008),p['pink'],'Head')
        a.line('Tail',[(0,.24,bz),(.03,.40,bz+.07),(.08,.5,bz+.27),(.05,.48,bz+.34)],.025,coat,'Tail')
        for i in range(4):
            yy=-.10+i*.095
            a.line('Tabby marking',[(-.11,yy,bz+.07),(0,yy,bz+.162),(.11,yy,bz+.07)],.009,p['stripe'],'Body')
    elif name=='hare':
        a.oval('Muzzle',(0,hy-.093,hz-.029),(.045,.025,.028),p['cream'],'Head')
        a.oval('Nose',(0,hy-.118,hz-.017),(.009,.006,.006),p['dark'],'Head')
        a.oval('Tail',(0,.24,bz+.015),(.047,.043,.048),p['cream'],'Tail')
    else:
        a.segment('Muzzle',(0,hy-.04,hz-.005),(0,hy-.102,hz-.015),.033,coat,'Head',.008)
        a.oval('Nose',(0,hy-.105,hz-.015),(.009,.006,.006),p['pink'],'Head')
        a.line('Tail',[(0,.13,bz),(.03,.25,.06),(.08,.34,.025),(.12,.38,.023)],.009,p['pink'],'Tail')
    for suffix,top,knee,ankle,toe in legs:
        rad=.012 if small else (.031 if name in ('forge_cat','fox','hare') else .045)
        a.oval('Shoulder',top,(rad*1.3,rad*1.35,rad*1.5),coat,'Leg.'+suffix,16,10)
        a.segment('Upper leg',top,knee,rad*1.25,coat,'Leg.'+suffix,rad*.83)
        a.oval('Joint',knee,(rad*.87,)*3,coat,'Leg.'+suffix,16,10)
        a.segment('Lower leg',knee,ankle,rad*.81,p['leather_dark'] if name in ('sheep','goat','fox') else coat,'Shin.'+suffix,rad*.58)
        a.oval('Hoof' if hoof else 'Paw',toe,(rad*.97,rad*1.65,az*.55),p['hoof'] if hoof else coat,'Foot.'+suffix,16,10)
        if hoof:
            a.line('Cloven split',[(toe[0],toe[1]-rad*1.64,toe[2]),(toe[0],toe[1]-rad*1.35,toe[2]+az*.43)],.002,p['dark'],'Foot.'+suffix)
    mesh=a.bind_join();a.animate_fauna(False)
    return mesh


def limb(a, name, joints, radii, materials, bones):
    """Continuous sleeve/hose across the bending joint, with blended skinning."""
    start,joint,end=map(Vector,joints)
    rings=[(start,radii[0],{bones[0]:1}),
           (start.lerp(joint,.18),radii[1],{bones[0]:1}),
           (start.lerp(joint,.78),radii[2],{bones[0]:.9,bones[1]:.1}),
           (joint,radii[2],{bones[0]:.5,bones[1]:.5}),
           (joint.lerp(end,.20),radii[3],{bones[0]:.1,bones[1]:.9}),
           (joint.lerp(end,.80),radii[4],{bones[1]:1}),
           (end,radii[4],{bones[1]:1})]
    if name.startswith('upperarm.'):
        rings.insert(0,(start-(joint-start).normalized()*radii[0]*.6,radii[0]*.52,{bones[0]:1}))
    verts=[]; n=20
    for idx,(pos,rad,w) in enumerate(rings):
        tangent=(rings[min(idx+1,len(rings)-1)][0]-rings[max(idx-1,0)][0]).normalized()
        u=tangent.cross(Vector((0,1,0))).normalized();v=tangent.cross(u).normalized()
        for i in range(n):verts.append(pos+rad*(u*math.cos(i*math.tau/n)+v*math.sin(i*math.tau/n)))
    faces=[(r*n+i,r*n+(i+1)%n,(r+1)*n+(i+1)%n,(r+1)*n+i) for r in range(len(rings)-1) for i in range(n)]
    faces.extend([tuple(reversed(range(n))),tuple((len(rings)-1)*n+i for i in range(n))])
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
    obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj);a.finish(obj,name,materials,{})
    for r,(_,_,weights) in enumerate(rings):
        for bone,weight in weights.items():
            g=obj.vertex_groups.get(bone) or obj.vertex_groups.new(name=bone);g.add(list(range(r*n,(r+1)*n)),weight,'REPLACE')
    bpy.context.view_layer.objects.active=obj
    mod=obj.modifiers.new('Continuous cloth','SUBSURF');mod.levels=1;bpy.ops.object.modifier_apply(modifier=mod.name)
