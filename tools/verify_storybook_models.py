#!/usr/bin/env python3
"""Check portable skin/animation data in the P0-206 live model GLBs."""
import json
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1]
HUMANS = ('mart', 'aita', 'ellen', 'watchman', 'henning', 'jurgen', 'kaja')
BIRDS = ('robin', 'hooded_crow', 'gull', 'hen', 'duck')
MAMMALS = ('forge_cat', 'sheep', 'dog', 'pig', 'goat', 'boar', 'fox', 'hare', 'rat')
EXPECTED = {**dict.fromkeys(HUMANS, 76), **dict.fromkeys(MAMMALS, 6), **dict.fromkeys(BIRDS, 8)}
EXPECTED["forge_cat"] = 9
SIZES = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}
FORMATS = {5120: 'b', 5121: 'B', 5122: 'h', 5123: 'H', 5125: 'I', 5126: 'f'}


def read_glb(path):
    data = path.read_bytes()
    magic, version, size = struct.unpack_from('<4sII', data)
    assert magic == b'glTF' and version == 2 and size == len(data), path
    length, kind = struct.unpack_from('<II', data, 12)
    assert kind == 0x4E4F534A
    doc = json.loads(data[20:20+length])
    start = 20 + length
    binary_length, binary_kind = struct.unpack_from('<II', data, start)
    assert binary_kind == 0x004E4942
    return doc, data[start+8:start+8+binary_length]


def accessor(doc, binary, index):
    a = doc['accessors'][index]
    view = doc['bufferViews'][a['bufferView']]
    n = SIZES[a['type']]
    fmt = '<' + FORMATS[a['componentType']] * n
    stride = view.get('byteStride', struct.calcsize(fmt))
    offset = view.get('byteOffset', 0) + a.get('byteOffset', 0)
    return [struct.unpack_from(fmt, binary, offset+i*stride) for i in range(a['count'])]


def verify(mammals_only=False):
    report = []
    for name, count in EXPECTED.items():
        if mammals_only and name not in MAMMALS:
            continue
        path = ROOT / 'assets/storybook' / f'{name}.glb'
        doc, binary = read_glb(path)
        assert path.stat().st_size < 10 * 1024**2, f'{name}: size budget'
        assert len(doc.get('skins', [])) == 1, f'{name}: skin required'
        skin = doc['skins'][0]
        names = {doc['nodes'][i]['name'] for i in skin['joints']}
        humanoid = count == 76
        required = {'hips', 'head', 'handslot.l', 'handslot.r'} if humanoid else {'Body', 'Head', 'Tail'}
        assert required <= names or (name == 'rat' and all(any(n.startswith(prefix) for n in names) for prefix in ('Head_Head.','Leg_Toe.L.','Leg_Toe.R.'))), f'{name}: skeleton contract'
        assert len(doc['animations']) == count, f'{name}: clip count'
        clips = {a['name'] for a in doc['animations']}
        expected = {'Idle', 'Walking_A', 'Running_B', 'Interact', '1H_Melee_Attack_Chop'} if humanoid else ({'Idle', 'Walk', 'LookAround','Run','Graze','Alert'} if name in MAMMALS else {'Idle', 'Walk', 'Hop', 'Fly', 'Peck', 'TakeOff', 'Glide', 'Land'})
        if name == 'forge_cat': expected |= {'Sleep', 'Groom', 'Stretch'}
        assert expected <= clips, f'{name}: named clips'
        tris = 0
        for mesh in doc['meshes']:
            for prim in mesh['primitives']:
                attrs = prim['attributes']
                assert {'POSITION', 'NORMAL', 'JOINTS_0', 'WEIGHTS_0'} <= attrs.keys()
                weights = accessor(doc, binary, attrs['WEIGHTS_0'])
                assert all(abs(sum(w)-1) < 1e-5 for w in weights), f'{name}: weights not normalized'
                joints = accessor(doc, binary, attrs['JOINTS_0'])
                assert all(0 <= j < len(skin['joints']) for row in joints for j in row)
                assert prim['material'] < len(doc['materials'])
                tris += doc['accessors'][prim['indices']]['count'] // 3
        assert tris <= 60000, f'{name}: triangle budget'
        for anim in doc['animations']:
            moving = False
            rotation_samplers = {c["sampler"] for c in anim["channels"] if c["target"]["path"] == "rotation"}
            for sample_index, sampler in enumerate(anim['samplers']):
                times = accessor(doc, binary, sampler['input'])
                values = accessor(doc, binary, sampler['output'])
                assert len(times) > 0
                if not humanoid:
                    assert times[-1][0] > times[0][0], f'{name}/{anim["name"]}: empty duration'
                assert all(a[0] < b[0] for a, b in zip(times, times[1:]))
                moving |= any(any(abs(a-b) > 1e-5 for a, b in zip(values[0], v)) for v in values[1:])
                if not humanoid and anim["name"] not in ("TakeOff", "Land"):
                    # q and -q encode the same rotation (Blender may export either at a 180-degree rest pose).
                    same = all(abs(a-b) < 1e-5 for a,b in zip(values[0],values[-1]))
                    antipodal = sample_index in rotation_samplers and all(abs(a+b) < 1e-5 for a,b in zip(values[0],values[-1]))
                    assert same or antipodal, f'{name}/{anim["name"]}: loop seam'

            if not humanoid:
                assert moving, f'{name}/{anim["name"]}: no actual motion'
        if humanoid:
            meshes = {n.get('name') for n in doc['nodes'] if 'mesh' in n}
            assert {'Clothing_Torso', 'Clothing_Sleeve', 'Clothing_Outerwear', 'Clothing_Legs', 'Clothing_Feet', 'Hair_Scalp', 'Anatomy_Hands'} <= meshes, f'{name}: modular sections'
            for kind in ('mail','helmet','cape'):
                gear, gear_binary = read_glb(ROOT/'assets/storybook/equipment'/f'{name}_{kind}.glb')
                assert not gear.get('animations'), f'{name}/{kind}: wearable must use live body animation'
                assert len(gear['skins']) == 1
                bones = [gear['nodes'][j]['name'] for j in gear['skins'][0]['joints']]
                body_bones = [doc['nodes'][j]['name'] for j in skin['joints']]
                assert bones == body_bones, f'{name}/{kind}: joint ordering'
                bind = accessor(doc,binary,skin['inverseBindMatrices'])
                gear_bind = accessor(gear,gear_binary,gear['skins'][0]['inverseBindMatrices'])
                assert all(abs(a-b)<1e-5 for aa,bb in zip(bind,gear_bind) for a,b in zip(aa,bb)), f'{name}/{kind}: fit'
                for mesh in gear['meshes']:
                    for prim in mesh['primitives']:
                        assert all(abs(sum(row)-1)<1e-5 for row in accessor(gear,gear_binary,prim['attributes']['WEIGHTS_0']))
        elif name in MAMMALS:
            if name != 'rat':
                assert {'Shin.LF','Shin.RF','Shin.LB','Shin.RB','Foot.LF','Foot.RF','Foot.LB','Foot.RB','Ankle.LF','Ankle.RF','Ankle.LB','Ankle.RB'} <= names, f'{name}: anatomical leg articulation'
            manifest=json.loads((ROOT/'assets/storybook/mammal_sources.json').read_text())['models'][name]
            assert manifest['license']=='CC-BY-4.0' and len(manifest['sha256'])==64
            assert any('walk_reference_speed' in n.get('extras',{}) for n in doc['nodes']), f'{name}: measured gait metadata'
            textured=0
            for mesh in doc['meshes']:
                for primitive in mesh['primitives']:
                    material=doc['materials'][primitive['material']]
                    pbr=material['pbrMetallicRoughness']
                    assert 'KHR_materials_unlit' not in material.get('extensions', {}), f'{name}: unlit coat ignores night lighting'
                    assert pbr.get('metallicFactor',1)==0, f'{name}: nonmetallic tissue'
                    assert pbr.get('roughnessFactor',1)>=.2, f'{name}: surface response'
                    if 'baseColorTexture' in pbr:
                        textured+=1
                        assert 'TEXCOORD_0' in primitive['attributes'], f'{name}: authored coat UVs'
                        assert len(set(accessor(doc,binary,primitive['attributes']['TEXCOORD_0'])))>100
            assert textured>0, f'{name}: original coat texture required'
        elif name in BIRDS:
            assert {'Wing.L','Wing.R','WingTip.L','WingTip.R'} <= names
            for mesh in doc['meshes']:
                for primitive in mesh['primitives']:
                    material = doc['materials'][primitive['material']]
                    attributes = primitive['attributes']
                    assert 'COLOR_0' in attributes, f'{name}: missing species pigmentation'
                    colors = accessor(doc, binary, attributes['COLOR_0'])
                    if material['name'] != 'Bird cornea':
                        # Blender 5.2 can silently export white on all but the
                        # first material of a joined mesh. Check every region.
                        limit = 65535 if doc['accessors'][attributes['COLOR_0']]['componentType'] == 5123 else 1
                        # Authored sculpts carry their species markings in the
                        # albedo map, so neutral vertex colour there is correct
                        # rather than a lost paint layer.
                        painted = 'baseColorTexture' not in material.get('pbrMetallicRoughness', {})
                        assert not painted or any(min(c[:3]) < limit * .8 for c in colors), f'{name}/{material["name"]}: lost pigmentation'
                    if material['name'] == 'Bird plumage':
                        pbr = material['pbrMetallicRoughness']
                        assert 'baseColorTexture' in pbr and 'metallicRoughnessTexture' in pbr and 'normalTexture' in material
                        assert 'TEXCOORD_0' in attributes
                        uv = accessor(doc, binary, attributes['TEXCOORD_0'])
                        assert len(set(uv)) > 100, f'{name}: feather UVs collapsed'
            clips_by_name={a['name']:a for a in doc['animations']}
            def endpoint(clip, end):
                result={}
                for channel in clips_by_name[clip]['channels']:
                    sample=clips_by_name[clip]['samplers'][channel['sampler']]
                    result[(channel['target']['node'],channel['target']['path'])]=accessor(doc,binary,sample['output'])[-1 if end else 0]
                return result
            for previous,following in zip(['Idle','TakeOff','Fly','Glide','Land'],['TakeOff','Fly','Glide','Land','Idle']):
                left,right=endpoint(previous,True),endpoint(following,False)
                assert left.keys()==right.keys()
                assert all(abs(a-b)<1e-5 for key in left for a,b in zip(left[key],right[key])), f'{name}: {previous} -> {following} discontinuity'
        report.append({'model': name, 'triangles': tris, 'bones': len(names), 'clips': count, 'bytes': path.stat().st_size})
    print(json.dumps(report, indent=2))
    return report


if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('--mammals-only', action='store_true')
    verify(mammals_only=parser.parse_args().mammals_only)
