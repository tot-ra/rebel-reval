"""Species-authored limb landmarks and build-time foot-contact animation.

Blender coordinates: +Z up, -Y toward the nose. Dimensions are art placements,
not veterinary measurements. Anatomy reference: vanat.ahc.umn.edu/run/plate4.html.
The hock/carpus and metapodial are separate from the digit-bearing foot.
"""
from dataclasses import dataclass
import math


@dataclass(frozen=True)
class Limb:
    suffix: str
    points: tuple
    radius: float
    foot_width: float
    foot_height: float
    digits: int
    hoof: bool

    @property
    def hind(self):
        return self.suffix.endswith('B')

    @property
    def bones(self):
        return tuple(f'{prefix}.{self.suffix}' for prefix in ('Leg','Shin','Ankle','Foot'))


# Shoulder, elbow, carpus; hip, stifle, hock heights relative to trunk centre.
# Last entries: fore/hind foot length, half-width, sole height and limb radius.
PROPORTIONS = {
    'dog':       ((1.00,.69,.21),(1.13,.76,.37),.065,.061,.029,.025,.032),
    'forge_cat': ((1.04,.70,.20),(1.15,.77,.37),.045,.047,.022,.019,.020),
    'fox':       ((1.05,.70,.22),(1.17,.77,.39),.050,.046,.022,.020,.020),
    'sheep':     ((1.05,.72,.36),(1.12,.82,.48),.058,.054,.035,.035,.030),
    'goat':      ((1.03,.72,.34),(1.10,.80,.46),.052,.050,.031,.030,.026),
    'pig':       ((1.01,.72,.31),(1.12,.82,.44),.063,.059,.037,.032,.043),
    'boar':      ((1.02,.72,.32),(1.13,.82,.44),.069,.065,.040,.034,.047),
    'hare':      ((1.05,.61,.23),(1.18,.74,.25),.046,.120,.023,.018,.019),
    'rat':       ((.93,.52,.23),(1.09,.65,.29),.025,.040,.011,.008,.009),
}


def landmarks(species, bz, stance, fore_y, hind_y):
    front, rear, fore_length, hind_length, width, height, radius = PROPORTIONS[species]
    limbs=[]
    for side,sign in (('L',1),('R',-1)):
        for end,y,heights,length in (('F',fore_y,front,fore_length),('B',hind_y,rear,hind_length)):
            hind=end=='B'
            # Upper limb roots sit inside the trunk; paws support its underside.
            x=sign*stance*(.88 if species in ('dog','forge_cat','fox') else .94)
            root=(x,y,bz*heights[0])
            if hind:
                joint=(x,y-bz*(.31 if species!='hare' else .40),bz*heights[1])
                ankle=(x,y+bz*(.19 if species!='hare' else .34),bz*heights[2])
                ball=(x,y+bz*.025,height)
                if species in ('hare','rat'):
                    ball=(x,ankle[1]-length*.72,height)
                    length*=.28
            else:
                joint=(x,y+bz*.19,bz*heights[1])
                ankle=(x,y+bz*.018,bz*heights[2])
                ball=(x,y-bz*.014,height)
            toe=(x,ball[1]-length,height*.66)
            digits=2 if species in ('sheep','goat','pig','boar') else (5 if species=='rat' and hind else 4)
            limbs.append(Limb(side+end,(root,joint,ankle,ball,toe),radius,
                              width*(.91 if hind and species=='fox' else 1),height,digits,digits==2))
    return limbs


def distance(a,b):
    return math.sqrt(sum((x-y)**2 for x,y in zip(a,b)))


def solve_joint(root, target, upper, lower, backward):
    """Analytic sagittal two-bone solve; no length scaling or hyperextension."""
    dy,dz=target[1]-root[1],target[2]-root[2]
    d=math.hypot(dy,dz)
    if not abs(upper-lower)+1e-7 < d < upper+lower-1e-7:
        raise ValueError(f'Limb target outside reach: {d:.5f}, lengths {upper:.5f}/{lower:.5f}')
    along=(upper*upper-lower*lower+d*d)/(2*d)
    across=math.sqrt(max(0,upper*upper-along*along))
    # Perpendicular points backward (+Y) when the target is below the root.
    sign=1 if backward else -1
    return (root[0],root[1]+dy/d*along+sign*(-dz/d)*across,
            root[2]+dz/d*along+sign*(dy/d)*across)


def foot_path(phase, stride, clearance, duty=.68):
    """Linear planted support followed by smooth raised recovery; periodic."""
    phase=phase%1
    if phase<duty:
        return (-stride/2+stride*phase/duty,0.0,True)
    t=(phase-duty)/(1-duty)
    smooth=t*t*(3-2*t)
    return (stride/2-stride*smooth,clearance*math.sin(math.pi*t)**2,False)


def pose_points(limb, travel=0, lift=0, body_drop=0):
    root,joint,ankle,ball,toe=limb.points
    root=(root[0],root[1],root[2]+body_drop)
    # The distal segment keeps its support angle; the proximal joints flex.
    ankle=(ankle[0],ankle[1]+travel,ankle[2]+lift)
    ball=(ball[0],ball[1]+travel,ball[2]+lift)
    toe=(toe[0],toe[1]+travel,toe[2]+lift)
    joint=solve_joint(root,ankle,distance(limb.points[0],limb.points[1]),
                      distance(limb.points[1],limb.points[2]),not limb.hind)
    return (root,joint,ankle,ball,toe)


def cycle(species, limb, t, running=False):
    bz=limb.points[0][2]/PROPORTIONS[species][1 if limb.hind else 0][0]
    # Lateral four-beat walk; diagonal pair timing is reserved for trot/run.
    phases={'LB':0,'LF':.25,'RB':.5,'RF':.75}
    if running:
        phases={'LF':0,'RB':0,'RF':.5,'LB':.5}
    if species=='hare':
        # Compact bound: hind drive precedes staggered fore contacts.
        phases={'LB':0,'RB':.025,'LF':.46,'RF':.52}
    phase=t-phases[limb.suffix]
    stride=bz*(.65 if running else .48)
    if species=='hare':stride=bz*(.60 if running else .50)
    clearance=bz*(.11 if running else .075)
    duty=.58 if running else .72 if species=='hare' else .68
    travel,lift,planted=foot_path(phase,stride,clearance,duty)
    return pose_points(limb,travel,lift),planted


def build_skin(a, limbs, coat, species):
    """Lean forearms, proximal thigh mass and distinct distal metapodials."""
    for limb in limbs:
        top,knee,hock,ball,toe=limb.points
        upper,lower,distal,foot=limb.bones
        r=limb.radius
        if limb.hind:
            # Femoral bulk follows the angled femur inside the flank.
            a.segment('Thigh',top,knee,r*(2.7 if species=='hare' else 1.95 if species in ('pig','boar') else 1.65),coat,
                      {upper:.85,'Body':.15},r*.98)
        else:
            a.segment('Upper arm',top,knee,r*1.17,coat,{upper:.85,'Body':.15},r*.83)
        a.oval('Stifle' if limb.hind else 'Elbow',knee,(r*.85,r*.94,r*1.05),coat,{upper:.45,lower:.55})
        # Flesh ends above the hock/wrist; lower parts carry tendons, not calf balls.
        a.segment('Gaskin' if limb.hind else 'Forearm',knee,hock,r*(1.8 if species=='hare' and limb.hind else 1.3 if species in ('pig','boar') else .98),coat,lower,r*.57)
        a.oval('Hock' if limb.hind else 'Carpus',hock,(r*.58,r*.70,r*.62),coat,{lower:.35,distal:.65})
        a.segment('Metatarsus' if limb.hind else 'Metacarpus',hock,ball,
                  r*(.87 if limb.hind and species in ('hare','rat') else .49),coat,distal,r*.44)
        if not limb.hoof:
            # Long hare/rat hind foot; compact rounded carnivore digit platform.
            mid=tuple((v+w)/2 for v,w in zip(ball,toe))
            a.oval('Foot pad',mid,(limb.foot_width*.90,distance(ball,toe)*.56,limb.foot_height*.70),coat,foot,24,12)


def build_feet(a, limbs, coat, keratin, species):
    """Flat cloven soles or four/five digit paws; accessory toes stay raised."""
    import bpy
    for limb in limbs:
        top,knee,hock,ball,toe=limb.points
        foot=limb.bones[-1];w=limb.foot_width;h=limb.foot_height
        if limb.hoof:
            length=ball[1]-toe[1]
            for side in (-1,1):
                cx=ball[0]+side*w*.48
                # Heel, wall and sloping toe share a flat weight-bearing sole.
                rings=[(0,.92,0),(.22*h,1,0),(.97*h,.77,length*.13)]
                verts=[]
                outline=[(-.43,.18),(-.47,-.45),(-.30,-1.04),(.29,-1.04),(.43,-.45),(.40,.18)]
                for z,scale,offset in rings:
                    verts += [(cx+x*w*scale,ball[1]+y*length+offset,z) for x,y in outline]
                n=len(outline);faces=[tuple(reversed(range(n))),tuple(2*n+i for i in range(n))]
                for row in range(2):
                    for i in range(n):faces.append((row*n+i,row*n+(i+1)%n,(row+1)*n+(i+1)%n,(row+1)*n+i))
                mesh=bpy.data.meshes.new('Cloven sole');mesh.from_pydata(verts,[],faces);mesh.update()
                ob=bpy.data.objects.new('Hoof',mesh);bpy.context.collection.objects.link(ob)
                a.finish(ob,'Hoof',keratin,foot)
                # Developed pig accessory claws; smaller ruminant dewclaws.
                factor=.35 if species in ('pig','boar') else .23
                a.oval('Dewclaw',(cx,ball[1]+length*.17,h*1.65),(w*factor,w*factor,h*.26),keratin,limb.bones[2],12,8)
        else:
            for i in range(limb.digits):
                across=(i-(limb.digits-1)/2)/(limb.digits-1)
                x=toe[0]+across*w*1.5
                y=toe[1]+abs(across)*h*.40
                # Toes terminate at the ground without the old overlarge spheres.
                a.oval('Digit',(x,y,h*.36),(w/(limb.digits)*.87,h*.61,h*.36),coat,foot,16,10)
                if species!='forge_cat':
                    a.segment('Claw',(x,y-h*.40,h*.25),(x,y-h*.78,h*.13),w*.055,keratin,foot,.0004)
            if not limb.hind and species in ('dog','fox','forge_cat','hare'):
                sign=1 if limb.suffix.startswith('L') else -1
                a.oval('Medial dewclaw',(ball[0]-sign*w*.9,ball[1]+h*.16,h*1.8),(w*.18,h*.24,h*.24),coat,limb.bones[2],12,8)


def animate(a, species, limbs):
    """Bake solved limb poses; runtime needs only its existing named clips."""
    import bpy
    from mathutils import Vector, Matrix, Euler
    rig=a.RIG
    rig.animation_data_create()
    clips=['Idle','Walk','LookAround','Run','Graze','Alert']
    if species=='forge_cat':clips+=['Sleep','Groom','Stretch']
    for clip in clips:
        action=bpy.data.actions.new(clip);action.use_fake_user=True
        rig.animation_data.action=action
        for frame in range(49):
            progress=frame/48;t=progress*math.tau
            for pb in rig.pose.bones:
                pb.rotation_mode='QUATERNION';pb.matrix_basis.identity()
            drop=0.0
            if clip=='Sleep':drop=-.08
            if clip=='Stretch':drop=-.012*(1-math.cos(t))*.5
            rig.pose.bones['Body'].location.y=drop
            head=rig.pose.bones['Head']
            angles=(0,0,.035*math.sin(t))
            if clip=='LookAround':angles=(.06*math.sin(t*2),0,.28*math.sin(t))
            elif clip=='Graze':angles=(.60*(1-math.cos(t))*.5,0,.025*math.sin(t))
            elif clip=='Alert':angles=(-.12*(1-math.cos(t))*.5,0,.08*math.sin(t))
            elif clip=='Sleep':angles=(.18,0,.10)
            elif clip=='Groom':angles=(.3+.10*math.sin(t*2),0,.23)
            elif clip=='Stretch':angles=(.16*(1-math.cos(t))*.5,0,0)
            head.rotation_quaternion=Euler(angles).to_quaternion()
            rig.pose.bones['Tail'].rotation_quaternion=Euler((0,.08*math.sin(t),0)).to_quaternion()
            body_rest=rig.data.bones['Body'].matrix_local
            body_pose=body_rest @ rig.pose.bones['Body'].matrix_basis
            poses={'Body':body_pose}
            for limb in limbs:
                points,_=cycle(species,limb,progress,clip=='Run') if clip in ('Walk','Run') else (pose_points(limb,body_drop=drop),True)
                if clip=='Groom' and limb.suffix=='LF':
                    points=pose_points(limb,travel=-.018,lift=.075)
                for i,bone_name in enumerate(limb.bones):
                    pb=rig.pose.bones[bone_name];rest=pb.bone.matrix_local
                    start,end=Vector(points[i]),Vector(points[i+1])
                    rest_dir=pb.bone.tail_local-pb.bone.head_local
                    rotation=rest_dir.rotation_difference(end-start).to_matrix().to_4x4()
                    desired=Matrix.Translation(start) @ rotation @ rest.to_3x3().to_4x4()
                    parent=pb.parent.name
                    pb.matrix_basis=rest.inverted() @ pb.parent.bone.matrix_local @ poses[parent].inverted() @ desired
                    poses[bone_name]=desired
            for pb in rig.pose.bones:
                pb.keyframe_insert('rotation_quaternion',frame=frame,group=pb.name)
                pb.keyframe_insert('location',frame=frame,group=pb.name)
        # Explicit linear keys avoid Bezier contact overshoot between samples.
        for layer in action.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    for fc in bag.fcurves:
                        for key in fc.keyframe_points:key.interpolation='LINEAR'
        rig.animation_data.action=None
    bpy.context.scene.render.fps=48
