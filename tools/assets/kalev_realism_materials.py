"""Deterministic original PBR maps for Kalev; embedded into portable GLBs.

No external images or bake dependency. UV detail survives Godot GL Compatibility.
"""
import math
import bpy
import numpy as np


def image(name, rgb, color=True):
    h, w = rgb.shape[:2]
    im = bpy.data.images.new(name, width=w, height=h, alpha=True)
    if not color:
        im.colorspace_settings.name = 'Non-Color'
    pixels = np.ones((h, w, 4), dtype=np.float32)
    rgb = np.clip(rgb, 0, 1)
    if color:
        rgb = np.where(rgb <= .04045, rgb/12.92, ((rgb+.055)/1.055)**2.4)
    pixels[:, :, :3] = rgb
    im.pixels.foreach_set(pixels.ravel())
    im.pack()
    return im


def material(name, base, family, size=512):
    rng = np.random.default_rng(207)
    v, u = np.mgrid[0:size, 0:size] / size
    grain = rng.normal(0, 1, (size, size))
    broad = (np.sin(u*math.tau*3+.6*np.sin(v*math.tau*2)) + np.sin(v*math.tau*5+u*math.tau))*.5
    fine = np.sin(u*math.tau*64) * np.sin(v*math.tau*61)
    rough = np.full_like(u, .75)
    variation = .035*broad + .008*grain
    bump = .012*grain
    if family == 'skin':
        variation = .025*broad + .006*grain
        rough = .57+.04*broad+.02*grain
        bump = .012*grain+.009*fine
    elif family == 'cloth':
        weave = np.sin(u*math.tau*64)*np.sin(v*math.tau*64)
        variation = .04*broad+.027*weave+.015*grain
        bump = .045*weave+.02*grain
        rough = .88+.03*broad
    elif family == 'leather':
        creases = np.maximum(0, np.sin(u*55+np.sin(v*37)*2))**16
        variation = .09*broad+.018*grain-.05*creases
        bump = .025*grain-.035*creases
        rough = .70+.09*broad
    elif family == 'hair':
        strands = np.sin(u*math.tau*155+.4*np.sin(v*14))
        variation = .10*strands+.035*broad+.018*grain
        bump = .11*strands
        rough = .66+.05*broad
    elif family == 'metal':
        variation = .035*broad+.012*grain
        rough = .47+.12*broad
        bump = .015*grain
    elif family == 'mail':
        # Alternating overlapping ovals, carried as PBR instead of giant torus beads.
        xx = (u*92 + (np.floor(v*102)%2)*.5)%1-.5
        yy = (v*102)%1-.5
        ring = np.exp(-((np.sqrt((xx/.37)**2+(yy/.43)**2)-1)/.19)**2)
        variation = .12*ring-.06
        bump = ring*.15
        rough = .54+.1*(1-ring)
    rgb = np.clip(np.array(base)[None,None,:]*(1+variation[:,:,None]), 0, 1)
    if family == 'skin':
        front = np.maximum(0, -np.sin(u*math.tau))**12
        z = .018+v*.278
        # Small warm/cool changes around the cheeks/nose and under-eye region.
        redness = front*np.exp(-((z-.128)/.041)**2)*.013
        rgb[:,:,0] += redness
        rgb[:,:,1] -= redness*.45
        x=.095*np.cos(u*math.tau)
        boundary=.075+.065*(np.abs(x)/.095)**1.3
        beard=np.clip((boundary-z)/.014,0,1)*front*np.clip((z-.025)/.012,0,1)
        rgb *= (1-beard[:,:,None]*.30)
        pores=(grain < -1.6)*.012
        rgb -= pores[:,:,None]*front[:,:,None]
    dy, dx = np.gradient(bump)
    normal = np.stack((-dx*1.7, -dy*1.7, np.ones_like(u)), axis=2)
    normal /= np.linalg.norm(normal, axis=2)[:,:,None]
    normal = normal*.5+.5
    mat = bpy.data.materials.new('kalev_'+name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    bsdf = nodes.get('Principled BSDF')
    bsdf.inputs['Roughness'].default_value = .7
    bsdf.inputs['Specular IOR Level'].default_value = .28
    bsdf.inputs['Metallic'].default_value = .8 if family in ('metal','mail') else 0
    for label, data, color, socket in [('Albedo',rgb,True,'Base Color'),('Roughness',np.repeat(np.clip(rough,.2,.98)[:,:,None],3,axis=2),False,'Roughness')]:
        tex = nodes.new('ShaderNodeTexImage');tex.image=image('kalev_'+name+'_'+label,data,color)
        links.new(tex.outputs['Color'],bsdf.inputs[socket])
    tex = nodes.new('ShaderNodeTexImage');tex.image=image('kalev_'+name+'_Normal',normal,False)
    nm=nodes.new('ShaderNodeNormalMap');nm.inputs['Strength'].default_value=.35;links.new(tex.outputs['Color'],nm.inputs['Color']);links.new(nm.outputs['Normal'],bsdf.inputs['Normal'])
    return mat


def palette(p):
    definitions = {
        'skin': ('skin',(.64,.54,.48),'skin',512),
        'blush': ('lip',(.58,.43,.39),'skin',256),
        'hair': ('hair',(.25,.20,.16),'hair',256),
        'hair_light': ('hair_tip',(.30,.25,.20),'hair',256),
        'crimson': ('wool',(.47,.21,.17),'cloth',512),
        'cream': ('linen',(.61,.55,.43),'cloth',256),
        'hose': ('hose',(.23,.245,.22),'cloth',256),
        'leather': ('apron',(.39,.27,.17),'leather',512),
        'leather_dark': ('boot',(.23,.18,.13),'leather',256),
        'steel': ('steel',(.43,.48,.49),'metal',256),
        'mail': ('mail',(.38,.42,.44),'mail',512),
        'blue': ('cape',(.14,.20,.23),'cloth',512),
    }
    for key,args in definitions.items(): p[key]=material(*args)
    return p


def unwrap(objects):
    """Non-overlapping UVs for wearable mesh sections; face keeps authored UVs."""
    for obj in objects:
        if obj.data.uv_layers: continue
        bpy.ops.object.select_all(action='DESELECT');obj.select_set(True)
        bpy.context.view_layer.objects.active=obj
        bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
        bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=.012)
        bpy.ops.object.mode_set(mode='OBJECT')
