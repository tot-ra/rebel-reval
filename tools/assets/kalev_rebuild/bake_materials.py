"""Bake original procedural textile/leather/mail shaders to portable PBR maps.

This is a Blender material bake, not editing the generated character images.
"""
from pathlib import Path
import bpy,math
ROOT=Path(__file__).resolve().parents[3];OUT=ROOT/'assets/characters/kalev_rebuild/materials'
OUT.mkdir(exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
s=bpy.context.scene;s.render.engine='CYCLES';s.cycles.samples=1;s.render.threads_mode='FIXED';s.render.threads=4
bpy.ops.mesh.primitive_plane_add(size=2);plane=bpy.context.object

def make_map(name,kind,color):
    mat=bpy.data.materials.new(name);mat.use_nodes=True;plane.data.materials.clear();plane.data.materials.append(mat)
    n=mat.node_tree.nodes;l=mat.node_tree.links;p=n.get('Principled BSDF')
    uv=n.new('ShaderNodeTexCoord')
    noise=n.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=22 if kind=='leather' else 65;noise.inputs['Detail'].default_value=3;l.new(uv.outputs['UV'],noise.inputs['Vector'])
    ramp=n.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].position=.22;ramp.color_ramp.elements[0].color=(*[v*.55 for v in color],1);ramp.color_ramp.elements[1].position=.8;ramp.color_ramp.elements[1].color=(*[min(1,v*1.25) for v in color],1);l.new(noise.outputs['Fac'],ramp.inputs[0])
    height=noise.outputs['Fac'];base=ramp.outputs['Color']
    if kind=='cloth':
        weave=n.new('ShaderNodeTexWave');weave.wave_type='BANDS';weave.bands_direction='X';weave.inputs['Scale'].default_value=100;weave.inputs['Distortion'].default_value=1.5;l.new(uv.outputs['UV'],weave.inputs['Vector']);height=weave.outputs['Color']
    if kind=='mail':
        tex=n.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(ROOT/'assets/characters/kalev_rebuild/reference/mail.png'));l.new(uv.outputs['UV'],tex.inputs['Vector']);base=tex.outputs['Color']
        luminance=n.new('ShaderNodeRGBToBW');l.new(base,luminance.inputs[0]);height=luminance.outputs[0]
    bump=n.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.5;bump.inputs['Distance'].default_value=.014 if kind=='mail' else .003;l.new(height,bump.inputs['Height']);l.new(bump.outputs['Normal'],p.inputs['Normal'])
    emit=n.new('ShaderNodeEmission');l.new(base,emit.inputs['Color']);l.new(emit.outputs[0],n.get('Material Output').inputs['Surface'])
    for mode in ('albedo','normal'):
        image=bpy.data.images.new(f'{name}_{mode}',width=1024,height=1024,alpha=False);image.filepath_raw=str(OUT/f'{name}_{mode}.png');image.file_format='PNG'
        tex=n.new('ShaderNodeTexImage');tex.image=image;n.active=tex
        if mode=='normal':
            l.new(p.outputs[0],n.get('Material Output').inputs['Surface']);image.colorspace_settings.name='Non-Color'
        bpy.ops.object.bake(type='EMIT' if mode=='albedo' else 'NORMAL',margin=8)
        image.save()
    print('BAKED',name,flush=True)

for name,kind,color in [('linen','cloth',(.49,.43,.32)),('wool','cloth',(.11,.16,.145)),('leather','leather',(.16,.075,.035)),('mail','mail',(.22,.24,.245)),('hose','cloth',(.095,.11,.085)),('boot_leather','leather',(.075,.042,.023))]:make_map(name,kind,color)
