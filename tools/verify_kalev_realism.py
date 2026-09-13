#!/usr/bin/env python3
"""Portable P0-210 checks without Blender/Godot; optional pre-edit rig parity."""
import argparse
import json
from pathlib import Path
from verify_storybook_models import ROOT, read_glb, accessor


def near(a,b):
    if isinstance(a,dict): return a.keys()==b.keys() and all(near(v,b[k]) for k,v in a.items())
    if isinstance(a,(list,tuple)): return len(a)==len(b) and all(near(x,y) for x,y in zip(a,b))
    if isinstance(a,(int,float)): return abs(a-b)<1e-6
    return a==b


def verify(baseline=None):
    path=ROOT/'assets/storybook/kalev.glb'
    doc,blob=read_glb(path)
    triangles=sum(doc['accessors'][p['indices']]['count']//3 for m in doc['meshes'] for p in m['primitives'])
    assert triangles<=60000, f'Hero exceeds 60,000 triangles: {triangles}'
    assert path.stat().st_size<10*1024**2, 'Hero exceeds portable 10 MiB budget'
    assert len(doc['animations'])==76
    skin=doc['skins'][0]
    bones=[doc['nodes'][j]['name'] for j in skin['joints']]
    bind=accessor(doc,blob,skin['inverseBindMatrices'])
    regions={n['name'] for n in doc['nodes'] if 'mesh' in n}
    assert {'Character_Head','Anatomy_Hands','Hair_Scalp','Hair_Beard','Clothing_Torso','Clothing_Sleeve','Clothing_Cuffs','Clothing_Outerwear','Clothing_Legs','Clothing_Feet'}<=regions
    for mesh in doc['meshes']:
        for prim in mesh['primitives']:
            attrs=prim['attributes']
            assert {'NORMAL','TEXCOORD_0','JOINTS_0','WEIGHTS_0'}<=attrs.keys()
            assert all(abs(sum(w)-1)<1e-5 for w in accessor(doc,blob,attrs['WEIGHTS_0']))
    # A planted pelvis alone cannot carry a skirt through a running thigh swing.
    leg_indices={i for i,name in enumerate(bones) if name in ('upperleg.l','upperleg.r')}
    torso_node=next(n for n in doc['nodes'] if n.get('name')=='Clothing_Torso')
    samples=[]
    for primitive in doc['meshes'][torso_node['mesh']]['primitives']:
        attrs=primitive['attributes']
        samples.extend(zip(accessor(doc,blob,attrs['POSITION']),accessor(doc,blob,attrs['JOINTS_0']),accessor(doc,blob,attrs['WEIGHTS_0'])))
    bottom=min(p[1] for p,j,w in samples)
    hem=[(j,w) for p,j,w in samples if p[1]<bottom+.035]
    assert hem and all(sum(weight for joint,weight in zip(j,w) if joint in leg_indices)>.35 for j,w in hem), 'Tunic hem must follow leg motion'
    required={'kalev_skin','kalev_hair','kalev_wool','kalev_apron','kalev_boot'}
    for mat in doc['materials']:
        if mat.get('name') in required:
            pbr=mat['pbrMetallicRoughness']
            assert 'baseColorTexture' in pbr and 'metallicRoughnessTexture' in pbr and 'normalTexture' in mat, mat['name']
            required.remove(mat['name'])
    assert not required, required
    for kind in ('mail','helmet','cape'):
        gear,data=read_glb(ROOT/f'assets/storybook/equipment/kalev_{kind}.glb')
        assert not gear.get('animations')
        gs=gear['skins'][0]
        assert bones==[gear['nodes'][j]['name'] for j in gs['joints']]
        assert near(bind,accessor(gear,data,gs['inverseBindMatrices'])), kind+' bind mismatch'
    if baseline:
        old,data=read_glb(Path(baseline))
        os=old['skins'][0]
        assert bones==[old['nodes'][j]['name'] for j in os['joints']]
        assert near(bind,accessor(old,data,os['inverseBindMatrices']))
        # Compare semantic targets and sampled values, independent of GLB indices.
        def clips(d,b):
            result={}
            for clip in d['animations']:
                channels={}
                for channel in clip['channels']:
                    target=channel['target'];sample=clip['samplers'][channel['sampler']]
                    channels[(d['nodes'][target['node']]['name'],target['path'])]=(sample.get('interpolation','LINEAR'),accessor(d,b,sample['input']),accessor(d,b,sample['output']))
                result[clip['name']]=channels
            return result
        assert near(clips(doc,blob),clips(old,data)), 'Animation data changed'
    print(json.dumps({'triangles':triangles,'bytes':path.stat().st_size,'clips':76,'fitted_wearables':3,'baseline_parity':bool(baseline)},indent=2))


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--baseline',type=Path)
    verify(parser.parse_args().baseline)
